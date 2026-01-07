# Story 5.3: Setup PostgreSQL Backup with pg_dump

Status: done

## Story

As a **cluster operator**,
I want **to backup PostgreSQL databases to NFS automatically**,
So that **I can recover from data corruption or accidental deletion**.

## Acceptance Criteria

1. **Given** PostgreSQL is running with data
   **When** I create a test database and table with sample data
   **Then** the data is queryable via psql

2. **Given** test data exists
   **When** I create a CronJob that runs pg_dump daily to an NFS-backed PVC
   **Then** the CronJob is created in the data namespace
   **And** the CronJob manifest is saved at `applications/postgres/backup-cronjob.yaml`

3. **Given** the backup CronJob exists
   **When** I trigger a manual run with `kubectl create job --from=cronjob/postgres-backup manual-backup -n data`
   **Then** the backup job runs successfully
   **And** a .sql.gz file is created in the backup PVC

4. **Given** backup file exists
   **When** I verify the backup file on Synology NFS share
   **Then** the file contains valid SQL dump
   **And** file size is reasonable for the data volume
   **And** this validates FR33 (backup PostgreSQL to NFS)

5. **Given** backups are working
   **When** I check backup retention
   **Then** the script retains the last 7 daily backups
   **And** older backups are automatically deleted

## Tasks / Subtasks

⚠️ **DRAFT TASKS** - Generated from requirements analysis. Will be validated and refined against actual codebase when dev-story runs.

### Task 1: Create Test Database and Sample Data (AC: 1)
- [x] 1.1: Connect to PostgreSQL via kubectl exec
- [x] 1.2: Create test database `backup_test`
- [x] 1.3: Create test table with sample data (users, transactions)
- [x] 1.4: Verify data is queryable via psql

### Task 2: Create Backup PVC for pg_dump Files (AC: 2)
- [x] 2.1: Create PVC manifest for backup storage (postgres-backup-pvc)
- [x] 2.2: Configure PVC with nfs-client StorageClass
- [x] 2.3: Set appropriate storage size (10Gi for backups)
- [x] 2.4: Apply PVC and verify it's bound

### Task 3: Create Backup CronJob Manifest (AC: 2)
- [x] 3.1: Create `applications/postgres/backup-cronjob.yaml`
- [x] 3.2: Configure CronJob to run daily at 2 AM (schedule: "0 2 * * *")
- [x] 3.3: Configure pg_dump command with compression (pg_dump -U postgres | gzip > /backup/...)
- [x] 3.4: Mount both PostgreSQL secret and backup PVC
- [x] 3.5: Add backup retention logic (delete backups older than 7 days)
- [x] 3.6: Add labels for consistency (app.kubernetes.io/part-of: home-lab)

### Task 4: Deploy CronJob and Trigger Manual Backup (AC: 3)
- [x] 4.1: Apply backup-cronjob.yaml to cluster
- [x] 4.2: Verify CronJob is created: `kubectl get cronjob -n data`
- [x] 4.3: Trigger manual backup run: `kubectl create job --from=cronjob/postgres-backup manual-backup -n data`
- [x] 4.4: Monitor job completion: `kubectl get jobs -n data`
- [x] 4.5: Check job logs for any errors

### Task 5: Verify Backup File Created (AC: 4)
- [x] 5.1: List files in backup PVC: `kubectl exec -n data <backup-pod> -- ls -lh /backup`
- [x] 5.2: Verify .sql.gz file exists with current date
- [x] 5.3: Check file size is reasonable (>0 bytes)
- [x] 5.4: Extract and validate SQL dump structure
- [x] 5.5: Verify backup contains test database and data

### Task 6: Verify NFS Share Contains Backup (AC: 4)
- [x] 6.1: Check Synology NFS share for backup PVC directory
- [x] 6.2: Verify .sql.gz file is accessible on NFS
- [x] 6.3: Confirm file integrity (not corrupted)
- [x] 6.4: Document NFS path for reference

