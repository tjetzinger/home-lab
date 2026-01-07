# Story 7.3: Enable Hot-Reload Configuration

Status: ready-for-dev

## Story

As a **cluster operator**,
I want **to add or remove proxy targets without restarting the cluster or pods**,
So that **I can quickly update dev proxy routing**.

## Acceptance Criteria

1. **Given** Nginx is deployed with ConfigMap-based configuration
   **When** I update the ConfigMap with a new proxy target
   **Then** the ConfigMap is updated in the cluster

2. **Given** ConfigMap is updated
   **When** I send a reload signal to Nginx (via nginx -s reload or pod exec)
   **Then** Nginx reloads its configuration without restart
   **And** existing connections are not interrupted

3. **Given** manual reload works
   **When** I configure Nginx to watch for config changes (inotify or sidecar)
   **Then** configuration changes are detected automatically
   **And** Nginx reloads within 30 seconds of ConfigMap update
   **And** this validates FR43 (add/remove proxy targets without cluster restart)

4. **Given** hot-reload is working
   **When** I remove a proxy target from the ConfigMap
   **Then** the route stops working after reload
   **And** 404 is returned for the removed path

5. **Given** configuration is dynamic
   **When** I document the process in `applications/nginx/README.md`
   **Then** the documentation includes:
   - How to add a new proxy target
   - How to trigger reload (manual and automatic)
   - How to verify routing
   **And** examples are provided for common scenarios

## Tasks / Subtasks

⚠️ **DRAFT TASKS** - Generated from requirements analysis. Will be validated and refined against actual codebase when dev-story runs.

### Task 1: Validate Current ConfigMap Mount and Nginx Process Model (AC: 1, 2)
- [x] 1.1: Verify nginx deployment has ConfigMap mounted at `/etc/nginx/nginx.conf`
- [x] 1.2: Check ConfigMap mount is using `subPath: nginx.conf` pattern
- [x] 1.3: Verify nginx is running with master-worker process model (ps aux | grep nginx)
- [x] 1.4: Document current nginx.conf location and ConfigMap name (`nginx-proxy-config`)
- [x] 1.5: Test manual ConfigMap update propagation time (kubectl apply + watch file in pod)

### Task 2: Implement Manual Reload Mechanism (AC: 2)
- [x] 2.1: Document nginx reload command: `kubectl exec -n dev <pod> -- nginx -s reload`
- [x] 2.2: Test reload signal sends SIGHUP to master process (verify in logs)
- [x] 2.3: Verify old worker processes gracefully finish current requests
- [x] 2.4: Verify new worker processes spawn with updated configuration
- [x] 2.5: Test health endpoint remains responsive during reload
- [x] 2.6: Validate existing connections are not interrupted (run curl during reload)
- [x] 2.7: Add pre-reload validation: `kubectl exec -n dev <pod> -- nginx -t`

### Task 3: Create Reload Validation Script (AC: 2)
- [x] 3.1: Create shell script: `applications/nginx/reload-proxy.sh`
- [x] 3.2: Script validates ConfigMap syntax before applying (nginx -t in dry-run pod)
- [x] 3.3: Script applies ConfigMap update: `kubectl apply -f applications/nginx/configmap.yaml`
- [x] 3.4: Script waits for ConfigMap propagation (10-60 seconds polling)
- [x] 3.5: Script triggers reload: `kubectl exec ... -- nginx -s reload`
- [x] 3.6: Script validates health endpoint post-reload
- [x] 3.7: Script logs reload timestamp and result (success/failure)
- [x] 3.8: Make script executable and test end-to-end

### Task 4: Implement Automatic Reload Detection (AC: 3)
- [ ] 4.1: Choose implementation approach: inotify-based script OR sidecar container
- [ ] 4.2: If inotify approach: Install inotify-tools in nginx container (or init container)
- [ ] 4.3: Create file watcher script: monitor `/etc/nginx/nginx.conf` for changes
- [ ] 4.4: Watcher detects file modification (inotifywait -e modify)
- [ ] 4.5: Watcher waits for stable file state (5 seconds no writes)
- [ ] 4.6: Watcher validates config: `nginx -t` before reload
- [ ] 4.7: Watcher executes reload: `nginx -s reload` if validation passes
- [ ] 4.8: Watcher logs all reload events to stdout (for kubectl logs visibility)
- [ ] 4.9: Update deployment to start watcher in background (entrypoint wrapper)
- [ ] 4.10: Test automatic detection: update ConfigMap → verify reload within 30 seconds

