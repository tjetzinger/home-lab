# Kubernetes Dashboard

Kubernetes Dashboard provides a web-based UI for cluster visualization.

**Story:** 18.1 - Deploy Kubernetes Dashboard
**Epic:** 18 - Cluster Visualization Dashboard

## Components

| Component | Description |
|-----------|-------------|
| kubernetes-dashboard-api | Dashboard backend API |
| kubernetes-dashboard-auth | Authentication service |
| kubernetes-dashboard-kong | API gateway proxy |
| kubernetes-dashboard-web | Web UI frontend |
| kubernetes-dashboard-metrics-scraper | Metrics collection |

## Requirements Implemented

- **FR130:** Kubernetes Dashboard deployed in `infra` namespace
- **FR133:** Dashboard provides read-only view of all namespaces, pods, and resources
- **NFR77:** Dashboard loads cluster overview within 5 seconds (measured: 0.159s)

## Access

### Port-Forward (Development)

```bash
# Start port-forward
kubectl port-forward -n infra svc/kubernetes-dashboard-kong-proxy 9443:80

# Access dashboard
open http://localhost:9443
```

### Generate Access Token

```bash
# Generate token valid for 8760 hours (1 year)
kubectl create token dashboard-viewer -n infra --duration=8760h

# Or for shorter duration (1 hour)
kubectl create token dashboard-viewer -n infra --duration=1h
```

### Login

1. Access dashboard URL
2. Select "Token" authentication
3. Paste generated bearer token
4. Click "Sign In"

## RBAC Configuration

The `dashboard-viewer` ServiceAccount uses the built-in `view` ClusterRole:

| Permission | Allowed |
|------------|---------|
| Get, List, Watch | ✅ All resources |
| Create, Update, Delete | ❌ Blocked |
| Exec into pods | ❌ Blocked |

## Files

| File | Description |
|------|-------------|
| `values-homelab.yaml` | Helm chart configuration |
| `rbac.yaml` | ServiceAccount and ClusterRoleBinding |

## Helm Chart

```bash
# Add repository
helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/

# Install/upgrade
helm upgrade --install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard \
  -f values-homelab.yaml \
  -n infra

# Verify deployment
kubectl get pods -n infra -l app.kubernetes.io/name=kubernetes-dashboard
```

## Troubleshooting

### Check pod status
```bash
kubectl get pods -n infra -l app.kubernetes.io/name=kubernetes-dashboard
```

### Check logs
```bash
kubectl logs -n infra -l app.kubernetes.io/name=kubernetes-dashboard --all-containers
```

### Verify RBAC
```bash
kubectl auth can-i list pods --as=system:serviceaccount:infra:dashboard-viewer -A
# Should return: yes

kubectl auth can-i delete pods --as=system:serviceaccount:infra:dashboard-viewer -A
# Should return: no
```

## Related Stories

- **Story 18.2:** Configure Dashboard Ingress and Authentication (adds HTTPS access)
