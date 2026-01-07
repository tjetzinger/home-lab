# K3s Cluster Upgrade Procedure

**Purpose:** Safe upgrade procedure for K3s Kubernetes distribution with zero downtime

**Story:** 8.1 - Configure K3s Upgrade Procedure
**Date Created:** 2026-01-07
**Last Updated:** 2026-01-07

---

## Overview

This runbook documents the procedure for safely upgrading K3s version on all cluster nodes (control plane + workers) with zero downtime and zero data loss.

**Upgrade Strategy:**
- **Method**: Rolling upgrade (master first, then workers one-by-one)
- **Approach**: K3s binary replacement via official install script
- **Downtime**: Control plane: ~2-5 minutes per node; Workers: Zero (drain/upgrade/uncordon)
- **Risk Level**: Medium (with proper pre-upgrade backup)

**Current Cluster Configuration:**

| Node | Role | IP | Current Version | Status |
|------|------|-----|-----------------|--------|
| k3s-master | Control plane | 192.168.2.20 | v1.34.3+k3s1 | Ready |
| k3s-worker-01 | Worker | 192.168.2.21 | v1.34.3+k3s1 | Ready |
| k3s-worker-02 | Worker | 192.168.2.22 | v1.34.3+k3s1 | Ready |

**Key Features:**
- Pre-upgrade etcd snapshot for rollback capability
- Master node upgraded first (control plane)
- Worker nodes upgraded serially with drain/uncordon pattern
- Health verification at each step
- Rollback procedure documented

---

## Prerequisites

Before starting the upgrade:

1. **Cluster Health Check**: Verify cluster is healthy
   ```bash
   kubectl get nodes
   # All nodes should show Ready status

   kubectl get pods --all-namespaces | grep -v Running | grep -v Completed
   # Should show minimal/no non-running pods
   ```

2. **Backup Verification**: Ensure recent etcd snapshot exists
   ```bash
   # Verify snapshot capability (run on master node)
   ssh root@192.168.2.20 "ls -lh /var/lib/rancher/k3s/server/db/snapshots/ | tail -5"
   ```

3. **Version Selection**: Identify target upgrade version
   - Check K3s releases: https://github.com/k3s-io/k3s/releases
   - Recommended: Upgrade one minor version at a time (e.g., v1.28 → v1.29)
   - Review release notes for breaking changes

4. **Maintenance Window**: Plan sufficient time
   - Small cluster (3 nodes): 30-45 minutes
   - Master upgrade: 5-10 minutes
   - Per-worker upgrade: 10-15 minutes

5. **Access Verification**: Ensure you have access
   - kubectl access from workstation (via Tailscale)
   - SSH access to all nodes (master, worker-01, worker-02)
   - Root/sudo privileges on all nodes

---

## Pre-Upgrade Checklist

Complete these steps before starting the upgrade:

### 1. Document Current State

```bash
# Record current versions
kubectl version
kubectl get nodes -o wide

# Record current K3s version on each node
for node in 192.168.2.20 192.168.2.21 192.168.2.22; do
  echo "=== $node ==="
  ssh root@$node "k3s --version"
done

# Save cluster state
kubectl get all --all-namespaces > /tmp/pre-upgrade-cluster-state.txt
```

### 2. Verify Critical Services

```bash
# Check critical workloads are running
kubectl get pods -n data -l app.kubernetes.io/name=postgresql
kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana
kubectl get pods -n ml -l app=ollama
kubectl get pods -n apps -l app=n8n

# Verify ingress is working
curl -k https://grafana.home.jetzinger.com
curl -k https://n8n.home.jetzinger.com
```

### 3. Create Pre-Upgrade etcd Snapshot

**CRITICAL:** Always create a snapshot before upgrading

```bash
# SSH to master node
ssh root@192.168.2.20

# Create snapshot with descriptive name
k3s etcd-snapshot save --name pre-upgrade-$(date +%Y%m%d-%H%M%S)

# Verify snapshot was created
ls -lh /var/lib/rancher/k3s/server/db/snapshots/ | tail -1

# Optional: Copy snapshot off-node for safety
# (to NFS or local machine)
exit
```

**Expected Output:**
```
INFO[0000] Saving etcd snapshot to /var/lib/rancher/k3s/server/db/snapshots/pre-upgrade-20260107-123456
INFO[0001] Snapshot pre-upgrade-20260107-123456 saved
```

### 4. Verify Storage Health

```bash
# Check all PVCs are Bound
kubectl get pvc --all-namespaces

# Verify NFS connectivity
kubectl get sc nfs-client -o yaml
```

### 5. Notify Users (if applicable)