### Task 5: Test Add Proxy Target Hot-Reload (AC: 3, 4)
- [ ] 5.1: Add new upstream block to ConfigMap: `upstream app3 { server 192.168.2.52:9000; }`
- [ ] 5.2: Add new location block: `location /app3 { proxy_pass http://app3; ... }`
- [ ] 5.3: Apply ConfigMap update
- [ ] 5.4: Trigger reload (manual or automatic)
- [ ] 5.5: Verify new route is accessible: `curl https://dev.home.jetzinger.com/app3`
- [ ] 5.6: Verify existing routes still work (/app1, /app2 unchanged)
- [ ] 5.7: Check nginx logs for upstream creation and location block activation

### Task 6: Test Remove Proxy Target Hot-Reload (AC: 4)
- [ ] 6.1: Remove upstream and location block from ConfigMap (e.g., app3)
- [ ] 6.2: Apply ConfigMap update
- [ ] 6.3: Trigger reload (manual or automatic)
- [ ] 6.4: Verify removed route returns 404: `curl https://dev.home.jetzinger.com/app3`
- [ ] 6.5: Verify existing routes still work (/app1, /app2 unchanged)
- [ ] 6.6: Check nginx logs for upstream removal

### Task 7: Validate FR43 - No Cluster/Pod Restart Required (AC: 3)
- [ ] 7.1: Capture nginx pod name and creation timestamp before test
- [ ] 7.2: Perform multiple ConfigMap updates with reloads (add/remove targets)
- [ ] 7.3: Verify pod name and creation timestamp unchanged throughout
- [ ] 7.4: Verify pod restart count remains 0 (kubectl get pod -o wide)
- [ ] 7.5: Verify no cluster-level operations required (no kubelet restarts, no node changes)
- [ ] 7.6: Document FR43 validation: "Proxy targets can be updated without cluster/pod restart" ✓

### Task 8: Update Documentation and Runbook (AC: 5)
- [ ] 8.1: Update `applications/nginx/README.md` with hot-reload section
- [ ] 8.2: Document manual reload procedure (step-by-step with commands)
- [ ] 8.3: Document automatic reload configuration (if implemented)
- [ ] 8.4: Add "Adding New Proxy Targets" section with hot-reload workflow
- [ ] 8.5: Add "Removing Proxy Targets" section with verification steps
- [ ] 8.6: Include troubleshooting section (reload fails, config errors, timing issues)
- [ ] 8.7: Add example scenarios: add target, remove target, modify target
- [ ] 8.8: Document ConfigMap propagation timing (~10-60 seconds)
- [ ] 8.9: Document reload trigger options (manual vs automatic)
- [ ] 8.10: Add validation commands (health check, route testing, log inspection)

## Gap Analysis

**Executed:** 2026-01-06 (dev-story Step 1.5)

### Codebase Scan Results

**What Exists:**
- ✅ Nginx deployment (`nginx-proxy`) running in `dev` namespace with 1 replica
- ✅ ConfigMap (`nginx-proxy-config`) with nginx.conf mounted at `/etc/nginx/nginx.conf`
- ✅ ConfigMap mount pattern: `subPath: nginx.conf`, `readOnly: true` (verified)
- ✅ Nginx master-worker process model confirmed (master PID 1, 4 worker processes)
- ✅ Pod running: `nginx-proxy-57b6946546-gmrdl`
- ✅ All Story 7.1/7.2 files present: configmap.yaml, deployment.yaml, service.yaml, ingress.yaml, README.md
- ✅ ConfigMap contains app1 (192.168.2.50:3000) and app2 (192.168.2.51:8080) upstreams from Story 7.2

**What's Missing:**
- ❌ No `reload-proxy.sh` script exists (Task 3 will create)
- ❌ No automatic reload mechanism implemented (Task 4 will implement)
- ❌ No inotify-tools in nginx container (Task 4 may add if automatic reload chosen)
- ❌ No hot-reload documentation in README.md (Task 8 will add)

### Task Refinements Applied

**NO CHANGES NEEDED** - Draft tasks accurately reflect current codebase state. All prerequisites from Story 7.1 and 7.2 are in place.

**Total Subtasks:** 60 subtasks across 8 tasks (no modifications)

---

## Dev Notes

### Technical Requirements

