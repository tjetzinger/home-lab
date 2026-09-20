# Secret Rotation Procedure

**Purpose:** Rotate a shared credential across all its consumers, and scrub it from git history

**Date Created:** 2026-09-20
**Last Updated:** 2026-09-20

---

## Overview

Rotation is the only reliable remedy for an exposed credential. **History rewriting is not.**
A force-push removes the object from the branch, but GitHub keeps the unreachable objects and
continues to serve them by their old commit SHA — verified during the 2026-09-20 incident below.

Treat every exposed key as permanently public. Rotate first, scrub second.

**The two rules that govern every step here:**

- **NEVER `kubectl apply` a `secret.yaml` from this repo.** The committed templates hold empty
  placeholders and an apply overwrites the live values with them.
- **ALWAYS use `kubectl patch`** to change an individual key.

---

## Part 1 — Rotate

### 1.1 Find every consumer before changing anything

A key is usually shared. Rotating one copy and missing another produces a partial outage that is
hard to read, because the services that still hold the old key fail with 401 while the rest work.

```bash
# Which manifests reference the key by name
grep -rn "LITELLM_MASTER_KEY" --include="*.yaml" applications/

# Which live secrets exist in each namespace
kubectl --context default get secrets -n ml
kubectl --context default get secrets -n apps
kubectl --context default get secrets -n docs
```

The LiteLLM master key, for example, lives in **four** secrets:

| Secret | Namespace | Key name |
|--------|-----------|----------|
| `litellm-secrets` | `ml` | `LITELLM_MASTER_KEY` |
| `open-webui-secrets` | `apps` | `OPENAI_API_KEY` |
| `openclaw-secrets` | `apps` | `LITELLM_MASTER_KEY` |
| `paperless-gpt-secrets` | `docs` | `OPENAI_API_KEY` |

The three consumer copies are named `OPENAI_API_KEY` because each client talks to LiteLLM through
an OpenAI-compatible SDK. Grepping for `LITELLM_MASTER_KEY` alone will miss them.

### 1.2 Generate and apply

```bash
NEW_KEY="sk-litellm-$(openssl rand -base64 32 | tr -d '/+=' | head -c 32)"

kubectl --context default patch secret litellm-secrets -n ml --type='merge' \
  -p "{\"stringData\":{\"LITELLM_MASTER_KEY\":\"${NEW_KEY}\"}}"

kubectl --context default patch secret open-webui-secrets -n apps --type='merge' \
  -p "{\"stringData\":{\"OPENAI_API_KEY\":\"${NEW_KEY}\"}}"

kubectl --context default patch secret openclaw-secrets -n apps --type='merge' \
  -p "{\"stringData\":{\"LITELLM_MASTER_KEY\":\"${NEW_KEY}\"}}"

kubectl --context default patch secret paperless-gpt-secrets -n docs --type='merge' \
  -p "{\"stringData\":{\"OPENAI_API_KEY\":\"${NEW_KEY}\"}}"
```

Patch the **issuer** (`litellm-secrets`) and its consumers in the same sitting. Between the first
and last patch, authentication is broken for whatever has not been updated yet.

### 1.3 Restart consumers

Secrets mounted as environment variables are read once at container start. A patched secret changes
nothing until the pod restarts.

```bash
kubectl --context default rollout restart deployment/litellm -n ml
kubectl --context default rollout restart statefulset/open-webui -n apps
kubectl --context default rollout restart deployment/paperless-gpt -n docs
kubectl --context default rollout restart deployment/openclaw -n apps

kubectl --context default rollout status deployment/litellm -n ml
```

Secrets mounted as *files* are refreshed in place by the kubelet, but on a delay of up to a minute.
Everything in this cluster uses `env` / `envFrom`, so assume a restart is always required.

### 1.4 Verify — both directions

Confirming the new key works is only half the check. Confirm the **old key is dead**, or you have
not proven the rotation took effect anywhere.

```bash
# New key: expect HTTP 200
kubectl --context default run curl-test --rm -it --restart=Never --image=curlimages/curl -- \
  curl -s -o /dev/null -w '%{http_code}\n' \
  -H "Authorization: Bearer ${NEW_KEY}" \
  http://litellm.ml.svc.cluster.local:4000/v1/models

# Old key: expect HTTP 401
kubectl --context default run curl-test --rm -it --restart=Never --image=curlimages/curl -- \
  curl -s -o /dev/null -w '%{http_code}\n' \
  -H "Authorization: Bearer <old-key>" \
  http://litellm.ml.svc.cluster.local:4000/v1/models
```

