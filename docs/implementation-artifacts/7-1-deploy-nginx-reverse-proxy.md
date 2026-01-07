# Story 7.1: Deploy Nginx Reverse Proxy

Status: done

## Story

As a **cluster operator**,
I want **to deploy Nginx as a reverse proxy to local development servers**,
So that **I can access my dev machines through the cluster**.

## Acceptance Criteria

1. **Given** cluster has ingress and TLS configured
   **When** I verify the `dev` namespace exists
   **Then** the namespace is present (created in Story 3.5)

2. **Given** the dev namespace exists
   **When** I create a ConfigMap with initial proxy configuration
   **Then** the ConfigMap contains nginx.conf with upstream definitions
   **And** the ConfigMap is saved at `applications/nginx/configmap.yaml`

3. **Given** the ConfigMap exists
   **When** I deploy Nginx with the ConfigMap mounted
   **Then** the Nginx deployment is created in the dev namespace
   **And** the Nginx pod starts successfully
   **And** the deployment manifest is saved at `applications/nginx/deployment.yaml`

4. **Given** Nginx pod is running
   **When** I check the nginx configuration inside the pod
   **Then** the proxy configuration from ConfigMap is loaded
   **And** this validates FR41 (configure Nginx to proxy to local dev servers)

5. **Given** Nginx is deployed
   **When** I create a Service of type ClusterIP for Nginx
   **Then** the Service exposes port 80
   **And** the Service is accessible within the cluster

## Tasks / Subtasks

⚠️ **DRAFT TASKS** - Validated and refined by dev-story gap analysis (2026-01-06). Task 1 removed (namespace already exists).

### Task 2: Create Nginx ConfigMap with Proxy Configuration (AC: 2)
- [x] 2.1: Create `applications/nginx/` directory if it doesn't exist
- [x] 2.2: Create `applications/nginx/configmap.yaml` manifest
- [x] 2.3: Add metadata with labels (app.kubernetes.io/name: nginx, app.kubernetes.io/instance: nginx-proxy)
- [x] 2.4: Define nginx.conf with basic server block listening on port 80
- [x] 2.5: Add upstream definition placeholder for future dev servers (e.g., `upstream dev-server { server localhost:3000; }`)
- [x] 2.6: Add location block routing / to default nginx welcome page
- [x] 2.7: Add comment indicating proxy targets will be added in Story 7.2
- [x] 2.8: Apply ConfigMap with `kubectl apply -f applications/nginx/configmap.yaml`
- [x] 2.9: Verify ConfigMap exists with `kubectl get configmap -n dev`

### Task 3: Create Nginx Deployment (AC: 3)
- [x] 3.1: Create `applications/nginx/deployment.yaml` manifest
- [x] 3.2: Set deployment name: nginx-proxy, namespace: dev
- [x] 3.3: Add Kubernetes recommended labels matching ConfigMap
- [x] 3.4: Set replicas: 1 (no HA needed for dev proxy)
- [x] 3.5: Use nginx:1.27-alpine image (matches test-deployment.yaml pattern)
- [x] 3.6: Configure volume mount: ConfigMap → /etc/nginx/nginx.conf
- [x] 3.7: Set resource requests: 50m CPU, 64Mi memory (match test-deployment.yaml)
- [x] 3.8: Set resource limits: 100m CPU, 128Mi memory
- [x] 3.9: Add readiness probe: HTTP GET /health on port 80
- [x] 3.10: Add liveness probe: HTTP GET /health on port 80
- [x] 3.11: Apply deployment with `kubectl apply -f applications/nginx/deployment.yaml`
- [x] 3.12: Wait for pod to reach Running state with `kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=nginx -n dev --timeout=2m`

