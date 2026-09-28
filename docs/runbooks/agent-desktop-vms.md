# Runbook: Agent Desktop VMs (Cowork + Codex)

Operations for `agent-cowork` (VMID 104) and `agent-codex` (VMID 105) on `pve`.
Build steps and specs: [`infrastructure/agent-vms/README.md`](../../infrastructure/agent-vms/README.md).
Reasoning: [ADR-018](../adrs/ADR-018-agent-desktop-vms.md).

## Access

- **Desktop:** RDP with Remmina, profiles in group "Agent VMs". Connect → Ubuntu login screen → log in as
  `tt`. The desktop follows the Remmina window size. Disconnecting leaves the session and apps running;
  the next connect returns to the same session after the login screen.
- **Credentials:** one pair for both VMs, in `~/.config/agent-vms/rdp-credentials` on Tom's laptop
  (mode 600, not in git):
  - `rdp=` — RDP password, user `tt`. Stored in Remmina's keyring entry, so Remmina never asks.
  - `login=` — Linux password of `tt`, typed at the login screen.
- **SSH:** `ssh tt@<ip>` or `ssh tt@agent-cowork` over Tailscale — key-only, set by cloud-init.
- **LAN IPs** come from DHCP (cowork `.99`, codex `.93`). A rebuild keeps the MAC, so they stay. Check:
  `ssh pve 'qm guest cmd 104 network-get-interfaces'`.
- **Fallback:** the noVNC console of the VM in the Proxmox UI shows the VM's own login screen.

**After a VM reboot, nothing runs until you log in over RDP once.** There is no auto-login.

### Remmina client settings (Tom's laptop)

| Setting | Value | Why |
|---|---|---|
| Profiles | `~/.local/share/remmina/group_rdp_agent-{cowork,codex}_*.remmina` | Server = LAN IP, user `tt` |
| `scale` | `2` (dynamic resolution) | The VM creates its screen at the window size and resizes with it |
| Password | `password=.` → keyring item, schema `org.remmina.Password`, attributes `filename` + `key=password` | Set from the credentials file, see below |
| Launcher | `~/.local/share/applications/org.remmina.Remmina.desktop` with `env GDK_BACKEND=x11` | See below |

The laptop runs niri at scale 1.25. Native-Wayland Remmina drew the remote desktop at 1.25× and cut off the
right side; under X11 it fits. The launcher override applies to all Remmina connections. Remmina started
from a terminal skips it — use `GDK_BACKEND=x11 remmina -c <profile>`.

Store the RDP password in Remmina without typing it (the password is read from the file, never printed):

```bash
grep '^rdp=' ~/.config/agent-vms/rdp-credentials | cut -d= -f2- | tr -d '\n' | python3 -c '
import sys, gi
gi.require_version("Secret", "1")
from gi.repository import Secret
schema = Secret.Schema.new("org.remmina.Password", Secret.SchemaFlags.NONE,
    {"filename": Secret.SchemaAttributeType.STRING, "key": Secret.SchemaAttributeType.STRING})
profile = "/home/tt/.local/share/remmina/group_rdp_agent-codex_192-168-2-93.remmina"
Secret.password_store_sync(schema, {"filename": profile, "key": "password"},
    Secret.COLLECTION_DEFAULT, "Remmina: Agent Codex - password", sys.stdin.read(), None)'
```

## First-time setup per VM (manual, needs Tom)

1. Log in once over RDP (see Access).
2. Join Tailscale: `sudo tailscale up` and open the printed URL.
3. Sign in to the app: Claude Desktop (cowork) or ChatGPT (codex).

## Change the passwords

Edit `rdp=` / `login=` in the credentials file, then for each VM:

```bash
bash infrastructure/agent-vms/setup-remote-login.sh 192.168.2.99
bash infrastructure/agent-vms/setup-remote-login.sh 192.168.2.93
```

If `rdp=` changed, store it in Remmina again (snippet above, once per profile).