Then exercise one real path end to end — tag a document with `paperless-gpt`, or send a chat message
in Open-WebUI. A 200 on `/v1/models` does not prove the consumers picked up the new value.

### 1.5 Update the local untracked copies

`secret.yaml` is gitignored (`.gitignore:37`), so the on-disk copies under `applications/*/` are
**not** rewritten by a history scrub. After rotating, they still hold the dead key and will mislead
anyone who reads them during a later recovery. Update them by hand, or blank them.

---

## Part 2 — Scrub git history

Do this only after Part 1 is verified. It does not undo the exposure; it stops the key spreading
further through clones and future greps.

### 2.1 Rewrite

```bash
# Map of secret -> replacement, one per line
cat > /tmp/replacements.txt <<'EOF'
sk-litellm-OLDKEYHERE==>***REDACTED-ROTATED-2026-09-20***
EOF

git filter-repo --replace-text /tmp/replacements.txt --force
rm /tmp/replacements.txt
```

`git filter-repo` removes the `origin` remote by design, to stop an accidental push of a
half-finished rewrite. Re-add it afterwards.

```bash
git remote add origin git@github.com:tjetzinger/home-lab.git
git push --force origin master
```

### 2.2 Confirm the rewrite locally

```bash
# Expect no output
git grep -l "sk-litellm-OLDKEYHERE" $(git rev-list --all)
```

`filter-repo` writes its own audit trail to `.git/filter-repo/`:

- `commit-map` — old SHA → new SHA for every commit, including unchanged ones
- `first-changed-commits` — the earliest commit the rewrite touched
- `changed-refs` — which refs moved

The 2026-09-20 run rewrote **32 of 161 commits**, starting at `9a77573` → `fc70bc2`, and also
touched `refs/stash`.

### 2.3 Confirm what GitHub still serves — this is the part people skip

The old commits are unreachable from any branch but still exist on GitHub's side, and
`raw.githubusercontent.com` will serve a file out of them by SHA.

```bash
curl -s -o /dev/null -w '%{http_code}\n' \
  https://raw.githubusercontent.com/tjetzinger/home-lab/<old-sha>/<path-that-held-the-key>
```

On 2026-09-20 this returned **HTTP 200 with the key still present** at `3790bb9`
(rewritten to `dc0e04f`), *after* the force-push completed.

Only GitHub Support can garbage-collect unreachable objects on a repository. Open a request if the
exposure warrants it. Until they do, **rotation is the only thing protecting the credential** — which
is why Part 1 comes first and is not optional.

---

## Incident log

### 2026-09-20 — LiteLLM master key

| | |
|---|---|
| **Credential** | LiteLLM master key (`sk-litellm-X85…`) |
| **Exposed in** | `docs/analysis/brainstorming-session-2026-02-19.md`, 2 occurrences |
| **Exposure window** | 2026-02-19 → 2026-09-20 (~7 months), public repo |
| **Blast radius** | Full admin on the LiteLLM proxy: model access, spend, and the `/ui/login` admin UI |
| **Consumers rotated** | 4 secrets across `ml`, `apps`, `docs` |
| **Verified** | New key 200, old key 401 |
| **History** | 32 commits rewritten, replaced with `***REDACTED-ROTATED-2026-09-20***` |
| **Still public** | Yes — old objects served by SHA; rotation is the mitigation |

**Found by:** a repo-wide audit of 61 live secrets against 158 commits. It was the only real leak.
Several other hits were self-documenting placeholders, not exposures.

**Why it went unnoticed:** the key was pasted into an analysis document, not a manifest. The
`.gitignore` rules cover `secret.yaml` and `*-secrets.yaml`, so they never applied to a file under
`docs/analysis/`. Secret-scanning rules keyed on filenames will keep missing this class of leak.

---

## Related

- `docs/runbooks/cluster-restore.md` — full cluster state recovery
- `applications/litellm/secret.yaml` — key inventory and per-key patch commands (untracked)
- `CLAUDE.md` — the never-apply / always-patch rule
