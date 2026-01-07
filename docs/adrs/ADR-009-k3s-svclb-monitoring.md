# ADR-009: K3s Service Load Balancer (svclb) Monitoring

**Date:** 2026-01-07
**Status:** Planned
**Context:** Epic 8 - Cluster Operations & Maintenance
**Relates to:** ADR-008 (KubeProxyDown alert disabled)

## Context

K3s uses a built-in service load balancer called **svclb** (Service Load Balancer, implemented via klipper-lb) instead of kube-proxy. After disabling the KubeProxyDown alert (which was a false positive for K3s), we need K3s-specific monitoring to detect service networking failures.

## K3s Service Load Balancer Architecture

**How svclb Works:**
- K3s deploys DaemonSet pods (e.g., `svclb-traefik-*`) for LoadBalancer services
- Each node runs an svclb pod that proxies traffic to the service
- Uses iptables/nftables rules for load balancing
- Lighter weight than traditional kube-proxy

**Current Deployment:**
```
svclb-traefik-5b1f5b3f-qnr7n    2/2     Running     0    40h   (worker-01)
svclb-traefik-5b1f5b3f-qz92t    2/2     Running     0    41h   (master)
svclb-traefik-5b1f5b3f-vn5jv    2/2     Running     0    39h   (worker-02)
```

**Service Networking Dependencies:**
- MetalLB LoadBalancer services depend on svclb
- Traefik ingress depends on svclb-traefik pods
- Ingress → svclb → Traefik → backend services

## Decision

Create K3s-specific monitoring alerts to detect svclb failures that could impact service networking.

### Alert 1: K3sSvclbPodsDown

**Purpose:** Detect when svclb pods are not running, which breaks LoadBalancer service routing

**Alert Rule:**
```yaml
- alert: K3sSvclbPodsDown
  annotations:
    action: Check svclb DaemonSet status and pod logs. Verify LoadBalancer services are accessible.
    description: K3s Service Load Balancer (svclb) pods in namespace 'kube-system' are not running. LoadBalancer services may be unavailable.
    impact: Ingress traffic routing broken. External access to cluster services unavailable.
    runbook_url: https://github.com/yourusername/home-lab/blob/main/docs/runbooks/k3s-svclb-recovery.md
    summary: K3s svclb pods unavailable
  expr: |
    kube_daemonset_status_number_ready{daemonset=~"svclb-.*", namespace="kube-system"}
    <
    kube_daemonset_status_desired_number_scheduled{daemonset=~"svclb-.*", namespace="kube-system"}
  for: 5m
  labels:
    component: k3s-networking
    priority: P1
    service: svclb
    severity: critical
```

**Rationale:**
- Checks if svclb DaemonSet has fewer ready pods than desired
- 5-minute wait period to avoid flapping during node maintenance
- P1 priority because it breaks external cluster access
- Matches any svclb-* DaemonSet (handles multiple LoadBalancer services)

### Alert 2: K3sSvclbDaemonSetMissing

**Purpose:** Detect if svclb DaemonSet was accidentally deleted

**Alert Rule:**
```yaml
- alert: K3sSvclbDaemonSetMissing
  annotations:
    action: Check if LoadBalancer services exist and if K3s servicelb is enabled. Verify K3s configuration.
    description: K3s Service Load Balancer (svclb) DaemonSet not found in kube-system namespace. This should exist for any LoadBalancer-type service.
    impact: LoadBalancer services cannot be created or accessed. Cluster ingress unavailable.
    runbook_url: https://github.com/yourusername/home-lab/blob/main/docs/runbooks/k3s-svclb-recovery.md
    summary: K3s svclb DaemonSet missing
  expr: |
    absent(kube_daemonset_labels{daemonset=~"svclb-.*", namespace="kube-system"})
    and
    kube_service_info{type="LoadBalancer"} > 0
  for: 2m
  labels:
    component: k3s-networking
    priority: P1
    service: svclb
    severity: critical
```

**Rationale:**
- Only fires if LoadBalancer services exist but no svclb DaemonSet found
- Indicates misconfiguration or K3s servicelb disabled incorrectly
- 2-minute wait to avoid false positives during service creation

### Alert 3: K3sSvclbTraefikDown (High Priority)

