# PostgreSQL Restore Procedures

**Purpose:** Restore PostgreSQL databases from backup in home-lab cluster

**Story:** 5.4 - Validate PostgreSQL Restore Procedure
**Date Created:** 2026-01-06
**Last Updated:** 2026-01-06

---

## Overview

This runbook documents the procedures for restoring PostgreSQL databases from pg_dumpall backups stored on NFS-backed persistent volumes. These procedures have been validated through destructive testing and provide documented disaster recovery capabilities.

**Restore Method:**
- **Backup Format:** pg_dumpall SQL dumps (gzip compressed)
- **Restore Tool:** psql command-line utility
- **Backup Location:** postgres-backup PVC (10Gi, NFS-backed)
- **Restore Scope:** Full cluster restore (all databases, roles, permissions)

**Use Cases:**
- Disaster recovery from data corruption
- Recovery from accidental database deletion
- Restoration after hardware failure
- Migration to new PostgreSQL instance

---

## Prerequisites

Before performing a restore, ensure:

- ✅ kubectl access to cluster with data namespace permissions
- ✅ PostgreSQL pod is running: `postgres-postgresql-0` in data namespace
- ✅ Backup files exist in postgres-backup PVC
- ✅ PostgreSQL admin password available from secret
- ✅ Applications using PostgreSQL are stopped (to prevent data conflicts)
- ✅ Sufficient storage space for restored databases

**Required Tools:**
- kubectl (configured for cluster access)
- Backup file from postgres-backup PVC

---

## Restore Procedures

### Step 1: Identify Backup File

List available backup files to choose which backup to restore:

```bash
# Create temporary pod to list backups
kubectl run backup-list --image=busybox --restart=Never -n data \
  --overrides='{"spec":{"containers":[{"name":"list","image":"busybox","command":["sleep","60"],"volumeMounts":[{"name":"backup","mountPath":"/backup"}]}],"volumes":[{"name":"backup","persistentVolumeClaim":{"claimName":"postgres-backup"}}]}}' && \
  sleep 3 && \
  kubectl exec backup-list -n data -- ls -lh /backup && \
  kubectl delete pod backup-list -n data

# Expected output:
# -rw-r--r--    1 1001     users       2.1K Jan  6 16:54 postgres-backup-2026-01-06-165438.sql.gz
# -rw-r--r--    1 1001     users       2.2K Jan  6 16:54 postgres-backup-2026-01-06-165445.sql.gz
# ...
```

**Choose the appropriate backup file** based on:
- Date/time when data was last known good
- Before corruption or deletion event occurred
- Most recent backup if performing routine restore test

### Step 2: Extract Backup File from PVC

Copy the chosen backup file from the postgres-backup PVC to a temporary location:

```bash
# Set backup filename (replace with actual filename from Step 1)
export BACKUP_FILE="postgres-backup-2026-01-06-165445.sql.gz"

# Create temporary pod with backup PVC mounted
kubectl run backup-extract --image=busybox --restart=Never -n data \
  --overrides='{"spec":{"containers":[{"name":"extract","image":"busybox","command":["sleep","300"],"volumeMounts":[{"name":"backup","mountPath":"/backup"}]}],"volumes":[{"name":"backup","persistentVolumeClaim":{"claimName":"postgres-backup"}}]}}'

# Wait for pod to be ready
kubectl wait --for=condition=ready pod/backup-extract -n data --timeout=60s

# Copy backup file to local machine (optional - for offsite restore)
kubectl cp data/backup-extract:/backup/$BACKUP_FILE ./$BACKUP_FILE

# Verify file was copied
ls -lh $BACKUP_FILE
```

### Step 3: Copy Backup into PostgreSQL Pod

Transfer the backup file into the PostgreSQL pod for restoration:

```bash
# Copy backup file into PostgreSQL pod
kubectl cp ./$BACKUP_FILE data/postgres-postgresql-0:/tmp/$BACKUP_FILE

# Verify file exists in pod
kubectl exec -n data postgres-postgresql-0 -- ls -lh /tmp/$BACKUP_FILE

# Expected output: -rw-r--r-- 1 1001 1001 2.2K Jan  6 16:54 /tmp/postgres-backup-2026-01-06-165445.sql.gz
```

**Alternative (Direct Method):**
If you prefer to restore directly from backup PVC without local copy:

