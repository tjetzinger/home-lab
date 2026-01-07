# ADR-008: Fix K3s-Specific Prometheus Alert Misconfigurations

**Date:** 2026-01-07
**Status:** Implemented
**Context:** Epic 8 - Cluster Operations & Maintenance

## Context

Two false-positive P1 alerts were firing in the monitoring system, causing unnecessary mobile notifications via ntfy:

1. **PostgreSQLUnhealthy** - Alert was checking for a Deployment that doesn't exist
2. **KubeProxyDown** - Alert was checking for kube-proxy which K3s doesn't use

Both alerts were sending P1 notifications to mobile devices since 2026-01-06 ~09:00.

## Investigation Findings

### Alert 1: PostgreSQLUnhealthy

**Issue:**
- Alert query: `kube_deployment_status_replicas_available{deployment="postgresql", namespace="data"}`
- PostgreSQL is deployed as a **StatefulSet** (`postgres-postgresql`), not a Deployment
- Alert was always firing due to `absent()` condition matching non-existent resource

**Actual Status:**
- StatefulSet: 1/1 ready
- Pod: 2/2 Running (17+ hours uptime)
- PVCs: Bound and healthy
- Services: All operational

### Alert 2: KubeProxyDown

**Issue:**
- Alert query: `absent(up{job="kube-proxy"})`
- K3s does **not use kube-proxy** by design
- K3s uses built-in service load balancing via **svclb** (klipper-lb)

**Actual Status:**
- K3s v1.34.3+k3s1 running normally
- All 3 nodes Ready
- svclb pods running on all nodes: `svclb-traefik-*` (3 pods)
- Service networking fully operational

## Decision

### Fix 1: Update PostgreSQL Alert to Check StatefulSet

Changed alert expression from checking Deployment to checking StatefulSet:

```yaml
# Before
expr: |
  kube_deployment_status_replicas_available{deployment="postgresql", namespace="data"} == 0
  or
  absent(kube_deployment_status_replicas_available{deployment="postgresql", namespace="data"})

# After
expr: |
  kube_statefulset_status_replicas_ready{statefulset="postgres-postgresql", namespace="data"} == 0
  or
  absent(kube_statefulset_status_replicas_ready{statefulset="postgres-postgresql", namespace="data"})
```

**Additional Changes:**
- Updated description to mention "StatefulSet" instead of "deployment"
- Changed `for: 0s` to `for: 2m` to avoid alert flapping during restarts
- Applied to: `monitoring/home-lab-custom-alerts` PrometheusRule

### Fix 2: Disable KubeProxyDown Alert for K3s

K3s doesn't use kube-proxy, so this alert is not applicable. Disabled by setting expression to return empty result (never fires):

```yaml
# Before
expr: absent(up{job="kube-proxy"})

# After (Initial attempt - incorrect)
expr: vector(0)  # This still fired because vector(0) returns a result

# After (Final fix)
expr: absent(vector(1))  # Always returns empty result, never fires
```

**Technical Note:**
- `vector(0)` returns a vector with value 0, which causes the alert to fire
- `absent(vector(1))` returns empty because vector(1) always exists
- Empty result = alert never fires

**Rationale:**
- K3s uses svclb (klipper-lb) for service load balancing
- Checking for kube-proxy in K3s is incorrect
- Will create K3s-specific svclb health alert separately (see ADR-009)

**Applied to:** `monitoring/kube-prometheus-stack-kubernetes-system-kube-proxy` PrometheusRule

## Consequences

### Positive
- ✅ No more false-positive mobile notifications
- ✅ Alert system now K3s-aware
- ✅ PostgreSQL alert will correctly detect actual database failures
- ✅ Monitoring system properly configured for StatefulSet workloads

### Negative
- ⚠️ No monitoring for K3s service load balancing (svclb) failures
- ⚠️ Helm chart updates may revert KubeProxyDown alert changes

### Mitigations
- Create K3s-specific svclb health alert (ADR-009)
- Document these changes for future Helm upgrades
- Consider adding to Helm values to permanently disable KubeProxyDown

## Verification

**Alert Resolution Timeline:**
- PostgreSQLUnhealthy: Resolved immediately after fix (2026-01-07 10:20 CET)
- KubeProxyDown (Initial): Required additional fix due to `vector(0)` still firing
- KubeProxyDown (Final): Changed to `absent(vector(1))`, resolved within minutes
- Final Status: Only expected alerts firing (Watchdog, InfoInhibitor)

**Alert Status (Post-Fix):**
- Critical/Warning Alerts: 0
- Active Alerts: 2 (Watchdog, InfoInhibitor - both expected)
- Prometheus State: KubeProxyDown = inactive
- All false positives eliminated

**Commands Used:**
```bash
# Verify PostgreSQL is healthy
kubectl get statefulset -n data postgres-postgresql
kubectl get pod -n data postgres-postgresql-0

# Verify K3s svclb is running
kubectl get pods -n kube-system | grep svclb

# Check current alerts
kubectl exec -n monitoring alertmanager-kube-prometheus-stack-alertmanager-0 \
  -c alertmanager -- wget -qO- http://localhost:9093/api/v2/alerts
```

## Related Work

- **Story 4.4:** Configure Alertmanager with Alert Rules (original alert configuration)
- **Story 4.5:** Setup Mobile Notifications for P1 Alerts (ntfy integration)
- **Story 5.1:** Deploy PostgreSQL via Bitnami Helm Chart (StatefulSet deployment)
- **ADR-009:** K3s Service Load Balancer (svclb) Monitoring (to be created)

## References

- [K3s Service Load Balancer Documentation](https://docs.k3s.io/networking#service-load-balancer)
- [kube-state-metrics StatefulSet Metrics](https://github.com/kubernetes/kube-state-metrics/blob/main/docs/statefulset-metrics.md)
- PrometheusRule: `monitoring/home-lab-custom-alerts`
- PrometheusRule: `monitoring/kube-prometheus-stack-kubernetes-system-kube-proxy`

## Implementation Details

**Date:** 2026-01-07 10:20 CET
**Applied by:** Claude Code (Story 7.3 continuation)
**Git Commit:** (Pending - changes applied to cluster)

**Files Modified:**
- Kubernetes Resource: `monitoring/home-lab-custom-alerts` (PrometheusRule)
- Kubernetes Resource: `monitoring/kube-prometheus-stack-kubernetes-system-kube-proxy` (PrometheusRule)

**Alert State Before:**
- PostgreSQLUnhealthy: Active (22+ hours)
- KubeProxyDown: Active (24+ hours)

**Alert State After:**
- All critical alerts resolved
- Only Watchdog firing (expected)
