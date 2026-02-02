#!/bin/bash
set -euo pipefail

NAMESPACE="apps"

echo "Applying openclaw deployment..."
kubectl apply -f "$(dirname "$0")/deployment.yaml"

echo "Waiting for rollout..."
kubectl rollout status deployment/openclaw -n "${NAMESPACE}" --timeout=120s

echo "Deployment complete!"
echo ""
echo "Verify:"
echo "  kubectl get pods -n apps -l app.kubernetes.io/name=openclaw"
echo "  kubectl logs -n apps deployment/openclaw -c openclaw --tail=20"
echo "  kubectl logs -n apps deployment/openclaw -c sandbox-browser --tail=20"
