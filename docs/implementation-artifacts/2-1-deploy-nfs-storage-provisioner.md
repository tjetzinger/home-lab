# Story 2.1: Deploy NFS Storage Provisioner

Status: done
Completed: 2026-01-05

## Story

As a **cluster operator**,
I want **to deploy an NFS provisioner that creates PersistentVolumes automatically**,
so that **applications can request storage without manual PV creation**.

## Acceptance Criteria

1. **AC1: NFS Connectivity**
   - **Given** Synology NFS share is configured at 192.168.2.2:/volume1/k8s-data
   - **When** I verify NFS connectivity from a worker node with `showmount -e 192.168.2.2`
   - **Then** the k8s-data export is visible
   - **And** worker nodes are in the allowed hosts list

2. **AC2: Provisioner Deployment**
   - **Given** NFS is accessible from all cluster nodes
   - **When** I deploy nfs-subdir-external-provisioner via Helm with `values-homelab.yaml`
   - **Then** the provisioner pod starts in the `infra` namespace
   - **And** pod status shows Running

3. **AC3: StorageClass Configuration**
   - **Given** the provisioner is running
   - **When** I check for StorageClass with `kubectl get storageclass`
   - **Then** `nfs-client` StorageClass exists
   - **And** it is marked as the default StorageClass

4. **AC4: StorageClass Validation**
   - **Given** the StorageClass is configured
   - **When** I inspect StorageClass details
   - **Then** reclaim policy is set to Delete
   - **And** provisioner is set to `cluster.local/nfs-subdir-external-provisioner`

## Tasks / Subtasks

