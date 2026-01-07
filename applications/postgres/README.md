# PostgreSQL Database Service

**Purpose:** Production-ready PostgreSQL database for home-lab cluster workloads

**Story:** 5.1 - Deploy PostgreSQL via Bitnami Helm Chart
**Epic:** 5 - PostgreSQL Database Service
**Namespace:** `data`

---

## Overview

PostgreSQL is deployed as a StatefulSet using the Bitnami Helm chart, providing a production-ready relational database for cluster applications.

**Key Features:**
- StatefulSet deployment for data persistence
- Prometheus metrics integration
- Internal cluster access via ClusterIP service
- Production-ready defaults from Bitnami chart

---

## Deployment

### Prerequisites

- `data` namespace exists
- NFS storage provisioner available (for Story 5.2 persistence)
- Monitoring stack deployed (for metrics integration)

### Deploy PostgreSQL

```bash
# Add Bitnami Helm repository (if not already added)
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Deploy PostgreSQL
helm upgrade --install postgres bitnami/postgresql \
  -f values-homelab.yaml \
  -n data

# Verify deployment
kubectl get pods -n data
kubectl get statefulset -n data
kubectl get svc -n data
```

---

## Access

### Internal Cluster Access

**Service DNS:** `postgres.data.svc.cluster.local`
**Port:** 5432

### Connection via kubectl

```bash
# Connect to PostgreSQL CLI
kubectl exec -it postgres-0 -n data -- psql -U postgres

# Run psql commands
\l          # List databases
\du         # List roles
\dt         # List tables (in current database)
\q          # Exit
```

### Retrieve Password from Secret

```bash
# Get PostgreSQL password
kubectl get secret postgres-postgresql -n data -o jsonpath="{.data.postgres-password}" | base64 -d
echo
```

---

## Configuration

### Current Setup

| Setting | Value |
|---------|-------|
| Chart | bitnami/postgresql |
| Namespace | data |
| Service Type | ClusterIP (internal only) |
| Port | 5432 |
| Persistence | NFS-backed PVC (Story 5.2) |
| PVC Name | data-postgres-postgresql-0 |
| Storage Class | nfs-client |
| Storage Size | 8Gi |
| Access Mode | ReadWriteOnce (RWO) |
| NFS Server | 192.168.2.2 (Synology DS920+) |
| Metrics | Enabled (Prometheus integration) |
| Read Replicas | Disabled (not needed for home lab) |

### Resource Allocation

| Component | CPU Request | CPU Limit | Memory Request | Memory Limit |
|-----------|-------------|-----------|----------------|--------------|
| PostgreSQL | 100m | 500m | 256Mi | 1Gi |
| Metrics Exporter | 50m | 100m | 64Mi | 128Mi |

---

## Monitoring

PostgreSQL metrics are automatically scraped by Prometheus via ServiceMonitor.

**Metrics Endpoint:** `postgres-postgresql-metrics:9187/metrics`

**Available Metrics:**
- Connection pool status
- Query performance
- Database size
- Transaction rates
- Lock statistics

---

## Persistence Details

**Storage Configuration (Story 5.2):**
- **PVC:** `data-postgres-postgresql-0` (8Gi, nfs-client StorageClass)
- **Reclaim Policy:** Delete (PV deleted when PVC is deleted)
- **NFS Backend:** Synology DS920+ (192.168.2.2)
- **NFS Path:** `/volume1/k8s-data/data-data-postgres-postgresql-0-pvc-<uid>/`
- **Data Persistence:** Survives pod restarts and node failures

**Persistence Validation:**
- ✅ Data survives pod deletion (tested with `kubectl delete pod`)
- ✅ Data survives node failure (tested with `kubectl drain`)
- ✅ PostgreSQL data files on NFS: pg_wal, base, global directories

---

## Backup & Recovery

**Backup Strategy (Story 5.3):**
- **Method:** Automated pg_dumpall with gzip compression
- **Schedule:** Daily at 2 AM UTC via Kubernetes CronJob
- **Storage:** NFS-backed PVC (10Gi, nfs-client StorageClass)
- **Retention:** Last 7 daily backups retained, older backups auto-deleted
- **Backup File Pattern:** `postgres-backup-YYYY-MM-DD-HHMMSS.sql.gz`

