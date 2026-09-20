# Open-WebUI

ChatGPT-like web interface for LLM models via LiteLLM.

## Overview

Open-WebUI provides a polished chat interface similar to ChatGPT, connected to our LiteLLM proxy for unified model access.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  User Browser                                                   │
│  https://chat.home.jetzinger.com                               │
└─────────────────────┬───────────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────────┐
│  Traefik Ingress (Story 17.3)                                   │
└─────────────────────┬───────────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────────┐
│  Open-WebUI (apps namespace)                                    │
│  ├── Web Interface                                              │
│  ├── Chat History (SQLite on NFS)                              │
│  └── OpenAI-compatible API client                               │
└─────────────────────┬───────────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────────┐
│  LiteLLM Proxy (ml namespace)                                   │
│  ├── vLLM (GPU - local)                                        │
│  ├── Ollama (CPU - fallback)                                   │
│  └── External providers (Groq, Google, Mistral)                │
└─────────────────────────────────────────────────────────────────┘
```

## Deployment

### Prerequisites

- Kubernetes cluster with `apps` namespace
- NFS storage class (`nfs-client`)
- LiteLLM running in `ml` namespace (for Story 17.2)

### Install

```bash
# Add Open-WebUI Helm repo
helm repo add open-webui https://helm.openwebui.com/
helm repo update

# Deploy Open-WebUI
helm upgrade --install open-webui open-webui/open-webui \
  -f values-homelab.yaml \
  -n apps
```

### Verify

```bash
# Check pods
kubectl get pods -n apps -l app.kubernetes.io/name=open-webui

# Check PVC
kubectl get pvc -n apps

# Port-forward for testing
kubectl port-forward -n apps svc/open-webui 8080:80
# Access: http://localhost:8080
```

## Configuration

### Persistence

Chat history stored on NFS at `/app/backend/data`:
- SQLite database for conversations
- User settings and preferences
- Uploaded files

### LiteLLM Integration (Story 17.2)

Open-WebUI connects to LiteLLM for unified model access:

```yaml
extraEnvVars:
  - name: OPENAI_API_BASE_URL
    value: "http://litellm.ml.svc.cluster.local:4000/v1"
  - name: OPENAI_API_KEY
    valueFrom:
      secretKeyRef:
        name: open-webui-secrets
        key: OPENAI_API_KEY
```

Open-WebUI draws models from **two independent connections**:

1. **Direct Ollama Pro cloud** (`ollamaUrls: https://ollama.com`) — enumerates the account catalogue
   live, so new models appear and retired ones drop off with no config change.
2. **LiteLLM** (`OPENAI_API_BASE_URL`) — the role aliases, which add automatic failover.

**Visible models (curated, ADR-013):**

| Model | Source | Why it is in the picker |
|-------|--------|-------------------------|
| `kimi-k3` | Cloud | Most powerful available: 1M ctx, vision + thinking + tools |
| `deepseek-v4-pro:0813` | Cloud | Top-tier reasoning, 1M ctx |
| `glm-5.3` | Cloud | Current GLM flagship, 1M ctx |
| `mistral-large-3:675b` | Cloud | Best German of the catalogue, vision |
| `minimax-m3` | Cloud | Current MiniMax flagship, 512K ctx, vision |
| `kimi-k2.7-code` | Cloud | Dedicated coding model |
| `deepseek-v4.1-flash` | Cloud | Fast tier, 1M ctx, vision |
| `gpt-oss:120b` | Cloud | Open-weight option |
| `gemma4:31b` | Cloud | Small and quick, strong multilingual |
| `nemotron-3-ultra` | Cloud | NVIDIA flagship |
| `cloud-docs` | LiteLLM | `mistral-large-3` + automatic fallback chain |
| `cloud-fast` | LiteLLM | `deepseek-v4.1-flash` + automatic fallback chain |
| `cloud-smart` | LiteLLM | `kimi-k3` + automatic fallback chain (**default model**) |

**Fallback Chain (LiteLLM aliases only):** Ollama Pro cloud → vLLM (GPU) → Ollama (CPU).
`openai-gpt4o` is explicit-selection only and not in the auto-fallback chain.

## Web search (Exa)

