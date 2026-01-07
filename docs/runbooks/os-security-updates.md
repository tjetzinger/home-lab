# Operating System Security Updates

**Purpose:** Automatic security update configuration and management for Ubuntu Server nodes

**Story:** 8.4 - Configure Automatic OS Security Updates
**Date Created:** 2026-01-07
**Last Updated:** 2026-01-07

---

## Overview

This runbook documents the automatic security update system configured on all K3s cluster nodes using Ubuntu's `unattended-upgrades` package.

**Update Strategy:**
- **Method**: Automated security-only updates via unattended-upgrades
- **Frequency**: Daily check and application (meets NFR11: 7-day requirement)
- **Scope**: Security patches only (no feature updates)
- **Reboot**: Manual control (no automatic reboots)

**Current Configuration:**

| Node | OS | unattended-upgrades | Status | Auto-Reboot |
|------|-----|---------------------|--------|-------------|
| k3s-master | Ubuntu 22.04 LTS | 2.8ubuntu1 | Active | Disabled |
| k3s-worker-01 | Ubuntu 22.04 LTS | 2.8ubuntu1 | Active | Disabled |
| k3s-worker-02 | Ubuntu 22.04 LTS | 2.8ubuntu1 | Active | Disabled |

**Key Features:**
- Security updates applied automatically within 1-2 days of release
- Regular/feature updates explicitly blocked
- Automatic reboots disabled (manual coordination required)
- Comprehensive logging for audit trail
- Weekly automatic cleanup of unused packages

**Compliance:**
- ✅ **NFR11**: Security updates within 7 days (actual: 1-2 days)
- ✅ **FR47**: Automatic security updates without manual intervention
- ✅ **FR48** (partial): OS package upgrade history available via logs

---

## Configuration Files

### Primary Configuration: `/etc/apt/apt.conf.d/50unattended-upgrades`

```bash
# Security-only update sources (enabled)
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";         # Ubuntu security
    "${distro_id}ESMApps:${distro_codename}-apps-security";  # ESM Apps
    "${distro_id}ESM:${distro_codename}-infra-security";     # ESM Infrastructure
};

# Regular updates (disabled - commented out)
// "${distro_id}:${distro_codename}";           # Regular updates
// "${distro_id}:${distro_codename}-updates";   # Feature updates
// "${distro_id}:${distro_codename}-backports"; # Backports

# Automatic cleanup (enabled)
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-New-Unused-Dependencies "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";

# Automatic reboot (disabled)
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Automatic-Reboot-WithUsers "false";
```

### Update Frequency: `/etc/apt/apt.conf.d/20auto-upgrades`

```bash
APT::Periodic::Update-Package-Lists "1";          # Daily
APT::Periodic::Unattended-Upgrade "1";            # Daily
APT::Periodic::Download-Upgradeable-Packages "1"; # Daily
APT::Periodic::AutocleanInterval "7";             # Weekly
```

---

## Verification Commands

### Check Service Status

```bash
# Verify service is running
systemctl status unattended-upgrades.service

# Check timer status
systemctl list-timers | grep apt

# Expected output:
# apt-daily.timer           - Daily package updates
# apt-daily-upgrade.timer   - Daily upgrade application
```

### Test Configuration

```bash
# Dry-run test (no actual changes)
sudo unattended-upgrade --dry-run --debug | grep "Allowed origins"

# Expected: o=Ubuntu,a=jammy-security (and ESM variants only)
# Should NOT include: jammy-updates, jammy, jammy-backports
```

### Check Pending Updates

```bash
# View security updates available
sudo unattended-upgrade --dry-run 2>&1 | grep "Packages that will be upgraded"

# Check for reboot requirement
cat /var/run/reboot-required 2>/dev/null && echo "Reboot required" || echo "No reboot needed"
```

---

## Log Management

### Log File Locations

