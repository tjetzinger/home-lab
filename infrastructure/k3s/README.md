# K3s Cluster Infrastructure

This directory contains scripts and documentation for setting up the K3s cluster.

## Prerequisites

- Proxmox VE host with available resources
- Network: 192.168.2.0/24 with internet access
- Ubuntu 22.04 LTS (ISO for VM or LXC template)

## LXC Container Creation (Recommended)

LXC containers are lighter weight than VMs and work well with K3s when properly configured.

### Create Container via Proxmox MCP or CLI

```bash
# On Proxmox host - create container
pct create 100 local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst \
  --hostname k3s-master \
  --memory 4096 \
  --cores 2 \
  --rootfs local-lvm:32 \
  --net0 name=eth0,bridge=vmbr0,ip=192.168.2.20/24,gw=192.168.2.1 \
  --features nesting=1,keyctl=1,fuse=1

# Add K3s-required LXC configuration
cat >> /etc/pve/lxc/100.conf << 'EOF'
lxc.mount.entry: /dev/kmsg dev/kmsg none bind,rw,optional,create=file
lxc.apparmor.profile: unconfined
lxc.cap.drop:
lxc.cgroup2.devices.allow: a
lxc.mount.auto: proc:rw sys:rw
EOF

# Start container
pct start 100
```

### LXC Configuration Explained

K3s requires these LXC settings (see `lxc-k3s-config.conf`):

| Setting | Purpose |
|---------|---------|
| `nesting=1` | Allow container orchestration (required for K3s) |
| `keyctl=1` | Kubernetes secrets management |
| `fuse=1` | Container filesystem operations |
| `/dev/kmsg` bind mount | Kubelet logging |
| `apparmor: unconfined` | K3s system calls without restrictions |
| `cap.drop:` (empty) | Don't drop any capabilities |
| `cgroup2.devices.allow: a` | Full device access |
| `proc:rw sys:rw` | Writable /proc and /sys for kernel parameters |

### SSH Setup for LXC

Ubuntu LXC templates have SSH disabled by default:

```bash
# On Proxmox host - configure SSH in container
pct exec 100 -- bash -c 'mkdir -p /root/.ssh && chmod 700 /root/.ssh'
pct exec 100 -- bash -c 'echo "YOUR_PUBLIC_KEY" >> /root/.ssh/authorized_keys'
pct exec 100 -- chmod 600 /root/.ssh/authorized_keys

# Enable root login with key only
pct exec 100 -- bash -c 'echo "PermitRootLogin prohibit-password" > /etc/ssh/sshd_config.d/99-security.conf'
pct exec 100 -- bash -c 'echo "PasswordAuthentication no" >> /etc/ssh/sshd_config.d/99-security.conf'
pct exec 100 -- mkdir -p /run/sshd
pct exec 100 -- systemctl restart sshd
```

---

## VM Creation (Alternative - Proxmox UI)

### Control Plane Node (k3s-master)

1. **Create VM in Proxmox:**
   - VM ID: 100 (or next available)
   - Name: `k3s-master`
   - ISO: Ubuntu Server 22.04 LTS

2. **Hardware Configuration:**
   - CPU: 2 vCPU
   - Memory: 4096 MB (4GB)
   - Disk: 32GB (VirtIO Block)
   - Network: vmbr0 (bridge to LAN)

3. **Ubuntu Installation:**
   - Hostname: `k3s-master`
   - Username: Your admin user
   - Enable OpenSSH server during install

4. **Network Configuration (Static IP):**
   ```yaml
   # /etc/netplan/00-installer-config.yaml
   network:
     version: 2
     ethernets:
       ens18:  # or your interface name
         addresses:
           - 192.168.2.20/24
         routes:
           - to: default
             via: 192.168.2.1
         nameservers:
           addresses:
             - 192.168.2.1
             - 8.8.8.8
   ```
   Apply with: `sudo netplan apply`

5. **Verify SSH Access:**
   ```bash
   ssh user@192.168.2.20
   ```

## K3s Master Installation

After VM/container is created and accessible via SSH:

```bash
# Copy script to VM
scp install-master.sh user@192.168.2.20:~/

# SSH to VM and run
ssh user@192.168.2.20
chmod +x install-master.sh
sudo ./install-master.sh
```

## K3s Worker Installation

After worker container is created with LXC K3s config applied:

### Get Node Token from Master

```bash
ssh root@192.168.2.20 "cat /var/lib/rancher/k3s/server/node-token"
```

### Install K3s Agent on Worker

```bash
# Copy script to worker
scp install-worker.sh root@192.168.2.21:~/

# SSH to worker and run
ssh root@192.168.2.21
chmod +x install-worker.sh
./install-worker.sh https://192.168.2.20:6443 <NODE_TOKEN>
```

### Verify Worker Joined

From master node:
```bash
kubectl get nodes
```

Expected output:
```
NAME            STATUS   ROLES           VERSION
k3s-master      Ready    control-plane   v1.34.x+k3s1
k3s-worker-01   Ready    <none>          v1.34.x+k3s1
```

## Validation

After installation, verify cluster health:

