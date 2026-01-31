# Story 21.1: Deploy OpenClaw Gateway with Local Persistent Storage

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **cluster operator**,
I want **to deploy the OpenClaw gateway container on K3s with local persistent storage on k3s-worker-01 for configuration and workspace data**,
So that **my AI assistant infrastructure is running and survives pod restarts without losing state**.

## Acceptance Criteria

1. **OpenClaw pod deploys successfully on k3s-worker-01** — The OpenClaw pod starts in the `apps` namespace using the official `openclaw/openclaw` image (Node.js >= 22) with a single replica Deployment, scheduled to k3s-worker-01 via node affinity (FR152a).

2. **Local PVC bound and mounted** — A 10Gi local PVC using `local-path` storage class (`openclaw-data`) is created with `ReadWriteOnce` access and mounted via subPath:
   - `~/.openclaw` (config) → subPath `openclaw`
   - `~/clawd/` (workspace) → subPath `clawd`

3. **K8s Secret created with placeholder values** — `openclaw-secrets` Secret in `apps` namespace contains placeholder values for all credential types:
   - `ANTHROPIC_OAUTH_TOKEN`
   - `TELEGRAM_BOT_TOKEN`
   - `WHATSAPP_CREDENTIALS`
   - `DISCORD_BOT_TOKEN`
   - `ELEVENLABS_API_KEY`
   - `EXA_API_KEY`
   - `LITELLM_FALLBACK_URL` (set to `http://litellm.ml.svc.cluster.local:4000/v1`)
   - `CLAWDBOT_GATEWAY_TOKEN` (required for gateway auth)

4. **Configuration persists on local storage** — The gateway configuration is stored at `~/.openclaw/` on the local PVC on k3s-worker-01.

5. **Velero backup includes PVC** — Velero cluster backups include the OpenClaw local PVC for disaster recovery (FR152b).

6. **Pod restart preserves state** — When the pod is deleted or k3s-worker-01 reboots, the replacement pod starts on k3s-worker-01 with all configuration and workspace data intact from local storage (NFR100). No manual re-configuration is required.

## Tasks / Subtasks

