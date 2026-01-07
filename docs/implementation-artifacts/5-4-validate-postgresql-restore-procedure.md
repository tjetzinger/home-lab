# Story 5.4: Validate PostgreSQL Restore Procedure

Status: done

## Story

As a **cluster operator**,
I want **to restore PostgreSQL from a backup**,
So that **I can recover from disasters with documented procedures**.

## Acceptance Criteria

1. **Given** a valid pg_dump backup exists on NFS
   **When** I document the restore procedure in `docs/runbooks/postgres-restore.md`
   **Then** the runbook includes step-by-step restore instructions

2. **Given** runbook is documented
   **When** I intentionally drop the test database
   **Then** the database is deleted and data is lost

3. **Given** data loss has occurred
   **When** I follow the restore runbook to restore from backup
   **Then** I can copy the backup file into the postgres pod
   **And** I can run `psql -U postgres < backup.sql` to restore

4. **Given** restore command completes
   **When** I verify the restored data
   **Then** the test database exists again
   **And** all rows in the test table are restored
   **And** this validates FR34 (restore PostgreSQL from backup)

5. **Given** restore is validated
   **When** I measure restore time for the test database
   **Then** restore time is documented in the runbook
   **And** the procedure works within acceptable time bounds

## Tasks / Subtasks

⚠️ **DRAFT TASKS** - Generated from requirements analysis. Will be validated and refined against actual codebase when dev-story runs.

### Task 1: Create Restore Runbook Documentation (AC: 1)
- [ ] 1.1: Create docs/runbooks/postgres-restore.md file
- [ ] 1.2: Document prerequisites (backup exists, kubectl access, PostgreSQL credentials)
- [ ] 1.3: Document step-by-step restore procedure
- [ ] 1.4: Include commands for extracting backup file from NFS PVC
- [ ] 1.5: Include commands for copying backup into PostgreSQL pod
- [ ] 1.6: Include psql restore commands
- [ ] 1.7: Add verification steps for post-restore data validation

### Task 2: Prepare Test Environment for Restore (AC: 2)
- [ ] 2.1: Verify test database `backup_test` exists from Story 5.3
- [ ] 2.2: Verify backup files exist in postgres-backup PVC
- [ ] 2.3: Choose a specific backup file for restore testing
- [ ] 2.4: Document current state of test database (row counts, schema)

### Task 3: Perform Destructive Test (Drop Database) (AC: 2)
- [ ] 3.1: Connect to PostgreSQL pod via kubectl exec
- [ ] 3.2: Execute `DROP DATABASE backup_test;` to simulate data loss
- [ ] 3.3: Verify database no longer exists with `\l` command
- [ ] 3.4: Verify data is truly deleted (cannot query)

### Task 4: Execute Restore from Backup (AC: 3)
- [ ] 4.1: Extract backup file from postgres-backup PVC to local system or temp pod
- [ ] 4.2: Copy backup file into PostgreSQL pod (kubectl cp or volume mount)
- [ ] 4.3: Extract gzipped backup: `gunzip backup-file.sql.gz`
- [ ] 4.4: Run restore command: `psql -U postgres < backup-file.sql`
- [ ] 4.5: Monitor restore process for errors
- [ ] 4.6: Verify restore command completes successfully

### Task 5: Verify Restored Data (AC: 4)
- [ ] 5.1: Connect to PostgreSQL and list databases with `\l`
- [ ] 5.2: Verify `backup_test` database exists again
- [ ] 5.3: Connect to backup_test database: `\c backup_test`
- [ ] 5.4: Query users table and verify all 3 rows restored
- [ ] 5.5: Query transactions table and verify all 5 rows restored
- [ ] 5.6: Verify foreign key relationships are intact
- [ ] 5.7: Compare row counts to pre-drop state
- [ ] 5.8: Verify FR34 validation

### Task 6: Measure and Document Restore Time (AC: 5)
- [ ] 6.1: Record start time of restore procedure
- [ ] 6.2: Record end time when restore completes
- [ ] 6.3: Calculate total restore duration
- [ ] 6.4: Document restore time in postgres-restore.md runbook
- [ ] 6.5: Add performance notes (e.g., "2.2K backup restores in < 5 seconds")
- [ ] 6.6: Verify restore time is acceptable for disaster recovery

