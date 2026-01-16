# Story 19.2: Configure Gitea Storage and Ingress

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **developer**,
I want **Gitea repositories persisted to NFS and accessible via HTTPS**,
So that **my code is safely stored and accessible from anywhere**.

## Acceptance Criteria

1. **Given** Gitea is deployed
   **When** I configure persistent storage
   **Then** repositories are stored on NFS volume
   **And** data survives pod restarts
   **And** this validates FR136

2. **Given** storage is configured
   **When** I create ingress resource
   **Then** ingress routes `git.home.jetzinger.com` to Gitea service
   **And** TLS certificate is provisioned via cert-manager
   **And** this validates FR135

3. **Given** ingress is configured
   **When** I access `https://git.home.jetzinger.com`
   **Then** Gitea interface loads with valid HTTPS
   **And** repository operations work via HTTPS

## Tasks / Subtasks

⚠️ **DRAFT TASKS** - Generated from requirements analysis. Will be validated and refined against actual codebase when dev-story runs.

### Task 1: Verify NFS Persistent Storage (AC: 1, FR136)
- [x] 1.1: Verify existing PVC `gitea-shared-storage` is bound
- [x] 1.2: Verify PVC uses `nfs-client` storage class
- [x] 1.3: Test data persistence by deleting and recreating pod
- [x] 1.4: Verify repository data survives restart

### Task 2: Create Ingress for Gitea Web Interface (AC: 2, FR135)
- [x] 2.1: Create `applications/gitea/ingressroute.yaml`
- [x] 2.2: Configure Certificate for `git.home.jetzinger.com` via cert-manager
- [x] 2.3: Configure HTTPS IngressRoute pointing to `gitea-http` service on port 3000
- [x] 2.4: Configure HTTP to HTTPS redirect IngressRoute
- [x] 2.5: Apply ingress resources to cluster

### Task 3: Verify HTTPS Access and TLS (AC: 2, 3)
- [x] 3.1: Wait for certificate to be provisioned
- [x] 3.2: Test HTTPS access to `https://git.home.jetzinger.com`
- [x] 3.3: Verify TLS certificate is valid
- [x] 3.4: Test HTTP redirect to HTTPS

### Task 4: Test Repository Operations (AC: 3)
- [x] 4.1: Create test repository via API
- [x] 4.2: Clone repository via HTTPS
- [x] 4.3: Push changes via HTTPS
- [x] 4.4: Verify clone completes within reasonable time (0.6s)

### Task 5: Documentation (AC: all)
- [x] 5.1: Update `applications/gitea/README.md` with ingress access
- [x] 5.2: Document HTTPS URL and certificate details
- [x] 5.3: Update story file with completion notes

## Gap Analysis

**Scan Date:** 2026-01-15

✅ **What Existed:**
- PVC `gitea-shared-storage` bound with nfs-client storage class (10Gi)
- Gitea pod running in dev namespace
- Services: gitea-http (3000), gitea-ssh (22)

❌ **What Was Missing:**
- No `applications/gitea/ingressroute.yaml`
- No TLS certificate for git.home.jetzinger.com
- No https-redirect middleware in dev namespace

**Task Changes:** None - draft tasks accurately reflected codebase state.

---

## Dev Notes

### Technical Requirements

**FR135: Gitea accessible via ingress at `git.home.jetzinger.com` with HTTPS**
- Traefik IngressRoute pattern (same as Open-WebUI, LiteLLM, Dashboard)
- cert-manager with ClusterIssuer `letsencrypt-prod`
- DNS-01 challenge via Cloudflare

**FR136: Gitea persists repositories and data to NFS storage**
- Already configured in Story 19.1 via `persistence.enabled: true`
- PVC: `gitea-shared-storage` with `nfs-client` storage class
- Size: 10Gi (can be expanded later if needed)

### Existing Infrastructure Context

**From Story 19.1:**
- Gitea deployed in `dev` namespace
- HTTP Service: `gitea-http.dev.svc.cluster.local:3000`
- SSH Service: `gitea-ssh.dev.svc.cluster.local:22`
- Persistence already enabled with NFS storage class
- Admin credentials: admin / gitea-admin-2026

