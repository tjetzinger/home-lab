# Steam Gaming Setup on Intel NUC (k3s-gpu-worker)

This guide documents the Steam installation and Proton configuration for gaming on the Intel NUC GPU worker node with RTX 3060 eGPU.

## Prerequisites

- Ubuntu 22.04 Desktop with Xorg session
- NVIDIA driver 535+ installed and working (`nvidia-smi` returns GPU info)
- RTX 3060 eGPU connected via Thunderbolt and authorized
- `nvidia-drm.modeset=1` configured (required for PRIME support)

## System Information

| Component | Value |
|-----------|-------|
| Host | k3s-gpu-worker (Intel NUC) |
| OS | Ubuntu 22.04 LTS Desktop |
| GPU | NVIDIA RTX 3060 12GB (eGPU via Thunderbolt) |
| Driver | 535.274.02 |
| IP (LAN) | 192.168.0.25 |
| IP (Tailscale) | 100.80.98.64 |

## Installation Steps

### 1. Enable Multiverse Repository (if not already enabled)

```bash
sudo add-apt-repository multiverse -y
sudo apt update
```

### 2. Install Steam

```bash
sudo apt install -y steam
```

This installs Steam and all required 32-bit libraries for game compatibility.

### 3. Launch Steam and Authenticate

On the Intel NUC desktop (not via SSH):

```bash
steam
```

1. Accept the Steam license agreement
2. Sign in with your Steam account
3. Steam will download updates (~500MB)

### 4. Enable Proton for Windows Games

In Steam (UI updated in recent versions):

1. Click **Steam** (top-left) > **Settings**
2. Select **Compatibility** from the left menu
3. "Enable Steam Play for supported titles" should already be enabled (verified games)
4. Toggle **"Enable Steam Play for all other titles"** to ON (enables unverified games)
5. Select Proton version from dropdown: **Proton Experimental** (recommended) or **Proton 9.0+**
6. Restart Steam when prompted

**Note:** The settings menu changed from "Steam Play" to "Compatibility" in recent Steam updates. Both names refer to the same Proton functionality.

### Proton Version Recommendations

| Version | Use Case |
|---------|----------|
| **Proton Experimental** | Latest features, best for newer games |
| **Proton 9.0+** | Stable, good compatibility |
| **Proton-GE** | Community build with extra patches (install via ProtonUp-Qt) |

Check [ProtonDB](https://www.protondb.com/) for game-specific Proton version recommendations.

## Verify NVIDIA Configuration

### Check nvidia-drm.modeset

```bash
cat /etc/modprobe.d/nvidia-drm.conf
# Should show: options nvidia-drm modeset=1
```

### Verify GPU is Available

```bash
nvidia-smi
# Should show RTX 3060 with driver 535.x
```

### Check Vulkan Support (for Proton/DXVK)

```bash
vulkaninfo | grep "GPU id"
# Should show NVIDIA GeForce RTX 3060
```

## Game Compatibility

Tested games and their status:

| Game | Proton Version | Status | Notes |
|------|----------------|--------|-------|
| Counter-Strike 2 | Proton 9.0-4 | ✅ Platinum | 1080p Med: 60 FPS, 58°C max, no stuttering |

Check [ProtonDB](https://www.protondb.com/) for community compatibility reports.

## Performance Tips

### Force Game to Use eGPU

For games that don't automatically use the eGPU:

1. Right-click game in Steam Library
2. **Properties** > **General** > **Launch Options**
3. Add: `__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia %command%`

### Monitor GPU Usage During Gaming

```bash
# Watch GPU usage in real-time
watch -n 1 nvidia-smi

# Or use nvidia-smi pmon for per-process monitoring
nvidia-smi pmon -i 0
```

## Mode Switching (ML vs Gaming)

The RTX 3060 is shared between gaming and ML inference. Use the `gpu-mode` script to switch:

### Quick Reference

```bash
# Before gaming - release GPU for Steam
gpu-mode gaming

# After gaming - restore ML inference
gpu-mode ml

# Check current status
gpu-mode status
```

### Gaming Mode
Scales vLLM to 0 replicas, releasing GPU memory for Steam games. Ollama CPU fallback remains available for AI workflows.

```bash
gpu-mode gaming
# Completion time: ~6s (target: <30s - NFR51)
```

### ML Mode
Restores vLLM with GPU inference. Wait for model loading (~30-60s).

```bash
gpu-mode ml
# Completion time: ~38s (target: <2min - NFR52)
```

### Status Check
Shows current mode, vLLM replicas, GPU memory usage, and Ollama fallback status.

```bash
gpu-mode status
```

### Script Location
- **Intel NUC:** `/usr/local/bin/gpu-mode`
- **Repository:** `scripts/gpu-worker/gpu-mode`

### Default ML Mode at Boot (FR119)

The system automatically activates ML Mode when k3s-gpu-worker boots, ensuring vLLM is available for inference by default.

**Installation (run on k3s-gpu-worker):**

```bash
# Copy service file
sudo cp /path/to/home-lab/scripts/gpu-worker/gpu-mode-default.service /etc/systemd/system/

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable gpu-mode-default.service

# Verify (after reboot or manual start)
sudo systemctl status gpu-mode-default.service
```

**Behavior:**
- Waits for k3s-agent to be ready (up to 5 minutes)
- Automatically runs `gpu-mode ml` to scale vLLM to 1
- User can manually switch to `gpu-mode gaming` anytime
- After gaming, run `gpu-mode ml` or reboot to restore ML Mode

See [eGPU Hot-Plug Runbook](../../docs/runbooks/egpu-hotplug.md) for hardware disconnect/reconnect procedures.

## Troubleshooting

### Steam Won't Launch

```bash
# Check Steam logs
cat ~/.steam/error.log

# Reinstall Steam runtime
rm -rf ~/.steam/ubuntu12_32
steam
```

### Game Crashes with Proton

1. Try a different Proton version (Proton GE from ProtonUp-Qt)
2. Check game-specific fixes on [ProtonDB](https://www.protondb.com/)
3. Add launch option: `PROTON_LOG=1 %command%` to generate logs

### GPU Not Detected by Games

```bash
# Verify driver is loaded
lsmod | grep nvidia

# Check Vulkan
vulkaninfo --summary

# Restart display manager if needed
sudo systemctl restart gdm3
```

## Related Documentation

- [eGPU Hot-Plug Runbook](../../docs/runbooks/egpu-hotplug.md)
- [Story 12.1: Install Ubuntu 22.04 on Intel NUC](../../docs/implementation-artifacts/12-1-install-ubuntu-22-04-on-intel-nuc-and-configure-egpu.md)
- [Story 13.2: Configure Mode Switching Script](../../docs/implementation-artifacts/13-2-configure-mode-switching-script.md)

## Revision History

| Date | Version | Changes |
|------|---------|---------|
| 2026-01-13 | 1.0 | Initial creation - Story 13.1 |
| 2026-01-13 | 1.1 | Added gpu-mode script usage - Story 13.2 |
| 2026-01-14 | 1.2 | Added CS2 validation, default ML Mode at boot (FR119) |
