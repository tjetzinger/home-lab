#!/bin/bash
# K3s Kubeconfig Setup Script
# Usage: ./kubeconfig-setup.sh [MASTER_IP]
#
# This script copies the kubeconfig from the K3s master and configures it
# for remote access via the specified IP address.
#
# Prerequisites:
#   - SSH access to the K3s master node
#   - kubectl installed locally (or will be reminded to install)
#
# Default master IP: 192.168.2.20

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Configuration
MASTER_IP="${1:-192.168.2.20}"
KUBECONFIG_SOURCE="/etc/rancher/k3s/k3s.yaml"
KUBECONFIG_DEST="${HOME}/.kube/config"
K3S_API_PORT="6443"

log_info "K3s Kubeconfig Setup Script"
log_info "============================"
log_info "Master IP: $MASTER_IP"
log_info "Kubeconfig destination: $KUBECONFIG_DEST"

# Create .kube directory if it doesn't exist
if [ ! -d "${HOME}/.kube" ]; then
    log_info "Creating ${HOME}/.kube directory..."
    mkdir -p "${HOME}/.kube"
fi

# Backup existing kubeconfig if it exists
if [ -f "$KUBECONFIG_DEST" ]; then
    BACKUP_FILE="${KUBECONFIG_DEST}.backup.$(date +%Y%m%d_%H%M%S)"
    log_warn "Existing kubeconfig found, backing up to: $BACKUP_FILE"
    cp "$KUBECONFIG_DEST" "$BACKUP_FILE"
fi

# Copy kubeconfig from master
log_info "Copying kubeconfig from master..."
if ! ssh "root@${MASTER_IP}" "cat ${KUBECONFIG_SOURCE}" > "$KUBECONFIG_DEST" 2>/dev/null; then
    log_error "Failed to copy kubeconfig from ${MASTER_IP}"
    log_error "Please verify:"
    log_error "  1. SSH access to root@${MASTER_IP}"
    log_error "  2. K3s is installed and running on the master"
    log_error "  3. ${KUBECONFIG_SOURCE} exists on the master"
    exit 1
fi

# Update server URL from localhost to master IP
log_info "Updating server URL to https://${MASTER_IP}:${K3S_API_PORT}..."
sed -i "s|server: https://127.0.0.1:${K3S_API_PORT}|server: https://${MASTER_IP}:${K3S_API_PORT}|g" "$KUBECONFIG_DEST"

# Set proper permissions (600 = owner read/write only)
log_info "Setting kubeconfig permissions to 600..."
chmod 600 "$KUBECONFIG_DEST"

# Verify kubeconfig was updated correctly
if grep -q "server: https://${MASTER_IP}:${K3S_API_PORT}" "$KUBECONFIG_DEST"; then
    log_info "Server URL updated successfully"
else
    log_error "Failed to update server URL in kubeconfig"
    exit 1
fi

# Test kubectl if available
if command -v kubectl &> /dev/null; then
    log_info "Testing kubectl connection..."
    if kubectl get nodes --request-timeout=5s &> /dev/null; then
        log_info ""
        log_info "============================"
        log_info "Kubeconfig Setup Complete!"
        log_info "============================"
        log_info ""
        kubectl get nodes
        log_info ""
        log_info "You can now use kubectl to manage the cluster."
    else
        log_warn "kubectl test failed - this may be normal if:"
        log_warn "  - You're not connected to Tailscale"
        log_warn "  - You're not on the same network as the cluster"
        log_warn "Kubeconfig has been saved. Try connecting to Tailscale and retry."
    fi
else
    log_warn "kubectl not found. Please install kubectl to use the cluster."
    log_warn "  Arch Linux: sudo pacman -S kubectl"
    log_warn "  Ubuntu/Debian: sudo apt install kubectl"
    log_warn "  macOS: brew install kubectl"
fi

log_info ""
log_info "Kubeconfig saved to: $KUBECONFIG_DEST"
log_info ""
log_info "For remote access, ensure:"
log_info "  1. Tailscale is connected"
log_info "  2. Subnet routing for 192.168.2.0/24 is enabled"
