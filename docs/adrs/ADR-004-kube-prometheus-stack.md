# ADR-004: kube-prometheus-stack for Observability

**Status:** Accepted
**Date:** 2026-01-07
**Decision Makers:** Tom, Claude (AI Assistant)

## Context

The home-lab K3s cluster requires comprehensive observability to meet NFRs and demonstrate production-ready monitoring practices for portfolio purposes. The cluster must provide metrics, dashboards, alerting, and log aggregation across 8+ namespaces and 15+ services.

Requirements:
- **NFR21:** All components expose Prometheus metrics
- **NFR22:** Grafana dashboards for cluster health
- **NFR23:** 7-day metric retention minimum
- **NFR20:** Alertmanager for critical alerts
- **Portfolio goal:** Demonstrate production observability patterns
- **Operational:** Single operator, weekend-based implementation

Target metrics collection:
- K3s cluster health (nodes, pods, deployments)
- PostgreSQL (connections, queries, replication)
- Ollama (inference requests, model loading)
- Ingress traffic (Traefik HTTP metrics)
- Storage (NFS PVC usage)

## Decision Drivers

- **NFR compliance** - Prometheus metrics required across all components
- **Integration complexity** - Pre-integrated stack vs managing component versions
- **Learning value** - Understanding full observability stack vs partial monitoring
- **Community support** - Mature, well-documented solutions preferred
- **Portfolio demonstration** - Complete observability shows production readiness
- **Time efficiency** - Single Helm deployment vs multiple installations
- **Operational simplicity** - Unified configuration, fewer troubleshooting surfaces

## Considered Options

### Option 1: kube-prometheus-stack (All-in-One Helm Chart) - Selected

**Pros:**
- **Complete stack** - Prometheus, Grafana, Alertmanager, node-exporter, kube-state-metrics all included
- **Pre-integrated** - Components configured to work together out-of-the-box
- **Production-ready** - Based on Prometheus Operator pattern used at scale
- **Rich dashboards** - 15+ pre-built Grafana dashboards for K8s monitoring
- **Single deployment** - One Helm chart, unified values configuration
- **Active maintenance** - prometheus-community Helm chart, thousands of production deployments
- **ServiceMonitor CRD** - Declarative metric scraping configuration
- **Alert rules included** - Pre-configured critical alerts for K8s components

**Cons:**
- Higher resource overhead (Prometheus, Grafana, Alertmanager all running)
- Large Helm chart (complex values.yaml, many configuration options)
- Opinionated architecture (Prometheus Operator CRDs)
- Potential version conflicts if individual components need customization

### Option 2: Individual Component Installation (Prometheus + Grafana + Alertmanager)

