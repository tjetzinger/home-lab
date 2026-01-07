# K3s Cluster State Restore Runbook

**Last Updated:** 2026-01-07
**Story:** 8.3 - Validate Cluster Restore Procedure
**Maintainer:** Home Lab Operations

## Overview

This runbook describes the procedure for restoring K3s cluster state from an etcd snapshot. The restore process replaces the current control plane state with a previous snapshot, enabling recovery from control plane failures, data corruption, or the need to rollback to a known-good state.

**Restore Method:** K3s cluster-reset with snapshot restore
**Recovery Time Objective:** 30 minutes (NFR6)
**Data Source:** etcd snapshots on NFS (`/mnt/k3s-snapshots`)
**Impact:** Control plane downtime during restore, workers may need rejoin

⚠️ **WARNING:** Restoring from snapshot replaces ALL cluster state. Application data on NFS PVCs is preserved, but cluster resources (pods, services, etc.) return to the snapshot point in time.

## Prerequisites

- SSH access to k3s-master node (192.168.2.20)
- Root/sudo privileges on master node
- Valid etcd snapshot file on `/mnt/k3s-snapshots`
- NFS mount `/mnt/k3s-snapshots` must be accessible
- Backup of current cluster state (if not completely lost)

## When to Use Restore vs Rebuild

### Use Restore When:
- ✅ Control plane corruption or etcd database issues
- ✅ Accidental deletion of critical cluster resources
- ✅ Need to rollback to known-good state after failed upgrade
- ✅ Certificate authority issues requiring rollback
- ✅ Testing disaster recovery procedures (this story)

### Use Rebuild Instead When:
- ⛔ Hardware failure of master node (requires new node)
- ⛔ Complete cluster loss with no accessible snapshots
- ⛔ Intentional fresh start for cluster
- ⛔ Major K3s version migration requiring clean install

## Snapshot Selection Criteria

### List Available Snapshots

```bash
# List snapshots via K3s
ssh k3s-master "k3s etcd-snapshot ls"

# List snapshot files on NFS
ssh k3s-master "ls -lh /mnt/k3s-snapshots/"
```

### Choosing the Right Snapshot

**Naming Convention:** `etcd-snapshot-k3s-master-<timestamp>`
**Manual Snapshots:** `manual-<description>-<date>-k3s-master-<timestamp>`

**Selection Guidelines:**
1. **For routine recovery:** Use most recent automatic snapshot
2. **For rollback after change:** Use snapshot created immediately before the change
3. **For testing:** Use older snapshot to verify process without losing recent work
4. **Snapshot age:** Snapshots older than 7 days are automatically pruned (14 retention limit)

**Verify Snapshot Integrity:**
```bash
# Check snapshot file size (should be ~15-20MB for typical cluster)
ssh k3s-master "ls -lh /mnt/k3s-snapshots/<snapshot-file>"

# Verify file is not corrupted (file command should show data)
ssh k3s-master "file /mnt/k3s-snapshots/<snapshot-file>"
```

## Pre-Restore Preparation

### 1. Document Current State

```bash
# Document current cluster state (if accessible)
kubectl get nodes -o wide > pre-restore-nodes.txt
kubectl get pods --all-namespaces -o wide > pre-restore-pods.txt
kubectl get pvc --all-namespaces > pre-restore-pvcs.txt
```

### 2. Create Safety Snapshot

**If cluster is still operational:**
```bash
# Create pre-restore snapshot for safety
ssh k3s-master "k3s etcd-snapshot save --name pre-restore-$(date +%Y%m%d-%H%M%S)"

# Verify snapshot created
ssh k3s-master "k3s etcd-snapshot ls | tail -1"
```

### 3. Notify Stakeholders

- Document planned downtime window
- Notify users that cluster will be unavailable
- Estimate recovery time: 10-30 minutes (NFR6 target)

### 4. Verify NFS Accessibility

```bash
# Verify NFS mount is healthy
ssh k3s-master "df -h | grep k3s-snapshots"

# Verify snapshot file exists
ssh k3s-master "ls -lh /mnt/k3s-snapshots/<snapshot-file>"
```

