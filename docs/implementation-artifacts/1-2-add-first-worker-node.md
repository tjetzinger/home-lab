# Story 1.2: Add First Worker Node

Status: done
Completed: 2026-01-05

## Story

As a **cluster operator**,
I want **to add a worker node to the cluster**,
so that **workloads can be scheduled on dedicated compute resources**.

## Acceptance Criteria

1. **AC1: Worker Container Creation**
   - **Given** Proxmox host is running with available resources
   - **When** I create an LXC container with 4 vCPU, 8GB RAM, 50GB disk at 192.168.2.21
   - **Then** the container boots successfully with Ubuntu 22.04
   - **And** SSH access is available with key-based authentication

2. **AC2: K3s Agent Installation**
   - **Given** the worker container is running and can reach the control plane (192.168.2.20:6443)
   - **When** I run the K3s agent installation with the server URL and node token
   - **Then** the agent joins the cluster successfully
   - **And** `kubectl get nodes` shows k3s-worker-01 as Ready

3. **AC3: Workload Scheduling**
   - **Given** both master and worker nodes are Ready
   - **When** I deploy a test pod without node selector
   - **Then** the pod schedules to the worker node (not master)
   - **And** the pod reaches Running state

## Tasks / Subtasks

- [x] Task 1: Create LXC Container in Proxmox (AC: #1)
  - [x] 1.1: Create container VMID 102 via Proxmox MCP with Ubuntu 22.04 template
  - [x] 1.2: Configure: 4 vCPU, 8GB RAM, 50GB disk, features nesting=1,keyctl=1,fuse=1
  - [x] 1.3: Set hostname: `k3s-worker-01`, IP: 192.168.2.21/24, gateway: 192.168.2.1
  - [x] 1.4: Apply K3s LXC configuration from `lxc-k3s-config.conf` via Proxmox host
  - [x] 1.5: Configure SSH with key-based auth (copy authorized_keys, configure sshd_config.d)
  - [x] 1.6: Start container and verify SSH access

- [x] Task 2: Install K3s Agent (AC: #2)
  - [x] 2.1: Verify connectivity to control plane: `curl -k https://192.168.2.20:6443`
  - [x] 2.2: Install curl if not present
  - [x] 2.3: Run K3s agent installation with server URL and token
  - [x] 2.4: Verify k3s-agent service is running: `systemctl status k3s-agent`
  - [x] 2.5: Verify node appears in `kubectl get nodes` from master

- [x] Task 3: Validate Workload Scheduling (AC: #3)
  - [x] 3.1: Verify both nodes show Ready status
  - [x] 3.2: Deploy test pod (nginx) without nodeSelector
  - [x] 3.3: Verify pod scheduled to worker node
  - [x] 3.4: Clean up test pod

- [x] Task 4: Create install-worker.sh script
  - [x] 4.1: Create reusable worker installation script
  - [x] 4.2: Update infrastructure/k3s/README.md with worker instructions

## Gap Analysis

**Scan Date:** 2026-01-05
**Scan Result:** ✅ Draft tasks validated - no changes needed

**What Exists:**
- `infrastructure/k3s/lxc-k3s-config.conf` - LXC config template ready
- `infrastructure/k3s/README.md` - Already has worker placeholder
- k3s-master (VMID 100) running at 192.168.2.20
- Ubuntu 22.04 LXC template available
- Node token captured from Story 1.1

**What's Missing:**
- k3s-worker-01 container (VMID 102)
- K3s agent installation on worker
- `install-worker.sh` script

**Task Changes:** None - draft tasks accurate

---

## Dev Notes

### Technical Specifications

**Container Configuration:**
```
VMID: 102 (next available)
Hostname: k3s-worker-01
Template: local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst
vCPU: 4
RAM: 8GB (8192 MB)
Disk: 50GB
Storage: local-lvm
IP: 192.168.2.21/24
Gateway: 192.168.2.1
Bridge: vmbr0
```

**K3s Agent Installation Command:**
```bash
curl -sfL https://get.k3s.io | K3S_URL=https://192.168.2.20:6443 K3S_TOKEN=<token> sh -
```

**Node Token (from master):**
```
K1021a064bc9bc62ec3255a3dc70d42e588e8b24c2a8749ec20b906a988914acbf5::server:eee546808ed3af09733c2e606a2cbd48
```

### LXC Configuration Required

Apply after container creation (same as master per ADR-001):
```
# In /etc/pve/lxc/102.conf
lxc.mount.entry: /dev/kmsg dev/kmsg none bind,rw,optional,create=file
lxc.apparmor.profile: unconfined
lxc.cap.drop:
lxc.cgroup2.devices.allow: a
lxc.mount.auto: proc:rw sys:rw
```

Or use: `cat infrastructure/k3s/lxc-k3s-config.conf >> /etc/pve/lxc/102.conf`

### Previous Story Intelligence (Story 1.1)

**Learnings to Apply:**
1. **LXC over VM** - Use LXC container for consistency and resource efficiency
2. **SSH setup required** - Ubuntu LXC template needs SSH configuration:
   - Create `/run/sshd` directory
   - Copy authorized_keys for root
   - Configure `/etc/ssh/sshd_config.d/99-security.conf`
3. **Proxmox MCP works well** - Use for container creation and management
4. **K3s needs full LXC config** - Without proper config, kubelet fails with permission errors

**Files Created in 1.1:**
- `infrastructure/k3s/lxc-k3s-config.conf` - LXC config template
- `infrastructure/k3s/README.md` - Updated with LXC instructions
- `docs/adrs/ADR-001-lxc-containers-for-k3s.md` - Architecture decision

### Project Structure Notes

**Files to Create/Update:**
```
infrastructure/k3s/
├── install-worker.sh     # NEW - Worker installation script
└── README.md             # UPDATE - Add worker join instructions
```

### Testing Approach

**Test Pod for AC3:**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-worker-scheduling
spec:
  containers:
  - name: nginx
    image: nginx:alpine
```

Verify with: `kubectl get pods -o wide` - should show worker node in NODE column.

### References

- [Source: epics.md#Story 1.2]
- [Source: architecture.md#Cluster Layout]
- [Source: 1-1-create-k3s-control-plane.md#Implementation Gaps & Deviations]
- [ADR-001: LXC Containers for K3s](../adrs/ADR-001-lxc-containers-for-k3s.md)
- [LXC K3s Config Template](../../infrastructure/k3s/lxc-k3s-config.conf)

## Dev Agent Record

### Agent Model Used

Claude Opus 4.5 (claude-opus-4-5-20251101)

### Debug Log References

- Infrastructure story - validation via kubectl commands on actual cluster

### Completion Notes List

**Completed: 2026-01-05**

1. **AC1 Satisfied:** LXC container VMID 102 created via Proxmox MCP
   - 4 vCPU, 8GB RAM, 50GB disk
   - IP 192.168.2.21/24, hostname k3s-worker-01
   - K3s LXC config applied (nesting, keyctl, fuse, kmsg, apparmor unconfined)
   - SSH key-based auth configured

2. **AC2 Satisfied:** K3s agent v1.34.3+k3s1 installed and running
   - Worker joined cluster successfully
   - Both nodes show Ready status

3. **AC3 Satisfied:** Workload scheduling validated
   - Test pod (nginx:alpine) scheduled to k3s-worker-01 (not master)
   - Pod reached Running state
   - Test pod cleaned up

4. **Documentation:** Created install-worker.sh script with pre-flight checks, updated README with worker installation instructions

### File List

_Files created/modified during implementation:_
- [x] `infrastructure/k3s/install-worker.sh` - Worker installation script (NEW)
- [x] `infrastructure/k3s/README.md` - Added worker installation section (MODIFIED)
