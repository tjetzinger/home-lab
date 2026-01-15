# Gitea Self-Hosted Git Service

**Purpose:** Self-hosted Git repository service for local code hosting

**Story:** 19.1 - Deploy Gitea with PostgreSQL Backend
**Epic:** 19 - Self-Hosted Git Service (Gitea)
**Namespace:** `dev`

---

## Overview

Gitea is deployed as a lightweight self-hosted Git service using the official Helm chart, providing a reliable platform for local repository hosting with PostgreSQL backend storage.

**Key Features:**
- PostgreSQL backend for metadata persistence
- NFS-backed persistent storage for repositories (FR136)
- Single-user mode with registration disabled (FR137)
- Memory-based caching for lightweight operation

---

## Deployment

### Prerequisites

- `dev` namespace exists
- PostgreSQL service available at `postgres-postgresql.data.svc.cluster.local:5432`
- NFS storage provisioner available
- `gitea` database created in PostgreSQL

### Deploy Gitea

```bash
# Add Gitea Helm repository
helm repo add gitea-charts https://dl.gitea.com/charts/
helm repo update

# Deploy Gitea
helm upgrade --install gitea gitea-charts/gitea \
  -f values-homelab.yaml \
  -n dev

# Verify deployment
kubectl get pods -n dev -l app.kubernetes.io/name=gitea
kubectl get svc -n dev -l app.kubernetes.io/name=gitea
```

---

## Access

### Internal Cluster Access

**HTTP Service:** `gitea-http.dev.svc.cluster.local:3000`
**SSH Service:** `gitea-ssh.dev.svc.cluster.local:22`

### Port Forward for Local Access

```bash
# Web interface
kubectl port-forward svc/gitea-http -n dev 3000:3000

# Access at http://localhost:3000
```

### Default Admin Credentials

**Username:** admin
**Password:** gitea-admin-2026

---

## Configuration

### Current Setup

| Setting | Value |
|---------|-------|
| Chart | gitea-charts/gitea |
| Chart Version | Latest |
| Namespace | dev |
| HTTP Service Type | ClusterIP |
| HTTP Port | 3000 |
| SSH Service Type | ClusterIP |
| SSH Port | 22 |
| Persistence | NFS-backed PVC (10Gi) |
| Storage Class | nfs-client |
| Database | PostgreSQL (external) |
| Cache | Memory |
| Session | Memory |

### PostgreSQL Configuration

| Setting | Value |
|---------|-------|
| Host | postgres-postgresql.data.svc.cluster.local |
| Port | 5432 |
| Database | gitea |
| User | gitea |
| Password | gitea-homelab-2026 |

### Resource Allocation

| Component | CPU Request | CPU Limit | Memory Request | Memory Limit |
|-----------|-------------|-----------|----------------|--------------|
| Gitea | 100m | 500m | 256Mi | 512Mi |

---

## Database Setup

The Gitea database was created in PostgreSQL:

```sql
CREATE DATABASE gitea;
CREATE USER gitea WITH ENCRYPTED PASSWORD 'gitea-homelab-2026';
GRANT ALL PRIVILEGES ON DATABASE gitea TO gitea;
-- PostgreSQL 15+ requires additional schema permissions
\c gitea
GRANT ALL ON SCHEMA public TO gitea;
```

---

## Performance

**Web Interface Load Time:** 0.247s (NFR80 requirement: < 3 seconds)

---

## Files

| File | Description |
|------|-------------|
| `values-homelab.yaml` | Helm values configuration |
| `README.md` | This documentation |

---

## Troubleshooting

### Pod Not Starting

```bash
# Check pod events
kubectl describe pod -n dev -l app.kubernetes.io/name=gitea

# Check logs
kubectl logs -n dev -l app.kubernetes.io/name=gitea

# Check init container logs
kubectl logs -n dev -l app.kubernetes.io/name=gitea -c init-directories
kubectl logs -n dev -l app.kubernetes.io/name=gitea -c configure-gitea
```

### Database Connection Issues

```bash
# Verify database exists
kubectl exec -n data postgres-postgresql-0 -- psql -U postgres -c "\l" | grep gitea

# Test connection from Gitea pod
kubectl exec -n dev -l app.kubernetes.io/name=gitea -- \
  nc -zv postgres-postgresql.data.svc.cluster.local 5432
```

### PVC Issues

```bash
# Check PVC status
kubectl get pvc -n dev gitea-shared-storage

# Verify NFS provisioner
kubectl get pods -n infra -l app=nfs-subdir-external-provisioner
```

---

## Related Documentation

- [Gitea Official Docs](https://docs.gitea.com/)
- [Gitea Helm Chart](https://gitea.com/gitea/helm-chart)
- [PostgreSQL README](../postgres/README.md)

---

## Change Log

- 2026-01-15: Initial deployment with PostgreSQL backend (Story 19.1)
