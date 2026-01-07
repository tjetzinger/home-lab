#!/bin/bash
#
# K3s Master Node Installation Script
# ====================================
# Project: home-lab
# Story: 1.1 - Create K3s Control Plane
#
# Prerequisites:
#   - Ubuntu Server 22.04 LTS installed on VM
#   - VM configured with:
#     - Hostname: k3s-master
#     - IP: 192.168.2.20/24
#     - Gateway: 192.168.2.1
#     - 2 vCPU, 4GB RAM, 32GB disk
#   - SSH access working
#   - Internet connectivity for downloading K3s
#
# Usage:
#   chmod +x install-master.sh
#   ./install-master.sh
#
# What this script does:
#   1. Installs K3s server with kubeconfig mode 644
#   2. Waits for K3s to be ready
#   3. Displays node status and token location
#
# References:
#   - K3s Official Docs: https://docs.k3s.io/installation
#   - Architecture Decision: architecture.md#Infrastructure Management Approach
#

set -e  # Exit on any error

echo "=========================================="
echo "  K3s Master Node Installation"
echo "  Project: home-lab"
echo "=========================================="
echo ""

# Pre-flight checks
echo "[1/5] Running pre-flight checks..."

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then
    echo "  Please run as root or with sudo"
    exit 1
fi

# Check hostname
HOSTNAME=$(hostname)
echo "  Hostname: $HOSTNAME"

# Check IP address
IP=$(hostname -I | awk '{print $1}')
echo "  IP Address: $IP"

# Verify expected IP (optional check)
EXPECTED_IP="192.168.2.20"
if [ "$IP" != "$EXPECTED_IP" ]; then
    echo "  WARNING: Expected IP $EXPECTED_IP but found $IP"
    echo "  Continuing anyway..."
fi

echo "  Pre-flight checks complete."
echo ""

# Install K3s
echo "[2/5] Installing K3s server..."
echo "  Running: curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644"
echo ""

curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644

echo ""
echo "  K3s installation complete."
echo ""

# Wait for K3s to be ready
echo "[3/5] Waiting for K3s to be ready..."
sleep 10  # Give K3s time to start

# Check K3s service status
echo "[4/5] Checking K3s service status..."
systemctl status k3s --no-pager || true
echo ""

# Display node status
echo "[5/5] Verifying cluster status..."
echo ""
echo "Node Status:"
kubectl get nodes
echo ""

echo "System Pods:"
kubectl get pods -n kube-system
echo ""

# Display important information
echo "=========================================="
echo "  Installation Complete!"
echo "=========================================="
echo ""
echo "Important Information:"
echo "  - Kubeconfig: /etc/rancher/k3s/k3s.yaml"
echo "  - Node Token: /var/lib/rancher/k3s/server/node-token"
echo ""
echo "Node Token (for worker join):"
# Note: This file is only readable by root
cat /var/lib/rancher/k3s/server/node-token
echo ""
echo ""
echo "Next Steps:"
echo "  1. Copy kubeconfig to your local machine for remote access"
echo "  2. Run Story 1.2 to add worker nodes"
echo ""
echo "To copy kubeconfig locally (run from your workstation):"
echo "  scp user@$IP:/etc/rancher/k3s/k3s.yaml ~/.kube/config"
echo "  # Replace 'user' with your SSH username"
echo "  # Then update the server URL in the kubeconfig to https://$IP:6443"
echo ""