## Step-by-Step Restore Procedure

### Step 1: Stop K3s Service

```bash
# Stop K3s on master node
ssh k3s-master "sudo systemctl stop k3s"

# Verify service stopped
ssh k3s-master "sudo systemctl status k3s"
# Expected: "Active: inactive (dead)"
```

### Step 2: Execute Cluster Reset and Restore

⚠️ **CRITICAL:** This command will delete current etcd data and restore from snapshot.

```bash
# Execute restore (run on master node)
ssh k3s-master "sudo k3s server \
  --cluster-reset \
  --cluster-reset-restore-path=/mnt/k3s-snapshots/<snapshot-file>"
```

**Expected Output:**
```
time="..." level=info msg="Managed etcd cluster membership has been reset, restart without --cluster-reset flag now."
time="..." level=info msg="Cluster reset complete"
```

**Important Notes:**
- Replace `<snapshot-file>` with actual snapshot filename
- Command runs once and exits - this is normal behavior
- Etcd data is replaced with snapshot contents
- Do NOT include `--cluster-reset` flag on subsequent starts

### Step 3: Start K3s Service

```bash
# Start K3s service (cluster-reset flag NOT needed now)
ssh k3s-master "sudo systemctl start k3s"

# Monitor K3s startup
ssh k3s-master "sudo journalctl -u k3s -f"
# Look for: "Wrote kubeconfig" and "Node registered successfully"
```

**Expected Startup Time:** 1-3 minutes for control plane to become ready

### Step 4: Verify Control Plane Recovery

```bash
# Check K3s service status
ssh k3s-master "sudo systemctl status k3s"
# Expected: "Active: active (running)"

# Verify kubectl connectivity
kubectl version

# Check API server health
kubectl get --raw='/healthz'
# Expected: "ok"
```

## Post-Restore Verification

### Verify Master Node

```bash
# Check master node status
kubectl get nodes
# Expected: k3s-master should show "Ready"

# Verify etcd is running
ssh k3s-master "sudo ls -lh /var/lib/rancher/k3s/server/db/etcd/"
# Expected: member directory with recent timestamp
```

### Verify Core System Pods

```bash
# Check core system pods
kubectl get pods -n kube-system

# Expected pods Running:
# - coredns-*
# - traefik-*
# - metrics-server-*
# - local-path-provisioner-*
```

### Verify Cluster Resources

```bash
# Check namespaces restored
kubectl get namespaces

# Check PVCs restored (data intact)
kubectl get pvc --all-namespaces
# All PVCs should show "Bound" status

# Check critical workloads
kubectl get pods --all-namespaces -o wide
```

**Important:** Pods on worker nodes will show as "Unknown" or "Terminating" until workers rejoin.

## Worker Node Rejoin Procedure

Worker nodes may lose connection to master after restore and need to rejoin.

### Check Worker Status

```bash
# Check worker node status from master
kubectl get nodes

# Expected for workers after restore:
# - May show "NotReady"
# - May show "Unknown"
# - May not appear at all
```

### Option A: Automatic Rejoin (Try First)

Workers often rejoin automatically after restart:

```bash
# Restart k3s-agent on each worker
ssh k3s-worker-01 "sudo systemctl restart k3s-agent"
ssh k3s-worker-02 "sudo systemctl restart k3s-agent"

# Monitor worker reconnection
kubectl get nodes -w
# Wait for workers to show "Ready" (timeout: 5 minutes)
```

### Option B: Manual Rejoin (If Automatic Fails)

If workers don't rejoin automatically:

```bash
# On each worker, stop agent
ssh k3s-worker-01 "sudo systemctl stop k3s-agent"

# Remove old k3s data on worker
ssh k3s-worker-01 "sudo rm -rf /var/lib/rancher/k3s/agent"

# Restart agent (will rejoin with master)
ssh k3s-worker-01 "sudo systemctl start k3s-agent"

# Monitor logs on worker
ssh k3s-worker-01 "sudo journalctl -u k3s-agent -f"
# Look for: "Successfully registered node"
```

### Verify Workers Rejoined

