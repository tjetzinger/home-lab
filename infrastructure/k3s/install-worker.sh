#!/bin/bash
# K3s Worker Node Installation Script
# Usage: ./install-worker.sh <K3S_URL> <K3S_TOKEN>
#
# Example:
#   ./install-worker.sh https://192.168.2.20:6443 K1021a...token...
#
# Prerequisites:
#   - Ubuntu 22.04 LXC container with K3s-compatible config
#   - Network connectivity to K3s control plane
#   - curl installed
#
# For LXC containers, ensure these settings are applied to /etc/pve/lxc/<VMID>.conf:
#   features: nesting=1,keyctl=1,fuse=1
#   lxc.mount.entry: /dev/kmsg dev/kmsg none bind,rw,optional,create=file
#   lxc.apparmor.profile: unconfined
#   lxc.cap.drop:
#   lxc.cgroup2.devices.allow: a
#   lxc.mount.auto: proc:rw sys:rw
#
# See: infrastructure/k3s/lxc-k3s-config.conf

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check arguments
if [ $# -lt 2 ]; then
    echo "Usage: $0 <K3S_URL> <K3S_TOKEN>"
    echo ""
    echo "Example:"
    echo "  $0 https://192.168.2.20:6443 K1021a...token..."
    echo ""
    echo "To get the token from the master node:"
    echo "  sudo cat /var/lib/rancher/k3s/server/node-token"
    exit 1
fi

K3S_URL="$1"
K3S_TOKEN="$2"

log_info "K3s Worker Installation Script"
log_info "==============================="
log_info "Server URL: $K3S_URL"
log_info "Token: ${K3S_TOKEN:0:20}...${K3S_TOKEN: -10}"

# Pre-flight checks
log_info "Running pre-flight checks..."

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_error "This script must be run as root"
    exit 1
fi

# Check if curl is installed
if ! command -v curl &> /dev/null; then
    log_warn "curl not found, installing..."
    apt-get update -qq && apt-get install -y -qq curl
fi

# Check connectivity to control plane
log_info "Checking connectivity to control plane..."
if ! curl -sk --connect-timeout 5 "$K3S_URL" > /dev/null 2>&1; then
    log_error "Cannot reach K3s control plane at $K3S_URL"
    log_error "Please verify:"
    log_error "  1. The control plane is running"
    log_error "  2. Network connectivity from this node"
    log_error "  3. Firewall rules allow port 6443"
    exit 1
fi
log_info "Control plane reachable"

# Check if K3s agent is already installed
if systemctl is-active --quiet k3s-agent 2>/dev/null; then
    log_warn "K3s agent is already running"
    log_warn "To reinstall, first run: /usr/local/bin/k3s-agent-uninstall.sh"
    exit 1
fi

# Install K3s agent
log_info "Installing K3s agent..."
curl -sfL https://get.k3s.io | K3S_URL="$K3S_URL" K3S_TOKEN="$K3S_TOKEN" sh -

# Wait for agent to start
log_info "Waiting for K3s agent to start..."
sleep 5

# Verify installation
if systemctl is-active --quiet k3s-agent; then
    log_info "K3s agent service is running"
else
    log_error "K3s agent failed to start"
    log_error "Check logs with: journalctl -u k3s-agent -f"
    exit 1
fi

log_info ""
log_info "==============================="
log_info "K3s Worker Installation Complete!"
log_info "==============================="
log_info ""
log_info "Next steps:"
log_info "  1. On the master node, verify this worker joined:"
log_info "     kubectl get nodes"
log_info ""
log_info "  2. Check agent logs if needed:"
log_info "     journalctl -u k3s-agent -f"
log_info ""
log_info "To uninstall:"
log_info "  /usr/local/bin/k3s-agent-uninstall.sh"