**Pros:**
- Granular control over each component version
- Smaller resource footprint (install only what's needed)
- Simpler troubleshooting (fewer abstraction layers)
- Flexible architecture (swap components independently)

**Cons:**
- **High integration complexity** - Manual configuration of Prometheus datasource, Alertmanager config, ServiceMonitor discovery
- **No pre-built dashboards** - Must create or import each dashboard manually
- **Multiple Helm deployments** - Separate installation steps, version compatibility testing
- **Time overhead** - Significantly longer implementation vs all-in-one
- **Operational burden** - More components to upgrade, backup, monitor independently

### Option 3: Victoria Metrics (Prometheus-Compatible Alternative)

**Pros:**
- Lower resource usage (optimized TSDB)
- Better long-term storage efficiency
- Prometheus-compatible query language (PromQL)
- Horizontal scalability built-in

**Cons:**
- **Learning curve** - Different architecture (vmselect, vmstorage, vminsert)
- Smaller community vs Prometheus ecosystem
- Fewer integrations with third-party tools
- No significant advantage at home lab scale (<100 metrics/sec)
- Adds unfamiliar technology (reduces portfolio clarity)

### Option 4: Cloud Monitoring (Grafana Cloud, Datadog, New Relic)

**Pros:**
- Zero infrastructure overhead (SaaS)
- Managed scaling, upgrades, retention
- Advanced features (APM, distributed tracing, log aggregation)
- Mobile apps for on-the-go monitoring

**Cons:**
- **Cost** - Monthly subscription fees (not suitable for home lab)
- **Data egress** - Sending metrics outside network (privacy, bandwidth)
- **Portfolio value loss** - Doesn't demonstrate self-hosted observability skills
- **Vendor lock-in** - Platform-specific configurations
- **Dependency** - Requires internet connectivity for dashboard access

## Decision

**Deploy kube-prometheus-stack Helm chart (all-in-one observability platform)**

Implementation specifications:
- **Helm chart:** `prometheus-community/kube-prometheus-stack`
- **Namespace:** `monitoring`
- **Components enabled:**
  - Prometheus (metrics collection, TSDB)
  - Grafana (dashboards, visualization)
  - Alertmanager (alert routing, notification)
  - node-exporter (node-level metrics)
  - kube-state-metrics (K8s object metrics)
- **Storage:** NFS-backed PVC (7-day retention = ~10GB estimated)
- **Ingress:** `grafana.home.jetzinger.com` (Traefik + cert-manager)
- **Retention:** 7 days (NFR23 compliance)

## Consequences

### Positive

- **Fast implementation** - Single `helm install` command deploys entire stack
- **Immediate value** - 15+ pre-built dashboards operational from day one
- **Production patterns** - Prometheus Operator CRDs used in enterprise environments
- **Portfolio credibility** - Demonstrates knowledge of industry-standard observability
- **Unified management** - Single Helm values file controls entire stack
- **ServiceMonitor discovery** - Auto-discovers metrics endpoints via labels
- **Alert automation** - Critical K8s alerts (node down, pod crash-looping) pre-configured
- **Integration ready** - Loki, Tempo can integrate seamlessly (Grafana datasources)

### Negative

- **Resource overhead** - ~2GB RAM for Prometheus + Grafana + Alertmanager
- **Configuration complexity** - Large values.yaml (100+ options)
- **Upgrade caution** - CRD upgrades require careful migration
- **Over-provisioned** - Some features (federation, Thanos sidecar) unused at home lab scale

### Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Prometheus disk usage exceeds NFS allocation | Monitor via Grafana; 7-day retention = ~10GB; can extend NFS PVC if needed |
| Grafana performance issues (slow dashboards) | Home lab scale (<100 series) well within Grafana limits; optimize queries if needed |
| Alert fatigue (too many notifications) | Start with critical alerts only; tune thresholds based on actual usage patterns |
| Helm chart version upgrades break CRDs | Follow prometheus-community upgrade guide; test in non-prod namespace first; backup CRDs before upgrade |
| Prometheus scrape failures | ServiceMonitor troubleshooting documented; Prometheus UI shows scrape errors |

## Implementation Notes

**Helm Deployment:**
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -f monitoring/prometheus/values-homelab.yaml \
  -n monitoring --create-namespace
```

**Key Values Configuration:**
```yaml
prometheus:
  prometheusSpec:
    retention: 7d
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: nfs-client
          resources:
            requests:
              storage: 20Gi

grafana:
  enabled: true
  adminPassword: <sealed-secret>
  ingress:
    enabled: true
    annotations:
      cert-manager.io/cluster-issuer: letsencrypt-prod
    hosts:
      - grafana.home.jetzinger.com
    tls:
      - secretName: grafana-tls
        hosts:
          - grafana.home.jetzinger.com

alertmanager:
  enabled: true
  config:
    route:
      receiver: 'null'  # Configure mobile notifications in Story 4.5
```

**Validation:**
```bash
kubectl get pods -n monitoring
kubectl get servicemonitors -n monitoring
kubectl get prometheusrules -n monitoring
```

**Access Grafana:**
- URL: https://grafana.home.jetzinger.com (via Tailscale VPN)
- Default dashboards: Kubernetes / Compute Resources / Namespace (Pods), Node Exporter / Nodes

**ServiceMonitor Example (Auto-Discovery):**
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: postgres-metrics
  namespace: data
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: postgresql
  endpoints:
    - port: metrics
      interval: 30s
```

**Future Enhancements (Phase 2):**
- Integrate Loki for log aggregation (Grafana datasource)
- Add Tempo for distributed tracing
- Configure Thanos for long-term storage (multi-month retention)
- Implement Alertmanager webhook to ntfy.sh (mobile notifications)

## References

- [Architecture Decision: Observability Architecture](../planning-artifacts/architecture.md#observability-architecture)
- [kube-prometheus-stack Helm Chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [Prometheus Operator Documentation](https://prometheus-operator.dev/)
- [Grafana Dashboard Repository](https://grafana.com/grafana/dashboards/)
- [Story 4.1: Deploy kube-prometheus-stack](../implementation-artifacts/sprint-status.yaml)
- [Story 4.2: Configure Grafana Dashboards and Ingress](../implementation-artifacts/sprint-status.yaml)
- [NFR21, NFR22, NFR23: Observability Requirements](../planning-artifacts/prd.md)
