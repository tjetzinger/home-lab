# Runbook: Agent Desktop VMs (Cowork + Codex)

Operations for `agent-cowork` (VMID 104) and `agent-codex` (VMID 105) on `pve`.
Build steps and specs: [`infrastructure/agent-vms/README.md`](../../infrastructure/agent-vms/README.md).
Reasoning: [ADR-018](../adrs/ADR-018-agent-desktop-vms.md).

## Access

- SSH: `ssh tt@agent-cowork` / `ssh tt@agent-codex` over Tailscale — key-only, set by cloud-init.
- LAN IPs come from DHCP and can change. Current IP: `ssh pve 'qm guest cmd 104 network-get-interfaces'`.
- Desktop: RDP with Remmina (profiles in group "Agent VMs"). User `tt`; the passwords are in
  `~/.config/agent-vms/rdp-credentials` on Tom's laptop (mode 600, not in git).
  - GNOME Remote Desktop runs in **Desktop Sharing** mode: RDP shows the auto-login session, the same one
    the apps run in. Do not switch to *Remote Login*: that starts a second session, without the running apps.
  - Port 3389 listens on all interfaces (LAN and Tailscale). Remmina asks once to accept the TLS certificate.
- The desktop is fixed at **1920×1200** (`set-resolution.sh`). It does not follow the Remmina window size:
  desktop sharing mirrors the VM's own screen and ignores the client's resize requests.

### Remmina client settings (Tom's laptop)

| Setting | Value | Why |
|---|---|---|
| Profiles | `~/.local/share/remmina/group_rdp_agent-{cowork,codex}_*.remmina` | Group "Agent VMs", server = current LAN IP |
| `scale` | `1` (scaled) | Fits the 1920×1200 desktop into any window size |
| `viewmode` | `2` (fullscreen) | |
| Launcher | `~/.local/share/applications/org.remmina.Remmina.desktop` with `env GDK_BACKEND=x11` | See below |

The laptop runs niri at scale 1.25 (1920×1200 panel → 1536×960 logical). Native-Wayland Remmina ignores
scaled mode there: it draws the remote desktop at 1.25× and cuts off the right side. Under X11
(`GDK_BACKEND=x11`) scaled mode works. The launcher override applies to all Remmina connections. Remmina
started from a terminal skips it — use `GDK_BACKEND=x11 remmina -c <profile>`.
- Fallback: the noVNC console of the VM in the Proxmox UI.

## First-time setup per VM (manual, needs Tom)

These steps need Tom's own accounts, so the provisioning scripts do not do them.

1. Join Tailscale: `sudo tailscale up` and open the printed URL.
2. Sign in to the app: Claude Desktop (cowork) or ChatGPT (codex).
3. Optional: `sudo passwd tt`. Only needed for `sudo` in the desktop; RDP has its own password.

Already scripted by [`setup-rdp.sh`](../../infrastructure/agent-vms/setup-rdp.sh): the unencrypted default
keyring, no screen lock / blanking / suspend, the RDP TLS certificate, the credentials, and the service.

## RDP does not connect

| Symptom | Cause | Fix |
|---|---|---|
| `grdctl rdp set-credentials` hangs | The keyring is locked or not loaded yet | Reboot the VM once after `setup-rdp.sh` phase 1 |
| Remmina: authentication failure | Wrong password, or credentials missing from the keyring | `grdctl status --show-credentials` on the VM, rerun phase 2 |
| Connection refused | Service not running, or the VM got a new DHCP address | `systemctl --user status gnome-remote-desktop`; check the IP (see Access) |
| Small picture with black bars | Desktop resolution smaller than the Remmina window | `qm config <vmid>` must show `vga: virtio`; run `set-resolution.sh [W H]`, reboot |
| Picture too big, right side cut off, clock right of center | Remmina runs native Wayland on a fractionally scaled screen | Start Remmina with `GDK_BACKEND=x11` (see Remmina client settings) |
| Black screen | Session locked or display asleep | Check `gsettings get org.gnome.desktop.screensaver lock-enabled` is `false` |

To tell a VM problem from a client problem, look at what the VM itself shows:

```bash
ssh pve 'echo "screendump /tmp/vm104.ppm" | qm monitor 104' && scp pve:/tmp/vm104.ppm .
```

## Cowork gate: is the sandbox VM running?

Cowork runs shell commands inside its own KVM microVM, nested inside `agent-cowork`.

```bash
ssh tt@agent-cowork
kvm-ok                                             # must say "KVM acceleration can be used"
tail -n 30 ~/.config/Claude/logs/cowork_vm_node.log
```

| Log line | Meaning | Action |
|---|---|---|
| `Startup complete` | Sandbox VM is running | Done |
| `VM not supported (linux/x64), skipping` | The app's support check failed (GH anthropics/claude-code #74605, #77348) | See below |
| `VM guest is not connected` in a task | Same root cause, seen from inside a session | See below |

Fix attempt for the virtiofsd probe bug:

```bash
sudo ln -sf /usr/libexec/virtiofsd /usr/bin/virtiofsd   # or the bundled /usr/lib/claude-desktop/resources/virtiofsd
pkill -f claude-desktop                                 # closing the window is not enough, the check is cached
claude-desktop &
```

If the log still says `VM not supported`, the Linux beta does not work here yet. Fallback: the Windows 11
VM 101 (already `cpu: host`), with the `.msix` installer and the `VirtualMachinePlatform` feature on.

## Updates

- `agent-cowork`: `sudo apt update && sudo apt upgrade` — also updates `claude-desktop` (Anthropic apt repo).
- `agent-codex`: `sudo apt update && sudo apt upgrade` — also updates `chatgpt` (its `.deb` registers
  `/etc/apt/sources.list.d/chatgpt.sources`).
  Codex CLI: run the installer again (`curl -fsSL https://chatgpt.com/codex/install.sh | sh`).
- After an app update that breaks something: roll back with the Proxmox snapshot (below).

## Snapshots

```bash
ssh pve 'qm snapshot 104 <name>'      # before app updates
ssh pve 'qm listsnapshot 104'
ssh pve 'qm rollback 104 <name>'
```

Snapshots hold thin-pool blocks. Delete old ones — `local-lvm` is overcommitted (see ADR-018).

## Rebuild from scratch

1. `ssh pve 'qm stop 104 && qm destroy 104 --purge'` — **deletes the disk and everything on it.**
2. Follow [`infrastructure/agent-vms/README.md`](../../infrastructure/agent-vms/README.md).
3. Remove the old machine from the Tailscale admin console and from claude.ai / ChatGPT connected devices.
