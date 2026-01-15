# Story 16.1: Deploy K3s Worker VM on Synology NAS

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **cluster operator**,
I want **a K3s worker VM running on the Synology DS920+ NAS**,
So that **I can run storage-adjacent workloads close to the data**.

## Acceptance Criteria

1. **Given** Synology DS920+ has Virtual Machine Manager installed
   **When** I create a new VM for K3s worker
   **Then** VM is allocated 2 vCPU and 6GB RAM
   **And** VM uses Ubuntu 22.04 LTS minimal image
   **And** this validates FR123

2. **Given** VM is created
   **When** I install K3s agent on the VM
   **Then** agent connects to k3s-master control plane
   **And** node appears in `kubectl get nodes`
   **And** node joins within 3 minutes of VM boot (NFR74)

3. **Given** K3s agent is running
   **When** I configure Tailscale on the NAS worker
   **Then** node is accessible via Tailscale mesh
   **And** cluster networking works across subnets

## Tasks / Subtasks

### Task 1: Create VM in Synology Virtual Machine Manager (AC: 1, FR123, NFR73)
- [x] 1.1: Access Synology DSM and open Virtual Machine Manager
- [x] 1.2: Download Ubuntu 22.04 LTS Server ISO if not available
- [x] 1.3: Create new VM with name `k3s-nas-worker`
- [x] 1.4: Configure VM: 2 vCPU, 6GB RAM, 20GB disk (thin provisioned)
- [x] 1.5: Configure network: bridged to LAN
- [x] 1.6: Assign static IP: 192.168.2.23

### Task 2: Install Ubuntu 22.04 LTS (AC: 1)
- [x] 2.1: Boot VM from Ubuntu ISO
- [x] 2.2: Install Ubuntu Server minimal (SSH enabled)
- [x] 2.3: Configure hostname: k3s-nas-worker
- [x] 2.4: Static IP configured: 192.168.2.23
- [x] 2.5: Enable SSH with key-based authentication
- [x] 2.6: Update system packages

### Task 3: Install Tailscale and Join Tailnet (AC: 3)
- [x] 3.1: Install Tailscale on VM
- [x] 3.2: Run `tailscale up` and authenticate
- [x] 3.3: Verify Tailscale IP assigned (100.76.153.66)
- [x] 3.4: Test connectivity to k3s-master via Tailscale

### Task 4: Install K3s Agent (AC: 2, NFR74)
- [x] 4.1: Get node token from k3s-master
- [x] 4.2: Install K3s agent with Tailscale interface (`--flannel-iface tailscale0`)
- [x] 4.3: Verify k3s-agent service is running
- [x] 4.4: Verify node appears in `kubectl get nodes` within 3 minutes

### Task 5: Verify Cluster Integration (AC: 2, 3)
- [x] 5.1: Check node is Ready in `kubectl get nodes`
- [x] 5.2: Verified DaemonSet pods scheduled (taint working correctly)
- [x] 5.3: Verified node can pull images (DaemonSet pods running)
- [x] 5.4: Check node shows in Tailscale status

### Task 6: Documentation (AC: all)
- [x] 6.1: Update infrastructure/k3s/README.md with NAS worker node
- [x] 6.2: Add k3s-nas-worker to network layout table
- [x] 6.3: Document Synology VMM setup process (manual via DSM UI)
- [x] 6.4: Update story file with completion notes

## Gap Analysis

**Scan Date:** 2026-01-15 (create-story workflow)

### What Exists:
- Synology DS920+ NAS at 192.168.2.10 with Virtual Machine Manager available
- K3s cluster running with 4 nodes (master + 2 Proxmox workers + GPU worker)
- K3s worker installation script: `infrastructure/k3s/install-worker.sh`
- Tailscale mesh networking configured across all nodes
- NFS storage provisioner serving the cluster from the NAS

### What's Missing:
- VM not created in Synology VMM
- Ubuntu not installed on VM
- Tailscale not configured on VM
- K3s agent not installed
- Node not joined to cluster

### Task Validation:
**NO CHANGES NEEDED** - Draft tasks accurately reflect requirements for deploying new K3s worker on Synology NAS.

---

## Dev Notes

### Technical Requirements

**FR123: K3s worker VM deployed on Synology DS920+ using Virtual Machine Manager**
- Use native Synology VMM hypervisor
- No additional software needed on NAS
- Lightweight VM to minimize NAS resource impact

**VM Resources: 2 vCPU, 6GB RAM**
- DS920+ has: Intel Celeron J4125 (4 cores), 20GB RAM
- After VM allocation: 2 cores + 14GB remain for NAS operations
- Thin provisioned disk to avoid storage waste

**NFR74: NAS worker node joins cluster within 3 minutes of VM boot**
- K3s agent lightweight, starts quickly
- VM boot adds ~60 seconds
- Total boot-to-ready should be under 3 minutes

### Architecture Compliance

