# Story 10.1: Deploy Paperless-ngx with Redis Backend

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **platform engineer**,
I want **Paperless-ngx deployed with Redis for task queuing**,
so that **the document management system can process uploads and OCR tasks asynchronously**.

## Acceptance Criteria

**Given** cluster has `docs` namespace
**When** I deploy Paperless-ngx via gabe565 Helm chart
**Then** the following resources are created:
- Deployment: `paperless-ngx` (1 replica)
- Deployment: `redis` (1 replica for task queue)
- Service: `paperless-ngx` (port 8000)
- Service: `redis` (port 6379)

**Given** Paperless-ngx is deployed
**When** I check Helm values configuration
**Then** the chart uses:
- Image: `ghcr.io/paperless-ngx/paperless-ngx:latest`
- Redis connection: `redis://redis:6379`
- Environment variables set for PAPERLESS_URL, PAPERLESS_SECRET_KEY

**Given** pods are running
**When** I execute `kubectl get pods -n docs`
**Then** both `paperless-ngx-*` and `redis-*` pods show status Running
**And** this validates FR55 (deploy Paperless-ngx with Redis)

## Tasks / Subtasks

⚠️ **DRAFT TASKS** - Generated from requirements analysis. Will be validated and refined against actual codebase when dev-story runs.

- [x] **Task 1:** Create namespace and Helm repository (AC: 1)
  - [x] Create `docs` namespace: `kubectl create namespace docs`
  - [x] Add gabe565 Helm repository: `helm repo add gabe565 https://charts.gabe565.com`
  - [x] Update Helm repo: `helm repo update`

- [x] **Task 2:** Create Helm values file (AC: 2)
  - [x] Create `applications/paperless/values-homelab.yaml`
  - [x] Configure image: `ghcr.io/paperless-ngx/paperless-ngx:latest`
  - [x] Configure Redis connection: `redis://paperless-ngx-redis-master:6379`
  - [x] Set PAPERLESS_URL environment variable: `https://paperless.home.jetzinger.com`
  - [x] Generate and set PAPERLESS_SECRET_KEY (placeholder - TODO: sealed-secrets)
  - [x] Follow naming convention: `{app}-{component}` pattern
  - [x] Add Kubernetes recommended labels per architecture standards

- [x] **Task 3:** Deploy Paperless-ngx via Helm (AC: 1, 2, 3)
  - [x] Deploy standalone Redis (Bitnami subchart had image pull issues)
  - [x] Run Helm install:
    ```bash
    kubectl apply -f applications/paperless/redis.yaml
    helm upgrade --install paperless gabe565/paperless-ngx \
      -f applications/paperless/values-homelab.yaml \
      -n docs
    ```
  - [x] Verify deployment creates both paperless-ngx and redis pods
  - [x] Verify services are created (paperless-ngx:8000, redis:6379)

- [x] **Task 4:** Validate deployment (AC: 3)
  - [x] Run `kubectl get pods -n docs`
  - [x] Verify `paperless-ngx-*` pod status: Running
  - [x] Verify `redis-*` pod status: Running
  - [x] Check pod logs for startup errors (clean logs)
  - [x] Verify Redis connection from Paperless-ngx pod (Celery connected successfully)

## Gap Analysis

**Scan Date:** 2026-01-08

### Codebase Reality Check

✅ **What Exists:**
- Kubernetes cluster operational (10 namespaces: apps, data, default, dev, infra, kube-node-lease, kube-public, kube-system, metallb-system, ml, monitoring)
- Existing Helm repos: bitnami, community-charts, prometheus-community, ollama-helm, jetstack, metallb, grafana, nfs-subdir-external-provisioner
- Established pattern: `applications/{app}/values-homelab.yaml` for all apps (ollama, postgres, n8n)

❌ **What's Missing:**
- `docs` namespace (needs creation as per Task 1)
- `gabe565` Helm repository (needs adding as per Task 1)
- `applications/paperless/` directory and `values-homelab.yaml` file (Task 2)

