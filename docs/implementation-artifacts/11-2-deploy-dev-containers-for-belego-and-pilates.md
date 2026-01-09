# Story 11.2: Deploy Dev Containers for Belego and Pilates

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **developer**,
I want **two dev containers deployed (one for Belego, one for Pilates projects)**,
so that **I can develop both projects in isolated environments**.

## Acceptance Criteria

1. **Given** base image exists
   **When** I deploy dev container for Belego
   **Then** the following resources are created in `dev` namespace:
   - Deployment: `dev-container-belego` (1 replica)
   - Service: `dev-container-belego-svc` (port 22 for SSH)
   - Resources: 2 CPU cores, 4GB RAM (FR68)

2. **Given** Belego container is deployed
   **When** I deploy dev container for Pilates
   **Then** the following resources are created:
   - Deployment: `dev-container-pilates` (1 replica)
   - Service: `dev-container-pilates-svc` (port 22 for SSH)
   - Resources: 2 CPU cores, 4GB RAM

3. **Given** both containers are running
   **When** I execute `kubectl get pods -n dev`
   **Then** both `dev-container-belego-*` and `dev-container-pilates-*` show status Running
   **And** each pod has SSH server listening on port 22

4. **Given** I verify resource allocation
   **When** I check pod resource requests
   **Then** cluster allocates 4 CPU cores and 8GB RAM total
   **And** resources are within cluster capacity (k3s-worker nodes have sufficient resources)

## Tasks / Subtasks

⚠️ **DRAFT TASKS** - Generated from requirements analysis. Will be validated and refined against actual codebase when dev-story runs.

- [x] **Task 1:** Create SSH ConfigMaps for both containers (AC: 1, 2)
  - [x] Create `dev-container-belego-ssh` ConfigMap with SSH public key
  - [x] Create `dev-container-pilates-ssh` ConfigMap with SSH public key
  - [x] Apply ConfigMaps to `dev` namespace

- [x] **Task 2:** Deploy Belego dev container (AC: 1)
  - [x] Copy `dev-container-template.yaml` to `dev-container-belego.yaml`
  - [x] Replace INSTANCE with `belego` throughout
  - [x] Apply deployment to `dev` namespace
  - [x] Verify pod reaches Running state
  - [x] Verify SSH service is accessible

- [x] **Task 3:** Deploy Pilates dev container (AC: 2)
  - [x] Copy `dev-container-template.yaml` to `dev-container-pilates.yaml`
  - [x] Replace INSTANCE with `pilates` throughout
  - [x] Apply deployment to `dev` namespace
  - [x] Verify pod reaches Running state
  - [x] Verify SSH service is accessible

- [x] **Task 4:** Validate both containers (AC: 3, 4)
  - [x] Verify both pods are Running
  - [x] Verify SSH connectivity to both containers
  - [x] Verify resource allocation (4 CPU, 8GB RAM total)
  - [x] Test tool availability (node, python, kubectl, helm, claude)

- [x] **Task 5:** Documentation and sprint status update
  - [x] Document deployment process in README
  - [x] Update sprint-status.yaml to mark story done

## Gap Analysis

**Scan Date:** 2026-01-09

### ✅ What Exists:
| Item | Location | Status |
|------|----------|--------|
| `dev` namespace | cluster | ✅ Operational |
| Base image | `applications/dev-containers/base-image/Dockerfile` | ✅ Created (Story 11.1) |
| Template | `applications/dev-containers/dev-container-template.yaml` | ✅ Created (Story 11.1) |
| SSH ConfigMap template | `applications/dev-containers/ssh-configmap.yaml` | ✅ Created (Story 11.1) |
| NFS storage class | cluster | ✅ `nfs-client` available |

### ❌ What's Missing (To Be Created):
| Item | Required Action |
|------|-----------------|
| `dev-container-belego-ssh` ConfigMap | CREATE with SSH key |
| `dev-container-pilates-ssh` ConfigMap | CREATE with SSH key |
| `dev-container-belego.yaml` manifest | CREATE from template |
| `dev-container-pilates.yaml` manifest | CREATE from template |
| PVCs for workspaces | AUTO-CREATED by manifests |

**Task Changes:** None - draft tasks accurately reflect what needs to be created.

---

## Dev Notes

### Architecture Requirements

