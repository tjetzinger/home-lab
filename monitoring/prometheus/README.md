# Prometheus - Metrics Collection and Monitoring

**Story:** 4.1 - Deploy kube-prometheus-stack
**Epic:** 4 - Observability Stack
**Namespace:** `monitoring`

## What It Does

Prometheus is an open-source monitoring and alerting toolkit designed for reliability and scalability. It scrapes metrics from instrumented targets at intervals, stores time-series data, and provides a powerful query language (PromQL) for analysis and alerting.

## Why It Was Chosen

**Decision Rationale (ADR-004):**
- **Industry standard:** De facto monitoring solution for Kubernetes environments
- **Native Kubernetes integration:** Auto-discovers services, pods, and endpoints
- **kube-prometheus-stack:** Comprehensive bundle including Prometheus, Grafana, Alertmanager, and pre-configured dashboards
- **Pull-based model:** Prometheus scrapes targets (vs push-based), reducing client-side complexity
- **Powerful query language:** PromQL enables complex aggregations and alerting rules

**Alternatives Considered:**
- **Datadog/New Relic** → Rejected (SaaS cost, unnecessary for home lab)
- **InfluxDB + Telegraf** → Rejected (additional operational complexity, less Kubernetes-native)
- **Standalone Prometheus** → Rejected (kube-prometheus-stack provides better out-of-box experience)
- **VictoriaMetrics** → Considered (more efficient storage), but Prometheus ecosystem maturity preferred

## Key Configuration Decisions

### Deployment via kube-prometheus-stack

Prometheus is deployed as part of the `kube-prometheus-stack` Helm chart, which includes:
- **Prometheus Operator:** Manages Prometheus instances via CRDs
- **Prometheus:** Metrics collection and storage
- **Alertmanager:** Alert routing and notification
- **Grafana:** Metrics visualization
- **Node Exporter:** Host-level metrics (CPU, memory, disk, network)
- **kube-state-metrics:** Kubernetes object metrics (pods, deployments, services)
- **Pre-configured ServiceMonitors:** Automatic scraping of cluster components

### Metrics Retention

**Retention Period:** 7 days (168 hours)

```yaml
prometheus:
  prometheusSpec:
    retention: 7d
```

**Rationale:**
- Home lab context: 7 days sufficient for troubleshooting recent issues
- Storage efficiency: Balances historical data with NFS storage capacity
- Extension possible: Increase retention if storage capacity allows

### Scrape Configuration

**Scrape Interval:** 30 seconds (default)

**Targets Auto-Discovered:**
- **Kubernetes API Server** - Cluster health metrics
- **kubelet** - Node and pod metrics (cAdvisor built-in)
- **kube-state-metrics** - Kubernetes object state
- **Node Exporter** - OS-level metrics from all nodes
- **Traefik** - Ingress metrics (requests, latency)
- **cert-manager** - Certificate expiration metrics
- **Application metrics** - Any service exposing `/metrics` endpoint

**ServiceMonitor CRDs:**
The Prometheus Operator uses ServiceMonitor resources to define scrape targets:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: example-app
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: example
  endpoints:
    - port: metrics
      interval: 30s
```

### Storage

**PersistentVolumeClaim:** Prometheus data stored on NFS-backed PVC

```yaml
prometheus:
  prometheusSpec:
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: nfs-client
          resources:
            requests:
              storage: 20Gi  # Adjust based on retention and cardinality
```

**TSDB (Time Series Database):**
- Prometheus uses its own TSDB optimized for time-series data
- Data organized in 2-hour blocks, compacted over time
- Efficient compression for long-term storage

## How to Access/Use

### PromQL Queries

Access Prometheus UI for ad-hoc queries:

```bash
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
```

Navigate to: `http://localhost:9090`

**Example Queries:**
```promql
# CPU usage by pod
rate(container_cpu_usage_seconds_total[5m])

# Memory usage by namespace
sum(container_memory_usage_bytes) by (namespace)

# Pod restart count
kube_pod_container_status_restarts_total

# 95th percentile request latency for Traefik
histogram_quantile(0.95, rate(traefik_service_request_duration_seconds_bucket[5m]))
```

### Grafana Integration

Prometheus is pre-configured as a data source in Grafana:
- URL: `https://grafana.home.jetzinger.com`
- Pre-built dashboards for cluster, nodes, pods, and services
- Custom dashboards can query Prometheus via PromQL

### API Access

Query Prometheus API programmatically:

```bash
# Instant query
curl 'http://localhost:9090/api/v1/query?query=up'

# Range query
curl 'http://localhost:9090/api/v1/query_range?query=rate(http_requests_total[5m])&start=2026-01-08T00:00:00Z&end=2026-01-08T23:59:59Z&step=15s'
```

### Check Prometheus Status

View Prometheus pods:
```bash
kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus
```

Check Prometheus logs:
```bash
kubectl logs -n monitoring prometheus-prometheus-kube-prometheus-prometheus-0 -c prometheus
```

Verify scrape targets:
```bash
# Port-forward to Prometheus UI
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090

# Navigate to: http://localhost:9090/targets
# Shows all discovered targets and scrape health
```

## Deployment Details