### Task 4: Verify Nginx Configuration Loaded (AC: 4)
- [x] 4.1: Get pod name with `kubectl get pods -n dev -l app.kubernetes.io/name=nginx`
- [x] 4.2: Exec into pod: `kubectl exec -n dev <pod-name> -- cat /etc/nginx/nginx.conf`
- [x] 4.3: Verify nginx.conf matches ConfigMap content
- [x] 4.4: Check nginx syntax with `kubectl exec -n dev <pod-name> -- nginx -t`
- [x] 4.5: Verify nginx process is running with `kubectl exec -n dev <pod-name> -- ps aux | grep nginx`
- [x] 4.6: Test nginx responds with `kubectl exec -n dev <pod-name> -- curl localhost:80/health`
- [x] 4.7: Document FR41 validation in completion notes

### Task 5: Create ClusterIP Service (AC: 5)
- [x] 5.1: Create `applications/nginx/service.yaml` manifest (separate file)
- [x] 5.2: Set service name: nginx-proxy, namespace: dev
- [x] 5.3: Set service type: ClusterIP
- [x] 5.4: Add Kubernetes recommended labels matching deployment
- [x] 5.5: Configure selector: app.kubernetes.io/name: nginx, app.kubernetes.io/instance: nginx-proxy
- [x] 5.6: Expose port 80 with name: http
- [x] 5.7: Apply service with `kubectl apply -f applications/nginx/service.yaml`
- [x] 5.8: Verify service exists with `kubectl get svc -n dev nginx-proxy`
- [x] 5.9: Get ClusterIP with `kubectl get svc -n dev nginx-proxy -o jsonpath='{.spec.clusterIP}'` → 10.43.16.27
- [x] 5.10: Test service accessibility from hello-nginx pod with `curl http://nginx-proxy.dev.svc.cluster.local/health`

### Task 6: Document Deployment
- [x] 6.1: Create `applications/nginx/README.md` (comprehensive documentation)
- [x] 6.2: Document purpose: Reverse proxy for accessing local dev servers
- [x] 6.3: Document deployment procedure (ConfigMap, deployment, service)
- [x] 6.4: Document how to verify deployment (pod status, config check, service test)
- [x] 6.5: Add note that ingress configuration is deferred to Story 7.2
- [x] 6.6: Add note that hot-reload configuration is deferred to Story 7.3
- [x] 6.7: Document basic architecture: Nginx → ConfigMap-based config → ClusterIP service
- [x] 6.8: Include references to Story 7.2 and 7.3 for next steps

## Gap Analysis

**Executed:** 2026-01-06 (dev-story Step 1.5)

### Codebase Scan Results

**What Exists:**
- ✅ Dev namespace (`dev`) - Already created in Story 3.5 (Active status)
- ✅ `applications/nginx/` directory with test files from Story 3.5:
  - `test-deployment.yaml` - Test nginx deployment (`hello-nginx`) with ClusterIP service
  - `test-ingress.yaml` - HTTPS ingress route for hello.home.jetzinger.com
- ✅ Running test deployment in dev namespace:
  - `deployment.apps/hello-nginx` - 1/1 ready
  - `service/hello-nginx` - ClusterIP on 10.43.233.221

**What's Missing:**
- ❌ Nginx proxy ConfigMap (`applications/nginx/configmap.yaml`)
- ❌ Nginx proxy deployment (`applications/nginx/deployment.yaml`) - separate from test deployment
- ❌ Nginx proxy service (`applications/nginx/service.yaml`) - separate from test service
- ❌ Documentation (`applications/nginx/README.md`)

### Task Refinements Applied

**REMOVED:**
- Task 1: Create Dev Namespace (6 subtasks) - Namespace already exists from Story 3.5

**KEPT AS-IS:**
- Task 2: Create Nginx ConfigMap (9 subtasks) - ConfigMap does not exist
- Task 3: Create Nginx Deployment (12 subtasks) - Can reference test-deployment.yaml patterns
- Task 4: Verify Nginx Configuration (7 subtasks) - Valid
- Task 5: Create ClusterIP Service (10 subtasks) - Can reference test-deployment.yaml service
- Task 6: Document Deployment (8 subtasks) - README does not exist

**Total Subtasks:** 46 subtasks → 40 subtasks (6 removed)

---

## Dev Notes

### Technical Requirements

