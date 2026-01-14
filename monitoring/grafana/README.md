# Grafana - Metrics Visualization and Dashboards

**Story:** 4.2 - Configure Grafana Dashboards and Ingress
**Epic:** 4 - Observability Stack
**Namespace:** `monitoring`

## What It Does

Grafana is an open-source analytics and interactive visualization platform. It provides dashboards to visualize time-series data from Prometheus, logs from Loki, and other data sources, enabling comprehensive observability for the Kubernetes cluster.

## Why It Was Chosen

**Decision Rationale (ADR-004):**
- **Bundled with kube-prometheus-stack:** Integrated deployment with Prometheus and Alertmanager
- **Pre-built Kubernetes dashboards:** Out-of-box visibility into cluster health, nodes, pods, and services
- **Multi-source support:** Unified view of metrics (Prometheus) and logs (Loki)
- **Customization:** Flexible dashboard creation for application-specific monitoring
- **Community ecosystem:** Extensive library of community dashboards

**Alternatives Considered:**
- **Kibana** → Rejected (designed for Elasticsearch, not ideal for Prometheus metrics)
- **Chronograf** → Rejected (InfluxDB-focused, less Kubernetes ecosystem integration)
- **Prometheus Console Templates** → Rejected (limited visualization, less user-friendly)

## Key Configuration Decisions

### Deployment via kube-prometheus-stack

Grafana is deployed as part of the `kube-prometheus-stack` Helm chart:
- **Automatic Prometheus integration:** Pre-configured data source
- **Pre-loaded dashboards:** Kubernetes cluster, nodes, pods, workloads
- **Persistent storage:** Dashboard customizations saved to NFS-backed PVC
- **Ingress configuration:** Accessible via HTTPS at `grafana.home.jetzinger.com`

### Data Sources

**Prometheus (Primary):**
- URL: `http://prometheus-kube-prometheus-prometheus.monitoring.svc:9090`
- Type: Prometheus
- Default: Yes
- Usage: Cluster metrics, application metrics, alerting data

**Loki (Logs):**
- URL: `http://loki.monitoring.svc:3100`
- Type: Loki
- Usage: Log aggregation and querying

### Pre-Built Dashboards

kube-prometheus-stack includes comprehensive dashboards:

**Cluster Overview:**
- Kubernetes / Compute Resources / Cluster
- Kubernetes / Compute Resources / Namespace (Pods)
- Kubernetes / Compute Resources / Namespace (Workloads)
- Kubernetes / Networking / Cluster

**Node Metrics:**
- Node Exporter / Nodes
- Node Exporter / USE Method / Node

**Pod & Container:**
- Kubernetes / Compute Resources / Pod
- Kubernetes / Compute Resources / Container

**Persistent Storage:**
- Kubernetes / Persistent Volumes

**Prometheus & Alerting:**
- Prometheus / Overview
- Alertmanager / Overview

### Ingress Configuration

**URL:** `https://grafana.home.jetzinger.com`