- [x] Task 1: Verify NFS Share Configuration on Synology (AC: #1)
  - [x] 1.1: Verify NFS share exists at 192.168.2.2:/volume1/k8s-data
  - [x] 1.2: Verify cluster node IPs (192.168.2.20-22) are in allowed hosts
  - [x] 1.3: Test NFS connectivity from k3s-worker-01 with `showmount -e 192.168.2.2`
  - [x] 1.4: Test NFS mount capability from worker node (mount, write, unmount)

- [x] Task 2: Create Infrastructure Directory Structure (AC: #2)
  - [x] 2.1: Create `infrastructure/nfs/` directory if it doesn't exist
  - [x] 2.2: Create `infrastructure/nfs/values-homelab.yaml` with NFS provisioner config
  - [x] 2.3: Document NFS server details in values file comments

- [x] Task 3: Deploy NFS Provisioner via Helm (AC: #2)
  - [x] 3.1: Create `infra` namespace if it doesn't exist
  - [x] 3.2: Add NFS provisioner Helm repo: `nfs-subdir-external-provisioner`
  - [x] 3.3: Deploy provisioner with `helm install nfs-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner -f values-homelab.yaml -n infra`
  - [x] 3.4: Verify pod is Running: `kubectl get pods -n infra`

- [x] Task 4: Configure and Validate StorageClass (AC: #3, #4)
  - [x] 4.1: Verify StorageClass was created by Helm chart
  - [x] 4.2: Mark nfs-client as default StorageClass if not already
  - [x] 4.3: Validate reclaim policy is set to Delete
  - [x] 4.4: Validate provisioner name is correct

- [x] Task 5: Update Documentation (AC: #2, #3, #4)
  - [x] 5.1: Create/update `infrastructure/nfs/README.md` with setup instructions
  - [x] 5.2: Document NFS server configuration requirements
  - [x] 5.3: Document troubleshooting steps for common NFS issues

## Gap Analysis

**Scan Date:** 2026-01-05
**Scan Result:** ✅ Draft tasks validated - no changes needed

**What Exists:**
- `infrastructure/` directory exists with `k3s/` subdirectory
- K3s cluster running: 3 nodes Ready (v1.34.3+k3s1)
- `local-path` StorageClass exists (K3s default, rancher.io/local-path)
- kubectl available and working locally

**What's Missing:**
- `infrastructure/nfs/` directory (will create)
- `infrastructure/nfs/values-homelab.yaml` (will create)
- `infra` namespace (will create)
- Helm repos not configured (will add nfs-subdir-external-provisioner repo)
- `nfs-client` StorageClass (will be created by Helm chart)

**Task Changes:** None - draft tasks accurate

---

## Dev Notes

### Technical Specifications

**NFS Server Details:**
- Server: Synology DS920+ (192.168.2.2)
- Export: `/volume1/k8s-data`
- Capacity: 8.8TB RAID1

**Helm Chart:**
- Chart: nfs-subdir-external-provisioner/nfs-subdir-external-provisioner
- Namespace: infra
- Values file: `infrastructure/nfs/values-homelab.yaml`

**StorageClass Configuration:**
```yaml
storageClass:
  name: nfs-client
  defaultClass: true
  reclaimPolicy: Delete
  archiveOnDelete: false
```

### Architecture Requirements

**From [Source: architecture.md#Storage Architecture]:**
| Decision | Choice | Rationale |
|----------|--------|-----------|
| NFS Provisioner | nfs-subdir-external-provisioner | Simple, Helm-based, dynamic PVC provisioning |
| StorageClass | nfs-client (default) | Dynamic provisioning from Synology |
| Reclaim Policy | Delete | Clean up on PVC deletion |

**From [Source: architecture.md#Namespace Boundaries]:**
| Namespace | Components | Purpose |
|-----------|------------|---------|
| `infra` | MetalLB, cert-manager, NFS provisioner | Core infrastructure |

**From [Source: epics.md#Epic 2]:**
- FR14: Operator can provision persistent volumes from NFS storage
- FR15: Operator can create PersistentVolumeClaims for applications
- FR16: System provisions storage dynamically via StorageClass

### Previous Story Intelligence (Story 1.5)

**Learnings to Apply:**
1. **kubectl is now available locally** - Can run commands directly
2. **Tailscale routing works** - Remote access validated
3. **Cluster state:** 3 nodes Ready, v1.34.3+k3s1
4. **Proxmox MCP available** - Can exec commands into containers

**Current Cluster State:**
| Node | IP | VMID | Status | Version |
|------|-----|------|--------|---------|
| k3s-master | 192.168.2.20 | 100 | Ready | v1.34.3+k3s1 |
| k3s-worker-01 | 192.168.2.21 | 102 | Ready | v1.34.3+k3s1 |
| k3s-worker-02 | 192.168.2.22 | 103 | Ready | v1.34.3+k3s1 |

### Project Structure Notes

**Files to Create:**
```
infrastructure/nfs/
├── values-homelab.yaml     # NFS provisioner Helm values
├── storageclass.yaml       # Optional: explicit StorageClass if needed
└── README.md               # Setup documentation
```

**Alignment with Architecture:**
- Placing in `infrastructure/nfs/` per architecture.md structure
- Using `values-homelab.yaml` naming pattern per convention
- Deploying to `infra` namespace per namespace strategy

### Testing Approach

**NFS Connectivity Test (from worker node):**
```bash
# Via Proxmox MCP
pct exec 102 -- apt install -y nfs-common
pct exec 102 -- showmount -e 192.168.2.2
pct exec 102 -- mount -t nfs 192.168.2.2:/volume1/k8s-data /mnt
pct exec 102 -- touch /mnt/test-file
pct exec 102 -- rm /mnt/test-file
pct exec 102 -- umount /mnt
```

**Provisioner Deployment Test:**
```bash
kubectl get pods -n infra
kubectl get storageclass
kubectl describe storageclass nfs-client
```

### Security Considerations

- NFS share should only allow cluster node IPs (192.168.2.20-22)
- No sensitive data should be exposed via NFS permissions
- Synology user for NFS should have minimal required permissions

### Dependencies

- **Upstream:** Story 1.x (K3s cluster) - COMPLETED
- **Downstream:** Stories 2.2, 2.3, 2.4 (PVC testing, health verification, backup)
- **External:** Synology NFS share must be pre-configured

### References

- [Source: epics.md#Story 2.1]
- [Source: epics.md#FR14, FR15, FR16]
- [Source: architecture.md#Storage Architecture]
- [Source: architecture.md#Project Structure]
- [Source: 1-5-document-node-removal-procedure.md#Completion Notes]
- [NFS Provisioner Helm Chart](https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner)
- [Synology NFS Configuration](https://kb.synology.com/en-us/DSM/tutorial/How_to_access_files_on_Synology_NAS_within_the_local_network_NFS)

## Dev Agent Record

### Agent Model Used

Claude Opus 4.5 (claude-opus-4-5-20251101)

### Debug Log References

N/A - No debug logs required

### Completion Notes List

1. **NFS Service Setup**: Initial NFS connectivity test failed - Synology NFS service was not enabled. Researched Synology NFS setup via Exa and provided step-by-step guide. User configured NFS via DSM Control Panel.

2. **Helm Installation**: Helm was not installed on the local machine. Installed via `sudo pacman -S helm`.

3. **Worker Node NFS Requirements**: NFS provisioner pod stuck in ContainerCreating due to missing `nfs-common` package on worker nodes. Installed on all three nodes (master, worker-01, worker-02).

4. **SSH Access Issue**: k3s-worker-02 (192.168.2.22) SSH connection refused. Root cause: SSH service not started and `PermitRootLogin` set to `prohibit-password`. Fixed via Proxmox host (`ssh pve "pct exec 103 -- ..."`).

5. **Dual Default StorageClass**: After deployment, both `local-path` and `nfs-client` were marked as default. Patched `local-path` to remove default annotation: `kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'`

6. **Final State**:
   - NFS provisioner running in `infra` namespace
   - `nfs-client` StorageClass is sole default
   - Reclaim policy: Delete
   - Provisioner: `cluster.local/nfs-subdir-external-provisioner`

### File List

_Files created/modified during implementation:_
- `infrastructure/nfs/values-homelab.yaml` - NEW - Helm values for NFS provisioner
- `infrastructure/nfs/README.md` - NEW - Comprehensive NFS setup documentation with troubleshooting
- `docs/implementation-artifacts/2-1-deploy-nfs-storage-provisioner.md` - MODIFIED - Story status updated to review
