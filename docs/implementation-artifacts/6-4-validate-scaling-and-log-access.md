# Story 6.4: Validate Scaling and Log Access

Status: done

## Story

As a **cluster operator**,
I want **to scale deployments and view pod logs**,
So that **I can manage workload capacity and troubleshoot issues**.

## Acceptance Criteria

1. **Given** Ollama is deployed as a Deployment (not StatefulSet)
   **When** I run `kubectl scale deployment ollama -n ml --replicas=2`
   **Then** a second Ollama pod starts
   **And** both pods reach Running state
   **And** this validates FR12 (scale deployments up or down)

2. **Given** multiple Ollama pods are running
   **When** I scale back down with `kubectl scale deployment ollama -n ml --replicas=1`
   **Then** one pod terminates gracefully
   **And** the remaining pod continues serving requests

3. **Given** pods are running
   **When** I run `kubectl logs ollama-xxx -n ml`
   **Then** pod logs are displayed showing Ollama activity
   **And** I can see model loading and inference requests

4. **Given** logs are accessible
   **When** I run `kubectl logs ollama-xxx -n ml --follow`
   **Then** logs stream in real-time
   **And** new inference requests appear as they happen

5. **Given** events are tracked
   **When** I run `kubectl get events -n ml --sort-by=.lastTimestamp`
   **Then** I can see recent events for the namespace
   **And** pod scheduling, scaling, and health events are visible
   **And** this validates FR13 (view pod logs and events)

## Tasks / Subtasks

⚠️ **DRAFT TASKS** - Generated from requirements analysis. Will be validated and refined against actual codebase when dev-story runs.

### Task 1: Scale Ollama Deployment to 2 Replicas (AC: 1)
- [ ] 1.1: Verify current Ollama deployment replica count (should be 1)
- [ ] 1.2: Execute `kubectl scale deployment ollama -n ml --replicas=2`
- [ ] 1.3: Monitor pod creation with `kubectl get pods -n ml -w`
- [ ] 1.4: Verify both pods reach Running state (1/1 Ready)
- [ ] 1.5: Check pod scheduling - verify both pods on same node (RWO PVC constraint)
- [ ] 1.6: Run health check: `./scripts/ollama-health.sh --internal`
- [ ] 1.7: Validate FR12 compliance (scale deployments up)

### Task 2: Scale Ollama Deployment Down to 1 Replica (AC: 2)
- [ ] 2.1: Execute `kubectl scale deployment ollama -n ml --replicas=1`
- [ ] 2.2: Monitor pod termination with `kubectl get pods -n ml -w`
- [ ] 2.3: Verify one pod terminates with reason "Terminating"
- [ ] 2.4: Verify graceful shutdown (no force delete required)
- [ ] 2.5: Confirm remaining pod continues in Running state
- [ ] 2.6: Run health check: `./scripts/ollama-health.sh --internal`
- [ ] 2.7: Validate FR12 compliance (scale deployments down)

### Task 3: View and Analyze Pod Logs (AC: 3)
- [ ] 3.1: List current Ollama pods: `kubectl get pods -n ml -l app.kubernetes.io/name=ollama`
- [ ] 3.2: Extract pod name from list output
- [ ] 3.3: View full logs: `kubectl logs <pod-name> -n ml`
- [ ] 3.4: Verify Ollama startup messages visible
- [ ] 3.5: Verify model loading logs present
- [ ] 3.6: Test with inference request and verify request appears in logs
- [ ] 3.7: Test log filtering with `--tail=50` flag
- [ ] 3.8: Test log time filtering with `--since=5m` flag

### Task 4: Stream Real-Time Logs (AC: 4)
- [ ] 4.1: Start log streaming: `kubectl logs <pod-name> -n ml --follow`
- [ ] 4.2: In separate terminal, trigger inference request via curl
- [ ] 4.3: Verify new log entries appear in real-time
- [ ] 4.4: Verify timestamps appear with `--timestamps` flag
- [ ] 4.5: Test streaming multiple pods with `kubectl logs -n ml -l app.kubernetes.io/name=ollama --follow`
- [ ] 4.6: Document log streaming patterns for troubleshooting

### Task 5: View and Analyze Kubernetes Events (AC: 5)
- [ ] 5.1: View all namespace events: `kubectl get events -n ml --sort-by=.lastTimestamp`
- [ ] 5.2: Verify pod creation events visible
- [ ] 5.3: Verify pod scheduling events (node assignment)
- [ ] 5.4: Verify pod started/ready events
- [ ] 5.5: Verify scaling events (replica count changes)
- [ ] 5.6: Verify pod termination events (from scale-down)
- [ ] 5.7: Use `kubectl describe pod <pod-name> -n ml` to view pod-specific events
- [ ] 5.8: Validate FR13 compliance (view pod logs and events)

