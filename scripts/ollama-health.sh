#!/bin/bash
# Ollama Health Check Script
# Validates Ollama API availability, model availability, and basic inference
#
# Exit codes:
# 0 - All healthy
# 1 - API unreachable
# 2 - Model not available
# 3 - Inference failed
# 4 - Performance degraded (>30s response time)
#
# Usage: ./scripts/ollama-health.sh [--external]
#        --external: Test against https://ollama.home.jetzinger.com (default)
#        --internal: Test against http://ollama.ml.svc.cluster.local:11434
#
# Created: Story 6.2 - Test Ollama API and Model Inference

set -euo pipefail

# Configuration
OLLAMA_ENDPOINT="${OLLAMA_ENDPOINT:-https://ollama.home.jetzinger.com}"
OLLAMA_MODEL="${OLLAMA_MODEL:-llama3.2:1b}"
RESPONSE_TIME_THRESHOLD=30
TEST_PROMPT="Hello"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --internal)
            OLLAMA_ENDPOINT="http://ollama.ml.svc.cluster.local:11434"
            shift
            ;;
        --external)
            OLLAMA_ENDPOINT="https://ollama.home.jetzinger.com"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--external|--internal]"
            exit 1
            ;;
    esac
done

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters
CHECKS_PASSED=0
CHECKS_FAILED=0
WARNINGS=0

print_header() {
    echo ""
    echo "======================================"
    echo "  Ollama Health Check"
    echo "======================================"
    echo "  Endpoint: $OLLAMA_ENDPOINT"
    echo "  Model: $OLLAMA_MODEL"
    echo "======================================"
    echo ""
}

print_result() {
    local check_name="$1"
    local status="$2"
    local details="${3:-}"

    if [[ "$status" == "PASS" ]]; then
        echo -e "[${GREEN}PASS${NC}] $check_name"
        ((CHECKS_PASSED++))
    elif [[ "$status" == "WARN" ]]; then
        echo -e "[${YELLOW}WARN${NC}] $check_name"
        if [[ -n "$details" ]]; then
            echo "       $details"
        fi
        ((WARNINGS++))
    else
        echo -e "[${RED}FAIL${NC}] $check_name"
        if [[ -n "$details" ]]; then
            echo "       $details"
        fi
        ((CHECKS_FAILED++))
    fi
}

# Check 1: API Endpoint Accessibility
check_api_accessibility() {
    echo "Checking API endpoint accessibility..."

    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" "$OLLAMA_ENDPOINT/api/tags" 2>/dev/null || echo "000")

    if [[ "$http_code" == "200" ]]; then
        print_result "API endpoint accessible ($OLLAMA_ENDPOINT)" "PASS"
        return 0
    else
        print_result "API endpoint accessible" "FAIL" "HTTP $http_code"
        return 1
    fi
}

# Check 2: Model Availability
check_model_availability() {
    echo "Checking model availability..."

    local models_response
    models_response=$(curl -s "$OLLAMA_ENDPOINT/api/tags" 2>/dev/null || echo "{}")

    if ! command -v jq &> /dev/null; then
        print_result "Model availability check" "WARN" "jq not installed, skipping"
        return 0
    fi

    if echo "$models_response" | jq -e ".models[] | select(.name == \"$OLLAMA_MODEL\")" > /dev/null 2>&1; then
        local model_size
        model_size=$(echo "$models_response" | jq -r ".models[] | select(.name == \"$OLLAMA_MODEL\") | .size" | numfmt --to=iec 2>/dev/null || echo "unknown")
        print_result "Model $OLLAMA_MODEL available (size: $model_size)" "PASS"
        return 0
    else
        print_result "Model $OLLAMA_MODEL available" "FAIL" "Model not found in API response"
        return 2
    fi
}

# Check 3: Basic Inference Test
check_inference() {
    echo "Checking basic inference..."

    local start_time
    local end_time
    local response_time
    local response

    start_time=$(date +%s)

    response=$(curl -s "$OLLAMA_ENDPOINT/api/generate" -d "{
        \"model\": \"$OLLAMA_MODEL\",
        \"prompt\": \"$TEST_PROMPT\",
        \"stream\": false
    }" 2>/dev/null || echo "{}")

    end_time=$(date +%s)
    response_time=$((end_time - start_time))

    if ! command -v jq &> /dev/null; then
        print_result "Inference test" "WARN" "jq not installed, skipping"
        return 0
    fi

    if echo "$response" | jq -e '.response' > /dev/null 2>&1; then
        local response_text
        response_text=$(echo "$response" | jq -r '.response' | head -c 50)

        if [[ $response_time -le $RESPONSE_TIME_THRESHOLD ]]; then
            print_result "Inference successful (${response_time}s)" "PASS" "Response: \"$response_text...\""
        else
            print_result "Inference successful (${response_time}s)" "WARN" "Response time exceeds ${RESPONSE_TIME_THRESHOLD}s threshold (NFR13)"
        fi
        return 0
    else
        print_result "Inference test" "FAIL" "No response from API"
        return 3
    fi
}

# Print summary
print_summary() {
    echo ""
    echo "======================================"
    echo "  Summary"
    echo "======================================"
    echo ""
    echo -e "Checks passed: ${GREEN}$CHECKS_PASSED${NC}"
    echo -e "Warnings:      ${YELLOW}$WARNINGS${NC}"
    echo -e "Checks failed: ${RED}$CHECKS_FAILED${NC}"
    echo ""
}

# Main
main() {
    local exit_code=0

    print_header

    # Run checks, capture first failure exit code
    check_api_accessibility || exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        check_model_availability || exit_code=$?
    fi

    if [[ $exit_code -eq 0 ]]; then
        check_inference || exit_code=$?
    fi

    print_summary

    if [[ $CHECKS_FAILED -gt 0 ]]; then
        echo -e "${RED}OLLAMA HEALTH: DEGRADED${NC}"
        exit "${exit_code:-1}"
    elif [[ $WARNINGS -gt 0 ]]; then
        echo -e "${YELLOW}OLLAMA HEALTH: OK (with warnings)${NC}"
        exit 0
    else
        echo -e "${GREEN}OLLAMA HEALTH: OK${NC}"
        exit 0
    fi
}

main "$@"