In-chat web search uses [Exa](https://exa.ai).

| Setting | Value |
|---------|-------|
| `ENABLE_WEB_SEARCH` | `true` |
| `WEB_SEARCH_ENGINE` | `exa` |
| `WEB_SEARCH_RESULT_COUNT` | `5` |
| `EXA_API_KEY` | from `open-webui-secrets` |

The key is the same one `openclaw-secrets` holds, copied into Open-WebUI's own secret so
this app does not depend on another app's secret. Apply it with `kubectl patch`, never
`kubectl apply` the secret file.

**These are PersistentConfig vars.** The Helm `extraEnvVars` seed a fresh install only —
on an existing install the database value wins and the env vars are ignored. Change them
live via `POST /api/v1/retrieval/config/update` or Admin → Settings → Web Search. This is
the same trap documented under Model curation below.

### Default-on per user

Engine config alone does not switch search on for a chat. Each user carries their own
`ui.webSearch` setting, applied via `POST /api/v1/users/user/settings/update`:

```bash
# 'always' | 'on' | 'off'
curl -s -X POST https://chat.home.jetzinger.com/api/v1/users/user/settings/update \
  -H "Authorization: Bearer $OPENWEBUI_API_KEY" \
  -H 'Content-Type: application/json' \
  -d '{"ui":{"webSearch":"always"}}'
```

**Read the value back from the database, not from the API response.** The update endpoint
echoes the value it was sent whether or not it persisted — a first attempt on 2026-09-20
returned `always` and then read back as `None`.

```bash
kubectl --context default exec -n apps statefulset/open-webui -- \
  python3 -c "import sqlite3,json; \
    r=sqlite3.connect('/app/backend/data/webui.db').execute( \
      'select settings from user').fetchone(); \
    print(json.loads(r[0])['ui'].get('webSearch'))"
```

### Why `function_calling: legacy` is set on every model

**Status as of 2026-09-20: verified working.** A chat asking for the current Kubernetes release
returns `sources: 1` and the real answer (v1.37, August 2026). Before this change the same question
returned v1.29 from December 2023 — the model's training data, with no search at all.

Open-WebUI has two paths for web search, chosen by a model's `function_calling` param:

| `function_calling` | Behaviour |
|---|---|
| `native` (default) | Offers the model a `web_search` tool and lets it decide. Skipped entirely unless the request carries a websocket `session_id`. |
| `legacy` | Runs Exa and injects the results into the prompt. Deterministic. |

The relevant code in app 0.11.3:

```python
# utils/middleware.py:2677 — the forced-search path
if metadata.get('params', {}).get('function_calling') == 'legacy':
    form_data = await chat_web_search_handler(request, form_data, extra_params, user)

# utils/middleware.py:2769 — the native path, which also needs a live socket session
use_builtin_tools = is_note_chat or (
    bool(metadata.get('session_id'))
    and metadata.get('params', {}).get('function_calling') != 'legacy'
    ...
)
```

`main.py:1267` defaults the value to `'native'` when neither the request nor the stored model record
sets it, so doing nothing means search never reliably runs.

**The trade-off:** `legacy` routes *all* tool use through prompt-based calling
(`chat_completion_tools_handler`) instead of the provider's native tool API. Web search becomes
guaranteed; native tool calling is given up. Revert by setting `model_params` to `{}` in
[`model-curation.json`](model-curation.json) and re-running the curation script.

The value is stored per model and applied by
[`apply-model-curation.sh`](../../scripts/open-webui/apply-model-curation.sh) from the
`model_params` block in `model-curation.json`, so it survives a PVC restore.

**Verifying it:** read the value from SQLite, not the API.

```bash
kubectl --context default exec -n apps statefulset/open-webui -c open-webui -- \
  python3 -c "import sqlite3; print(sqlite3.connect( \
    '/app/backend/data/webui.db').execute('select id, params from model').fetchall())"
```

`ModelParams` is declared with `extra='allow'`, so the value is stored and honoured at request time
— but `GET /api/models` and `GET /api/v1/models` both serialise `params` as `{}` and drop it.
Asserting against either endpoint reports a false failure on a correct config.

To confirm search actually ran, check the response for citation sources: `sources` non-empty via the
API, or a sources block under the answer in the browser. Config values only prove it *can* run.

## Model curation

The picker is curated down from ~33 entries to the 13 above. The keep/hide lists live in
[`model-curation.json`](model-curation.json) and are applied with:

```bash
./scripts/open-webui/apply-model-curation.sh            # apply
./scripts/open-webui/apply-model-curation.sh --dry-run  # preview
```

It also applies the `model_params` block — currently `function_calling: legacy`, which is what
makes web search actually run. See the web search section above.

**Two upstream constraints make this a script rather than Helm values — read before editing:**

1. **`DEFAULT_MODELS` is a `ConfigVar` (PersistentConfig).** With `ENABLE_PERSISTENT_CONFIG=true` (the
   default) the value stored in the Open-WebUI DB wins and the Helm env var is **ignored**. Changing it
   in `values-homelab.yaml` and running `helm upgrade` has no effect on an existing install — it must
   also be set in Admin Panel → Settings → General.
2. **`OLLAMA_API_CONFIGS` / `OPENAI_API_CONFIGS` cannot be seeded from env vars.** The `model_ids`
   whitelist they expose is the right mechanism, but upstream never implemented JSON parsing for them
   ([issue #19017](https://github.com/open-webui/open-webui/issues/19017), closed as *not planned*).

A third trap, found during the 16.5.0 upgrade: on startup 0.11.3 logged
`Seeded 341 new config defaults` and silently reset `OPENAI_API_BASE_URLS` to
`https://api.openai.com/v1` with an empty key, overriding the `openaiBaseApiUrl` and
`openaiApiKeyExistingSecret` values from Helm. Chat returned HTTP 400 with OpenAI's
"You didn't provide an API key" error. The picker still listed every `cloud-*` model
throughout, because `model_ids` only filters names and never checks that the connection
works. The apply script now asserts the base URL and key, not just the visible model set.

Model visibility therefore lives in the Open-WebUI DB on the NFS PVC, not in Git. The script is both
the declarative substitute and the recovery path if that PVC is ever lost. It needs an admin API key in
`open-webui-secrets` as `OPENWEBUI_API_KEY` (generate in Open-WebUI → Settings → Account, then apply
with `kubectl patch` — never `kubectl apply` the secret file).

### Ingress (Story 17.3)

HTTPS access via `chat.home.jetzinger.com`:

```bash
# Apply ingress resources
kubectl apply -f ingressroute.yaml

# Verify certificate
kubectl get certificate -n apps open-webui-tls

# Verify ingress routes
kubectl get ingressroute -n apps | grep open-webui
```

**Ingress Components:**
- Certificate: `open-webui-tls` (Let's Encrypt via cert-manager)
- IngressRoute: `open-webui-ingress` (HTTPS on websecure entrypoint)
- HTTP Redirect: `open-webui-ingress-redirect` (HTTP to HTTPS)

**Access:**
- URL: `https://chat.home.jetzinger.com`
- HTTP automatically redirects to HTTPS (308)
- Valid TLS certificate from Let's Encrypt

## Backup and restore

Open-WebUI schema migrations are **one-way**. Rolling the image back does not undo them, so a
pre-upgrade archive is the only rollback path. Take one before every chart or app upgrade, and
before any bulk data change.

Backups live on the `open-webui-backup` PVC (5Gi, `nfs-client`, see
[`backup-pvc.yaml`](backup-pvc.yaml)), not on your workstation. See the truncation trap below.

### Take a backup

Scale the statefulset to 0 first. `tar` on a live data directory fails with
`file changed as we read it` and leaves an inconsistent archive.

```bash
kubectl --context default scale statefulset open-webui -n apps --replicas=0

# Run a busybox pod mounting both `open-webui` (data) and `open-webui-backup`, then:
#   cd /data && tar czf /backup/open-webui-data-$(date +%Y%m%d-%H%M%S).tar.gz --exclude=./cache .

kubectl --context default scale statefulset open-webui -n apps --replicas=1
```

Always verify the archive before trusting it:

```bash
gzip -t /backup/open-webui-data-<timestamp>.tar.gz   # silent = good
```

`cache/` is excluded. It holds ~1.1G of embedding models that regenerate on demand. Real state
— `webui.db`, `uploads/`, `vector_db/` — is roughly 23MB, so a full archive lands near 22MB.

For a quick, low-risk snapshot before a data change, copying `webui.db` alone is enough and does
not need a scale-down:

```bash
kubectl --context default exec -n apps statefulset/open-webui -- \
  cp /app/backend/data/webui.db /backup/webui-pre-<change>-$(date +%Y%m%d-%H%M%S).db
```

### Do not stream archives out of the cluster

**`kubectl cp` and `kubectl exec -- cat` both truncate at ~17MB in this environment** and produce
a corrupt gzip that `gzip -t` rejects. The truncation is silent — the command exits 0. This is why
the backup PVC exists: write the archive inside the cluster and leave it there.

### Restore

```bash
kubectl --context default scale statefulset open-webui -n apps --replicas=0

# From a busybox pod mounting both volumes:
#   cd /data && rm -rf ./* && tar xzf /backup/open-webui-data-<timestamp>.tar.gz

kubectl --context default scale statefulset open-webui -n apps --replicas=1
kubectl --context default rollout status statefulset/open-webui -n apps
```

A restore returns the database to its archived state, which includes the PersistentConfig values.
Expect to re-apply anything changed since — model curation, web search config, the default model.
Re-run [`apply-model-curation.sh`](../../scripts/open-webui/apply-model-curation.sh) afterwards.

## Stories

| Story | Description | Status |
|-------|-------------|--------|
| 17.1 | Deploy with persistent storage | Done |
| 17.2 | Configure LiteLLM backend | Done |
| 17.3 | Configure HTTPS ingress | Done |

## Requirements

- FR126: Deployed in `apps` namespace with persistent storage
- FR127: LiteLLM backend integration (Story 17.2)
- FR128: HTTPS ingress access (Story 17.3)
- FR129: Model switching support (Story 17.2)
- NFR75: Page load < 3 seconds
- NFR76: Chat history survives pod restarts
