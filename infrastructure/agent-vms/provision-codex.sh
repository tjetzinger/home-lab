#!/bin/bash
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get -y upgrade
apt-get -y install ubuntu-desktop-minimal qemu-guest-agent curl gnupg git bubblewrap
systemctl enable --now qemu-guest-agent
curl -fsSL https://tailscale.com/install.sh | sh
curl -fsSLo /tmp/chatgpt_amd64.deb https://persistent.oaistatic.com/codex-app-prod/linux/deb/latest/chatgpt_amd64.deb
dpkg-deb -f /tmp/chatgpt_amd64.deb Package Version Maintainer Homepage | tee /root/chatgpt-deb-info.txt
grep -qi openai /root/chatgpt-deb-info.txt
apt-get -y install /tmp/chatgpt_amd64.deb
sudo -u tt bash -c 'curl -fsSL https://chatgpt.com/codex/install.sh | sh'
systemctl set-default graphical.target
echo PROVISION_DONE
