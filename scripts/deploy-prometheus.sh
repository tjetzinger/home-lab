#!/bin/bash
# Deploy kube-prometheus-stack with automatic secrets merging
# This script automatically merges values-homelab.yaml with grafana-secrets.yaml and ntfy-secrets.yaml

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Deploying kube-prometheus-stack with secrets..."
echo "Values: monitoring/prometheus/values-homelab.yaml"
echo "Secrets: secrets/grafana-secrets.yaml, secrets/ntfy-secrets.yaml"

helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -f "$PROJECT_ROOT/monitoring/prometheus/values-homelab.yaml" \
  -f "$PROJECT_ROOT/secrets/grafana-secrets.yaml" \
  -f "$PROJECT_ROOT/secrets/ntfy-secrets.yaml" \
  -n monitoring --create-namespace

echo "kube-prometheus-stack deployment complete!"
echo "Verify: kubectl get pods -n monitoring"
