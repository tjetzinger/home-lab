# NFS Snapshot Restore Runbook

This runbook documents the procedure for restoring data from Synology snapshots, including snapshot configuration verification, file-level recovery, and full folder restoration.

## Overview

| Item | Details |
|------|---------|
| **Scope** | NFS data recovery from Synology snapshots |
| **NAS Model** | Synology DS920+ |
| **NAS IP** | 192.168.2.2 |
| **Shared Folder** | /volume1/k8s-data |
| **Snapshot Package** | Snapshot Replication |
| **RTO (Recovery Time Objective)** | 5-15 minutes (file-level), 15-30 minutes (full restore) |

## Prerequisites

Before starting recovery:

1. **Synology DSM Access**: Verify you can access DSM web UI
   ```
   URL: https://192.168.2.2:5001
   Credentials: Admin account with Snapshot Replication access
   ```

2. **Snapshot Availability**: Confirm snapshots exist for the target timeframe
   ```
   DSM → Snapshot Replication → Snapshots → k8s-data
   ```

3. **Identify Recovery Target**: Determine what needs to be restored
   - Specific file(s) or folder(s)
   - PVC path pattern: `{namespace}-{pvc-name}-{pv-id}/`
   - Full shared folder rollback

4. **Cluster Impact Assessment**: Check if pods are using affected PVCs
   ```bash
   kubectl get pods -A -o wide | grep -i <pvc-related-term>
   kubectl get pvc -A
   ```

## Snapshot Configuration Reference

### Current Configuration

| Setting | Value |
|---------|-------|
| Shared Folder | k8s-data |
| Schedule | Hourly |
| Retention Policy | Advanced (24 hourly + 7 daily) |
| Max Snapshots | 1,024 per folder |
| File System | Btrfs (required) |

### Snapshot Naming Convention

Snapshots are named with timestamp format:
```
GMT+00-YYYY.MM.DD-HH.MM.SS
```

Example: `GMT+00-2026.01.05-20.00.00`

### PVC Directory Structure on NFS

```
/volume1/k8s-data/
├── infra-pvc-nfs-provisioner-nfs-subdir-external-provisioner-pv-xxx/
├── {namespace}-{pvc-name}-{pv-id}/
│   └── [application data]
└── ...
```

---

## Procedure 1: File-Level Recovery (Recommended)

Use this procedure to recover specific files or folders without affecting other data.

### Step 1: Access Snapshot Replication

```
DSM → Main Menu → Snapshot Replication
```

### Step 2: Navigate to Recovery

```
Left sidebar → Recovery
Select: k8s-data shared folder
```

### Step 3: Browse Snapshots

1. Click **Action** → **Browse**
2. Select the snapshot timestamp to recover from
3. Navigate to the file/folder you need to restore
4. File Station will open showing the snapshot contents

### Step 4: Copy Files from Snapshot

**Option A - Via File Station:**
1. Navigate to the file/folder in the snapshot browser
2. Right-click → **Copy**
3. Navigate to the live folder location
4. Right-click → **Paste**

**Option B - Via Download:**
1. Right-click the file/folder → **Download**
2. Upload to the correct location manually

### Step 5: Verify Recovery

```bash
# From kubectl - verify file exists in pod
kubectl exec -n <namespace> <pod-name> -- ls -la /data/
kubectl exec -n <namespace> <pod-name> -- cat /data/<restored-file>
```

**Expected Result:** File restored without pod restart required.

---

## Procedure 2: Full Snapshot Restore

Use this procedure for catastrophic data loss requiring full folder rollback.

### Step 1: Assess Impact

```bash
# List all pods using NFS storage
kubectl get pods -A -o json | jq -r '.items[] | select(.spec.volumes[]?.persistentVolumeClaim != null) | "\(.metadata.namespace)/\(.metadata.name)"'

# Check PVC status
kubectl get pvc -A
```

### Step 2: Create Pre-Restore Snapshot (Safety)

Before restoring, take a snapshot of current state:

```
DSM → Snapshot Replication → Snapshots → k8s-data
Click: Snapshot → Take a Snapshot
Description: "Pre-restore backup - [date/reason]"
☑ Lock (prevents automatic deletion)
Click: OK
```

### Step 3: Perform Restore

```
DSM → Snapshot Replication → Recovery → k8s-data
Select the snapshot to restore to
Click: Action → Restore to this snapshot
```

**Warning Dialog:**
- DSM will warn about overwriting current data
- ☑ Take a snapshot before restoring (recommended)
- Click **OK** to proceed

### Step 4: Monitor Restoration

- Restoration progress shown in Snapshot Replication
- Duration depends on data size and changes since snapshot
- NFS clients may experience brief I/O pause

### Step 5: Verify Cluster Recovery

```bash
# Check pod status (should recover automatically)
kubectl get pods -A -w

# Verify NFS connectivity
./scripts/health-check.sh

# Verify data in affected PVCs
kubectl exec -n <namespace> <pod-name> -- ls -la /data/
```

**Expected Result:** Pods continue running, data restored to snapshot point.