```bash
# Create restore pod with both backup PVC and postgres access
kubectl run postgres-restore --image=registry-1.docker.io/bitnami/postgresql:latest \
  --restart=Never -n data \
  --overrides='{"spec":{"containers":[{"name":"restore","image":"registry-1.docker.io/bitnami/postgresql:latest","command":["sleep","600"],"volumeMounts":[{"name":"backup","mountPath":"/backup"}],"env":[{"name":"PGPASSWORD","valueFrom":{"secretKeyRef":{"name":"postgres-postgresql","key":"postgres-password"}}},{"name":"PGHOST","value":"postgres-postgresql.data.svc.cluster.local"}]}],"volumes":[{"name":"backup","persistentVolumeClaim":{"claimName":"postgres-backup"}}]}}'

# Wait for pod
kubectl wait --for=condition=ready pod/postgres-restore -n data --timeout=60s
```

### Step 4: Prepare for Restore (Drop Conflicting Databases)

**⚠️ WARNING:** This step is DESTRUCTIVE. Ensure you have verified the backup file before proceeding.

**For Full Cluster Restore:**

If restoring a pg_dumpall backup that includes databases that already exist, you may need to drop them first to avoid conflicts:

```bash
# Get PostgreSQL password
export POSTGRES_PASSWORD=$(kubectl get secret postgres-postgresql -n data -o jsonpath="{.data.postgres-password}" | base64 -d)

# Connect to PostgreSQL
kubectl exec -it postgres-postgresql-0 -n data -- env PGPASSWORD=$POSTGRES_PASSWORD psql -U postgres

# List existing databases
\l

# Drop specific database (replace 'backup_test' with database name)
DROP DATABASE backup_test;

# Verify database is dropped
\l

# Exit psql
\q
```

**For Single Database Restore:**

You can restore a single database without dropping all databases:

```bash
# Restore will create the database if it doesn't exist
# Or recreate it if you drop it first
```

### Step 5: Execute Restore

Restore the database from the backup file:

**Method 1: Restore from file in PostgreSQL pod**

```bash
# Extract gzipped backup and restore in one command
kubectl exec -n data postgres-postgresql-0 -- \
  env PGPASSWORD=$POSTGRES_PASSWORD \
  bash -c "zcat /tmp/$BACKUP_FILE | psql -U postgres"

# Monitor output for errors
# Expected: CREATE DATABASE, CREATE TABLE, INSERT statements
```

**Method 2: Restore using separate extract and restore steps**

```bash
# Extract backup file
kubectl exec -n data postgres-postgresql-0 -- \
  gunzip /tmp/$BACKUP_FILE

# Restore from extracted SQL file
export SQL_FILE="${BACKUP_FILE%.gz}"  # Remove .gz extension

kubectl exec -n data postgres-postgresql-0 -- \
  env PGPASSWORD=$POSTGRES_PASSWORD \
  psql -U postgres < /tmp/$SQL_FILE
```

**Method 3: Restore from backup PVC pod (Alternative)**

```bash
# If using postgres-restore pod from Step 3 alternative
kubectl exec -n data postgres-restore -- \
  bash -c "zcat /backup/$BACKUP_FILE | psql -U postgres"
```

**Common Restore Options:**

```bash
# Restore with verbose output
kubectl exec -n data postgres-postgresql-0 -- \
  env PGPASSWORD=$POSTGRES_PASSWORD \
  bash -c "zcat /tmp/$BACKUP_FILE | psql -U postgres -v ON_ERROR_STOP=1"

# Restore specific database only (if backup contains single database)
kubectl exec -n data postgres-postgresql-0 -- \
  env PGPASSWORD=$POSTGRES_PASSWORD \
  bash -c "zcat /tmp/$BACKUP_FILE | psql -U postgres -d target_database"
```

### Step 6: Verify Restore Success

After restore completes, verify the data was restored correctly:

```bash
# Connect to PostgreSQL
kubectl exec -it postgres-postgresql-0 -n data -- \
  env PGPASSWORD=$POSTGRES_PASSWORD psql -U postgres

# List all databases
\l

# Verify target database exists
# Expected: backup_test (or your database name) appears in list

# Connect to restored database
\c backup_test

# List tables
\dt

# Verify table data (example for backup_test database)
SELECT COUNT(*) FROM users;
-- Expected: 3 (or your expected row count)

SELECT COUNT(*) FROM transactions;
-- Expected: 5 (or your expected row count)

# Verify specific records
SELECT * FROM users;
-- Expected: alice, bob, charlie

# Verify foreign key relationships
SELECT t.id, t.user_id, u.username, t.amount
FROM transactions t
JOIN users u ON t.user_id = u.id
ORDER BY t.id;
-- Expected: All 5 transactions with matching user names

# Exit psql
\q
```