### Task 6: Document Operations in README (AC: All)
- [ ] 6.1: Update applications/ollama/README.md with Operations section (insert after Monitoring section, ~line 380)
- [ ] 6.2: Document scaling procedures (up and down)
- [ ] 6.3: Document log viewing commands and use cases
- [ ] 6.4: Document event inspection for troubleshooting
- [ ] 6.5: Add RWO storage constraint note for scaling
- [ ] 6.6: Include example log output snippets
- [ ] 6.7: Include example event output
- [ ] 6.8: Add troubleshooting guide for scaling issues

## Gap Analysis

**Completed:** 2026-01-06

### Codebase Scan Results

✅ **Infrastructure Ready:**

1. **Ollama Deployment** - Fully operational and scalable
   - Type: Deployment (not StatefulSet - enables horizontal scaling)
   - Current replicas: 1
   - Update strategy: Recreate
   - Resources: 500m/2Gi requests, 4 CPU/8Gi limits per pod
   - Status: 1/1 Running

2. **Health Check Script** - `scripts/ollama-health.sh` (215 lines)
   - Comprehensive validation: API accessibility, model availability, inference
   - Exit codes: 0=healthy, 1=API unreachable, 2=model missing, 3=inference failed, 4=performance degraded
   - Supports both `--internal` and `--external` endpoints
   - Ready to use for Tasks 1.6 and 2.6

3. **Ollama README** - `applications/ollama/README.md` (480 lines)
   - Existing sections: Overview, Deployment, Access, Configuration, Model Management, API Usage, API Testing Results, Monitoring, Troubleshooting
   - Operations section insertion point: After Monitoring section (line ~380)
   - Structure ready for Task 6 additions

4. **Persistent Storage** - RWO constraint confirmed
   - PVC: `ollama` (50Gi, nfs-client StorageClass)
   - Access mode: ReadWriteOnce (RWO)
   - Implication: Multiple replicas must schedule to same node (as documented in story)

5. **Service Configuration** - Load balancing ready
   - Type: ClusterIP, Port: 11434
   - Internal DNS: `ollama.ml.svc.cluster.local:11434`
   - Kubernetes service will automatically load balance across healthy pods

### Task Validation

**All 6 tasks validated against codebase:**

✅ **Task 1 (Scale to 2 replicas)** - Deployment scalable, health script ready
✅ **Task 2 (Scale down to 1 replica)** - Graceful termination supported
✅ **Task 3 (View pod logs)** - kubectl logs commands validated
✅ **Task 4 (Stream real-time logs)** - kubectl logs --follow supported
✅ **Task 5 (View events)** - kubectl get events validated
✅ **Task 6 (Document operations)** - README structure confirmed, clear insertion point

### Task Refinements Applied

**Task 1.6:** Updated to use existing health script: `./scripts/ollama-health.sh --internal`
**Task 2.6:** Updated to use existing health script: `./scripts/ollama-health.sh --internal`
**Task 6.1:** Confirmed README insertion point after Monitoring section (~line 380)

**No tasks removed or restructured.** All draft tasks are accurate and implementable.

**Confidence:** 🟢 High - Infrastructure ready, no blockers identified

---

## Dev Notes

### Technical Requirements

