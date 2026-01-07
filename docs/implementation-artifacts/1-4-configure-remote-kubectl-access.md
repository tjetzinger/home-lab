# Story 1.4: Configure Remote kubectl Access

Status: done
Completed: 2026-01-05

## Story

As a **cluster operator**,
I want **to run kubectl commands from any Tailscale-connected device**,
so that **I can manage the cluster remotely without SSH**.

## Acceptance Criteria

1. **AC1: Kubeconfig Export**
   - **Given** K3s cluster is running with all nodes Ready
   - **When** I copy `/etc/rancher/k3s/k3s.yaml` to my local `~/.kube/config`
   - **Then** the kubeconfig file contains valid cluster credentials

2. **AC2: Local Network Access**
   - **Given** the kubeconfig references `127.0.0.1:6443`
   - **When** I update the server URL to `https://192.168.2.20:6443`
   - **Then** kubectl can connect to the cluster from the local network

3. **AC3: Remote Access via Tailscale**
   - **Given** Tailscale is configured with subnet routing to 192.168.2.0/24
   - **When** I run `kubectl get nodes` from a Tailscale-connected laptop outside the home network
   - **Then** the command succeeds and shows all 3 nodes
   - **And** response time is under 2 seconds

4. **AC4: Access Control Validation**
   - **Given** remote kubectl access is working
   - **When** I attempt kubectl without valid kubeconfig
   - **Then** access is denied (NFR12: no anonymous access)

## Tasks / Subtasks

⚠️ **DRAFT TASKS** - Generated from requirements analysis. Will be validated and refined against actual codebase when dev-story runs.