**Purpose:** Specific alert for Traefik svclb pods (most critical for cluster ingress)

**Alert Rule:**
```yaml
- alert: K3sSvclbTraefikDown
  annotations:
    action: Check svclb-traefik pods on all nodes. Verify Traefik LoadBalancer service. Test ingress accessibility.
    description: K3s svclb pods for Traefik LoadBalancer are not running on all nodes. HTTPS ingress may be unavailable.
    impact: External HTTPS access broken. All ingress routes (Grafana, n8n, dev proxy) unreachable.
    runbook_url: https://github.com/yourusername/home-lab/blob/main/docs/runbooks/k3s-svclb-recovery.md
    summary: Traefik LoadBalancer svclb pods unavailable
  expr: |
    kube_daemonset_status_number_ready{daemonset="svclb-traefik", namespace="kube-system"}
    <
    kube_node_info{} > 0
  for: 3m
  labels:
    component: ingress
    priority: P0
    service: traefik-svclb
    severity: critical
```

**Rationale:**
- Specific to Traefik svclb (most critical for home-lab)
- P0 priority (higher than P1) - breaks all external access
- 3-minute wait balances quick detection with stability
- Checks if svclb-traefik pods < number of nodes

## Implementation Plan

**Phase 1: Create Alert Rules**
1. Add alerts to `monitoring/home-lab-custom-alerts` PrometheusRule
2. Apply changes to cluster
3. Verify alerts load correctly in Prometheus

**Phase 2: Create Runbook**
1. Create `docs/runbooks/k3s-svclb-recovery.md`
2. Document troubleshooting steps:
   - Check DaemonSet status
   - Check pod logs
   - Verify LoadBalancer service configuration
   - Test service connectivity
   - K3s servicelb re-enable procedure

**Phase 3: Testing**
1. Verify alerts don't fire under normal conditions
2. Test alert by scaling down svclb DaemonSet (optional)
3. Confirm notification routing to ntfy
4. Verify alert resolution

**Phase 4: Documentation**
1. Update monitoring documentation
2. Add to alert runbook index
3. Document K3s-specific monitoring approach

## Consequences

### Positive
- ✅ K3s-appropriate networking monitoring
- ✅ Detect svclb failures before users report issues
- ✅ P0 alert for Traefik ensures quick response to ingress failures
- ✅ No more false positives from kube-proxy checks

### Negative
- ⚠️ Adds 3 new alerts to monitor
- ⚠️ Requires understanding of K3s-specific architecture
- ⚠️ More complex than generic kube-proxy monitoring

### Risks
- False positives during node maintenance (mitigated by 3-5 minute wait periods)
- Alert may fire during K3s upgrades (expected behavior)

## Alternative Approaches Considered

### Option 1: Monitor LoadBalancer Service Health Directly
**Rejected:** Doesn't catch svclb-specific failures, harder to debug root cause

### Option 2: Probe Ingress Endpoints Externally
**Rejected:** Only detects total failure, doesn't identify svclb as root cause

### Option 3: No K3s-Specific Monitoring
**Rejected:** Leaves blind spot in critical networking layer after disabling KubeProxyDown

## Acceptance Criteria

- [ ] PrometheusRule created with all 3 svclb alerts
- [ ] Alerts load successfully in Prometheus
- [ ] Alerts do not fire under normal conditions
- [ ] Runbook created with troubleshooting steps
- [ ] ntfy notifications configured for P0/P1 alerts
- [ ] Documentation updated

## Related Work

- **ADR-008:** Fix K3s Prometheus Alerts (disabled KubeProxyDown)
- **Story 3.2:** Configure Traefik Ingress Controller
- **Story 4.4:** Configure Alertmanager with Alert Rules
- **Epic 8:** Cluster Operations & Maintenance

## References

- [K3s Service Load Balancer Documentation](https://docs.k3s.io/networking#service-load-balancer)
- [K3s ServiceLB Controller Source](https://github.com/k3s-io/klipper-lb)
- [kube-state-metrics DaemonSet Metrics](https://github.com/kubernetes/kube-state-metrics/blob/main/docs/daemonset-metrics.md)

## Next Steps

1. Create alert rules in PrometheusRule
2. Create recovery runbook
3. Apply and test alerts
4. Update monitoring documentation