**Source:** [docs/planning-artifacts/epics.md#Story 6.4]

**Kubernetes Operations Focus:**
- This story validates fundamental Kubernetes operational skills (scaling, logging, events)
- Uses kubectl command-line interface for all operations
- No Helm deployments or infrastructure changes - pure operational validation
- Demonstrates platform engineering operational competency for portfolio

**Scaling Strategy:**
- Ollama deployed as Deployment (not StatefulSet) - enables horizontal scaling
- Current replicas: 1 (from values-homelab.yaml line 12)
- Target: Scale up to 2, then back down to 1
- Storage constraint: RWO PVC means both replicas must run on same node

**Resource Requirements (per pod):**
```yaml
requests:
  cpu: 500m
  memory: 2Gi
limits:
  cpu: 4000m
  memory: 8Gi
```

**Capacity Planning:**
- 2 replicas = 1 CPU request, 4Gi memory request minimum
- Worker nodes must have sufficient capacity
- Check node resources before scaling: `kubectl describe nodes`

**Logging Strategy:**
- Primary method: `kubectl logs` for tactical/immediate troubleshooting
- Strategic method: Grafana + Loki (already deployed in Epic 4) for historical analysis
- Log retention: Loki configured for 30-day retention (from Epic 4)

### Architecture Compliance

**Source:** [docs/planning-artifacts/architecture.md#Troubleshooting Process]

**Kubernetes Operations Pattern:**
1. Check pod status: `kubectl get pods -n {namespace}`
2. Check logs: `kubectl logs {pod} -n {namespace}`
3. Check events: `kubectl describe pod {pod} -n {namespace}`
4. Consult runbook if exists
5. Document resolution if new issue

**Namespace:** `ml` (AI/ML workloads)
- Isolation: Scaling operations don't affect other namespaces
- Labels: All resources use Kubernetes recommended labels

**Deployment Type:** Deployment (not StatefulSet)
- Chosen for horizontal scaling flexibility
- UpdateStrategy: Recreate (from values-homelab.yaml)

**Storage Considerations:**
- PVC: `ollama` (50Gi, nfs-client StorageClass)
- Access Mode: ReadWriteOnce (RWO)
- **Critical Constraint:** RWO means multiple pods must run on **same node** to share storage
- Model path: `/root/.ollama`
- Current model: llama3.2:1b (1.3GB)

**Service Configuration:**
- Type: ClusterIP
- Port: 11434
- Internal DNS: ollama.ml.svc.cluster.local:11434
- Load balancing: Kubernetes service automatically load balances across healthy pods

### Library/Framework Requirements

**Command-Line Tools:**
- `kubectl` - Kubernetes CLI (already configured from Epic 1)
- `curl` - API testing (used in Story 6.2)
- `jq` - JSON parsing (optional, for log analysis)
- `watch` - Real-time monitoring (optional, for continuous status updates)

**Health Check Script:**
- `scripts/ollama-health.sh` - Created in Story 6.2
- Exit codes: 0=healthy, 1=API unreachable, 2=model missing, 3=inference failed, 4=performance degraded
- Use during scaling operations to validate service continuity

**No additional dependencies required** - all operations use standard kubectl commands.

### File Structure Requirements

**Source:** [docs/planning-artifacts/architecture.md#Project Structure]

**Files to Update:**
```
applications/ollama/
└── README.md  # Add Operations section with scaling and logging procedures
```

**README Updates:**
- Add "Operations" section after "Deployment" section
- Subsections:
  - Scaling Procedures
  - Log Viewing
  - Event Inspection
  - Troubleshooting Common Issues
- Include example command output
- Document RWO storage constraint

**Optional Additions (if README becomes too large):**
```
docs/runbooks/
└── ollama-operations.md  # Dedicated operational procedures runbook
```

### Testing Requirements

**Deployment Validation:**
1. Initial state: 1 Ollama pod Running
2. Scale up: 2 Ollama pods Running, both on same node
3. API accessible: ollama-health.sh returns exit code 0
4. Scale down: 1 Ollama pod Running, 1 Terminating → Terminated
5. API still accessible: ollama-health.sh returns exit code 0

**Log Validation:**
1. Logs contain Ollama startup messages
2. Logs show model loading activity
3. Logs show inference requests (when triggered)
4. Streaming logs update in real-time
5. Log filtering works with --tail and --since flags

**Event Validation:**
1. Events show pod creation (Scheduled, Pulling, Pulled, Created, Started)
2. Events show pod scaling (ScalingReplicaSet)
3. Events show pod termination (Killing)
4. Events sorted by timestamp show most recent first
5. Events accessible for all pods in namespace

**Functional Requirements Validation:**
- FR12: Operator can scale deployments up or down ✓
- FR13: Operator can view pod logs and events ✓

**Non-Functional Requirements:**
- NFR1: Cluster operations use kubectl CLI (validated via operational commands)

### Previous Story Intelligence

**Source:** [docs/implementation-artifacts/6-1-deploy-ollama-for-llm-inference.md, 6-2-test-ollama-api-and-model-inference.md]

**Story 6.1 Learnings:**

**Deployment Patterns Established:**
- Helm-based deployment with `values-homelab.yaml`
- NFS-backed persistent storage (50Gi PVC, RWO access mode)
- IngressRoute for HTTPS access (ollama.home.jetzinger.com)
- Let's Encrypt TLS certificate automation
- Security context: non-root user (1000:1000), capabilities dropped

**Files Created:**
- `applications/ollama/values-homelab.yaml` - Helm configuration (114 lines)
- `applications/ollama/ingress.yaml` - IngressRoute + Certificate (97 lines)
- `applications/ollama/README.md` - Deployment documentation (335 lines)

**Challenges Resolved:**
1. **Values File Structure**: Initial values used wrong field names → corrected by reading chart defaults (`helm show values`)
2. **Pod Termination**: Old pod stuck terminating → force delete with `--grace-period=0 --force`
3. **Certificate Provisioning**: Takes ~2 minutes for Let's Encrypt ACME challenge (expected behavior)

**Success Metrics:**
- Pod status: 1/1 Running, 0 restarts
- PVC status: Bound
- Model persistence: Validated (models survive pod restarts without re-download)
- HTTPS access: HTTP 200 status from ollama.home.jetzinger.com

**Story 6.2 Learnings:**

**Testing Patterns Established:**
- CLI-first validation using curl + jq
- Performance benchmarking with timing measurements
- External access validation via Tailscale VPN
- Automated health checks via bash scripts

**Files Created:**
- `scripts/ollama-health.sh` - Comprehensive health monitoring (207 lines, executable)

**Health Check Script Features:**
1. API endpoint accessibility check
2. Model availability verification
3. Basic inference test with response time measurement
4. Exit codes for automation: 0=healthy, 1=API unreachable, 2=model missing, 3=inference failed, 4=performance degraded

**API Endpoints Validated:**
- `/api/tags` - List available models ✓
- `/api/generate` - Text completion (streaming and non-streaming) ✓
- HTTP→HTTPS redirect (308 Permanent Redirect) ✓

**Performance Findings (NFR13 Validation):**
- Simple prompts (1-3 words): ~2s response time ✅ meets <30s threshold
- Medium prompts (5-10 words): ~116s response time ❌ exceeds 30s threshold
- CPU-only inference has high variability
- GPU support (Phase 2) will address performance gaps for complex prompts

**Key Operational Insights:**
- `kubectl logs` already used for validation in Story 6.1 (checking startup messages, model loading)
- `kubectl describe pod` used for troubleshooting stuck pods
- `kubectl get events` used to diagnose certificate provisioning delays
- All operations performed against `ml` namespace

**Established Conventions:**
- All kubectl commands include `-n ml` namespace flag
- Pod names follow pattern: `ollama-{replicaset-hash}-{pod-hash}`
- Health validation always uses both kubectl checks and API endpoint tests

### Project Context Reference

**Source:** [CLAUDE.md, docs/FOLDER_DOCUMENTATION.md]

**Repository Guidelines:**
- All operations documented in README files or runbooks
- kubectl commands version controlled in documentation (not executed scripts)
- Troubleshooting patterns captured for future reference
- No inline --set flags or undocumented manual commands

**Cluster Context:**
- K3s cluster with 1 control plane (k3s-master) + 2 workers (k3s-worker-01, k3s-worker-02)
- Worker nodes: 4 CPU, 8GB RAM each (from architecture.md)
- Ollama running on worker nodes (no node affinity configured)
- Current Ollama pod node assignment: Check with `kubectl get pod -n ml -o wide`

**Kubernetes Version:**
- K3s version: v1.28+ (from Epic 1 implementation)
- kubectl version: Must match server version (validated in Epic 1)

**Naming Conventions:**
- Namespace: `ml` (AI/ML workloads)
- Deployment: `ollama`
- Service: `ollama`
- PVC: `ollama`
- Pod naming: `ollama-{replicaset}-{pod}` (auto-generated)

**Operational Philosophy:**
- "Cattle not pets" - pods are disposable, scaling is normal
- Validate operations via both CLI and API endpoints
- Document all operational procedures for portfolio demonstration
- Capture troubleshooting patterns for career showcase

**Epic 6 Context:**
- Story 6.1: Deploy Ollama ✅ DONE
- Story 6.2: Test Ollama API and model inference ✅ DONE
- Story 6.3: Deploy n8n for workflow automation ✅ DONE
- Story 6.4: Validate scaling and log access ⏳ THIS STORY

**Expected Challenges & Mitigations:**

**Challenge 1: RWO Storage Constraint**
- **Issue:** ReadWriteOnce PVC means multiple replicas must schedule to same node
- **Detection:** Second pod stuck in ContainerCreating with mount error: "Volume is already exclusively attached to one node"
- **Mitigation:** Verify both pods on same node with `kubectl get pods -n ml -o wide`, or add nodeAffinity if needed
- **Acceptable for MVP:** Single-node scaling demonstrates operational skills without requiring RWX storage

**Challenge 2: Model Loading Time**
- **Issue:** Each pod loads model independently on startup (even from NFS)
- **Impact:** Second pod may take 30-60s to become Ready (initial pod takes ~30s)
- **Detection:** Pod status shows Running but 0/1 Ready
- **Validation:** Check readiness probe in `kubectl describe pod -n ml <pod-name>`

**Challenge 3: Log Volume**
- **Issue:** Ollama can be verbose, especially with inference requests
- **Impact:** Difficult to find relevant information in full log output
- **Mitigation:** Use `--tail=50` to limit output, `--since=5m` for time-bounded logs, `grep` for filtering
- **Best Practice:** Document common log patterns in README troubleshooting section

**Challenge 4: Event Retention**
- **Issue:** Kubernetes events have limited retention (typically 1 hour)
- **Impact:** Historical scaling events may not be visible if validation delayed
- **Mitigation:** Run event checks immediately after scaling operations
- **Note:** Loki provides long-term event storage (30 days) for historical analysis

---

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-5-20250929

### Debug Log References

_Will be recorded during implementation_

### Completion Notes List

**Implementation Summary:**

All 6 tasks completed successfully, validating Kubernetes operational skills (FR12, FR13).

**Key Findings:**

1. **NFS Storage Allows Multi-Node Scaling:**
   - PVC access mode: ReadWriteOnce (RWO)
   - Storage backend: NFS (nfs-client StorageClass)
   - **Discovery:** NFS-backed storage supports multi-node concurrent access despite RWO access mode
   - **Impact:** Ollama can scale across different nodes (k3s-worker-02 and k3s-master observed)
   - **Clarification:** RWO restrictions apply primarily to block storage (iSCSI, FC), not NFS
   - **Documented:** Added RWO storage clarification to README Operations section

2. **Scaling Operations:**
   - Scale up: 1→2 replicas executed successfully
   - New pod scheduled to k3s-master (different node than existing pod)
   - Image pull time: ~4m22s (2.1GB Ollama image)
   - Both pods reached Running 1/1 Ready
   - Health check: PASSED (API accessible, model available, inference working)
   - Scale down: 2→1 replica with graceful termination
   - No service interruption during scaling operations

3. **Log Access:**
   - Pod logs accessible via kubectl logs
   - Startup messages visible: server config, GPU discovery, model loading
   - Inference requests logged: POST "/api/generate" with response time
   - Health checks logged: GET "/" every few seconds
   - Log filtering validated: --tail, --since, --timestamps, grep
   - Real-time streaming validated: --follow, --prefix for multi-pod

4. **Event Inspection:**
   - Namespace events show complete scaling lifecycle
   - Events: Scheduled, Pulling, Pulled, Created, Started, ScalingReplicaSet, Killing, SuccessfulDelete
   - Event retention: ~1 hour (as expected)
   - Pod-specific events via kubectl describe
   - Event filtering by object type (Deployment, Pod) validated

5. **Documentation:**
   - Added comprehensive Operations section to applications/ollama/README.md
   - 212 lines covering: Scaling, Log Viewing, Event Inspection, Troubleshooting
   - Includes command examples, expected behavior, common patterns
   - RWO storage behavior clarified for future reference

**Functional Requirements Validated:**

- ✅ **FR12:** Operator can scale deployments up or down (kubectl scale)
- ✅ **FR13:** Operator can view pod logs and events (kubectl logs, kubectl get events)

**Non-Functional Requirements:**

- ✅ **NFR1:** Cluster operations use kubectl CLI (all tasks used kubectl commands)

### File List

**Modified:**
- `applications/ollama/README.md` - Added Operations section (212 lines) with scaling, logging, and event inspection procedures

---

### Change Log

- 2026-01-06: Story created with requirements analysis, draft implementation tasks, and comprehensive dev context from Stories 6.1-6.3
- 2026-01-06: Gap analysis completed - All infrastructure ready, health check script exists, README structure confirmed
- 2026-01-06: Tasks 1-6 implemented - Scaling validated, logs and events inspected, operations documented in README
- 2026-01-06: Story marked for review - All acceptance criteria met, FR12 and FR13 validated, important NFS storage finding documented
- 2026-01-06: Story marked as done - User approved implementation, Epic 6 (AI Inference Platform) complete
