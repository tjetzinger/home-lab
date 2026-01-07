# ADR-010: K3s Datastore Migration from Sqlite to Embedded Etcd

**Date:** 2026-01-07
**Status:** Approved
**Context:** Epic 8 - Cluster Operations & Maintenance, Story 8.2

## Context

During gap analysis for Story 8.2 (Setup Cluster State Backup), a critical architectural deviation was discovered: the K3s cluster is using the default sqlite datastore instead of embedded etcd as assumed by the architecture document.

### Current State

**K3s Configuration:**
- Version: v1.34.3+k3s1
- Topology: 1 master + 2 workers (single control plane)
- Datastore: SQLite at `/var/lib/rancher/k3s/server/db/state.db` (45MB)
- Service flags: Only `--write-kubeconfig-mode 644`
- Installed via: `infrastructure/k3s/install-master.sh` (Story 1.1)

**Impact:**
- `k3s etcd-snapshot` commands fail with "etcd datastore disabled"
- No native K3s snapshot capability available
- Cannot implement Story 8.2 as designed (assumes etcd snapshots)

### Architecture Expectation

From `docs/planning-artifacts/architecture.md`:

```markdown
### Backup & Recovery Architecture
| Cluster State | etcd snapshots (K3s) | Built-in, automatic, lightweight |
```

The architecture explicitly assumes K3s will use embedded etcd for cluster state with native snapshot capabilities.

### Root Cause

Story 1.1 implementation (`install-master.sh`) used the default K3s installation without the `--cluster-init` flag:

```bash
curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644
```

K3s defaults to sqlite for single-server installations unless `--cluster-init` is specified.

## Decision

**We will migrate K3s from sqlite to embedded etcd using the officially supported migration path.**

This involves:
1. Adding `--cluster-init` flag to K3s systemd service
2. Restarting K3s service to trigger automatic data migration
3. Verifying successful migration and cluster recovery

## Rationale

### Why Migrate to Etcd (Chosen Approach)

**Alignment with Architecture:**
- Explicit architecture decision calls for etcd snapshots
- Restore alignment with documented design

**Native Snapshot Capability:**
- Automatic snapshots every 12 hours (configurable)
- Built-in retention management (default: 5 snapshots)
- Off-node storage support via `--etcd-snapshot-dir`
- Manual snapshot capability: `k3s etcd-snapshot save`
- Native restore procedure: `k3s etcd-snapshot restore`

**Future-Ready:**
- Enables HA expansion (can add more control plane nodes)
- No second migration needed if HA is desired later
- etcd required for multi-master setup

**Low Implementation Cost:**
- Officially supported migration path
- Automatic data migration by K3s
- Story 8.2 tasks remain valid (add Task 0 only)
- ~5 minutes one-time downtime

**Operational Simplicity:**
- K3s native commands (no custom scripts)
- Consistent with K3s ecosystem best practices
- Better documented than custom sqlite backup solutions

### Why Not Keep Sqlite (Alternative Rejected)

**Rejected because:**
- Deviates from architecture document (requires ADR to override architecture)
- No native snapshot scheduling (would need custom cron)
- Manual backup/restore processes (copy files, no `k3s` commands)
- Story 8.2 complete rewrite required (6-8 hours of work)
- If HA needed later, would require migration anyway

**When sqlite would be appropriate:**
- Temporary/dev clusters
- Environments where downtime for migration is unacceptable
- No HA requirements ever expected
- Preference for manual backup processes

## Migration Approach

### Official K3s Migration Process

From K3s documentation and GitHub discussions:

```bash
# 1. Edit K3s service
sudo vi /etc/systemd/system/k3s.service
# Add: --cluster-init \ to ExecStart after "server \"

# 2. Apply changes
sudo systemctl daemon-reload
sudo systemctl restart k3s

# K3s automatically:
# - Reads data from sqlite
# - Initializes embedded etcd
# - Migrates all cluster state
# - Starts using etcd as primary datastore
```

