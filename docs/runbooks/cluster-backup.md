# K3s Cluster State Backup Runbook

**Last Updated:** 2026-01-07
**Story:** 8.2 - Setup Cluster State Backup
**Maintainer:** Home Lab Operations

## Overview

This runbook describes the K3s cluster state backup system using embedded etcd snapshots. The cluster automatically creates snapshots of the etcd database every 12 hours and stores them on NFS for off-node protection.

**Backup Method:** K3s native etcd snapshots
**Storage Location:** `/mnt/k3s-snapshots` (NFS mount from Synology DS920+)
**Schedule:** Every 12 hours (00:00 and 12:00 UTC)
**Retention:** 14 snapshots (7 days of history)
**Secondary Protection:** Synology hourly snapshots of NFS volume

## Prerequisites

- SSH access to k3s-master node (192.168.2.20)
- Sudo privileges on master node
- NFS mount `/mnt/k3s-snapshots` must be healthy

## Configuration

### K3s Snapshot Settings

**Configuration File:** `/etc/rancher/k3s/config.yaml` on k3s-master

```yaml
cluster-init: true
etcd-snapshot-dir: /mnt/k3s-snapshots
etcd-snapshot-schedule-cron: "0 */12 * * *"
etcd-snapshot-retention: 14
```

### Storage Architecture

```
K3s Master Node (192.168.2.20)
    └─ /mnt/k3s-snapshots (NFS mount)
           │
           └─> Synology DS920+ (192.168.2.2)
                  └─ /volume1/k8s-data/k3s-snapshots/
                        └─ Hourly Synology snapshots (additional protection)
```

**Dual Protection:**
1. Primary: K3s etcd snapshots (every 12 hours, 14 retention)
2. Secondary: Synology snapshots of NFS volume (hourly, per Synology policy)

## Snapshot Operations

### List All Snapshots

```bash
# List snapshots via K3s
ssh k3s-master "k3s etcd-snapshot ls"

# Example output:
# Name                                              Location                                                    Size     Created
# etcd-snapshot-k3s-master-1767787427              file:///mnt/k3s-snapshots/etcd-snapshot-k3s-master-...     17621024 2026-01-07T12:00:00Z
```

### View Snapshot Files on NFS

```bash
# List snapshot files
ssh k3s-master "ls -lh /mnt/k3s-snapshots/"

# Expected output: Timestamped snapshot files (~15-20MB each)
```

### Create Manual Snapshot

**When to use:**
- Before major cluster changes (upgrades, configuration changes)
- Before deploying critical applications
- As part of disaster recovery testing

**Command:**
```bash
ssh k3s-master "k3s etcd-snapshot save --name manual-$(date +%Y%m%d-%H%M%S)"
```

**Expected Output:**
```
time="2026-01-07T12:00:00Z" level=info msg="Snapshot manual-20260107-120000-k3s-master-1767787427 saved."
```

**Verification:**
```bash
# Verify snapshot created
k3s etcd-snapshot ls | grep manual

# Verify file on NFS
ls -lh /mnt/k3s-snapshots/ | grep manual
```

### Delete Old Snapshots (Manual Cleanup)

**Note:** Automatic retention cleanup happens during scheduled snapshots. Manual deletion is rarely needed.

```bash
# Delete specific snapshot
ssh k3s-master "k3s etcd-snapshot delete <snapshot-name>"

# Example:
ssh k3s-master "k3s etcd-snapshot delete manual-20260107-120000-k3s-master-1767787427"
```

## Monitoring

### Verify Automatic Snapshot Schedule

```bash
# Check recent snapshot activity in K3s logs
ssh k3s-master "sudo journalctl -u k3s --since '24 hours ago' | grep -i 'snapshot.*saved'"

# Expected: Snapshots at 00:00 and 12:00 UTC
```

### Check NFS Mount Health

```bash
# Verify NFS mount is active
ssh k3s-master "df -h | grep k3s-snapshots"

# Expected output:
# 192.168.2.2:/volume1/k8s-data/k3s-snapshots  5.3T  3.9T  1.4T  75% /mnt/k3s-snapshots

# Test write access
ssh k3s-master "sudo touch /mnt/k3s-snapshots/test && sudo rm /mnt/k3s-snapshots/test"
```

### Disk Space Monitoring

```bash
# Check NFS volume free space
ssh k3s-master "df -h /mnt/k3s-snapshots"

# Check snapshot sizes
ssh k3s-master "du -sh /mnt/k3s-snapshots/*"

# Expected: ~15-20MB per snapshot, ~280MB total for 14 snapshots
```

## Troubleshooting

### Issue: No Recent Snapshots

**Symptoms:** No snapshots created in last 12 hours

**Diagnosis:**
```bash
# Check K3s service status
ssh k3s-master "sudo systemctl status k3s"

# Check K3s logs for snapshot errors
ssh k3s-master "sudo journalctl -u k3s --since '24 hours ago' | grep -i snapshot"

# Verify snapshot configuration
ssh k3s-master "cat /etc/rancher/k3s/config.yaml | grep snapshot"
```

**Resolution:**
1. Verify NFS mount is healthy (see NFS Mount Health check above)
2. Check disk space on NFS volume
3. Restart K3s if configuration was changed: `sudo systemctl restart k3s`
4. Create manual snapshot to test: `k3s etcd-snapshot save --name test-$(date +%Y%m%d)`

### Issue: NFS Mount Not Available

**Symptoms:** `/mnt/k3s-snapshots` not accessible, snapshots failing

**Diagnosis:**
```bash
# Check mount status
ssh k3s-master "mount | grep k3s-snapshots"

# Check NFS server connectivity
ssh k3s-master "ping -c 3 192.168.2.2"

# Check Synology NFS service
showmount -e 192.168.2.2
```

