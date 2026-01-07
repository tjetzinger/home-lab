# Story 1.5: Document Node Removal Procedure

Status: done
Completed: 2026-01-05

## Story

As a **cluster operator**,
I want **to safely remove a worker node without data loss**,
so that **I can perform maintenance or replace failed nodes**.

## Acceptance Criteria

1. **AC1: Node Drain**
   - **Given** cluster has 3 nodes with pods running on all workers
   - **When** I run `kubectl drain k3s-worker-02 --ignore-daemonsets --delete-emptydir-data`
   - **Then** all non-DaemonSet pods are evicted from the node
   - **And** pods reschedule to k3s-worker-01

2. **AC2: Node Deletion**
   - **Given** node is drained
   - **When** I run `kubectl delete node k3s-worker-02`
   - **Then** the node is removed from cluster
   - **And** `kubectl get nodes` shows only 2 nodes

3. **AC3: Application Health**
   - **Given** node removal is complete
   - **When** I check application health
   - **Then** all applications remain accessible
   - **And** no data loss has occurred (NFR3)

4. **AC4: Documentation**
   - **Given** the procedure is validated
   - **When** I document it in `docs/runbooks/node-removal.md`
   - **Then** the runbook includes drain, delete, and rejoin steps
   - **And** recovery procedure is documented

## Tasks / Subtasks

⚠️ **DRAFT TASKS** - Generated from requirements analysis. Will be validated and refined against actual codebase when dev-story runs.

