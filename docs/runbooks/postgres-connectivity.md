# PostgreSQL Application Connectivity

**Purpose:** Guide for connecting applications to PostgreSQL within the home-lab cluster

**Story:** 5.5 - Test Application Connectivity to PostgreSQL
**Date Created:** 2026-01-06
**Last Updated:** 2026-01-06

---

## Overview

This runbook provides step-by-step instructions for connecting applications deployed in the cluster to the PostgreSQL database service. All connections use Kubernetes internal service discovery and secure credential management via Secrets.

**PostgreSQL Service Details:**
- **Internal DNS:** `postgres-postgresql.data.svc.cluster.local`
- **Port:** 5432
- **Namespace:** data
- **Service Type:** ClusterIP (internal cluster access only)

**Validated Configuration:**
- ✅ Cross-namespace connectivity (apps → data)
- ✅ DNS resolution and service discovery
- ✅ Connection latency: ~30ms (well under 100ms target)
- ✅ CRUD operations functional
- ✅ Kubernetes Secret-based credential management

---

## Prerequisites

- Application deployed in a Kubernetes namespace (typically `apps`)
- PostgreSQL database and user created for your application
- Kubernetes Secret created with application credentials

---

## Application Deployment Checklist

**Use this checklist when deploying any new application that requires PostgreSQL:**

- [ ] **Step 1:** Create application-specific database and user (see Step 1 below)
- [ ] **Step 2:** Store credentials in Kubernetes Secret in application's namespace (see Step 2 below)
- [ ] **Step 3:** Configure application to use PostgreSQL via environment variables (see Step 3 below)
- [ ] **Step 4:** Deploy test pod to validate connectivity before application deployment (see Testing Connectivity section)
- [ ] **Step 5:** Verify DNS resolution to `postgres-postgresql.data.svc.cluster.local`
- [ ] **Step 6:** Test CRUD operations with application user credentials
- [ ] **Step 7:** Measure connection latency (should be < 100ms for internal cluster)
- [ ] **Step 8:** Verify application user has correct privileges (not superuser)
- [ ] **Step 9:** Deploy application with database connection configured
- [ ] **Step 10:** Monitor application logs for successful database connection

**Quick Validation Command:**
```bash
# Test connectivity from application namespace
kubectl run test-db --image=postgres:latest --rm -it --restart=Never -n apps -- \
  psql -h postgres-postgresql.data.svc.cluster.local -U <app_user> -d <app_db> -c "SELECT version();"
```

---

## Quick Start - Application Connection

### Step 1: Create Application Database and User

Connect to PostgreSQL and create dedicated database and user for your application:

```bash
# Get PostgreSQL admin password
export POSTGRES_PASSWORD=$(kubectl get secret postgres-postgresql -n data -o jsonpath="{.data.postgres-password}" | base64 -d)

# Connect to PostgreSQL
kubectl exec -it postgres-postgresql-0 -n data -- env PGPASSWORD=$POSTGRES_PASSWORD psql -U postgres

# Create application database
CREATE DATABASE myapp_db;

# Create application user
CREATE USER myapp_user WITH PASSWORD 'secure_password_here';

# Grant privileges
GRANT ALL PRIVILEGES ON DATABASE myapp_db TO myapp_user;

# Connect to the new database and grant schema privileges
\c myapp_db
GRANT ALL ON SCHEMA public TO myapp_user;

# Exit psql
\q
```

### Step 2: Store Credentials in Kubernetes Secret

Create a Secret in your application's namespace with connection details:

```bash
kubectl create secret generic myapp-db-credentials \
  -n apps \
  --from-literal=username=myapp_user \
  --from-literal=password=secure_password_here \
  --from-literal=database=myapp_db \
  --from-literal=host=postgres-postgresql.data.svc.cluster.local \
  --from-literal=port=5432
```

### Step 3: Configure Application to Use PostgreSQL

Reference the Secret in your application deployment:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  namespace: apps
spec:
  template:
    spec:
      containers:
      - name: myapp
        image: myapp:latest
        env:
        - name: DB_HOST
          valueFrom:
            secretKeyRef:
              name: myapp-db-credentials
              key: host
        - name: DB_PORT
          valueFrom:
            secretKeyRef:
              name: myapp-db-credentials
              key: port
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

---

## Connection String Examples

### PostgreSQL CLI (psql)

```bash
psql -h postgres-postgresql.data.svc.cluster.local -U myapp_user -d myapp_db -p 5432
```

### Python (psycopg2)

```python
import psycopg2
import os

conn = psycopg2.connect(
    host=os.environ['DB_HOST'],
    port=os.environ['DB_PORT'],
    database=os.environ['DB_NAME'],
    user=os.environ['DB_USER'],
    password=os.environ['DB_PASSWORD']
)
```

