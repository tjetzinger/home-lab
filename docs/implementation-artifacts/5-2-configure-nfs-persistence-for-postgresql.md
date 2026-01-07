# Story 5.2: Configure NFS Persistence for PostgreSQL

Status: done

## Story

As a **cluster operator**,
I want **PostgreSQL data to persist on NFS storage**,
So that **data survives pod restarts and node failures**.

## Acceptance Criteria

1. **Given** PostgreSQL Helm chart is configured
   **When** I set `primary.persistence.storageClass: nfs-client` in values-homelab.yaml
   **Then** the chart requests storage from the NFS provisioner

2. **Given** PostgreSQL is deployed with NFS persistence
   **When** I check PVCs with `kubectl get pvc -n data`
   **Then** a PVC for PostgreSQL data exists and shows Bound status
   **And** the PVC uses the nfs-client StorageClass

3. **Given** PVC is bound
   **When** I check the Synology NFS share
   **Then** a directory exists for the PostgreSQL PVC
   **And** PostgreSQL data files are visible
   **And** this validates FR32 (PostgreSQL persists data to NFS)

4. **Given** data is on NFS
   **When** I delete the PostgreSQL pod with `kubectl delete pod postgres-postgresql-0 -n data`
   **Then** the StatefulSet recreates the pod
   **And** the new pod mounts the same PVC
   **And** all previously created databases and data are intact

5. **Given** persistence is validated
   **When** I simulate a worker node failure (drain the node running postgres)
   **Then** PostgreSQL pod reschedules to another node
   **And** data remains accessible via NFS

## Tasks / Subtasks

⚠️ **DRAFT TASKS** - Generated from requirements analysis. Will be validated and refined against actual codebase when dev-story runs.

### Task 1: Create Test Data Before Migration (AC: 4)
- [x] 1.1: Connect to PostgreSQL and create test database `test_persistence`
- [x] 1.2: Create test table with sample data in test database
- [x] 1.3: Query test data to verify it exists
- [x] 1.4: Document test data for post-migration verification

### Task 2: Update PostgreSQL Helm Values for NFS Persistence (AC: 1)
- [x] 2.1: Read current values-homelab.yaml to understand emptyDir configuration
- [x] 2.2: Update `primary.persistence.enabled: true` (currently false)
- [x] 2.3: Set `primary.persistence.storageClass: nfs-client`
- [x] 2.4: Configure `primary.persistence.size: 8Gi` (appropriate for home lab database)
- [x] 2.5: Add comments documenting persistence configuration change
- [x] 2.6: Review other persistence settings (accessModes, annotations)

### Task 3: Deploy Updated PostgreSQL Configuration (AC: 2)
- [x] 3.1: Upgrade PostgreSQL Helm release with updated values
- [x] 3.2: Wait for StatefulSet to recreate pod with PVC
- [x] 3.3: Monitor pod status during recreation
- [x] 3.4: Check for any errors in pod events or logs

### Task 4: Verify PVC Creation and Binding (AC: 2)
- [x] 4.1: List PVCs in data namespace
- [x] 4.2: Verify PVC name matches pattern (data-postgres-postgresql-0)
- [x] 4.3: Confirm PVC status is "Bound"
- [x] 4.4: Verify storageClass is "nfs-client"
- [x] 4.5: Check PV details to confirm NFS backend
- [x] 4.6: Verify capacity matches requested size (8Gi)

### Task 5: Verify NFS Share Contents (AC: 3)
- [x] 5.1: Identify PV directory path on NFS share
- [x] 5.2: Check Synology NFS share for PostgreSQL PVC directory
- [x] 5.3: Verify PostgreSQL data files exist (pg_wal, base, global directories)
- [x] 5.4: Check directory permissions and ownership
- [x] 5.5: Document NFS path for reference