- [x] Task 1: Export and Configure Kubeconfig (AC: #1, #2)
  - [x] 1.1: Copy `/etc/rancher/k3s/k3s.yaml` from k3s-master to local machine
  - [x] 1.2: Update server URL from `127.0.0.1:6443` to `https://192.168.2.20:6443`
  - [x] 1.3: Save to `~/.kube/config` with proper permissions (600)
  - [x] 1.4: Verify `kubectl get nodes` works from local network

- [x] Task 2: Configure Tailscale Subnet Routing (AC: #3)
  - [x] 2.1: Verify Tailscale is installed on a device in the 192.168.2.0/24 network
  - [x] 2.2: Enable subnet routing for 192.168.2.0/24 in Tailscale admin console
  - [x] 2.3: Approve the subnet route in Tailscale admin console
  - [x] 2.4: Verify subnet is advertised with `tailscale status`

- [x] Task 3: Validate Remote Access (AC: #3, #4)
  - [x] 3.1: Connect to Tailscale from outside home network (mobile hotspot or external network)
  - [x] 3.2: Run `kubectl get nodes` and verify all 3 nodes are shown
  - [x] 3.3: Measure response time (should be under 2 seconds)
  - [x] 3.4: Test access without kubeconfig to verify denial (NFR12)

- [x] Task 4: Create kubeconfig-setup.sh Script (AC: #1, #2)
  - [x] 4.1: Create `infrastructure/k3s/kubeconfig-setup.sh` script
  - [x] 4.2: Script should copy kubeconfig, update server URL, set permissions
  - [x] 4.3: Update `infrastructure/k3s/README.md` with remote access instructions

## Gap Analysis

**Scan Date:** 2026-01-05
**Scan Result:** ✅ Draft tasks validated - no changes needed

**What Exists:**
- `infrastructure/k3s/install-master.sh` - K3s master installation script
- `infrastructure/k3s/install-worker.sh` - K3s worker join script
- `infrastructure/k3s/lxc-k3s-config.conf` - LXC config template
- `infrastructure/k3s/README.md` - Cluster setup docs (no remote access section)
- K3s cluster: 3 nodes Ready at 192.168.2.20/21/22
- Kubeconfig exists at `/etc/rancher/k3s/k3s.yaml` on master (server: 127.0.0.1:6443)
- Tailscale installed with devices: x1, nas, pi, mini, iphone15, etc.

**What's Missing:**
- Local kubeconfig (`~/.kube/config` doesn't exist)
- `kubeconfig-setup.sh` script
- Remote access section in README
- Tailscale subnet routing for 192.168.2.0/24 verification

**Task Changes:** None - draft tasks accurate

---

## Dev Notes

### Technical Specifications

**Kubeconfig Location:**
```
Source: /etc/rancher/k3s/k3s.yaml (on k3s-master)
Destination: ~/.kube/config (on local machine)
```

**Server URL Update:**
```yaml
# Before
server: https://127.0.0.1:6443

# After
server: https://192.168.2.20:6443
```

**Tailscale Subnet Routing:**
- Subnet: `192.168.2.0/24`
- Exit node not required (subnet routing only)
- DNS via NextDNS (already configured)

### Architecture Requirements

**From [Source: architecture.md#Security Architecture]:**
- Cluster Access: Tailscale only (no public API exposure)
- RBAC: Cluster-admin (single user)

**From [Source: architecture.md#Network Boundaries]:**
```
Internet → Tailscale → Home Network → Traefik (NodePort) → Services
```

**From [Source: epics.md#NFR12]:**
- kubectl access requires valid kubeconfig (no anonymous access)

### Previous Story Intelligence (Story 1.3)

**Learnings to Apply:**
1. **Proxmox MCP works well** - Can use for container operations if needed
2. **pct exec for commands** - Execute commands inside containers via Proxmox host
3. **Cluster is stable** - 3 nodes all Ready, v1.34.3+k3s1

**Current Cluster State:**
| Node | IP | VMID | Status | Version |
|------|-----|------|--------|---------|
| k3s-master | 192.168.2.20 | 100 | Ready | v1.34.3+k3s1 |
| k3s-worker-01 | 192.168.2.21 | 102 | Ready | v1.34.3+k3s1 |
| k3s-worker-02 | 192.168.2.22 | 103 | Ready | v1.34.3+k3s1 |

### Project Structure Notes

**Files to Create/Update:**
```
infrastructure/k3s/
├── kubeconfig-setup.sh     # NEW - Kubeconfig export/setup script
└── README.md               # UPDATE - Add remote access instructions
```

### Testing Approach

**Local Network Test:**
```bash
# From any device on 192.168.2.0/24 network
kubectl get nodes
```

**Remote Access Test:**
```bash
# From Tailscale-connected device outside home network
# 1. Disconnect from home WiFi
# 2. Connect to mobile hotspot or external network
# 3. Ensure Tailscale is connected
tailscale status
# 4. Run kubectl
kubectl get nodes
# 5. Time the response
time kubectl get nodes
```

**Access Denial Test:**
```bash
# Remove or rename kubeconfig
mv ~/.kube/config ~/.kube/config.bak
# Try kubectl - should fail
kubectl get nodes
# Restore
mv ~/.kube/config.bak ~/.kube/config
```

### Security Considerations

- Kubeconfig contains cluster credentials - treat as sensitive
- File permissions must be 600 (owner read/write only)
- Tailscale provides encrypted tunnel - no additional TLS needed for API access
- Do not commit kubeconfig to git repository

### References

- [Source: epics.md#Story 1.4]
- [Source: architecture.md#Security Architecture]
- [Source: architecture.md#Network Boundaries]
- [Source: 1-3-add-second-worker-node.md#Completion Notes]
- [K3s Documentation: Cluster Access](https://docs.k3s.io/cluster-access)
- [Tailscale Subnet Routing](https://tailscale.com/kb/1019/subnets)

## Dev Agent Record

### Agent Model Used

Claude Opus 4.5 (claude-opus-4-5-20251101)

### Debug Log References

- Infrastructure story - validation via kubectl commands and Tailscale status

### Completion Notes List

**Completed: 2026-01-05**

1. **AC1 Satisfied:** Kubeconfig exported from K3s master
   - Copied `/etc/rancher/k3s/k3s.yaml` to `~/.kube/config`
   - Contains valid cluster credentials (certificate-authority-data, client-certificate-data, client-key-data)

2. **AC2 Satisfied:** Local network access configured
   - Server URL updated from `127.0.0.1:6443` to `192.168.2.20:6443`
   - File permissions set to 600 (owner read/write only)
   - `kubectl get nodes` works from local network

3. **AC3 Satisfied:** Remote access via Tailscale working
   - NAS (Synology) advertising 192.168.2.0/24 subnet
   - Traffic routes through `tailscale0` interface
   - Response time: ~0.55 seconds (well under 2-second requirement)
   - All 3 nodes visible via remote kubectl

4. **AC4 Satisfied:** Access control validated
   - Access denied without valid kubeconfig
   - kubectl falls back to localhost:8080 (connection refused)

5. **Documentation:** Created kubeconfig-setup.sh script, updated README with remote access section

**Key Findings:**
- Tailscale subnet routing was already configured on NAS
- Route verification: `ip route get 192.168.2.20` → `dev tailscale0`

### File List

_Files created/modified during implementation:_
- [x] `infrastructure/k3s/kubeconfig-setup.sh` - NEW - Kubeconfig export/setup script
- [x] `infrastructure/k3s/README.md` - MODIFIED - Added remote access section and script to Files table
