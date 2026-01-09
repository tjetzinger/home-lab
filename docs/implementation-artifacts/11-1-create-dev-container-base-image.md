# Story 11.1: Create Dev Container Base Image

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **platform engineer**,
I want **a standardized dev container base image with all required tools**,
so that **new dev containers can be provisioned consistently**.

## Acceptance Criteria

1. **Given** I need a base image for dev containers
   **When** I create a Dockerfile
   **Then** it includes the following components:
   - Base: Ubuntu 22.04
   - SSH server (openssh-server)
   - Node.js 20.x with npm
   - Python 3.11 with pip
   - kubectl (latest stable)
   - helm 3
   - Claude Code CLI (`@anthropic-ai/claude-code`)
   - git, sudo, vim, curl
   - Non-root user `dev` with sudo privileges
   **And** this validates FR67 (single base image with all tools)

2. **Given** Dockerfile is created
   **When** I build the image
   **Then** the build completes without errors
   **And** image is tagged as `dev-container-base:latest`

3. **Given** image is built
   **When** I verify installed tools
   **Then** the following commands succeed:
   - `node --version` returns 20.x
   - `npm --version` returns compatible version
   - `python3 --version` returns 3.11.x
   - `pip3 --version` returns compatible version
   - `kubectl version --client` works
   - `helm version` works
   - `claude-code --version` works (or `claude --version`)
   - `git --version` works
   - `ssh -V` works

4. **Given** image is verified
   **When** I push to local registry or make available for cluster deployment
   **Then** the image is accessible for dev container deployments
   **And** NFR31 (90-second provisioning) is achievable with pre-built image

## Tasks / Subtasks

⚠️ **DRAFT TASKS** - Generated from requirements analysis. Will be validated and refined against actual codebase when dev-story runs.

- [x] **Task 1:** Create Dockerfile for dev container base image (AC: 1)
  - [x] Create `applications/dev-containers/base-image/Dockerfile`
  - [x] Use Ubuntu 22.04 as base
  - [x] Install openssh-server and configure SSH
  - [x] Install Node.js 20.x via NodeSource repository
  - [x] Install Python 3.11 with pip
  - [x] Install kubectl from official release
  - [x] Install helm 3 via official script
  - [x] Install Claude Code CLI via npm
  - [x] Install git, sudo, vim, curl utilities
  - [x] Create `dev` user with sudo NOPASSWD privileges
  - [x] Expose port 22 for SSH
  - [x] Set CMD to run sshd in foreground

- [x] **Task 2:** Build and test the image locally (AC: 2, 3)
  - [x] Build image: `docker build -t dev-container-base:latest .`
  - [x] Verify build completes without errors
  - [x] Run container and verify all tools work
  - [x] Test SSH connectivity into container
  - [x] Document image size and build time

- [x] **Task 3:** Create supporting Kubernetes manifests (AC: 4)
  - [x] Create `applications/dev-containers/ssh-configmap.yaml` template for SSH keys
  - [x] Create `applications/dev-containers/dev-container-template.yaml` as Deployment template
  - [x] Document how to use the template for new containers

- [x] **Task 4:** Document usage and update sprint status
  - [x] Add README to `applications/dev-containers/`
  - [x] Document build and deployment process
  - [x] Mark story as done in sprint-status.yaml

## Gap Analysis

**Scan Date:** 2026-01-09

### ✅ What Exists:
| Item | Location | Status |
|------|----------|--------|
| `dev` namespace | cluster | ✅ Operational (nginx proxy) |
| Nginx proxy | dev namespace | ✅ Running |
| NFS storage class | cluster | ✅ `nfs-client` available |
| Ingress infrastructure | cluster | ✅ Traefik + cert-manager |

### ❌ What's Missing (To Be Created):
| Item | Required Action |
|------|-----------------|
| `applications/dev-containers/` directory | CREATE |
| `base-image/Dockerfile` | CREATE |
| `ssh-configmap.yaml` template | CREATE |
| `dev-container-template.yaml` | CREATE |
| `README.md` documentation | CREATE |

**Task Changes:** None - draft tasks accurately reflect what needs to be created.

---

## Dev Notes

### Architecture Requirements

