#!/bin/bash
# Deploy n8n with automatic secrets merging
# This script automatically merges values-homelab.yaml with secrets/n8n-secrets.yaml

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# Always target the home-lab cluster explicitly. Without this, helm used whatever
# kubectl context was current - on 2026-09-28 that was flowkraft-hetzner, and this
# script installed n8n into the wrong cluster. No --create-namespace either, so a
# wrong context fails instead of creating a namespace there.
KUBE_CONTEXT="${KUBE_CONTEXT:-default}"

echo "Deploying n8n with secrets..."
echo "Values: applications/n8n/values-homelab.yaml"
echo "Secrets: secrets/n8n-secrets.yaml"

helm --kube-context "$KUBE_CONTEXT" upgrade --install n8n community-charts/n8n \
  --version 1.24.41 \
  --history-max 5 \
  -f "$PROJECT_ROOT/applications/n8n/values-homelab.yaml" \
  -f "$PROJECT_ROOT/secrets/n8n-secrets.yaml" \
  -n apps

echo "n8n deployment complete!"
echo "Verify: kubectl --context $KUBE_CONTEXT get pods -n apps"