### Task 6: Test Pod Deletion and Data Persistence (AC: 4)
- [x] 6.1: Verify test data exists before pod deletion
- [x] 6.2: Delete PostgreSQL pod: `kubectl delete pod postgres-postgresql-0 -n data`
- [x] 6.3: Wait for StatefulSet to recreate pod
- [x] 6.4: Verify new pod mounts same PVC (check volume mounts)
- [x] 6.5: Connect to new pod and verify test database exists
- [x] 6.6: Query test table to confirm all data is intact
- [x] 6.7: Verify PostgreSQL logs show successful data directory mount

### Task 7: Test Node Failure Scenario (AC: 5)
- [x] 7.1: Identify which node is running postgres-postgresql-0
- [x] 7.2: Drain the node: `kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data`
- [x] 7.3: Verify PostgreSQL pod reschedules to different node
- [x] 7.4: Wait for pod to become ready on new node
- [x] 7.5: Connect to PostgreSQL and verify test data still accessible
- [x] 7.6: Uncordon the drained node: `kubectl uncordon <node-name>`
- [x] 7.7: Verify cluster returns to normal state

### Task 8: Update Documentation
- [x] 8.1: Update applications/postgres/README.md with persistence details
- [x] 8.2: Update docs/runbooks/postgres-setup.md with NFS configuration
- [x] 8.3: Document PVC details (size, storageClass, retention)
- [x] 8.4: Add troubleshooting section for PVC issues
- [x] 8.5: Document test procedures for data persistence validation

## Gap Analysis

**Scan Date:** 2026-01-06

### What Exists:

**Infrastructure:**
- ✅ PostgreSQL 18.1 deployed and running (pod: postgres-postgresql-0 on k3s-worker-02)
- ✅ values-homelab.yaml exists with persistence currently disabled (line 43: `enabled: false`)
- ✅ NFS storage class `nfs-client` exists and is set as default
- ✅ NFS provisioner: nfs-subdir-external-provisioner (deployed in Epic 2)
- ✅ Current PostgreSQL using emptyDir (ephemeral storage) as expected from Story 5.1
- ✅ No existing PVCs in data namespace (clean migration path)
- ✅ README.md and postgres-setup.md runbook exist in applications/postgres/ and docs/runbooks/

### What's Missing:

- ❌ Test data in PostgreSQL (needs creation for persistence validation)
- ❌ NFS persistence configuration in values-homelab.yaml (lines 43-45 commented/disabled)
- ❌ PVC bound to PostgreSQL pod
- ❌ Documentation updates for NFS persistence in README.md and runbook

### Task Changes Applied:

**NO CHANGES NEEDED** - Draft tasks accurately reflect current codebase state. All tasks address missing infrastructure components and the migration path from emptyDir to NFS PVC is valid.

---

## Dev Notes

### Technical Requirements