**Automated Verification Script:**

```bash
# Run verification queries in batch
kubectl exec -n data postgres-postgresql-0 -- \
  env PGPASSWORD=$POSTGRES_PASSWORD \
  psql -U postgres -d backup_test -c "SELECT COUNT(*) FROM users;" \
  -c "SELECT COUNT(*) FROM transactions;" \
  -c "SELECT * FROM users ORDER BY id;"
```

### Step 7: Clean Up Temporary Files

Remove temporary files and pods after successful restore:

```bash
# Delete backup file from PostgreSQL pod
kubectl exec -n data postgres-postgresql-0 -- rm -f /tmp/$BACKUP_FILE /tmp/$SQL_FILE

# Delete temporary pods (if created)
kubectl delete pod backup-extract -n data --ignore-not-found
kubectl delete pod postgres-restore -n data --ignore-not-found

# Delete local backup file (if copied)
rm -f ./$BACKUP_FILE
```

### Step 8: Restart Applications

Once restore is verified, restart applications that use PostgreSQL:

```bash
# Restart application deployments in apps namespace
kubectl rollout restart deployment -n apps

# Verify applications reconnect successfully
kubectl get pods -n apps
kubectl logs -n apps <app-pod-name>
```

---

## Restore Performance Benchmarks

**Test Environment:**
- PostgreSQL 18.1 on K3s cluster
- NFS-backed storage (Synology DS920+)
- Test database: backup_test (3 users, 5 transactions)

**Measured Restore Times:**

| Backup Size | Database Size | Restore Time | Notes |
|-------------|---------------|--------------|-------|
| 2.2K (gzipped) | ~5KB uncompressed | **2 seconds** | **Validated:** backup_test (3 users, 5 transactions) |
| 1-10 MB | ~50MB uncompressed | < 30 seconds | Expected for small production DB |
| 100+ MB | ~500MB uncompressed | < 5 minutes | Expected for medium production DB |

**Performance Notes:**
- **Validated restore time:** 2 seconds for 2.2K backup (Story 5.4 testing)
- Restore time is primarily limited by database INSERT operations, not I/O
- NFS storage adds minimal overhead for small/medium databases
- For large databases (1GB+), consider using pg_restore with custom format for parallelization
- Test database restore validates < 5 second RTO for small databases

---

## Disaster Recovery Scenarios

### Scenario 1: Accidental Database Drop

**Situation:** Developer accidentally drops production database

**Recovery Steps:**
1. Identify last backup before deletion (Step 1)
2. Extract and copy backup to PostgreSQL pod (Steps 2-3)
3. Skip Step 4 (database already dropped)
4. Execute restore (Step 5)
5. Verify data restored (Step 6)
6. Clean up and restart apps (Steps 7-8)

**Recovery Time Objective (RTO):** < 10 minutes for small databases

### Scenario 2: Data Corruption

**Situation:** Application bug corrupts database tables

**Recovery Steps:**
1. Identify last known good backup (Step 1)
2. Stop applications to prevent further corruption
3. Extract backup (Steps 2-3)
4. Drop corrupted database (Step 4)
5. Restore from backup (Step 5)
6. Verify data integrity (Step 6)
7. Clean up and restart apps (Steps 7-8)

**Recovery Time Objective (RTO):** < 15 minutes

### Scenario 3: Complete Cluster Loss

**Situation:** K3s cluster destroyed, need to restore PostgreSQL to new cluster

**Recovery Steps:**
1. Rebuild K3s cluster and deploy PostgreSQL (see postgres-setup.md)
2. Restore backup PVC from Synology snapshots
3. Identify backup file (Step 1)
4. Execute restore (Steps 2-5)
5. Verify all databases restored (Step 6)
6. Redeploy applications (Step 8)

**Recovery Time Objective (RTO):** < 1 hour (including cluster rebuild)

### Scenario 4: Point-in-Time Recovery

