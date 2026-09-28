#!/bin/bash
# Configure GNOME Remote Desktop (RDP, desktop sharing of the auto-login session) for Remmina.
# Run as tt on the VM, over SSH. Reads the RDP password from stdin:
#   grep '^agent-cowork=' ~/.config/agent-vms/rdp-credentials | cut -d= -f2 | ssh tt@<vm> 'bash -s' < setup-rdp.sh
# Phase 1 creates the keyring and needs a reboot before phase 2 can store credentials.
set -euo pipefail
export XDG_RUNTIME_DIR=/run/user/$(id -u)
export DBUS_SESSION_BUS_ADDRESS=unix:path=$XDG_RUNTIME_DIR/bus

keyrings=~/.local/share/keyrings
tls_dir=~/.local/share/gnome-remote-desktop

if [ ! -f "$keyrings/Default_keyring.keyring" ]; then
  # Unencrypted keyring: auto-login cannot unlock a password-protected one, and both
  # RDP credentials and the apps' sign-in tokens live here.
  mkdir -p "$keyrings" && chmod 700 "$keyrings"
  printf '[keyring]\ndisplay-name=Default keyring\nctime=0\nmtime=0\nlock-on-idle=false\nlock-after=false\n' \
    > "$keyrings/Default_keyring.keyring"
  chmod 600 "$keyrings/Default_keyring.keyring"
  echo Default_keyring > "$keyrings/default"

  gsettings set org.gnome.desktop.screensaver lock-enabled false
  gsettings set org.gnome.desktop.session idle-delay 0
  gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type nothing
  gsettings set org.gnome.settings-daemon.plugins.power idle-dim false

  mkdir -p "$tls_dir"
  openssl req -x509 -newkey rsa:4096 -nodes -days 3650 -subj "/CN=$(hostname)" \
    -keyout "$tls_dir/tls.key" -out "$tls_dir/tls.crt" 2>/dev/null
  chmod 600 "$tls_dir/tls.key"
  grdctl rdp set-tls-key "$tls_dir/tls.key"
  grdctl rdp set-tls-cert "$tls_dir/tls.crt"
  echo "PHASE1_DONE: reboot the VM (qm reboot <vmid>), then run this script again"
  exit 0
fi

read -r rdp_password
grdctl rdp disable
timeout 20 grdctl rdp set-credentials tt "$rdp_password"
grdctl rdp disable-view-only
grdctl rdp enable
systemctl --user enable gnome-remote-desktop.service
systemctl --user restart gnome-remote-desktop.service
grdctl status
echo PHASE2_DONE
