#!/bin/bash
# Fixes both agent VMs need, found in operation (see ADR-018). Run with sudo bash after provision-*.sh.
set -euxo pipefail

# German keyboard, matching Tom's laptop. GDM, the desktop and the console read these.
localectl set-x11-keymap de "" nodeadkeys
localectl set-keymap de-latin1-nodeadkeys || true
sed -i 's/^XKBLAYOUT=.*/XKBLAYOUT="de"/; s/^XKBVARIANT=.*/XKBVARIANT="nodeadkeys"/' /etc/default/keyboard

# Disable KVM paravirtual async page faults. With pve kernel 6.8, a lost "page ready" notification
# left tasks hung forever in kvm_async_pf_task_wait_schedule once pve swapped VM memory (2026-10-02).
cat > /etc/default/grub.d/90-no-kvmapf.cfg <<'EOF'
# Disable KVM paravirtual async page faults (home-lab ADR-018).
GRUB_CMDLINE_LINUX_DEFAULT="$GRUB_CMDLINE_LINUX_DEFAULT no-kvmapf"
EOF
update-grub

# unattended-upgrades restarts the system RDP daemon after library updates (e.g. libssl). The
# handover daemon in tt's running remote session then loses it and never retries, so logins bounce
# back to the login screen. Restart it whenever the system daemon starts. "+" runs the step as root:
# the service itself runs as user gnome-remote-desktop.
mkdir -p /etc/systemd/system/gnome-remote-desktop.service.d
cat > /etc/systemd/system/gnome-remote-desktop.service.d/restart-user-handover.conf <<'EOF'
# Restart tt's handover daemon after the system RDP daemon restarts (home-lab ADR-018).
[Service]
ExecStartPost=-+/bin/sh -c 'sleep 3; systemctl --user --machine=tt@ restart gnome-remote-desktop-handover.service'
EOF
systemctl daemon-reload

echo PROVISION_COMMON_DONE