```bash
# Check all nodes Ready
kubectl get nodes
# Expected: All 3 nodes should show "Ready" within 5 minutes

# Verify pods reschedule to workers
kubectl get pods --all-namespaces -o wide
# Pods should be Running across all nodes
```

## Application Recovery Validation

### Verify PersistentVolumeClaims

```bash
# Check all PVCs Bound
kubectl get pvc --all-namespaces

# Expected: All PVCs show "Bound" status
# Data on NFS is preserved (not affected by etcd restore)
```

### Verify Application Pods

```bash
# Check application pods Running
kubectl get pods -n data      # PostgreSQL
kubectl get pods -n monitoring # Prometheus, Grafana, Loki
kubectl get pods -n ml         # Ollama
kubectl get pods -n apps       # n8n

# Wait for all pods to reach "Running" status
# Timeout: 10 minutes (pods restart and mount PVCs)
```

### Test Application Endpoints

```bash
# Test Grafana
curl -k https://grafana.home.jetzinger.com
# Expected: HTTP 200 or redirect

# Test Prometheus
curl -k https://prometheus.home.jetzinger.com
# Expected: HTTP 200 or redirect

# Test PostgreSQL connectivity
kubectl exec -it -n data postgres-postgresql-0 -- pg_isready
# Expected: "accepting connections"
```

## Troubleshooting

### Issue: Control Plane Won't Start After Restore

**Symptoms:** K3s service fails to start, API server not responding

**Diagnosis:**
```bash
# Check K3s logs
ssh k3s-master "sudo journalctl -u k3s -n 100"

# Check for etcd errors
ssh k3s-master "sudo journalctl -u k3s | grep -i etcd"
```

**Common Causes:**
- Snapshot file corrupted: Verify file integrity, try different snapshot
- Insufficient disk space: Check disk space on master node
- Permission issues: Verify K3s can read snapshot file

**Resolution:**
```bash
# Try restore with different snapshot
ssh k3s-master "sudo systemctl stop k3s"
ssh k3s-master "sudo k3s server --cluster-reset --cluster-reset-restore-path=/mnt/k3s-snapshots/<different-snapshot>"
ssh k3s-master "sudo systemctl start k3s"
```

### Issue: Worker Nodes Won't Rejoin

**Symptoms:** Workers show "NotReady" or don't appear in `kubectl get nodes`

**Diagnosis:**
```bash
# Check worker agent status
ssh k3s-worker-01 "sudo systemctl status k3s-agent"

# Check worker logs
ssh k3s-worker-01 "sudo journalctl -u k3s-agent -n 50"
```

**Resolution:**
```bash
# Stop agent
ssh k3s-worker-01 "sudo systemctl stop k3s-agent"

# Remove worker data
ssh k3s-worker-01 "sudo rm -rf /var/lib/rancher/k3s/agent"

# Restart agent
ssh k3s-worker-01 "sudo systemctl start k3s-agent"

# Verify node appears
kubectl get nodes
```

### Issue: Pods Stuck in Pending or Unknown

**Symptoms:** Pods show "Pending" or "Unknown" status after restore

**Diagnosis:**
```bash
# Check pod status
kubectl get pods --all-namespaces -o wide

# Describe stuck pod
kubectl describe pod <pod-name> -n <namespace>
```

**Common Causes:**
- Workers not yet rejoined: Complete worker rejoin procedure
- PVC not mounting: Verify NFS mount healthy
- Resource constraints: Check node resources

**Resolution:**
```bash
# Delete stuck pods (will be recreated)
kubectl delete pod <pod-name> -n <namespace>

# Check events
kubectl get events --all-namespaces --sort-by='.lastTimestamp' | tail -20
```

### Issue: Application Data Missing

**Symptoms:** Applications start but data is missing

**Diagnosis:**
```bash
# Verify PVCs are Bound
kubectl get pvc --all-namespaces

# Check NFS mount on nodes
kubectl exec -it <pod-name> -n <namespace> -- df -h

# Check PVC data on NFS server
ssh synology "ls -lh /volume1/k8s-data/"
```

**Resolution:**
- Verify NFS mount on master and workers
- Check Synology NFS service is running
- Verify PVC bindings are correct
- Check PV reclaim policy (should be "Retain")

