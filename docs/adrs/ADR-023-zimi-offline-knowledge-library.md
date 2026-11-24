# ADR-023: Zimi Offline Knowledge Library on the NAS Worker, Wired into Open WebUI

**Status:** Accepted — applied 2026-11-24
**Date:** 2026-11-24
**Decision Makers:** Tom, Claude (AI Assistant)
**Relates to:** [ADR-022](ADR-022-local-uncensored-gemma-on-vllm.md) (local model that benefits most),
[ADR-013](ADR-013-cloud-model-tier-refresh.md) (Open WebUI config-as-script pattern)

## Context

Tom asked for [Zimi](https://github.com/epheterson/Zimi) on `k3s-nas-worker`, connected to Open WebUI.
Zimi serves Kiwix ZIM files (offline Wikipedia and more) as a web app, a JSON API and an MCP server.

Findings that shaped the design (researched 2026-11-24):

- **Zimi 1.16.0** (released 2026-11-23), GPL-3.0, active. Upstream ships a Kubernetes manifest: single
  replica, `Recreate`, uid 1000, BitTorrent off, `/health` probes with a 10-minute startup window.
- **Its MCP server speaks stdio only.** Open WebUI 0.13.4 reaches tools only over HTTP (OpenAPI or
  MCP Streamable HTTP). A bridge is unavoidable.
- **`k3s-nas-worker`** is a Synology VM: Celeron J4125, 2 vCPU, ~5 GiB RAM, 47 GB free disk, tainted
  `workload-type=lightweight:NoSchedule`. Only DaemonSets ran there until now.

## Decision

### 1. One pod, two containers, pinned to the NAS worker

| Container | Image | Job |
|---|---|---|
| `zimi` | `epheterson/zimi:1.16.0` | Web app, Manage pages, title-index builds |
| `mcpo` | `ghcr.io/open-webui/mcpo:git-788ff92` (= v0.0.20) | Launches `zimi-mcp` (uvx, pinned `zimi-mcp==1.16.0`) and serves its tools as OpenAPI on :8000 with a bearer key |

mcpo is Open WebUI's own MCP-to-OpenAPI proxy and the path Zimi's docs recommend. It publishes no
version tags, so the image is pinned to the git tag of the v0.0.20 release commit. The MCP server
shares Zimi's data dir, as upstream's own remote recipe (`docker exec ... zimi mcp`) does.

Namespace `docs`, next to Paperless and Docling. Web UI at `zimi.home.jetzinger.com`; the tool API
stays cluster-internal.

### 2. Storage split by what the data is

| Volume | Class | Size | Why |
|---|---|---|---|
| `zimi-library` | `nfs-client` | 300Gi | ZIMs are large and re-downloadable; the Synology has 1.2 TB free and hosts the VM, so traffic stays on the box |
| `zimi-config` | `local-path` | 10Gi | SQLite indexes. SQLite locking over NFS is unreliable |

Trade-off: `zimi-config` is not in Synology share snapshots. It holds rebuildable indexes and bookmarks.

### 3. Content: English + German Wikipedia with images (~176 GB)

Tom's choice over the no-images variants (~71 GB): better for reading in the browser; the AI sees the
same text either way. Loaded by a Job (`download-job.yaml`) rather than Zimi's catalog downloader,
because the Job is in git, resumes, and verifies Kiwix's sha256 before a file becomes visible.

### 4. Open WebUI: OpenAPI tool server, config as a script

Tool server connections are PersistentConfig (`tool_server.connections`); `TOOL_SERVER_CONNECTIONS`
only seeds a fresh install. Same constraint as ADR-013's model curation, same answer:
`applications/open-webui/tool-servers.json` plus `scripts/open-webui/apply-tool-servers.sh`. The bearer
key is read from `docs/zimi-secrets` at apply time and sent on stdin, never stored in git.

Empty `access_grants` makes the connection admin-only — on this single-user instance, everyone.
Zimi is a per-chat toggle, not default-on.

### 5. Full toolset, narrowed to `deep_search`, `search`, `read`

Every model runs with `function_calling: legacy` (ADR-013, for deterministic Exa search). Legacy allows
one tool round. With Zimi's lean tools that round was a `search` returning snippets only; Gemma then
invented an answer (a fictitious opera director) and `cloud-smart` declined. mcpo therefore serves the
full set and Open WebUI's `function_name_filter_list` passes three tools. `deep_search` reads the top hits
in the same call; with it Gemma answered correctly with a citation.

Native function calling for Gemma was tried and rejected. vLLM got `--enable-auto-tool-choice
--tool-call-parser gemma4 --reasoning-parser gemma4` (kept: harmless, and API clients can use tools).
Direct tests: thinking off, 2 of 3 prompts produced a correct tool call in ~1 s and the third looped on
empty `<|channel>thought` blocks to the 600-token cap (24 s); thinking on, no tool calls at all. The
reasoning parser only moved the loop out of `content`. Cloud models stay on legacy too: native would
make Exa search optional.

## Traps found during the install

- **Service-link env collision.** The Service `zimi` made Kubernetes inject
  `ZIMI_PORT=tcp://10.43.184.79:80`, which is Zimi's own port setting; both containers crashed with
  `ZIMI_PORT: port must be a number`. Fixed with `enableServiceLinks: false` (the n8n `N8N_PORT` trap,
  solved without renaming the Service).
- **No NFS client on the NAS worker.** `mount: ... bad option; ... need a /sbin/mount.<type> helper`.
  `nfs-common` installed on the VM. Any rebuild of that VM needs it again.
- **Tool filter matches operationIds by suffix.** Tools are named `tool_<name>_post` (mcpo operationIds);
  a filter entry `deep_search` matched nothing and silently removed every tool.
- **New ZIMs from the Job need a pod restart**; Zimi only registers external files at startup.
- **`fsGroupChangePolicy: OnRootMismatch`** avoids a recursive chown of the library at every start.

## Consequences

### Positive

- Offline encyclopedic lookup for every model, including `local-uncensored`, whose prompts and
  lookups then never leave the cluster
- The NAS worker finally carries a workload that suits it: storage-heavy, CPU-light at rest
- Everything reproducible from git except the two secret values

### Negative

- First title-index builds on a Celeron take hours per large ZIM; search is partial until then
- `zimi-mcp` is fetched from PyPI at every mcpo start (pinned version, but a network dependency)
- 3 GiB memory limit on a ~5 GiB VM: little headroom for anything else there
- Gemma's 8K context limits how much article text one answer can use

## Alternatives Considered

| Alternative | Why rejected |
|---|---|
| Open WebUI native MCP (Streamable HTTP) via an stdio-to-HTTP proxy | Works too, but adds a third-party proxy where mcpo is Open WebUI's own and Zimi's documented path |
| Config volume on NFS | Gets Synology snapshots, risks SQLite locking problems |
| Zimi's catalog downloader for the initial library | Not in git, no checksum gate before Zimi sees the file |
| No-images Wikipedia (~71 GB) | Tom preferred images for browser reading |
| A worker other than the NAS VM | Tom asked for the NAS worker; it is also otherwise idle |

## References

- `applications/zimi/` — manifests, download Job, README
- `applications/open-webui/tool-servers.json`, `scripts/open-webui/apply-tool-servers.sh`
- Upstream: `deploy/kubernetes.yaml`, `docs/integrations/openwebui.md`, `docs/features/api-and-mcp.md`
