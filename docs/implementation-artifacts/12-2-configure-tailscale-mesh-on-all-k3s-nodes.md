# Story 12.2: Configure Tailscale Mesh on All K3s Nodes

Status: done

## Story

As a **platform engineer**,
I want **Tailscale installed on all K3s nodes with flannel configured over the mesh**,
So that **the Intel NUC GPU worker can join the cluster from a different subnet (192.168.0.x → 192.168.2.x)**.

## Acceptance Criteria

**AC1: Install Tailscale on Existing K3s Nodes**
Given K3s cluster is running (master, worker-01, worker-02)
When I install Tailscale on each node
Then I run on each node:
```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```
And each node gets a Tailscale IP (100.x.x.a, 100.x.x.b, 100.x.x.c)
And all nodes appear in Tailscale admin console
And this validates FR100 (all K3s nodes run Tailscale)

**AC2: Configure K3s Master with Tailscale**
Given Tailscale is running on k3s-master
When I update K3s server config
Then I add to `/etc/rancher/k3s/config.yaml`:
```yaml
flannel-iface: tailscale0
node-external-ip: <tailscale-100.x.x.a>
tls-san:
  - <tailscale-100.x.x.a>
  - 192.168.2.20
```
And I add NO_PROXY to `/etc/environment`:
```
NO_PROXY=127.0.0.0/8,10.0.0.0/8,100.64.0.0/10,172.16.0.0/12,192.168.0.0/16,.local,localhost
```
And I restart K3s: `sudo systemctl restart k3s`
And this validates FR101, FR102, FR103

**AC3: Configure K3s Workers with Tailscale**
Given Tailscale is running on k3s-worker-01 and k3s-worker-02
When I update K3s agent config on each worker
Then I add to `/etc/rancher/k3s/config.yaml`:
```yaml
flannel-iface: tailscale0
node-external-ip: <tailscale-100.x.x.b>  # Each worker's Tailscale IP
```
And I add NO_PROXY to `/etc/environment` (same as master)
And I restart K3s agent: `sudo systemctl restart k3s-agent`
And rolling restart: one node at a time, verify Ready before next

**AC4: Verify Cluster Connectivity**
Given all nodes restarted with Tailscale config
When I verify cluster status
Then `kubectl get nodes -o wide` shows all nodes with Tailscale IPs (100.x.x.*)
And pods can communicate across nodes (test with busybox ping)
And this validates NFR55, NFR56

**AC5: Join Intel NUC GPU Worker**
Given Intel NUC has Ubuntu 22.04 and Tailscale installed (from Story 12.1)
When I install K3s agent on Intel NUC
Then I run:
```bash
TAILSCALE_IP=$(tailscale ip -4)
curl -sfL https://get.k3s.io | K3S_URL=https://<master-tailscale-ip>:6443 \
  K3S_TOKEN=<cluster-token> sh -s - agent \
  --flannel-iface tailscale0 \
  --node-external-ip=$TAILSCALE_IP
```
And node joins: `kubectl get nodes` shows `k3s-gpu-worker` as Ready
And this validates FR71 (GPU worker joins via Tailscale mesh)
And this validates NFR36 (GPU worker joins in 2 minutes)

**AC6: Apply GPU Labels and Taints**
Given k3s-gpu-worker has joined
When I apply labels and taints
Then I run:
```bash
kubectl label node k3s-gpu-worker nvidia.com/gpu=true
kubectl label node k3s-gpu-worker gpu-type=rtx3060
kubectl taint node k3s-gpu-worker gpu=true:NoSchedule
```
And GPU workloads can be scheduled with toleration

## Tasks / Subtasks

