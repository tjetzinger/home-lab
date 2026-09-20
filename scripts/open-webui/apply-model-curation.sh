#!/bin/bash
# Open-WebUI Model Curation
# Applies applications/open-webui/model-curation.json to the running Open-WebUI
# instance, restricting the model picker to the curated keep-list.
#
# ADR-013: Cloud Model Tier Refresh
#
# WHY A SCRIPT: Open-WebUI's OLLAMA_API_CONFIGS / OPENAI_API_CONFIGS env vars are
# documented but never parsed from JSON upstream (issue #19017, closed as not
# planned), so per-connection model filtering cannot be set from Helm values.
# This script is the declarative substitute and the PVC-loss recovery path.
#
# Exit codes:
#   0 - Curation applied successfully
#   1 - Missing dependency or manifest
#   2 - API key not configured
#   3 - API request failed
#   4 - Verification mismatch
#
# Usage: ./scripts/open-webui/apply-model-curation.sh [--dry-run] [--verify-only]

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MANIFEST="${REPO_ROOT}/applications/open-webui/model-curation.json"
NAMESPACE="${NAMESPACE:-apps}"
CONTEXT="${KUBE_CONTEXT:-default}"
BASE_URL="${OPENWEBUI_URL:-http://localhost:8080}"

DRY_RUN=false
VERIFY_ONLY=false
for arg in "$@"; do
  case "$arg" in
    --dry-run)     DRY_RUN=true ;;
    --verify-only) VERIFY_ONLY=true ;;
    *) echo "Unknown argument: $arg" >&2; exit 1 ;;
  esac
done

command -v kubectl >/dev/null || { echo "ERROR: kubectl not found" >&2; exit 1; }
command -v jq      >/dev/null || { echo "ERROR: jq not found" >&2; exit 1; }
[[ -f "$MANIFEST" ]] || { echo "ERROR: manifest not found: $MANIFEST" >&2; exit 1; }

POD="$(kubectl --context "$CONTEXT" get pods -n "$NAMESPACE" \
        -l app.kubernetes.io/name=open-webui -o jsonpath='{.items[0].metadata.name}')"
[[ -n "$POD" ]] || { echo "ERROR: no open-webui pod found in namespace $NAMESPACE" >&2; exit 1; }
echo "Target pod: $POD"

# Build the per-connection model_ids whitelists from the manifest.
OLLAMA_IDS="$(jq -c '[.connections.ollama.keep[].id]' "$MANIFEST")"
OPENAI_IDS="$(jq -c '[.connections.openai.keep[].id]' "$MANIFEST")"
DEFAULT_MODEL="$(jq -r '.default_model' "$MANIFEST")"

echo "Keep (ollama, $(jq 'length' <<<"$OLLAMA_IDS")): $(jq -r 'join(", ")' <<<"$OLLAMA_IDS")"
echo "Keep (openai, $(jq 'length' <<<"$OPENAI_IDS")): $(jq -r 'join(", ")' <<<"$OPENAI_IDS")"
echo "Default model: $DEFAULT_MODEL"

if [[ "$DRY_RUN" == true ]]; then
  echo "--dry-run: no changes made"
  exit 0
fi

# Admin API key lives in open-webui-secrets (generate in Open-WebUI -> Settings -> Account).
API_KEY="$(kubectl --context "$CONTEXT" get secret open-webui-secrets -n "$NAMESPACE" \
            -o jsonpath='{.data.OPENWEBUI_API_KEY}' 2>/dev/null | base64 -d 2>/dev/null || true)"
if [[ -z "$API_KEY" ]]; then
  cat >&2 <<'MSG'
ERROR: OPENWEBUI_API_KEY is empty in secret open-webui-secrets.

  1. Open-WebUI -> Settings -> Account -> API keys -> create a new key
  2. kubectl patch secret open-webui-secrets -n apps --type='merge' \
       -p '{"stringData":{"OPENWEBUI_API_KEY":"<key>"}}'

Never `kubectl apply` secret.yaml — it holds empty placeholders.
MSG
  exit 2
fi

# in_pod <method> <path> [body] — curl from inside the pod; Open-WebUI is ClusterIP-only.
in_pod() {
  local method="$1" path="$2" body="${3:-}"
  local args=(-sS -X "$method" "${BASE_URL}${path}"
              -H "Authorization: Bearer ${API_KEY}"
              -H "Content-Type: application/json"
              -w '\n%{http_code}')
  [[ -n "$body" ]] && args+=(-d "$body")
  kubectl --context "$CONTEXT" exec -n "$NAMESPACE" "$POD" -c open-webui -- curl "${args[@]}"
}

check() {
  local label="$1" out="$2"
  local code="${out##*$'\n'}"
  if [[ "$code" != "200" ]]; then
    echo "ERROR: $label failed with HTTP $code" >&2
    echo "${out%$'\n'*}" >&2
    exit 3
  fi
  echo "  OK: $label"
}

if [[ "$VERIFY_ONLY" != true ]]; then
  echo "Applying connection whitelists..."

  # Preserve each connection's existing settings, override only model_ids.
  ollama_cfg="$(in_pod GET /ollama/config)"; check "read ollama config" "$ollama_cfg"
  # An empty {} is truthy in jq, so `//` will not substitute a default — seed
  # connection "0" explicitly when no per-connection config exists yet.
  ollama_payload="$(jq -c --argjson ids "$OLLAMA_IDS" \
    '.OLLAMA_API_CONFIGS = (if ((.OLLAMA_API_CONFIGS // {}) | length) == 0
                            then {"0": {"enable": true, "model_ids": $ids}}
                            else (.OLLAMA_API_CONFIGS | with_entries(.value.model_ids = $ids))
                            end)' \
    <<<"${ollama_cfg%$'\n'*}")"
  check "update ollama config" "$(in_pod POST /ollama/config/update "$ollama_payload")"

  openai_cfg="$(in_pod GET /openai/config)"; check "read openai config" "$openai_cfg"
  openai_payload="$(jq -c --argjson ids "$OPENAI_IDS" \
    '.OPENAI_API_CONFIGS = (if ((.OPENAI_API_CONFIGS // {}) | length) == 0
                            then {"0": {"enable": true, "model_ids": $ids}}
                            else (.OPENAI_API_CONFIGS | with_entries(.value.model_ids = $ids))
                            end)' \
    <<<"${openai_cfg%$'\n'*}")"
  check "update openai config" "$(in_pod POST /openai/config/update "$openai_payload")"
fi

echo "Verifying model picker..."
models_out="$(in_pod GET /api/models)"; check "read /api/models" "$models_out"
visible="$(jq -r '[.data[].id] | sort | join(" ")' <<<"${models_out%$'\n'*}")"
expected="$(jq -r '[.connections[].keep[].id] | sort | join(" ")' "$MANIFEST")"

echo "  visible:  $visible"
if [[ "$visible" != "$expected" ]]; then
  echo "  expected: $expected"
  echo "WARNING: visible model set does not match the manifest." >&2
  echo "Models already cached as workspace records may need hiding in Admin -> Models." >&2
  exit 4
fi

echo "Model curation applied and verified ($(jq '[.connections[].keep[]] | length' "$MANIFEST") models visible)."
echo "NOTE: DEFAULT_MODELS is a PersistentConfig var — set '$DEFAULT_MODEL' in"
echo "      Admin Panel -> Settings -> General if the picker does not already default to it."
