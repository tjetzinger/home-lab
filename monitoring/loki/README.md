# Loki Log Aggregation

**Story:** 4.6 - Deploy Loki for Log Aggregation
**Epic:** 4 - Observability Stack

---

## Overview

Loki is a horizontally scalable, highly available log aggregation system inspired by Prometheus. This deployment provides centralized log collection and querying for the home-lab Kubernetes cluster.

**Components:**
- **Loki**: Log storage and query engine
- **Promtail**: Log collection agent (DaemonSet)
- **Grafana**: Visualization and query interface

**Deployment Mode:** Monolithic (all Loki components in single process, suitable for home lab scale)

---

## Deployment

```bash
# Add Grafana Helm repository
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Deploy Loki stack
helm upgrade --install loki grafana/loki \
  -f values-homelab.yaml \
  -n monitoring

# Verify deployment
kubectl get pods -n monitoring -l app.kubernetes.io/name=loki
kubectl get daemonset -n monitoring | grep promtail
```

---

## Configuration

**Namespace:** `monitoring`
**Storage:** NFS persistent storage via `nfs-client` StorageClass
**Retention:** 7 days (NFR19 compliance)

**Resource Limits:**
- Loki: 500m-1000m CPU, 1-2Gi memory
- Promtail: 50m-200m CPU, 128-256Mi memory

**Log Collection:**
- Promtail runs as DaemonSet on all nodes (control plane + workers)
- Automatically discovers pods and scrapes container logs
- Adds labels: namespace, pod, container

---

## Grafana Integration

**Data Source:**
- Name: Loki
- Type: Loki
- URL: `http://loki.monitoring.svc.cluster.local:3100`

**Provisioning:**
Data source is provisioned via kube-prometheus-stack Helm values for automated configuration.

---

## Usage

**Access Logs via Grafana:**
1. Open Grafana: https://grafana.home.jetzinger.com
2. Navigate to **Explore**
3. Select **Loki** data source
4. Run LogQL queries

**Example Queries:**
```logql
# All logs from monitoring namespace
{namespace="monitoring"}

# Logs from specific pod
{namespace="monitoring", pod="alertmanager-kube-prometheus-stack-alertmanager-0"}

# Search for errors
{namespace="monitoring"} |= "error"

# Filter by severity
{namespace="monitoring"} | json | level="error"
```

---

## Architecture

**Storage Flow:**
```
Pods → Promtail (DaemonSet) → Loki → NFS Storage
                                   ↓
                              Grafana (queries)
```

**NFR Compliance:**
- NFR19: 7-day log retention (configured in Loki limits_config)
- Logs automatically pruned after retention period

---

## Troubleshooting

**Loki pod not starting:**
```bash
kubectl describe pod -n monitoring -l app.kubernetes.io/name=loki
kubectl logs -n monitoring -l app.kubernetes.io/name=loki
```

**Promtail not collecting logs:**
```bash
kubectl get daemonset -n monitoring
kubectl logs -n monitoring -l app.kubernetes.io/name=promtail --tail=50
```

**No logs in Grafana:**
1. Verify Loki data source connection in Grafana
2. Check Promtail is running on all nodes
3. Verify Promtail logs show successful scraping
4. Test LogQL query: `{namespace="monitoring"}` in Grafana Explore

---

## Related Documentation

- [Story 4.6 - Deploy Loki for Log Aggregation](../../docs/implementation-artifacts/4-6-deploy-loki-for-log-aggregation.md)
- [Loki Documentation](https://grafana.com/docs/loki/latest/)
- [LogQL Query Language](https://grafana.com/docs/loki/latest/logql/)
- [Promtail Configuration](https://grafana.com/docs/loki/latest/clients/promtail/)

---

## Change Log

- 2026-01-06: Initial Loki deployment for centralized log aggregation