If other users access the cluster:
- Announce maintenance window
- Expected duration and impact
- Contact information for issues

---

## Upgrade Procedure

### Phase 1: Upgrade Master Node (Control Plane)

**Impact:** 2-5 minutes of API server unavailability
**Requirement:** NFR2 - Control plane must recover within 5 minutes

#### Step 1.1: Upgrade K3s on Master

```bash
# SSH to master node
ssh root@192.168.2.20

# Note current version
k3s --version
# Output: k3s version v1.34.3+k3s1 (...)

# Run upgrade with target version
# Replace v1.XX.Y+k3s1 with your target version
export TARGET_VERSION="v1.35.0+k3s1"  # Example - adjust as needed
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=$TARGET_VERSION sh -s - --write-kubeconfig-mode 644

# K3s will automatically restart
```

#### Step 1.2: Wait for Control Plane Recovery

```bash
# Wait for K3s service to restart (on master node)
sleep 10

# Check service status
systemctl status k3s

# Exit master node
exit
```

#### Step 1.3: Verify Master Upgrade

```bash
# From your workstation
# Check master node version
kubectl get nodes

# Expected output:
# NAME            STATUS   ROLES           AGE   VERSION
# k3s-master      Ready    control-plane   42h   v1.35.0+k3s1    <-- Updated
# k3s-worker-01   Ready    <none>          41h   v1.34.3+k3s1
# k3s-worker-02   Ready    <none>          40h   v1.34.3+k3s1

# Verify kubectl commands work
kubectl get pods -n kube-system

# Verify all control plane pods are Running
kubectl get pods -n kube-system | grep -E "(coredns|metrics|traefik)"

# Check cluster info
kubectl cluster-info
```

**Health Check:**
- [ ] Master node shows new version
- [ ] Master node status is Ready
- [ ] kubectl commands respond (API server working)
- [ ] All kube-system pods are Running
- [ ] Recovery time < 5 minutes (NFR2)