- [x] Task 1: Create `applications/openclaw/` directory structure (AC: #1)
  - [x] 1.1 Create directory `applications/openclaw/`

- [x] Task 2: Create Local PVC manifest (AC: #2)
  - [x] 2.1 Create `applications/openclaw/pvc.yaml` with 10Gi local PVC named `openclaw-data` in `apps` namespace
  - [x] 2.2 Set `storageClassName: local-path` (K3s default local storage provisioner)
  - [x] 2.3 Set `accessModes: [ReadWriteOnce]`
  - [x] 2.4 Apply standard labels: `app.kubernetes.io/name: openclaw`, `app.kubernetes.io/part-of: home-lab`, `app.kubernetes.io/managed-by: kubectl`

- [x] Task 3: Create K8s Secret manifest (AC: #3)
  - [x] 3.1 Create `applications/openclaw/secret.yaml` with placeholder values for all 8 credential types
  - [x] 3.2 Set `LITELLM_FALLBACK_URL` to `http://litellm.ml.svc.cluster.local:4000/v1`
  - [x] 3.3 Verify existing `.gitignore` patterns cover `secret.yaml` (`git check-ignore` confirmation)

- [x] Task 4: Create Deployment manifest with node affinity (AC: #1, #2, #4, #5)
  - [x] 4.1 Create `applications/openclaw/deployment.yaml` with `openclaw/openclaw:latest` image
  - [x] 4.2 Configure single replica, `apps` namespace
  - [x] 4.3 Add node affinity to schedule pod on k3s-worker-01 (FR152a):
    ```yaml
    affinity:
      nodeAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          nodeSelectorTerms:
            - matchExpressions:
                - key: kubernetes.io/hostname
                  operator: In
                  values:
                    - k3s-worker-01
    ```
  - [x] 4.4 Mount `openclaw-data` PVC with two subPath mounts:
    - `/home/node/.openclaw` → subPath `openclaw`
    - `/home/node/clawd` → subPath `clawd`
  - [x] 4.5 Reference `openclaw-secrets` via `envFrom.secretRef`
  - [x] 4.6 Expose container ports 18789 (gateway) and 18790 (bridge)
  - [x] 4.7 Apply standard labels
  - [x] 4.8 Set `RollingUpdate` strategy
  - [x] 4.9 Set gateway startup command: `node dist/index.js gateway --bind lan --port 18789 --allow-unconfigured`

- [x] Task 5: Create ClusterIP Service manifest (AC: #1)
  - [x] 5.1 Create `applications/openclaw/service.yaml` exposing ports 18789 (gateway) and 18790 (bridge)
  - [x] 5.2 Apply standard labels and selector `app.kubernetes.io/name: openclaw`

- [x] Task 6: Apply manifests and validate (AC: #1, #2, #3, #6)
  - [x] 6.1 Apply PVC, Secret, Deployment, Service to cluster
  - [x] 6.2 Verify pod starts successfully on k3s-worker-01 (check via `kubectl get pod -n apps -o wide`)
  - [x] 6.3 Verify PVC is bound with local-path storage class
  - [x] 6.4 Verify mount paths exist inside container (`.openclaw/` and `clawd/`)
  - [N/A] 6.5 Verify Velero includes PVC in backups - Velero not deployed (uses K3s etcd snapshots per Story 8.2)
  - [x] 6.6 Delete pod and verify replacement starts on k3s-worker-01 with config intact

## Gap Analysis

**Scan Date:** 2026-01-30 (Re-verified for fresh implementation)

**What Exists:**
- `applications/openclaw/` directory with documentation files (OAUTH-SETUP.md, PAIRING.md)
- `apps` namespace active and ready
- `local-path` storageClass available (K3s default provisioner, set as default class)
- k3s-worker-01 node Ready (192.168.2.21, Ubuntu 22.04 LTS)
- `.gitignore` correctly covers `secret.yaml` (verified via git check-ignore)
- LiteLLM service available at `http://litellm.ml.svc.cluster.local:4000/v1` (Epic 14)
- Infrastructure prerequisites complete (storage, namespace, nodes)

**What's Missing:**
- All K8s manifests: deployment.yaml, service.yaml, pvc.yaml, secret.yaml
- No openclaw pods, PVC, Secret, or Service deployed (clean slate)

**Architecture Changes from Previous Implementation:**
- Storage: NFS → local persistent storage on k3s-worker-01
- Node affinity: Added to pin pod to k3s-worker-01 (FR152a)
- Backup: Velero cluster backups now cover local PVC (FR152b)
- Rationale: Eliminate network complexity and corruption vectors experienced in first implementation

---

## Dev Notes

### Architecture Patterns & Constraints

- **Namespace:** `apps` (same as n8n, Open-WebUI)
- **Image:** `openclaw/openclaw:latest` — official Docker image, no custom build
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
- `/home/node/.clawdbot` — config directory (contains `openclaw.json`)
- `/home/node/clawd` — workspace directory (agent workspace, mcporter config, session data)

Both use subPath mounts from a single PVC `openclaw-data`:
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

- New directory: `applications/openclaw/` (does not exist yet)
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

Similar deployment in cluster: Open-WebUI (`applications/open-webui/`) uses Helm values, but OpenClaw uses raw YAML manifests. Closer pattern: dev-containers (raw YAML in `applications/dev-containers/`).

### References

- [Source: docs/planning-artifacts/architecture.md - OpenClaw Personal AI Assistant Architecture (line ~1368)]
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

**Re-implementation (2026-01-30):**
- ✅ All 4 manifests created and applied: pvc.yaml, secret.yaml, deployment.yaml, service.yaml
- ✅ Switched from NFS to local-path storage class on k3s-worker-01 (architecture change after NFS corruption)
- ✅ Node affinity configured to pin pod to k3s-worker-01 for local storage persistence
- ✅ Gateway token auto-generated (required for startup): `CLAWDBOT_GATEWAY_TOKEN`
- ✅ Pod running successfully on k3s-worker-01 (1/1 Ready)
- ✅ Local PVC bound (10Gi local-path storage)
- ✅ Mount paths verified: `/home/node/.openclaw` and `/home/node/clawd`
- ✅ Pod restart persistence validated (delete pod → replacement starts with config intact)
- ⚠️ AC#5 skipped: Velero not deployed (project uses K3s etcd snapshots per Story 8.2)
- 📝 Note: PVC data backup not currently covered (etcd snapshots only backup metadata)

### Change Log

- 2026-01-30: ✅ Implementation complete - all manifests applied, pod running on k3s-worker-01
- 2026-01-30: Renamed file from *-nfs-persistence.md to *-local-persistence.md (reflects actual implementation)
- 2026-01-30: Generated gateway token for CLAWDBOT_GATEWAY_TOKEN (required for auth)
- 2026-01-30: Re-implementation started after infrastructure reset (local storage migration)
- 2026-01-30: Gap analysis verified - clean slate confirmed, tasks approved
- 2026-01-29: Tasks refined based on codebase gap analysis
- 2026-01-29: Previous implementation completed (NFS-based, later removed due to corruption)

### File List

**Created:**
- `applications/openclaw/pvc.yaml` - PersistentVolumeClaim for local storage (10Gi)
- `applications/openclaw/secret.yaml` - K8s Secret with 8 credential types (gitignored)
- `applications/openclaw/deployment.yaml` - Deployment with node affinity to k3s-worker-01
- `applications/openclaw/service.yaml` - ClusterIP Service exposing ports 18789/18790

**Modified:**
- `docs/implementation-artifacts/21-1-deploy-openclaw-gateway-with-nfs-persistence.md` - Tasks marked complete, Gap Analysis updated, status in-progress→review
