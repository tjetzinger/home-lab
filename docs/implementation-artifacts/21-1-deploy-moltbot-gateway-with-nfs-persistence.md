# Story 21.1: Deploy Moltbot Gateway with NFS Persistence

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **cluster operator**,
I want **to deploy the Moltbot gateway container on K3s with persistent NFS storage for configuration and workspace data**,
So that **my AI assistant infrastructure is running and survives pod restarts without losing state**.

## Acceptance Criteria

1. **Moltbot pod deploys successfully** — The Moltbot pod starts in the `apps` namespace using the official `moltbot/moltbot` image (Node.js >= 22) with a single replica Deployment.

2. **NFS PVC bound and mounted** — A 10Gi NFS PVC (`moltbot-data`) is created with `ReadWriteOnce` access and mounted via subPath:
   - `~/.moltbot` (config) → subPath `moltbot` *(updated: image renamed `.clawdbot` to `.moltbot`)*
   - `~/clawd/` (workspace) → subPath `clawd`

3. **K8s Secret created with placeholder values** — `moltbot-secrets` Secret in `apps` namespace contains placeholder values for all credential types:
   - `ANTHROPIC_OAUTH_TOKEN`
   - `TELEGRAM_BOT_TOKEN`
   - `WHATSAPP_CREDENTIALS`
   - `DISCORD_BOT_TOKEN`
   - `ELEVENLABS_API_KEY`
   - `EXA_API_KEY`
   - `LITELLM_FALLBACK_URL` (set to `http://litellm.ml.svc.cluster.local:4000/v1`)
   - `CLAWDBOT_GATEWAY_TOKEN` (required for gateway auth)

4. **Configuration persists on NFS** — The gateway configuration is stored at `~/.moltbot/` on the NFS PVC.

5. **Pod restart preserves state** — When the pod is deleted or the node reboots, the replacement pod starts with all configuration and workspace data intact from NFS (NFR100). No manual re-configuration is required.

## Tasks / Subtasks