**IngressRoute Pattern (from similar deployments):**

```yaml
# Pattern from applications/open-webui/ingressroute.yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: gitea-tls
  namespace: dev
spec:
  secretName: gitea-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
    - git.home.jetzinger.com
---
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: gitea-https
  namespace: dev
spec:
  entryPoints:
    - websecure
  routes:
    - kind: Rule
      match: Host(`git.home.jetzinger.com`)
      services:
        - name: gitea-http
          port: 3000
  tls:
    secretName: gitea-tls
```

### Previous Story Intelligence

**From Story 19.1:**
- Gitea deployed successfully with PostgreSQL backend
- Web interface load time: 0.247s (NFR80 < 3 seconds met)
- valkey-cluster disabled for simpler setup
- Memory-based caching configured
- Persistence already enabled via Helm values

### Architecture Compliance

**Namespace:** `dev` (development tools)
**Ingress Pattern:** Traefik IngressRoute with cert-manager TLS
**Storage Pattern:** NFS-backed PVC via `nfs-client` storage class
**Labels:** Standard `app.kubernetes.io/part-of: home-lab`

### Project Context Reference

- [Source: docs/planning-artifacts/epics.md#Story 19.2, lines 4652-4684]
- [Source: docs/planning-artifacts/prd.md#FR135, FR136]
- [Source: docs/planning-artifacts/architecture.md#Gitea Architecture]
- [Source: applications/open-webui/ingressroute.yaml - IngressRoute pattern]
- [Source: applications/gitea/values-homelab.yaml - Current Gitea config]
- [Source: docs/implementation-artifacts/19-1-deploy-gitea-with-postgresql-backend.md - Previous story]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.5 (claude-opus-4-5-20251101)

### Debug Log References

- PVC verification: `gitea-shared-storage` bound, 10Gi, nfs-client storage class
- Certificate provisioning: DNS-01 challenge completed in ~90 seconds
- Web interface load time: 0.199s (NFR80 < 3 seconds)
- Git clone time: 0.6s (NFR79 < 10 seconds)
- Data persistence verified across pod restart

### Completion Notes List

1. **NFS Persistent Storage** (Task 1):
   - PVC `gitea-shared-storage` verified as Bound (10Gi, nfs-client)
   - Created test repository, verified data persisted across pod restart
   - Repository data stored at `/data/git/gitea-repositories/`

2. **Ingress Configuration** (Task 2):
   - Created `applications/gitea/ingressroute.yaml` with:
     - Certificate for `git.home.jetzinger.com` via letsencrypt-prod ClusterIssuer
     - HTTPS IngressRoute pointing to gitea-http:3000
     - HTTP to HTTPS redirect via https-redirect middleware
   - Certificate issued by Let's Encrypt R13, valid until Apr 15, 2026

3. **HTTPS Verification** (Task 3):
   - HTTPS access returns 200 OK
   - HTTP redirects to HTTPS (308 Permanent Redirect)
   - TLS certificate valid and trusted

4. **Repository Operations** (Task 4):
   - Clone via HTTPS: 0.6s (NFR79 < 10 seconds)
   - Push via HTTPS: Working correctly
   - API access requires authentication (as expected)

5. **Resources Created:**
   - Certificate: `gitea-tls` in dev namespace
   - Middleware: `https-redirect` in dev namespace
   - IngressRoute: `gitea-ingress` (HTTPS)
   - IngressRoute: `gitea-ingress-redirect` (HTTP redirect)

### File List

| File | Action |
|------|--------|
| `applications/gitea/ingressroute.yaml` | Created |
| `applications/gitea/README.md` | Updated |

### Change Log

- 2026-01-15: Story 19.2 completed - HTTPS ingress configured (Claude Opus 4.5)
- 2026-01-15: Story 19.2 created - Configure Gitea Storage and Ingress (Claude Opus 4.5)
