# K3s Cluster Rollback Procedure

**Purpose:** Safe rollback procedures for K3s version downgrades and recovery from problematic upgrades

**Story:** 8.5 - Document Rollback and History Procedures
**Date Created:** 2026-01-07
**Last Updated:** 2026-01-07

---

## Overview

This runbook documents procedures for rolling back K3s cluster to a previous version when upgrades cause issues or instability.

**Rollback Strategy:**
- **Scope**: K3s version downgrade on control plane and workers
- **Methods**: Binary reinstall or etcd snapshot restore
- **Downtime**: Similar to upgrade (~30 minutes for 3-node cluster)
- **Risk Level**: Medium (with proper snapshot backup)

**Current Cluster Configuration:**

| Node | Role | IP | Current Version | Status |
|------|------|-----|-----------------|--------|
| k3s-master | Control plane | 192.168.2.20 | v1.34.3+k3s1 | Ready |
| k3s-worker-01 | Worker | 192.168.2.21 | v1.34.3+k3s1 | Ready |
| k3s-worker-02 | Worker | 192.168.2.22 | v1.34.3+k3s1 | Ready |

**Key Features:**
- Decision matrix for rollback vs restore
- Version-specific binary rollback
- Full cluster state restore via etcd snapshot
- Comprehensive post-rollback verification
- Integration with cluster-restore procedures

---

## When to Rollback vs Restore

**Decision Matrix:**

| Scenario | Recommended Action | Rationale |
|----------|-------------------|-----------|
| **Version-specific issues** | Rollback (Method 1) | New K3s version has bugs or incompatibilities |
| **Control plane unstable** | Rollback (Method 1) | API server issues, scheduling problems |
| **Worker node issues** | Rollback (Method 1) | Pods not scheduling, networking problems |
| **Recent upgrade (<24h)** | Rollback (Method 1) | Quick recovery to known-good version |
| **etcd corruption** | Restore (Method 2) | Data store integrity compromised |
| **Cluster state broken** | Restore (Method 2) | Multiple failures, unknown cluster state |
| **Data loss concerns** | Restore (Method 2) | Need to restore to specific point in time |
| **Multiple component failures** | Restore (Method 2) | Complex issues requiring full state reset |

**Quick Decision Guide:**

```
Can you identify the issue as K3s-version-specific?
├─ YES → Use Rollback (Method 1 - Binary Reinstall)
└─ NO → Is cluster state corrupt or unknown?
    ├─ YES → Use Restore (Method 2 - etcd Snapshot)
    └─ NO → Try Rollback first, Restore if unsuccessful
```

**References:**
- **Rollback procedures**: This runbook (k3s-rollback.md)
- **Restore procedures**: [cluster-restore.md](cluster-restore.md) - Full disaster recovery guide

---

## Prerequisites

Before starting rollback:

1. **Identify Target Version**: Determine which K3s version to roll back to
   ```bash
   # Check upgrade history in k3s-upgrade.md runbook
   # View: docs/runbooks/k3s-upgrade.md → Upgrade History Log

   # Or check system journal for previous version
   ssh root@192.168.2.20 "journalctl -u k3s | grep 'version v' | tail -10"
   ```

2. **Verify etcd Snapshot Exists** (backup safety net)
   ```bash
   # Check for recent pre-upgrade snapshot
   ssh root@192.168.2.20 "ls -lh /var/lib/rancher/k3s/server/db/snapshots/ | grep pre-upgrade | tail -5"
   ```

3. **Document Current State** (for rollback validation)
   ```bash
   # Save current problematic state
   kubectl get nodes -o wide > /tmp/before-rollback-nodes.txt
   kubectl get pods --all-namespaces > /tmp/before-rollback-pods.txt
   kubectl get all --all-namespaces > /tmp/before-rollback-state.txt
   ```

4. **Access Verification**
   - SSH access to all nodes (master, worker-01, worker-02)
   - Root/sudo privileges on all nodes
   - kubectl access from workstation (via Tailscale)

---

## Method 1: Rollback via Binary Reinstall

**Use Case:** Version-specific issues, control plane instability, recent upgrades

**Approach:** Reinstall previous K3s version using official install script

### Option A: Reinstall via Install Script (Recommended)

#### Step 1: Rollback Master Node

```bash
# Identify target version from upgrade history
export PREVIOUS_VERSION="v1.34.3+k3s1"  # Replace with your previous version

# SSH to master
ssh root@192.168.2.20

# Stop K3s (brief control plane downtime)
systemctl stop k3s

# Reinstall previous K3s version
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=$PREVIOUS_VERSION sh -s - server \
  --write-kubeconfig-mode 644

# Wait for K3s to start
sleep 15

# Verify service started
systemctl status k3s

# Exit master
exit
```