**Situation:** Need to restore database to specific point in time

**Recovery Steps:**
1. Identify backup closest to desired point in time
   - Daily backups at 2 AM UTC
   - Choose backup BEFORE the timestamp you want
2. Follow standard restore procedure (Steps 1-8)
3. Manually replay transactions from application logs if needed

**Limitation:** Point-in-time recovery limited to backup frequency (daily)

---

## Troubleshooting

### Restore Command Fails with "ERROR: database already exists"

**Symptoms:**
```
ERROR:  database "backup_test" already exists
```

**Cause:** pg_dumpall backup includes CREATE DATABASE statements, but database already exists

**Resolution:**
```bash
# Option 1: Drop existing database before restore (see Step 4)
kubectl exec -it postgres-postgresql-0 -n data -- \
  env PGPASSWORD=$POSTGRES_PASSWORD psql -U postgres -c "DROP DATABASE backup_test;"

# Option 2: Edit SQL dump to remove CREATE DATABASE (not recommended)
```

### Restore Command Fails with "ERROR: role does not exist"

**Symptoms:**
```
ERROR:  role "myapp_user" does not exist
```

**Cause:** Backup includes grants to roles that don't exist yet

**Resolution:**
```bash
# Option 1: Create missing role before restore
kubectl exec -it postgres-postgresql-0 -n data -- \
  env PGPASSWORD=$POSTGRES_PASSWORD psql -U postgres \
  -c "CREATE ROLE myapp_user WITH LOGIN PASSWORD 'password';"

# Option 2: Use pg_dumpall which includes role definitions
# (This is the default for our backup system)

# Verify roles exist
kubectl exec -it postgres-postgresql-0 -n data -- \
  env PGPASSWORD=$POSTGRES_PASSWORD psql -U postgres -c "\du"
```

### Restore Hangs or Takes Extremely Long

**Symptoms:**
- Restore process runs for > 30 minutes for small database
- No progress output

**Diagnosis:**
```bash
# Check PostgreSQL pod resources
kubectl top pod postgres-postgresql-0 -n data

# Check for long-running queries
kubectl exec -it postgres-postgresql-0 -n data -- \
  env PGPASSWORD=$POSTGRES_PASSWORD psql -U postgres \
  -c "SELECT pid, usename, state, query FROM pg_stat_activity WHERE state = 'active';"

# Check for locks
kubectl exec -it postgres-postgresql-0 -n data -- \
  env PGPASSWORD=$POSTGRES_PASSWORD psql -U postgres \
  -c "SELECT * FROM pg_locks WHERE NOT granted;"
```

**Resolution:**
- Stop applications that may be holding locks
- Increase PostgreSQL pod resources if CPU/memory constrained
- Consider using pg_restore with --jobs flag for parallel restore (requires custom format backup)

### Backup File Corrupted or Cannot Be Read

**Symptoms:**
```
gzip: stdin: not in gzip format
ERROR: syntax error at or near "..."
```

**Diagnosis:**
```bash
# Verify file is gzipped
kubectl exec backup-extract -n data -- file /backup/$BACKUP_FILE

# Try to extract manually
kubectl exec backup-extract -n data -- gunzip -t /backup/$BACKUP_FILE

# Check file size (should be > 0)
kubectl exec backup-extract -n data -- ls -lh /backup/$BACKUP_FILE
```

**Resolution:**
- Use a different backup file if available
- Check Synology NFS share for backup file integrity
- Restore from Synology snapshots if all backups corrupted
- Review backup CronJob logs for backup creation failures

### Restored Data is Missing Records

**Symptoms:**
- Database restored but some tables have fewer rows than expected
- Foreign key violations during application use

**Diagnosis:**
```bash
# Check restore command output for errors
# Look for "ERROR" or "WARNING" messages

# Verify backup file contains all data
kubectl exec backup-extract -n data -- \
  sh -c "zcat /backup/$BACKUP_FILE | grep -c 'INSERT'"

# Compare row counts between backup file and restored database
kubectl exec backup-extract -n data -- \
  sh -c "zcat /backup/$BACKUP_FILE | grep 'COPY.*FROM stdin' -A 100"
```

**Resolution:**
- Use older backup if data is missing from current backup
- Check if backup was taken during active writes (backup at 2 AM UTC to minimize this)
- Verify backup completed successfully (check CronJob logs)

