# Story 12.1: Install Ubuntu 22.04 on Intel NUC and Configure eGPU

Status: done

## Story

As a **platform engineer**,
I want Ubuntu 22.04 installed on the Intel NUC with RTX 3060 eGPU configured,
so that the hardware is ready to join the K3s cluster with GPU capabilities.

## Acceptance Criteria

**AC1: OS Installation**
Given I have Intel NUC hardware and RTX 3060 eGPU
When I install Ubuntu 22.04 LTS
Then the OS is installed with:
- Static IP: 192.168.0.25 (local network)
- Hostname: `k3s-gpu-worker`
- SSH access configured with key-based authentication
- System updates applied: `sudo apt update && sudo apt upgrade -y`

**AC2: eGPU Detection**
Given OS is installed
When I connect the eGPU via Thunderbolt
Then `boltctl list` shows the eGPU enclosure
And I authorize the device: `boltctl authorize <device-uuid>`
And `lspci | grep NVIDIA` shows RTX 3060

**AC3: NVIDIA Driver Installation**
Given eGPU is detected
When I install NVIDIA drivers
Then I run:
```bash
sudo apt install nvidia-driver-535
sudo reboot
```
And after reboot, `nvidia-smi` shows RTX 3060 with 12GB VRAM
And driver version is 535+ (CUDA 12.2+ compatible)
And nvidia-persistenced service is enabled: `sudo systemctl enable --now nvidia-persistenced`

**AC4: System Hardening**
Given drivers are installed
When I configure system hardening
Then UFW firewall allows SSH and K3s ports
And unattended upgrades are enabled
And eGPU auto-connects on boot

## Tasks / Subtasks

**DRAFT TASKS** - Generated from requirements analysis. Will be validated and refined against actual codebase when dev-story runs.

