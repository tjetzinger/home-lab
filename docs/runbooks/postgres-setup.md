# PostgreSQL Database Setup

**Purpose:** Deploy and manage PostgreSQL database service in home-lab cluster

**Story:** 5.1 - Deploy PostgreSQL via Bitnami Helm Chart
**Date Created:** 2026-01-06
**Last Updated:** 2026-01-06

---

## Overview

This runbook documents the deployment and configuration of PostgreSQL using the Bitnami Helm chart for the home-lab Kubernetes cluster.

**Components:**
- **PostgreSQL**: Production-ready relational database (PostgreSQL 18.1)
- **Metrics Exporter**: PostgreSQL exporter for Prometheus integration
- **StatefulSet**: Ensures stable network identity and persistent storage (configured in Story 5.2)

**Key Features:**
- StatefulSet deployment for data persistence
- Prometheus metrics integration
- Internal cluster access via ClusterIP service
- Production-ready defaults from Bitnami chart

---

## Prerequisites

- `data` namespace exists with labels
- NFS storage provisioner available (nfs-client StorageClass)
- Monitoring stack deployed (kube-prometheus-stack)
- Helm installed
- kubectl access to cluster

---

## Deployment

### Step 1: Add Bitnami Helm Repository

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
```

### Step 2: Deploy PostgreSQL

```bash
# Deploy PostgreSQL via Helm
helm upgrade --install postgres bitnami/postgresql \
  -f /home/tt/Workspace/home-lab/applications/postgres/values-homelab.yaml \
  -n data

# Verify deployment
kubectl get pods -n data
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=postgresql -n data --timeout=120s
```

### Step 3: Verify Deployment

```bash
# Check StatefulSet
kubectl get statefulset -n data
kubectl get pods -n data

# Check services
kubectl get svc -n data

# Check logs
kubectl logs -n data postgres-postgresql-0 --tail=20
```

---

## Connection Methods

### Method 1: kubectl exec (Interactive)

```bash
# Get PostgreSQL password
export POSTGRES_PASSWORD=$(kubectl get secret --namespace data postgres-postgresql -o jsonpath="{.data.postgres-password}" | base64 -d)

# Connect to PostgreSQL CLI
kubectl exec -it postgres-postgresql-0 -n data -- env PGPASSWORD=$POSTGRES_PASSWORD psql -U postgres

# Or use the Bitnami-provided command
kubectl run postgres-postgresql-client --rm --tty -i --restart='Never' \
  --namespace data \
  --image registry-1.docker.io/bitnami/postgresql:latest \
  --env="PGPASSWORD=$POSTGRES_PASSWORD" \
  --command -- psql --host postgres-postgresql -U postgres -d postgres -p 5432
```

### Method 2: Internal DNS (From within cluster)

**Service DNS:** `postgres-postgresql.data.svc.cluster.local`
**Port:** 5432

```bash
# From another pod in the cluster
psql -h postgres-postgresql.data.svc.cluster.local -U postgres -d postgres -p 5432
```

### Method 3: Port Forwarding (From localhost)

```bash
# Forward port to localhost
kubectl port-forward --namespace data svc/postgres-postgresql 5432:5432 &

# Connect from localhost
export POSTGRES_PASSWORD=$(kubectl get secret --namespace data postgres-postgresql -o jsonpath="{.data.postgres-password}" | base64 -d)
PGPASSWORD="$POSTGRES_PASSWORD" psql --host 127.0.0.1 -U postgres -d postgres -p 5432
```

---

## Basic PostgreSQL Commands

### Database Operations

```sql
-- List databases
\l

-- Create database
CREATE DATABASE myapp;

-- Drop database
DROP DATABASE myapp;

-- Connect to database
\c myapp
```

### User/Role Operations

```sql
-- List roles
\du

-- Create user
CREATE USER appuser WITH PASSWORD 'password123';

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE myapp TO appuser;

-- Create user with specific privileges
CREATE USER readonly WITH PASSWORD 'readonly123';
GRANT CONNECT ON DATABASE myapp TO readonly;
GRANT USAGE ON SCHEMA public TO readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO readonly;
```

### Table Operations

```sql
-- List tables (in current database)
\dt

-- Describe table
\d tablename

-- Show table size
SELECT pg_size_pretty(pg_total_relation_size('tablename'));
```

### Query Information

```sql
-- Show running queries
SELECT pid, usename, application_name, state, query
FROM pg_stat_activity
WHERE state = 'active';

-- Show database connections
SELECT datname, count(*)
FROM pg_stat_activity
GROUP BY datname;

-- Show database sizes
SELECT datname, pg_size_pretty(pg_database_size(datname)) AS size
FROM pg_database
ORDER BY pg_database_size(datname) DESC;
```

---

## Retrieving Credentials

### Get PostgreSQL Password from Secret

```bash
# Get password
kubectl get secret postgres-postgresql -n data -o jsonpath="{.data.postgres-password}" | base64 -d
echo