```bash
# Check node status
kubectl get nodes

# Check system pods
kubectl get pods -n kube-system

# Check component status
kubectl get componentstatuses

# Verify node token exists
sudo cat /var/lib/rancher/k3s/server/node-token
```

## Files

| File | Purpose | Status |
|------|---------|--------|
| `install-master.sh` | K3s master installation script | ✅ Available |
| `install-worker.sh` | K3s worker join script | ✅ Available |
| `kubeconfig-setup.sh` | Remote kubectl access setup script | ✅ Available |
| `lxc-k3s-config.conf` | LXC config template for K3s nodes | ✅ Available |
| `README.md` | This documentation | ✅ Available |

## Network Layout

| Node | IP | Role |
|------|-----|------|
| k3s-master | 192.168.2.20 | Control Plane |
| k3s-worker-01 | 192.168.2.21 | Worker (Story 1.2) |
| k3s-worker-02 | 192.168.2.22 | Worker (Story 1.3) |

## Remote kubectl Access

### Quick Setup

Use the provided script to configure kubectl access:

```bash
# From your local machine
chmod +x kubeconfig-setup.sh
./kubeconfig-setup.sh
```

The script will:
1. Copy kubeconfig from the K3s master
2. Update the server URL to point to the master IP
3. Set proper file permissions (600)
4. Test the connection if kubectl is installed

### Manual Setup

If you prefer manual setup:

```bash
# 1. Create .kube directory
mkdir -p ~/.kube

# 2. Copy kubeconfig from master
ssh root@192.168.2.20 "cat /etc/rancher/k3s/k3s.yaml" > ~/.kube/config

# 3. Update server URL (replace localhost with master IP)
sed -i 's|server: https://127.0.0.1:6443|server: https://192.168.2.20:6443|g' ~/.kube/config

# 4. Set secure permissions
chmod 600 ~/.kube/config

# 5. Verify
kubectl get nodes
```

### Remote Access via Tailscale

This cluster is configured for remote access via Tailscale VPN:

**Prerequisites:**
- Tailscale installed and logged in
- Subnet routing for 192.168.2.0/24 enabled (k3s-master is the subnet router)

**Verify Tailscale connectivity:**
```bash
# Check Tailscale status
tailscale status

# Verify route to cluster goes through Tailscale
ip route get 192.168.2.20
# Should show: 192.168.2.20 dev tailscale0 ...
```

**Test remote access:**
```bash
kubectl get nodes
```

### Subnet Router Configuration

k3s-master is configured as a Tailscale subnet router, advertising the 192.168.2.0/24 network to all Tailscale clients. This allows remote access to any device on the home network without installing Tailscale on each device.

**Current Subnet Routers:**

| Node | Subnet | Purpose |
|------|--------|---------|
| k3s-master | 192.168.2.0/24 | Main cluster network (Proxmox VMs, NAS) |
| k3s-gpu-worker | 192.168.0.0/24 | GPU worker network (Story 15.2) |

**Configuration Commands (already applied):**
```bash
# On k3s-master - configure subnet route advertisement
sudo tailscale set --advertise-routes=192.168.2.0/24 --accept-routes

# Verify configuration
tailscale debug prefs | grep -E "AdvertiseRoutes|RouteAll"
```

**Approving Subnet Routes:**
1. Go to https://login.tailscale.com/admin/machines
2. Find the machine advertising routes (e.g., k3s-master)
3. Click on the machine to open settings
4. Under "Subnet routes", approve the advertised route
5. Save changes

**Verify Route is Working:**
```bash
# Check route path
ip route get 192.168.2.10

# Should show: 192.168.2.10 dev tailscale0 ...

# Trace route to verify path
traceroute 192.168.2.21
# Should show: hop 1 = k3s-master Tailscale IP (100.x.x.x)
```

**Troubleshooting Subnet Routes:**

| Issue | Solution |
|-------|----------|
| Route not appearing | Check `tailscale debug prefs` for AdvertiseRoutes |
| Route pending approval | Approve in Tailscale admin console |
| Can't reach devices | Verify IP forwarding: `cat /proc/sys/net/ipv4/ip_forward` (should be 1) |
| Health check warnings | Run `tailscale set --accept-routes` to accept other routes |

### Security Notes

- The kubeconfig contains cluster credentials - treat as sensitive
- File permissions must be 600 (owner read/write only)
- Never commit kubeconfig to git (add to .gitignore)
- Access requires valid kubeconfig + Tailscale connection

## References

- [K3s Documentation](https://docs.k3s.io/)
- [K3s Cluster Access](https://docs.k3s.io/cluster-access)
- [Tailscale Subnet Routing](https://tailscale.com/kb/1019/subnets)
- [Architecture Decision: architecture.md](../../docs/planning-artifacts/architecture.md)
- [Story 1.1](../../docs/implementation-artifacts/1-1-create-k3s-control-plane.md)
- [Story 1.4](../../docs/implementation-artifacts/1-4-configure-remote-kubectl-access.md)
- [Story 15.1](../../docs/implementation-artifacts/15-1-configure-k3s-master-as-subnet-router.md)