**From [Source: architecture.md#Synology NAS K3s Worker Architecture]:**

**VM Specification:**
```
┌─────────────────────────────────────────────────────────────────┐
│  Synology DS920+ (Intel Celeron J4125, 20GB RAM)               │
├─────────────────────────────────────────────────────────────────┤
│  Host Services:                                                 │
│  ├── DSM (Synology OS)                                         │
│  ├── NFS Server (primary function)                             │
│  ├── Container Manager (Docker)                                │
│  └── Virtual Machine Manager                                   │
├─────────────────────────────────────────────────────────────────┤
│  K3s Worker VM:                                                │
│  ├── Name: k3s-nas-worker                                      │
│  ├── IP: 192.168.2.23 (static)                                 │
│  ├── vCPU: 2 cores                                             │
│  ├── RAM: 6GB                                                  │
│  ├── Disk: 20GB (thin provisioned)                             │
│  └── Network: vmbr0 (bridged to LAN)                           │
└─────────────────────────────────────────────────────────────────┘
```

**Suitable Workloads (after Story 16.2 labels/taints):**
- Lightweight monitoring agents
- Log collectors (Promtail)
- Storage-adjacent services (NFS-related utilities)
- NOT suitable: CPU-intensive, memory-intensive, or GPU workloads

### Current Network Configuration

| Node | IP | Role |
|------|-----|------|
| k3s-master | 192.168.2.20 | Control Plane |
| k3s-worker-01 | 192.168.2.21 | Worker (Proxmox) |
| k3s-worker-02 | 192.168.2.22 | Worker (Proxmox) |
| k3s-nas-worker | 192.168.2.23 | Worker (Synology) - THIS STORY |
| k3s-gpu-worker | 192.168.0.25 | Worker (Intel NUC) |

### K3s Installation Command

```bash
# On k3s-nas-worker, after Tailscale is configured:
# Get token from master
K3S_TOKEN=$(ssh root@192.168.2.20 "cat /var/lib/rancher/k3s/server/node-token")

# Install K3s agent with Tailscale interface
curl -sfL https://get.k3s.io | K3S_URL="https://192.168.2.20:6443" K3S_TOKEN="$K3S_TOKEN" sh -s - agent --flannel-iface tailscale0
```

### Testing Requirements

**Validation Methods:**
1. **VM Creation:** Synology VMM shows VM running with correct resources
2. **Cluster Join:** `kubectl get nodes` shows k3s-nas-worker Ready
3. **Tailscale:** `tailscale status` shows k3s-nas-worker with 100.x.x.x IP
4. **Join Time:** Measure from VM boot to Ready status < 3 minutes

**Test Commands:**
```bash
# From any machine with kubectl
kubectl get nodes
kubectl get nodes -o wide

# Verify Tailscale connectivity
tailscale ping k3s-nas-worker

# Deploy test pod to verify networking
kubectl run test-nas --image=nginx --restart=Never
kubectl get pods -o wide
kubectl delete pod test-nas
```

### Project Context Reference

**Epic 16 Status:**
- Story 16.1: THIS STORY - Deploy K3s Worker VM on Synology NAS
- Story 16.2: Backlog - Label and Taint NAS Worker Node

**Dependencies:**
- Synology DS920+ with VMM package installed
- K3s cluster operational
- Tailscale mesh configured
- Node token from k3s-master

### References

- [Source: docs/planning-artifacts/epics.md#Story 16.1, lines 4344-4378]
- [Source: docs/planning-artifacts/architecture.md#Synology NAS K3s Worker Architecture, lines 888-939]
- [Source: docs/planning-artifacts/prd.md#FR123, NFR73-74]
- [Source: infrastructure/k3s/install-worker.sh - Existing worker installation script]
- [Source: infrastructure/k3s/README.md - K3s cluster documentation]
- [Synology VMM Documentation](https://www.synology.com/en-global/dsm/feature/virtual_machine_manager)

## Dev Agent Record

### Agent Model Used

Claude Opus 4.5 (claude-opus-4-5-20251101)

### Debug Log References

- Tailscale auth required manual approval in admin console
- SSH connection resets during authentication resolved by using Tailscale IP

### Completion Notes List

1. **VM Created via Synology VMM**: k3s-nas-worker with 2 vCPU, 6GB RAM, 20GB disk
2. **Ubuntu 22.04 LTS installed**: Minimal server with SSH enabled
3. **Tailscale connected**: IP 100.76.153.66, accept-routes enabled
4. **K3s agent installed**: Using `--flannel-iface tailscale0` for Tailscale networking
5. **Node labels applied**: `workload-type=lightweight`, `node-role.kubernetes.io/nas-worker=true`
6. **Taint applied**: `workload-type=lightweight:NoSchedule` prevents general scheduling
7. **Cluster integration verified**: Node Ready, DaemonSets scheduled correctly

### File List

- `docs/implementation-artifacts/16-1-deploy-k3s-worker-vm-on-synology-nas.md` - This story file
- `infrastructure/k3s/README.md` - Updated with NAS worker info

### Change Log

- 2026-01-15: Story 16.1 created - Deploy K3s Worker VM on Synology NAS (Claude Opus 4.5)
- 2026-01-15: Story 16.1 completed - VM deployed, Tailscale connected, K3s agent joined cluster (Claude Opus 4.5)