# Get password and set as environment variable
export POSTGRES_PASSWORD=$(kubectl get secret postgres-postgresql -n data -o jsonpath="{.data.postgres-password}" | base64 -d)
```

### Secret Contents

The `postgres-postgresql` secret contains:
- `postgres-password`: PostgreSQL superuser password

---

## Monitoring

### Prometheus Integration

PostgreSQL metrics are automatically scraped by Prometheus via ServiceMonitor.

**Metrics Service:** `postgres-postgresql-metrics:9187`
**ServiceMonitor:** `postgres-postgresql` (data namespace)

### Key Metrics

```promql
# Database connections
pg_stat_database_numbackends

# Query execution time
pg_stat_activity_max_tx_duration

# Database size
pg_database_size_bytes

# Transactions per second
rate(pg_stat_database_xact_commit[5m])

# Lock statistics
pg_locks_count
```

### View Metrics in Prometheus

1. Access Prometheus: https://prometheus.home.jetzinger.com
2. Go to **Status > Targets**
3. Search for **postgres-postgresql** to verify scraping status
4. Run queries using metrics above

---

## Verification

### Verify StatefulSet

```bash
# Check StatefulSet status
kubectl get statefulset -n data postgres-postgresql

# Expected output:
# NAME                  READY   AGE
# postgres-postgresql   1/1     Xm
```

### Verify Pod

```bash
# Check pod status
kubectl get pods -n data -l app.kubernetes.io/name=postgresql

# Expected output:
# NAME                    READY   STATUS    RESTARTS   AGE
# postgres-postgresql-0   2/2     Running   0          Xm

# Check containers
kubectl get pod postgres-postgresql-0 -n data -o jsonpath='{.spec.containers[*].name}'
# Expected: postgresql metrics
```

### Verify Service

```bash
# Check services
kubectl get svc -n data

# Expected services:
# - postgres-postgresql (ClusterIP, port 5432)
# - postgres-postgresql-hl (Headless, port 5432)
# - postgres-postgresql-metrics (ClusterIP, port 9187)
```

### Verify Connectivity

```bash
# Test PostgreSQL connection
kubectl exec postgres-postgresql-0 -n data -- \
  env PGPASSWORD=${POSTGRES_PASSWORD} \
  psql -U postgres -c "SELECT version();"

# Expected: PostgreSQL 18.1 version info
```

---

## Troubleshooting

### Pod Not Starting

**Symptoms:**
- Pod in CrashLoopBackOff or Error state

**Diagnosis:**
```bash
kubectl describe pod postgres-postgresql-0 -n data
kubectl logs -n data postgres-postgresql-0
```

**Common Issues:**
1. Insufficient resources on nodes
2. PVC not bound (Story 5.2 when persistence enabled)
3. Configuration error in values-homelab.yaml

**Resolution:**
- Check node resources: `kubectl top nodes`
- Verify PVC status: `kubectl get pvc -n data`
- Review Helm values for errors

### Connection Refused

**Symptoms:**
- Cannot connect to PostgreSQL from within cluster

**Diagnosis:**
```bash
# Verify pod is running
kubectl get pods -n data -l app.kubernetes.io/name=postgresql

# Check pod logs for errors
kubectl logs -n data postgres-postgresql-0 --tail=50

# Verify service endpoints
kubectl get endpoints postgres-postgresql -n data
```

**Resolution:**
- Ensure pod is in Running state (2/2 containers ready)
- Verify service has endpoints matching pod IP
- Check firewall/network policies if enabled

### Password Authentication Failed

**Symptoms:**
- `psql: error: FATAL: password authentication failed for user "postgres"`

**Diagnosis:**
```bash
# Verify password in secret matches values-homelab.yaml
kubectl get secret postgres-postgresql -n data -o jsonpath="{.data.postgres-password}" | base64 -d
```

**Resolution:**
- Ensure PGPASSWORD environment variable is set correctly
- Password from secret should match auth.postgresPassword in values-homelab.yaml
- If persistence is enabled (Story 5.2), old PVC may have different password

### Metrics Not Appearing in Prometheus

**Symptoms:**
- PostgreSQL metrics missing from Prometheus

**Diagnosis:**
```bash
# Verify ServiceMonitor exists
kubectl get servicemonitor -n data postgres-postgresql

# Check metrics service
kubectl get svc postgres-postgresql-metrics -n data