**Resolution:**
```bash
# Remount NFS
ssh k3s-master "sudo umount /mnt/k3s-snapshots"
ssh k3s-master "sudo mount /mnt/k3s-snapshots"

# Verify mount
ssh k3s-master "df -h | grep k3s-snapshots"

# If mount fails, check /etc/fstab entry:
# 192.168.2.2:/volume1/k8s-data/k3s-snapshots /mnt/k3s-snapshots nfs defaults 0 0
```

### Issue: Snapshots Too Large

**Symptoms:** Snapshot files growing beyond expected size (~20MB+)

**Possible Causes:**
- Large number of resources in cluster
- Many ConfigMaps or Secrets
- Cert-manager certificates accumulating

**Diagnosis:**
```bash
# Check snapshot file sizes
ssh k3s-master "ls -lh /mnt/k3s-snapshots/ | sort -k5 -h"

# Count cluster resources
kubectl get all --all-namespaces --no-headers | wc -l
kubectl get secrets --all-namespaces --no-headers | wc -l
```

**Resolution:**
- Normal for snapshot size to grow as cluster grows
- If >50MB, review for unnecessary resources
- Consider cleanup of old cert-manager orders/challenges
- Increase NFS storage allocation if needed

### Issue: Snapshot Command Fails

**Symptoms:** `k3s etcd-snapshot save` returns error

**Common Errors and Solutions:**

**Error: "etcd datastore disabled"**
- **Cause:** K3s not using embedded etcd
- **Check:** `kubectl get nodes` - master should show `control-plane,etcd` role
- **Resolution:** See ADR-010 for etcd migration procedure

**Error: "permission denied" on /mnt/k3s-snapshots**
- **Cause:** NFS permissions issue
- **Check:** `ls -ld /mnt/k3s-snapshots`
- **Resolution:** Verify K3s process can write to NFS, check Synology NFS permissions

**Error: "no space left on device"**
- **Cause:** NFS volume full
- **Check:** `df -h /mnt/k3s-snapshots`
- **Resolution:** Free space on Synology or increase retention settings

## Backup Best Practices

### Pre-Change Snapshots

**Always create manual snapshot before:**
- K3s version upgrades
- Major application deployments
- Cluster configuration changes
- Certificate authority updates

**Command Pattern:**
```bash
# Descriptive snapshot names help with recovery
k3s etcd-snapshot save --name pre-upgrade-to-v1.35-$(date +%Y%m%d)
k3s etcd-snapshot save --name before-traefik-v3-migration-$(date +%Y%m%d)
```

### Snapshot Verification

**Recommended monthly verification:**
```bash
# 1. List recent snapshots
k3s etcd-snapshot ls

# 2. Verify NFS accessibility
ls -lh /mnt/k3s-snapshots/

# 3. Check Synology snapshots of NFS volume
# (Via Synology DSM: Snapshot Replication > Snapshots > volume1/k8s-data)

# 4. Verify retention policy working (should have 14 snapshots max)
ls /mnt/k3s-snapshots/ | wc -l
```

### Off-Site Backup Considerations

**Current Protection:**
- Primary: NFS on Synology (RAID protection)
- Secondary: Synology hourly snapshots

**Additional Protection (Optional):**
- Synology Hyper Backup to external drive
- Synology Cloud Sync to cloud provider
- Manual periodic copy to external storage

## Restore Procedures

**Note:** Snapshot restore is covered in detail in `cluster-restore.md` runbook (Story 8.3).

**Quick Reference:**
```bash
# List available snapshots
k3s etcd-snapshot ls

# Restore from snapshot (stops cluster, requires caution)
k3s server \
  --cluster-reset \
  --cluster-reset-restore-path=/mnt/k3s-snapshots/<snapshot-name>
```

**⚠️ WARNING:** Restoring from snapshot replaces all cluster state. See `cluster-restore.md` for full procedure.

## Related Runbooks

- **k3s-upgrade.md** - Uses pre-upgrade snapshots for safety
- **cluster-restore.md** (Story 8.3) - Full restore procedures from snapshots
- **postgres-backup.md** - Application-level database backup
- **nfs-restore.md** - NFS storage troubleshooting

## Compliance & Requirements

**Satisfies:**
- **FR45:** Operator can backup cluster state
- **NFR6:** Cluster state can be restored within 30 minutes (validated in Story 8.3)
- **NFR20:** K3s upgrades complete with zero data loss (pre-upgrade snapshots)

**Architecture Alignment:**
- Backup & Recovery Architecture: etcd snapshots (K3s built-in)
- Off-node storage via NFS for disaster recovery
- Dual protection: K3s snapshots + Synology snapshots

## Additional Resources

### K3s Documentation
- [K3s Backup and Restore](https://docs.k3s.io/datastore/backup-restore)
- [K3s etcd-snapshot CLI](https://docs.k3s.io/cli/etcd-snapshot)
- [K3s HA Embedded etcd](https://docs.k3s.io/datastore/ha-embedded)

### Architecture Decisions
- **ADR-010:** K3s Datastore Migration (sqlite → etcd)
- Architecture.md: Backup & Recovery Architecture

### Monitoring Queries

**Prometheus Alert:** (Future - Story 4.x extension)
```yaml
# Alert if no snapshot in last 13 hours (should run every 12h)
- alert: K3sSnapshotMissing
  expr: time() - etcd_snapshot_last_timestamp > 46800
  for: 1h
  labels:
    severity: warning
```

---

**Runbook Version:** 1.0
**Last Tested:** 2026-01-07
**Next Review:** 2026-02-07 (monthly)
