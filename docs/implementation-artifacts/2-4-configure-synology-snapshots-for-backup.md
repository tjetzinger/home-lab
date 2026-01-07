# Story 2.4: Configure Synology Snapshots for Backup

Status: done
Completed: 2026-01-05

## Story

As a **cluster operator**,
I want **to configure Synology snapshots for the k8s-data volume**,
so that **I can recover from accidental data deletion or corruption**.

## Acceptance Criteria

1. **AC1: Snapshot Configuration**
   - **Given** Synology DS920+ is accessible via web UI
   - **When** I configure Snapshot Replication for /volume1/k8s-data
   - **Then** hourly snapshots are scheduled
   - **And** retention policy keeps 24 hourly + 7 daily snapshots

2. **AC2: Snapshot Execution**
   - **Given** snapshots are configured
   - **When** an hourly snapshot runs
   - **Then** the snapshot completes successfully
   - **And** snapshot is visible in Synology Snapshot Replication

3. **AC3: Data Recovery**
   - **Given** data exists in a PVC
   - **When** I accidentally delete files from the NFS mount
   - **Then** I can restore from a Synology snapshot via the web UI
   - **And** the data is recovered without affecting running pods

4. **AC4: Runbook Documentation**
   - **Given** backup strategy is validated
   - **When** I document the procedure in `docs/runbooks/nfs-restore.md`
   - **Then** the runbook includes snapshot location, restore steps, and verification
   - **And** recovery time objective is documented

## Tasks / Subtasks

