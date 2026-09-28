# Agent Desktop VMs

Two Ubuntu 24.04 desktop VMs on the Proxmox host `pve` that run AI agent desktop apps.
They are VMs, not k3s workloads, because both apps are GUI desktop apps that must stay open and awake.
See [ADR-018](../../docs/adrs/ADR-018-agent-desktop-vms.md) for the reasoning and
[the runbook](../../docs/runbooks/agent-desktop-vms.md) for operations.

| VM | VMID | App | vCPU | RAM (balloon min) | Disk | LAN IP (DHCP, 2026-09-28) |
|---|---|---|---|---|---|---|
| `agent-cowork` | 104 | Claude Desktop (Cowork) | 4 | 12 GB (8 GB) | 64 GB | 192.168.2.99 |
| `agent-codex` | 105 | ChatGPT desktop app (Codex) + Codex CLI | 4 | 8 GB (4 GB) | 48 GB | 192.168.2.93 |

Both use `cpu: host`. For `agent-cowork` this is required: Cowork runs its sandbox as a KVM microVM
inside the guest, so the guest needs nested virtualization. The host already has
`kvm_intel nested=Y`.

## Prerequisites

- `kvm_intel` nested virtualization on `pve`: `cat /sys/module/kvm_intel/parameters/nested` → `Y`
- Free space in the `local-lvm` thin pool. Run `pct fstrim 100; pct fstrim 102; pct fstrim 103` first
  if `lvs pve/data` shows high usage — the k3s containers never trim deleted blocks.

## Create a VM

Both VMs are built from the Ubuntu 24.04 cloud image with cloud-init, then provisioned over SSH.

```bash
# On pve — once: download and verify the cloud image
cd /var/lib/vz/template/iso
wget https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img -O noble-cloudimg-amd64.img
wget https://cloud-images.ubuntu.com/noble/current/SHA256SUMS -O noble-SHA256SUMS
grep " \*noble-server-cloudimg-amd64.img$" noble-SHA256SUMS | awk '{print $1"  noble-cloudimg-amd64.img"}' | sha256sum -c

# On pve — create the VM (values for agent-cowork; agent-codex: 105, 8192/4096, 48G)
qm create 104 --name agent-cowork --machine q35 --bios ovmf --cpu host --cores 4 --sockets 1 \
  --memory 12288 --balloon 8192 --ostype l26 --scsihw virtio-scsi-single --agent enabled=1 \
  --net0 virtio,bridge=vmbr0,firewall=1 --vga virtio --onboot 1 \
  --efidisk0 local-lvm:1,efitype=4m,pre-enrolled-keys=0
qm set 104 --scsi0 local-lvm:0,import-from=/var/lib/vz/template/iso/noble-cloudimg-amd64.img,discard=on,ssd=1,iothread=1
qm resize 104 scsi0 64G
qm set 104 --ide2 local-lvm:cloudinit --boot order=scsi0
qm set 104 --ciuser tt --sshkeys /root/tt-id_ed25519.pub --ipconfig0 ip=dhcp
qm start 104
```

Then run the scripts on the VM over SSH, in this order: the matching `provision-*.sh` with `sudo bash`,
then `setup-rdp.sh` and `set-resolution.sh` as `tt`:

| Script | Installs |
|---|---|
| [`provision-cowork.sh`](provision-cowork.sh) | `ubuntu-desktop-minimal`, QEMU/OVMF/virtiofsd for the Cowork sandbox, Tailscale, `claude-desktop` from Anthropic's apt repo (signing key fingerprint checked) |
| [`provision-codex.sh`](provision-codex.sh) | `ubuntu-desktop-minimal`, Tailscale, the ChatGPT desktop `.deb` (package metadata checked), the Codex CLI |
| [`setup-rdp.sh`](setup-rdp.sh) | Run as `tt` after provisioning, in two phases with a reboot between: open keyring, no lock/sleep, RDP TLS cert, credentials, service |
| [`set-resolution.sh`](set-resolution.sh) | Run as `tt`, then reboot: pins the desktop to 1920×1200 (`~/.config/monitors.xml`) so Remmina fills the screen |

Use `--vga virtio`, not `std`: the cloud-image kernel has no `bochs` driver, so `std` stays on the
1280×800 UEFI framebuffer and RDP shows a small picture with black bars.

The LAN IPs are DHCP leases and changed once already; use the Tailscale names.

Both `provision-*.sh` scripts enable GDM auto-login for `tt`, so the apps can start again after a reboot.
