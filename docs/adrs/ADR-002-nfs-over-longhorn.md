# ADR-002: External NFS Storage over Longhorn Distributed Storage

**Status:** Accepted
**Date:** 2026-01-07
**Decision Makers:** Tom, Claude (AI Assistant)

## Context

The home-lab K3s cluster requires persistent storage for stateful workloads (PostgreSQL, Prometheus, Loki, Ollama model storage). Kubernetes StatefulSets need dynamic PersistentVolume provisioning with reliable data persistence and backup capabilities.

The home-lab architecture constraints:
- 3-node K3s cluster (k3s-master, k3s-worker-01, k3s-worker-02)
- Existing Synology DS920+ NAS with 8.8TB available storage
- Weekend-based phased implementation approach
- Single operator (learning-first goals)
- NFR requirement: 95% uptime with 5-minute recovery time

## Decision Drivers

- **Existing hardware** - Synology DS920+ already available with ample storage (8.8TB)
- **Cluster size** - 3 nodes meets minimum for distributed storage but adds complexity
- **Operational simplicity** - Single operator needs manageable infrastructure
- **Backup/snapshot capabilities** - Synology provides built-in hourly snapshots
- **Learning value** - Understanding storage trade-offs is more valuable than running complex distributed storage
- **Time constraints** - Weekend-based implementation favors simpler solutions
- **Cost efficiency** - Leverage existing investment rather than adding complexity

## Considered Options

### Option 1: Longhorn Distributed Storage

**Pros:**
- Kubernetes-native distributed block storage
- Automatic replication across nodes (N-way mirroring)
- Built-in snapshots and backups
- No external dependencies
- Active CNCF project with good community support

**Cons:**
- Requires 3+ nodes minimum (we have exactly 3)
- Higher resource overhead (storage replicas, controller pods)
- More complex troubleshooting (distributed consensus, replica sync)
- Learning curve for managing distributed storage
- Requires dedicated disks or careful filesystem management

### Option 2: Rook-Ceph Distributed Storage

**Pros:**
- Enterprise-grade distributed storage
- Supports block, file, and object storage
- Excellent scalability and performance
- Strong community and production track record

**Cons:**
- **Significant operational complexity** (Ceph cluster management)
- High resource overhead (monitors, managers, OSDs)
- Requires 3+ nodes with dedicated disks
- Steep learning curve for single operator
- Overkill for home lab scale

### Option 3: Local Path Provisioner

**Pros:**
- Extremely simple (local disk on each node)
- Low overhead
- Fast I/O performance
- Built into K3s by default

**Cons:**
- **No data persistence if node fails** - data tied to specific node
- No backups or snapshots
- StatefulSets tied to specific nodes (pod can't reschedule to different node)
- Not suitable for production-like workloads
- Defeats purpose of learning proper storage patterns

### Option 4: External NFS Storage via Synology (Selected)

**Pros:**
- **Leverages existing hardware** - Synology DS920+ already available
- Simple architecture - single storage backend
- **Built-in redundancy** - Synology handles RAID, snapshots (hourly)
- Easy troubleshooting - centralized storage, familiar NFS protocols
- Production-ready - `nfs-subdir-external-provisioner` is stable, Helm-based
- Dynamic provisioning - automatic PV creation from PVC requests
- Cross-node portability - pods can reschedule to any node

**Cons:**
- Single point of failure (NAS downtime = storage unavailable)
- Network dependency (1Gbps - sufficient for home lab)
- NFS performance limitations vs block storage
- External dependency (not self-contained within cluster)

## Decision

**Use external NFS storage from Synology DS920+ via `nfs-subdir-external-provisioner`**

Implementation details:
- **NFS Server:** Synology DS920+ at 192.168.2.10
- **NFS Export:** `/volume1/k8s-data/` (8.8TB available)
- **Provisioner:** `nfs-subdir-external-provisioner` Helm chart
- **StorageClass:** `nfs-client` (set as default)
- **Reclaim Policy:** Delete (clean up on PVC deletion)
- **Access Mode:** ReadWriteMany (multi-pod access where needed)

## Consequences

### Positive

- **Immediate availability** - No new infrastructure required
- **Operational simplicity** - Familiar NFS protocols, Synology admin UI
- **Automatic backups** - Synology hourly snapshots provide recovery points
- **Resource efficiency** - No storage replicas consuming cluster resources
- **Proven reliability** - Synology RAID redundancy + snapshots
- **Fast implementation** - Helm chart deployment takes minutes
- **Debugging ease** - Can inspect NFS mounts, verify data on NAS directly

### Negative

- **Single point of failure** - NAS downtime impacts all stateful workloads
- **Network bottleneck** - 1Gbps network limits I/O throughput (acceptable for home lab)
- **External dependency** - Cluster not self-sufficient for storage
- **NFS limitations** - No block storage features (thin provisioning, snapshots at K8s level)
- **Learning gap** - Don't gain experience with distributed storage systems

### Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Synology NAS failure | Synology RAID 1 redundancy; UPS power protection; documented recovery process |
| Network connectivity issues | Synology on same subnet; static IPs; documented NFS mount troubleshooting |
| NFS performance bottlenecks | Acceptable for home lab workloads; monitor via Prometheus; can migrate to Longhorn in Phase 2 if needed |
| Data loss from accidental deletion | Synology hourly snapshots (7-day retention); documented restore procedure |
| Storage exhaustion (8.8TB limit) | Monitor usage via Grafana; 8.8TB sufficient for Phase 1 scope; can expand Synology storage |

## Implementation Notes

**Helm Deployment:**
```bash
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
helm upgrade --install nfs-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
  -f infrastructure/nfs/values-homelab.yaml \
  -n infra --create-namespace
```

**Values Configuration:**
```yaml
nfs:
  server: 192.168.2.10
  path: /volume1/k8s-data
storageClass:
  name: nfs-client
  defaultClass: true
  reclaimPolicy: Delete
```

**Validation:**
```bash
kubectl get storageclass
kubectl get pods -n infra | grep nfs-provisioner
```

**Directory Structure on Synology:**
```
/volume1/k8s-data/
├── {namespace}-{pvc-name}-{pv-id}/
│   ├── monitoring-prometheus-data/
│   ├── monitoring-loki-data/
│   ├── data-postgres-data/
│   └── ml-ollama-models/
```

**Future Migration Path:**
If distributed storage becomes necessary (Phase 2+):
1. Deploy Longhorn alongside NFS
2. Create new StorageClass `longhorn`
3. Migrate workloads one at a time (backup, recreate with new SC, restore)
4. Decommission NFS provisioner after validation

## References

- [Architecture Decision: Storage Architecture](../planning-artifacts/architecture.md#storage-architecture)
- [Synology DS920+ Specifications](https://www.synology.com/en-us/products/DS920+)
- [nfs-subdir-external-provisioner Helm Chart](https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner)
- [K8s Storage Classes Documentation](https://kubernetes.io/docs/concepts/storage/storage-classes/)
- [Story 2.1: Deploy NFS Storage Provisioner](../implementation-artifacts/sprint-status.yaml)