---

## Procedure 3: Single PVC Directory Recovery

Restore only a specific PVC's data without affecting other PVCs.

### Step 1: Identify PVC Path

```bash
# Get PV name for the PVC
kubectl get pvc <pvc-name> -n <namespace> -o jsonpath='{.spec.volumeName}'

# PVC directory pattern on NFS:
# {namespace}-{pvc-name}-{pv-id}/
```

### Step 2: Browse Snapshot for PVC Directory

```
DSM → Snapshot Replication → Recovery → k8s-data
Action → Browse → Select snapshot
Navigate to: {namespace}-{pvc-name}-{pv-id}/
```

### Step 3: Copy Directory Contents

1. Select all files/folders in the snapshot PVC directory
2. Right-click → **Copy**
3. Navigate to live location: `/volume1/k8s-data/{namespace}-{pvc-name}-{pv-id}/`
4. Right-click → **Paste** (overwrite existing)

### Step 4: Verify in Kubernetes

```bash
# Restart pod to ensure fresh mount (optional)
kubectl delete pod <pod-name> -n <namespace>

# Wait for pod to restart
kubectl get pods -n <namespace> -w

# Verify data
kubectl exec -n <namespace> <new-pod-name> -- ls -la /data/
```

---

## Recovery Scenarios

### Scenario: Accidental File Deletion

**Symptoms:** User/application deleted important file

**Recovery:**
1. Use Procedure 1 (File-Level Recovery)
2. Browse snapshot from before deletion
3. Copy file to current location
4. No pod restart required

**RTO:** 5-10 minutes

### Scenario: Data Corruption

**Symptoms:** Application data corrupted, need clean restore

**Recovery:**
1. Identify last known good snapshot
2. Use Procedure 3 (Single PVC Recovery)
3. Restore specific PVC directory
4. Restart affected pod

**RTO:** 10-15 minutes

### Scenario: Ransomware/Mass Deletion

**Symptoms:** Multiple files encrypted or deleted

**Recovery:**
1. **Immediately** take a snapshot of current state (for forensics)
2. Use Procedure 2 (Full Snapshot Restore)
3. Restore to pre-incident snapshot
4. Verify all PVCs recovered

**RTO:** 15-30 minutes

### Scenario: NFS Share Unavailable

**Symptoms:** Synology offline, NFS not responding

**Troubleshooting:**
```bash
# Check NFS connectivity
ping 192.168.2.2
showmount -e 192.168.2.2

# Check from cluster
./scripts/health-check.sh
```

**If Synology is down:**
1. Wait for Synology to come back online
2. NFS hard mounts will auto-reconnect
3. Pods should recover automatically (no restart needed)

---

## Validation Checklist

After any restore operation:

- [ ] `./scripts/health-check.sh` returns exit code 0
- [ ] `kubectl get pvc -A` shows all PVCs as Bound
- [ ] Restored files/folders accessible from pods
- [ ] No pods stuck in CrashLoopBackOff or Error state
- [ ] Applications functioning correctly with restored data

---

## Snapshot Management

### View All Snapshots

```
DSM → Snapshot Replication → Snapshots → k8s-data
```

### Manually Take a Snapshot

```
Snapshots → k8s-data → Snapshot → Take a Snapshot
Description: "Manual - [reason]"
☑ Lock (optional - prevents auto-deletion)
```

### Delete Old Snapshots

```
Snapshots → k8s-data → Select snapshot(s) → Delete
```

**Warning:** Locked snapshots must be unlocked before deletion.

### Modify Retention Policy

```
Snapshots → k8s-data → Settings → Retention tab
```

---

## Troubleshooting

### Snapshot Browser Shows Empty Directory

**Cause:** Directory didn't exist at snapshot time

**Solution:** Check earlier snapshots or verify correct path

### Restore Taking Too Long

**Cause:** Large amount of changed data

**Solution:**
- Wait for completion (don't interrupt)
- Consider file-level recovery for faster restore

### Pods CrashLoopBackOff After Restore

**Cause:** Application state inconsistent with restored data

**Solution:**
```bash
# Delete pod to force fresh start
kubectl delete pod <pod-name> -n <namespace>

# If StatefulSet, may need to delete PVC and restore
kubectl delete pvc <pvc-name> -n <namespace>
# Then recreate and restore data
```

### "Shared Folder Not Found" in Recovery

**Cause:** Shared folder name changed or Btrfs issue

**Solution:**
1. Verify shared folder exists in File Station
2. Check Storage Manager for volume health
3. Contact Synology support if volume issues

---

## Related Documentation

- [Synology Snapshot Replication Guide](https://kb.synology.com/en-global/DSM/help/SnapshotReplication/snapshots)
- [Storage Health Check Script](../../scripts/health-check.sh)
- [NFS Provisioner README](../../infrastructure/nfs/README.md)
- [Node Removal Runbook](./node-removal.md)

---

## Revision History

| Date | Version | Changes |
|------|---------|---------|
| 2026-01-05 | 1.0 | Initial creation - Story 2.4 |