### Issue: Restore Takes Longer Than 30 Minutes (NFR6 Violation)

**Symptoms:** Restore process exceeds 30-minute target

**Analysis:**
```bash
# Check snapshot size
ssh k3s-master "ls -lh /mnt/k3s-snapshots/<snapshot>"

# Check etcd data size
ssh k3s-master "du -sh /var/lib/rancher/k3s/server/db/etcd/"
```

**Common Factors:**
- Large snapshot size: Expected for clusters with many resources
- Slow NFS mount: Check network connectivity to Synology
- Worker rejoin delays: Workers taking too long to reconnect
- Application startup time: Many pods restarting simultaneously

**Mitigation:**
- Pre-prepare workers for rejoin
- Stagger pod restarts if possible
- Optimize NFS network path
- Consider reducing retention if snapshots too large

## Recovery Time Metrics

**NFR6 Target:** Restore cluster state within 30 minutes

**Typical Timeline:**
- K3s service stop: < 30 seconds
- Snapshot restore: 1-2 minutes
- Control plane startup: 1-3 minutes
- Worker rejoin: 2-5 minutes
- Pod recovery: 5-10 minutes
- **Total:** 10-20 minutes (within NFR6 target)

**Factors Affecting Recovery Time:**
- Snapshot size: Larger snapshots take longer to restore
- Cluster size: More nodes = more rejoin time
- Application count: More pods = longer startup time
- Network speed: NFS speed affects snapshot access

## Best Practices

### Regular Restore Testing

**Recommendation:** Test restore procedure quarterly

**Safe Testing Approach:**
1. Create pre-test snapshot
2. Choose test snapshot that's 12-24 hours old
3. Execute restore following this runbook
4. Verify complete recovery
5. Restore back to pre-test snapshot
6. Update runbook with any learnings

### Pre-Change Snapshots

**Always create manual snapshot before:**
- K3s version upgrades
- Major configuration changes
- Certificate authority updates
- Critical application deployments

**Command:**
```bash
k3s etcd-snapshot save --name pre-<change-description>-$(date +%Y%m%d)
```

### Snapshot Validation

**Monthly verification:**
```bash
# List recent snapshots
k3s etcd-snapshot ls

# Verify NFS accessibility
ls -lh /mnt/k3s-snapshots/

# Check Synology backup snapshots
# (Via Synology DSM: Snapshot Replication > Snapshots)
```

## Related Runbooks

- **cluster-backup.md** (Story 8.2) - Snapshot creation and management
- **k3s-upgrade.md** (Story 8.1) - K3s upgrade procedure (uses snapshots for safety)
- **node-removal.md** (Story 1.5) - Node removal and rejoin procedures

## Compliance & Requirements

**Satisfies:**
- **FR46:** Operator can restore cluster from backup
- **NFR6:** Cluster state can be restored within 30 minutes
- **NFR20:** K3s upgrades complete with zero data loss (restore enables rollback)
- **NFR22:** Runbooks exist for all P1 alert scenarios

**Architecture Alignment:**
- Backup & Recovery Architecture: etcd snapshots with NFS storage
- Single control plane with worker rejoin capability
- Application data preserved independently on NFS PVCs

## Additional Resources

