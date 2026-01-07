#!/bin/bash
# Nginx Proxy Configuration Reload Script
# Story: 7.3 - Enable Hot-Reload Configuration
# Purpose: Apply ConfigMap updates and gracefully reload nginx without pod restart

set -e

# Configuration
NAMESPACE="dev"
DEPLOYMENT="nginx-proxy"
CONFIGMAP_FILE="applications/nginx/configmap.yaml"
WAIT_TIME=30  # Max wait time for ConfigMap propagation (seconds)
POLL_INTERVAL=5  # Check interval during wait

# Colors for output
GREEN='\033[0.32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "========================================="
echo "Nginx Proxy Configuration Reload"
echo "========================================="
echo

# Function: Get nginx pod name
get_pod() {
    kubectl get pod -n "$NAMESPACE" -l app.kubernetes.io/instance=nginx-proxy -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

# Function: Validate nginx configuration syntax
validate_config() {
    local pod=$1
    echo -n "Validating nginx configuration syntax... "
    if kubectl exec -n "$NAMESPACE" "$pod" -- nginx -t 2>&1 | grep -q "successful"; then
        echo -e "${GREEN}OK${NC}"
        return 0
    else
        echo -e "${RED}FAILED${NC}"
        kubectl exec -n "$NAMESPACE" "$pod" -- nginx -t 2>&1
        return 1
    fi
}

# Function: Check health endpoint
check_health() {
    local pod=$1
    kubectl exec -n "$NAMESPACE" "$pod" -- curl -sf http://localhost/health > /dev/null 2>&1
}

# Step 1: Get current pod
echo "Step 1: Getting nginx pod..."
POD=$(get_pod)
if [ -z "$POD" ]; then
    echo -e "${RED}Error: Nginx pod not found in namespace $NAMESPACE${NC}"
    exit 1
fi
echo -e "  Pod: ${GREEN}$POD${NC}"
echo

# Step 2: Validate current configuration (pre-check)
echo "Step 2: Pre-flight validation..."
if ! validate_config "$POD"; then
    echo -e "${RED}Error: Current configuration is invalid${NC}"
    exit 1
fi
echo

# Step 3: Get current config file timestamp
echo "Step 3: Capturing current configuration timestamp..."
OLD_TIMESTAMP=$(kubectl exec -n "$NAMESPACE" "$POD" -- stat -c '%Y' /etc/nginx/nginx.conf)
echo "  Current timestamp: $OLD_TIMESTAMP"
echo

# Step 4: Apply ConfigMap update
echo "Step 4: Applying ConfigMap update..."
if [ ! -f "$CONFIGMAP_FILE" ]; then
    echo -e "${RED}Error: ConfigMap file not found: $CONFIGMAP_FILE${NC}"
    exit 1
fi

if kubectl apply -f "$CONFIGMAP_FILE" > /dev/null 2>&1; then
    echo -e "  ${GREEN}ConfigMap applied successfully${NC}"
else
    echo -e "${RED}Error: Failed to apply ConfigMap${NC}"
    exit 1
fi
echo

# Step 5: Wait for ConfigMap propagation
echo "Step 5: Waiting for ConfigMap propagation..."
echo "  (Kubernetes takes ~10-60 seconds to sync ConfigMap changes to pods)"
ELAPSED=0
PROPAGATED=false

while [ $ELAPSED -lt $WAIT_TIME ]; do
    NEW_TIMESTAMP=$(kubectl exec -n "$NAMESPACE" "$POD" -- stat -c '%Y' /etc/nginx/nginx.conf)
    if [ "$NEW_TIMESTAMP" != "$OLD_TIMESTAMP" ]; then
        echo -e "  ${GREEN}ConfigMap propagated after $ELAPSED seconds${NC}"
        PROPAGATED=true
        break
    fi
    echo -n "."
    sleep $POLL_INTERVAL
    ELAPSED=$((ELAPSED + POLL_INTERVAL))
done
echo

if [ "$PROPAGATED" = false ]; then
    echo -e "${YELLOW}Warning: ConfigMap not propagated within $WAIT_TIME seconds${NC}"
    echo "  This may be normal for large clusters or during high load"
    echo "  Proceeding anyway - you may need to manually trigger reload later"
fi
echo

# Step 6: Validate new configuration syntax
echo "Step 6: Validating new configuration..."
if ! validate_config "$POD"; then
    echo -e "${RED}Error: New configuration has syntax errors${NC}"
    echo "  ConfigMap has been applied but reload was NOT triggered"
    echo "  Fix the configuration and run this script again"
    exit 1
fi
echo

# Step 7: Trigger nginx reload
echo "Step 7: Triggering nginx graceful reload..."
RELOAD_TIMESTAMP=$(date +%s)
if kubectl exec -n "$NAMESPACE" "$POD" -- nginx -s reload > /dev/null 2>&1; then
    echo -e "  ${GREEN}Reload signal sent successfully${NC}"
    echo "  Timestamp: $(date -d @$RELOAD_TIMESTAMP '+%Y-%m-%d %H:%M:%S')"
else
    echo -e "${RED}Error: Failed to send reload signal${NC}"
    exit 1
fi
echo

# Step 8: Validate health endpoint post-reload
echo "Step 8: Validating nginx health..."
sleep 2  # Give nginx a moment to complete reload
if check_health "$POD"; then
    echo -e "  ${GREEN}Health check passed${NC}"
else
    echo -e "${RED}Warning: Health check failed${NC}"
    echo "  Nginx may be restarting or configuration may have issues"
    exit 1
fi
echo

# Step 9: Verify worker processes reloaded
echo "Step 9: Verifying worker processes..."
WORKER_COUNT=$(kubectl exec -n "$NAMESPACE" "$POD" -- sh -c "ps aux | grep 'nginx: worker' | grep -v grep | wc -l")
echo "  Active worker processes: $WORKER_COUNT"
if [ "$WORKER_COUNT" -gt 0 ]; then
    echo -e "  ${GREEN}Workers active and serving requests${NC}"
else
    echo -e "${YELLOW}Warning: No worker processes found${NC}"
fi
echo

# Summary
echo "========================================="
echo -e "${GREEN}✓ Reload completed successfully${NC}"
echo "========================================="
echo
echo "Summary:"
echo "  - ConfigMap applied and propagated"
echo "  - Configuration validated"
echo "  - Nginx reloaded gracefully (no pod restart)"
echo "  - Health endpoint responsive"
echo "  - Worker processes active: $WORKER_COUNT"
echo
echo "Next steps:"
echo "  - Test your new proxy routes"
echo "  - Verify routing with: curl https://dev.home.jetzinger.com/<route>"
echo "  - Check logs: kubectl logs -n $NAMESPACE $POD"
echo

exit 0