**Source:** [docs/planning-artifacts/epics.md#Epic 7, Story 7.1]

**Story Context:**
- Part of Epic 7: Development Proxy (Stories 7.1-7.3)
- Purpose: Enable access to local development servers (e.g., frontend dev servers running on workstations) through cluster ingress
- Architecture pattern: Nginx reverse proxy with ConfigMap-based configuration for future hot-reload (Story 7.3)

**Functional Requirements:**
- **FR41:** Operator can configure Nginx to proxy to local dev servers
- **FR42:** Developer can access local dev servers via cluster ingress (Story 7.2)
- **FR43:** Operator can add/remove proxy targets without cluster restart (Story 7.3)

**Non-Functional Requirements:**
- **NFR7:** All ingress traffic uses TLS 1.2+ with valid certificates (deferred to Story 7.2)
- **NFR1:** Cluster operations use kubectl CLI (all tasks use kubectl)

**Deliverables:**
1. Dev namespace with appropriate labels
2. ConfigMap with nginx.conf containing upstream definitions
3. Nginx deployment in dev namespace
4. ClusterIP service exposing Nginx on port 80
5. Validation that proxy configuration is loaded

### Architecture Compliance

**Source:** [docs/planning-artifacts/architecture.md#Dev Container Decision, Namespace Boundaries]

**Dev Namespace Specification:**
- **Namespace:** `dev` - Development tools + remote dev environments
- **Purpose:** Nginx proxy, dev containers (Epic 10)
- **Isolation:** Separate from production namespaces (apps, ml, data, docs, monitoring, infra, kube-system)
- **Access Control:** Tailscale VPN only (no public API exposure)

**Nginx Proxy Architecture Pattern:**
- **Component:** Nginx reverse proxy (dev tooling)
- **Integration:** Nginx proxy routes SSH traffic to dev container pods (Epic 10)
- **Configuration Storage:** ConfigMaps (enables hot-reload in Story 7.3)
- **Service Type:** ClusterIP (internal cluster access, exposed via Traefik ingress in Story 7.2)
- **Storage:** No NFS required - ephemeral nginx config, local workspace storage for dev containers

**Implementation Sequence:**
- Priority: 9th in implementation sequence (after K3s, NFS, cert-manager, MetalLB, kube-prometheus-stack, Loki, PostgreSQL, Ollama)
- Status: All upstream dependencies complete ✅

**Upstream Dependencies (All Complete):**
- Story 1.1-1.4: K3s cluster setup ✅
- Story 2.1-2.4: NFS storage provisioner ✅
- Story 3.1: MetalLB ✅
- Story 3.2: Traefik ingress ✅
- Story 3.3: cert-manager ✅
- Story 3.4: DNS configuration ✅
- Story 3.5: HTTPS ingress validation ✅

**Downstream Dependencies:**
- Story 7.2: Configure Ingress for Dev Proxy Access (HTTPS + cert-manager)
- Story 7.3: Enable Hot-Reload Configuration (inotify or sidecar)
- Epic 10: Dev Containers (depends on Nginx proxy for SSH routing)

### Library/Framework Requirements

**Nginx Image:**
- **Version:** `nginx:1.27-alpine`
- **Variant:** Alpine (lightweight, security-focused)
- **Source:** Docker Hub official nginx image
- **Rationale:** Matches test-deployment.yaml pattern from Story 3.5

**Kubernetes API Versions:**
- Namespace: `v1`
- ConfigMap: `v1`
- Deployment: `apps/v1`
- Service: `v1`

**No additional dependencies required** - using standard Kubernetes resources and official nginx image.

### File Structure Requirements

**Source:** [docs/planning-artifacts/architecture.md#Project Structure]

**New Files to Create:**

```
applications/nginx/
├── configmap.yaml       # Nginx configuration with upstream definitions
├── deployment.yaml      # Nginx deployment in dev namespace
├── service.yaml         # ClusterIP service (or combined with deployment.yaml)
└── README.md            # Deployment documentation
```

**Existing Files (Reference Only):**
```
applications/nginx/
├── test-deployment.yaml # From Story 3.5 - hello-nginx test (keep for reference)
└── test-ingress.yaml    # From Story 3.5 - test ingress (keep for reference)
```

**File Naming Conventions:**
- All manifests use lowercase with hyphens
- ConfigMaps: `configmap.yaml` or `{service}-configmap.yaml`
- Deployments: `deployment.yaml` or `{service}-deployment.yaml`
- Services: `service.yaml` or `{service}-service.yaml`

**Kubernetes Recommended Labels (All Resources):**
```yaml
labels:
  app.kubernetes.io/name: nginx
  app.kubernetes.io/instance: nginx-proxy
  app.kubernetes.io/component: reverse-proxy
  app.kubernetes.io/part-of: home-lab
  app.kubernetes.io/managed-by: kubectl
```

### Testing Requirements

**Deployment Validation:**
1. Namespace created with correct labels
2. ConfigMap contains valid nginx.conf
3. Deployment creates pod successfully
4. Pod status: 1/1 Running, 0 restarts
5. Nginx config loaded from ConfigMap (verify with `cat /etc/nginx/nginx.conf`)
6. Nginx syntax valid (verify with `nginx -t`)
7. ClusterIP service created
8. Service accessible via internal DNS: `nginx-proxy.dev.svc.cluster.local`

**Functional Validation:**
- FR41: Nginx configured to proxy to local dev servers (validated by ConfigMap containing upstream definitions)

**Readiness Criteria:**
- All 5 acceptance criteria met
- All tasks completed and checked off
- README documentation complete
- Pod running and healthy
- Service accessible from within cluster

### Previous Story Intelligence

**Source:** [docs/implementation-artifacts/6-4-validate-scaling-and-log-access.md]

**Story 6.4 Learnings (Most Recent Complete Story):**

**Deployment Patterns:**
- Kubernetes operations validated: scaling, log viewing, event inspection
- kubectl commands used for all operations (aligns with NFR1)
- Operations documented in README for future reference
- Health check scripts useful for validation

**Important Discovery:**
- NFS-backed storage (RWO access mode) allows multi-node scaling
- RWO restrictions apply primarily to block storage (iSCSI, FC), not NFS
- This applies to dev containers (Epic 10) using local storage - no multi-node issues

**Documentation Patterns:**
- Operations section added after Monitoring section in README
- Includes: command examples, expected behavior, common patterns
- Troubleshooting section with common issues and solutions
- Example output snippets for validation

**Testing Patterns:**
- Validate pod status: `kubectl get pods -n {namespace}`
- Verify config: `kubectl exec` to inspect files
- Check logs: `kubectl logs` for startup and runtime messages
- Inspect events: `kubectl get events --sort-by=.lastTimestamp`

**Files Modified:**
- README.md updated with comprehensive Operations section
- Story file updated with gap analysis, completion notes, file list

**Conventions Established:**
- All kubectl commands include `-n {namespace}` flag explicitly
- Pod names follow pattern: `{deployment}-{replicaset-hash}-{pod-hash}`
- Health validation uses both kubectl checks and API endpoint tests (where applicable)
- README structure: Overview, Deployment, Access, Configuration, Operations, Troubleshooting

### Project Context Reference

**Source:** [CLAUDE.md, docs/FOLDER_DOCUMENTATION.md]

**Repository Guidelines:**
- All operations documented in README files or runbooks
- kubectl commands version controlled in documentation (not executed scripts)
- Troubleshooting patterns captured for future reference
- No inline `--set` flags or undocumented manual commands

**Cluster Context:**
- K3s cluster with 1 control plane (k3s-master) + 2 workers (k3s-worker-01, k3s-worker-02)
- Worker nodes: 4 CPU, 8GB RAM each (from architecture.md)
- Nginx will run on worker nodes (no node affinity configured)

**Naming Conventions:**
- Namespace: `dev` (Development tools)
- Deployment: `nginx-proxy`
- Service: `nginx-proxy`
- ConfigMap: `nginx-config` or similar
- Pod naming: `nginx-proxy-{replicaset}-{pod}` (auto-generated)

**Ingress Patterns (Story 7.2 Reference):**
- Domain pattern: `dev.home.jetzinger.com`
- DNS resolution: NextDNS rewrite → `192.168.2.100` (Traefik LoadBalancer IP)
- TLS provider: Let's Encrypt Production (ClusterIssuer: `letsencrypt-prod`)
- Certificate duration: 90 days, auto-renewal 30 days before expiry
- HTTP→HTTPS redirect via Traefik Middleware

**Resource Allocation Patterns (from test-deployment.yaml):**
```yaml
resources:
  requests:
    cpu: 50m
    memory: 64Mi
  limits:
    cpu: 100m
    memory: 128Mi
```

**ConfigMap Mount Pattern:**
```yaml
volumeMounts:
  - name: config
    mountPath: /etc/nginx/nginx.conf
    subPath: nginx.conf
volumes:
  - name: config
    configMap:
      name: nginx-config
```

**Operational Philosophy:**
- "Cattle not pets" - pods are disposable, configuration is declarative
- Validate operations via kubectl commands
- Document all operational procedures for portfolio demonstration
- Capture troubleshooting patterns for career showcase

**Epic 7 Context:**
- Story 7.1: Deploy Nginx Reverse Proxy ⏳ THIS STORY
- Story 7.2: Configure Ingress for Dev Proxy Access (backlog)
- Story 7.3: Enable Hot-Reload Configuration (backlog)

**Expected Challenges & Mitigations:**

**Challenge 1: ConfigMap Volume Mount**
- **Issue:** Nginx expects /etc/nginx/nginx.conf as the main config file
- **Solution:** Use subPath mount to mount specific key from ConfigMap
- **Validation:** Exec into pod and verify config with `nginx -t`

**Challenge 2: Default Nginx Config Conflicts**
- **Issue:** Official nginx image has default config that may conflict
- **Solution:** Replace entire /etc/nginx directory or use subPath for nginx.conf only
- **Mitigation:** Test config syntax before deployment

**Challenge 3: Placeholder Upstream**
- **Issue:** Story 7.1 creates ConfigMap but no actual proxy targets yet
- **Solution:** Use placeholder upstream (localhost:3000) with comment
- **Acceptable for MVP:** ConfigMap structure validated, actual targets added in Story 7.2

**Challenge 4: Service Accessibility Testing**
- **Issue:** ClusterIP service only accessible from within cluster
- **Solution:** Use temporary curl pod for testing: `kubectl run curl --image=curlimages/curl --rm -i -- curl http://nginx-proxy.dev.svc.cluster.local`
- **Alternative:** Wait for Story 7.2 ingress to test external access

---

## Dev Agent Record

### Agent Model Used

**Model:** Claude Sonnet 4.5 (claude-sonnet-4-5-20250929)
**Workflow:** dev-story (BMAD framework)
**Date:** 2026-01-06

### Debug Log References

No debug logs required - implementation completed without errors.

### Completion Notes List

**Implementation Summary:**

All acceptance criteria met and validated:
1. ✅ **AC1:** Dev namespace verified (existed from Story 3.5)
2. ✅ **AC2:** ConfigMap created with nginx.conf containing upstream placeholders
3. ✅ **AC3:** Nginx deployment created and pod running (1/1 Ready)
4. ✅ **AC4:** Nginx configuration loaded and validated (nginx -t successful)
5. ✅ **AC5:** ClusterIP service created and accessible (10.43.16.27)

**FR41 Validation:** ✅ Operator can configure Nginx to proxy to local dev servers
- ConfigMap-based configuration enables declarative upstream management
- Placeholder upstream created for Story 7.2 proxy target configuration
- Health endpoint `/health` responding correctly

**Key Implementation Details:**

1. **Gap Analysis Findings:**
   - Dev namespace already existed (created in Story 3.5)
   - Task 1 (Create Dev Namespace) removed - 6 subtasks eliminated
   - Total: 46 subtasks → 40 subtasks after gap analysis

2. **ConfigMap (`nginx-proxy-config`):**
   - Created in `applications/nginx/configmap.yaml`
   - Contains complete nginx.conf with placeholder upstream
   - Includes `/health` endpoint for liveness/readiness probes
   - Mounted at `/etc/nginx/nginx.conf` using subPath to preserve other nginx files

3. **Deployment (`nginx-proxy`):**
   - Image: `nginx:1.27-alpine` (matches test-deployment.yaml pattern)
   - Resources: 50m/100m CPU, 64Mi/128Mi memory
   - Probes: Readiness (3s delay) and Liveness (5s delay) on `/health` endpoint
   - Volume mount: ConfigMap → `/etc/nginx/nginx.conf` (subPath: nginx.conf, readOnly: true)
   - Pod name: `nginx-proxy-7775b75c68-wwklt` (1/1 Running, 0 restarts)

4. **Service (`nginx-proxy`):**
   - Type: ClusterIP
   - ClusterIP: 10.43.16.27 (assigned by Kubernetes)
   - Port: 80/TCP (name: http)
   - DNS: `nginx-proxy.dev.svc.cluster.local`
   - Accessibility verified from hello-nginx pod

5. **Verification Results:**
   - ✅ nginx.conf loaded from ConfigMap (verified with `cat /etc/nginx/nginx.conf`)
   - ✅ nginx syntax valid (nginx -t: "configuration file test is successful")
   - ✅ nginx process running (master + 4 worker processes)
   - ✅ Health endpoint responding: `curl localhost:80/health` → "healthy"
   - ✅ Service accessible via DNS: `curl http://nginx-proxy.dev.svc.cluster.local/health` → "healthy"

6. **Documentation:**
   - Comprehensive README.md created (180+ lines)
   - Includes: Overview, Components, Deployment, Verification, Configuration, Access, Operations, Troubleshooting
   - References to Story 7.2 (ingress) and Story 7.3 (hot-reload)
   - Architecture diagram and next steps documented

**Deferred to Future Stories:**
- Story 7.2: Ingress configuration for external HTTPS access (dev.home.jetzinger.com)
- Story 7.3: Hot-reload configuration without pod restart

**No Issues or Blockers Encountered**

### File List

**Files Created:**
- `applications/nginx/configmap.yaml` - Nginx ConfigMap with nginx.conf (76 lines)
- `applications/nginx/deployment.yaml` - Nginx deployment manifest (68 lines)
- `applications/nginx/service.yaml` - ClusterIP service manifest (24 lines)
- `applications/nginx/README.md` - Comprehensive documentation (279 lines)

**Files Modified:**
- `docs/implementation-artifacts/sprint-status.yaml` - Story 7-1 marked as "in-progress"
- `docs/implementation-artifacts/7-1-deploy-nginx-reverse-proxy.md` - Gap analysis, task completion, completion notes

**Files Referenced (Existing):**
- `applications/nginx/test-deployment.yaml` - Test deployment from Story 3.5 (kept for reference)
- `applications/nginx/test-ingress.yaml` - Test ingress from Story 3.5 (kept for reference)

**Kubernetes Resources Created:**
- ConfigMap: `nginx-proxy-config` (namespace: dev)
- Deployment: `nginx-proxy` (namespace: dev, 1 replica)
- Service: `nginx-proxy` (namespace: dev, ClusterIP: 10.43.16.27)
- Pod: `nginx-proxy-7775b75c68-wwklt` (namespace: dev, 1/1 Running)

---

### Change Log

- 2026-01-06 (create-story): Story created with requirements analysis, draft implementation tasks, and comprehensive dev context from Epic 6 stories and architecture analysis
- 2026-01-06 (dev-story): Gap analysis completed - Task 1 removed (namespace already exists from Story 3.5)
- 2026-01-06 (dev-story): Implementation completed - All 5 acceptance criteria met, FR41 validated
  - ConfigMap created with nginx.conf containing placeholder upstream
  - Deployment created (nginx:1.27-alpine, 1/1 Running)
  - Service created (ClusterIP: 10.43.16.27)
  - Comprehensive README documentation added
- 2026-01-06 (dev-story): Story marked as "review" - Ready for code review
- 2026-01-06: Story marked as "done" - User approved implementation