### Task Validation

**NO CHANGES NEEDED** - Draft tasks accurately reflect current codebase state:
- ✅ Task 1: Create `docs` namespace and add gabe565 Helm repo (both missing, creation required)
- ✅ Task 2: Create `applications/paperless/values-homelab.yaml` (follows established project pattern)
- ✅ Task 3: Deploy via Helm (standard deployment process)
- ✅ Task 4: Validate deployment (verification step)

**Conclusion:** All draft tasks are implementation-ready. No refinement required.

---

## Dev Notes

### Architecture Requirements

**Deployment Strategy:** [Source: docs/planning-artifacts/architecture.md#Document Management Architecture]
- Use gabe565 community Helm chart (production-ready)
- Deploy to `docs` namespace
- Redis backend bundled with chart (simpler than external)
- PostgreSQL database connection (existing cluster PostgreSQL - deferred to Story 10.2+)

**Ingress Pattern:** [Source: docs/planning-artifacts/architecture.md#Namespace Boundaries]
- Domain: `paperless.home.jetzinger.com`
- HTTPS via cert-manager (automatic TLS)
- Traefik IngressRoute pattern

**Resource Naming:** [Source: docs/planning-artifacts/architecture.md#Implementation Patterns]
- Pattern: `{app}-{component}` (e.g., `paperless-ngx`, `redis`)
- Kubernetes recommended labels:
  ```yaml
  labels:
    app.kubernetes.io/name: paperless-ngx
    app.kubernetes.io/instance: paperless
    app.kubernetes.io/part-of: home-lab
    app.kubernetes.io/managed-by: helm
  ```

**Namespace Organization:** [Source: docs/planning-artifacts/architecture.md#Namespace Boundaries]
- Namespace: `docs`
- Purpose: Document management
- Components: Paperless-ngx, Redis

### Technical Constraints

**Storage:** [Source: docs/planning-artifacts/epics.md#Epic 10]
- Document storage via NFS PVC (deferred to Story 10.3)
- This story focuses on deployment only, not persistence

**OCR Configuration:** [Source: docs/planning-artifacts/epics.md#Epic 10]
- OCR language support (German + English) deferred to Story 10.2
- This story deploys base Paperless-ngx without OCR customization

**Database Backend:** [Source: docs/planning-artifacts/architecture.md#Document Management Architecture]
- PostgreSQL backend recommended for NFR29 (5,000+ docs scaling)
- Initial deployment may use bundled SQLite, PostgreSQL migration deferred

### Project Structure Notes

**File Locations:** [Source: docs/planning-artifacts/architecture.md#Project Structure]
```
applications/
├── paperless/
│   ├── values-homelab.yaml        # Paperless-ngx Helm config
│   ├── ingress.yaml               # paperless.home.jetzinger.com (Story 10.4)
│   └── pvc.yaml                   # Document storage PVC (Story 10.3)
```

**Deployment Pattern:** [Source: docs/planning-artifacts/architecture.md#Implementation Patterns]
- Helm-based deployment (consistent with other apps)
- Values file pattern: `values-homelab.yaml`
- No inline `--set` flags in production deployments

### Testing Requirements

**Validation Checklist:**
1. Namespace `docs` exists
2. Pods running: `paperless-ngx-*` and `redis-*`
3. Services accessible: `paperless-ngx:8000`, `redis:6379`
4. Redis connectivity from Paperless-ngx pod
5. No startup errors in pod logs

**Follow-up Stories:**
- Story 10.2: OCR configuration (German + English)
- Story 10.3: NFS persistent storage
- Story 10.4: HTTPS ingress configuration
- Story 10.5: End-to-end workflow validation

### Git Intelligence

**Recent Work Patterns:**
- Commit `7ef13de`: Added Phase 2 epics and stories (this story's planning)
- Commit `6aaf982`: Grafana screenshot optimization (monitoring pattern)
- Commit `54c7cba`: Visual documentation updates (portfolio work)

**Established Patterns:**
- All Helm deployments use `values-homelab.yaml` files
- Documentation includes screenshots and validation evidence
- Consistent namespace organization (`kube-system`, `infra`, `monitoring`, `data`, `apps`, `ml`, `docs`)

### References

- [Epic 10 Overview: docs/planning-artifacts/epics.md#Epic 10]
- [Architecture: Document Management: docs/planning-artifacts/architecture.md#Document Management Architecture]
- [Namespace Strategy: docs/planning-artifacts/architecture.md#Namespace Boundaries]
- [Implementation Patterns: docs/planning-artifacts/architecture.md#Implementation Patterns]
- [Functional Requirements: FR55, FR56, FR57, FR58, FR64, FR65: docs/planning-artifacts/prd.md]
- [Non-Functional Requirements: NFR28, NFR29, NFR30: docs/planning-artifacts/prd.md]

## Dev Agent Record

### Agent Model Used

Claude Sonnet 4.5 (model ID: claude-sonnet-4-5-20250929)

### Debug Log References

No debug logs required - deployment successful on first attempt after addressing Redis image compatibility.

### Completion Notes List

**Implementation Summary:**
- Created `docs` namespace and added gabe565 Helm repository
- Created `applications/paperless/values-homelab.yaml` with production-ready configuration
- Deployed standalone Redis (redis:7-alpine) due to Bitnami subchart image pull issues
- Deployed Paperless-ngx via gabe565/paperless-ngx Helm chart
- Verified both pods running with successful Redis connectivity

**Key Decisions:**
1. **Standalone Redis over Bitnami subchart**: Bitnami Redis image tags (7.4.2-debian-12-r0, 7.4.1-debian-12-r0, 8.4.0-debian-12-r4, 7.2) were not available on Docker Hub, causing ImagePullBackOff errors. Deployed lightweight official Redis image (redis:7-alpine) via standalone manifest instead.
2. **Redis auth disabled**: Simplified configuration for private cluster environment (Tailscale VPN only)
3. **Ephemeral Redis storage**: Task queue doesn't require persistence (no critical data)
4. **Secrets management**: Follows established project pattern - real credentials in `secrets/paperless-secrets.yaml` (gitignored), placeholders in `values-homelab.yaml` (committed to git). Secret key generated via `openssl rand -base64 50`.

**Validation Results:**
- ✅ Pods: paperless-paperless-ngx-685cfd5d4f-mvhqw (Running), redis-65b6f6cb77-9v2kq (Running)
- ✅ Services: paperless-paperless-ngx (8000), redis (6379)
- ✅ Celery worker connected to Redis successfully
- ✅ No startup errors in logs

**Follow-up Tasks:**
- Story 10.2: Configure OCR with German and English support
- Story 10.3: Configure NFS persistent storage for documents
- Story 10.4: Configure HTTPS ingress (paperless.home.jetzinger.com)
- Future: Migrate to sealed-secrets for cluster-wide secret management (mentioned in architecture)

### File List

**New Files:**
- `applications/paperless/values-homelab.yaml` - Helm chart values for Paperless-ngx (with placeholder credentials)
- `applications/paperless/redis.yaml` - Standalone Redis deployment manifest
- `secrets/paperless-secrets.yaml` - Real credentials (gitignored, not committed)

**Modified Files:**
- `docs/implementation-artifacts/10-1-deploy-paperless-ngx-with-redis-backend.md` - Task completion, gap analysis, dev notes
- `docs/implementation-artifacts/sprint-status.yaml` - Story status: ready-for-dev → review
- `secrets/README.md` - Added Paperless-ngx to secrets documentation
- `secrets/TEMPLATE.yaml` - Added paperless-secrets.yaml template section
