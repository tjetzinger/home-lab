#!/bin/bash
# Deploy n8n with automatic secrets merging
# This script automatically merges values-homelab.yaml with secrets/n8n-secrets.yaml

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Deploying n8n with secrets..."
echo "Values: applications/n8n/values-homelab.yaml"
echo "Secrets: secrets/n8n-secrets.yaml"

helm upgrade --install n8n community-charts/n8n \
  -f "$PROJECT_ROOT/applications/n8n/values-homelab.yaml" \
  -f "$PROJECT_ROOT/secrets/n8n-secrets.yaml" \
  -n apps --create-namespace

echo "n8n deployment complete!"
echo "Verify: kubectl get pods -n apps"
