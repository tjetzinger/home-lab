# Loki Log Aggregation Setup

**Purpose:** Configure Loki and Promtail for centralized log aggregation across the home-lab Kubernetes cluster

**Story:** 4.6 - Deploy Loki for Log Aggregation
**Date Created:** 2026-01-06
**Last Updated:** 2026-01-06

---

## Overview

This runbook documents the deployment and configuration of Loki (log storage) and Promtail (log collection) for centralized logging in the home-lab cluster.

**Components:**
- **Loki**: Log aggregation and query engine (SingleBinary mode)
- **Promtail**: Log collection agent (DaemonSet on all nodes)
- **Grafana**: Visualization and query interface

**Key Features:**
- 7-day log retention (NFR19 compliant)
- NFS persistent storage
- Automatic log collection from all pods
- LogQL query interface via Grafana

---

## Prerequisites

- kube-prometheus-stack deployed in `monitoring` namespace
- Grafana running and accessible
- NFS storage provisioner (`nfs-client` StorageClass)
- Helm installed
- kubectl access to cluster

---

## Deployment

### Step 1: Add Grafana Helm Repository

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
```

### Step 2: Deploy Loki

```bash
# Deploy Loki via Helm
helm upgrade --install loki grafana/loki \
  -f /home/tt/Workspace/home-lab/monitoring/loki/values-homelab.yaml \
  -n monitoring

# Verify Loki deployment
kubectl get pods -n monitoring -l app.kubernetes.io/name=loki
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=loki -n monitoring --timeout=120s
```

### Step 3: Deploy Promtail

```bash
# Deploy Promtail via Helm
helm upgrade --install promtail grafana/promtail \
  -f /home/tt/Workspace/home-lab/monitoring/loki/promtail-values-homelab.yaml \
  -n monitoring

# Verify Promtail DaemonSet
kubectl get daemonset -n monitoring promtail
kubectl get pods -n monitoring -l app.kubernetes.io/name=promtail -o wide
```

### Step 4: Configure Grafana Data Source

Update `monitoring/prometheus/values-homelab.yaml` to add Loki data source:

```yaml
grafana:
  additionalDataSources:
    - name: Loki
      type: loki
      access: proxy
      url: http://loki.monitoring.svc.cluster.local:3100
      jsonData:
        maxLines: 1000
```

Then upgrade kube-prometheus-stack:

```bash
helm upgrade kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -f /home/tt/Workspace/home-lab/monitoring/prometheus/values-homelab.yaml \
  -n monitoring
```

---

## Verification

### Check Loki Status

```bash
# Verify Loki pod is running
kubectl get pods -n monitoring -l app.kubernetes.io/name=loki

# Check Loki logs
kubectl logs -n monitoring -l app.kubernetes.io/name=loki --tail=20

# Test Loki readiness endpoint
kubectl exec -n monitoring deployment/kube-prometheus-stack-grafana -- \
  curl -s http://loki.monitoring.svc.cluster.local:3100/ready
```

### Check Promtail Status

```bash
# Verify Promtail DaemonSet (should have 3 pods for 3-node cluster)
kubectl get daemonset -n monitoring promtail

# Check Promtail pods on each node
kubectl get pods -n monitoring -l app.kubernetes.io/name=promtail -o wide

# Check Promtail logs for scraping activity
kubectl logs -n monitoring -l app.kubernetes.io/name=promtail --tail=20
```

### Verify Log Collection

```bash
# Query available namespaces
kubectl exec -n monitoring deployment/kube-prometheus-stack-grafana -- \
  curl -s 'http://loki.monitoring.svc.cluster.local:3100/loki/api/v1/label/namespace/values'

# Query logs from monitoring namespace
kubectl exec -n monitoring deployment/kube-prometheus-stack-grafana -- \
  curl -s -G 'http://loki.monitoring.svc.cluster.local:3100/loki/api/v1/query_range' \
  --data-urlencode 'query={namespace="monitoring"}' \
  --data-urlencode 'limit=5'
```

### Verify Retention Configuration

```bash
# Check retention settings
kubectl exec -n monitoring deployment/kube-prometheus-stack-grafana -- \
  curl -s 'http://loki.monitoring.svc.cluster.local:3100/config' | grep -i retention_period

# Expected output: retention_period: 1w (7 days)
```

---

## Using Loki in Grafana

### Access Grafana

1. Open browser: https://grafana.home.jetzinger.com
2. Login with admin credentials
3. Navigate to **Explore** (compass icon in left sidebar)
4. Select **Loki** from the data source dropdown

### Basic LogQL Queries

```logql
# All logs from monitoring namespace
{namespace="monitoring"}

# Logs from specific pod
{namespace="monitoring", pod="alertmanager-kube-prometheus-stack-alertmanager-0"}

# Logs from specific container
{namespace="monitoring", pod="loki-0", container="loki"}

# Filter by node
{node_name="k3s-master"}

# Search for errors
{namespace="monitoring"} |= "error"

# Search for errors (case insensitive)
{namespace="monitoring"} |~ "(?i)error"

# Filter by log level (if parsed)
{namespace="monitoring"} | json | level="error"