- [x] Task 1: Install Tailscale on Existing K3s Nodes (AC: #1)
  - [x] 1.1 SSH to k3s-master (192.168.2.20) and install Tailscale
  - [x] 1.2 Run `tailscale up` and authenticate with Tailscale account
  - [x] 1.3 Note master's Tailscale IP: `tailscale ip -4` → 100.84.89.67
  - [x] 1.4 Repeat for k3s-worker-01 (192.168.2.21) → 100.113.151.13
  - [x] 1.5 Repeat for k3s-worker-02 (192.168.2.22) → 100.124.163.54
  - [x] 1.6 Verify all 3 nodes appear in Tailscale admin console

- [x] Task 2: Configure K3s Master (AC: #2)
  - [x] 2.1 Create/update `/etc/rancher/k3s/config.yaml` with flannel-iface, node-ip, advertise-address
  - [x] 2.2 Add tls-san entries for Tailscale IP and physical IP
  - [x] 2.3 Add NO_PROXY to `/etc/environment` including 100.64.0.0/10
  - [x] 2.4 Restart K3s: `sudo systemctl restart k3s`
  - [x] 2.5 Verify master is Ready: `kubectl get nodes`

- [x] Task 3: Configure K3s Workers (AC: #3)
  - [x] 3.1 Update k3s-worker-01 `/etc/rancher/k3s/config.yaml`
  - [x] 3.2 Add NO_PROXY to k3s-worker-01 `/etc/environment`
  - [x] 3.3 Restart k3s-agent on worker-01: `sudo systemctl restart k3s-agent`
  - [x] 3.4 Verify worker-01 is Ready before proceeding
  - [x] 3.5 Repeat 3.1-3.4 for k3s-worker-02

- [x] Task 4: Verify Cluster Connectivity (AC: #4)
  - [x] 4.1 Check all nodes show correct IPs: `kubectl get nodes -o wide`
  - [x] 4.2 Deploy test busybox pod and verify cross-node communication
  - [x] 4.3 Verify flannel routes are using tailscale0 interface
  - [x] 4.4 Test kubectl logs works (NO_PROXY validation)

- [x] Task 5: Install Tailscale on Intel NUC (AC: #5)
  - [x] 5.1 SSH to k3s-gpu-worker (192.168.0.25)
  - [x] 5.2 Install Tailscale: `curl -fsSL https://tailscale.com/install.sh | sh`
  - [x] 5.3 Run `tailscale up` and authenticate
  - [x] 5.4 Note GPU worker's Tailscale IP → 100.80.98.64

- [x] Task 6: Join Intel NUC to K3s Cluster (AC: #5)
  - [x] 6.1 Get K3s token from master: `sudo cat /var/lib/rancher/k3s/server/node-token`
  - [x] 6.2 Add NO_PROXY to Intel NUC `/etc/environment`
  - [x] 6.3 Install K3s agent with Tailscale config
  - [x] 6.4 Verify node joins: `kubectl get nodes` shows k3s-gpu-worker
  - [x] 6.5 Verify node becomes Ready within 2 minutes (NFR36) - **Joined in 36 seconds ✓**

- [x] Task 7: Apply GPU Labels and Taints (AC: #6)
  - [x] 7.1 Label node with nvidia.com/gpu=true
  - [x] 7.2 Label node with gpu-type=rtx3060
  - [x] 7.3 Taint node with gpu=true:NoSchedule
  - [x] 7.4 Verify labels and taints are applied

- [x] Task 8: Validate Cross-Subnet Communication
  - [x] 8.1 Deploy test pod on GPU worker (with toleration)
  - [x] 8.2 Verify pod can reach pods on 192.168.2.x nodes (~42ms latency)
  - [x] 8.3 Verify pods on 192.168.2.x can reach GPU worker pods (~43ms latency)
  - [x] 8.4 Test kubectl exec to GPU worker pod works ✓

## Gap Analysis

**Last Run:** 2026-01-12
**Accuracy Score:** 100% (8/8 tasks accurate)

### Codebase Scan Results

**Existing Assets:**
- K3s cluster running with 3 nodes (k3s-master, k3s-worker-01, k3s-worker-02)
- All nodes using physical IPs (192.168.2.20-22)
- K3s master config at `/etc/rancher/k3s/config.yaml` with etcd snapshot settings
- Intel NUC (192.168.0.25) configured with Ubuntu 22.04, NVIDIA drivers (Story 12.1)
- UFW on Intel NUC allows K3s/Tailscale ports

**Missing (All tasks needed):**
- Tailscale NOT installed on any K3s node
- Tailscale NOT installed on Intel NUC
- No flannel-iface or node-external-ip in K3s configs
- No NO_PROXY environment variable on any node
- Intel NUC not joined to K3s cluster

### Assessment

All draft tasks are accurate - infrastructure story requiring physical node operations via SSH. No code changes in repository expected.

---

## Dev Notes

### Architecture Context
- This is Story 12.2 in Epic 12 (GPU/ML Inference Platform)
- Implements **Solution A**: Manual Tailscale on all K3s nodes
- Cross-subnet connectivity: 192.168.0.x (Intel NUC) ↔ 192.168.2.x (K3s cluster)
- Tailscale IPs from CGNAT range: 100.64.0.0/10 (100.x.x.x)

### Network Topology (Final)
| Node | Role | Physical IP | Tailscale IP |
|------|------|-------------|--------------|
| k3s-master | Control plane | 192.168.2.20 | 100.84.89.67 |
| k3s-worker-01 | General compute | 192.168.2.21 | 100.113.151.13 |
| k3s-worker-02 | General compute | 192.168.2.22 | 100.124.163.54 |
| k3s-gpu-worker | GPU (Intel NUC) | 192.168.0.25 | 100.80.98.64 |

### K3s Configuration (Final)
**Master config (`/etc/rancher/k3s/config.yaml`):**
```yaml
write-kubeconfig-mode: 644
cluster-init: true
etcd-snapshot-dir: /mnt/k3s-snapshots
etcd-snapshot-schedule-cron: "0 */12 * * *"
etcd-snapshot-retention: 14
node-ip: 192.168.2.20           # Physical IP for etcd
advertise-address: 100.84.89.67  # Tailscale IP for API server
flannel-iface: tailscale0
tls-san:
  - 100.84.89.67
  - 192.168.2.20
```

**Worker/Agent config (k3s-worker-01/02):**
```yaml
node-ip: 192.168.2.2X  # Physical IP
flannel-iface: tailscale0
```

**GPU Worker config (`/etc/rancher/k3s/config.yaml`):**
```yaml
server: https://100.84.89.67:6443  # Master's Tailscale IP
node-ip: 100.80.98.64              # GPU worker's Tailscale IP
flannel-iface: tailscale0
```

**Environment (`/etc/environment` on all nodes):**
```
NO_PROXY=127.0.0.0/8,10.0.0.0/8,100.64.0.0/10,172.16.0.0/12,192.168.0.0/16,.local,localhost
```

### Critical Requirements
- **MTU**: 1280 bytes (prevents VXLAN fragmentation over Tailscale) - NFR57
- **Rolling restart**: One node at a time to maintain cluster availability
- **NO_PROXY**: Must include 100.64.0.0/10 for kubectl logs/exec to work (FR103)
- **Tailscale IPs are stable**: CGNAT allocation persists across restarts

### Previous Story Intelligence (12.1)
- Intel NUC configured at 192.168.0.25, hostname: k3s-gpu-worker
- UFW already allows K3s ports: 6443, 10250, 10251, 8472/udp, 51820/udp, 41641/udp (Tailscale)
- NVIDIA driver 535.274.02 installed, nvidia-persistenced enabled
- SSH key-based auth configured, password auth disabled

### Operational Considerations
| Consideration | Mitigation |
|---------------|------------|
| Tailscale restart breaks flannel routes | Restart K3s service after Tailscale restart |
| MTU fragmentation over VXLAN | Configure MTU 1280 on tailscale0 interface |
| kubectl logs timeout | Ensure NO_PROXY includes 100.64.0.0/10 |
| Node IP changes on Tailscale reconnect | Tailscale IPs are stable (CGNAT allocation persists) |

### Rollback Plan
If Solution A causes issues:
1. Remove `flannel-iface` and `node-external-ip` from K3s configs
2. Restart K3s on all nodes
3. Intel NUC remains isolated (cannot join cluster from different subnet)

### Project Structure Notes
- K3s install scripts at `infrastructure/k3s/` (reference for patterns)
- No new manifests expected - this is infrastructure/configuration work
- Scripts may be added to `scripts/gpu-worker/` for documentation

### References
- [Source: docs/planning-artifacts/epics.md#Epic-12-GPU/ML-Inference-Platform]
- [Source: docs/planning-artifacts/architecture.md#Multi-Subnet-GPU-Worker-Network-Architecture]
- [Source: docs/planning-artifacts/architecture.md#Solution-A-Manual-Tailscale]
- [Source: docs/implementation-artifacts/12-1-install-ubuntu-22-04-on-intel-nuc-and-configure-egpu.md]
- [Source: tailscale.com/kb/1019/subnets]
- [Source: docs.k3s.io/networking]

## Dev Agent Record

### Agent Model Used
Claude Opus 4.5 (claude-opus-4-5-20251101)

### Debug Log References
- Proxmox LXC TUN device fix: added `lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file` to containers 100, 102, 103
- K3s etcd IP conflict: Fixed by using `node-ip` for physical and `advertise-address` for Tailscale
- Agent tunnel connection: Fixed by adding `advertise-address: 100.84.89.67` to master config

### Completion Notes List
- **Task 1** (2026-01-12): Installed Tailscale on all 3 K3s nodes. Required enabling TUN device in Proxmox LXC configs first.
- **Task 2** (2026-01-12): Configured master with flannel-iface=tailscale0. Key finding: must use node-ip (physical) + advertise-address (Tailscale) to keep etcd working while advertising Tailscale IP for agents.
- **Task 3** (2026-01-12): Configured workers with flannel-iface and node-ip (physical). Rolling restart successful.
- **Task 4** (2026-01-12): Verified flannel using tailscale0 for VXLAN encapsulation, cross-node pod ping successful.
- **Task 5** (2026-01-12): Installed Tailscale on Intel NUC. Tailscale IP: 100.80.98.64.
- **Task 6** (2026-01-12): Joined Intel NUC to cluster in 36 seconds (NFR36 <2min ✓). Agent config required explicit `server:` pointing to master's Tailscale IP.
- **Task 7** (2026-01-12): Applied labels (nvidia.com/gpu=true, gpu-type=rtx3060) and taint (gpu=true:NoSchedule).
- **Task 8** (2026-01-12): Full cross-subnet validation: kubectl exec ✓, pod-to-pod ping ~42ms latency via Tailscale mesh.

### File List
Modified on nodes (not in repo):
- `/etc/pve/lxc/100.conf` - Added TUN mount entry (Proxmox host)
- `/etc/pve/lxc/102.conf` - Added TUN mount entry (Proxmox host)
- `/etc/pve/lxc/103.conf` - Added TUN mount entry (Proxmox host)
- `/etc/rancher/k3s/config.yaml` on k3s-master - Added flannel-iface, advertise-address
- `/etc/rancher/k3s/config.yaml` on k3s-worker-01/02 - Added flannel-iface, node-ip
- `/etc/rancher/k3s/config.yaml` on k3s-gpu-worker - Server URL, node-ip, flannel-iface
- `/etc/environment` on all 4 nodes - Added NO_PROXY

---

## Change Log

| Date | Action | Notes |
|------|--------|-------|
| 2026-01-12 | Story created | Created via create-story workflow with full requirements analysis |
| 2026-01-12 | Story completed | All 8 tasks done. Key findings: LXC needs TUN device, K3s master needs advertise-address for cross-subnet agents |