### K3s Documentation
- [K3s Backup and Restore](https://docs.k3s.io/datastore/backup-restore)
- [K3s Cluster Reset](https://docs.k3s.io/cli/server#cluster-reset-options)
- [K3s HA Embedded etcd](https://docs.k3s.io/datastore/ha-embedded)

### Architecture Decisions
- **ADR-010:** K3s Datastore Migration (sqlite → etcd)
- **Architecture.md:** Backup & Recovery Architecture

### Validation
- **Story 8.3:** Validates restore procedure and measures actual recovery time

## Validation Results

**Test Date:** 2026-01-07
**Story:** 8.3 - Validate Cluster Restore Procedure
**Test Outcome:** ✅ **SUCCESS** - All validation criteria met

### Test Execution Summary

**Scenario:** Simulated control plane failure with etcd data loss
**Snapshot Used:** `production-test-20260107-130346` (17MB, created 12:03:47 UTC)
**Cluster State:** 3 nodes, 37 pods, 8 PVCs (Postgres, Prometheus, Grafana, n8n, Ollama, Loki)

### Recovery Time Metrics (NFR6 Validation)

| Metric | Target | Actual | Status |
|--------|--------|--------|--------|
| **Total Recovery Time** | 30 minutes | **74 seconds (1m 14s)** | ✅ **EXCEEDED** |
| Control Plane Recovery | 5 minutes | < 1 minute | ✅ Exceeded |
| Worker Rejoin | 5 minutes | < 1 minute (automatic) | ✅ Exceeded |
| Application Recovery | - | < 2 minutes | ✅ All operational |

**Performance:** Achieved 4.1% of allowed recovery time (24.3x faster than NFR6 requirement)

### Recovery Timeline Breakdown

1. **Snapshot Restore** (~4 seconds): K3s cluster-reset executed, etcd database replaced
2. **Control Plane Startup** (~30 seconds): K3s service started, API server became responsive
3. **Worker Reconnection** (< 60 seconds): Both workers automatically reconnected without manual intervention
4. **Application Recovery** (< 74 seconds): All 37 pods Running, all 8 PVCs Bound, all services operational

### Validation Checks Performed

✅ **Cluster State Restoration:**
- All 3 nodes showing Ready status
- All pods returned to Running or Completed state
- All PersistentVolumeClaims remained Bound
- Point-in-time restore validated (test marker created AFTER snapshot was correctly absent)

✅ **Application Data Integrity:**
- PostgreSQL: Operational with data preserved on NFS
- Prometheus: Historical metrics intact on 20Gi NFS-backed storage
- Grafana: Dashboards accessible, database connection OK
- n8n: Workflows preserved on NFS storage
- Ollama: Model files intact on 50Gi NFS storage
- Loki: Log aggregation resumed, data preserved

✅ **Network and Services:**
- All Ingress routes functional
- Cert-manager certificates valid
- Traefik load balancer operational
- NFS mounts healthy across all nodes

### Key Findings

**Positive Observations:**
1. **Workers auto-reconnect**: K3s agents automatically recognized restored master without manual intervention
2. **Application data unaffected**: NFS-backed PVCs completely independent of etcd state
3. **Fast NFS restore**: Local network snapshot access provided excellent restore performance
4. **Zero data loss**: All application data intact from snapshot point in time

**Lessons Learned:**
1. Worker rejoin procedure (documented in runbook) not needed for this cluster configuration
2. Recovery time well below target allows for additional safety checks during actual DR event
3. Pre-restore snapshot provides excellent safety net for restore testing

### Compliance Validation

| Requirement | Status | Evidence |
|-------------|--------|----------|
| **NFR6:** Restore within 30 minutes | ✅ VALIDATED | 74 seconds actual (<<< 30 min target) |
| **NFR2:** Control plane recovery < 5 min | ✅ VALIDATED | < 1 minute actual |
| **FR46:** Operator can restore from backup | ✅ VALIDATED | Full cluster restored successfully |
| **NFR20:** Zero data loss capability | ✅ VALIDATED | All application data intact |

---

## Related Documentation

**Home-lab Runbooks:**
- **[Cluster Backup Runbook](cluster-backup.md)** - etcd snapshot creation and management
- **[K3s Rollback Runbook](k3s-rollback.md)** - Alternative recovery method for version-specific issues
- **[K3s Upgrade Runbook](k3s-upgrade.md)** - K3s upgrade procedures
- **[OS Security Updates Runbook](os-security-updates.md)** - OS-level updates and rollback

**Official K3s Documentation:**
- [K3s Backup & Restore](https://docs.k3s.io/backup-restore) - Official K3s documentation

**Implementation Stories:**
- [Story 8.3](../implementation-artifacts/8-3-validate-cluster-restore-procedure.md) - Cluster restore validation (this runbook)

---

**Runbook Version:** 1.1
**Last Tested:** 2026-01-07 (Story 8.3)
**Test Result:** All validation criteria passed
**Next Review:** Quarterly (2026-04-07) or after K3s major version upgrade