**Dev Containers Architecture:** [Source: docs/planning-artifacts/architecture.md#Dev Containers Architecture]
- Container Base: Ubuntu 22.04 with Node.js, Python, Claude Code CLI, git, kubectl, helm (FR67)
- Access Method: SSH via Nginx proxy
- Workspace Storage: Hybrid - Git repos on NFS PVC (10GB), build artifacts on emptyDir (FR69)
- Resource Limits: 2 CPU cores, 4GB RAM per container (FR68)
- NetworkPolicy: Access cluster services, no cross-container communication (NFR33)

**Base Image Components:**
```dockerfile
# FR67: Single base image with standard tools
FROM ubuntu:22.04
- openssh-server (SSH access)
- Node.js 20.x + npm
- Python 3.11 + pip
- kubectl (latest stable)
- helm 3
- Claude Code CLI (@anthropic-ai/claude-code)
- git, sudo, vim, curl
- Non-root `dev` user with sudo NOPASSWD
```

**Directory Structure (from Architecture):**
```
applications/dev-containers/
├── base-image/
│   └── Dockerfile             # Dev container base image
├── dev-container-template.yaml # Template for new containers
├── ssh-configmap.yaml         # SSH authorized_keys
└── nginx-stream-config.yaml   # Nginx TCP/SSH routing (Story 11.4)
```

### Technical Constraints

**Namespace:** `dev` (same as nginx proxy)
**Storage:** NFS PVC (10GB) for workspace, emptyDir for builds
**Network:** NetworkPolicy isolation (Story 11.5)
**Resources:** 2 CPU cores, 4GB RAM per container (FR68)

### Previous Story Intelligence

**From Epic 10 Stories:**
- Raw Kubernetes manifests work well for custom deployments
- Label pattern: `app.kubernetes.io/name`, `app.kubernetes.io/instance`, `app.kubernetes.io/part-of`
- NFS storage provisioner reliable for PVCs

**Recent Commit Patterns:**
- Story-based commits with clear descriptions
- Manifests stored in `applications/{app}/` directories
- README documentation for each component

### Project Structure Notes

**New Directory:** `applications/dev-containers/`
- Follows existing pattern: `applications/{app}/`
- Will contain Dockerfile, templates, and configs

**Naming Conventions:**
- Image: `dev-container-base:latest`
- Deployments: `dev-container-{name}` (e.g., `dev-container-belego`)
- Services: `dev-container-{name}-svc`
- PVCs: `dev-workspace-{name}`

**Label Pattern:**
```yaml
labels:
  app.kubernetes.io/name: dev-container
  app.kubernetes.io/instance: dev-container-{name}
  app.kubernetes.io/component: development
  app.kubernetes.io/part-of: home-lab
```

### Testing Requirements

**Validation Checklist:**
1. [ ] Dockerfile created with all required components
2. [ ] Image builds successfully
3. [ ] All tools verified working in container
4. [ ] SSH access working
5. [ ] Template manifests created
6. [ ] Documentation complete

**Test Commands:**
```bash
# Build image
cd applications/dev-containers/base-image
docker build -t dev-container-base:latest .

# Test container
docker run -d --name test-dev dev-container-base:latest
docker exec -it test-dev node --version
docker exec -it test-dev python3 --version
docker exec -it test-dev kubectl version --client
docker exec -it test-dev helm version
docker exec -it test-dev claude --version  # or claude-code --version
docker exec -it test-dev git --version

# Cleanup
docker stop test-dev && docker rm test-dev
```

### References

- [Epic 11: Dev Containers Platform](../planning-artifacts/epics.md#epic-11)
- [Dev Containers Architecture](../planning-artifacts/architecture.md#dev-containers-architecture)
- [FR67: Single base image with all tools](../planning-artifacts/prd.md)
- [FR68: 2 CPU cores, 4GB RAM per container](../planning-artifacts/prd.md)
- [FR69: Persistent 10GB volumes](../planning-artifacts/prd.md)
- [NFR31: 90-second provisioning](../planning-artifacts/prd.md)
- [Claude Code CLI](https://www.npmjs.com/package/@anthropic-ai/claude-code)

## Dev Agent Record

### Agent Model Used

Claude Opus 4.5 (claude-opus-4-5-20251101)

### Debug Log References

N/A

### Completion Notes List

- Dockerfile created with Ubuntu 22.04 base and all required tools
- Image builds successfully (1.02GB size)
- All tools verified:
  - Node.js v20.19.6
  - npm 10.8.2
  - Python 3.11.0rc1
  - pip 22.0.2
  - kubectl v1.35.0
  - helm v3.19.4
  - Claude Code CLI 2.1.2
  - git 2.34.1
  - OpenSSH 8.9p1
- SSH server runs correctly in foreground
- Kubernetes manifests created (template-based approach)
- README documentation complete

### File List

- `applications/dev-containers/base-image/Dockerfile` - Base image definition
- `applications/dev-containers/ssh-configmap.yaml` - SSH keys ConfigMap template
- `applications/dev-containers/dev-container-template.yaml` - Deployment/Service/PVC template
- `applications/dev-containers/README.md` - Documentation

