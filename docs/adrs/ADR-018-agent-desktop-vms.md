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

- **Two Ubuntu 26.04 desktop VMs**: `agent-cowork` (104; 4 vCPU, 12 GB, 64 GB) and `agent-codex`
  (105; 4 vCPU, 8 GB, 48 GB), both `cpu: host`, `vga: virtio`, on `local-lvm`.
- **Ubuntu over Windows**: both apps support it, one build procedure, no Windows licence, easy SSH
  automation. Windows would be the safer choice for Cowork alone, because Cowork on Windows is not beta.
- **Nested virtualization** on `agent-cowork`, so the Cowork sandbox microVM runs inside the VM.
- **Built from the Ubuntu cloud image with cloud-init**, then provisioned by scripts in
  `infrastructure/agent-vms/`, instead of a click-through ISO install. Each VM is built fresh; no cloning,
  so machine-id and Tailscale identity never need resetting. A rebuild keeps the VMID and MAC address,
  so the DHCP lease and the Remmina profiles stay valid.
- **Access by RDP through GNOME Remote Login** (Remmina), plus SSH by key, over LAN and Tailscale.
  RDP → GDM login screen → a headless GNOME session with one virtual screen that follows the client
  window size and keeps running after disconnect. No ingress, no public exposure.
- **No auto-login.** The user logs in at the RDP login screen, which also unlocks the normal, encrypted
  GNOME keyring that holds the apps' sign-in tokens.
- **One shared credential pair for both VMs**: an RDP password (stored in Remmina's keyring entry) and
  a Linux login password for `tt` (typed at the login screen). Kept in `~/.config/agent-vms/rdp-credentials`
  on Tom's laptop, never in git.
- **Space freed with `pct fstrim`** on the three k3s containers: 88.3 % → 59.1 %, ~98 GB returned
  without deleting anything.

### How remote access got here

The first build used Ubuntu 24.04. Each step below failed or was rejected, and led to the next.

| Attempt | Result |
|---|---|
| 24.04, `vga: std` | Stuck at 1280×800: the cloud-image kernel (`linux-image-virtual`) has no `bochs` driver. Fixed with `vga: virtio`. |
| 24.04, Desktop Sharing of an auto-login session, pinned 1920×1200 | Worked, but a fixed size: sharing mirrors the VM's own screen and ignores client resize. Needed an unencrypted keyring, because auto-login cannot unlock a password-protected one. |
| 24.04, Desktop Sharing in *extend* mode | Resized correctly, but added a second screen next to the real one. Top bar and dock stayed on the real screen, which nobody sees. Rejected. |
| 24.04, Remote Login | Broken: the handover to the login screen aborts (`Aborting handover, removing remote client`, LP #2141992, #2154408). Fixed upstream in GNOME 50. |
| **26.04, Remote Login** | **Works**: handover to GDM, single virtual screen sized to the client, session survived a reconnect (verified on `agent-codex`). |

Client side: Remmina on Tom's niri laptop (scale 1.25) runs under X11 (`GDK_BACKEND=x11`). Native
Wayland Remmina drew the remote desktop at 1.25× and cut it off. See the runbook.

### Fallback

If the Cowork sandbox fails on Linux (GH #77348), use the existing Windows 11 VM 101, which already has
`cpu: host`. Install the `.msix` build and enable `VirtualMachinePlatform`. The Codex VM is unaffected.

## Consequences

- **After a VM reboot nothing runs until someone logs in over RDP.** Claude and ChatGPT start only in a
  logged-in session. A disconnect is fine; a reboot is not.
- Real RAM use on `pve` goes from ~22 GB to ~40 GB of 62.7 GB. Allocations (VMs + LXC limits) exceed
  physical RAM; this relies on the LXC limits not being reached together.
- **`local-lvm` is overcommitted**: thin volumes add up to far more than the 335.6 GB pool. A full thin pool
  corrupts every volume on it, so it must be watched. The k3s containers slowly re-fill it until trimming
  runs on a schedule.
- Both apps update through apt: `claude-desktop` from Anthropic's repo, `chatgpt` from the repo its `.deb`
  registers (`/etc/apt/sources.list.d/chatgpt.sources`).
- The ChatGPT `.deb` URL (`persistent.oaistatic.com/codex-app-prod/...`) came from the OpenAI community
  forum, not official docs. The provisioning script checks that the package maintainer is OpenAI.
- 26.04 is newer than the Cowork docs' tested set (Ubuntu 22.04+ is the stated requirement). The Cowork
  sandbox check has not run on it yet.

## References

- [Runbook](../runbooks/agent-desktop-vms.md) — access, Cowork gate, updates, rebuild
- [`infrastructure/agent-vms/`](../../infrastructure/agent-vms/README.md) — specs and build scripts
- [ADR-001](ADR-001-lxc-containers-for-k3s.md) — why k3s runs in LXC, the other workload type on `pve`
- LP #2141992, #2154408 — GNOME Remote Login handover bugs on Ubuntu 24.04
