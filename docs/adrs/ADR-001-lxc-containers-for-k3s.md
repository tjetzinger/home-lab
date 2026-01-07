# ADR-001: LXC Containers for K3s Nodes

**Status:** Accepted
**Date:** 2026-01-05
**Decision Makers:** Tom, Claude (AI Assistant)

## Context

Story 1.1 originally specified QEMU VMs for K3s cluster nodes. During implementation, we evaluated LXC containers as an alternative.

The home-lab architecture requires:
- K3s control plane and worker nodes
- Ubuntu 22.04 as the base OS
- 2 vCPU, 4GB RAM, 32GB disk per node
- Static IP addressing (192.168.2.20-22)

## Decision Drivers

- **Resource efficiency** - Home lab has finite resources
- **Provisioning speed** - Faster iteration during development
- **Template availability** - Ubuntu 22.04 LXC template was readily available
- **Learning value** - Understanding LXC/container constraints provides valuable knowledge

## Considered Options

### Option 1: QEMU Virtual Machines

**Pros:**
- Full OS isolation with dedicated kernel
- No special configuration needed for K3s
- Matches common production patterns
- Simpler troubleshooting (standard Linux)

**Cons:**
- Higher resource overhead (~1GB+ per VM)
- Slower provisioning (requires ISO, full OS install)
- Ubuntu Server ISO wasn't pre-loaded in Proxmox

### Option 2: LXC Containers (Selected)

**Pros:**
- Lower resource overhead (~256MB per container)
- Faster provisioning (template-based, seconds vs minutes)
- Ubuntu 22.04 template immediately available
- Proxmox MCP automation support

**Cons:**
- Requires extensive configuration for K3s compatibility
- Shares host kernel (potential security consideration)
- Less isolation than full VMs
- Some K3s features may have limitations

## Decision

**Use LXC containers for all K3s nodes** with the following required configuration:

```
features: nesting=1,keyctl=1,fuse=1
lxc.mount.entry: /dev/kmsg dev/kmsg none bind,rw,optional,create=file
lxc.apparmor.profile: unconfined
lxc.cap.drop:
lxc.cgroup2.devices.allow: a
lxc.mount.auto: proc:rw sys:rw
```

## Consequences

### Positive
- 3 nodes use ~768MB overhead vs ~3GB+ with VMs
- Node provisioning takes seconds instead of minutes
- Consistent automation via Proxmox MCP
- Documented configuration enables reproducible setup

### Negative
- More complex initial setup (one-time learning curve)
- Reduced isolation compared to VMs
- May encounter edge cases with certain K3s features
- Kernel modules must be loaded on Proxmox host

### Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| K3s incompatibility discovered later | Can migrate to VMs; LXC config is documented |
| Security concerns with reduced isolation | Tailscale VPN provides network-level isolation |
| Proxmox kernel updates break K3s | Test updates on one node first; maintain snapshots |

## Implementation Notes

Configuration template stored at: `infrastructure/k3s/lxc-k3s-config.conf`

Worker nodes (Stories 1.2, 1.3) should use identical LXC configuration for consistency.

## References

- [K3s in LXC containers](https://docs.k3s.io/)
- [Proxmox LXC documentation](https://pve.proxmox.com/wiki/Linux_Container)
- [Story 1.1 Implementation Gaps](../implementation-artifacts/1-1-create-k3s-control-plane.md#implementation-gaps--deviations)