**Dev Containers Architecture:** [Source: docs/planning-artifacts/architecture.md#Dev Containers Architecture]
- Container Base: Ubuntu 22.04 with Node.js, Python, Claude Code CLI, git, kubectl, helm (FR67)
- Access Method: SSH via Nginx proxy (Story 11.4)
- Workspace Storage: Hybrid - Git repos on NFS PVC (10GB), build artifacts on emptyDir (FR69)
- Resource Limits: 2 CPU cores, 4GB RAM per container (FR68)
- NetworkPolicy: Access cluster services, no cross-container communication (NFR33) - Story 11.5

**Resource Capacity:**
- Cluster supports 2-3 dev containers simultaneously
- k3s-worker-01: 8GB RAM → 1-2 containers
- k3s-worker-02: Similar capacity → 1 container

### Technical Constraints

**Namespace:** `dev` (same as nginx proxy)
**Storage:** NFS PVC (10GB) for workspace, emptyDir for builds
**Network:** NetworkPolicy isolation (configured in Story 11.5)
**Resources:** 2 CPU cores, 4GB RAM per container (FR68)
**Image:** `dev-container-base:latest` (built in Story 11.1)

### Previous Story Intelligence

**From Story 11.1:**
- Base image created: `dev-container-base:latest` (1.02GB)
- All tools verified working:
  - Node.js v20.19.6, npm 10.8.2
  - Python 3.11.0rc1, pip 22.0.2
  - kubectl v1.35.0, helm v3.19.4
  - Claude Code CLI 2.1.2
  - git 2.34.1, OpenSSH 8.9p1
- Template manifests created for deployments
- SSH server configured for key-based auth only

**Label Pattern (from Story 11.1):**
```yaml
labels:
  app.kubernetes.io/name: dev-container
  app.kubernetes.io/instance: dev-container-{name}
  app.kubernetes.io/component: development
  app.kubernetes.io/part-of: home-lab
```

**Naming Conventions:**
- Deployments: `dev-container-{name}` (e.g., `dev-container-belego`)
- Services: `dev-container-{name}-svc`
- PVCs: `dev-workspace-{name}`
- ConfigMaps: `dev-container-{name}-ssh`

### Project Structure Notes

**Directory:** `applications/dev-containers/`
- `base-image/Dockerfile` - Base image (exists)
- `dev-container-template.yaml` - Template (exists)
- `ssh-configmap.yaml` - Template (exists)
- `dev-container-belego.yaml` - To be created
- `dev-container-pilates.yaml` - To be created

### Testing Requirements

**Validation Checklist:**
1. [x] Both pods Running in `dev` namespace
2. [x] SSH connectivity verified for both containers
3. [x] Tool verification in both containers
4. [x] Resource allocation within cluster capacity
5. [x] PVCs bound and mounted correctly

**Test Commands:**
```bash
# Verify pods
kubectl get pods -n dev -l app.kubernetes.io/name=dev-container

# Verify services
kubectl get svc -n dev -l app.kubernetes.io/name=dev-container

# Verify PVCs
kubectl get pvc -n dev

# Test SSH via port-forward (temporary, until nginx proxy configured)
kubectl port-forward svc/dev-container-belego-svc 2222:22 -n dev
ssh -p 2222 dev@localhost

# Verify tools in container
kubectl exec -it deployment/dev-container-belego -n dev -- node --version
kubectl exec -it deployment/dev-container-belego -n dev -- python3 --version
kubectl exec -it deployment/dev-container-belego -n dev -- claude --version
```

### References

- [Epic 11: Dev Containers Platform](../planning-artifacts/epics.md#epic-11)
- [Story 11.1: Create Dev Container Base Image](./11-1-create-dev-container-base-image.md)
- [Dev Containers Architecture](../planning-artifacts/architecture.md#dev-containers-architecture)
- [FR68: 2 CPU cores, 4GB RAM per container](../planning-artifacts/prd.md)
- [FR69: Persistent 10GB volumes](../planning-artifacts/prd.md)

## Dev Agent Record

### Agent Model Used

Claude Opus 4.5 (claude-opus-4-5-20251101)

### Debug Log References

N/A

### Completion Notes List

- Created SSH ConfigMaps for both containers using user's ed25519 public key
- Built dev-container-base:latest image and distributed to worker nodes via containerd import
- Deployed Belego dev container: Deployment, Service, PVC all created successfully
- Deployed Pilates dev container: Deployment, Service, PVC all created successfully
- Both pods running on k3s-worker-02
- All tools verified in both containers:
  - Node.js v20.19.6
  - Python 3.11.0rc1
  - kubectl v1.35.0
  - helm v3.19.4
  - Claude Code CLI 2.1.2
- Resource allocation: 2 CPU cores, 4GB RAM limit per container (4 CPU, 8GB total)
- PVCs: 10GB NFS storage each, bound successfully
- SSH server running and listening on port 22 in both containers

### File List

- `applications/dev-containers/dev-container-belego-ssh.yaml` - Belego SSH ConfigMap
- `applications/dev-containers/dev-container-pilates-ssh.yaml` - Pilates SSH ConfigMap
- `applications/dev-containers/dev-container-belego.yaml` - Belego deployment manifest
- `applications/dev-containers/dev-container-pilates.yaml` - Pilates deployment manifest