# Count log lines
count_over_time({namespace="monitoring"}[5m])

# Rate of logs per second
rate({namespace="monitoring"}[1m])
```

### Advanced Queries

```logql
# Logs from multiple namespaces
{namespace=~"monitoring|kube-system"}

# Exclude specific pods
{namespace="monitoring", pod!~"loki.*"}

# Parse JSON logs
{namespace="monitoring"} | json | line_format "{{.level}}: {{.message}}"

# Extract fields from log lines
{namespace="monitoring"} | regexp "(?P<method>GET|POST) (?P<path>/\\S+)"

# Filter by extracted field
{namespace="monitoring"} | json | path="/api/v1/query"
```

---

## Troubleshooting

### Loki Pod Not Starting

**Symptoms:**
- Loki pod in CrashLoopBackOff or Error state

**Diagnosis:**
```bash
kubectl describe pod -n monitoring -l app.kubernetes.io/name=loki
kubectl logs -n monitoring -l app.kubernetes.io/name=loki
```

**Common Issues:**
1. Configuration error in values-homelab.yaml
2. PVC not bound (check NFS provisioner)
3. Insufficient resources

**Resolution:**
- Fix configuration errors and upgrade Helm release
- Verify NFS provisioner is running
- Check node resources with `kubectl top nodes`

### Promtail Not Collecting Logs

**Symptoms:**
- No logs appearing in Grafana
- Loki labels API returns empty namespaces

**Diagnosis:**
```bash
kubectl get daemonset -n monitoring promtail
kubectl logs -n monitoring -l app.kubernetes.io/name=promtail --tail=50
```

**Common Issues:**
1. Promtail not running on all nodes
2. Promtail can't reach Loki service
3. Log path configuration incorrect

**Resolution:**
- Verify Promtail pods on all nodes: `kubectl get pods -n monitoring -l app.kubernetes.io/name=promtail -o wide`
- Test Loki connectivity from Promtail pod
- Check tolerations in promtail-values-homelab.yaml

### No Logs in Grafana

**Symptoms:**
- Loki data source shows "Data source is working" but no logs returned

**Diagnosis:**
```bash
# Test Loki API directly
kubectl exec -n monitoring deployment/kube-prometheus-stack-grafana -- \
  curl -s 'http://loki.monitoring.svc.cluster.local:3100/loki/api/v1/label/namespace/values'

# Check Promtail is scraping
kubectl logs -n monitoring -l app.kubernetes.io/name=promtail | grep "tail routine: started"
```

**Resolution:**
- Wait 1-2 minutes for logs to appear after deployment
- Verify Promtail is running and scraping logs
- Check LogQL query syntax in Grafana Explore

### Loki Data Source Connection Failed

**Symptoms:**
- Grafana shows "Data source not working" error

**Diagnosis:**
```bash
# Test from Grafana pod
kubectl exec -n monitoring deployment/kube-prometheus-stack-grafana -- \
  curl -s http://loki.monitoring.svc.cluster.local:3100/ready
```

**Resolution:**
- Verify Loki service exists: `kubectl get svc -n monitoring | grep loki`
- Check Loki pod is running and ready
- Verify data source URL in Grafana settings

### High Memory Usage

**Symptoms:**
- Loki pod OOMKilled or restarting frequently

**Diagnosis:**
```bash
kubectl top pod -n monitoring -l app.kubernetes.io/name=loki
```

**Resolution:**
- Increase memory limits in values-homelab.yaml
- Reduce retention period or log volume
- Consider upgrading to distributed Loki deployment

---

## Configuration Reference

### Current Setup

| Component | Value |
|-----------|-------|
| Loki Version | 3.6.3 |
| Loki Helm Chart | 6.49.0 |
| Promtail Version | 3.5.1 |
| Promtail Helm Chart | 6.17.1 |
| Deployment Mode | SingleBinary |
| Storage | NFS (nfs-client, 10Gi PVC) |
| Retention Period | 7 days (168h) |
| Loki Endpoint | http://loki.monitoring.svc.cluster.local:3100 |
| Namespace | monitoring |

### Resource Allocation

| Component | CPU Request | CPU Limit | Memory Request | Memory Limit |
|-----------|------------|-----------|----------------|--------------|
| Loki | 500m | 1000m | 1Gi | 2Gi |
| Promtail (per pod) | 50m | 200m | 128Mi | 256Mi |

### Promtail Nodes

- k3s-master (control plane)
- k3s-worker-01
- k3s-worker-02

**Total:** 3 Promtail pods (1 per node)

---

## Related Documentation

- [Story 4.6 - Deploy Loki for Log Aggregation](../implementation-artifacts/4-6-deploy-loki-for-log-aggregation.md)
- [Loki Documentation](https://grafana.com/docs/loki/latest/)
- [LogQL Query Language](https://grafana.com/docs/loki/latest/logql/)
- [Promtail Configuration](https://grafana.com/docs/loki/latest/clients/promtail/)
- [kube-prometheus-stack Chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)

---

## Change Log

- 2026-01-06: Initial runbook creation - Loki and Promtail deployed successfully
