# Story 12.1: Install Ubuntu 22.04 on Intel NUC and Configure eGPU

Status: ready-for-dev

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

- [ ] Task 1: Install Ubuntu 22.04 on Intel NUC (AC: #1)
  - [ ] 1.1 Create bootable USB with Ubuntu 22.04 LTS Desktop
  - [ ] 1.2 Install Ubuntu Desktop (Xorg session - required for gaming in Story 13)
  - [ ] 1.3 Configure static IP 192.168.0.25 via netplan (local network)
  - [ ] 1.4 Set hostname to `k3s-gpu-worker`
  - [ ] 1.5 Configure SSH with key-based auth (disable password auth)
  - [ ] 1.6 Run `sudo apt update && sudo apt upgrade -y`

- [ ] Task 2: Configure eGPU via Thunderbolt (AC: #2)
  - [ ] 2.1 Connect RTX 3060 eGPU enclosure via Thunderbolt
  - [ ] 2.2 Install bolt utilities: `sudo apt install bolt`
  - [ ] 2.3 List devices: `boltctl list`
  - [ ] 2.4 Authorize eGPU device: `boltctl authorize <uuid>`
  - [ ] 2.5 Verify NVIDIA detection: `lspci | grep NVIDIA`

- [ ] Task 3: Install NVIDIA Drivers (AC: #3)
  - [ ] 3.1 Configure kernel parameters for PCIe hot-plug support in /etc/default/grub
  - [ ] 3.2 Configure thunderbolt module to load before nvidia_drm
  - [ ] 3.3 Install driver package: `sudo apt install nvidia-driver-535`
  - [ ] 3.4 Configure nvidia-drm.modeset=1 in /etc/modprobe.d/nvidia-drm.conf
  - [ ] 3.5 Reboot system
  - [ ] 3.6 Verify `nvidia-smi` shows RTX 3060 with 12GB VRAM
  - [ ] 3.7 Verify driver version is 535+
  - [ ] 3.8 Enable nvidia-persistenced daemon: `sudo systemctl enable --now nvidia-persistenced`

- [ ] Task 4: Configure System Hardening (AC: #4)
  - [ ] 4.1 Enable UFW: `sudo ufw enable`
  - [ ] 4.2 Allow SSH: `sudo ufw allow ssh`
  - [ ] 4.3 Allow K3s ports: 6443, 10250, 10251
  - [ ] 4.4 Configure unattended-upgrades
  - [ ] 4.5 Configure eGPU auto-authorize on boot via boltctl
  - [ ] 4.6 Document cold-plug requirement (eGPU must be connected before boot)

## Gap Analysis

_This section will be populated by dev-story when gap analysis runs._

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
- K3s master: 192.168.2.20 (accessed via Tailscale subnet router)
- K3s cluster subnet: 192.168.2.0/24 (advertised by subnet router on existing node)
- Story 12.2 configures: Tailscale install, accept-routes, K3s agent join via --node-ip

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
Add to `/etc/default/grub` GRUB_CMDLINE_LINUX_DEFAULT:
```
pcie_ports=native pci=assign-busses,hpbussize=0x33,realloc,hpmmiosize=128M,hpmmioprefsize=16G
```
Then run `sudo update-grub && sudo reboot`

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
- [Source: docs/planning-artifacts/prd.md#Gaming-Platform]
- [Source: wiki.archlinux.org/title/External_GPU]
- [Source: docs.nvidia.com/deploy/driver-persistence]
- [Source: egpu.io/forums/thunderbolt-linux-setup]

## Dev Agent Record

### Agent Model Used
_To be filled during dev-story execution_

### Debug Log References
_To be filled during implementation_

### Completion Notes List
_To be filled as tasks complete_

### File List
_To be filled with modified/created files_