| Log File | Purpose | Typical Size |
|----------|---------|--------------|
| `/var/log/unattended-upgrades/unattended-upgrades.log` | Main activity log | 1-2 MB |
| `/var/log/unattended-upgrades/unattended-upgrades-dpkg.log` | Package operations | 5-15 KB |
| `/var/log/unattended-upgrades/unattended-upgrades-shutdown.log` | Shutdown events | Usually empty |
| `/var/log/dpkg.log` | System-wide package changes | Varies |

### Viewing Update History

```bash
# View recent update activity
sudo tail -50 /var/log/unattended-upgrades/unattended-upgrades.log

# Find all completed upgrades
sudo grep "Packages that will be upgraded" /var/log/unattended-upgrades/unattended-upgrades.log

# View dpkg installation history
sudo grep "upgrade " /var/log/dpkg.log | tail -20

# Check what packages were upgraded in last 7 days
sudo grep "$(date -d '7 days ago' '+%Y-%m-%d')" /var/log/dpkg.log | grep upgrade
```

### Log Retention

- Managed by Ubuntu logrotate
- Default retention: ~4 weeks
- Logs rotated weekly
- Compressed archives: `/var/log/unattended-upgrades/*.log.*.gz`

---

## Manual Intervention

### Force Immediate Update Check

```bash
# Trigger update check immediately
sudo unattended-upgrade --debug

# Verify updates applied
sudo tail -f /var/log/unattended-upgrades/unattended-upgrades.log
```

### Temporarily Disable Automatic Updates

```bash
# Stop the service
sudo systemctl stop unattended-upgrades.service

# Disable timer (prevents automatic starts)
sudo systemctl stop apt-daily-upgrade.timer
sudo systemctl stop apt-daily.timer

# Re-enable when ready
sudo systemctl start apt-daily.timer
sudo systemctl start apt-daily-upgrade.timer
sudo systemctl start unattended-upgrades.service
```

### Hold Specific Package

```bash
# Prevent a package from being upgraded
sudo apt-mark hold <package-name>

# Example: Hold kernel package
sudo apt-mark hold linux-image-generic

# View held packages
apt-mark showhold

# Remove hold
sudo apt-mark unhold <package-name>
```

### Manually Upgrade Specific Package

```bash
# Update package list
sudo apt update

# Upgrade specific package
sudo apt install --only-upgrade <package-name>

# Example: Upgrade only openssl
sudo apt install --only-upgrade openssl
```

---

## Kernel Update and Reboot Procedure

### Detect Kernel Update Requiring Reboot

```bash
# Check if reboot is required
if [ -f /var/run/reboot-required ]; then
    echo "Reboot required"
    cat /var/run/reboot-required.pkgs  # Show which packages need reboot
else
    echo "No reboot required"
fi
```

### Coordinated Cluster Reboot Strategy

When kernel updates require reboot, follow this procedure to maintain cluster availability:

**Sequence:** Worker-01 → Worker-02 → Master (last)

#### Step 1: Reboot Worker-01

```bash
# Drain workloads from worker-01
kubectl drain k3s-worker-01 --ignore-daemonsets --delete-emptydir-data

# SSH to worker-01 and reboot
ssh k3s-worker-01 "sudo reboot"

# Wait for node to come back (2-5 minutes)
kubectl get nodes -w

# Verify node is Ready
kubectl get nodes k3s-worker-01

# Uncordon node (allow scheduling)
kubectl uncordon k3s-worker-01

# Verify pods are running
kubectl get pods -o wide | grep k3s-worker-01
```

#### Step 2: Reboot Worker-02

```bash
# Drain workloads from worker-02
kubectl drain k3s-worker-02 --ignore-daemonsets --delete-emptydir-data

# SSH to worker-02 and reboot
ssh k3s-worker-02 "sudo reboot"

# Wait for node to come back (2-5 minutes)
kubectl get nodes -w

# Verify node is Ready
kubectl get nodes k3s-worker-02

# Uncordon node
kubectl uncordon k3s-worker-02

# Verify pods are running
kubectl get pods -o wide | grep k3s-worker-02
```

#### Step 3: Reboot Master (Last)