### Permission Denied Writing to /tmp in PostgreSQL Pod

**Symptoms:**
```
cannot create file /tmp/postgres-backup-...sql.gz: Permission denied
```

**Resolution:**
```bash
# Use /bitnami/postgresql/tmp instead (Bitnami image writable directory)
kubectl cp ./$BACKUP_FILE data/postgres-postgresql-0:/bitnami/postgresql/tmp/$BACKUP_FILE

# Or use home directory
kubectl cp ./$BACKUP_FILE data/postgres-postgresql-0:~/$BACKUP_FILE

# Verify writable location
kubectl exec -n data postgres-postgresql-0 -- touch /bitnami/postgresql/tmp/test && \
kubectl exec -n data postgres-postgresql-0 -- rm /bitnami/postgresql/tmp/test
```

---

## Alternative Restore Methods

### Method A: Restore Using Custom Format (pg_restore)

If backups are created with `pg_dump -Fc` (custom format):

```bash
# Restore with parallel jobs (faster for large databases)
kubectl exec -n data postgres-postgresql-0 -- \
  env PGPASSWORD=$POSTGRES_PASSWORD \
  pg_restore -U postgres -d postgres --jobs=4 /tmp/backup.dump

# Restore specific tables only
kubectl exec -n data postgres-postgresql-0 -- \
  env PGPASSWORD=$POSTGRES_PASSWORD \
  pg_restore -U postgres -d backup_test --table=users /tmp/backup.dump
```

**Note:** Current backup system uses pg_dumpall (SQL format), not custom format.

### Method B: Restore from Synology Snapshot

If backup PVC is corrupted or all backups are lost:

1. Access Synology DSM web interface
2. Navigate to Snapshot Replication
3. Find snapshot of `/volume1/k8s-data/data-postgres-backup-pvc-*`
4. Restore snapshot to original location or new location
5. Update PVC to point to restored snapshot location
6. Follow standard restore procedure (Steps 1-8)

**Recovery Time:** < 30 minutes (depending on snapshot size)

### Method C: Restore from Application-Level Backup

If PostgreSQL backups are unavailable, restore from application exports:

- n8n: Import workflows from JSON export
- Paperless-ngx: Re-import documents from filesystem
- Custom apps: Use application-specific backup/restore procedures

**Note:** This is last resort if all PostgreSQL backups are lost.

---

## Restore Testing Recommendations

### Quarterly Restore Validation

Perform test restores quarterly to validate disaster recovery procedures:

**Test Schedule:**
- Q1 (January): Restore to temporary database, verify data integrity
- Q2 (April): Full cluster restore to dev environment
- Q3 (July): Restore specific database, measure RTO
- Q4 (October): Simulate disaster scenario, full recovery

**Test Checklist:**
- [ ] Identify backup file from last week
- [ ] Execute restore to test database
- [ ] Verify all tables and row counts
- [ ] Verify foreign key relationships
- [ ] Measure restore time and document
- [ ] Clean up test database

### Monthly Backup Verification

Verify backup files are valid and accessible:

```bash
# List backup files
kubectl run backup-verify --image=busybox --restart=Never -n data --rm -it \
  --overrides='{"spec":{"containers":[{"name":"verify","image":"busybox","command":["sh","-c","ls -lh /backup && echo && echo Verifying most recent backup: && zcat /backup/postgres-backup-*.sql.gz | head -50"],"volumeMounts":[{"name":"backup","mountPath":"/backup"}]}],"volumes":[{"name":"backup","persistentVolumeClaim":{"claimName":"postgres-backup"}}]}}'

# Expected: Valid SQL dump header and statements
```

---

## Related Documentation

- [PostgreSQL Backup Runbook](postgres-backup.md) - Automated backup procedures
- [PostgreSQL Setup Runbook](postgres-setup.md) - PostgreSQL deployment and configuration
- [PostgreSQL README](../../applications/postgres/README.md) - Application overview
- [Story 5.3 - Setup PostgreSQL Backup](../implementation-artifacts/5-3-setup-postgresql-backup-with-pg-dump.md)
- [Story 5.4 - Validate PostgreSQL Restore](../implementation-artifacts/5-4-validate-postgresql-restore-procedure.md)

---

## Change Log

- 2026-01-06: Initial restore runbook creation - Validated restore procedures with destructive testing (Story 5.4)