**Verify Master Rollback:**
```bash
# Check master version (should show previous version)
ssh root@192.168.2.20 "k3s --version"

# Verify control plane accessible
kubectl get nodes
kubectl get pods -n kube-system

# Expected: Master shows previous version, status Ready
```

#### Step 2: Rollback Worker-01

```bash
# Worker nodes follow same pattern
export PREVIOUS_VERSION="v1.34.3+k3s1"

# Drain workloads from worker-01
kubectl drain k3s-worker-01 --ignore-daemonsets --delete-emptydir-data

# SSH to worker-01
ssh root@192.168.2.21

# Stop K3s agent
systemctl stop k3s-agent

# Reinstall previous K3s version
curl -sfL https://get.k3s.io | K3S_URL=https://192.168.2.20:6443 \
  K3S_TOKEN=$(cat /var/lib/rancher/k3s/server/node-token 2>/dev/null || echo "YOUR_TOKEN") \
  INSTALL_K3S_VERSION=$PREVIOUS_VERSION sh -

# Wait for agent to start
sleep 10

# Verify service started
systemctl status k3s-agent

# Exit worker
exit

# Uncordon node
kubectl uncordon k3s-worker-01

# Verify worker rejoined
kubectl get nodes
```

#### Step 3: Rollback Worker-02

```bash
# Repeat for worker-02
kubectl drain k3s-worker-02 --ignore-daemonsets --delete-emptydir-data

ssh root@192.168.2.22

systemctl stop k3s-agent

curl -sfL https://get.k3s.io | K3S_URL=https://192.168.2.20:6443 \
  K3S_TOKEN=$(cat /var/lib/rancher/k3s/server/node-token 2>/dev/null || echo "YOUR_TOKEN") \
  INSTALL_K3S_VERSION=$PREVIOUS_VERSION sh -

sleep 10
systemctl status k3s-agent
exit

kubectl uncordon k3s-worker-02
kubectl get nodes
```

---

### Option B: Manual Binary Replacement (Offline/Advanced)

**Use Case:** No internet access, custom binary, advanced troubleshooting

```bash
# On node with problematic K3s version
ssh root@<node-ip>

# Stop K3s
systemctl stop k3s  # or k3s-agent for workers

# Backup current binary
cp /usr/local/bin/k3s /usr/local/bin/k3s.backup-$(date +%Y%m%d-%H%M%S)

# Replace with previous binary (you must have saved it)
# Option 1: Copy from another node
scp root@<working-node-ip>:/usr/local/bin/k3s /usr/local/bin/k3s

# Option 2: Download specific version
wget https://github.com/k3s-io/k3s/releases/download/${VERSION}/k3s -O /usr/local/bin/k3s
chmod +x /usr/local/bin/k3s

# Start K3s
systemctl start k3s  # or k3s-agent for workers

# Verify
k3s --version
systemctl status k3s
```

**Note:** Manual binary replacement requires careful version matching and is not recommended unless install script unavailable.

---

## Method 2: Rollback via etcd Snapshot Restore

**Use Case:** etcd corruption, cluster state broken, multiple failures

**Important:** This method restores the ENTIRE cluster state to snapshot time, including:
- K3s version
- All deployed workloads and configurations
- Kubernetes objects (pods, services, deployments, etc.)
- etcd data

**Refer to Full Procedure:**
This method is documented comprehensively in [cluster-restore.md](cluster-restore.md).

**Quick Reference:**

```bash
# On master node
ssh root@192.168.2.20

# Stop K3s
systemctl stop k3s

# List available snapshots
ls -lh /var/lib/rancher/k3s/server/db/snapshots/

# Restore from pre-upgrade snapshot
k3s server \
  --cluster-reset \
  --cluster-reset-restore-path=/var/lib/rancher/k3s/server/db/snapshots/pre-upgrade-YYYYMMDD-HHMMSS

# Start K3s
systemctl start k3s

# Wait for cluster to recover (2-5 minutes)
sleep 120

# Exit master
exit

# Verify from workstation
kubectl get nodes
kubectl get pods --all-namespaces
```

**Worker Node Rejoin:**
After snapshot restore, workers may need rejoining:
```bash
# If workers show NotReady:
ssh root@<worker-ip>
systemctl restart k3s-agent

# If restart doesn't help, reinstall agent:
curl -sfL https://get.k3s.io | K3S_URL=https://192.168.2.20:6443 \
  K3S_TOKEN=$(ssh root@192.168.2.20 "cat /var/lib/rancher/k3s/server/node-token") sh -
```