**Connection String Format:**
```python
DATABASE_URL = f"postgresql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
```

### Node.js (pg)

```javascript
const { Pool } = require('pg');

const pool = new Pool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
});

// Test connection
pool.query('SELECT NOW()', (err, res) => {
  console.log(err ? err : res.rows[0]);
});
```

**Connection String Format:**
```javascript
const connectionString = `postgres://${process.env.DB_USER}:${process.env.DB_PASSWORD}@${process.env.DB_HOST}:${process.env.DB_PORT}/${process.env.DB_NAME}`;
```

### Go (pgx)

```go
import (
    "context"
    "fmt"
    "os"
    "github.com/jackc/pgx/v5"
)

func connectDB() (*pgx.Conn, error) {
    connString := fmt.Sprintf(
        "postgres://%s:%s@%s:%s/%s",
        os.Getenv("DB_USER"),
        os.Getenv("DB_PASSWORD"),
        os.Getenv("DB_HOST"),
        os.Getenv("DB_PORT"),
        os.Getenv("DB_NAME"),
    )

    return pgx.Connect(context.Background(), connString)
}
```

### Java (JDBC)

```java
import java.sql.Connection;
import java.sql.DriverManager;

String url = String.format(
    "jdbc:postgresql://%s:%s/%s",
    System.getenv("DB_HOST"),
    System.getenv("DB_PORT"),
    System.getenv("DB_NAME")
);

Connection conn = DriverManager.getConnection(
    url,
    System.getenv("DB_USER"),
    System.getenv("DB_PASSWORD")
);
```

---

## Service Discovery Details

### Internal DNS Resolution

Kubernetes provides automatic DNS resolution for services. The PostgreSQL service is accessible via:

**Full DNS Name (works from any namespace):**
```
postgres-postgresql.data.svc.cluster.local
```

**Components:**
- `postgres-postgresql`: Service name
- `data`: Namespace where PostgreSQL is deployed
- `svc.cluster.local`: Kubernetes service DNS suffix

**Short DNS Names (namespace-dependent):**
- From `data` namespace: `postgres-postgresql` or `postgres-postgresql.data`
- From other namespaces: Must use full name `postgres-postgresql.data.svc.cluster.local`

**DNS Resolution Test:**
```bash
# From any pod in the cluster
getent hosts postgres-postgresql.data.svc.cluster.local

# Expected output:
# 10.43.x.x postgres-postgresql.data.svc.cluster.local
```

### Service Endpoints

| Service | DNS | Port | Purpose |
|---------|-----|------|---------|
| postgres-postgresql | postgres-postgresql.data.svc.cluster.local | 5432 | Primary database connection |
| postgres-postgresql-hl | postgres-postgresql-hl.data.svc.cluster.local | 5432 | Headless service (StatefulSet) |
| postgres-postgresql-metrics | postgres-postgresql-metrics.data.svc.cluster.local | 9187 | Prometheus metrics (monitoring only) |

---

## Retrieving Credentials from Secrets

### Get PostgreSQL Admin Password

```bash
# Extract password from Secret
kubectl get secret postgres-postgresql -n data -o jsonpath="{.data.postgres-password}" | base64 -d
```

### Get Application User Credentials

```bash
# Get username
kubectl get secret myapp-db-credentials -n apps -o jsonpath="{.data.username}" | base64 -d

# Get password
kubectl get secret myapp-db-credentials -n apps -o jsonpath="{.data.password}" | base64 -d

# Get database name
kubectl get secret myapp-db-credentials -n apps -o jsonpath="{.data.database}" | base64 -d

# Get all connection details as environment variables
export DB_HOST=$(kubectl get secret myapp-db-credentials -n apps -o jsonpath="{.data.host}" | base64 -d)
export DB_PORT=$(kubectl get secret myapp-db-credentials -n apps -o jsonpath="{.data.port}" | base64 -d)
export DB_USER=$(kubectl get secret myapp-db-credentials -n apps -o jsonpath="{.data.username}" | base64 -d)
export DB_PASSWORD=$(kubectl get secret myapp-db-credentials -n apps -o jsonpath="{.data.password}" | base64 -d)
export DB_NAME=$(kubectl get secret myapp-db-credentials -n apps -o jsonpath="{.data.database}" | base64 -d)
```

---

## Application User Creation Procedure

**Best Practices:**
- Create one database per application
- Create one user per application (do NOT share postgres superuser)
- Use strong, randomly generated passwords
- Store credentials only in Kubernetes Secrets (never in code or ConfigMaps)
- Grant minimum required privileges (principle of least privilege)

**Standard User Creation Pattern:**

```sql
-- 1. Create database
CREATE DATABASE app_name_db;