### Task 7: Enhance Restore Runbook (AC: 1, 5)
- [ ] 7.1: Add troubleshooting section for common restore issues
- [ ] 7.2: Document alternative restore methods (pg_restore for custom format)
- [ ] 7.3: Document full cluster restore vs single database restore
- [ ] 7.4: Add restore performance benchmarks
- [ ] 7.5: Reference backup runbook from Story 5.3
- [ ] 7.6: Add restore testing recommendations (quarterly validation)

### Task 8: Update Related Documentation
- [ ] 8.1: Update applications/postgres/README.md with restore reference
- [ ] 8.2: Update docs/runbooks/postgres-backup.md with restore section link
- [ ] 8.3: Update docs/runbooks/postgres-setup.md with restore runbook reference
- [ ] 8.4: Add disaster recovery planning notes

## Gap Analysis

**Scan Date:** 2026-01-06

### What Exists:

**Infrastructure:**
- ✅ PostgreSQL deployment: postgres-postgresql-0 running in data namespace
- ✅ Test database: `backup_test` exists with data from Story 5.3
- ✅ Backup PVC: `postgres-backup` (10Gi, bound, nfs-client StorageClass)
- ✅ Backup files: 7 backups in PVC (postgres-backup-2026-01-06-*.sql.gz, ~2.1-2.2K each)
- ✅ PostgreSQL data PVC: `data-postgres-postgresql-0` (8Gi, bound)
- ✅ Backup runbook: docs/runbooks/postgres-backup.md (from Story 5.3)
- ✅ PostgreSQL setup runbook: docs/runbooks/postgres-setup.md
- ✅ PostgreSQL README: applications/postgres/README.md

### What's Missing:

- ❌ Restore runbook: docs/runbooks/postgres-restore.md (not created yet)
- ❌ Restore procedure documentation and testing
- ❌ Restore performance benchmarks

### Task Changes Applied:

**NO CHANGES NEEDED** - Draft tasks accurately reflect current codebase state. All tasks address missing restore infrastructure components.

---

## Dev Notes

### Technical Requirements