### Task 7: Test Backup Retention Logic (AC: 5)
- [x] 7.1: Create multiple manual backups to simulate 8+ days
- [x] 7.2: Verify only 7 most recent backups are retained
- [x] 7.3: Confirm older backups are deleted automatically
- [x] 7.4: Check retention script handles edge cases

### Task 8: Update Documentation
- [x] 8.1: Update applications/postgres/README.md with backup details
- [x] 8.2: Create docs/runbooks/postgres-backup.md with backup procedures
- [x] 8.3: Document CronJob schedule and configuration
- [x] 8.4: Document manual backup trigger procedure
- [x] 8.5: Document backup file location and retention policy

## Gap Analysis

**Scan Date:** 2026-01-06

### What Exists:

**Infrastructure:**
- ✅ PostgreSQL 18.1 running with NFS persistence (Story 5.2 complete)
- ✅ Existing PVC: `data-postgres-postgresql-0` (8Gi, nfs-client)
- ✅ PostgreSQL Secret: `postgres-postgresql` with credentials
- ✅ Test database: `test_persistence` (from Story 5.2)
- ✅ Documentation: `postgres-setup.md` runbook exists
- ✅ Applications directory: `applications/postgres/` with values-homelab.yaml and README.md

### What's Missing:

- ❌ Backup PVC for storing pg_dump files
- ❌ CronJob for automated backups (no CronJobs in data namespace)
- ❌ `backup-cronjob.yaml` manifest file
- ❌ `backup-pvc.yaml` manifest file
- ❌ `docs/runbooks/postgres-backup.md` runbook
- ❌ Test database with sample data for backup validation

### Task Changes Applied:

**NO CHANGES NEEDED** - Draft tasks accurately reflect current codebase state. All tasks address missing backup infrastructure components.

---

## Dev Notes

### Technical Requirements

