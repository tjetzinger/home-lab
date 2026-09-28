# ADR-018: Agent Desktop VMs for Claude Cowork and Codex

**Status:** Accepted
**Date:** 2026-09-28

## Context

Two AI agent apps should run permanently in the home lab: **Claude Cowork** (inside Claude Desktop) and
**Codex** (inside the ChatGPT desktop app since July 2026, when OpenAI merged the standalone Codex app into it).
Both are GUI desktop apps. Both stop working when the app is closed or the machine sleeps. Neither fits
k3s: they need a logged-in desktop session, not a container.

### What the research found (2026-09-28)

| Question | Answer | Source |
|---|---|---|
| Does Cowork run on Linux? | Yes, as a beta: Ubuntu 22.04+ / Debian 12+, from Anthropic's apt repo | code.claude.com/docs/en/desktop-linux |
| What does Cowork need? | Its own KVM microVM (QEMU, OVMF, virtiofsd), >8 GB RAM, >25 GB free disk | same, GH anthropics/claude-code #74605 |
| Does it work reliably on Linux? | **No guarantee.** Open bug: `VM not supported (linux/x64), skipping` on compliant hosts | GH #77348 |
| Does the Codex desktop app run on Linux? | Yes, preview since 2026-08-11: Ubuntu 24.04/26.04, `.deb`. No Computer Use on Linux. | community.openai.com |

### Host constraints

- `pve` (i7-10810U, 12 threads, 62.7 GB RAM) already had `kvm_intel nested=Y`.
- The `local-lvm` thin pool was 88.3 % allocated with ~39 GB free — too little for two desktops.
  The k3s LXC volumes were 98–99 % allocated but only ~50–60 % used inside: deleted blocks had never
  been trimmed.

## Decision

- **Two Ubuntu 24.04 desktop VMs**: `agent-cowork` (104; 4 vCPU, 12 GB, 64 GB) and `agent-codex`
  (105; 4 vCPU, 8 GB, 48 GB), both `cpu: host`, on `local-lvm`.
- **Ubuntu over Windows**: both apps support it, one build procedure, no Windows licence, easy SSH
  automation. Windows would be the safer choice for Cowork alone, because Cowork on Windows is not beta.
- **Nested virtualization** on `agent-cowork`, so the Cowork sandbox microVM runs inside the VM.
- **Built from the Ubuntu cloud image with cloud-init**, then provisioned by scripts in
  `infrastructure/agent-vms/`, instead of a click-through ISO install. Each VM is built fresh; no cloning,
  so machine-id and Tailscale identity never need resetting.
- **Access by RDP (Remmina) and SSH key**, over LAN and Tailscale. GNOME Remote Desktop runs in Desktop
  Sharing mode, so RDP shows the auto-login session in which the apps run. No ingress, no public exposure.
- **Unencrypted default keyring.** Auto-login cannot unlock a password-protected keyring. A locked keyring
  would block both the RDP credentials and the apps' sign-in tokens after every reboot.
- **Space freed with `pct fstrim`** on the three k3s containers: 88.3 % → 59.1 %, ~98 GB returned
  without deleting anything.

### Display

- **`vga: virtio`**, not the Proxmox default `std`. The Ubuntu cloud-image kernel (`linux-image-virtual`)
  has no `bochs` driver, so `std` stays on the fixed 1280×800 UEFI framebuffer. `virtio-gpu` is included
  and offers modes up to 5120×2160.
- **Fixed 1920×1200**, written to `~/.config/monitors.xml`. Setting it live via Mutter's D-Bus API reverts
  after ~20 s, because nobody confirms the "keep changes" prompt.
- **No automatic resize to the client window.** Desktop sharing mirrors the VM's screen. GNOME's
  *extend* mode would follow the client size, but it adds a second virtual screen next to the real one,
  and app windows can open on the screen nobody sees. Rejected for unattended agent VMs.
- **Client side:** Remmina on Tom's niri laptop (scale 1.25) must run under X11 for scaled mode to work.
  See the runbook.

### Fallback

If the Cowork sandbox fails on Linux (GH #77348), use the existing Windows 11 VM 101, which already has
`cpu: host`. Install the `.msix` build and enable `VirtualMachinePlatform`. The Codex VM is unaffected.

## Consequences

- Real RAM use on `pve` goes from ~22 GB to ~40 GB of 62.7 GB. Allocations (VMs + LXC limits) exceed
  physical RAM; this relies on the LXC limits not being reached together.
- **`local-lvm` is overcommitted**: thin volumes (including snapshots) add up to ~655 GB on a 335.6 GB pool. It is at 64.7 %
  after both VMs and their `provisioned` snapshots. A full thin pool corrupts every volume on it, so it
  must be watched. The k3s containers will slowly re-fill it until trimming runs on a schedule.
- Both apps update through apt: `claude-desktop` from Anthropic's repo, `chatgpt` from the repo its `.deb`
  registers (`/etc/apt/sources.list.d/chatgpt.sources`).
- The ChatGPT `.deb` URL (`persistent.oaistatic.com/codex-app-prod/...`) came from the OpenAI community
  forum, not official docs. The provisioning script checks that the package maintainer is OpenAI.
- DHCP addresses changed when NetworkManager took over from networkd at the first desktop boot. The VMs
  are reached by their Tailscale names, not by LAN IP.

- Secrets in the keyring (RDP password, Claude and ChatGPT session tokens) sit unencrypted on the VM disk.
  Anyone with root on `pve` or a VM backup can read them. Accepted for single-purpose VMs; revoke the
  sessions from claude.ai / chatgpt.com if a VM or backup leaks.

## References

- [Runbook](../runbooks/agent-desktop-vms.md) — access, Cowork gate, updates, rebuild
- [`infrastructure/agent-vms/`](../../infrastructure/agent-vms/README.md) — specs and build scripts
- [ADR-001](ADR-001-lxc-containers-for-k3s.md) — why k3s runs in LXC, the other workload type on `pve`