**If any check fails:** See [Rollback Procedure](#rollback-procedure) section

---

### Phase 2: Upgrade Worker Nodes

**Impact:** Zero downtime for applications with replicas > 1
**Requirement:** NFR20 - Zero data loss during upgrades

**Pattern:** Drain → Upgrade → Uncordon (one node at a time)

#### Step 2.1: Upgrade Worker-01

**Drain the node:**

```bash
# From your workstation
kubectl drain k3s-worker-01 --ignore-daemonsets --delete-emptydir-data --timeout=5m
```

**Expected Output:**
```
node/k3s-worker-01 cordoned
Warning: ignoring DaemonSet-managed Pods: kube-system/svclb-traefik-XXXXX
evicting pod data/postgres-postgresql-0
evicting pod monitoring/prometheus-kube-prometheus-stack-prometheus-0
...
pod/postgres-postgresql-0 evicted
node/k3s-worker-01 drained
```

**Verify pods rescheduled:**

```bash
# Check PostgreSQL moved to another node
kubectl get pods -n data -o wide | grep postgresql

# Check Prometheus moved
kubectl get pods -n monitoring -o wide | grep prometheus
```

**Upgrade K3s on worker-01:**

```bash
# SSH to worker-01
ssh root@192.168.2.21

# Note current version
k3s --version

# Run upgrade
export TARGET_VERSION="v1.35.0+k3s1"  # Must match master version
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=$TARGET_VERSION sh -

# K3s agent will restart automatically
sleep 10

# Check service status
systemctl status k3s-agent

# Exit worker-01
exit
```

**Verify worker-01 rejoined:**

```bash
# From your workstation
# Wait for node to rejoin
sleep 30

# Check node status
kubectl get nodes

# Expected: k3s-worker-01 shows Ready with new version
# NAME            STATUS   ROLES           AGE   VERSION
# k3s-master      Ready    control-plane   42h   v1.35.0+k3s1
# k3s-worker-01   Ready    <none>          41h   v1.35.0+k3s1    <-- Updated
# k3s-worker-02   Ready    <none>          40h   v1.34.3+k3s1
```

**Uncordon the node:**

```bash
kubectl uncordon k3s-worker-01

# Verify node is schedulable
kubectl get nodes
# k3s-worker-01 should NOT show SchedulingDisabled
```

**Wait for pods to stabilize:**

```bash
# Watch pods reschedule
kubectl get pods --all-namespaces -o wide | grep worker-01

# Wait 2-3 minutes for DaemonSets and workloads to start
sleep 120

# Verify all pods Running
kubectl get pods --all-namespaces | grep -v Running | grep -v Completed
```

**Health Check:**
- [ ] Worker-01 shows new version
- [ ] Worker-01 status is Ready and schedulable
- [ ] Pods rescheduled successfully
- [ ] No pods stuck in Pending/CrashLoopBackOff

---

#### Step 2.2: Upgrade Worker-02

**Repeat same process for worker-02:**

```bash
# Drain
kubectl drain k3s-worker-02 --ignore-daemonsets --delete-emptydir-data --timeout=5m

# Verify pods moved
kubectl get pods -o wide --all-namespaces | grep worker-02
# Should show only DaemonSet pods remaining

# SSH and upgrade
ssh root@192.168.2.22
export TARGET_VERSION="v1.35.0+k3s1"
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=$TARGET_VERSION sh -
sleep 10
systemctl status k3s-agent
exit

# Wait for rejoin
sleep 30

# Verify and uncordon
kubectl get nodes
kubectl uncordon k3s-worker-02

# Wait for stabilization
sleep 120

# Verify health
kubectl get pods --all-namespaces | grep -v Running | grep -v Completed
```

**Health Check:**
- [ ] Worker-02 shows new version
- [ ] Worker-02 status is Ready and schedulable
- [ ] All pods Running
- [ ] No errors in pod logs

---

## Post-Upgrade Verification

### 1. Verify All Nodes Upgraded

```bash
# Check all nodes show same version
kubectl get nodes -o wide

# Expected output (all nodes on v1.35.0+k3s1):
# NAME            STATUS   ROLES           AGE   VERSION
# k3s-master      Ready    control-plane   42h   v1.35.0+k3s1
# k3s-worker-01   Ready    <none>          41h   v1.35.0+k3s1
# k3s-worker-02   Ready    <none>          40h   v1.35.0+k3s1
```

### 2. Verify Cluster Health

```bash
# All pods should be Running
kubectl get pods --all-namespaces | grep -v Running | grep -v Completed

# Check critical services
kubectl get pods -n data -l app.kubernetes.io/name=postgresql
kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus
kubectl get pods -n ml -l app=ollama
kubectl get pods -n apps -l app=n8n
```

### 3. Test Service Accessibility

```bash
# Test ingress endpoints
curl -k https://grafana.home.jetzinger.com
curl -k https://n8n.home.jetzinger.com
curl -k https://dev.home.jetzinger.com/health

# Verify Grafana dashboards load correctly
# Verify Prometheus metrics are being collected
```

### 4. Verify Data Integrity (NFR20)

```bash
# PostgreSQL: Connect and verify data
kubectl exec -it -n data postgres-postgresql-0 -- psql -U postgres -c "SELECT current_database(), count(*) FROM pg_tables WHERE schemaname='public';"

# Prometheus: Verify metrics continuity
# Check Grafana for metrics gaps during upgrade

# Ollama: Verify models accessible
kubectl exec -n ml deployment/ollama -- curl -s http://localhost:11434/api/tags
```

### 5. Check for Anomalies

```bash
# Check for any warnings/errors in recent events
kubectl get events --all-namespaces --sort-by='.lastTimestamp' | tail -50

# Check node conditions
kubectl describe nodes | grep -A 5 Conditions

# Verify no resource pressure
kubectl top nodes
```

### 6. Monitor for 24-48 Hours

After upgrade completion:
- Monitor Grafana dashboards for anomalies
- Watch for any CrashLoopBackOff pods
- Review logs for any new errors
- Verify scheduled jobs (CronJobs) run successfully

---

## Rollback Procedure

**When to rollback:**
- Control plane doesn't recover within 5 minutes
- Worker nodes fail to rejoin cluster
- Critical services fail health checks
- Data loss detected

### Rollback Master Node

**Option 1: Reinstall Previous Version**

```bash
# SSH to master
ssh root@192.168.2.20

# Reinstall previous K3s version
export PREVIOUS_VERSION="v1.34.3+k3s1"  # Your previous version
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=$PREVIOUS_VERSION sh -s - --write-kubeconfig-mode 644

# Wait for restart
sleep 10
systemctl status k3s
exit

# Verify from workstation
kubectl get nodes
kubectl get pods -n kube-system
```

**Option 2: Restore from etcd Snapshot** (if control plane is broken)

```bash
# SSH to master
ssh root@192.168.2.20

# Stop K3s
systemctl stop k3s

# Find your pre-upgrade snapshot
ls -lh /var/lib/rancher/k3s/server/db/snapshots/ | grep pre-upgrade

# Restore snapshot (WARNING: This will reset cluster to snapshot time)
k3s server --cluster-reset --cluster-reset-restore-path=/var/lib/rancher/k3s/server/db/snapshots/pre-upgrade-YYYYMMDD-HHMMSS

# Start K3s
systemctl start k3s

# Verify restoration
sleep 20
kubectl get nodes
exit
```

### Rollback Worker Nodes

```bash
# For each worker that was upgraded
ssh root@<worker-ip>

# Reinstall previous version
export PREVIOUS_VERSION="v1.34.3+k3s1"
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=$PREVIOUS_VERSION sh -

sleep 10
systemctl status k3s-agent
exit

# Verify worker rejoined with old version
kubectl get nodes
```

**CRITICAL:** All nodes should run matching K3s versions. If master is rolled back, all workers must be rolled back too.

---

## Troubleshooting

### Issue: Master Node Won't Start After Upgrade

**Symptoms:**
- `systemctl status k3s` shows failed/inactive
- kubectl commands timeout
- Control plane pods not running

**Diagnosis:**

```bash
# SSH to master
ssh root@192.168.2.20

# Check K3s logs
journalctl -u k3s -n 100 --no-pager

# Check for common issues:
# - Port conflicts (6443, 10250)
# - Certificate issues
# - etcd corruption
```

**Resolution:**
1. Check logs for specific error
2. If etcd corruption: Restore from snapshot (see [Rollback](#rollback-procedure))
3. If port conflict: Identify and stop conflicting process
4. If all else fails: Rollback to previous version

---

### Issue: Worker Node Won't Rejoin

**Symptoms:**
- Node shows NotReady after upgrade
- Node doesn't appear in `kubectl get nodes`
- Pods not scheduling to node

**Diagnosis:**

```bash
# Check worker logs
ssh root@<worker-ip>
journalctl -u k3s-agent -n 100 --no-pager

# Common issues:
# - Can't connect to master (192.168.2.20:6443)
# - Token mismatch
# - Network connectivity issues
```

**Resolution:**

```bash
# Verify connectivity to master
ssh root@<worker-ip>
ping 192.168.2.20
curl -k https://192.168.2.20:6443

# Verify token
# On master:
cat /var/lib/rancher/k3s/server/node-token

# Reinstall worker with explicit token
ssh root@<worker-ip>
curl -sfL https://get.k3s.io | K3S_URL=https://192.168.2.20:6443 K3S_TOKEN=<token> sh -
```

---

### Issue: Pods Stuck in Pending After Worker Upgrade

**Symptoms:**
- Pods show Pending status
- Drain/uncordon completed but pods don't reschedule

**Diagnosis:**

```bash
# Describe pending pod
kubectl describe pod <pod-name> -n <namespace>

# Check for:
# - Insufficient resources (CPU/memory)
# - Node affinity not satisfied
# - Taints preventing scheduling
```

**Resolution:**

```bash
# Check node resources
kubectl describe node <node-name> | grep -A 10 "Allocated resources"

# Check node taints
kubectl describe node <node-name> | grep Taints

# If tainted, remove taint:
kubectl taint nodes <node-name> <taint-key>-
```

---

### Issue: StatefulSet Pods Won't Start After Upgrade

**Symptoms:**
- PostgreSQL or Prometheus pods stuck in Pending/Init
- PVC won't mount

**Diagnosis:**

```bash
# Check PVC status
kubectl get pvc -n <namespace>

# Check PV status
kubectl get pv

# Describe problematic pod
kubectl describe pod <pod-name> -n <namespace>
```

**Resolution:**

```bash
# Verify NFS connectivity
kubectl get sc nfs-client -o yaml

# Check PV reclaim policy
kubectl get pv -o custom-columns=NAME:.metadata.name,RECLAIM:.spec.persistentVolumeReclaimPolicy

# If PVC mount fails, check NFS server
ssh root@192.168.2.2  # Synology NFS server
# Verify NFS exports are accessible
```

---

## Upgrade History

| Date | From Version | To Version | Duration | Issues | Performed By |
|------|--------------|------------|----------|--------|--------------|
| 2026-01-07 | v1.34.3+k3s1 | (pending) | - | - | Cluster Operator |
|  |  |  |  |  |  |

**Notes:**
- Update this table after each upgrade
- Document any issues encountered
- Record lessons learned for future upgrades

---

## Best Practices

### Regular Upgrades

- **Frequency**: Quarterly minor version upgrades recommended
- **Security Patches**: Apply patch versions within 1-2 weeks of release
- **Testing**: Test upgrades in dev environment if possible

### Pre-Upgrade Preparation

- Always create etcd snapshot before upgrade
- Verify cluster health before starting
- Review K3s release notes for breaking changes
- Plan for sufficient maintenance window

### During Upgrade

- Upgrade master first, workers second
- Upgrade workers one at a time (never multiple simultaneously)
- Verify health after each node upgrade
- Don't proceed if any health check fails

### Post-Upgrade

- Monitor for 24-48 hours after upgrade
- Keep pre-upgrade snapshot for at least 7 days
- Document any issues in upgrade history
- Update this runbook with lessons learned

---

## Upgrade History Tracking

### Checking Current K3s Version

**On each node directly:**
```bash
# Check K3s version on master
ssh root@192.168.2.20 "k3s --version"

# Check K3s version on worker nodes
ssh root@192.168.2.21 "k3s --version"
ssh root@192.168.2.22 "k3s --version"

# Example output:
# k3s version v1.34.3+k3s1 (48ffa7b6)
# go version go1.24.11
```

**From remote kubectl:**
```bash
# Check both client and server versions
kubectl version

# Example output:
# Client Version: v1.35.0
# Kustomize Version: v5.7.1
# Server Version: v1.34.3+k3s1
```

**Check all node versions:**
```bash
kubectl get nodes -o wide

# Shows:
# NAME             STATUS   VERSION
# k3s-master       Ready    v1.34.3+k3s1
# k3s-worker-01    Ready    v1.34.3+k3s1
# k3s-worker-02    Ready    v1.34.3+k3s1
```

### Upgrade History Log

Document each upgrade for reference and rollback purposes:

| Date | Previous Version | New Version | Duration | Issues | Rollback Used |
|------|-----------------|-------------|----------|--------|---------------|
| 2026-01-07 | v1.34.3+k3s1 | v1.34.3+k3s1 | N/A | Initial deployment | No |
| _Future_ | _Previous_ | _New_ | _Time_ | _Notes_ | _Yes/No_ |

**Recording Upgrades:**
When performing an upgrade, add an entry to this table with:
- Date of upgrade
- K3s version before upgrade (from `k3s --version`)
- K3s version after upgrade
- Total time taken for full cluster upgrade
- Any issues encountered
- Whether rollback was needed

### Where Upgrade History is Recorded

**Primary Record:**
- This runbook maintains the Upgrade History Log table above
- Git history of this file provides secondary audit trail
- Commit message should include: "Upgrade K3s: v{old} → v{new}"

**System Logs:**
```bash
# View K3s service startup/version changes
journalctl -u k3s | grep "version"
journalctl -u k3s-agent | grep "version"

# View recent K3s service restarts (indicates upgrades)
journalctl -u k3s --since "30 days ago" | grep "Started\|Stopped"
```

**Snapshot Records:**
```bash
# List etcd snapshots (includes pre-upgrade snapshots)
ssh root@192.168.2.20 "ls -lh /var/lib/rancher/k3s/server/db/snapshots/"

# Snapshot filenames include timestamps:
# pre-upgrade-20260107-120000
# on-demand-20260107-150000
```

**Best Practices:**
- Document version before starting any upgrade
- Create git commit after updating this runbook with upgrade results
- Keep upgrade history for minimum 12 months
- Reference upgrade history when planning future upgrades or rollbacks

---

## Related Documentation

**Home-lab Runbooks:**
- **[K3s Rollback Runbook](k3s-rollback.md)** - Rollback procedures if upgrade fails
- **[Cluster Backup Runbook](cluster-backup.md)** - etcd snapshot creation and management
- **[Cluster Restore Runbook](cluster-restore.md)** - Full disaster recovery via etcd snapshot
- **[OS Security Updates Runbook](os-security-updates.md)** - OS-level updates and rollback
- **[Node Removal Runbook](node-removal.md)** - Drain/uncordon procedures

**Official K3s Documentation:**
- [K3s Manual Upgrades](https://docs.k3s.io/upgrades/manual) - Official K3s upgrade guide
- [K3s Backup & Restore](https://docs.k3s.io/backup-restore) - etcd snapshot procedures
- [K3s Releases](https://github.com/k3s-io/k3s/releases) - Version releases and notes

**Implementation Stories:**
- [Story 8.1](../implementation-artifacts/8-1-configure-k3s-upgrade-procedure.md) - K3s upgrade procedure (this runbook)
- [Story 8.2](../implementation-artifacts/8-2-setup-cluster-state-backup.md) - Cluster backup
- [Story 8.3](../implementation-artifacts/8-3-validate-cluster-restore-procedure.md) - Disaster recovery
- [Story 8.5](../implementation-artifacts/8-5-document-rollback-and-history-procedures.md) - Rollback and history

---

## Change Log

- 2026-01-07: Initial runbook creation - K3s upgrade procedure documented (Story 8.1)