**Backup Configuration:**
- **CronJob:** `postgres-backup` in `data` namespace
- **Backup PVC:** `postgres-backup` (10Gi)
- **NFS Path:** `192.168.2.2:/volume1/k8s-data/data-postgres-backup-pvc-<uid>/`
- **Image:** `registry-1.docker.io/bitnami/postgresql:latest`

### Manual Backup

Trigger a manual backup anytime:

```bash
# Trigger manual backup
kubectl create job --from=cronjob/postgres-backup manual-backup-$(date +%Y%m%d%H%M%S) -n data

# Monitor backup job
kubectl get jobs -n data
kubectl logs -n data job/manual-backup-<timestamp>
```

### Verify Backups

```bash
# List backup files
kubectl run backup-verify --image=busybox --restart=Never -n data --rm -it \
  --overrides='{"spec":{"containers":[{"name":"verify","image":"busybox","command":["ls","-lh","/backup"],"volumeMounts":[{"name":"backup","mountPath":"/backup"}]}],"volumes":[{"name":"backup","persistentVolumeClaim":{"claimName":"postgres-backup"}}]}}'

# Verify backup content
kubectl run backup-verify --image=busybox --restart=Never -n data --rm -it \
  --overrides='{"spec":{"containers":[{"name":"verify","image":"busybox","command":["sh","-c","zcat /backup/postgres-backup-*.sql.gz | head -20"],"volumeMounts":[{"name":"backup","mountPath":"/backup"}]}],"volumes":[{"name":"backup","persistentVolumeClaim":{"claimName":"postgres-backup"}}]}}'
```

### Backup Details

| Setting | Value |
|---------|-------|
| CronJob Name | postgres-backup |
| Schedule | `0 2 * * *` (daily at 2 AM) |
| Backup PVC | postgres-backup (10Gi) |
| Retention | Last 7 backups |
| Compression | gzip |
| Backup Method | pg_dumpall (all databases) |

**For detailed backup procedures, see:** [PostgreSQL Backup Runbook](../../docs/runbooks/postgres-backup.md)

### Restore from Backup

**Restore Capability (Story 5.4):**
- **Method:** psql restore from pg_dumpall SQL dumps
- **Validated:** ✅ 2-second restore time for small databases
- **Recovery Time Objective (RTO):** < 10 minutes for disaster recovery
- **Disaster Recovery:** Documented procedures with destructive testing validation

**Quick Restore Example:**

```bash
# 1. Identify backup file
kubectl run backup-list --image=busybox --restart=Never -n data --rm -it \
  --overrides='{"spec":{"containers":[{"name":"list","image":"busybox","command":["ls","-lh","/backup"],"volumeMounts":[{"name":"backup","mountPath":"/backup"}]}],"volumes":[{"name":"backup","persistentVolumeClaim":{"claimName":"postgres-backup"}}]}}'

# 2. Create restore pod
kubectl run postgres-restore --image=registry-1.docker.io/bitnami/postgresql:latest \
  --restart=Never -n data \
  --overrides='{"spec":{"containers":[{"name":"restore","image":"registry-1.docker.io/bitnami/postgresql:latest","command":["sleep","600"],"volumeMounts":[{"name":"backup","mountPath":"/backup"}],"env":[{"name":"PGPASSWORD","valueFrom":{"secretKeyRef":{"name":"postgres-postgresql","key":"postgres-password"}}},{"name":"PGHOST","value":"postgres-postgresql.data.svc.cluster.local"}]}],"volumes":[{"name":"backup","persistentVolumeClaim":{"claimName":"postgres-backup"}}]}}'

# 3. Wait for pod ready
kubectl wait --for=condition=ready pod/postgres-restore -n data --timeout=60s

# 4. Execute restore
kubectl exec -n data postgres-restore -- \
  bash -c "zcat /backup/postgres-backup-YYYY-MM-DD-HHMMSS.sql.gz | psql -U postgres -h \$PGHOST"

# 5. Verify restored data
kubectl exec -it postgres-postgresql-0 -n data -- \
  env PGPASSWORD=$(kubectl get secret postgres-postgresql -n data -o jsonpath="{.data.postgres-password}" | base64 -d) \
  psql -U postgres -c "\l"

# 6. Clean up
kubectl delete pod postgres-restore -n data
```

**Restore Performance:**
- Small database (2.2K backup): 2 seconds
- Expected for production databases: < 5 minutes