- [x] Task 1: Prepare Test Workload (AC: #1, #3)
  - [x] 1.1: Deploy a test Deployment with 3 replicas to verify pod distribution
  - [x] 1.2: Verify pods are running on k3s-worker-02
  - [x] 1.3: Create a test PVC with data (if NFS provisioner available, otherwise skip) - SKIPPED (NFS not available)

- [x] Task 2: Execute and Document Drain Procedure (AC: #1)
  - [x] 2.1: Run `kubectl drain k3s-worker-02 --ignore-daemonsets --delete-emptydir-data`
  - [x] 2.2: Document command output and any warnings
  - [x] 2.3: Verify pods rescheduled to k3s-worker-01 or k3s-master
  - [x] 2.4: Document expected behavior for DaemonSets (remain, not evicted)

- [x] Task 3: Execute and Document Node Deletion (AC: #2)
  - [x] 3.1: Run `kubectl delete node k3s-worker-02`
  - [x] 3.2: Verify node is removed with `kubectl get nodes`
  - [x] 3.3: Document what happens to the LXC container (still running but disconnected)

- [x] Task 4: Validate Application Health (AC: #3)
  - [x] 4.1: Verify test Deployment pods are still Running (on remaining nodes)
  - [x] 4.2: Verify test data in PVC is still accessible (if applicable) - SKIPPED (NFS not available)
  - [x] 4.3: Document NFR3 compliance (no service outage, no data loss)

- [x] Task 5: Document Node Rejoin Procedure (AC: #4)
  - [x] 5.1: Stop k3s-agent on the removed node (if still running) - NOT NEEDED (agent rejoined on restart)
  - [x] 5.2: Rejoin node using install-worker.sh or direct K3s agent command
  - [x] 5.3: Verify node shows Ready in `kubectl get nodes`
  - [x] 5.4: Uncordon node if needed: `kubectl uncordon k3s-worker-02` - Already uncordoned

- [x] Task 6: Create Runbook Documentation (AC: #4)
  - [x] 6.1: Create `docs/runbooks/` directory if it doesn't exist
  - [x] 6.2: Create `docs/runbooks/node-removal.md` with complete procedure
  - [x] 6.3: Include: pre-checks, drain, delete, rejoin, verification, troubleshooting
  - [x] 6.4: Add rollback/recovery section

## Gap Analysis

**Scan Date:** 2026-01-05
**Scan Result:** ✅ Draft tasks validated - minor adjustment

**What Exists:**
- K3s cluster running with 3 nodes all Ready (v1.34.3+k3s1)
- `infrastructure/k3s/install-worker.sh` - Worker join script for rejoining
- `infrastructure/k3s/kubeconfig-setup.sh` - Remote access setup
- kubectl available locally and working

**What's Missing:**
- `docs/runbooks/` directory (will create)
- `docs/runbooks/node-removal.md` runbook (will create)
- NFS provisioner not deployed (Epic 2 backlog) - Task 1.3 will be skipped

**Task Changes:** Task 1.3 skipped (NFS not available)

---

## Dev Notes

### Technical Specifications

**Drain Command:**
```bash
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data
```

**Delete Command:**
```bash
kubectl delete node <node-name>
```

**Rejoin Command (from worker node):**
```bash
curl -sfL https://get.k3s.io | K3S_URL=https://192.168.2.20:6443 K3S_TOKEN=<token> sh -
```

### Architecture Requirements

**From [Source: epics.md#FR3]:**
- Operator can remove worker nodes from the cluster without data loss

**From [Source: epics.md#NFR3]:**
- Worker node failure does not cause service outage (pods reschedule)

**From [Source: architecture.md#Node Topology]:**
| Node | Role | IP |
|------|------|-----|
| k3s-master | Control plane | 192.168.2.20 |
| k3s-worker-01 | General compute | 192.168.2.21 |
| k3s-worker-02 | General compute | 192.168.2.22 |

### Previous Story Intelligence (Story 1.4)

**Learnings to Apply:**
1. **kubectl is now available locally** - Can run commands directly
2. **Tailscale routing works** - Remote access validated
3. **kubeconfig-setup.sh exists** - For reference on cluster access
4. **Cluster state:** 3 nodes Ready, v1.34.3+k3s1

**Key Files Created in Previous Stories:**
- `infrastructure/k3s/install-master.sh` - Master installation
- `infrastructure/k3s/install-worker.sh` - Worker join script
- `infrastructure/k3s/kubeconfig-setup.sh` - Remote access setup
- `infrastructure/k3s/lxc-k3s-config.conf` - LXC configuration

### Project Structure Notes

**Files to Create:**
```
docs/runbooks/
└── node-removal.md     # NEW - Node removal runbook
```

**Existing Infrastructure:**
- LXC containers on Proxmox (VMIDs: 100, 102, 103)
- K3s v1.34.3+k3s1 on all nodes
- Node token stored on master at `/var/lib/rancher/k3s/server/node-token`

### Testing Approach

**Pre-test Setup:**
```bash
# Deploy test workload
kubectl create deployment test-drain --image=nginx --replicas=3

# Verify distribution
kubectl get pods -o wide
```

**Drain Test:**
```bash
# Drain the node
kubectl drain k3s-worker-02 --ignore-daemonsets --delete-emptydir-data

# Verify eviction
kubectl get pods -o wide
kubectl get nodes
```

**Delete Test:**
```bash
# Delete node from cluster
kubectl delete node k3s-worker-02

# Verify removal
kubectl get nodes
```

**Rejoin Test:**
```bash
# On the worker node (via pct exec or SSH)
# Get token from master
TOKEN=$(ssh root@192.168.2.20 cat /var/lib/rancher/k3s/server/node-token)

# Rejoin cluster
curl -sfL https://get.k3s.io | K3S_URL=https://192.168.2.20:6443 K3S_TOKEN=$TOKEN sh -

# Verify
kubectl get nodes
```

### Security Considerations

- Drain operation is safe and graceful
- Delete operation does not affect the actual VM/container
- Rejoin requires the cluster token (keep secure)
- Consider RBAC if multiple operators in future

### References

- [Source: epics.md#Story 1.5]
- [Source: epics.md#FR3]
- [Source: epics.md#NFR3]
- [Source: architecture.md#Node Topology]
- [Source: 1-4-configure-remote-kubectl-access.md#Completion Notes]
- [K3s Documentation: Node Management](https://docs.k3s.io/reference/server-config)
- [Kubernetes: Safely Drain a Node](https://kubernetes.io/docs/tasks/administer-cluster/safely-drain-node/)

## Dev Agent Record

### Agent Model Used

Claude Opus 4.5 (claude-opus-4-5-20251101)

### Debug Log References

- Node drain/delete/rejoin cycle validated via kubectl commands
- Proxmox MCP used for k3s-agent restart on VMID 103

### Completion Notes List

**Completed: 2026-01-05**

1. **AC1 Satisfied:** Node Drain
   - `kubectl drain k3s-worker-02 --ignore-daemonsets --delete-emptydir-data` executed successfully
   - 1 pod evicted from test-drain deployment
   - DaemonSet pod (svclb-traefik) correctly ignored with warning
   - Pod rescheduled to k3s-worker-01

2. **AC2 Satisfied:** Node Deletion
   - `kubectl delete node k3s-worker-02` removed node from cluster
   - Verified only 2 nodes (k3s-master, k3s-worker-01) remained
   - LXC container (VMID 103) continued running but disconnected from cluster

3. **AC3 Satisfied:** Application Health
   - All 3 test-drain pods remained Running after node removal
   - Pods distributed across remaining nodes
   - NFR3 compliance: No service outage, no data loss

4. **AC4 Satisfied:** Documentation
   - Created `docs/runbooks/node-removal.md` with complete procedure
   - Includes: prerequisites, drain procedure, delete procedure, rejoin procedure
   - Includes: recovery/troubleshooting scenarios, validation checklists

5. **Node Rejoin Validated:**
   - k3s-agent restart via `pct exec 103 -- systemctl restart k3s-agent`
   - Node rejoined cluster automatically (age: 26s after restart)
   - Node already uncordoned (fresh join doesn't require uncordon)

**Key Findings:**
- K3s agent restart is sufficient to rejoin after node deletion (no reinstall needed)
- DaemonSets are correctly ignored during drain with --ignore-daemonsets flag
- LXC container remains operational even after Kubernetes node deletion

### File List

_Files created/modified during implementation:_
- `docs/runbooks/node-removal.md` - NEW - Node removal runbook with full procedure