**Source:** [docs/planning-artifacts/epics.md#Epic 7, Story 7.3]

**Story Context:**
- Part of Epic 7: Development Proxy (Stories 7.1-7.3)
- Purpose: Enable hot-reload of nginx configuration without pod restarts
- Dependencies: Story 7.1 (nginx deployment), Story 7.2 (ingress configured)

**Functional Requirements:**
- **FR43:** Operator can add/remove proxy targets without cluster restart (PRIMARY)
- **FR41:** Operator can configure Nginx to proxy to local dev servers (dependency from Story 7.1)
- **FR42:** Developer can access local dev servers via cluster ingress (dependency from Story 7.2)

**Non-Functional Requirements:**
- **NFR1:** 95% uptime, automatic pod rescheduling - NO pod restarts for config-only changes
- **Performance:** ConfigMap update → nginx reload within 30 seconds maximum
- **Zero-downtime:** Existing connections must not be interrupted during reload

**Deliverables:**
1. Manual reload mechanism (nginx -s reload validation)
2. Automatic reload detection (inotify or sidecar-based)
3. Reload validation script (`applications/nginx/reload-proxy.sh`)
4. Updated documentation in README.md with hot-reload procedures
5. FR43 validation: ConfigMap updates applied without pod/cluster restart

### Architecture Compliance

**Source:** [docs/planning-artifacts/architecture.md#Kubernetes Patterns, Nginx Configuration]

**Nginx Process Model (MANDATORY):**
- Nginx runs with master-worker process model (master PID 1, multiple workers)
- Reload mechanism: `nginx -s reload` sends SIGHUP to master process
- Master spawns new workers with updated config, old workers gracefully finish requests
- **CRITICAL:** Reload does NOT restart pod - master process remains PID 1

**ConfigMap Mount Pattern (Established in Story 7.1):**
- ConfigMap: `nginx-proxy-config` in `dev` namespace
- Mounted at: `/etc/nginx/nginx.conf` using `subPath: nginx.conf`
- Mount mode: `readOnly: true` (configuration safety)
- Volume type: ConfigMap volume (not hostPath or secret)

**Kubernetes ConfigMap Update Behavior:**
- ConfigMap volumes are **eventually consistent** with kubelet polling
- Default propagation time: ~10-60 seconds (varies by kubelet sync period)
- File system mount lags behind ConfigMap update in etcd
- **Solution for hot-reload:** Implement pod-side file watcher (inotify) to detect changes

**Health Probe Integration:**
```yaml
readinessProbe:
  httpGet: /health
  periodSeconds: 5
livenessProbe:
  httpGet: /health
  periodSeconds: 10
```
- Probes validate nginx responsiveness after reload
- Readiness probe can detect config errors (probe fails if nginx can't serve)
- Reload must keep health endpoint responsive (zero-downtime requirement)

**Deployment Pattern Constraints:**
- Current replicas: 1 (single pod, no HA needed for dev proxy)
- **For hot-reload:** Single replica acceptable IF reload is graceful (preserves connections)
- **Alternative:** Could scale to 2+ replicas for rolling reload, but Story 7.3 focuses on graceful single-pod reload

### Library/Framework Requirements

**Nginx Version & Image:**
- **Image:** `nginx:1.27-alpine` (official, lightweight, Alpine Linux base)
- **Alpine tools:** Supports `inotify-tools` package for file watching
- **Nginx capabilities:** Supports `nginx -s reload` (graceful reload signal)

**Reload Mechanisms Available:**

| Mechanism | Command | Installation Required | Connection Impact |
|-----------|---------|----------------------|-------------------|
| **SIGHUP Signal** | `nginx -s reload` | None (built-in) | Graceful - connections preserved |
| **Pod Exec** | `kubectl exec pod -- nginx -s reload` | None (kubectl) | Graceful |
| **inotify Watcher** | `inotifywait -e modify /etc/nginx/nginx.conf` | `inotify-tools` package | Graceful (triggers reload) |
| **Sidecar Container** | Dedicated watcher container | Custom container image | Graceful (triggers reload) |

**Recommended Approach for Story 7.3:**
1. **Phase 1 (MVP):** Manual pod exec reload - validates AC 1, 2, 4
2. **Phase 2 (Automatic):** inotify-based watcher - validates AC 3 (30-second window)

**inotify-tools Installation (if using inotify approach):**
```bash
# In nginx:1.27-alpine container
apk add --no-cache inotify-tools
```
**Alternative:** Use custom Dockerfile extending nginx:1.27-alpine with inotify-tools pre-installed

**No new dependencies required** - all components already available in nginx:alpine image or via standard Alpine packages.

### File Structure Requirements

**Source:** [docs/planning-artifacts/architecture.md#Project Structure]

**Files to Create:**
```
applications/nginx/
└── reload-proxy.sh          # Shell script for manual/scripted reload (Task 3)
```

**Files to Modify:**
```
applications/nginx/
├── configmap.yaml           # Test ConfigMap updates (Tasks 5, 6)
├── deployment.yaml          # Add inotify watcher if automatic reload (Task 4)
└── README.md                # Document hot-reload procedures (Task 8)
```

**Files to Reference:**
- `applications/nginx/deployment.yaml` - Verify ConfigMap mount pattern
- `applications/nginx/configmap.yaml` - Test target for reload validation
- `applications/nginx/README.md` - Update with hot-reload documentation

**Naming Conventions:**
- Script: `reload-proxy.sh` (follows existing pattern: install-master.sh, etc.)
- ConfigMap: `nginx-proxy-config` (existing, from Story 7.1)
- Deployment: `nginx-proxy` (existing, from Story 7.1)

### Testing Requirements

**Source:** [Story 7.1 Completion Notes, Story 7.3 Acceptance Criteria]

**Validation Framework (Existing from Story 7.1):**
```bash
# 1. Configuration syntax validation
kubectl exec -n dev <pod> -- nginx -t
# Expected: "configuration file test is successful"

# 2. Health endpoint validation
kubectl exec -n dev deployment/nginx-proxy -- curl -s http://localhost/health
# Expected: "healthy"

# 3. Process verification
kubectl exec -n dev <pod> -- ps aux | grep nginx
# Expected: master (PID 1) + worker processes
```

**Hot-Reload Specific Tests:**

**Test 1: Manual Reload (AC 2)**
```bash
# Add new upstream to configmap.yaml
# Apply: kubectl apply -f applications/nginx/configmap.yaml
# Wait for propagation (~30s)
# Reload: kubectl exec -n dev <pod> -- nginx -s reload
# Verify: curl https://dev.home.jetzinger.com/new-route
# Expected: New route accessible, existing routes unchanged
```

**Test 2: Connection Preservation (AC 2)**
```bash
# Start long-running request: curl -s https://dev.home.jetzinger.com/app1 &
# Trigger reload: kubectl exec -n dev <pod> -- nginx -s reload
# Verify: Long-running request completes successfully without error
# Expected: No connection interruption, no 5xx errors
```

**Test 3: Automatic Reload Timing (AC 3)**
```bash
# Timestamp start: date +%s
# Update ConfigMap: kubectl apply -f applications/nginx/configmap.yaml
# Watch logs: kubectl logs -n dev -l app=nginx-proxy -f
# Wait for reload log entry
# Timestamp end: date +%s
# Calculate: end - start
# Expected: Reload within 30 seconds of ConfigMap update
```

**Test 4: Route Removal (AC 4)**
```bash
# Remove upstream and location block from configmap.yaml
# Apply and reload
# Test removed route: curl -I https://dev.home.jetzinger.com/removed-route
# Expected: HTTP 404 Not Found
```

**Test 5: FR43 Validation (AC 3)**
```bash
# Capture pod creation time: kubectl get pod -n dev nginx-proxy-xxx -o jsonpath='{.status.startTime}'
# Perform 5 ConfigMap updates with reloads
# Check pod creation time again
# Expected: Creation time unchanged, pod not restarted
```

### Previous Story Intelligence

**Source:** [docs/implementation-artifacts/7-2-configure-ingress-for-dev-proxy-access.md#Dev Agent Record]

**Story 7.2 Learnings (Configure Ingress for Dev Proxy Access):**

**What Worked Well:**
1. **ConfigMap Pattern Success** - ConfigMap-based nginx.conf worked perfectly
   - No syntax errors, clean validation with `nginx -t`
   - All proxy headers (Host, X-Real-IP, X-Forwarded-For, X-Forwarded-Proto) properly configured
   - Multiple upstreams (app1, app2) routing correctly

2. **Pod Restart Requirement** - Current limitation that Story 7.3 addresses
   - After ConfigMap update, required: `kubectl rollout restart deployment/nginx-proxy -n dev`
   - Rollout successful, no connection errors
   - Story 7.3 goal: Eliminate this restart requirement via hot-reload

3. **Health Endpoint Reliability** - Health checks worked throughout
   - `/health` endpoint responsive during all operations
   - Readiness/liveness probes never failed
   - Can be used for post-reload validation

**Key Files Modified in Story 7.2:**
- `applications/nginx/configmap.yaml` - Added app1 (192.168.2.50:3000), app2 (192.168.2.51:8080)
- `applications/nginx/README.md` - Updated with proxy target addition instructions
- Story 7.2 already documents: "Hot-reload without pod restart will be implemented in Story 7.3"

**Problems Encountered:**
- None - Story 7.2 had zero errors during implementation
- ConfigMap updates require pod restart (Story 7.3 solves this)

**Code Patterns Established:**
```nginx
# Upstream definition pattern (from Story 7.2)
upstream app1 {
    server 192.168.2.50:3000;
}

# Location block pattern
location /app1 {
    proxy_pass http://app1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

**Testing Approaches That Worked:**
- DNS resolution test: `nslookup dev.home.jetzinger.com`
- HTTPS access test: `curl https://dev.home.jetzinger.com/app1`
- Nginx config validation: `kubectl exec ... -- nginx -t`
- Health endpoint test: `curl http://nginx-proxy.dev.svc.cluster.local/health`

**Recommendations for Story 7.3:**
1. Reuse existing ConfigMap structure (app1, app2 upstreams)
2. Test hot-reload by adding app3, app4 upstreams
3. Use same validation commands (nginx -t, health endpoint, curl tests)
4. Document hot-reload in README.md using same format as Story 7.2

**Story 7.1 Learnings (Deploy Nginx Reverse Proxy):**

**Deployment Pattern:**
- Deployment: `nginx-proxy` with 1 replica
- Service: `nginx-proxy` ClusterIP on port 80
- ConfigMap: `nginx-proxy-config` with complete nginx.conf
- Image: `nginx:1.27-alpine` (official, lightweight)

**ConfigMap Mount Implementation:**
- Volume: ConfigMap volume mounted at `/etc/nginx`
- SubPath: `nginx.conf` to preserve other nginx system files
- ReadOnly: `true` for configuration safety

**Health Endpoint Pattern:**
```nginx
location /health {
    access_log off;
    return 200 "healthy\n";
    add_header Content-Type text/plain;
}
```

**Validation Commands:**
```bash
# Pod status
kubectl get pods -n dev -l app.kubernetes.io/instance=nginx-proxy

# Config validation
kubectl exec -n dev <pod> -- nginx -t

# Health check
kubectl exec -n dev deployment/nginx-proxy -- curl -s http://localhost/health
```

### Git Intelligence Summary

**Source:** [Recent commits from Epic 7 work]

**Recent Pattern Analysis:**
- Story completion commits follow pattern: "Complete Story X.Y: Title"
- All manifests committed to Git before applying to cluster
- Documentation updates included in same commit as code changes
- No inline configuration changes - all via version-controlled files

**Code Patterns from Recent Work:**
- Kubernetes manifests: YAML with explicit apiVersion, kind, metadata
- Labels: Kubernetes recommended labels (app.kubernetes.io/*)
- Scripts: Shell scripts with clear comments, error handling
- Documentation: Markdown with code blocks, clear examples

### Project Context Reference

**Source:** [CLAUDE.md, docs/FOLDER_DOCUMENTATION.md]

**Consistency Rules:**
- All operations via kubectl commands (documented in README)
- Manifests are single source of truth (version controlled)
- Comprehensive troubleshooting documentation for portfolio showcase
- "Cattle not pets" - pods are disposable, configuration is declarative

**Repository Structure:**
```
infrastructure/      # Not touched by Story 7.3
applications/nginx/  # PRIMARY - all Story 7.3 changes here
  ├── configmap.yaml
  ├── deployment.yaml
  ├── service.yaml
  ├── ingress.yaml
  ├── README.md
  └── reload-proxy.sh (NEW)
docs/               # Documentation updates
  └── implementation-artifacts/
      └── 7-3-enable-hot-reload-configuration.md (THIS FILE)
```

**Architecture Decision Impact:**
- ADR pattern: All significant decisions captured as ADRs
- Story 7.3 may warrant ADR if automatic reload mechanism chosen (inotify vs sidecar)
- Document rationale for reload approach in story completion notes

---

## Dev Agent Record

### Agent Model Used

_Will be recorded during implementation_

### Debug Log References

_Will be recorded during implementation_

### Completion Notes List

_Will be populated after implementation_

### File List

_Will be populated after implementation_

---

### Change Log

- 2026-01-06: Story created via create-story workflow with comprehensive requirements analysis from epics.md, architecture patterns extraction, and learnings from Story 7.1 and 7.2
- 2026-01-06: Gap analysis completed - draft tasks validated against codebase, no refinements needed (all prerequisites in place)
