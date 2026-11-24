#!/bin/bash
# Open-WebUI External Tool Servers
# Applies applications/open-webui/tool-servers.json to the running Open-WebUI instance.
#
# ADR-023: Zimi offline knowledge library
#
# WHY A SCRIPT: tool server connections are a PersistentConfig value in the Open-WebUI DB.
# The TOOL_SERVER_CONNECTIONS env var only seeds a fresh install, so Helm cannot manage them.
# Same reasoning as apply-model-curation.sh; this is also the PVC-loss recovery path.
#
# Bearer keys are read from Kubernetes Secrets at apply time (`key_from` in the manifest) and
# sent on stdin, so they never appear in git or in a process list.
#
# Exit codes:
#   0 - Applied and verified
#   1 - Missing dependency or manifest
#   2 - API key or tool server key not found
#   3 - API request failed
#   4 - Verification failed
#
# Usage: ./scripts/open-webui/apply-tool-servers.sh [--dry-run]

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MANIFEST="${REPO_ROOT}/applications/open-webui/tool-servers.json"
NAMESPACE="${NAMESPACE:-apps}"
CONTEXT="${KUBE_CONTEXT:-default}"
BASE_URL="${OPENWEBUI_URL:-http://localhost:8080}"

DRY_RUN=false
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    *) echo "Unknown argument: $arg" >&2; exit 1 ;;
  esac
done

command -v kubectl >/dev/null || { echo "ERROR: kubectl not found" >&2; exit 1; }
command -v jq      >/dev/null || { echo "ERROR: jq not found" >&2; exit 1; }
[[ -f "$MANIFEST" ]] || { echo "ERROR: manifest not found: $MANIFEST" >&2; exit 1; }

secret_value() {
  local ns="$1" name="$2" key="$3"
  kubectl --context "$CONTEXT" get secret "$name" -n "$ns" \
    -o jsonpath="{.data.${key}}" 2>/dev/null | base64 -d 2>/dev/null || true
}

POD="$(kubectl --context "$CONTEXT" get pods -n "$NAMESPACE" \
        -l app.kubernetes.io/name=open-webui -o jsonpath='{.items[0].metadata.name}')"
[[ -n "$POD" ]] || { echo "ERROR: no open-webui pod found in namespace $NAMESPACE" >&2; exit 1; }
echo "Target pod: $POD"

echo "Tool servers: $(jq -r '[.connections[].info.id] | join(", ")' "$MANIFEST")"
if [[ "$DRY_RUN" == true ]]; then
  echo "--dry-run: no changes made"
  exit 0
fi

API_KEY="$(secret_value "$NAMESPACE" open-webui-secrets OPENWEBUI_API_KEY)"
[[ -n "$API_KEY" ]] || { echo "ERROR: OPENWEBUI_API_KEY is empty in open-webui-secrets" >&2; exit 2; }

# Resolve every key_from into key, and drop key_from (Open-WebUI keeps unknown fields).
payload='{"TOOL_SERVER_CONNECTIONS": []}'
count="$(jq '.connections | length' "$MANIFEST")"
for ((i = 0; i < count; i++)); do
  conn="$(jq -c ".connections[$i]" "$MANIFEST")"
  ref="$(jq -c '.key_from // empty' <<<"$conn")"
  key=""
  if [[ -n "$ref" ]]; then
    key="$(secret_value "$(jq -r .namespace <<<"$ref")" "$(jq -r .secret <<<"$ref")" "$(jq -r .key <<<"$ref")")"
    [[ -n "$key" ]] || { echo "ERROR: key for $(jq -r .info.id <<<"$conn") not found ($ref)" >&2; exit 2; }
  fi
  payload="$(jq -c --argjson c "$conn" --arg k "$key" \
    '.TOOL_SERVER_CONNECTIONS += [$c | del(.key_from) | .key = $k]' <<<"$payload")"
done

# in_pod <method> <path> — curl from inside the pod (Open-WebUI is ClusterIP-only).
# Line 1 of stdin is the admin API key, the rest is the request body.
in_pod() {
  local method="$1" path="$2"
  kubectl --context "$CONTEXT" exec -i -n "$NAMESPACE" "$POD" -c open-webui -- sh -c '
    read -r key
    curl -sS -X "$1" "$2" -H "Authorization: Bearer $key" \
      -H "Content-Type: application/json" -w "\n%{http_code}" -d @-' _ "$method" "${BASE_URL}${path}"
}

echo "Applying tool server connections..."
out="$(printf '%s\n%s' "$API_KEY" "$payload" | in_pod POST /api/v1/configs/tool_servers)"
code="${out##*$'\n'}"
[[ "$code" == "200" ]] || { echo "ERROR: apply failed with HTTP $code" >&2; echo "${out%$'\n'*}" | jq 'del(.. | .key? // empty)' >&2 2>/dev/null || true; exit 3; }
echo "  OK: applied"

echo "Verifying each server answers through Open-WebUI..."
for ((i = 0; i < count; i++)); do
  conn="$(jq -c ".TOOL_SERVER_CONNECTIONS[$i]" <<<"$payload")"
  id="$(jq -r .info.id <<<"$conn")"
  out="$(printf '%s\n%s' "$API_KEY" "$conn" | in_pod POST /api/v1/configs/tool_servers/verify)"
  code="${out##*$'\n'}"
  if [[ "$code" != "200" ]]; then
    echo "ERROR: $id did not verify (HTTP $code)" >&2
    exit 4
  fi
  echo "  OK: $id ($(jq -r '[.paths // {} | keys[]] | join(", ")' <<<"${out%$'\n'*}" 2>/dev/null))"
done

echo "Tool servers applied and verified."
