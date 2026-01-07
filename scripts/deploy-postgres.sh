#!/bin/bash
# Deploy PostgreSQL with automatic secrets merging
# This script automatically merges values-homelab.yaml with secrets/postgres-secrets.yaml

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Deploying PostgreSQL with secrets..."
echo "Values: applications/postgres/values-homelab.yaml"
echo "Secrets: secrets/postgres-secrets.yaml"

helm upgrade --install postgres bitnami/postgresql \
  -f "$PROJECT_ROOT/applications/postgres/values-homelab.yaml" \
  -f "$PROJECT_ROOT/secrets/postgres-secrets.yaml" \
  -n data --create-namespace

echo "PostgreSQL deployment complete!"
echo "Verify: kubectl get pods -n data"