```bash
# Verify workers are healthy before master reboot
kubectl get nodes
# Both workers should show "Ready"

# SSH to master and reboot
ssh k3s-master "sudo reboot"

# Wait for control plane to come back (2-5 minutes)
# Note: kubectl will be unavailable during master reboot

# Verify cluster health
kubectl get nodes
kubectl get pods --all-namespaces | grep -v Running | grep -v Completed
```

**Total Time:** ~15-20 minutes for full cluster reboot

---

## Monitoring and Alerting

### Weekly Health Check

Perform weekly review of update status:

```bash
# Check for failed updates
sudo grep -i "error\|failed" /var/log/unattended-upgrades/unattended-upgrades.log | tail -20

# Check for stale logs (no activity > 14 days indicates problem)
sudo ls -lh /var/log/unattended-upgrades/unattended-upgrades.log
# Compare file modification date

# Verify service is still active
systemctl is-active unattended-upgrades.service
```

### Monitoring Checklist

- [ ] Service active on all nodes
- [ ] Timers scheduled and running
- [ ] No errors in recent logs
- [ ] Recent update activity (within 7 days)
- [ ] No held packages blocking security updates
- [ ] Disk space available for updates (`df -h /var`)

### Optional: Prometheus/Grafana Integration

Consider adding node_exporter metrics:

- `node_reboot_required` - Boolean indicating reboot needed
- `node_time_seconds - node_boot_time_seconds` - Uptime tracking
- Custom alert: Stale update logs (no activity > 14 days)

**Note:** Detailed Prometheus integration is a potential future enhancement.

---

## Troubleshooting

### Service Not Running

```bash
# Check service status
systemctl status unattended-upgrades.service

# View recent logs
sudo journalctl -u unattended-upgrades.service -n 50

# Restart service
sudo systemctl restart unattended-upgrades.service
```

### Updates Not Being Applied

```bash
# Check timer status
systemctl list-timers | grep apt

# Check for held packages
apt-mark showhold

# Check disk space
df -h /var

# Run manual update to see errors
sudo unattended-upgrade --debug
```

### Configuration Changes Not Taking Effect

```bash
# Reload systemd after config changes
sudo systemctl daemon-reload

# Restart service
sudo systemctl restart unattended-upgrades.service

# Verify configuration parsed correctly
sudo unattended-upgrade --dry-run --debug | head -20
```

### Broken Packages After Update

```bash
# Fix broken packages
sudo apt --fix-broken install

# Reconfigure packages
sudo dpkg --configure -a

# If specific package is broken, try reinstalling
sudo apt install --reinstall <package-name>
```

### Rollback to Previous Package Version

#### Viewing Package History

```bash
# View all package upgrades in dpkg log
grep "upgrade " /var/log/dpkg.log

# View unattended-upgrades history
sudo grep "Packages that will be upgraded" /var/log/unattended-upgrades/unattended-upgrades.log

# Find specific package history
grep "<package-name>" /var/log/dpkg.log

# Check currently installed package version
dpkg -l | grep <package-name>

# Example: Find kernel upgrades
grep "linux-image" /var/log/dpkg.log
```

#### Package Downgrade Procedure

```bash
# Step 1: Check available versions in apt cache
apt-cache policy <package-name>

# Step 2: Downgrade to specific version
sudo apt install <package-name>=<version>

# Step 3: Hold package at current version (prevent auto-upgrade)
sudo apt-mark hold <package-name>

# Step 4: Verify hold is active
apt-mark showhold

# Step 5: Remove hold when ready for updates
sudo apt-mark unhold <package-name>
```

#### Common OS Rollback Scenarios

**Kernel Downgrade After Problematic Update:**
```bash
# List installed kernels
dpkg -l | grep linux-image

# Boot into older kernel via GRUB menu (select Advanced Options)
# After successful boot into old kernel, remove problematic kernel:
sudo apt remove linux-image-<version>
sudo apt-mark hold linux-image-generic  # Prevent auto-upgrade
```