- [x] Task 1: Install Ubuntu 22.04 on Intel NUC (AC: #1)
  - [x] 1.1 Create bootable USB with Ubuntu 22.04 LTS Desktop
  - [x] 1.2 Install Ubuntu Desktop (Xorg session - required for gaming in Story 13)
  - [x] 1.3 Configure static IP 192.168.0.25 via nmcli (local network)
  - [x] 1.4 Set hostname to `k3s-gpu-worker`
  - [x] 1.5 Configure SSH with key-based auth (disable password auth)
  - [x] 1.6 Run `sudo apt update && sudo apt upgrade -y`

- [x] Task 2: Configure eGPU via Thunderbolt (AC: #2)
  - [x] 2.1 Connect RTX 3060 eGPU enclosure via Thunderbolt
  - [x] 2.2 Install bolt utilities: `sudo apt install bolt`
  - [x] 2.3 List devices: `boltctl list`
  - [x] 2.4 Authorize eGPU device: `boltctl authorize <uuid>`
  - [x] 2.5 Verify NVIDIA detection: `lspci | grep NVIDIA`

- [x] Task 3: Install NVIDIA Drivers (AC: #3)
  - [x] 3.1 ~~Configure kernel parameters for PCIe hot-plug support~~ (SKIPPED - broke ethernet, not needed)
  - [x] 3.2 Configure thunderbolt module to load before nvidia_drm
  - [x] 3.3 Install driver package: `sudo apt install nvidia-driver-535`
  - [x] 3.4 Configure nvidia-drm.modeset=1 in /etc/modprobe.d/nvidia-drm.conf
  - [x] 3.5 Reboot system
  - [x] 3.6 Verify `nvidia-smi` shows RTX 3060 with 12GB VRAM
  - [x] 3.7 Verify driver version is 535+
  - [x] 3.8 Enable nvidia-persistenced daemon: `sudo systemctl enable --now nvidia-persistenced`

- [x] Task 4: Configure System Hardening (AC: #4)
  - [x] 4.1 Enable UFW: `sudo ufw enable`
  - [x] 4.2 Allow SSH: `sudo ufw allow ssh`
  - [x] 4.3 Allow K3s ports: 6443, 10250, 10251, 8472/udp, 51820/udp, 41641/udp
  - [x] 4.4 Configure unattended-upgrades
  - [x] 4.5 Configure eGPU auto-authorize on boot via boltctl (iommu policy)
  - [x] 4.6 Document cold-plug requirement (eGPU must be connected before boot)

## Gap Analysis

**Last Run:** 2026-01-11
**Accuracy Score:** 100% (24/24 tasks)

### Codebase Scan Results

**Existing Assets:**
- K3s install scripts at `infrastructure/k3s/` (reference pattern)
- Story file well-documented with research findings

**Missing (Expected - Story Not Started):**
- `scripts/gpu-worker/` directory (to be created during implementation)
- GPU worker installation scripts
- Netplan config templates

### Task Validation

| Category | Count | Status |
|----------|-------|--------|
| Accurate | 24 | ✅ All tasks correctly unchecked |
| False Positives | 0 | ✅ None |
| False Negatives | 0 | ✅ None |

### Assessment

This is a **hardware setup story** - tasks are performed on physical Intel NUC hardware, not code changes in this repository. Story is well-prepared with:
- Comprehensive acceptance criteria
- Critical research findings (cold-plug, nvidia-persistenced)
- Solution A networking context documented
- Ready for implementation

---

## Dev Notes

### Architecture Context
- This is Story 12.1 in Epic 12 (GPU/ML Inference Platform)
- Intel NUC + RTX 3060 eGPU will become K3s GPU worker node
- Physical network: 192.168.0.0/24 (Intel NUC location)
- Tailscale IP: 100.x.x.x (auto-assigned by Tailscale in Story 12.2)
- K3s cluster network: 192.168.2.0/24 (accessed via Tailscale subnet router)

### Hardware Requirements
- Intel NUC (Gen 11+ with Thunderbolt 4)
- RTX 3060 in eGPU enclosure (Thunderbolt 3/4)
- Minimum 16GB RAM recommended
- Ubuntu 22.04 LTS Desktop (not 24.04 - driver compatibility)
- **Display Server: Xorg** (not Wayland - better Steam/Proton/NVIDIA compatibility for Story 13)

### Network Planning
- Physical LAN IP: 192.168.0.25 (Intel NUC local network)
- Tailscale IP: 100.x.x.x (auto-assigned from CGNAT range, Story 12.2)
- K3s master: 192.168.2.20 (Physical) / 100.x.x.a (Tailscale)
- K3s cluster subnet: 192.168.2.0/24

**Story 12.2 Setup (Solution A - Tailscale on all K3s nodes):**
1. Install Tailscale on all existing K3s nodes (master, worker-01, worker-02)
2. Configure K3s with `--flannel-iface tailscale0` and `--node-external-ip <tailscale-ip>`
3. Add NO_PROXY=100.64.0.0/10 to /etc/environment on all nodes
4. Install Tailscale on Intel NUC
5. Join Intel NUC to K3s: `curl -sfL https://get.k3s.io | K3S_URL=https://<master-tailscale-ip>:6443 K3S_TOKEN=<token> sh -s - agent --flannel-iface tailscale0 --node-external-ip=$TAILSCALE_IP`

**Note:** All K3s nodes run Tailscale for full mesh connectivity. This is Solution A per architecture.md.

### Critical Research Findings (Exa 2026-01-11)

**NVIDIA Persistence Mode:**
- Do NOT use `nvidia-smi -pm 1` (legacy method)
- Use `nvidia-persistenced` daemon instead (official NVIDIA recommendation)
- Enable service: `sudo systemctl enable nvidia-persistenced`

**Thunderbolt Hot-plug Warning:**
- eGPU hot-unplug causes system instability/freezes (per NVIDIA docs)
- MUST cold-plug: connect eGPU BEFORE boot, disconnect AFTER shutdown
- Cannot safely remove eGPU while system running

**Required Kernel Parameters:**
~~Add to `/etc/default/grub` GRUB_CMDLINE_LINUX_DEFAULT:~~
```
pcie_ports=native pci=assign-busses,hpbussize=0x33,realloc,hpmmiosize=128M,hpmmioprefsize=16G
```
**WARNING: DO NOT USE** - These parameters break Intel NUC's built-in ethernet (enp88s0 disappears).
The eGPU works fine without any kernel parameters on Intel NUC 11+.

**Driver Load Order:**
- thunderbolt module MUST load before nvidia_drm
- Add to `/etc/modules-load.d/thunderbolt.conf`: `thunderbolt`
- Or add to initramfs: `MODULES=(thunderbolt)` in mkinitcpio equivalent

**nvidia-drm.modeset=1:**
- Required for PRIME support (already in architecture)
- Add to `/etc/modprobe.d/nvidia-drm.conf`: `options nvidia-drm modeset=1`

**Xorg Configuration (for gaming in Story 13):**
- Ubuntu 22.04 defaults to Wayland - select "Ubuntu on Xorg" at login screen (gear icon)
- Or set default: edit `/etc/gdm3/custom.conf` and set `WaylandEnable=false`
- Xorg provides better Steam/Proton/NVIDIA compatibility than Wayland
- eGPU config in Story 13: `/etc/X11/xorg.conf.d/80-egpu.conf` with `AllowExternalGpus`

### Project Structure Notes
- No Kubernetes manifests in this story (hardware setup only)
- Documentation: scripts/gpu-worker/ for any install scripts created

### References
- [Source: docs/planning-artifacts/epics.md#Epic-12-GPU/ML-Inference-Platform]
- [Source: docs/planning-artifacts/architecture.md#Dual-Use-GPU-Architecture]
- [Source: docs/planning-artifacts/architecture.md#Multi-Subnet-GPU-Worker-Network-Architecture]
- [Source: docs/planning-artifacts/prd.md#Gaming-Platform]
- [Source: docs/planning-artifacts/prd.md#Multi-Subnet-Networking]
- [Source: wiki.archlinux.org/title/External_GPU]
- [Source: docs.nvidia.com/deploy/driver-persistence]
- [Source: egpu.io/forums/thunderbolt-linux-setup]

## Dev Agent Record

### Agent Model Used
Claude Opus 4.5 (claude-opus-4-5-20251101) - Guided hardware setup mode

### Debug Log References
_To be filled during implementation_

### Completion Notes List
- **1.1 Create bootable USB** (2026-01-12): Downloaded ubuntu-22.04.5-desktop-amd64.iso (4.44GB), wrote to /dev/sdc using dd
- **1.2 Install Ubuntu** (2026-01-12): Minimal installation, no LVM, Xorg session
- **1.3 Static IP** (2026-01-12): Configured via nmcli (NetworkManager), 192.168.0.25/24, gw 192.168.0.1
- **1.4 Hostname** (2026-01-12): Set during install to k3s-gpu-worker
- **1.5 SSH** (2026-01-12): Password auth disabled in /etc/ssh/sshd_config
- **1.6 Updates** (2026-01-12): 258 packages upgraded
- **2.1-2.5 eGPU** (2026-01-12): Razer Core X detected, RTX 3060 (GA106 LHR) visible at 2f:00.0
- **3.1 Kernel params** (2026-01-12): SKIPPED - pcie_ports=native broke Intel NUC ethernet (enp88s0 disappeared), reverted
- **3.2-3.8 NVIDIA** (2026-01-12): Driver 535.274.02, CUDA 12.2, 12GB VRAM, nvidia-persistenced enabled
- **4.1-4.6 Hardening** (2026-01-12): UFW enabled with K3s/Tailscale ports, unattended-upgrades, eGPU iommu policy

### File List
_To be filled with modified/created files_

---

## Change Log

| Date | Action | Notes |
|------|--------|-------|
| 2026-01-11 | Gap analysis performed | Tasks validated against codebase - 100% accuracy, story ready for implementation |
| 2026-01-12 | Task 1.1 completed | Created bootable USB with Ubuntu 22.04.5 LTS Desktop |
| 2026-01-12 | Story completed | All tasks done. Note: PCIe kernel params broke ethernet - not needed for eGPU on Intel NUC |