-- 2. Create user with secure password
CREATE USER app_name_user WITH PASSWORD 'generate-secure-password';

-- 3. Grant database-level privileges
GRANT ALL PRIVILEGES ON DATABASE app_name_db TO app_name_user;

-- 4. Grant schema-level privileges
\c app_name_db
GRANT ALL ON SCHEMA public TO app_name_user;

-- 5. (Optional) Grant table privileges for existing tables
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO app_name_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO app_name_user;

-- 6. (Optional) Set default privileges for future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO app_name_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO app_name_user;
```

**Read-Only User Pattern:**

```sql
-- Create read-only user
CREATE USER readonly_user WITH PASSWORD 'secure-password';

-- Grant connect privilege
GRANT CONNECT ON DATABASE app_name_db TO readonly_user;

-- Grant usage on schema
\c app_name_db
GRANT USAGE ON SCHEMA public TO readonly_user;

-- Grant select on all existing tables
GRANT SELECT ON ALL TABLES IN SCHEMA public TO readonly_user;

-- Set default privileges for future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO readonly_user;
```

---

## Testing Connectivity

### Deploy Test Pod

Create a test pod to validate connectivity before deploying your application:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: postgres-test-client
  namespace: apps
spec:
  containers:
  - name: postgres-client
    image: registry-1.docker.io/bitnami/postgresql:latest
    command: ["sleep", "infinity"]
    env:
    - name: PGHOST
      value: "postgres-postgresql.data.svc.cluster.local"
    - name: PGPORT
      value: "5432"
    - name: PGUSER
      valueFrom:
        secretKeyRef:
          name: myapp-db-credentials
          key: username
    - name: PGPASSWORD
      valueFrom:
        secretKeyRef:
          name: myapp-db-credentials
          key: password
    - name: PGDATABASE
      valueFrom:
        secretKeyRef:
          name: myapp-db-credentials
          key: database
  restartPolicy: Never
```

### Run Connectivity Tests

```bash
# Deploy test pod
kubectl apply -f test-pod.yaml

# Wait for pod to be ready
kubectl wait --for=condition=ready pod/postgres-test-client -n apps --timeout=60s

# Test connection
kubectl exec -n apps postgres-test-client -- psql -c "SELECT version();"

# Test CRUD operations
kubectl exec -n apps postgres-test-client -- psql -c "CREATE TABLE test (id SERIAL, name TEXT);"
kubectl exec -n apps postgres-test-client -- psql -c "INSERT INTO test (name) VALUES ('test1'), ('test2');"
kubectl exec -n apps postgres-test-client -- psql -c "SELECT * FROM test;"
kubectl exec -n apps postgres-test-client -- psql -c "UPDATE test SET name = 'updated' WHERE id = 1;"
kubectl exec -n apps postgres-test-client -- psql -c "DELETE FROM test WHERE id = 2;"
kubectl exec -n apps postgres-test-client -- psql -c "DROP TABLE test;"

# Verify connection latency
kubectl exec -n apps postgres-test-client -- bash -c "time psql -c 'SELECT 1;'"
# Expected: < 100ms

# Clean up test pod
kubectl delete pod postgres-test-client -n apps
```

---

## Troubleshooting

### Connection Refused

**Symptoms:**
```
psql: error: connection to server at "postgres-postgresql.data.svc.cluster.local" (10.43.x.x), port 5432 failed: Connection refused
```

**Diagnosis:**
```bash
# Verify PostgreSQL is running
kubectl get pods -n data -l app.kubernetes.io/name=postgresql

# Check pod status
kubectl describe pod postgres-postgresql-0 -n data

# Check service endpoints
kubectl get endpoints postgres-postgresql -n data
```

**Resolution:**
- Ensure PostgreSQL pod is Running with 2/2 containers ready
- Verify service has endpoints matching pod IP
- Check pod logs: `kubectl logs -n data postgres-postgresql-0 -c postgresql`

### DNS Resolution Failure

**Symptoms:**
```
psql: error: could not translate host name "postgres-postgresql.data.svc.cluster.local" to address: Name or service not known
```

**Diagnosis:**
```bash
# From application pod, test DNS
kubectl exec -n apps <pod-name> -- getent hosts postgres-postgresql.data.svc.cluster.local

# Check CoreDNS is running
kubectl get pods -n kube-system -l k8s-app=kube-dns
```

**Resolution:**
- Verify DNS resolution works from pod
- Check CoreDNS logs if resolution fails
- Ensure service exists: `kubectl get svc postgres-postgresql -n data`

