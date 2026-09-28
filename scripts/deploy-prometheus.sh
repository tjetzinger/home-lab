#!/bin/bash
# Deploy kube-prometheus-stack with automatic secrets merging
# This script automatically merges values-homelab.yaml with grafana-secrets.yaml and ntfy-secrets.yaml

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# Always target the home-lab cluster explicitly. Without this, helm used whatever
# kubectl context was current - on 2026-09-28 that was flowkraft-hetzner, and this
# script installed n8n into the wrong cluster. No --create-namespace either, so a
# wrong context fails instead of creating a namespace there.
KUBE_CONTEXT="${KUBE_CONTEXT:-default}"

echo "Deploying kube-prometheus-stack with secrets..."
echo "Values: monitoring/prometheus/values-homelab.yaml"
echo "Secrets: secrets/grafana-secrets.yaml, secrets/ntfy-secrets.yaml"

helm --kube-context "$KUBE_CONTEXT" upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --version 91.4.1 \
  -f "$PROJECT_ROOT/monitoring/prometheus/values-homelab.yaml" \
  -f "$PROJECT_ROOT/secrets/grafana-secrets.yaml" \
  -f "$PROJECT_ROOT/secrets/ntfy-secrets.yaml" \
  -n monitoring

echo "kube-prometheus-stack deployment complete!"
echo "Verify: kubectl --context $KUBE_CONTEXT get pods -n monitoring"
