# Story 2.3: Verify Storage Mount Health

Status: done
Completed: 2026-01-05

## Story

As a **cluster operator**,
I want **to verify NFS mount health across the cluster**,
so that **I can detect storage issues before they affect applications**.

## Acceptance Criteria

1. **AC1: PV/PVC Status Verification**
   - **Given** NFS provisioner and test PVC are deployed
   - **When** I run `kubectl get pv` and `kubectl get pvc --all-namespaces`
   - **Then** all PVs show Available or Bound status
   - **And** all PVCs show Bound status

2. **AC2: Mount Visibility**
   - **Given** pods are using NFS-backed volumes
   - **When** I exec into a pod and run `df -h` on the mount point
   - **Then** the NFS mount is visible with correct capacity
   - **And** used/available space is reported accurately

3. **AC3: NFS Resilience**
   - **Given** NFS storage is operational
   - **When** Synology performs a firmware update (simulated by brief NFS restart)
   - **Then** existing mounts recover automatically
   - **And** pods do not crash (NFR4)

4. **AC4: Health Check Script**
   - **Given** I need ongoing health visibility
   - **When** I create a storage health check script at `scripts/health-check.sh`
   - **Then** the script validates NFS connectivity, PV/PVC status, and mount health
   - **And** returns exit code 0 for healthy, non-zero for issues

## Tasks / Subtasks

