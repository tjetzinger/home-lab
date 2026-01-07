# Story 6.1: Deploy Ollama for LLM Inference

Status: done

## Story

As a **cluster operator**,
I want **to deploy Ollama for running LLM inference**,
So that **I can serve AI models from my home cluster**.

## Acceptance Criteria

1. **Given** cluster has NFS storage and ingress configured
   **When** I create the `ml` namespace
   **Then** the namespace is created with appropriate labels

2. **Given** the ml namespace exists
   **When** I deploy Ollama via Helm with `values-homelab.yaml`
   **Then** the Ollama deployment is created in the ml namespace
   **And** the Ollama pod starts successfully

3. **Given** Ollama pod is running
   **When** I configure an NFS-backed PVC for model storage
   **Then** the PVC is bound to Ollama at `/root/.ollama`
   **And** downloaded models persist across pod restarts

4. **Given** Ollama is deployed with persistent storage
   **When** I create an IngressRoute for ollama.home.jetzinger.com with TLS
   **Then** Ollama API is accessible via HTTPS
   **And** this validates FR36 (deploy Ollama for LLM inference)

5. **Given** Ollama is accessible
   **When** I exec into the pod and run `ollama pull llama3.2:1b`
   **Then** the model downloads and is stored on NFS
   **And** subsequent pod restarts don't require re-downloading

## Tasks / Subtasks

⚠️ **DRAFT TASKS** - Generated from requirements analysis. Will be validated and refined against actual codebase when dev-story runs.

### Task 1: Create ml Namespace (AC: 1)
- [x] 1.1: Check if ml namespace already exists
- [x] 1.2: Create ml namespace with kubectl
- [x] 1.3: Apply Kubernetes recommended labels to namespace
- [x] 1.4: Verify namespace creation

### Task 2: Create Ollama Helm Values Configuration (AC: 2)
- [x] 2.1: Create applications/ollama/ directory structure
- [x] 2.2: Create values-homelab.yaml with Ollama configuration
- [x] 2.3: Configure resource requests and limits per architecture
- [x] 2.4: Configure service type as ClusterIP (internal access)
- [x] 2.5: Set Ollama environment variables if needed