**Source:** [docs/planning-artifacts/epics.md#Story 5.3]

**Backup Strategy:**
- Use pg_dump for logical backups (full database export)
- Compress backups with gzip to save storage space
- Store backups on NFS-backed PVC (separate from PostgreSQL data PVC)
- Daily automated backups via CronJob at 2 AM
- Retain last 7 daily backups, delete older backups automatically

**Backup File Naming:**
- Pattern: `postgres-backup-YYYY-MM-DD-HHMMSS.sql.gz`
- Example: `postgres-backup-2026-01-06-020000.sql.gz`

**Backup Scope:**
- All databases (use `pg_dumpall` for cluster-wide backup)
- Alternative: Individual database backups with `pg_dump <database>`

**CronJob Configuration:**
- Schedule: `0 2 * * *` (daily at 2 AM)
- Restart policy: OnFailure
- Backoff limit: 3
- TTL after finished: 86400 (24 hours)

### Architecture Compliance

**Source:** [docs/planning-artifacts/architecture.md]

**Backup Decision:**
- **Choice:** pg_dump to NFS-backed PVC
- **Rationale:**
  - Logical backups are portable and version-independent
  - NFS provides network-accessible backup storage
  - Kubernetes CronJob provides automation
  - Complements Synology snapshots (physical backup layer)

**Storage Architecture:**
- PostgreSQL Data PVC: `data-postgres-postgresql-0` (8Gi, existing from Story 5.2)
- Backup PVC: `postgres-backup` (10Gi, new for backups)
- Both use nfs-client StorageClass
- Both stored on Synology NFS share (192.168.2.2)

**CronJob Pattern:**
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: postgres-backup
  namespace: data
  labels:
    app.kubernetes.io/name: postgres
    app.kubernetes.io/component: backup
    app.kubernetes.io/part-of: home-lab
spec:
  schedule: "0 2 * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: registry-1.docker.io/bitnami/postgresql:18.1.0
            command: ["/bin/bash", "-c"]
            args:
              - |
                # Backup script with retention logic
                BACKUP_FILE="/backup/postgres-backup-$(date +%Y-%m-%d-%H%M%S).sql.gz"
                pg_dumpall -U postgres | gzip > $BACKUP_FILE

                # Retention: keep last 7 backups
                cd /backup
                ls -t postgres-backup-*.sql.gz | tail -n +8 | xargs -r rm
            env:
            - name: PGPASSWORD
              valueFrom:
                secretKeyRef:
                  name: postgres-postgresql
                  key: postgres-password
            - name: PGHOST
              value: postgres-postgresql.data.svc.cluster.local
            volumeMounts:
            - name: backup
              mountPath: /backup
          volumes:
          - name: backup
            persistentVolumeClaim:
              claimName: postgres-backup
          restartPolicy: OnFailure
```

### Library/Framework Requirements

**PostgreSQL Tools:**
- pg_dump / pg_dumpall: Built into Bitnami PostgreSQL image
- Version: 18.1 (matches deployed PostgreSQL version)
- No additional dependencies required

**Kubernetes Resources:**
- CronJob API: batch/v1
- PersistentVolumeClaim: v1
- Job: batch/v1 (for manual triggers)

### File Structure Requirements

**Source:** [docs/planning-artifacts/architecture.md#Directory Structure]

**New Files to Create:**
```
applications/postgres/
├── backup-cronjob.yaml          # CronJob manifest for pg_dump automation
├── backup-pvc.yaml               # PVC for backup storage

docs/runbooks/
└── postgres-backup.md            # Backup operational runbook
```

**Files to Modify:**
```
applications/postgres/
└── README.md                     # Add backup section

docs/runbooks/
└── postgres-setup.md             # Add reference to backup runbook
```

### Testing Requirements

**Backup Creation Validation:**
1. CronJob created successfully
2. Manual backup job runs without errors
3. .sql.gz file created in backup PVC
4. File size is reasonable (non-zero, matches data volume)
5. File is valid gzipped SQL dump

**Backup Content Validation:**
1. Backup contains all databases
2. Backup contains test data
3. Backup is compressed (gzip format)
4. SQL dump is syntactically valid

**Retention Policy Validation:**
1. 7 most recent backups retained
2. 8th and older backups deleted automatically
3. Retention runs after each backup

**NFR Validation:**
- FR33: Backup PostgreSQL to NFS ✅
- Backups automated via CronJob ✅
- Retention policy enforced ✅

### Previous Story Intelligence

**Source:** [docs/implementation-artifacts/5-2-configure-nfs-persistence-for-postgresql.md]

**Key Learnings from Story 5.2:**

**NFS Storage Configuration:**
- StorageClass: nfs-client (nfs-subdir-external-provisioner)
- NFS Server: 192.168.2.2 (Synology DS920+)
- NFS Path: `/volume1/k8s-data/`
- PVC Pattern: `<pvc-name>-pvc-<uid>/` directory created automatically
- Access Mode: ReadWriteOnce (RWO) for single-node access

**PostgreSQL Deployment:**
- PostgreSQL 18.1 via Bitnami Helm chart 18.2.0
- Namespace: data
- StatefulSet: postgres-postgresql
- Pod: postgres-postgresql-0
- Service: postgres-postgresql.data.svc.cluster.local:5432
- Password Secret: postgres-postgresql (key: postgres-password)

**NFS PVC Creation Pattern:**
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-backup
  namespace: data
  labels:
    app.kubernetes.io/name: postgres
    app.kubernetes.io/component: backup
    app.kubernetes.io/part-of: home-lab
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: nfs-client
  resources:
    requests:
      storage: 10Gi
```

**kubectl Commands from Previous Stories:**
```bash
# Get password from secret
export POSTGRES_PASSWORD=$(kubectl get secret postgres-postgresql -n data -o jsonpath="{.data.postgres-password}" | base64 -d)

# Connect to PostgreSQL
kubectl exec -it postgres-postgresql-0 -n data -- env PGPASSWORD=$POSTGRES_PASSWORD psql -U postgres

# Check PVC status
kubectl get pvc -n data
kubectl describe pvc <pvc-name> -n data

# Check CronJob
kubectl get cronjob -n data
kubectl describe cronjob postgres-backup -n data

# Trigger manual backup
kubectl create job --from=cronjob/postgres-backup manual-backup-$(date +%Y%m%d%H%M%S) -n data
```

### Project Context Reference

**Source:** [CLAUDE.md, docs/FOLDER_DOCUMENTATION.md]

**Backup Architecture:**
- Automated via Kubernetes CronJob
- Logical backups with pg_dump/pg_dumpall
- NFS storage provides network-accessible backup location
- 7-day retention policy balances storage vs recovery window
- Complements Synology snapshot-based backups (physical layer)

**Testing Pattern:**
- Create test data for backup validation
- Trigger manual backup to verify automation
- Validate backup file contents
- Test retention policy with multiple backups

**Documentation Requirements:**
- All operational procedures in runbooks
- Backup schedules and retention documented
- Recovery procedures documented (Story 5.4)

---

## Dev Agent Record

### Agent Model Used

Sonnet 4.5 (claude-sonnet-4-5-20250929)

### Debug Log References

No critical errors encountered during implementation.

**Image Tag Issue Resolved:**
- Initial CronJob used `bitnami/postgresql:18.1.0` tag (not found)
- Updated to `:latest` tag to match running PostgreSQL pod
- Job succeeded after image tag correction

### Completion Notes List

1. **Test Database Created**: backup_test database with users (3 records) and transactions (5 records) tables
2. **Backup PVC Provisioned**: postgres-backup PVC (10Gi, nfs-client) bound to NFS at 192.168.2.2:/volume1/k8s-data/data-postgres-backup-pvc-b517292a-137a-4dc8-9007-fd99f9934bbd
3. **CronJob Deployed**: postgres-backup CronJob scheduled daily at 2 AM UTC (0 2 * * *)
4. **Manual Backup Tested**: ✅ Backup job completed successfully in 2 seconds, created 2.2K compressed backup file
5. **Backup Validation**: ✅ Backup file contains valid PostgreSQL cluster dump with all databases including test data
6. **Retention Policy Verified**: ✅ Created 8 backup jobs, retention script correctly kept only 7 most recent backups
7. **NFS Storage Verified**: ✅ Backup files accessible on NFS share via PVC
8. **Documentation Complete**: README.md updated with backup section, postgres-backup.md runbook created with comprehensive procedures
9. **FR33 Validated**: ✅ Backup PostgreSQL to NFS storage (AC4)
10. **All Acceptance Criteria Met**: ✅ Test data created, CronJob deployed, manual backup successful, backup file valid, retention policy working

### File List

**Created:**
- `/home/tt/Workspace/home-lab/applications/postgres/backup-pvc.yaml` - PVC manifest for backup storage (10Gi, nfs-client)
- `/home/tt/Workspace/home-lab/applications/postgres/backup-cronjob.yaml` - CronJob manifest for automated pg_dumpall backups
- `/home/tt/Workspace/home-lab/docs/runbooks/postgres-backup.md` - Comprehensive backup & recovery runbook

**Modified:**
- `/home/tt/Workspace/home-lab/applications/postgres/README.md` - Added "Backup & Recovery" section with backup configuration, manual backup procedures, verification commands
- `/home/tt/Workspace/home-lab/docs/runbooks/postgres-setup.md` - Added reference to postgres-backup.md runbook
- `/home/tt/Workspace/home-lab/docs/implementation-artifacts/sprint-status.yaml` - Updated story status (line 81)
- `/home/tt/Workspace/home-lab/docs/implementation-artifacts/5-3-setup-postgresql-backup-with-pg-dump.md` - Gap analysis, task completion, dev notes

**Kubernetes Resources Created:**
- PVC: `postgres-backup` (data namespace, 10Gi, bound)
- CronJob: `postgres-backup` (data namespace, schedule: 0 2 * * *)
- Manual backup job: `manual-backup-20260106174921` (completed successfully)
- Test database: `backup_test` with users and transactions tables

---

### Change Log

- 2026-01-06: Story created with requirements analysis and draft implementation tasks
- 2026-01-06: Gap analysis completed - verified no backup infrastructure exists, tasks validated
- 2026-01-06: Story implementation completed - Automated backup system deployed with CronJob, PVC, 7-day retention policy; all acceptance criteria validated, marked for review
- 2026-01-06: Story marked as done - Automated PostgreSQL backup system operational with daily backups to NFS and 7-day retention