**Full Documentation:** See [cluster-restore.md](cluster-restore.md) for complete restore procedures and troubleshooting.

---

## Post-Rollback Verification

**Complete this checklist after any rollback:**

### 1. Verify K3s Version on All Nodes

```bash
# Check version on each node
for node in 192.168.2.20 192.168.2.21 192.168.2.22; do
  echo "=== $node ==="
  ssh root@$node "k3s --version"
done

# Expected: All nodes show target (previous) version
```

### 2. Verify Node Status

```bash
# Check all nodes Ready
kubectl get nodes

# Expected output:
# NAME             STATUS   VERSION
# k3s-master       Ready    v1.34.3+k3s1  (your previous version)
# k3s-worker-01    Ready    v1.34.3+k3s1
# k3s-worker-02    Ready    v1.34.3+k3s1
```

### 3. Verify Pod Health

```bash
# Check all pods running
kubectl get pods --all-namespaces | grep -v Running | grep -v Completed

# Should show minimal/no non-running pods

# Check critical workloads
kubectl get pods -n kube-system  # K3s system pods
kubectl get pods -n data         # PostgreSQL
kubectl get pods -n monitoring   # Prometheus/Grafana
kubectl get pods -n ml           # Ollama
kubectl get pods -n apps         # n8n
```

### 4. Verify Workload Functionality

```bash
# Spot-check critical services
curl -k https://grafana.home.jetzinger.com
curl -k https://n8n.home.jetzinger.com

# PostgreSQL connectivity test
kubectl exec -it -n data postgres-postgresql-0 -- psql -U postgres -c "SELECT version();"

# Ollama API test
kubectl exec -n ml deployment/ollama -- curl -s http://localhost:11434/api/tags
```

### 5. Verify etcd Health

```bash
# Check etcd health endpoint
kubectl get --raw /healthz/etcd

# Expected: ok

# Verify etcd member list
ssh root@192.168.2.20 "k3s kubectl get --raw /v1/members"
```

### 6. Check for Anomalies

```bash
# Review recent events
kubectl get events --all-namespaces --sort-by='.lastTimestamp' | tail -50

# Check node conditions
kubectl describe nodes | grep -A 5 Conditions

# Verify resource usage normal
kubectl top nodes
```

### 7. Recovery Time Validation

**Expected Recovery Time:** ~30 minutes for full 3-node cluster rollback

| Phase | Expected Duration |
|-------|------------------|
| Master rollback | 5-10 minutes |
| Worker-01 rollback | 10-15 minutes |
| Worker-02 rollback | 10-15 minutes |
| **Total** | **25-40 minutes** |

**Document Actual Time:**
Record actual rollback time in rollback log for future reference.

---

## Rollback Decision Log

Document each rollback for audit and learning purposes:

| Date | From Version | To Version | Method | Reason | Duration | Success |
|------|-------------|------------|--------|--------|----------|---------|
| _Date_ | _New Ver_ | _Old Ver_ | _Method 1/2_ | _Why rollback?_ | _Time_ | _Yes/No_ |

**Recording Rollbacks:**
- Date of rollback
- K3s version being rolled back FROM
- K3s version being rolled back TO
- Method used (Method 1: Binary Reinstall or Method 2: Snapshot Restore)
- Reason for rollback (issue description)
- Total time taken
- Success status and any issues

---

## Troubleshooting Rollback Issues

### Issue: Master Won't Start After Rollback

**Symptoms:**
- `systemctl status k3s` shows failed
- K3s logs show errors
- Control plane inaccessible

**Diagnosis:**
```bash
ssh root@192.168.2.20
journalctl -u k3s -n 100 --no-pager | grep -i error
```

**Resolution:**
1. Check for port conflicts (6443, 10250)
2. Verify token file exists: `/var/lib/rancher/k3s/server/node-token`
3. Check etcd data directory: `/var/lib/rancher/k3s/server/db/`
4. If all else fails: Use Method 2 (etcd snapshot restore)

---

### Issue: Worker Node Won't Rejoin After Rollback

**Symptoms:**
- Node shows NotReady
- `kubectl get nodes` missing worker
- Pods not scheduling

**Diagnosis:**
```bash
ssh root@<worker-ip>
journalctl -u k3s-agent -n 100 --no-pager | grep -i error
```