### Task 3: Configure NFS-Backed Persistent Storage (AC: 3)
- [x] 3.1: Define PVC specification in values-homelab.yaml
- [x] 3.2: Set storageClassName to nfs-client
- [x] 3.3: Request appropriate storage size for models (e.g., 50Gi)
- [x] 3.4: Mount PVC at /root/.ollama (Ollama's default model directory)
- [x] 3.5: Verify PVC binding before deployment

### Task 4: Deploy Ollama via Helm (AC: 2, 3)
- [x] 4.1: Add Ollama Helm repository (otwld/ollama-helm)
- [x] 4.2: Update Helm repo cache
- [x] 4.3: Deploy Ollama to ml namespace using values-homelab.yaml
- [x] 4.4: Wait for pod to reach Running state
- [x] 4.5: Verify PVC is mounted correctly inside pod

### Task 5: Create Ingress for HTTPS Access (AC: 4)
- [x] 5.1: Create ingress.yaml for Ollama
- [x] 5.2: Configure IngressRoute for ollama.home.jetzinger.com
- [x] 5.3: Enable TLS with cert-manager ClusterIssuer
- [x] 5.4: Apply ingress configuration
- [x] 5.5: Verify cert-manager provisions certificate
- [x] 5.6: Test HTTPS access from browser or curl

### Task 6: Download and Test Model Persistence (AC: 5)
- [x] 6.1: Exec into Ollama pod
- [x] 6.2: Run `ollama pull llama3.2:1b` to download model
- [x] 6.3: Verify model files are written to /root/.ollama
- [x] 6.4: Delete the Ollama pod (kubectl delete pod)
- [x] 6.5: Wait for Deployment to recreate pod
- [x] 6.6: Exec into new pod and verify model still exists (ollama list)
- [x] 6.7: Confirm model was NOT re-downloaded (persistence validated)

### Task 7: Validate FR36 and Document Deployment
- [x] 7.1: Verify FR36 (deploy Ollama for LLM inference) is satisfied
- [x] 7.2: Document deployment details in applications/ollama/README.md
- [x] 7.3: Test API accessibility via curl to /api/tags endpoint
- [x] 7.4: DNS already configured via home network (ollama.home.jetzinger.com resolves)
- [x] 7.5: Verify all acceptance criteria are met

## Gap Analysis

**Scan Date:** 2026-01-06

### What Exists:

**Infrastructure:**
- ✅ NFS StorageClass: nfs-client (default) - Dynamic provisioning operational
- ✅ cert-manager ClusterIssuer: letsencrypt-prod - TLS automation ready
- ✅ Traefik ingress controller: Deployed (Epic 3)
- ✅ MetalLB LoadBalancer: Deployed (Epic 3)
- ✅ Reference pattern: applications/postgres/values-homelab.yaml

### What's Missing:

- ❌ ml namespace does not exist (needs creation)
- ❌ applications/ollama/ directory does not exist
- ❌ Ollama Helm repository not added
- ❌ No Ollama deployment exists
- ❌ No ingress for ollama.home.jetzinger.com
- ❌ No model storage configured

### Task Changes Applied:

**NO CHANGES NEEDED** - Draft tasks accurately reflect current codebase state. All tasks address missing components that need to be created.

---

## Dev Notes

### Technical Requirements

**Source:** [docs/planning-artifacts/epics.md#Story 6.1]

**Ollama Deployment Strategy:**
- Deploy as Deployment (not StatefulSet) for flexibility per architecture decision
- Use official Ollama Helm chart (ollama/ollama)
- CPU-only inference for MVP (GPU support deferred to Phase 2)
- Models stored on NFS-backed PVC for persistence across pod restarts

**Model Storage Pattern:**
- Ollama default model directory: `/root/.ollama`
- NFS PVC mounted at this path ensures model persistence
- Downloaded models survive pod deletion, worker node failures
- Estimated storage: Start with 50Gi (expandable via PVC resize)

**API Access:**
- Internal: `ollama.ml.svc.cluster.local:11434`
- External: `https://ollama.home.jetzinger.com` via Traefik ingress
- TLS via cert-manager with Let's Encrypt production issuer

**Initial Model:**
- llama3.2:1b selected for testing (small, fast for CPU inference)
- Downloaded via `ollama pull` command inside running pod
- Model persists on NFS, validation = no re-download after pod restart

### Architecture Compliance

**Source:** [docs/planning-artifacts/architecture.md#AI/ML Architecture]

**Technology Stack:**
- **LLM Inference:** Ollama Helm chart (official)
- **GPU Support:** Deferred to Phase 2 (CPU for MVP)
- **Model Storage:** NFS PVC via nfs-client StorageClass

**Namespace Boundaries:**
- **ml namespace:** AI/ML workloads (Ollama)
- Separation from apps, data, monitoring per architecture

**Naming Compliance:**
- Ingress: `ollama.home.jetzinger.com` (subdomain pattern)
- K8s resources: `ollama-{component}` naming
- Labels: Kubernetes recommended labels (app.kubernetes.io/*)

**Storage Architecture:**
- **StorageClass:** nfs-client (default, dynamic provisioning)
- **NFS Path:** `/volume1/k8s-data/ml-ollama-models-pvc-{uid}/`
- **Reclaim Policy:** Delete (cleanup on PVC deletion)
- **Access Mode:** ReadWriteOnce (RWO) - single pod mount

**Network Architecture:**
- **Service Type:** ClusterIP (internal cluster access)
- **Ingress:** Traefik IngressRoute with TLS
- **Service Discovery:** `ollama.ml.svc.cluster.local:11434`
- **External Access:** HTTPS via ollama.home.jetzinger.com (Tailscale only)

### Library/Framework Requirements

**Ollama Helm Chart:**
- Chart Repository: https://ollama.github.io/ollama-helm/
- Chart Name: ollama/ollama
- Version: Latest stable (check at deployment time)

**Dependencies:**
- NFS provisioner (nfs-subdir-external-provisioner) - Already deployed (Epic 2)
- Traefik ingress controller - Already deployed (Epic 3)
- cert-manager for TLS - Already deployed (Epic 3)
- MetalLB for LoadBalancer - Already deployed (Epic 3)

**No additional dependencies required** - all prerequisites completed in Epics 1-5.

### File Structure Requirements

**Source:** [docs/planning-artifacts/architecture.md#Project Structure]

**New Files to Create:**
```
applications/ollama/
├── values-homelab.yaml          # Helm chart values
├── ingress.yaml                 # ollama.home.jetzinger.com IngressRoute
└── README.md                    # Deployment documentation
```

**Helm Values Content:**
- Resource requests/limits
- PVC configuration (size, storageClass)
- Service configuration (ClusterIP, port 11434)
- Environment variables (if needed)
- Ollama-specific settings

**Ingress Configuration:**
- IngressRoute custom resource (Traefik)
- Host: ollama.home.jetzinger.com
- TLS enabled with cert-manager annotation
- Routes to ollama service on port 11434

**README Content:**
- Deployment instructions
- Model management commands
- API usage examples
- Troubleshooting guide

### Testing Requirements

**Deployment Validation:**
1. Namespace exists with correct labels
2. Helm release deployed successfully to ml namespace
3. Ollama pod reaches Running state (1/1 containers ready)
4. PVC bound and mounted at /root/.ollama
5. Service created and endpoints populated

**Storage Validation:**
1. Model download completes successfully (ollama pull)
2. Model files visible in /root/.ollama directory
3. Pod deletion → recreation → model still present (no re-download)
4. NFS backend has model files at expected path

**API Validation:**
1. Internal service accessible: curl http://ollama.ml.svc.cluster.local:11434/api/tags
2. External HTTPS works: curl https://ollama.home.jetzinger.com/api/tags
3. Certificate is valid (issued by Let's Encrypt)
4. API returns list of available models

**Functional Requirements Validation:**
- FR36: Operator can deploy Ollama for LLM inference ✓

**NFR Validation:**
- NFR13: Ollama response time < 30 seconds (will be validated in Story 6.2)
- NFR8: Models persist across pod restarts (validated via delete/recreate test)

### Previous Story Intelligence

**Source:** Deployment patterns from Epics 1-5

**Successful Patterns from Previous Epics:**

**Epic 2 (Storage):** NFS Persistence Pattern
- Pattern: Create PVC with nfs-client StorageClass, mount in pod
- Learning: Always verify PVC binding before deploying application
- Application: Apply same pattern for Ollama model storage

**Epic 3 (Ingress/TLS):** HTTPS Ingress Pattern
- Pattern: IngressRoute with TLS annotation, cert-manager auto-provision
- Learning: Use ClusterIssuer letsencrypt-production for valid certs
- Application: Use same pattern for ollama.home.jetzinger.com

**Epic 4 (Observability):** Helm Deployment Pattern
- Pattern: Create values-homelab.yaml, deploy with `helm upgrade --install`
- Learning: All config in values file, no --set flags
- Application: Use same pattern for Ollama Helm deployment

**Epic 5 (PostgreSQL):** Namespace Setup Pattern
- Pattern: Create namespace with labels, deploy resources to namespace
- Learning: Apply app.kubernetes.io/* labels for consistency
- Application: Use same pattern for ml namespace

**Consistent File Structure:**
- All applications have values-homelab.yaml for Helm config
- All applications have README.md for documentation
- Ingress definitions kept separate from values files

**Resource Allocation Pattern:**
- Conservative CPU/memory requests (start small, scale up if needed)
- CPU limits set to allow bursting
- Example from PostgreSQL: 100m CPU request, 500m limit

### Project Context Reference

**Source:** [CLAUDE.md, docs/FOLDER_DOCUMENTATION.md]

**Repository Guidelines:**
- All manifests version controlled in Git
- Helm values in values-homelab.yaml (no inline --set)
- Documentation in runbooks for operational procedures
- ADRs for architectural decisions (not needed for standard deployments)

**Cluster Context:**
- K3s cluster with 1 control plane (k3s-master) + 2 workers
- All services internal via ClusterIP, external via Traefik ingress
- Tailscale VPN only access (no public internet exposure)
- NFS storage from Synology DS920+ (192.168.2.2)

**Naming Conventions:**
- Namespace: ml (already defined in architecture)
- Service: ollama (matches component name)
- Ingress: ollama.home.jetzinger.com (subdomain pattern)
- PVC: ollama-models or auto-generated by Helm

**Development Workflow:**
1. Create story file with requirements (this file)
2. Run dev-story workflow to implement with gap analysis
3. Run code-review workflow when implementation complete
4. Mark story as done, proceed to next story

**Epic 6 Context:**
- Story 6.1: Deploy Ollama (this story)
- Story 6.2: Test Ollama API and model inference
- Story 6.3: Deploy n8n for workflow automation
- Story 6.4: Validate scaling and log access

---

## Dev Agent Record

### Agent Model Used

Claude Sonnet 4.5 (claude-sonnet-4-5-20250929)

### Debug Log References

No debugging required - implementation successful on first attempt after correcting Helm chart values structure.

### Completion Notes List

**Implementation Highlights:**
1. Successfully deployed Ollama using otwld/ollama-helm chart (v1.36.0)
2. Corrected values file structure to match chart's expected format (persistentVolume vs persistence)
3. NFS-backed PVC (50Gi) bound successfully with dynamic provisioning
4. HTTPS ingress configured with Let's Encrypt TLS automation
5. Model persistence validated - llama3.2:1b (1.3GB) survives pod restarts
6. All 5 acceptance criteria met, FR36 validated

**Key Decisions:**
- Chart source: otwld/ollama-helm (533 stars, verified publisher) - more mature than alternative charts
- Model choice: llama3.2:1b for testing - small enough for CPU inference, validates storage pattern
- Update strategy: Recreate (not RollingUpdate) - appropriate for single-replica deployment
- Resource limits: Conservative (500m/2Gi requests, 4CPU/8Gi limits) - allows bursting for inference

**Challenges Resolved:**
- Initial values file used wrong field names (persistence vs persistentVolume) - corrected by reading chart defaults
- Old pod stuck terminating after upgrade - resolved with force delete and manual scaling
- Certificate provisioning took ~2 minutes - expected behavior for Let's Encrypt ACME challenge

### File List

**Created:**
- `applications/ollama/values-homelab.yaml` - Helm chart configuration (114 lines)
- `applications/ollama/ingress.yaml` - IngressRoute + Certificate resources (97 lines)
- `applications/ollama/README.md` - Deployment documentation (335 lines)

**Modified:**
- `docs/implementation-artifacts/6-1-deploy-ollama-for-llm-inference.md` - Story status updated to review, all tasks marked complete
- `docs/implementation-artifacts/sprint-status.yaml` - Story status updated to review (pending)

**Kubernetes Resources Created:**
- Namespace: `ml` (with labels)
- Deployment: `ollama` (1 replica)
- Service: `ollama` (ClusterIP, port 11434)
- PVC: `ollama` (50Gi, nfs-client, Bound)
- IngressRoute: `ollama-ingress` (HTTPS), `ollama-ingress-redirect` (HTTP→HTTPS)
- Certificate: `ollama-tls` (Let's Encrypt)
- Middleware: `https-redirect` (ml namespace)

---

### Change Log

- 2026-01-06: Story created with requirements analysis and draft implementation tasks
- 2026-01-06: Gap analysis verified - no task changes needed, all infrastructure prerequisites validated
- 2026-01-06: Implementation completed - All 7 tasks completed, all 5 acceptance criteria met, FR36 validated, story ready for review
- 2026-01-06: Story marked as done - Ollama deployment validated and operational