**Quote from K3s Maintainer (GitHub #7936):**
> "Add --cluster-init to the server's CLI flags, and restart it. This will convert your datastore from sqlite to etcd. This is the only supported datastore conversion."

### Safety Measures

**Pre-Migration:**
- Full backup of `/var/lib/rancher/k3s/server/` directory
- Verify cluster health (all nodes Ready, all pods Running)
- Document current state and baseline metrics

**During Migration:**
- Monitor K3s logs for migration progress
- Expected downtime: 2-5 minutes (control plane restart)
- All application data on NFS is unaffected

**Post-Migration:**
- Verify etcd datastore active (`k3s etcd-snapshot ls` works)
- Verify all nodes Ready within 5 minutes (NFR2)
- Verify all workloads recovered (no CrashLoopBackOff)
- Verify critical services accessible

### Rollback Procedure

If migration fails:
1. Stop K3s: `sudo systemctl stop k3s`
2. Restore backup: Extract `/var/lib/rancher/k3s/server/` from backup
3. Remove `--cluster-init` flag from service
4. Reload and restart: `sudo systemctl daemon-reload && sudo systemctl start k3s`
5. Verify cluster recovers on sqlite

## Consequences

### Positive

✅ **Architecture Alignment**: Cluster now matches documented design
✅ **Native Snapshots**: Enables K3s built-in snapshot functionality
✅ **Story 8.2 Valid**: All tasks work as designed with Task 0 added
✅ **Future HA Ready**: Can add control plane nodes without re-migration
✅ **Operational Simplicity**: Use K3s native commands instead of custom scripts
✅ **Better Documentation**: K3s etcd operations well-documented upstream

### Negative

⚠️ **One-Time Downtime**: ~5 minutes control plane unavailability during migration
⚠️ **Migration Risk**: Small risk of migration failure (mitigated by backup)
⚠️ **Increased Storage**: etcd uses more disk than sqlite (~2-3x)
⚠️ **Complexity**: etcd slightly more complex than sqlite (minimal for single-server)

### Neutral

- sqlite database remains on disk after migration (K3s keeps as backup)
- Can monitor both databases post-migration for comparison
- Future K3s upgrades will continue using etcd

## Verification

**Migration Success Criteria:**
1. `k3s etcd-snapshot ls` command works (no "disabled" error)
2. etcd directory has database files: `/var/lib/rancher/k3s/server/db/etcd/`
3. All nodes Ready within 5 minutes
4. All pods Running (no CrashLoopBackOff)
5. Critical services accessible (Grafana, Prometheus, PostgreSQL, Ollama, n8n)
6. No data loss in PVCs (all PVCs Bound, data intact)

**Post-Migration Validation:**
- Automatic snapshot schedule active (check logs after 12 hours)
- Can create manual snapshot: `k3s etcd-snapshot save --name test`
- Snapshot files appear in `/var/lib/rancher/k3s/server/db/snapshots/`

## Related Work

- **Story 1.1:** Create K3s Control Plane (original installation without `--cluster-init`)
- **Story 8.1:** Configure K3s Upgrade Procedure (references snapshots for safety)
- **Story 8.2:** Setup Cluster State Backup (primary driver for this migration)
- **Story 8.3:** Validate Cluster Restore Procedure (will test snapshot restore)
- **Architecture.md:** Backup & Recovery Architecture (etcd snapshots assumed)

## References

- [K3s Datastore Documentation](https://docs.k3s.io/datastore)
- [K3s Backup and Restore](https://docs.k3s.io/datastore/backup-restore)
- [K3s etcd-snapshot CLI](https://docs.k3s.io/cli/etcd-snapshot)
- [K3s HA Embedded etcd](https://docs.k3s.io/datastore/ha-embedded)
- [GitHub Discussion #7936: Migrate sqlite to etcd](https://github.com/k3s-io/k3s/discussions/7936)
- [GitHub Discussion #9432: SQLite to etcd migration](https://github.com/k3s-io/k3s/discussions/9432)

## Implementation Details

**Migration Execution:** Story 8.2, Task 0
**Date:** 2026-01-07
**Applied by:** Claude Code
**Downtime Window:** 11:42 CET - 11:43 CET (~1 minute actual downtime)

**Files Modified:**
- `/etc/systemd/system/k3s.service` - Added `--cluster-init` flag

**Migration Log:**
- **Pre-migration backup:** `/tmp/k3s-backup-20260107-124048.tar.gz` (12MB)
- **Migration start time:** 2026-01-07 11:42:35 CET
- **Migration completion time:** 2026-01-07 11:43:00 CET
- **Actual downtime:** ~1 minute (K3s restart + migration)
- **Issues encountered:** None - migration completed successfully

**Migration Results:**
- ✅ etcd datastore active (master node now shows `control-plane,etcd` role)
- ✅ `k3s etcd-snapshot ls` command works (no longer "disabled")
- ✅ etcd database: 135M in `/var/lib/rancher/k3s/server/db/etcd/`
- ✅ All 3 nodes Ready within 1 minute
- ✅ All pods Running (no CrashLoopBackOff)
- ✅ All PVCs Bound
- ✅ Critical services healthy: PostgreSQL, Prometheus, Grafana, Ollama, n8n, Alertmanager, Loki
- ✅ Migration logs showed successful key migration (cert-manager orders, etc.)

**Post-Migration State:**
- Datastore: Embedded etcd (migrated from sqlite)
- sqlite database preserved at `/var/lib/rancher/k3s/server/db/state.db` (K3s keeps for reference)
- Ready for snapshot configuration (Story 8.2 Tasks 1-9)