# Verify metrics exporter is running
kubectl get pod postgres-postgresql-0 -n data -o jsonpath='{.spec.containers[*].name}'
```

**Resolution:**
- Ensure ServiceMonitor has correct label: `release: kube-prometheus-stack`
- Verify metrics service endpoints: `kubectl get endpoints postgres-postgresql-metrics -n data`
- Check Prometheus logs for scraping errors

---

## Configuration Reference

### Current Setup

| Setting | Value |
|---------|-------|
| PostgreSQL Version | 18.1 |
| Bitnami Chart Version | 18.2.0 |
| Namespace | data |
| Service Type | ClusterIP (internal only) |
| Port | 5432 |
| Persistence | NFS-backed PVC (Story 5.2) |
| PVC Name | data-postgres-postgresql-0 |
| Storage Class | nfs-client |
| Storage Size | 8Gi |
| Access Mode | ReadWriteOnce (RWO) |
| NFS Server | 192.168.2.2 (Synology DS920+) |
| Reclaim Policy | Delete |
| Metrics | Enabled (Prometheus integration) |
| Read Replicas | Disabled |

### Resource Allocation

| Component | CPU Request | CPU Limit | Memory Request | Memory Limit |
|-----------|-------------|-----------|----------------|--------------|
| PostgreSQL | 100m | 500m | 256Mi | 1Gi |
| Metrics Exporter | 50m | 100m | 64Mi | 128Mi |

### Service Endpoints

- **PostgreSQL Service:** `postgres-postgresql.data.svc.cluster.local:5432`
- **Headless Service:** `postgres-postgresql-hl.data.svc.cluster.local:5432`
- **Metrics Service:** `postgres-postgresql-metrics.data.svc.cluster.local:9187`

---

## NFS Persistence Details (Story 5.2)

### PVC Configuration

**PersistentVolumeClaim:**
- **Name:** `data-postgres-postgresql-0`
- **Namespace:** `data`
- **StorageClass:** `nfs-client`
- **Capacity:** 8Gi
- **Access Mode:** ReadWriteOnce (RWO)
- **Status:** Bound
- **Reclaim Policy:** Delete

**NFS Backend:**
- **Server:** 192.168.2.2 (Synology DS920+)
- **Path:** `/volume1/k8s-data/data-data-postgres-postgresql-0-pvc-<uid>/`
- **Provisioner:** nfs-subdir-external-provisioner

### Verify Persistence

```bash
# Check PVC status
kubectl get pvc -n data
kubectl describe pvc data-postgres-postgresql-0 -n data

# Check PV details
kubectl get pv
kubectl describe pv <pv-name>

# Verify PostgreSQL data on NFS
kubectl exec postgres-postgresql-0 -n data -- ls -la /bitnami/postgresql/data
kubectl exec postgres-postgresql-0 -n data -- du -sh /bitnami/postgresql/data
```

### Test Data Persistence

**Pod Deletion Test:**
```bash
# Create test data
kubectl exec postgres-postgresql-0 -n data -- env PGPASSWORD=${POSTGRES_PASSWORD} psql -U postgres -c "CREATE DATABASE test_db;"

# Delete pod
kubectl delete pod postgres-postgresql-0 -n data

# Wait for recreation
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=postgresql -n data --timeout=120s

# Verify data persists
kubectl exec postgres-postgresql-0 -n data -- env PGPASSWORD=${POSTGRES_PASSWORD} psql -U postgres -c "\l" | grep test_db
```

**Node Failure Test:**
```bash
# Identify current node
kubectl get pods -n data -o wide

# Drain node (replace <node-name> with actual node)
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# Verify pod moves to different node
kubectl get pods -n data -o wide

# Verify data still accessible
kubectl exec postgres-postgresql-0 -n data -- env PGPASSWORD=${POSTGRES_PASSWORD} psql -U postgres -c "\l"

# Uncordon node
kubectl uncordon <node-name>
```

---

## Related Documentation

- [PostgreSQL Deployment README](../../applications/postgres/README.md)
- [PostgreSQL Backup & Recovery Runbook](postgres-backup.md)
- [PostgreSQL Restore Procedures Runbook](postgres-restore.md)
- [PostgreSQL Application Connectivity Runbook](postgres-connectivity.md)
- [Story 5.2 - Configure NFS Persistence](../implementation-artifacts/5-2-configure-nfs-persistence-for-postgresql.md)
- [Story 5.3 - Setup PostgreSQL Backup](../implementation-artifacts/5-3-setup-postgresql-backup-with-pg-dump.md)
- [Story 5.4 - Validate PostgreSQL Restore](../implementation-artifacts/5-4-validate-postgresql-restore-procedure.md)
- [Story 5.5 - Test Application Connectivity](../implementation-artifacts/5-5-test-application-connectivity-to-postgresql.md)
- [Bitnami PostgreSQL Chart](https://github.com/bitnami/charts/tree/main/bitnami/postgresql)
- [PostgreSQL Official Docs](https://www.postgresql.org/docs/18/)

---

## Change Log

- 2026-01-06: Initial runbook creation - PostgreSQL 18.1 deployed with emptyDir storage (Story 5.1)
- 2026-01-06: Updated for NFS persistence (Story 5.2) - Added PVC configuration, NFS backend details, persistence validation procedures
- 2026-01-06: Added backup system reference (Story 5.3) - Link to postgres-backup.md runbook for automated backup procedures
- 2026-01-06: Added restore procedures reference (Story 5.4) - Link to postgres-restore.md runbook for disaster recovery procedures
- 2026-01-06: Added connectivity reference (Story 5.5) - Link to postgres-connectivity.md runbook for application integration patterns
