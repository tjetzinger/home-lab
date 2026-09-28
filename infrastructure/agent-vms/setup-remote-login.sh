#!/bin/bash
# Configure GNOME Remote Login (RDP -> GDM login screen -> headless session that follows the client
# window size and keeps running after disconnect). Needs Ubuntu 26.04 / GNOME 50: the 24.04 backport
# aborts the handover (LP: #2141992).
#
# Run on Tom's laptop:  bash setup-remote-login.sh <lan-ip>
#   e.g.                bash setup-remote-login.sh 192.168.2.93
# Both VMs share one pair of credentials in ~/.config/agent-vms/rdp-credentials (generated if missing):
#   rdp=...    RDP password, user tt (saved in Remmina)
#   login=...  Linux password of tt (GDM login screen)
# To use your own passwords, edit that file and run this script again for each VM.
set -euo pipefail
ip=$1
creds=~/.config/agent-vms/rdp-credentials
umask 077

new_password() { openssl rand -base64 18 | tr -d '/+='; }
grep -q '^rdp=' "$creds" 2>/dev/null || echo "rdp=$(new_password)" >> "$creds"
grep -q '^login=' "$creds" || echo "login=$(new_password)" >> "$creds"
rdp_password=$(grep '^rdp=' "$creds" | cut -d= -f2-)
login_password=$(grep '^login=' "$creds" | cut -d= -f2-)

# First two input lines carry the passwords, the rest is the script (bash reads them unbuffered)
{ printf '%s\n%s\n' "$rdp_password" "$login_password"; cat <<'REMOTE'; } | \
  ssh -o BatchMode=yes "tt@${ip}" 'IFS= read -r rdp_password; IFS= read -r login_password; export rdp_password login_password; exec bash -s'
set -euo pipefail

echo "tt:${login_password}" | sudo chpasswd
sudo chfn -f tt tt   # cloud-init names the user "Ubuntu" on the login screen

tls_dir=/var/lib/gnome-remote-desktop/.local/share/gnome-remote-desktop
sudo -u gnome-remote-desktop mkdir -p "$tls_dir"
sudo -u gnome-remote-desktop openssl req -x509 -newkey rsa:4096 -nodes -days 3650 \
  -subj "/CN=$(hostname)" -keyout "$tls_dir/tls.key" -out "$tls_dir/tls.crt" 2>/dev/null
sudo grdctl --system rdp set-tls-key "$tls_dir/tls.key"
sudo grdctl --system rdp set-tls-cert "$tls_dir/tls.crt"
sudo grdctl --system rdp set-credentials tt "$rdp_password"
sudo grdctl --system rdp enable
sudo systemctl enable --now gnome-remote-desktop.service
sudo grdctl --system status 2>&1 | grep -v TPM
REMOTE