**TLS Certificate:** Managed by cert-manager (Let's Encrypt)

**Access Control:**
- Tailscale VPN required (no public internet exposure)
- Ingress routes through Traefik (MetalLB IP: 192.168.2.100)
- Basic authentication via Grafana login

**IngressRoute:**
```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: grafana
  namespace: monitoring
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`grafana.home.jetzinger.com`)
      kind: Rule
      services:
        - name: grafana
          port: 80
  tls:
    secretName: grafana-tls  # cert-manager managed
```

### Persistence

**PersistentVolumeClaim:** Dashboard configurations and user preferences stored on NFS

```yaml
grafana:
  persistence:
    enabled: true
    storageClassName: nfs-client
    size: 5Gi
```

**Data Stored:**
- Custom dashboards
- User accounts and permissions
- Dashboard settings and variables
- Annotations

## How to Access/Use

### Web UI Access

Navigate to: **https://grafana.home.jetzinger.com**

**Login Credentials:**
- Default admin user credentials configured during deployment
- Stored in Kubernetes Secret: `grafana` (namespace: `monitoring`)

```bash
# Retrieve admin password
kubectl get secret grafana -n monitoring -o jsonpath="{.data.admin-password}" | base64 --decode
```

### Creating Custom Dashboards

**Option 1: Web UI**
1. Navigate to `+` icon → Dashboard
2. Add panels with PromQL queries
3. Configure visualizations (graphs, gauges, tables)
4. Save dashboard

**Option 2: Import Community Dashboards**
1. Navigate to `+` icon → Import
2. Enter dashboard ID from [Grafana Dashboards](https://grafana.com/grafana/dashboards/)
3. Configure data source (Prometheus)
4. Import

**Option 3: Dashboard as Code (ConfigMap)**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: custom-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  custom-dashboard.json: |
    {
      "dashboard": { ... },
      "overwrite": true
    }
```

### Viewing Logs with Loki

**Explore Tab:**
1. Click "Explore" icon (compass)
2. Select "Loki" data source
3. Query logs using LogQL:

```logql
# All logs from namespace
{namespace="monitoring"}

# Pod-specific logs
{pod="prometheus-prometheus-kube-prometheus-prometheus-0"}

# Error logs across cluster
{} |= "error" |= "ERROR"

# Rate of errors per minute
rate({job="varlogs"}[1m]) | json | level="error"
```

**Logs Panel in Dashboards:**
Dashboards can include log panels to correlate metrics + logs:
- Add panel → Logs
- Select Loki data source
- Configure LogQL query

### Alerting in Grafana

Grafana can create alerts based on dashboard queries:
- Navigate to dashboard panel → Edit
- Add Alert rule
- Configure thresholds and notification channels

**Note:** Prometheus Alertmanager is preferred for Kubernetes-native alerting (configured in Story 4.4).

## Deployment Details

**Helm Chart:** `prometheus-community/kube-prometheus-stack` (Grafana sub-chart)
**Version:** As specified in Story 4.1/4.2 deployment
**Namespace:** `monitoring`

**Components:**
- `grafana` Deployment - Web UI and backend
- `grafana` Service - ClusterIP (behind Traefik Ingress)
- `grafana` PVC - Persistent dashboard storage

**Configuration:**
- Admin credentials stored in Secret
- Data sources defined in ConfigMaps (auto-provisioned)
- Dashboards loaded via ConfigMaps with `grafana_dashboard: "1"` label

## Integration Points

**Prometheus:**
- Primary data source for metrics queries
- Pre-configured dashboards query Prometheus via PromQL
- Alerting data visualization (Alertmanager integration)

**Loki:**
- Secondary data source for log aggregation
- Enables correlated metrics + logs debugging
- Explore UI for ad-hoc log queries

**Alertmanager:**
- Dashboard displays active alerts and alert history
- Alert rules managed in Prometheus, visualized in Grafana

**Traefik Ingress:**
- External HTTPS access via `grafana.home.jetzinger.com`
- Automatic TLS certificate from cert-manager

## Monitoring

**Grafana Self-Monitoring:**

Grafana exposes Prometheus metrics at `:3000/metrics`:
- `grafana_api_response_status_total` - API request counts and status codes
- `grafana_database_queries_total` - Database query performance
- `grafana_alerting_*` - Alert rule execution metrics

**Usage Metrics:**
- Dashboard view counts
- Query execution times
- User activity

## Troubleshooting

**Cannot Access Web UI:**
```bash
# Check Grafana pod status
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana

# View Grafana logs
kubectl logs -n monitoring deployment/grafana -f

# Verify Ingress configuration
kubectl get ingressroute grafana -n monitoring
kubectl describe ingressroute grafana -n monitoring
```

**Data Source Connection Failed:**
```bash
# Verify Prometheus is reachable from Grafana pod
kubectl exec -n monitoring deployment/grafana -- curl http://prometheus-kube-prometheus-prometheus.monitoring.svc:9090/-/healthy

# Check Loki health
kubectl exec -n monitoring deployment/grafana -- curl http://loki.monitoring.svc:3100/ready
```

**Dashboards Not Loading:**
```bash
# Check ConfigMaps with dashboard label
kubectl get configmaps -n monitoring -l grafana_dashboard=1

# Verify Grafana provisioning logs
kubectl logs -n monitoring deployment/grafana | grep -i provision
```

**Forgot Admin Password:**
```bash
# Reset admin password via Secret
kubectl patch secret grafana -n monitoring -p '{"data":{"admin-password":"'$(echo -n "newpassword" | base64)'"}}'

# Restart Grafana to pick up change
kubectl rollout restart deployment/grafana -n monitoring
```

## Performance Tuning

**Resource Limits:**
```yaml
grafana:
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 512Mi
```

**Query Performance:**
- Use dashboard query caching to reduce Prometheus load
- Limit time ranges for expensive queries
- Use template variables to parameterize dashboards

**Database:**
- Grafana uses SQLite by default (stored in PVC)
- For high-concurrency, consider external PostgreSQL

## Security Considerations

**Authentication:**
- Admin user required for UI access
- Support for OAuth, LDAP, SAML (not configured in home lab)
- Consider disabling anonymous access

**Authorization:**
- Role-based access control (Viewer, Editor, Admin)
- Dashboard permissions can restrict editing

**Network Exposure:**
- Access only via Tailscale VPN (no public internet)
- HTTPS enforced via Traefik and cert-manager

**Data Protection:**
- Dashboards may contain sensitive infrastructure details
- Ensure proper access controls for production deployments

## Customization

**Theme:**
Default theme: Dark (configurable per-user or globally)

**Plugins:**
Grafana supports plugins for extended functionality:
```bash
# Install plugin via kubectl
kubectl exec -n monitoring deployment/grafana -- grafana-cli plugins install <plugin-id>
kubectl rollout restart deployment/grafana -n monitoring
```

**Dashboard Variables:**
Use variables for dynamic filtering:
- Namespace selector
- Pod name selector
- Time range picker

## References

- [Grafana Documentation](https://grafana.com/docs/grafana/latest/)
- [Grafana Dashboards Library](https://grafana.com/grafana/dashboards/)
- [PromQL Query Guide](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [LogQL Query Guide](https://grafana.com/docs/loki/latest/logql/)
- [Story 4.2 Implementation](../../docs/implementation-artifacts/4-2-configure-grafana-dashboards-and-ingress.md)
- [ADR-004: kube-prometheus-stack](../../docs/adrs/ADR-004-kube-prometheus-stack.md)
- [Visual Tour (Screenshots)](../../docs/VISUAL_TOUR.md)