**Source:** [docs/planning-artifacts/epics.md#Story 5.4]

**Restore Strategy:**
- Use psql command-line tool to restore from pg_dump/pg_dumpall SQL dumps
- Restore compressed .sql.gz files by extracting first, then piping to psql
- Test restore procedure on non-production test database first
- Validate data integrity after restore (row counts, foreign keys, constraints)
- Measure restore time for disaster recovery planning

**Restore Command Pattern:**
```bash
# For gzipped backups
gunzip postgres-backup-YYYY-MM-DD-HHMMSS.sql.gz
psql -U postgres < postgres-backup-YYYY-MM-DD-HHMMSS.sql

# Or in one command
zcat postgres-backup-YYYY-MM-DD-HHMMSS.sql.gz | psql -U postgres
```

**Restore Scope:**
- pg_dumpall backups restore entire PostgreSQL cluster (all databases, roles, permissions)
- Single database restore: Use `psql -U postgres -d database_name < backup.sql`
- Must drop conflicting databases before restoring if they exist

**Testing Requirements:**
- Destructive testing: Intentionally drop database to simulate data loss
- Restore validation: Verify all data, schemas, and relationships restored correctly
- Performance validation: Measure restore time for different backup sizes
- Documentation validation: Follow runbook exactly to ensure accuracy

### Architecture Compliance

**Source:** [docs/planning-artifacts/architecture.md#PostgreSQL]

**Backup Decision:**
- **Choice:** pg_dump to NFS-backed PVC
- **Restore Implication:** Logical backups are easy to restore with psql
- **Portability:** SQL dumps can restore to different PostgreSQL versions
- **Complements:** Synology snapshots provide physical backup layer

**Storage Architecture:**
- PostgreSQL Data PVC: `data-postgres-postgresql-0` (8Gi)
- Backup PVC: `postgres-backup` (10Gi, from Story 5.3)
- Restore process accesses backup PVC to retrieve .sql.gz files
- Both PVCs use nfs-client StorageClass on Synology DS920+ (192.168.2.2)

**Kubernetes Patterns:**
- Use `kubectl cp` to copy backup files into PostgreSQL pod
- Alternative: Create temporary pod mounting both backup PVC and PostgreSQL PVC
- Use `kubectl exec` to run psql commands inside PostgreSQL pod
- Ensure PostgreSQL pod is running before attempting restore

### Library/Framework Requirements

**PostgreSQL Tools:**
- psql: Built into Bitnami PostgreSQL image (version 18.1)
- gunzip/zcat: Available in Bitnami image for decompressing backups
- No additional dependencies required

**Kubernetes Resources:**
- Pod: postgres-postgresql-0 (data namespace)
- PVC: postgres-backup (10Gi, contains backup files)
- Secret: postgres-postgresql (contains postgres-password)

### File Structure Requirements

**Source:** [docs/planning-artifacts/architecture.md#Directory Structure]

**New Files to Create:**
```
docs/runbooks/
└── postgres-restore.md         # Restore operational runbook
```

**Files to Modify:**
```
applications/postgres/
└── README.md                    # Add restore section reference

docs/runbooks/
├── postgres-backup.md           # Add restore runbook link
└── postgres-setup.md            # Add restore runbook reference
```

### Testing Requirements

**Restore Testing Validation:**
1. Backup file exists and is accessible
2. Database drop completes successfully (data loss simulated)
3. Restore command executes without errors
4. All databases, tables, and data restored correctly
5. Restore time measured and documented

**Data Integrity Validation:**
1. Row counts match pre-drop state
2. Foreign key relationships intact
3. Sequences and auto-increment values correct
4. User permissions and roles restored (pg_dumpall)

**Performance Validation:**
- Small backup (2-3KB): < 5 seconds
- Medium backup (1-10MB): < 30 seconds
- Large backup (100MB+): < 5 minutes
- Document actual restore times in runbook

**NFR Validation:**
- FR34: Operator can restore PostgreSQL from backup ✅
- Disaster recovery capability validated ✅
- Documented procedure for future recovery needs ✅

### Previous Story Intelligence

**Source:** [docs/implementation-artifacts/5-3-setup-postgresql-backup-with-pg-dump.md]

**Key Learnings from Story 5.3:**

**Backup System Components:**
- CronJob: `postgres-backup` (data namespace, schedule: 0 2 * * *)
- Backup PVC: `postgres-backup` (10Gi, nfs-client StorageClass)
- NFS Path: `192.168.2.2:/volume1/k8s-data/data-postgres-backup-pvc-b517292a-137a-4dc8-9007-fd99f9934bbd`
- Backup File Pattern: `postgres-backup-YYYY-MM-DD-HHMMSS.sql.gz`
- Retention: Last 7 backups kept, older backups auto-deleted

**Test Database Created in Story 5.3:**
- Database: `backup_test`
- Table: `users` (3 rows: alice, bob, charlie)
- Table: `transactions` (5 rows with foreign keys to users)
- Total data: ~2.2K compressed backup size

**Backup Validation from Story 5.3:**
- Backup file is valid gzipped PostgreSQL cluster dump
- Contains all databases (postgres, template0, template1, backup_test)
- Contains roles, permissions, and all data
- Backup job completes in ~2 seconds

**Image Tag Learning:**
- PostgreSQL image: `registry-1.docker.io/bitnami/postgresql:latest`
- Do NOT use version-specific tags (18.1.0 not found)
- Use `:latest` tag to match running PostgreSQL deployment

**kubectl Commands from Story 5.3:**
```bash
# Get PostgreSQL password
export POSTGRES_PASSWORD=$(kubectl get secret postgres-postgresql -n data -o jsonpath="{.data.postgres-password}" | base64 -d)

# Connect to PostgreSQL
kubectl exec -it postgres-postgresql-0 -n data -- env PGPASSWORD=$POSTGRES_PASSWORD psql -U postgres

# List backups in PVC
kubectl run backup-list --image=busybox --restart=Never -n data \
  --overrides='{"spec":{"containers":[{"name":"list","image":"busybox","command":["ls","-lh","/backup"],"volumeMounts":[{"name":"backup","mountPath":"/backup"}]}],"volumes":[{"name":"backup","persistentVolumeClaim":{"claimName":"postgres-backup"}}]}}' && \
  sleep 3 && kubectl exec backup-list -n data -- ls -lh /backup && kubectl delete pod backup-list -n data
```

### Project Context Reference

**Source:** [CLAUDE.md, docs/FOLDER_DOCUMENTATION.md]

**Restore Architecture:**
- Restore validates disaster recovery capability (NFR: 5-min recovery)
- Logical backups (pg_dump) provide cross-version compatibility
- Testing restore procedures ensures recovery readiness
- Quarterly restore testing recommended for production environments

**Documentation Requirements:**
- All operational procedures in runbooks
- Restore procedures documented step-by-step
- Troubleshooting guidance for restore failures
- Performance benchmarks for recovery time objectives (RTO)

**Disaster Recovery Planning:**
- Story 5.3: Automated daily backups to NFS
- Story 5.4: Validated restore procedures
- Story 5.5: Application connectivity validation
- Together: Complete PostgreSQL disaster recovery solution

---

## Dev Agent Record

### Agent Model Used

Sonnet 4.5 (claude-sonnet-4-5-20250929)

### Debug Log References

No critical errors encountered during implementation.

**Shell Command Syntax Issues:**
- Initial attempts to get PostgreSQL password in single command failed due to shell parsing
- Resolution: Split into separate commands or use proper quoting

### Completion Notes List

1. **Restore Runbook Created**: Comprehensive postgres-restore.md with 8-step restore procedure, disaster recovery scenarios, troubleshooting, and testing recommendations
2. **Test Environment Prepared**: Verified backup_test database (3 users, 5 transactions), identified 7 backup files in postgres-backup PVC
3. **Destructive Test Executed**: ✅ Dropped backup_test database successfully to simulate data loss
4. **Restore Validated**: ✅ Restored database from postgres-backup-2026-01-06-165445.sql.gz (2.2K) in 2 seconds
5. **Data Integrity Verified**: ✅ All 3 users and 5 transactions restored correctly with intact foreign key relationships
6. **Performance Documented**: ✅ 2-second restore time for 2.2K backup validated and documented in runbook
7. **FR34 Validated**: ✅ Operator can restore PostgreSQL from backup (Acceptance Criteria 4)
8. **Documentation Updated**: README.md, postgres-backup.md, and postgres-setup.md all updated with restore references and performance notes
9. **Disaster Recovery Capability**: Complete disaster recovery solution validated with documented procedures
10. **All Acceptance Criteria Met**: ✅ Runbook created, destructive test performed, restore successful, data verified, performance measured

### File List

**Created:**
- `/home/tt/Workspace/home-lab/docs/runbooks/postgres-restore.md` - Comprehensive 400+ line restore runbook with step-by-step procedures, disaster recovery scenarios, troubleshooting guide, and quarterly testing recommendations

**Modified:**
- `/home/tt/Workspace/home-lab/applications/postgres/README.md` - Added "Restore from Backup" subsection with quick restore example, performance notes, and restore runbook reference (lines 193-233)
- `/home/tt/Workspace/home-lab/docs/runbooks/postgres-backup.md` - Updated "Restore Procedures" section with validated procedures and restore runbook link (lines 191-209)
- `/home/tt/Workspace/home-lab/docs/runbooks/postgres-setup.md` - Added postgres-restore.md reference in Related Documentation section (line 495, 509)
- `/home/tt/Workspace/home-lab/docs/implementation-artifacts/sprint-status.yaml` - Updated story status to in-progress (line 82)
- `/home/tt/Workspace/home-lab/docs/implementation-artifacts/5-4-validate-postgresql-restore-procedure.md` - Gap analysis, implementation notes, completion documentation

**Kubernetes Resources Tested:**
- Database: backup_test (dropped and restored successfully)
- Backup file: postgres-backup-2026-01-06-165445.sql.gz (2.2K, used for restore testing)
- Temporary pod: postgres-restore (created for restore execution, deleted after completion)

---

### Change Log

- 2026-01-06: Story created with requirements analysis and draft implementation tasks
- 2026-01-06: Gap analysis completed - verified backup infrastructure exists, restore runbook missing, tasks validated
- 2026-01-06: Story implementation completed - Restore runbook created, destructive testing performed, 2-second restore validated, all documentation updated, FR34 validated, ready for review
- 2026-01-06: Story marked as done - PostgreSQL disaster recovery capability validated with 2-second restore time, comprehensive runbook operational