**Helm Chart:** `prometheus-community/kube-prometheus-stack`
**Version:** As specified in Story 4.1 deployment
**Namespace:** `monitoring`

**Components:**
- `prometheus-operator` - Manages Prometheus instances
- `prometheus` StatefulSet - Metrics collection and storage
- `alertmanager` StatefulSet - Alert routing
- `grafana` Deployment - Visualization
- `kube-state-metrics` Deployment - Kubernetes object metrics
- `prometheus-node-exporter` DaemonSet - Host metrics (runs on all nodes)

**CRDs Installed:**
- `Prometheus` - Defines Prometheus instance
- `ServiceMonitor` - Defines scrape targets
- `PodMonitor` - Monitors pods directly
- `PrometheusRule` - Defines alerting and recording rules
- `Alertmanager` - Defines Alertmanager instance
- `ThanosRuler` - (Not used) For Thanos integration

## Integration Points

**Alertmanager:**
- Prometheus evaluates alert rules and sends firing alerts to Alertmanager
- Alertmanager handles deduplication, grouping, and routing to notification channels (ntfy.sh)

**Grafana:**
- Prometheus configured as default data source
- Pre-built dashboards visualize cluster health, node metrics, pod resources

**Loki:**
- Separate log aggregation system (not part of Prometheus)
- Both integrated in Grafana for correlated metrics + logs viewing

**ServiceMonitors:**
- Traefik: Ingress metrics (request rates, latency)
- cert-manager: Certificate expiration tracking
- Application metrics: Custom /metrics endpoints

## Monitoring

**Prometheus Self-Monitoring:**

Prometheus exposes its own metrics:
- `prometheus_tsdb_storage_blocks_bytes` - TSDB storage size
- `prometheus_tsdb_head_samples_appended_total` - Metric ingestion rate
- `prometheus_rule_evaluation_failures_total` - Alert rule evaluation errors

**Key Alerts (Pre-configured):**
- `PrometheusDown` - Prometheus instance unavailable
- `PrometheusTSDBCompactionsFailing` - TSDB compaction errors
- `PrometheusTargetScrapeMissing` - Target scrape failures

## Alerting Rules

Prometheus evaluates alerting rules and sends to Alertmanager when thresholds breach.

**Example Alert Rule:**
```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: node-alerts
  namespace: monitoring
spec:
  groups:
    - name: node.rules
      interval: 30s
      rules:
        - alert: NodeHighCPU
          expr: rate(node_cpu_seconds_total{mode="idle"}[5m]) < 0.2
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "Node {{ $labels.instance }} CPU usage high"
            description: "CPU idle < 20% for 5 minutes"
```

**Pre-configured Alert Groups:**
- Kubernetes cluster health
- Node resource exhaustion
- Pod crash loops and restarts
- Storage capacity warnings
- Certificate expiration

## Troubleshooting

**High Cardinality Issues:**
```bash
# Check metric cardinality
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090

# Navigate to: http://localhost:9090/tsdb-status
# Shows metric counts and label cardinality
```

**Scrape Failures:**
```bash
# Check Prometheus logs for scrape errors
kubectl logs -n monitoring prometheus-prometheus-kube-prometheus-prometheus-0 | grep -i error

# Verify ServiceMonitor configuration
kubectl get servicemonitor -n monitoring
kubectl describe servicemonitor <name> -n monitoring
```

**Storage Issues:**
```bash
# Check PVC status
kubectl get pvc -n monitoring

# Verify NFS mount health
kubectl describe pvc prometheus-prometheus-kube-prometheus-prometheus-db-prometheus-prometheus-kube-prometheus-prometheus-0
```

**Out of Memory:**
- Increase Prometheus memory limits if OOMKilled
- Reduce retention period to lower memory footprint
- Consider reducing scrape frequency for high-cardinality metrics

## Performance Tuning

**Resource Limits:**
```yaml
prometheus:
  prometheusSpec:
    resources:
      requests:
        cpu: 500m
        memory: 2Gi
      limits:
        cpu: 2000m
        memory: 4Gi
```

**Query Performance:**
- Use recording rules to pre-compute expensive queries
- Limit query time ranges for heavy aggregations
- Use Grafana query caching for frequently accessed dashboards

## Security Considerations

**Access Control:**
- Prometheus UI not exposed externally (port-forward only)
- Grafana provides authenticated access to Prometheus data
- RBAC controls Prometheus Operator CRD access

**Network Policies:**
- Consider NetworkPolicy to restrict Prometheus scraping to specific namespaces
- Limit ingress to Prometheus pods (only Grafana and Alertmanager should query)

**Data Retention:**
- 7-day retention limits exposure of historical metrics
- No PII or sensitive data should be stored in metric labels

## References

- [Prometheus Documentation](https://prometheus.io/docs/)
- [kube-prometheus-stack Chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [PromQL Basics](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Story 4.1 Implementation](../../docs/implementation-artifacts/4-1-deploy-kube-prometheus-stack.md)
- [ADR-004: kube-prometheus-stack](../../docs/adrs/ADR-004-kube-prometheus-stack.md)
- [Grafana Documentation](../grafana/README.md)