**Resolution:**
```bash
# Verify master connectivity
ping 192.168.2.20
curl -k https://192.168.2.20:6443

# Get token from master
ssh root@192.168.2.20 "cat /var/lib/rancher/k3s/server/node-token"

# Reinstall worker agent with explicit token
ssh root@<worker-ip>
systemctl stop k3s-agent
rm -rf /var/lib/rancher/k3s/agent  # Clean agent state

export K3S_TOKEN="<token-from-master>"
export PREVIOUS_VERSION="v1.34.3+k3s1"
curl -sfL https://get.k3s.io | K3S_URL=https://192.168.2.20:6443 \
  INSTALL_K3S_VERSION=$PREVIOUS_VERSION sh -
```

---

### Issue: Pods Stuck After Rollback

**Symptoms:**
- Pods show CrashLoopBackOff or Pending
- Services not accessible

**Diagnosis:**
```bash
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace>
```

**Resolution:**
```bash
# Restart affected deployments
kubectl rollout restart deployment/<deployment-name> -n <namespace>

# Force pod recreation
kubectl delete pod <pod-name> -n <namespace>

# Check for resource constraints
kubectl describe nodes | grep -A 10 "Allocated resources"
```

---

### Issue: Different Behavior After Rollback

**Symptoms:**
- Cluster works but behavior differs from before upgrade
- Configuration seems lost or changed

**Possible Causes:**
- ConfigMaps or Secrets modified during upgrade
- Workload configurations changed
- Snapshot restore from wrong time point

**Resolution:**
1. Compare current state with pre-upgrade documentation
2. Check git history for configuration changes during upgrade period
3. Review kubectl apply logs if available
4. Consider restoring from earlier snapshot if available

---

## Best Practices

### Before Rollback

- **Document thoroughly**: Capture current state before rollback
- **Verify snapshot**: Ensure recent etcd snapshot exists
- **Review upgrade history**: Confirm target version is known-good
- **Plan maintenance window**: Allow 30-60 minutes

### During Rollback

- **Master first**: Always rollback master before workers
- **Workers one-by-one**: Never rollback multiple workers simultaneously
- **Verify each step**: Check health after each node rollback
- **Don't rush**: Take time to verify before proceeding

### After Rollback

- **Monitor 24-48 hours**: Watch for delayed issues
- **Document lessons**: Update rollback log with findings
- **Keep snapshots**: Retain both pre-upgrade and post-rollback snapshots
- **Review root cause**: Understand why rollback was necessary
- **Update runbooks**: Document any new insights or procedures

### Preventing Future Rollbacks

- **Test upgrades**: Use dev environment if possible
- **Review release notes**: Check for breaking changes before upgrading
- **Upgrade incrementally**: One minor version at a time
- **Keep snapshots fresh**: Multiple recent snapshots increase recovery options

---

## Related Documentation

