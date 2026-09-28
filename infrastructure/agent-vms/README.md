# Agent Desktop VMs

Two Ubuntu 26.04 desktop VMs on the Proxmox host `pve` that run AI agent desktop apps.
They are VMs, not k3s workloads, because both apps are GUI desktop apps that must stay open and awake.
See [ADR-018](../../docs/adrs/ADR-018-agent-desktop-vms.md) for the reasoning and
[the runbook](../../docs/runbooks/agent-desktop-vms.md) for operations.

| VM | VMID | App | vCPU | RAM (balloon min) | Disk | MAC | LAN IP (DHCP) |
|---|---|---|---|---|---|---|---|
| `agent-cowork` | 104 | Claude Desktop (Cowork) | 4 | 12 GB (8 GB) | 64 GB | `BC:24:11:25:59:28` | 192.168.2.99 |
| `agent-codex` | 105 | ChatGPT desktop app (Codex) + Codex CLI | 4 | 8 GB (4 GB) | 48 GB | `BC:24:11:0B:C6:7F` | 192.168.2.93 |

Both use `cpu: host`. For `agent-cowork` this is required: Cowork runs its sandbox as a KVM microVM
inside the guest, so the guest needs nested virtualization. The host already has `kvm_intel nested=Y`.

## Prerequisites

- `kvm_intel` nested virtualization on `pve`: `cat /sys/module/kvm_intel/parameters/nested` → `Y`
- Free space in the `local-lvm` thin pool. Run `pct fstrim 100; pct fstrim 102; pct fstrim 103` first
  if `lvs pve/data` shows high usage — the k3s containers never trim deleted blocks.
- Tom's SSH public key on `pve` at `/root/tt-id_ed25519.pub` (for cloud-init).

## Create a VM

Both VMs are built from the Ubuntu 26.04 cloud image with cloud-init, then provisioned over SSH.
Ubuntu 26.04 (GNOME 50) is required: Remote Login is broken on 24.04 (see ADR-018).

```bash
# On pve — once: download and verify the cloud image
cd /var/lib/vz/template/iso
wget https://cloud-images.ubuntu.com/resolute/current/resolute-server-cloudimg-amd64.img -O resolute-cloudimg-amd64.img
wget https://cloud-images.ubuntu.com/resolute/current/SHA256SUMS -O resolute-SHA256SUMS
grep " \*resolute-server-cloudimg-amd64.img$" resolute-SHA256SUMS | awk '{print $1"  resolute-cloudimg-amd64.img"}' | sha256sum -c

# On pve — create the VM (values for agent-cowork; agent-codex: 105, 8192/4096, 48G, its MAC)
qm create 104 --name agent-cowork --machine q35 --bios ovmf --cpu host --cores 4 --sockets 1 \
  --memory 12288 --balloon 8192 --ostype l26 --scsihw virtio-scsi-single --agent enabled=1 \
  --net0 virtio=BC:24:11:25:59:28,bridge=vmbr0,firewall=1 --vga virtio --onboot 1 \
  --efidisk0 local-lvm:1,efitype=4m,pre-enrolled-keys=0
qm set 104 --scsi0 local-lvm:0,import-from=/var/lib/vz/template/iso/resolute-cloudimg-amd64.img,discard=on,ssd=1,iothread=1
qm resize 104 scsi0 64G
qm set 104 --ide2 local-lvm:cloudinit --boot order=scsi0
qm set 104 --ciuser tt --sshkeys /root/tt-id_ed25519.pub --ipconfig0 ip=dhcp
qm start 104
```

Reusing the MAC keeps the DHCP lease, so the Remmina profiles stay valid. Use `--vga virtio`, not `std`:
the cloud-image kernel has no `bochs` driver, so `std` stays on a 1280×800 UEFI framebuffer.

Then, from Tom's laptop, in this order:

| Step | Script | Does |
|---|---|---|
| 1 | [`provision-cowork.sh`](provision-cowork.sh) — copy to the VM, run with `sudo bash` | `ubuntu-desktop-minimal`, QEMU/OVMF/virtiofsd for the Cowork sandbox, Tailscale, `claude-desktop` from Anthropic's apt repo (signing key fingerprint checked) |
| 1 | [`provision-codex.sh`](provision-codex.sh) — same | `ubuntu-desktop-minimal`, Tailscale, the ChatGPT desktop `.deb` (package metadata checked), the Codex CLI |
| 2 | [`setup-remote-login.sh`](setup-remote-login.sh) `<ip>` — run locally | Linux password for `tt`, system RDP daemon with its own TLS certificate, shared RDP credentials |
| 3 | `ssh pve 'qm reboot <vmid>'` | Starts the GDM login screen that RDP hands over to |

```bash
scp provision-cowork.sh tt@192.168.2.99:/tmp/provision.sh
ssh tt@192.168.2.99 'sudo bash /tmp/provision.sh > /tmp/provision.log 2>&1'   # ~10 min
bash setup-remote-login.sh 192.168.2.99
ssh pve 'qm reboot 104'
```