### Authentication Failed

**Symptoms:**
```
psql: error: connection to server at "postgres-postgresql.data.svc.cluster.local", port 5432 failed: FATAL:  password authentication failed for user "myapp_user"
```

**Diagnosis:**
```bash
# Verify secret contents
kubectl get secret myapp-db-credentials -n apps -o yaml

# Check username and password are correct
kubectl get secret myapp-db-credentials -n apps -o jsonpath="{.data.username}" | base64 -d
kubectl get secret myapp-db-credentials -n apps -o jsonpath="{.data.password}" | base64 -d

# Verify user exists in PostgreSQL
kubectl exec -it postgres-postgresql-0 -n data -- env PGPASSWORD=$POSTGRES_PASSWORD psql -U postgres -c "\du"
```

**Resolution:**
- Verify credentials in Secret match PostgreSQL user
- Recreate Secret with correct credentials
- Ensure application user was created with correct password

### Permission Denied on Database

**Symptoms:**
```
ERROR:  permission denied for schema public
ERROR:  permission denied for table xyz
```

**Diagnosis:**
```bash
# Check user privileges
kubectl exec -it postgres-postgresql-0 -n data -- env PGPASSWORD=$POSTGRES_PASSWORD psql -U postgres -d myapp_db -c "\du myapp_user"

# Check schema privileges
kubectl exec -it postgres-postgresql-0 -n data -- env PGPASSWORD=$POSTGRES_PASSWORD psql -U postgres -d myapp_db -c "\dn+"
```

**Resolution:**
```sql
-- Grant schema privileges
GRANT ALL ON SCHEMA public TO myapp_user;

-- Grant table privileges
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO myapp_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO myapp_user;

-- Set default privileges for future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO myapp_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO myapp_user;
```

### Secret Not Found in Application Namespace

**Symptoms:**
```
Error from server (NotFound): secrets "postgres-postgresql" not found
```

**Resolution:**
- Secrets are namespace-scoped and cannot be shared across namespaces
- Create application-specific secret in application's namespace
- Do NOT copy postgres-postgresql secret (contains superuser password)
- Follow "Application User Creation Procedure" above

### Slow Connection Performance

**Symptoms:**
- Queries take > 100ms
- Application timeouts

**Diagnosis:**
```bash
# Measure connection latency
kubectl exec -n apps <pod-name> -- bash -c "time psql -h postgres-postgresql.data.svc.cluster.local -U myapp_user -d myapp_db -c 'SELECT 1;'"

# Check PostgreSQL pod resources
kubectl top pod postgres-postgresql-0 -n data

# Check for network policies blocking traffic
kubectl get networkpolicies -n data
kubectl get networkpolicies -n apps
```

**Resolution:**
- Expected connection latency: 20-50ms (internal cluster network)
- If > 100ms, investigate pod resource constraints
- Check network policies aren't blocking traffic
- Verify PostgreSQL isn't under heavy load

---

## Security Best Practices

1. **Never Share Superuser Password:**
   - Each application gets its own database and user
   - Never use `postgres` superuser from applications
   - Limit superuser access to DBAs only

2. **Use Kubernetes Secrets:**
   - Store credentials only in Secrets (never in ConfigMaps or code)
   - Mount Secrets as environment variables or volumes
   - Avoid logging credentials

3. **Principle of Least Privilege:**
   - Grant minimum required privileges to application users
   - Use read-only users when writes aren't needed
   - Separate users for different access levels

4. **Network Security:**
   - PostgreSQL exposed only as ClusterIP (no external access)
   - All communication happens within cluster network
   - Future: Add NetworkPolicies for additional network isolation

5. **Password Rotation:**
   - Periodically rotate application user passwords
   - Update Secrets when passwords change
   - Restart application pods to pick up new credentials

---

## Related Documentation

- [PostgreSQL Setup Runbook](postgres-setup.md) - PostgreSQL deployment and configuration
- [PostgreSQL Backup Runbook](postgres-backup.md) - Automated backup procedures
- [PostgreSQL Restore Runbook](postgres-restore.md) - Disaster recovery procedures
- [PostgreSQL README](../../applications/postgres/README.md) - Application overview
- [Story 5.5 - Test Application Connectivity](../implementation-artifacts/5-5-test-application-connectivity-to-postgresql.md)

---

## Change Log

- 2026-01-06: Initial connectivity runbook creation - Validated cross-namespace connectivity with 30ms latency (Story 5.5)
- 2026-01-06: Added Application Deployment Checklist - 10-step checklist for future application deployments requiring PostgreSQL