## RDP does not connect

| Symptom | Cause | Fix |
|---|---|---|
| Remmina asks for RDP credentials | Keyring entry missing or old password | Store the password (snippet above) |
| Remmina hangs on "Connecting", log shows `Aborting handover` | Handover to the login screen failed | Not seen on 26.04 yet. First try (untested): reboot the VM, reconnect. On 24.04 this is a known bug (LP #2141992) — the reason for 26.04 |
| Connection refused | System daemon not running, or new DHCP address | `sudo grdctl --system status`; check the IP (see Access) |
| Login screen rejects the password | `login=` not applied on this VM | Run `setup-remote-login.sh <ip>` |
| Picture too big, right side cut off | Remmina runs native Wayland on the fractionally scaled laptop screen | Start Remmina with `GDK_BACKEND=x11` |

Server log: `ssh tt@<ip> 'sudo journalctl -u gnome-remote-desktop -n 30'`. A good connect shows
`Sending server redirection`, then the user service `gnome-remote-desktop-handover.service` starting.

To tell a VM problem from a client problem, look at what the VM's own screen shows:

```bash
ssh pve 'echo "screendump /tmp/vm104.ppm" | qm monitor 104' && scp pve:/tmp/vm104.ppm .
```

## Cowork gate: is the sandbox VM running?

Cowork runs shell commands inside its own KVM microVM, nested inside `agent-cowork`. The sandbox image is
only downloaded when the first Cowork task starts.

```bash
ssh tt@192.168.2.99
kvm-ok                                             # must say "KVM acceleration can be used"
tail -n 30 ~/.config/Claude/logs/cowork_vm_node.log
```

| Log line | Meaning | Action |
|---|---|---|
| `Startup complete` | Sandbox VM is running | Done |
| `[Bundle:status] rootfs.img missing` only | No Cowork task has run yet | Start a small task |
| `VM not supported (linux/x64), skipping` | The app's support check failed (GH anthropics/claude-code #74605, #77348) | See below |
| `VM guest is not connected` in a task | Same root cause, seen from inside a session | See below |

Fix attempt for the virtiofsd probe bug:

```bash
sudo ln -sf /usr/libexec/virtiofsd /usr/bin/virtiofsd   # or the bundled /usr/lib/claude-desktop/resources/virtiofsd
pkill -f claude-desktop                                 # closing the window is not enough, the check is cached
```

Then start Claude again from the desktop. If the log still says `VM not supported`, the Linux beta does
not work here yet. Fallback: the Windows 11 VM 101 (already `cpu: host`), with the `.msix` installer and
the `VirtualMachinePlatform` feature on.

## Updates

- `sudo apt update && sudo apt upgrade` on either VM — also updates `claude-desktop` (Anthropic apt repo)
  and `chatgpt` (its `.deb` registers `/etc/apt/sources.list.d/chatgpt.sources`).
- Codex CLI: run the installer again (`curl -fsSL https://chatgpt.com/codex/install.sh | sh`).
- After an app update that breaks something: roll back with the Proxmox snapshot (below).

## Snapshots

```bash
ssh pve 'qm snapshot 104 <name>'      # before app updates
ssh pve 'qm listsnapshot 104'
ssh pve 'qm rollback 104 <name>'
```

Snapshots hold thin-pool blocks. Delete old ones — `local-lvm` is overcommitted (see ADR-018).

## Rebuild from scratch

1. `ssh pve 'qm stop 104 && qm destroy 104 --purge 1 --destroy-unreferenced-disks 1'` — **deletes the disk
   and everything on it.** Note the MAC first (`qm config 104 | grep net0`).
2. Follow [`infrastructure/agent-vms/README.md`](../../infrastructure/agent-vms/README.md), reusing the MAC.
3. `ssh-keygen -R <ip>` on the laptop — the VM has a new host key.
4. Remove the old machine from the Tailscale admin console and from claude.ai / ChatGPT connected devices.
