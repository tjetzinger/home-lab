#!/bin/bash
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get -y upgrade
apt-get -y install ubuntu-desktop-minimal qemu-guest-agent cpu-checker curl gnupg \
  qemu-system-x86 ovmf virtiofsd
usermod -aG kvm tt
systemctl enable --now qemu-guest-agent
curl -fsSL https://tailscale.com/install.sh | sh
curl -fsSLo /usr/share/keyrings/claude-desktop-archive-keyring.asc https://downloads.claude.ai/claude-desktop/key.asc
gpg --show-keys /usr/share/keyrings/claude-desktop-archive-keyring.asc | tee /root/claude-key.txt
grep -q 31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE /root/claude-key.txt
echo "deb [arch=amd64,arm64 signed-by=/usr/share/keyrings/claude-desktop-archive-keyring.asc] https://downloads.claude.ai/claude-desktop/apt/stable stable main" > /etc/apt/sources.list.d/claude-desktop.list
apt-get update
apt-get -y install claude-desktop
systemctl set-default graphical.target
echo PROVISION_DONE