- [x] Task 1: Create `applications/moltbot/` directory structure (AC: #1)
  - [x] 1.1 Create directory `applications/moltbot/`

- [x] Task 2: Create NFS PVC manifest (AC: #2)
  - [x] 2.1 Create `applications/moltbot/pvc.yaml` with 10Gi NFS PVC named `moltbot-data` in `apps` namespace
  - [x] 2.2 Set `storageClassName: nfs-client` (matches existing NFS provisioner pattern)
  - [x] 2.3 Set `accessModes: [ReadWriteOnce]`
  - [x] 2.4 Apply standard labels: `app.kubernetes.io/name: moltbot`, `app.kubernetes.io/part-of: home-lab`, `app.kubernetes.io/managed-by: kubectl`

- [x] Task 3: Create K8s Secret manifest (AC: #3)
  - [x] 3.1 Create `applications/moltbot/secret.yaml` with placeholder values for all 8 credential types (7 original + CLAWDBOT_GATEWAY_TOKEN)
  - [x] 3.2 Set `LITELLM_FALLBACK_URL` to `http://litellm.ml.svc.cluster.local:4000/v1`
  - [x] 3.3 Verified existing `.gitignore` patterns cover `secret.yaml` (`git check-ignore` confirmed)

- [x] Task 4: Create Deployment manifest (AC: #1, #2, #4)
  - [x] 4.1 Create `applications/moltbot/deployment.yaml` with `moltbot/moltbot:latest` image
  - [x] 4.2 Configure single replica, `apps` namespace
  - [x] 4.3 Mount `moltbot-data` PVC with two subPath mounts:
    - `/home/node/.moltbot` → subPath `moltbot` *(updated from `.clawdbot`)*
    - `/home/node/clawd` → subPath `clawd`
  - [x] 4.4 Reference `moltbot-secrets` via `envFrom.secretRef`
  - [x] 4.5 Expose container ports 18789 (gateway) and 18790 (bridge) *(updated from 3000)*
  - [x] 4.6 Apply standard labels
  - [x] 4.7 Set `RollingUpdate` strategy
  - [x] 4.8 Set gateway startup command: `node dist/index.js gateway --bind lan --port 18789 --allow-unconfigured`

- [x] Task 5: Create ClusterIP Service manifest (AC: #1)
  - [x] 5.1 Create `applications/moltbot/service.yaml` exposing ports 18789 (gateway) and 18790 (bridge) *(updated from 3000)*
  - [x] 5.2 Apply standard labels and selector `app.kubernetes.io/name: moltbot`

- [x] Task 6: Apply manifests and validate (AC: #1, #2, #3, #5)
  - [x] 6.1 Apply PVC, Secret, Deployment, Service to cluster
  - [x] 6.2 Verify pod starts successfully — Running 1/1 on k3s-worker-02
  - [x] 6.3 Verify PVC is bound — 10Gi RWO nfs-client Bound
  - [x] 6.4 Verify NFS mount paths exist inside container — `.moltbot/` and `clawd/` confirmed with data
  - [x] 6.5 Delete pod and verify replacement starts with config intact — replacement pod Running 1/1, data persisted

## Gap Analysis

**Scan Date:** 2026-01-29

**What Exists:**
- `apps` namespace is active
- `nfs-client` storageClass available (NFS provisioner operational)
- `.gitignore` already covers `*-secret.yaml`, `secret.yaml`, `secrets/` patterns
- Similar deployment patterns exist (open-webui in apps namespace as reference)

**What's Missing:**
- `applications/moltbot/` directory does not exist
- No moltbot-related manifests in the repo

**Task Changes Applied:**
- Task 3.3: Changed from "Ensure secret.yaml is in .gitignore" to "Verify existing .gitignore patterns cover secret.yaml" (already covered by generic patterns)

---

## Dev Notes

### Architecture Patterns & Constraints

- **Namespace:** `apps` (same as n8n, Open-WebUI)
- **Image:** `moltbot/moltbot:latest` — official Docker image, no custom build
- **Runtime:** Node.js >= 22
- **Port:** 3000 (gateway control UI + WebChat)
- **Replicas:** 1 (single instance, not horizontally scalable)
- **Strategy:** RollingUpdate
- **Storage:** NFS PVC via `nfs-client` storageClass (10Gi), same pattern as other apps
- **Secrets:** Kubernetes Secrets (not ConfigMaps) per NFR91 — all credentials stored as K8s Secrets
- **Labels:** Must follow `app.kubernetes.io/*` labeling convention per architecture doc
- **Managed-by:** `kubectl` (not Helm) — direct YAML manifests like dev-containers, unlike Helm-based apps

### Storage Mount Paths (Critical)

The architecture specifies exact mount paths inside the container:
- `/home/node/.clawdbot` — config directory (contains `moltbot.json`)
- `/home/node/clawd` — workspace directory (agent workspace, mcporter config, session data)

Both use subPath mounts from a single PVC `moltbot-data`:
- subPath `clawdbot` → `/home/node/.clawdbot`
- subPath `clawd` → `/home/node/clawd`

### Secret Keys (7 credential types per NFR91)

From architecture document reference manifests:
```
ANTHROPIC_OAUTH_TOKEN: ""
TELEGRAM_BOT_TOKEN: ""
WHATSAPP_CREDENTIALS: ""
DISCORD_BOT_TOKEN: ""
ELEVENLABS_API_KEY: ""
EXA_API_KEY: ""
LITELLM_FALLBACK_URL: "http://litellm.ml.svc.cluster.local:4000/v1"
```

Note: `secret.yaml` must be gitignored. Only `LITELLM_FALLBACK_URL` has a known value at deploy time.

### Project Structure Notes

- New directory: `applications/moltbot/` (does not exist yet)
- Architecture specifies these files for the full epic:
  - `deployment.yaml`, `service.yaml`, `ingressroute.yaml`, `pvc.yaml`, `secret.yaml`, `blackbox-probe.yaml`
- **This story creates:** `deployment.yaml`, `service.yaml`, `pvc.yaml`, `secret.yaml`
- **Story 21.2 creates:** `ingressroute.yaml`
- **Story 24.x creates:** `blackbox-probe.yaml`

### Dependencies

- **Requires:** NFS provisioner (Epic 2 - done), `apps` namespace (exists)
- **Depends on:** Epic 14 LiteLLM (done) — for `LITELLM_FALLBACK_URL` value
- **No external dependencies** — all infrastructure prerequisites are satisfied

### Reference Pattern

Similar deployment in cluster: Open-WebUI (`applications/open-webui/`) uses Helm values, but Moltbot uses raw YAML manifests. Closer pattern: dev-containers (raw YAML in `applications/dev-containers/`).

### References

- [Source: docs/planning-artifacts/architecture.md - Moltbot Personal AI Assistant Architecture (line ~1368)]
- [Source: docs/planning-artifacts/architecture.md - Reference Deployment manifest (line ~1511)]
- [Source: docs/planning-artifacts/architecture.md - Reference Secret manifest (line ~1553)]
- [Source: docs/planning-artifacts/architecture.md - Reference PVC manifest (line ~1573)]
- [Source: docs/planning-artifacts/architecture.md - Repository Structure Addition (line ~1630)]
- [Source: docs/planning-artifacts/epics.md - Story 21.1 BDD (line ~5159)]
- [Source: docs/planning-artifacts/epics.md - Epic 21 Implementation Notes (line ~1068)]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.5 (claude-opus-4-5-20251101)

### Debug Log References

### Completion Notes List

- All 4 manifests created and applied: pvc.yaml, secret.yaml, deployment.yaml, service.yaml
- Gateway requires explicit startup command: `node dist/index.js gateway --bind lan --port 18789 --allow-unconfigured`
- Image renamed config dir from `.clawdbot` to `.moltbot` — mount path updated accordingly
- Gateway port is 18789 (not 3000 as architecture doc assumed) with bridge on 18790
- Added `CLAWDBOT_GATEWAY_TOKEN` to secrets (8th key, required for gateway auth)
- `--allow-unconfigured` flag needed for initial startup without moltbot.json
- Pod confirmed Running 1/1, NFS persistence verified across pod deletion
- Architecture doc references need updating for port and config path changes

### Change Log

- 2026-01-29: Tasks refined based on codebase gap analysis
- 2026-01-29: Implementation complete — all manifests created, applied, and validated

### File List

- `applications/moltbot/pvc.yaml` (new)
- `applications/moltbot/secret.yaml` (new, gitignored)
- `applications/moltbot/deployment.yaml` (new)
- `applications/moltbot/service.yaml` (new)
