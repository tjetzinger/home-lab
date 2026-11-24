# Zimi — Offline Knowledge Library

Offline Wikipedia (English + German, with images) served from Kiwix ZIM files, readable in a
browser and searchable by the models in Open WebUI. ADR-023.

| Item | Value |
|---|---|
| Upstream | [epheterson/Zimi](https://github.com/epheterson/Zimi) (GPL-3.0) |
| Image | `epheterson/zimi:1.16.0` + `ghcr.io/open-webui/mcpo:git-788ff92` (mcpo v0.0.20) |
| Namespace | `docs` |
| Node | `k3s-nas-worker` (pinned; tolerates `workload-type=lightweight:NoSchedule`) |
| Web UI | https://zimi.home.jetzinger.com (Tailscale only) |
| Tool API | `http://zimi-mcpo.docs.svc.cluster.local:8000` (cluster-internal, bearer key) |
| Library | PVC `zimi-library`, 300Gi, `nfs-client` (Synology) |
| State | PVC `zimi-config`, 10Gi, `local-path` on the NAS VM (SQLite indexes) |

## How it fits together

```
Open WebUI ──OpenAPI + bearer──▶ zimi-mcpo:8000 ──stdio──▶ zimi-mcp (uvx, pinned 1.16.0)
                                        │                          │
Browser ──Traefik──▶ zimi:80 ──▶ zimi (web app :8899)              │
                                        │                          │
                          /zims (NFS, ZIMs)  +  /config (local-path, indexes) ◀─┘
```

- **zimi** is the web app: reader, search, Manage pages, title-index builds.
- **mcpo** turns Zimi's MCP server into OpenAPI. Zimi's MCP server speaks stdio only, and
  Open WebUI reaches tools only over HTTP. mcpo starts `zimi-mcp` itself; `uvx` fetches it from
  PyPI at container start, pinned to the same version as the image.
- mcpo runs Zimi's **full** toolset (`--tools full`, ~20 tools). Open WebUI narrows it to three with
  `function_name_filter_list`: `deep_search`, `search`, `read`. `deep_search` is the one that matters
  (see below).

## Deploy

```bash
# once: create the secret with real values (see secret.yaml), never kubectl apply it
kubectl apply -f applications/zimi/pvc.yaml
kubectl apply -f applications/zimi/deployment.yaml
kubectl apply -f applications/zimi/service.yaml
kubectl apply -f applications/zimi/ingressroute.yaml
kubectl apply -f applications/zimi/download-job.yaml   # initial library, ~176GB
./scripts/open-webui/apply-tool-servers.sh             # registers Zimi in Open WebUI
```

## Why `deep_search`, and why the full toolset

Open WebUI runs every model with `function_calling: legacy`, because that is what makes Exa web search
run (see the Open WebUI README). Legacy gives a model **one** tool round and no follow-up. With Zimi's
default lean tools that meant one `search` and only snippets: `cloud-smart` said it could not answer,
and Gemma (`local-uncensored`) **invented** a director of the Vienna State Opera. `deep_search` searches
and reads the top hits in that single call; with it Gemma answered correctly with a citation.

Native function calling (search, then read, over several rounds) was tested for Gemma on 2026-11-24.
vLLM now has `--enable-auto-tool-choice --tool-call-parser gemma4 --reasoning-parser gemma4`, but the
model is unreliable with it: thinking off, it made 2 of 3 tool calls correctly and looped on empty
`<|channel>thought` blocks until max tokens on the third; thinking on, it never called a tool. So
`local-uncensored` stays on legacy. For cloud models native would also turn Exa into an optional tool.

## Traps found during the install

- **`enableServiceLinks: false` is required.** Kubernetes injects `ZIMI_PORT=tcp://10.43.x.x:80` for
  the Service `zimi`, which is Zimi's own port setting. Both containers crashed with
  `ZIMI_PORT: port must be a number`. Same class of bug as n8n's `N8N_PORT`.
- **The NAS worker had no NFS client.** No pod had ever mounted NFS there; mounts failed with
  `bad option ... need a /sbin/mount.<type> helper`. `nfs-common` was installed on 2026-11-24.
  A rebuilt NAS VM needs it again.
- **The tool filter matches operationIds by suffix.** Open WebUI names an mcpo tool after its OpenAPI
  operationId (`tool_deep_search_post`), and `function_name_filter_list` keeps names that *end with* an
  entry. A filter of `deep_search` matched nothing and silently dropped every tool; models then answered
  without calling Zimi and one claimed it had. Use the full operationIds.
- **New ZIMs need a pod restart.** Zimi registers files from its own downloader live, but files that
  appear from outside (the download Job) only at startup:
  `kubectl rollout restart deployment/zimi -n docs`.
- **`fsGroupChangePolicy: OnRootMismatch`** keeps Kubernetes from re-owning 176GB on NFS at every start.

## Library content

15 ZIMs, ~215 GB, as of 2026-11-24. All of them are listed in `download-job.yaml` (`FILES`, as
`dir/file.zim` under https://download.kiwix.org/zim/), so a lost library comes back the same.

| ZIM | Size | Kiwix dir |
|---|---|---|
| `wikipedia_en_all_maxi_2026-08` | 127.4 GB | `wikipedia/` |
| `wikipedia_de_all_maxi_2026-10` | 48.6 GB | `wikipedia/` |
| `maps_en_europe_2026-08` | 26.7 GB | `maps/` |
| `gutenberg_en_top_2026-11` | 7.3 GB | `community/` |
| `mdwiki_en_all_maxi_2025-11` | 2.3 GB | `other/` |
| `medlineplus.gov_en_all_2025-01` | 1.9 GB | `zimit/` |
| `quickguidesformedicine_en_all_2026-06` | 0.5 GB | `videos/` |
| 8 small ones (CDC, Stack Exchange, LibrePathology, NHS medicines, …) | < 0.2 GB each | `zimit/`, `other/`, `stack_exchange/`, `community/` |

Zimi also ships two built-in ZIMs (games, almanac).

**Updates are automatic.** Auto-update is on in Manage (`/config/auto_update.json`: daily,
`wikipedia_de` skipped), and Zimi replaces a ZIM with the newest dump of the **same flavor**. That
includes files the Job placed. So the dates on disk move ahead of `FILES`; the Job treats any dump of
a ZIM as present and never downloads an older one over it. Zimi's own downloads are not checked
against the published sha256 by this repo.

**Adding a ZIM:** through Manage is fine (registered live, no restart). To keep the repo complete,
also add it to `FILES`. A ZIM placed by the Job needs `kubectl rollout restart deployment/zimi -n docs`.

Space: the 300Gi PVC is a label; the NFS provisioner does not enforce it. While Zimi replaces the
English Wikipedia, old and new dump coexist briefly (~255 GB for that one ZIM).

The first title-index build of each large ZIM runs on a Celeron J4125 and takes hours. Search works
meanwhile; a result line `Incomplete: ... title index building NN%` says which sources are not done.

## Open WebUI

Registered as an OpenAPI tool server through `applications/open-webui/tool-servers.json`
(PersistentConfig, so a script and not Helm values). In a chat, turn on **Zimi** in the tools menu.
It works with any model; `local-uncensored` has builtin tools off, which does not affect external
tool servers. Gemma's 8K context limits how much article text fits per answer.

Access is admin-only (empty `access_grants`), which on this instance is the only user.

## Operations

```bash
kubectl get pods -n docs -l app.kubernetes.io/name=zimi -o wide
kubectl logs -n docs deploy/zimi -c zimi --tail=50     # web app, index builds
kubectl logs -n docs deploy/zimi -c mcpo --tail=50     # tool calls from Open WebUI
kubectl logs -n docs job/zimi-download --tail=5        # download progress
curl -s https://zimi.home.jetzinger.com/health
```

Management password: `kubectl get secret zimi-secrets -n docs -o jsonpath='{.data.ZIMI_MANAGE_PASSWORD}' | base64 -d`

Backups: `zimi-config` sits on the NAS VM's disk and is not in Synology share snapshots. It holds
rebuildable indexes plus bookmarks. The ZIMs are re-downloadable.