- **[K3s Upgrade Runbook](k3s-upgrade.md)** - Upgrade procedures and history tracking
- **[Cluster Restore Runbook](cluster-restore.md)** - Full disaster recovery via etcd snapshot
- **[Cluster Backup Runbook](cluster-backup.md)** - etcd snapshot creation and management
- **[OS Security Updates Runbook](os-security-updates.md)** - OS-level rollback procedures
- **[K3s Releases](https://github.com/k3s-io/k3s/releases)** - Version releases and notes
- **[K3s Backup & Restore](https://docs.k3s.io/backup-restore)** - Official K3s documentation
- **[Story 8.5](../implementation-artifacts/8-5-document-rollback-and-history-procedures.md)** - Implementation story

---

## Compliance Validation

**FR48: View upgrade history and rollback if needed**
- ✅ **Upgrade History**: Documented in [k3s-upgrade.md](k3s-upgrade.md) → Upgrade History Tracking section
- ✅ **OS Package History**: Documented in [os-security-updates.md](os-security-updates.md) → Rollback section
- ✅ **K3s Rollback**: Documented in this runbook (k3s-rollback.md)
- ✅ **OS Package Rollback**: Documented in [os-security-updates.md](os-security-updates.md)

**Combined Coverage:** K3s upgrade/rollback + OS package upgrade/rollback = **Full FR48 Compliance**

---

## P1 Alert Response Guide (NFR22 Validation)

**NFR22 Requirement:** Runbooks must exist for all P1 (critical severity) alert scenarios

**Purpose:** This section maps all P1/critical alerts to their corresponding response runbooks, validating NFR22 compliance.

### P1 Alert to Runbook Mapping Matrix

| P1 Alert Scenario | Alert Name (if defined) | Severity | Runbook | Coverage Status |
|-------------------|------------------------|----------|---------|-----------------|
| **Database Unavailable** | PostgreSQLUnhealthy | critical | [postgres-restore.md](postgres-restore.md), [postgres-connectivity.md](postgres-connectivity.md) | ✅ Complete |
| **Storage Provisioner Down** | NFSProvisionerUnreachable | critical | [nfs-restore.md](nfs-restore.md) | ✅ Complete |
| **K3s Node Not Ready** | KubeNodeNotReady (default) | critical | [k3s-upgrade.md](k3s-upgrade.md), [os-security-updates.md](os-security-updates.md) | ✅ Complete |
| **K3s Control Plane Down** | KubeControllerManagerDown, KubeSchedulerDown (default) | critical | [k3s-rollback.md](k3s-rollback.md), [cluster-restore.md](cluster-restore.md) | ✅ Complete |
| **etcd Cluster Issues** | etcdMembersDown, etcdInsufficientMembers (default) | critical | [cluster-restore.md](cluster-restore.md), [cluster-backup.md](cluster-backup.md) | ✅ Complete |
| **Pod Crash Looping** | KubePodCrashLooping (default) | critical | [k3s-rollback.md](k3s-rollback.md) (if after upgrade), [cluster-restore.md](cluster-restore.md) | ✅ Complete |
| **Deployment Replicas Mismatch** | KubeDeploymentReplicasMismatch (default) | critical | [k3s-rollback.md](k3s-rollback.md), [k3s-svclb-recovery.md](k3s-svclb-recovery.md) | ✅ Complete |
| **PVC Provisioning Failures** | - | critical | [nfs-restore.md](nfs-restore.md) | ✅ Complete |
| **Alertmanager System Down** | AlertmanagerFailedReload (default) | critical | [alertmanager-setup.md](alertmanager-setup.md) | ✅ Complete |
| **K3s Version Issues After Upgrade** | - | critical | [k3s-rollback.md](k3s-rollback.md) (**this runbook**) | ✅ Complete |
| **OS Package Issues After Update** | - | critical | [os-security-updates.md](os-security-updates.md) | ✅ Complete |

### Runbook Coverage Summary

**Total P1 Scenarios Identified:** 11
**Runbooks Available:** 14
**Coverage Gaps:** 0 ❌ None

**All Runbooks:**
1. ✅ **alertmanager-setup.md** - Alertmanager configuration and troubleshooting
2. ✅ **cluster-backup.md** - etcd snapshot backup procedures
3. ✅ **cluster-restore.md** - Disaster recovery from etcd snapshots
4. ✅ **k3s-rollback.md** - K3s version rollback (this runbook)
5. ✅ **k3s-svclb-recovery.md** - Service LoadBalancer recovery
6. ✅ **k3s-upgrade.md** - K3s upgrade procedures and node issues
7. ✅ **loki-setup.md** - Log aggregation setup (non-P1)
8. ✅ **nfs-restore.md** - NFS storage provisioner recovery
9. ✅ **node-removal.md** - Node removal procedures (non-P1)
10. ✅ **os-security-updates.md** - OS updates and package rollback
11. ✅ **postgres-backup.md** - PostgreSQL backup procedures
12. ✅ **postgres-connectivity.md** - PostgreSQL connection troubleshooting
13. ✅ **postgres-restore.md** - PostgreSQL database recovery
14. ✅ **postgres-setup.md** - PostgreSQL initial setup (non-P1)

### NFR22 Compliance Statement

✅ **NFR22 VALIDATED:** Runbooks exist for all P1 (critical severity) alert scenarios in the home-lab cluster.

**Validation Date:** 2026-01-07
**Validation Method:** Comprehensive audit of:
- Custom alert rules ([monitoring/prometheus/custom-rules.yaml](../../monitoring/prometheus/custom-rules.yaml))
- Default kube-prometheus-stack critical alerts
- All runbooks in [docs/runbooks/](../)

**Coverage:** 11 P1 scenarios mapped to 14 available runbooks with 0 gaps.

**Mobile Notification:** All P1 alerts (severity=critical) route to mobile notifications via ntfy.sh per [alertmanager-setup.md](alertmanager-setup.md).

**Next Steps if P1 Alert Fires:**
1. Check mobile notification for alert details
2. Identify alert scenario from matrix above
3. Follow corresponding runbook for recovery
4. Document incident and update runbook if needed

---

## Change Log

- 2026-01-07: Initial runbook creation - K3s rollback procedures documented (Story 8.5)