- [x] Task 1: Configure Synology Snapshot Replication (AC: #1)
  - [x] 1.1: Access Synology DSM web UI at 192.168.2.2
  - [x] 1.2: Open Snapshot Replication package (install if not present)
  - [x] 1.3: Create snapshot schedule for /volume1/k8s-data shared folder
  - [x] 1.4: Configure hourly snapshot schedule
  - [x] 1.5: Set retention policy: 24 hourly + 7 daily snapshots
  - [x] 1.6: Enable snapshot schedule

- [x] Task 2: Verify Snapshot Execution (AC: #2)
  - [x] 2.1: Wait for first scheduled snapshot OR trigger manual snapshot
  - [x] 2.2: Verify snapshot appears in Snapshot Replication list
  - [x] 2.3: Check snapshot size and timestamp
  - [x] 2.4: Document snapshot naming convention

- [x] Task 3: Test Data Recovery (AC: #3)
  - [x] 3.1: Create test data in a PVC (write test file via kubectl exec)
  - [x] 3.2: Wait for snapshot to capture the test data
  - [x] 3.3: Delete the test file from the PVC
  - [x] 3.4: Restore from snapshot via Synology web UI
  - [x] 3.5: Verify test file is recovered
  - [x] 3.6: Verify running pods are not affected during restore

- [x] Task 4: Create Runbook Documentation (AC: #4)
  - [x] 4.1: Create `docs/runbooks/nfs-restore.md`
  - [x] 4.2: Document snapshot location and access method
  - [x] 4.3: Document step-by-step restore procedure
  - [x] 4.4: Document verification steps after restore
  - [x] 4.5: Document recovery time objective (RTO) based on testing
  - [x] 4.6: Add troubleshooting section

## Gap Analysis

**Scan Date:** 2026-01-05
**Scan Result:** ✅ Draft tasks validated - no changes needed

**What Exists:**
- `docs/runbooks/` directory exists (contains `node-removal.md` as template)
- `scripts/health-check.sh` exists (Story 2.3, verifies NFS connectivity)
- NFS provisioner running in `infra` namespace
- 3 nodes Ready (k3s-master, k3s-worker-01, k3s-worker-02)

**What's Missing:**
- `docs/runbooks/nfs-restore.md` (will create in Task 4)
- Synology snapshot configuration (external to cluster - Tasks 1-3)

**Task Changes:** None - draft tasks accurate for this external configuration story

---

## Dev Notes

### Technical Specifications

**Synology NAS Details:**
- Model: DS920+
- IP Address: 192.168.2.2
- DSM Version: (to be verified)
- Shared Folder: `/volume1/k8s-data`
- Capacity: 8.8TB RAID1

**NFS Configuration (from Story 2.1):**
- Export: `/volume1/k8s-data`
- Protocol: NFSv4.1
- Mount Options: `nfsvers=4.1,hard,timeo=600,retrans=3`

**Snapshot Retention Strategy:**
| Type | Count | Purpose |
|------|-------|---------|
| Hourly | 24 | Recover from recent mistakes |
| Daily | 7 | Weekly recovery window |
| Total | 31 | ~1 week of snapshots |

### Architecture Requirements

**From [Source: architecture.md#Backup & Recovery Architecture]:**
| Decision | Choice | Rationale |
|----------|--------|-----------|
| PVC Data | Synology snapshots | Hourly, handled by NAS |

**From [Source: epics.md#Epic 2]:**
- FR18: Operator can backup persistent data to Synology snapshots

**From [Source: architecture.md#Storage Boundaries]:**
```
Synology: /volume1/k8s-data/
├── {namespace}-{pvc-name}-{pv-id}/    # Auto-created by provisioner
```

### Previous Story Intelligence (Story 2.3)

**Learnings to Apply:**
1. **NFS server accessible at 192.168.2.2** - Confirmed via health check
2. **Storage capacity:** 5.2T total, 3.9T used, 1.4T available
3. **PVC path pattern:** `{namespace}-{pvc-name}-{pv-id}/`
4. **Health check script:** `scripts/health-check.sh` can verify NFS connectivity

**Current Cluster State:**
| Node | IP | Status |
|------|-----|--------|
| k3s-master | 192.168.2.20 | Ready |
| k3s-worker-01 | 192.168.2.21 | Ready |
| k3s-worker-02 | 192.168.2.22 | Ready |

### Project Structure Notes

**Files to Create:**
```
docs/
└── runbooks/
    └── nfs-restore.md     # NEW - NFS snapshot restore runbook
```

**Alignment with Architecture:**
- Runbook location follows `docs/runbooks/` convention from architecture.md
- Synology configuration is external to cluster (NAS-side)
- No Kubernetes manifests needed for this story

### Testing Approach

**Snapshot Configuration Verification:**
```
1. Access Synology DSM: https://192.168.2.2:5001
2. Navigate: Main Menu → Snapshot Replication
3. Verify k8s-data folder has active schedule
4. Check retention settings match 24h + 7d
```

**Data Recovery Test:**
```bash
# 1. Create test namespace and PVC
kubectl create namespace backup-test
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: backup-test-pvc
  namespace: backup-test
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 100Mi
EOF

# 2. Create test pod and write data
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: backup-test-pod
  namespace: backup-test
spec:
  containers:
    - name: test
      image: busybox
      command: ["sleep", "3600"]
      volumeMounts:
        - name: data
          mountPath: /data
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: backup-test-pvc
EOF

# 3. Write test file
kubectl exec -n backup-test backup-test-pod -- sh -c 'echo "BACKUP_TEST_$(date +%s)" > /data/backup-test.txt'
kubectl exec -n backup-test backup-test-pod -- cat /data/backup-test.txt

# 4. Wait for snapshot, then delete file
kubectl exec -n backup-test backup-test-pod -- rm /data/backup-test.txt

# 5. Restore via Synology UI, then verify
kubectl exec -n backup-test backup-test-pod -- cat /data/backup-test.txt
```

### Security Considerations

- Synology DSM access requires admin credentials (not stored in cluster)
- Snapshot restore is a privileged operation on the NAS
- No Kubernetes credentials needed for NAS snapshot management

### Dependencies

- **Upstream:** Story 2.1 (NFS provisioner), Story 2.2 (PVC testing), Story 2.3 (health verification) - COMPLETED
- **Downstream:** None (final story in Epic 2)
- **External:** Synology DSM web UI access

### References

- [Source: epics.md#Story 2.4]
- [Source: epics.md#FR18]
- [Source: architecture.md#Backup & Recovery Architecture]
- [Source: architecture.md#Storage Boundaries]
- [Source: 2-3-verify-storage-mount-health.md#Completion Notes]
- [Synology Snapshot Replication](https://kb.synology.com/en-global/DSM/help/SnapshotReplication/snapshots)

## Dev Agent Record

### Agent Model Used

Claude Opus 4.5 (claude-opus-4-5-20251101)

### Debug Log References

N/A - External configuration story

### Completion Notes List

1. **AC1 - Snapshot Configuration:** Configured Synology Snapshot Replication for `/volume1/k8s-data` with hourly schedule and Advanced Retention policy (24 hourly + 7 daily snapshots). Btrfs file system enables space-efficient copy-on-write snapshots.

2. **AC2 - Snapshot Execution:** Verified snapshots appear in Snapshot Replication with timestamp format `GMT+00-YYYY.MM.DD-HH.MM.SS`. Manual snapshot triggered successfully for testing.

3. **AC3 - Data Recovery:** Full end-to-end test completed:
   - Created test namespace `backup-test` with PVC and pod
   - Wrote test file: `BACKUP_TEST_DATA_2026-01-05`
   - Snapshot captured the test data
   - Deleted test file from PVC
   - Restored from Synology snapshot via File Station browse/copy
   - File recovered successfully, pod had 0 restarts (not affected)

4. **AC4 - Runbook Documentation:** Created comprehensive `docs/runbooks/nfs-restore.md` with:
   - 3 recovery procedures (file-level, full restore, single PVC)
   - RTO documented: 5-15 min (file), 15-30 min (full)
   - Troubleshooting section and validation checklist
   - Recovery scenarios for common issues

5. **Cleanup:** Test namespace `backup-test` deleted, PV reclaimed.

### File List

_Files created/modified during implementation:_
- `docs/runbooks/nfs-restore.md` - NEW - Comprehensive NFS snapshot restore runbook
- `docs/implementation-artifacts/2-4-configure-synology-snapshots-for-backup.md` - MODIFIED - Story completed