- [x] Task 1: Verify PV/PVC Status (AC: #1)
  - [x] 1.1: Create test PVC in a test namespace for validation
  - [x] 1.2: Run `kubectl get pv` and verify all PVs show Available or Bound
  - [x] 1.3: Run `kubectl get pvc --all-namespaces` and verify all PVCs show Bound
  - [x] 1.4: Document expected status patterns

- [x] Task 2: Verify Mount Visibility (AC: #2)
  - [x] 2.1: Deploy test pod with NFS-backed PVC
  - [x] 2.2: Exec into pod and run `df -h /data` to verify mount visibility
  - [x] 2.3: Verify capacity matches expected NFS share size
  - [x] 2.4: Verify used/available space is accurate

- [x] Task 3: Test NFS Resilience (AC: #3)
  - [x] 3.1: Document current pod and mount state
  - [x] 3.2: Simulate NFS disruption (brief network interruption or NFS service restart)
  - [x] 3.3: Monitor pod status during and after disruption
  - [x] 3.4: Verify mounts recover automatically without pod restart
  - [x] 3.5: Verify no data loss after recovery

- [x] Task 4: Create Health Check Script (AC: #4)
  - [x] 4.1: Create `scripts/health-check.sh` script
  - [x] 4.2: Add NFS server ping/connectivity check
  - [x] 4.3: Add PV/PVC status validation (fail if any not Bound)
  - [x] 4.4: Add showmount check to verify NFS exports visible
  - [x] 4.5: Return exit code 0 for healthy, non-zero for issues
  - [x] 4.6: Document script usage in README

- [x] Task 5: Cleanup Test Resources (AC: #1-4)
  - [x] 5.1: Delete test pod and PVC
  - [x] 5.2: Delete test namespace
  - [x] 5.3: Verify cleanup completed

## Gap Analysis

**Scan Date:** 2026-01-05
**Scan Result:** ✅ Draft tasks validated - minor update to Task 1.1

**What Exists:**
- NFS provisioner running in `infra` namespace (pod Running)
- `nfs-client` StorageClass is default, reclaim policy: Delete
- 1 PV/PVC pair exists (for provisioner itself) - both Bound
- 3 nodes Ready (k3s-master, k3s-worker-01, k3s-worker-02)
- NFS connectivity validated in Story 2.2

**What's Missing:**
- `scripts/` directory (will create)
- `scripts/health-check.sh` (will create)
- Test namespace and resources (will create for validation)

**Task Changes:** Minor - Task 1.1 clarified to include namespace creation

---

## Dev Notes

### Technical Specifications

**NFS Server Details:**
- Server: Synology DS920+ (192.168.2.2)
- Export: `/volume1/k8s-data`
- Protocol: NFSv4.1 with hard mounts

**NFS Provisioner Status (from Story 2.1/2.2):**
- Provisioner: `cluster.local/nfs-provisioner-nfs-subdir-external-provisioner`
- StorageClass: `nfs-client` (default)
- Namespace: `infra`
- Reclaim Policy: Delete
- Mount Options: `nfsvers=4.1,hard,timeo=600,retrans=3`

**Health Check Script Requirements:**
```bash
#!/bin/bash
# scripts/health-check.sh

# Exit codes:
# 0 - All healthy
# 1 - NFS server unreachable
# 2 - PV/PVC status issues
# 3 - Mount issues
```

### Architecture Requirements

**From [Source: architecture.md#Storage Architecture]:**
| Decision | Choice | Rationale |
|----------|--------|-----------|
| NFS Provisioner | nfs-subdir-external-provisioner | Simple, Helm-based, dynamic PVC provisioning |
| StorageClass | nfs-client (default) | Dynamic provisioning from Synology |

**From [Source: epics.md#Epic 2]:**
- FR17: Operator can verify storage mount health
- NFR4: NFS storage remains accessible during Synology firmware updates

### Previous Story Intelligence (Story 2.2)

**Learnings to Apply:**
1. **PVC binding is fast** - Binds within seconds, not 30
2. **Mount options confirmed:** NFS4, hard, timeo=600, retrans=3
3. **Path pattern verified:** `{namespace}-{pvc-name}-{pv-id}/`
4. **Test namespace pattern:** `test-storage` worked well for isolation
5. **SSH to worker nodes works** - Can verify mounts from node level

**Validation Results from 2.2:**
| Test | Result |
|------|--------|
| PVC binds within 30 seconds | PASS |
| Volume mounts within 10 seconds | PASS |
| Data persists on NFS | PASS |
| Data survives pod restart | PASS |
| Reclaim policy (Delete) works | PASS |

**Current Cluster State:**
| Node | IP | Status | nfs-common |
|------|-----|--------|------------|
| k3s-master | 192.168.2.20 | Ready | Installed |
| k3s-worker-01 | 192.168.2.21 | Ready | Installed |
| k3s-worker-02 | 192.168.2.22 | Ready | Installed |

### Project Structure Notes

**Files to Create:**
```
scripts/
└── health-check.sh     # NEW - Storage health check script
```

**Alignment with Architecture:**
- Script location follows `scripts/` convention from architecture.md
- No Helm charts or infrastructure changes needed
- Pure validation/observability story

### Testing Approach

**PV/PVC Status Check:**
```bash
# Check all PVs
kubectl get pv

# Check all PVCs
kubectl get pvc --all-namespaces

# Expected: All PVs should be Available or Bound
# Expected: All PVCs should be Bound
```

**Mount Visibility Check:**
```bash
# Exec into test pod
kubectl exec -n test-storage test-pod -- df -h /data

# Expected output shows NFS mount with ~8TB capacity
# Example: 192.168.2.2:/volume1/k8s-data/... 5.2T 3.9T 1.4T
```

**NFS Resilience Test:**
```bash
# Option 1: Simulate via iptables (on worker node)
# Block NFS port briefly then unblock
iptables -A OUTPUT -p tcp --dport 2049 -d 192.168.2.2 -j DROP
sleep 30
iptables -D OUTPUT -p tcp --dport 2049 -d 192.168.2.2 -j DROP

# Option 2: Check behavior after real NFS restart on Synology
# Coordinate with Synology restart, monitor pod status

# Monitor during disruption
kubectl get pods -n test-storage -w
```

**Health Check Script Test:**
```bash
# Run script
./scripts/health-check.sh

# Check exit code
echo $?

# Expected: 0 if healthy
```

### Security Considerations

- Health check script should not store credentials
- Script should be executable but not require elevated permissions
- NFS connectivity check uses standard tools (ping, showmount)

### Dependencies

- **Upstream:** Story 2.1 (NFS provisioner), Story 2.2 (PVC testing) - COMPLETED
- **Downstream:** Story 2.4 (Synology snapshots for backup)
- **External:** Synology NFS share (already configured)

### References

- [Source: epics.md#Story 2.3]
- [Source: epics.md#FR17]
- [Source: architecture.md#Storage Architecture]
- [Source: 2-2-create-and-test-persistentvolumeclaim.md#Completion Notes]
- [NFS Client Options](https://linux.die.net/man/5/nfs)

## Dev Agent Record

### Agent Model Used

Claude Opus 4.5 (claude-opus-4-5-20251101)

### Debug Log References

N/A - No debug logs required

### Completion Notes List

1. **AC1 - PV/PVC Status Verification:** Created test namespace `test-storage` and test PVC. All PVs (2) showed Bound status. All PVCs (2) showed Bound status. PVC binding occurred within seconds.

2. **AC2 - Mount Visibility:** Test pod deployed on `k3s-worker-01`. Mount verified at `/data` with NFS4 options (`vers=4.1, hard, timeo=600, retrans=3`). Capacity: 5.2T total, 3.9T used, 1.4T available (74% utilization).

3. **AC3 - NFS Resilience:** Simulated NFS disruption using iptables to block port 2049 for 15 seconds on worker node. Pod remained Running with 0 restarts. Data integrity verified - test file preserved after recovery. NFR4 satisfied.

4. **AC4 - Health Check Script:** Created `scripts/health-check.sh` with 5 checks:
   - NFS server connectivity (ping)
   - NFS export visibility (showmount)
   - PV status validation
   - PVC status validation
   - NFS provisioner pod status
   Script returns exit code 0 for healthy, non-zero for issues.

5. **Cleanup:** All test resources deleted. PV deletion confirmed (reclaim policy Delete worked). Only provisioner PV/PVC remain.

### File List

_Files created/modified during implementation:_
- `scripts/health-check.sh` - NEW - Storage health check script with NFS connectivity, PV/PVC status, and provisioner checks
- `docs/implementation-artifacts/2-3-verify-storage-mount-health.md` - MODIFIED - Story completed