**For detailed restore procedures, disaster recovery scenarios, and troubleshooting, see:** [PostgreSQL Restore Runbook](../../docs/runbooks/postgres-restore.md)

### Application Connectivity

**Connectivity Capability (Story 5.5):**
- **Service DNS:** postgres-postgresql.data.svc.cluster.local:5432
- **Validated:** ✅ Cross-namespace connectivity (apps → data)
- **Connection Latency:** ~30ms (internal cluster network)
- **CRUD Operations:** Fully validated with application users

**Quick Connection Example:**

```bash
# From any pod in the cluster (example: apps namespace)
# Using application-specific credentials from Secret

apiVersion: v1
kind: Pod
metadata:
  name: myapp
  namespace: apps
spec:
  containers:
  - name: app
    image: myapp:latest
    env:
    - name: DB_HOST
      value: "postgres-postgresql.data.svc.cluster.local"
    - name: DB_PORT
      value: "5432"
    - name: DB_USER
      valueFrom:
        secretKeyRef:
          name: myapp-db-credentials
          key: username
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: myapp-db-credentials
          key: password
    - name: DB_NAME
      valueFrom:
        secretKeyRef:
          name: myapp-db-credentials
          key: database
```

**Connection String Patterns:**
- **Python:** `postgresql://user:password@postgres-postgresql.data.svc.cluster.local:5432/database`
- **Node.js:** `postgres://user:password@postgres-postgresql.data.svc.cluster.local:5432/database`
- **Go:** `postgres://user:password@postgres-postgresql.data.svc.cluster.local:5432/database`

**For comprehensive connectivity guide, application user creation, and troubleshooting, see:** [PostgreSQL Connectivity Runbook](../../docs/runbooks/postgres-connectivity.md)

## Future Enhancements

Currently all planned Epic 5 stories are complete

---

## Troubleshooting

### Pod Not Starting

```bash
# Check pod events
kubectl describe pod postgres-0 -n data

# Check logs
kubectl logs -n data postgres-0

# Check StatefulSet status
kubectl get statefulset -n data postgres-postgresql -o yaml
```

### Connection Issues

```bash
# Verify service is running
kubectl get svc -n data postgres-postgresql

# Test connection from another pod
kubectl run -it --rm psql-test --image=postgres:latest --restart=Never -- \
  psql -h postgres.data.svc.cluster.local -U postgres
```

### Metrics Not Appearing in Prometheus

```bash
# Verify ServiceMonitor exists
kubectl get servicemonitor -n data

# Check metrics endpoint
kubectl exec -n data postgres-postgresql-0 -- curl localhost:9187/metrics
```

### PVC Not Binding (Story 5.2)

```bash
# Check PVC status
kubectl get pvc -n data
kubectl describe pvc data-postgres-postgresql-0 -n data

# Verify NFS provisioner is running
kubectl get pods -n infra -l app=nfs-subdir-external-provisioner

# Check StorageClass exists
kubectl get storageclass nfs-client

# View provisioner logs
kubectl logs -n infra -l app=nfs-subdir-external-provisioner
```

### Data Loss After Pod Restart

```bash
# Verify PVC is bound
kubectl get pvc data-postgres-postgresql-0 -n data

# Check pod is using PVC (not emptyDir)
kubectl describe pod postgres-postgresql-0 -n data | grep -A5 "Volumes:"

# Verify NFS mount inside pod
kubectl exec postgres-postgresql-0 -n data -- df -h /bitnami/postgresql/data
```

---

## Related Documentation

- [PostgreSQL Setup Runbook](../../docs/runbooks/postgres-setup.md)
- [Bitnami PostgreSQL Chart](https://github.com/bitnami/charts/tree/main/bitnami/postgresql)
- [PostgreSQL Official Docs](https://www.postgresql.org/docs/)

---

## Change Log

- 2026-01-06: Initial deployment with emptyDir storage (Story 5.1)
- 2026-01-06: Migrated to NFS-backed persistent storage (Story 5.2) - 8Gi PVC with nfs-client StorageClass
- 2026-01-06: Implemented automated backup system (Story 5.3) - Daily pg_dumpall backups to NFS with 7-day retention
- 2026-01-06: Validated restore procedures (Story 5.4) - Documented disaster recovery with 2-second restore time validation
- 2026-01-06: Validated application connectivity (Story 5.5) - Cross-namespace connectivity with 30ms latency, Epic 5 complete
