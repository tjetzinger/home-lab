#!/bin/bash
# Storage Health Check Script
# Validates NFS connectivity, PV/PVC status, and mount health
#
# Exit codes:
# 0 - All healthy
# 1 - NFS server unreachable
# 2 - PV/PVC status issues
# 3 - NFS export not visible
#
# Usage: ./scripts/health-check.sh
#
# Created: Story 2.3 - Verify Storage Mount Health

set -euo pipefail

# Configuration
NFS_SERVER="${NFS_SERVER:-192.168.2.2}"
NFS_EXPORT="${NFS_EXPORT:-/volume1/k8s-data}"
KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters
CHECKS_PASSED=0
CHECKS_FAILED=0

print_header() {
    echo ""
    echo "======================================"
    echo "  Storage Health Check"
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
    else
        echo -e "[${RED}FAIL${NC}] $check_name"
        if [[ -n "$details" ]]; then
            echo "       $details"
        fi
        ((CHECKS_FAILED++))
    fi
}

# Check 1: NFS Server Connectivity
check_nfs_connectivity() {
    echo "Checking NFS server connectivity..."

    if ping -c 1 -W 3 "$NFS_SERVER" > /dev/null 2>&1; then
        print_result "NFS server reachable ($NFS_SERVER)" "PASS"
        return 0
    else
        print_result "NFS server reachable ($NFS_SERVER)" "FAIL" "Cannot ping $NFS_SERVER"
        return 1
    fi
}

# Check 2: NFS Export Visibility
check_nfs_export() {
    echo "Checking NFS export visibility..."

    if ! command -v showmount &> /dev/null; then
        print_result "NFS export visible" "WARN" "showmount not installed, skipping"
        return 0
    fi

    if showmount -e "$NFS_SERVER" 2>/dev/null | grep -q "$NFS_EXPORT"; then
        print_result "NFS export visible ($NFS_EXPORT)" "PASS"
        return 0
    else
        print_result "NFS export visible ($NFS_EXPORT)" "FAIL" "Export not found"
        return 3
    fi
}

# Check 3: PV Status
check_pv_status() {
    echo "Checking PersistentVolume status..."

    if ! command -v kubectl &> /dev/null; then
        print_result "PV status check" "FAIL" "kubectl not found"
        return 2
    fi

    local pv_count
    local bound_count
    local problem_pvs

    pv_count=$(kubectl get pv --no-headers 2>/dev/null | wc -l)

    if [[ "$pv_count" -eq 0 ]]; then
        print_result "PV status check" "WARN" "No PVs found"
        return 0
    fi

    bound_count=$(kubectl get pv --no-headers 2>/dev/null | grep -c "Bound\|Available" || true)
    problem_pvs=$(kubectl get pv --no-headers 2>/dev/null | grep -v "Bound\|Available" | awk '{print $1}' || true)

    if [[ "$bound_count" -eq "$pv_count" ]]; then
        print_result "All PVs healthy ($pv_count PVs: Bound/Available)" "PASS"
        return 0
    else
        print_result "PV status check" "FAIL" "Problem PVs: $problem_pvs"
        return 2
    fi
}

# Check 4: PVC Status
check_pvc_status() {
    echo "Checking PersistentVolumeClaim status..."

    local pvc_count
    local bound_count
    local problem_pvcs

    pvc_count=$(kubectl get pvc --all-namespaces --no-headers 2>/dev/null | wc -l)

    if [[ "$pvc_count" -eq 0 ]]; then
        print_result "PVC status check" "WARN" "No PVCs found"
        return 0
    fi

    bound_count=$(kubectl get pvc --all-namespaces --no-headers 2>/dev/null | grep -c "Bound" || true)
    problem_pvcs=$(kubectl get pvc --all-namespaces --no-headers 2>/dev/null | grep -v "Bound" | awk '{print $1"/"$2}' || true)

    if [[ "$bound_count" -eq "$pvc_count" ]]; then
        print_result "All PVCs bound ($pvc_count PVCs)" "PASS"
        return 0
    else
        print_result "PVC status check" "FAIL" "Unbound PVCs: $problem_pvcs"
        return 2
    fi
}

# Check 5: NFS Provisioner Pod
check_provisioner() {
    echo "Checking NFS provisioner status..."

    local provisioner_status
    provisioner_status=$(kubectl get pods -n infra -l app=nfs-subdir-external-provisioner --no-headers 2>/dev/null | awk '{print $3}')

    if [[ "$provisioner_status" == "Running" ]]; then
        print_result "NFS provisioner running" "PASS"
        return 0
    elif [[ -z "$provisioner_status" ]]; then
        print_result "NFS provisioner running" "FAIL" "Provisioner pod not found in infra namespace"
        return 2
    else
        print_result "NFS provisioner running" "FAIL" "Status: $provisioner_status"
        return 2
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
    echo -e "Checks failed: ${RED}$CHECKS_FAILED${NC}"
    echo ""
}

# Main
main() {
    local exit_code=0

    print_header

    # Run checks, capture first failure exit code
    check_nfs_connectivity || exit_code=$?
    [[ $exit_code -eq 0 ]] && { check_nfs_export || exit_code=$?; }
    check_pv_status || [[ $exit_code -ne 0 ]] || exit_code=$?
    check_pvc_status || [[ $exit_code -ne 0 ]] || exit_code=$?
    check_provisioner || [[ $exit_code -ne 0 ]] || exit_code=$?

    print_summary

    if [[ $CHECKS_FAILED -gt 0 ]]; then
        echo -e "${RED}STORAGE HEALTH: DEGRADED${NC}"
        exit "${exit_code:-2}"
    else
        echo -e "${GREEN}STORAGE HEALTH: OK${NC}"
        exit 0
    fi
}

main "$@"
