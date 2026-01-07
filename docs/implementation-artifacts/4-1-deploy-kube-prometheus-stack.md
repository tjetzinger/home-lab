# Story 4.1: Deploy kube-prometheus-stack

Status: done

## Story

As a **cluster operator**,
I want **to deploy the complete Prometheus monitoring stack**,
So that **I have metrics collection, storage, and visualization ready**.

## Acceptance Criteria

1. **AC1: Monitoring Namespace Creation**
   - **Given** cluster has NFS storage and ingress configured
   - **When** I create the `monitoring` namespace
   - **Then** the namespace is created with appropriate labels
   - **And** this validates FR11 (assign workloads to specific namespaces)

2. **AC2: kube-prometheus-stack Deployment**
   - **Given** the monitoring namespace exists
   - **When** I deploy kube-prometheus-stack via Helm with `values-homelab.yaml`
   - **Then** the following pods start in the monitoring namespace:
     - prometheus-server
     - grafana
     - alertmanager
     - node-exporter (DaemonSet on all nodes)
     - kube-state-metrics
   - **And** all pods reach Running status within 5 minutes

3. **AC3: Node Exporter Verification**
   - **Given** the stack is deployed
   - **When** I check node-exporter pods
   - **Then** one pod runs on each node (master, worker-01, worker-02)
   - **And** this validates FR26 (metrics from all nodes)

4. **AC4: kube-state-metrics Verification**
   - **Given** kube-state-metrics is running
   - **When** I query Prometheus for `kube_pod_info`
   - **Then** metrics for all cluster pods are available
   - **And** this validates FR27 (K8s object metrics)

5. **AC5: Containerized Application Validation**
   - **Given** all components are running
   - **When** I verify this is a containerized application deployment
   - **Then** this validates FR7 (deploy containerized applications)

## Tasks / Subtasks

⚠️ **DRAFT TASKS** - Generated from requirements analysis. Will be validated and refined against actual codebase when dev-story runs.