**Security Patch Rollback (Use with Caution):**
```bash
# Only rollback if patch causes critical issues
# Check available versions
apt-cache policy <package-name>

# Downgrade and hold
sudo apt install <package-name>=<older-version>
sudo apt-mark hold <package-name>

# ⚠️ WARNING: Monitor security advisories
# Document why rollback was necessary
# Plan to address root cause and upgrade again
```

**Dependency Conflicts Resolution:**
```bash
# If upgrade causes dependency issues:
sudo apt install -f  # Try to fix dependencies first

# If fix fails, rollback the conflicting package
sudo apt install <package-name>=<previous-version>
sudo apt-mark hold <package-name>
```

**When NOT to Rollback:**
- ⚠️ Critical security vulnerabilities (CVE-2024-xxxx with CVSS 9+)
- Actively exploited vulnerabilities in the wild
- Security patches for remote code execution (RCE) or privilege escalation
- If rollback creates greater security risk than the bug being fixed

#### Coordination with K3s Cluster

**When OS Rollback Requires Node Reboot:**

If the rollback involves kernel changes or requires a reboot, coordinate with K3s:

```bash
# Step 1: Drain the node (move pods to other nodes)
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# Step 2: SSH to the node
ssh root@<node-ip>

# Step 3: Perform package rollback
sudo apt install <package-name>=<version>
sudo apt-mark hold <package-name>

# Step 4: Reboot if required
sudo reboot

# Step 5: Wait for node to come back online (~2 minutes)

# Step 6: Uncordon the node (allow pod scheduling)
kubectl uncordon <node-name>

# Step 7: Verify node is Ready and pods are running
kubectl get nodes
kubectl get pods --all-namespaces -o wide | grep <node-name>
```

**Cluster Availability Considerations:**
- 3-node cluster can tolerate 1 node drain at a time
- Rollback nodes sequentially, never drain multiple nodes simultaneously
- Allow 5-10 minutes between node rollbacks for pod rescheduling
- Monitor pod status during each node rollback
- Critical workloads should have PodDisruptionBudgets configured

**Reference:**
- For drain/uncordon details, see [k3s-upgrade.md](k3s-upgrade.md) → Node-by-Node Upgrade section
- For K3s version rollback, see [k3s-rollback.md](k3s-rollback.md)

---

## Compliance Validation

### NFR11: Security Update Timeliness (7-day target)

```bash
# Verify daily update schedule
grep "APT::Periodic::Update-Package-Lists" /etc/apt/apt.conf.d/20auto-upgrades
# Expected: "1" (daily)

# Verify daily upgrade schedule
grep "APT::Periodic::Unattended-Upgrade" /etc/apt/apt.conf.d/20auto-upgrades
# Expected: "1" (daily)

# Result: Updates applied within 1-2 days (well within 7-day requirement)
```

### FR47: Automatic Security Updates

```bash
# Verify security-only sources configured
grep "Allowed-Origins" /etc/apt/apt.conf.d/50unattended-upgrades
# Should show only security repositories

# Verify automatic updates enabled
systemctl is-active unattended-upgrades.service apt-daily-upgrade.timer
# Both should return "active"
```

### FR48 (Partial): OS Package History

```bash
# Verify logs available
ls -lh /var/log/unattended-upgrades/

# View upgrade history
sudo grep "Packages that will be upgraded" /var/log/unattended-upgrades/unattended-upgrades.log

# Note: Full FR48 includes K3s upgrade history (covered in Story 8.5)
```

---

## References

- **Story**: 8.4 - Configure Automatic OS Security Updates
- **Related Stories**:
  - 8.1 - K3s Upgrade Procedure
  - 8.5 - Document Rollback and History Procedures (full FR48)
- **Ubuntu Documentation**: https://help.ubuntu.com/community/AutomaticSecurityUpdates
- **unattended-upgrades**: https://wiki.debian.org/UnattendedUpgrades
- **NFR11**: Security updates applied within 7 days of release
- **FR47**: System applies security updates automatically
- **FR48**: Operator can view package and K3s upgrade history