**Source:** [docs/planning-artifacts/epics.md#Story 5.2]

**Persistence Configuration:**
- Enable persistence in PostgreSQL Helm values
- Use NFS storage class: `nfs-client` (from Story 2.1)
- Request 8Gi storage (appropriate for home lab database)
- Access mode: ReadWriteOnce (RWO) for StatefulSet

**NFS Integration:**
- NFS provisioner: nfs-subdir-external-provisioner (deployed in Epic 2)
- StorageClass: nfs-client
- NFS server: Synology DS920+ (configured in Story 2.1)
- Dynamic provisioning: Automatic PV creation

**Data Migration:**
- Current state: PostgreSQL using emptyDir (ephemeral storage)
- Target state: PostgreSQL using NFS-backed PVC (persistent storage)
- Migration: Helm upgrade will recreate pod with new volume

**Testing Strategy:**
- Create test data before migration
- Verify data survives pod deletion
- Verify data survives node failure (pod rescheduling)

### Architecture Compliance

**Source:** [docs/planning-artifacts/architecture.md]

**Storage Decision:**
- NFS-backed PVC chosen for PostgreSQL persistence
- Aligns with NFR: Data must survive pod/node failures
- Synology snapshots provide additional backup layer (Story 2.4)

**Directory Structure on NFS:**
```
/mnt/k3s-nfs/  # Synology NFS share
└── data-postgres-postgresql-0-pvc-<uid>/  # Auto-created by provisioner
    ├── pg_wal/         # Write-ahead logs
    ├── base/           # Database files
    ├── global/         # Cluster-wide tables
    ├── pg_tblspc/      # Tablespaces
    └── postgresql.conf # Configuration (if customized)
```

**PersistentVolumeClaim Pattern:**
- Naming: `data-<statefulset-name>-<ordinal>` (e.g., data-postgres-postgresql-0)
- Labels: Match StatefulSet selector
- Reclaim policy: Retain (data preserved after PVC deletion)

**StatefulSet Volume Behavior:**
- VolumeClaimTemplate creates PVC for each pod
- PVC binds to same pod across restarts
- Pod ordinal determines PVC name (stable identity)

### Library/Framework Requirements

**Helm Chart:**
- Chart: bitnami/postgresql (version 18.2.0 from Story 5.1)
- Persistence configuration via values-homelab.yaml
- No code changes required - configuration only

**Dependencies:**
- NFS provisioner: nfs-subdir-external-provisioner (deployed in Story 2.1)
- StorageClass: nfs-client (configured in Story 2.1)
- Synology NFS share: mounted and accessible

### File Structure Requirements

**Source:** [docs/planning-artifacts/architecture.md#Directory Structure]

**Files to Modify:**
```
applications/postgres/
├── values-homelab.yaml      # Update persistence configuration
└── README.md                # Document persistence details

docs/runbooks/
└── postgres-setup.md        # Add NFS configuration section
```

**Files to Create:**
- None (configuration change only)

### Testing Requirements

**Pre-Migration Validation:**
1. NFS provisioner running and healthy
2. StorageClass nfs-client exists
3. Test data created in PostgreSQL

**Post-Migration Validation:**
1. PVC created and bound
2. PVC uses nfs-client StorageClass
3. PostgreSQL data files visible on NFS share
4. Test data intact after pod deletion
5. Test data intact after node failure simulation

**Data Persistence Tests:**
1. **Pod Deletion Test**: Verify data survives pod recreation
2. **Node Failure Test**: Verify data accessible when pod moves to different node
3. **Storage Capacity Test**: Verify PVC size matches requested (8Gi)

**NFR Validation:**
- FR32: PostgreSQL persists data to NFS ✅
- Data survives pod restarts ✅
- Data survives node failures ✅

### Previous Story Intelligence

**Source:** [docs/implementation-artifacts/5-1-deploy-postgresql-via-bitnami-helm-chart.md]

**Key Learnings from Story 5.1:**

**Current PostgreSQL Deployment:**
- PostgreSQL 18.1 running with emptyDir storage (ephemeral)
- Bitnami Helm chart 18.2.0
- StatefulSet: postgres-postgresql
- Pod: postgres-postgresql-0
- Namespace: data
- Service: postgres-postgresql.data.svc.cluster.local:5432
- Password: ${POSTGRES_PASSWORD} (stored in Secret)

**Helm Upgrade Pattern:**
- Use `helm upgrade` (not `helm install`) for configuration changes
- Helm will detect StatefulSet changes and recreate pod
- StatefulSet ensures ordered pod recreation
- Pod name remains stable (postgres-postgresql-0)

**Volume Configuration Location:**
- File: applications/postgres/values-homelab.yaml
- Current setting: `primary.persistence.enabled: false`
- Target setting: `primary.persistence.enabled: true` + storageClass configuration

**Data Migration Strategy:**
- ⚠️ **WARNING**: emptyDir data will be lost when pod is recreated
- Current deployment has no critical data (fresh install from Story 5.1)
- Test data creation allows validation of persistence after migration
- Production migration would require pg_dump/restore process

**Monitoring Integration:**
- ServiceMonitor already configured
- Metrics will continue working after persistence change
- No changes needed to monitoring configuration

**Resource Limits:**
- CPU: 100m request, 500m limit
- Memory: 256Mi request, 1Gi limit
- No changes needed for persistence migration

### Project Context Reference

**Source:** [CLAUDE.md, docs/FOLDER_DOCUMENTATION.md]

**Storage Pattern (from Epic 2):**
- NFS provisioner: nfs-subdir-external-provisioner
- StorageClass: nfs-client
- Dynamic provisioning enabled
- Synology NFS server: 192.168.2.10 (from Story 2.1)
- Mount path: /mnt/k3s-nfs

**StatefulSet Volume Pattern:**
```yaml
volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: nfs-client
      resources:
        requests:
          storage: 8Gi
```

**Helm Upgrade Command:**
```bash
helm upgrade postgres bitnami/postgresql \
  -f /home/tt/Workspace/home-lab/applications/postgres/values-homelab.yaml \
  -n data
```

**Testing Commands:**
```bash
# Create test data
kubectl exec -it postgres-postgresql-0 -n data -- env PGPASSWORD=${POSTGRES_PASSWORD} psql -U postgres

# Verify PVC
kubectl get pvc -n data
kubectl describe pvc data-postgres-postgresql-0 -n data

# Check PV
kubectl get pv
kubectl describe pv <pv-name>

# Node operations
kubectl get pods -n data -o wide  # See which node
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data
kubectl uncordon <node-name>
```

---

## Dev Agent Record

### Agent Model Used

_Will be recorded during implementation_

### Debug Log References

_Will be recorded during implementation_

### Completion Notes List

1. **NFS Persistence Enabled**: PostgreSQL migrated from emptyDir to NFS-backed PVC (8Gi, nfs-client StorageClass)
2. **PVC Created**: data-postgres-postgresql-0 bound to PV pvc-523fdf5f-e4ad-4a40-bfcf-5479b4bf6ff0
3. **NFS Backend**: Synology DS920+ (192.168.2.2) at path /volume1/k8s-data/data-data-postgres-postgresql-0-pvc-<uid>
4. **StatefulSet Migration**: Deleted and recreated StatefulSet to enable volumeClaimTemplates (Kubernetes limitation)
5. **Pod Deletion Test**: ✅ Passed - Data survived pod deletion, 3 test records intact with unchanged timestamps
6. **Node Failure Test**: ✅ Passed - Pod moved from k3s-worker-02 to k3s-worker-01, all data accessible via NFS
7. **PostgreSQL Data Files**: Verified on NFS (pg_wal, base, global directories, 39MB total)
8. **Documentation Updated**: README.md and postgres-setup.md updated with PVC details, NFS configuration, troubleshooting procedures
9. **FR32 Validated**: PostgreSQL persists data to NFS storage (AC3)
10. **Data Durability Validated**: Data survives both pod restarts (AC4) and node failures (AC5)

### File List

**Modified:**
- `/home/tt/Workspace/home-lab/applications/postgres/values-homelab.yaml` - Enabled NFS persistence (lines 40-48)
- `/home/tt/Workspace/home-lab/applications/postgres/README.md` - Added persistence details, PVC troubleshooting, change log
- `/home/tt/Workspace/home-lab/docs/runbooks/postgres-setup.md` - Added NFS persistence configuration, verification commands, test procedures
- `/home/tt/Workspace/home-lab/docs/implementation-artifacts/sprint-status.yaml` - Updated story status (line 80)
- `/home/tt/Workspace/home-lab/docs/implementation-artifacts/5-2-configure-nfs-persistence-for-postgresql.md` - Gap analysis, task completion, dev notes

**Created:**
- None (configuration changes only, PVC created dynamically by Kubernetes)

---

### Change Log

- 2026-01-06: Story created with requirements analysis and draft implementation tasks
- 2026-01-06: Gap analysis completed - verified current emptyDir state, tasks validated
- 2026-01-06: Story implementation completed - PostgreSQL migrated to NFS persistence, all acceptance criteria validated, marked for review
- 2026-01-06: Story marked as done - NFS-backed persistent storage operational, data durability validated