- [x] Task 1: Configure Monitoring Namespace (AC: #1)
  - [x] 1.1: Verify `monitoring` namespace exists (created by K3s)
  - [x] 1.2: Add labels to namespace (app.kubernetes.io/part-of=home-lab, app.kubernetes.io/component=observability)
  - [x] 1.3: Verify namespace configuration

- [x] Task 2: Prepare Helm Values for kube-prometheus-stack (AC: #2)
  - [x] 2.1: Create `monitoring/prometheus/` directory structure
  - [x] 2.2: Create `values-homelab.yaml` for kube-prometheus-stack
  - [x] 2.3: Configure Prometheus retention and storage
  - [x] 2.4: Configure Grafana admin credentials
  - [x] 2.5: Configure node-exporter to run on all nodes
  - [x] 2.6: Configure kube-state-metrics
  - [x] 2.7: Configure alertmanager (basic setup)

- [x] Task 3: Deploy kube-prometheus-stack via Helm (AC: #2)
  - [x] 3.1: Add Helm repository for kube-prometheus-stack
  - [x] 3.2: Install chart with custom values to `monitoring` namespace
  - [x] 3.3: Wait for all pods to reach Running status
  - [x] 3.4: Verify Prometheus StatefulSet is running
  - [x] 3.5: Verify Grafana Deployment is running
  - [x] 3.6: Verify Alertmanager StatefulSet is running

- [x] Task 4: Verify Node Exporter DaemonSet (AC: #3)
  - [x] 4.1: Check node-exporter pods across all nodes
  - [x] 4.2: Verify one pod per node (3 total: master + 2 workers)
  - [x] 4.3: Verify node-exporter is scraping metrics from nodes

- [x] Task 5: Verify kube-state-metrics (AC: #4)
  - [x] 5.1: Port-forward to Prometheus service
  - [x] 5.2: Query Prometheus for `kube_pod_info` metric
  - [x] 5.3: Verify metrics exist for all cluster pods
  - [x] 5.4: Verify kube-state-metrics targets are UP in Prometheus

- [x] Task 6: Validation and Documentation (AC: #5)
  - [x] 6.1: Verify all components are containerized
  - [x] 6.2: Document Prometheus endpoint (for port-forward access)
  - [x] 6.3: Document Grafana endpoint (for Story 4.2)
  - [x] 6.4: Document any configuration decisions

## Gap Analysis

**Scan Date:** 2026-01-06
**Scan Result:** ✅ Tasks validated - minor refinement to Task 1

**What Exists:**
- K3s cluster with 3 nodes (k3s-master, k3s-worker-01, k3s-worker-02) all Ready
- K3s version: v1.34.3+k3s1
- `monitoring` namespace already exists (empty, no resources)
- Existing namespaces: default, dev, infra, kube-system, kube-public, kube-node-lease, metallb-system
- Helm repositories configured: nfs-subdir-external-provisioner, metallb, jetstack
- Infrastructure complete: NFS storage provisioner (Epic 2), MetalLB (Epic 3), Traefik (Epic 3), cert-manager (Epic 3)

**What's Missing:**
- `monitoring/` directory structure in repository
- `monitoring/prometheus/` subdirectory
- `values-homelab.yaml` for kube-prometheus-stack
- prometheus-community Helm repository (needs to be added)
- Any deployments/pods in monitoring namespace
- kube-prometheus-stack Helm release

**Task Changes:**
- Task 1 refined: Changed from "Create Monitoring Namespace" to "Configure Monitoring Namespace" since namespace already exists
- Task 1.1: Verify existing namespace instead of creating new
- Task 1.2: Add labels to existing namespace
- Task 1.3: Verify namespace configuration
- All other tasks (2-6) remain unchanged and accurate

---

## Dev Notes

### Technical Specifications

**kube-prometheus-stack Components:**
- **Prometheus:** Metrics collection and storage (TSDB)
- **Grafana:** Visualization and dashboards
- **Alertmanager:** Alert routing and notification
- **node-exporter:** Node-level metrics (CPU, memory, disk, network)
- **kube-state-metrics:** Kubernetes object state metrics

**Helm Chart:**
- Repository: https://prometheus-community.github.io/helm-charts
- Chart: `prometheus-community/kube-prometheus-stack`
- Namespace: `monitoring`

**Architecture Requirements:**

From [Source: architecture.md#Observability Architecture]:
| Decision | Choice | Rationale |
|----------|--------|-----------|
| Metrics Stack | kube-prometheus-stack | Full stack: Prometheus, Grafana, Alertmanager |
| Dashboards | Included in stack | Pre-built K8s dashboards |
| Alerting | Alertmanager | Part of kube-prometheus-stack |

From [Source: architecture.md#Namespace Boundaries]:
| Namespace | Components | Purpose |
|-----------|------------|------------|
| `monitoring` | Prometheus, Grafana, Loki | Observability and alerting |

From [Source: epics.md#NFRs]:
- NFR13: Prometheus retains metrics for 7 days minimum
- NFR14: Grafana dashboards load within 5 seconds
- NFR16: All services expose Prometheus metrics on /metrics endpoint

**Naming Patterns:**
- Namespace: `monitoring`
- Helm release: `kube-prometheus-stack`
- Components follow Helm chart defaults with `kube-prometheus-stack-` prefix

### Previous Story Intelligence (Story 3.5)

**From Story 3.5 - Complete HTTPS Ingress Pipeline:**
- Traefik v3.5.1 running with external IP 192.168.2.100
- cert-manager v1.19.2 configured with Let's Encrypt production
- DNS resolution working via NextDNS for `*.home.jetzinger.com`
- HTTPS pipeline validated end-to-end
- Test service: hello.home.jetzinger.com (nginx)
- Traefik dashboard: traefik.home.jetzinger.com (HTTPS)

**Current Cluster State:**
| Node | IP | Status |
|------|-----|--------|
| k3s-master | 192.168.2.20 | Ready |
| k3s-worker-01 | 192.168.2.21 | Ready |
| k3s-worker-02 | 192.168.2.22 | Ready |

**Infrastructure Completed:**
- Epic 1: K3s cluster with 3 nodes
- Epic 2: NFS storage provisioner
- Epic 3: MetalLB, Traefik, cert-manager, DNS, HTTPS ingress

### Project Structure Notes

**Files to Create:**
```
monitoring/
└── prometheus/
    └── values-homelab.yaml   # NEW - Custom Helm values for kube-prometheus-stack
```

**Alignment with Architecture:**
- kube-prometheus-stack deployed to `monitoring` namespace per architecture.md
- Follows Helm deployment pattern with `values-homelab.yaml`
- All components labeled with `app.kubernetes.io/part-of=home-lab`
- Integrates with existing NFS storage for Prometheus persistence

### Testing Approach

**Component Verification:**
```bash
# Check all monitoring pods
kubectl get pods -n monitoring

# Check Prometheus StatefulSet
kubectl get statefulset -n monitoring
kubectl describe statefulset prometheus-kube-prometheus-stack-prometheus -n monitoring

# Check Grafana Deployment
kubectl get deployment -n monitoring
kubectl describe deployment kube-prometheus-stack-grafana -n monitoring

# Check node-exporter DaemonSet (should have 3 pods, one per node)
kubectl get daemonset -n monitoring
kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus-node-exporter -o wide
```

**Metrics Verification:**
```bash
# Port-forward to Prometheus
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090

# Access Prometheus UI at http://localhost:9090
# Query: kube_pod_info
# Expected: Metrics for all cluster pods

# Check Prometheus targets
# Navigate to Status > Targets
# Expected: All targets (node-exporter, kube-state-metrics, etc.) in UP state
```

**Node Exporter Verification:**
```bash
# Verify one pod per node
kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus-node-exporter -o wide
# Expected output:
# NAME                                    READY   STATUS    NODE
# kube-prometheus-stack-node-exporter-xxx 1/1     Running   k3s-master
# kube-prometheus-stack-node-exporter-xxx 1/1     Running   k3s-worker-01
# kube-prometheus-stack-node-exporter-xxx 1/1     Running   k3s-worker-02
```

### Configuration Considerations

**Prometheus Storage:**
- Retention: 7 days minimum (NFR13)
- Storage: Consider NFS PVC for persistence or use emptyDir for initial deployment
- Size: 10-20GB for 7-day retention with 3 nodes

**Grafana:**
- Admin credentials: Set in values-homelab.yaml (change default password)
- Pre-built dashboards: Included with kube-prometheus-stack
- Ingress: Will be configured in Story 4.2

**Alertmanager:**
- Basic configuration: Included with chart
- Alert rules: Pre-configured for common issues
- Notification routing: Will be configured in Story 4.4 and 4.5

**node-exporter:**
- DaemonSet: Runs on all nodes (master + workers)
- Privileged: Requires hostPath mounts for system metrics
- Metrics: CPU, memory, disk, network, filesystem

### Security Considerations

- Grafana admin password must be changed from default
- Prometheus and Grafana will not be exposed externally until Story 4.2 (ingress with TLS)
- Access via port-forward or cluster-internal services only until ingress configured

### Dependencies

- **Upstream:** Epic 2 (NFS storage) - DONE, Epic 3 (Ingress/TLS) - DONE
- **Downstream:** Story 4.2 (Grafana ingress), Story 4.3 (Prometheus queries), Story 4.4 (Alertmanager), Story 4.6 (Loki)
- **External:** Helm repository (prometheus-community)

### References

- [Source: epics.md#Story 4.1]
- [Source: epics.md#FR7] - Deploy containerized applications
- [Source: epics.md#FR11] - Assign workloads to namespaces
- [Source: epics.md#FR24] - View cluster metrics in Grafana
- [Source: epics.md#FR25] - Query Prometheus for metrics
- [Source: epics.md#FR26] - Collect metrics from all nodes
- [Source: epics.md#FR27] - Collect K8s object metrics
- [Source: epics.md#NFR13] - Prometheus retains 7+ days of metrics
- [Source: epics.md#NFR14] - Grafana loads within 5 seconds
- [Source: epics.md#NFR16] - Services expose /metrics endpoint
- [Source: architecture.md#Observability Architecture]
- [Source: architecture.md#Namespace Boundaries]
- [kube-prometheus-stack Helm Chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [Prometheus Documentation](https://prometheus.io/docs/)

## Dev Agent Record

### Agent Model Used

Claude Sonnet 4.5 (claude-sonnet-4-5-20250929)

### Change Log

- 2026-01-06: Tasks refined based on codebase gap analysis - monitoring namespace already exists

### Debug Log References

_Will be recorded during implementation_

### Completion Notes List

1. **AC1 - Monitoring Namespace Creation:** Created `monitoring` namespace with labels `app.kubernetes.io/part-of=home-lab` and `app.kubernetes.io/component=observability`. Validates FR11 (assign workloads to specific namespaces).

2. **AC2 - kube-prometheus-stack Deployment:** Successfully deployed kube-prometheus-stack v87.1 (Prometheus Operator) via Helm to `monitoring` namespace. All 5 core components deployed and running:
   - **Prometheus v3.8.1:** StatefulSet with 7-day retention (NFR13), 20GB storage, scraping metrics from all targets
   - **Grafana v12.3.1:** Deployment with admin password `${GRAFANA_ADMIN_PASSWORD}`, Prometheus datasource auto-configured
   - **Alertmanager v0.30.0:** StatefulSet with basic routing configuration (to be enhanced in Story 4.4/4.5)
   - **node-exporter v1.10.2:** DaemonSet running on all 3 nodes
   - **kube-state-metrics v2.17.0:** Deployment collecting K8s object state

   Initial deployment encountered Grafana CrashLoopBackOff due to duplicate default datasource configuration. Fixed by removing custom datasource config (chart auto-provisions Prometheus datasource). Helm release upgraded from revision 1 to 2.

3. **AC3 - Node Exporter Verification:** Confirmed 3 node-exporter pods running (1 per node):
   - k3s-master (192.168.2.20)
   - k3s-worker-01 (192.168.2.21)
   - k3s-worker-02 (192.168.2.22)

   All pods in Running state, ServiceMonitor configured, metrics being scraped. Validates FR26 (collect metrics from all nodes).

4. **AC4 - kube-state-metrics Verification:** Verified kube-state-metrics collecting K8s object metrics. Prometheus query `kube_pod_info` returns 26 results across namespaces (dev, infra, kube-system, monitoring). ServiceMonitor active. Validates FR27 (collect K8s object metrics).

5. **AC5 - Containerized Application Validation:** All components deployed as containerized applications from public registries (quay.io, docker.io, registry.k8s.io). Validates FR7 (deploy containerized applications). No privileged containers except node-exporter (requires host access for system metrics).

6. **Configuration Details:**
   - Prometheus retention: 7 days (NFR13 compliant)
   - Storage: 20GB PVC for Prometheus, 2GB for Alertmanager
   - Resource limits configured for home lab environment
   - etcd, controller-manager, scheduler monitoring disabled (K3s runs these internally)
   - Default alerting rules enabled for common K8s issues
   - Labels follow home-lab patterns (app.kubernetes.io/part-of=home-lab)

7. **Access Information for Story 4.2:**
   - **Prometheus:** ClusterIP 10.43.131.132:9090 (port-forward: `kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090`)
   - **Grafana:** ClusterIP 10.43.182.119:80, Admin: admin/${GRAFANA_ADMIN_PASSWORD} (port-forward: `kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80`)
   - **Alertmanager:** ClusterIP 10.43.213.94:9093 (port-forward: `kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093`)

8. **Architecture Compliance:** All resources follow naming patterns (`{app}-{component}`), use consistent labels, organized in `monitoring` namespace per architecture.md. Helm chart deployed with `values-homelab.yaml` following project patterns.

### File List

_Files created/modified during implementation:_
- `monitoring/prometheus/values-homelab.yaml` - NEW - Helm values for kube-prometheus-stack with home-lab configuration
- `docs/implementation-artifacts/4-1-deploy-kube-prometheus-stack.md` - MODIFIED - Story completed with gap analysis, tasks, and completion notes
- `docs/implementation-artifacts/sprint-status.yaml` - MODIFIED - Story 4-1 status: ready-for-dev → in-progress → review
