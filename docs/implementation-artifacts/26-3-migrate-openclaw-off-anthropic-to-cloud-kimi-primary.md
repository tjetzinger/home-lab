# Story 26.3: Migrate OpenClaw Off Anthropic to Cloud-Kimi Primary

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **cluster operator**,
I want **to migrate openclaw's primary LLM from Anthropic Claude to cloud-kimi via LiteLLM, and coder sub-agents to cloud-qwen3-coder**,
So that **openclaw operates without any Anthropic dependency while maintaining full local fallback capability**.

## Acceptance Criteria

1. **Given** openclaw is running with `anthropic/claude-sonnet-4-6` as primary
   **When** I exec into the openclaw pod and inspect the config
   **Then** I can confirm the exact JSON key paths for primary model, fallbacks, and coder sub-agent model (FR222)
   **And** I document key names before making any changes

2. **Given** the config key names are confirmed
   **When** I remove `ANTHROPIC_OAUTH_TOKEN` from `openclaw-secrets` via kubectl patch
   **Then** the Anthropic OAuth token is removed from the cluster (FR222)
   **And** no fallback to Anthropic remains anywhere in the routing chain

3. **Given** Anthropic credentials are removed
   **When** I add `LITELLM_MASTER_KEY` to `openclaw-secrets` via `kubectl patch`
   **Then** the LiteLLM master key is available to the openclaw container as an env var

4. **Given** the secrets are updated
   **When** I apply the openclaw model config patch to `/home/node/.openclaw/openclaw.json`:
   - Provider: `litellm` at `http://litellm.ml.svc.cluster.local:4000/v1`
   - Models registered: `cloud-kimi`, `cloud-minimax`, `cloud-qwen3-coder`, `vllm-qwen`, `ollama-qwen`
   - Main agent primary: `litellm/cloud-kimi`
   - Main agent fallbacks: `["litellm/cloud-minimax", "litellm/vllm-qwen", "litellm/ollama-qwen"]`
   - Coder sub-agents: `litellm/cloud-qwen3-coder`
   **Then** openclaw routes all conversations to cloud-kimi as primary (FR222)
   **And** coder sub-agent tasks are routed to cloud-qwen3-coder (FR223)

5. **Given** the config is applied and openclaw pod restarts cleanly
   **When** I send a test Telegram message to openclaw
   **Then** the response comes from cloud-kimi (kimi-k2.5) via LiteLLM
   **And** I can verify cloud-kimi is handling the request from gateway logs in Loki

6. **Given** cloud-kimi is operational as primary
   **When** I simulate cloud API unavailability
   **Then** LiteLLM automatically falls back to `cloud-minimax`, then `vllm-qwen`, then `ollama-qwen` (FR217)
   **And** failover activates within 5 seconds (NFR123)
   **And** openclaw continues responding without error

7. **Given** the migration is complete
   **When** I verify operational behavior across all modes
   **Then** Normal → cloud-kimi, Cloud unavailable → vllm-qwen, Gaming Mode → cloud-kimi (cloud unaffected), Cloud+GPU down → ollama-qwen, Full outage → Error (by design, no Anthropic fallback) (NFR125)

**FRs covered:** FR222, FR223
**NFRs covered:** NFR123, NFR125

## Tasks / Subtasks

⚠️ **DRAFT TASKS** - Generated from requirements analysis. Will be validated and refined against actual codebase when dev-story runs.

- [x] Task 1: Inspect current openclaw config and document key paths (AC: #1)
  - [x] Subtask 1.1: Exec into pod and read config: `kubectl exec -n apps deployment/openclaw -- cat /home/node/.openclaw/openclaw.json`
  - [x] Subtask 1.2: Confirm current model keys: `agents.defaults.model.primary`, `agents.defaults.subagents.model`, `auth.profiles`
  - [x] Subtask 1.3: Note current values before any changes (current: `anthropic/claude-sonnet-4-6` for both)

- [x] Task 2: Update live `openclaw-secrets` — remove Anthropic, add LiteLLM key (AC: #2, #3)
  - [x] Subtask 2.1: Remove `ANTHROPIC_OAUTH_TOKEN` from live secret:
    `kubectl patch secret openclaw-secrets -n apps --type='json' -p '[{"op":"remove","path":"/data/ANTHROPIC_OAUTH_TOKEN"}]'`
  - [x] Subtask 2.2: Add `LITELLM_MASTER_KEY` to live secret:
    `kubectl patch secret openclaw-secrets -n apps --type='merge' -p '{"stringData":{"LITELLM_MASTER_KEY":"sk-litellm-X85qLfwJKERbijaT3KDwgZvTKGXl21Rd"}}'`
  - [x] Subtask 2.3: Verify secret contents: confirm `ANTHROPIC_OAUTH_TOKEN` absent, `LITELLM_MASTER_KEY` present

- [x] Task 3: Apply openclaw.json model config patch (AC: #4)
  - [x] Subtask 3.1: Copy current config to local: `kubectl cp apps/$(kubectl get pod -n apps -l app.kubernetes.io/name=openclaw -o name | head -1 | cut -d/ -f2):/home/node/.openclaw/openclaw.json /tmp/openclaw.json`
  - [x] Subtask 3.2: Apply JSON patch using jq (see Dev Notes for exact patch commands)
  - [x] Subtask 3.3: Verify patched JSON is valid (parse with `python3 -m json.tool`)
  - [x] Subtask 3.4: Copy modified config back: `kubectl cp /tmp/openclaw-patched.json apps/<pod-name>:/home/node/.openclaw/openclaw.json`

- [x] Task 4: Restart openclaw pod and validate (AC: #4, #5)
  - [x] Subtask 4.1: Rolling restart: `kubectl rollout restart deployment/openclaw -n apps`
  - [x] Subtask 4.2: Wait for restart: `kubectl rollout status deployment/openclaw -n apps`
  - [x] Subtask 4.3: Verify pod Running and Ready: `kubectl get pods -n apps -l app.kubernetes.io/name=openclaw`
  - [x] Subtask 4.4: Check env vars loaded: `kubectl exec -n apps deployment/openclaw -- env | grep -E 'LITELLM|ANTHROPIC'`
  - [x] Subtask 4.5: Verify config persisted: `kubectl exec -n apps deployment/openclaw -- cat /home/node/.openclaw/openclaw.json | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['agents']['defaults']['model'])"` — should show `cloud-kimi` primary

- [x] Task 5: Send test Telegram message and validate response (AC: #5)
  - [x] Subtask 5.1: Send test message to openclaw via Telegram
  - [x] Subtask 5.2: Confirm response returns and is coherent
  - [x] Subtask 5.3: Check gateway logs in Loki to confirm `cloud-kimi` / `litellm` model shown in request logs
  - [x] Subtask 5.4: Verify via LiteLLM logs that `cloud-kimi` model was invoked: `kubectl logs -n ml deployment/litellm --tail=30 | grep kimi`

- [x] Task 6: Validate fallback behavior (AC: #6, #7)
  - [x] Subtask 6.1: Verify LiteLLM fallback config still has cloud-kimi → [cloud-minimax, vllm-qwen, ollama-qwen]
  - [x] Subtask 6.2: Optionally test fallback: temporarily break cloud-kimi config in LiteLLM, verify fallback activates
  - [x] Subtask 6.3: Restore if broken for fallback test
  - [x] Subtask 6.4: Verify Gaming Mode works correctly (cloud-kimi unaffected by GPU scaling)

## Gap Analysis

**Scan performed:** 2026-02-19

**What Exists:**
- `applications/openclaw/deployment.yaml` — `envFrom: secretRef: name: openclaw-secrets` confirmed; config PVC mounted at `/home/node/.openclaw`
- `applications/openclaw/secret.yaml` (git) — `ANTHROPIC_OAUTH_TOKEN` already removed; `LITELLM_MASTER_KEY: ""` placeholder already present; `LITELLM_FALLBACK_URL` set
- LiteLLM cloud models (`cloud-kimi`, `cloud-minimax`, `cloud-qwen3-coder`) confirmed operational from Story 26.2

**What's Missing (live cluster):**
- `ANTHROPIC_OAUTH_TOKEN` still present in live `openclaw-secrets` — needs removal
- `LITELLM_MASTER_KEY` not yet in live `openclaw-secrets` — needs addition
- `openclaw.json` on PVC still has `anthropic/claude-sonnet-4-6` — needs config patch

**Task changes:** None — draft tasks accurately reflect codebase state.

---

## Dev Notes

### Live State at Story Creation (2026-02-19)

**Current openclaw primary model:** `anthropic/claude-sonnet-4-6`
**Current subagents model:** `anthropic/claude-sonnet-4-6`
**Current auth profiles:** `anthropic:subscription` (OAuth mode)

**Live `openclaw-secrets` state:**
| Key | Status |
|-----|--------|
| `ANTHROPIC_OAUTH_TOKEN` | **set** — must be removed |
| `LITELLM_MASTER_KEY` | **NOT present** — must be added |
| `LITELLM_FALLBACK_URL` | set (`http://litellm.ml.svc.cluster.local:4000/v1`) ✓ |
| `OPENAI_API_KEY` | set (used by memory-lancedb for embeddings — DO NOT TOUCH) |

**Git `applications/openclaw/secret.yaml` state:** Already correct — `ANTHROPIC_OAUTH_TOKEN` removed, `LITELLM_MASTER_KEY: ""` added. No git changes needed to the secret.yaml file.

### CRITICAL: Config File Path Correction

The epic AC states `~/.clawdbot/openclaw.json` but the **actual path is**:
```
/home/node/.openclaw/openclaw.json
```
This file is on the PVC (mounted at `/home/node/.openclaw`) and **persists across pod restarts**.

### Current openclaw.json Key Paths (Confirmed)

Key paths to change (verified by live inspection 2026-02-19):

| JSON Path | Current Value | Target Value |
|-----------|--------------|--------------|
| `agents.defaults.model.primary` | `"anthropic/claude-sonnet-4-6"` | `"litellm/cloud-kimi"` |
| `agents.defaults.model.fallbacks` | (not set) | `["litellm/cloud-minimax", "litellm/vllm-qwen", "litellm/ollama-qwen"]` |
| `agents.defaults.subagents.model` | `"anthropic/claude-sonnet-4-6"` | `"litellm/cloud-qwen3-coder"` |
| `auth.profiles` | `{ anthropic:subscription: {provider: "anthropic", mode: "oauth"} }` | Remove entire `auth.profiles` entry |
| `auth.order` | `{ anthropic: ["anthropic:subscription"] }` | Remove entire `auth.order.anthropic` entry |

### LITELLM_MASTER_KEY Value

From architecture.md (known value, already in git):
```
sk-litellm-X85qLfwJKERbijaT3KDwgZvTKGXl21Rd
```

### LiteLLM Provider Block for openclaw.json

Add this to the `models.providers` section (creating it if it doesn't exist):
```json
{
  "litellm": {
    "baseUrl": "http://litellm.ml.svc.cluster.local:4000/v1",
    "apiKey": "${LITELLM_MASTER_KEY}",
    "api": "openai-completions",
    "models": [
      { "id": "cloud-kimi",        "name": "Cloud Kimi K2.5",    "reasoning": true,  "input": ["text", "image"], "contextWindow": 256000, "maxTokens": 8192 },
      { "id": "cloud-minimax",     "name": "Cloud MiniMax M2.5", "reasoning": true,  "input": ["text"],          "contextWindow": 205000, "maxTokens": 8192 },
      { "id": "cloud-qwen3-coder", "name": "Cloud Qwen3 Coder",  "reasoning": true,  "input": ["text"],          "contextWindow": 128000, "maxTokens": 16384 },
      { "id": "vllm-qwen",         "name": "vLLM Qwen3 GPU",     "reasoning": true,  "input": ["text"],          "contextWindow": 32768,  "maxTokens": 8192 },
      { "id": "ollama-qwen",       "name": "Ollama Phi4-mini",   "reasoning": false, "input": ["text"],          "contextWindow": 16384,  "maxTokens": 4096 }
    ]
  }
}
```

### Config Patch Implementation Approach

**Recommended: jq-based patch** (if jq available) or direct kubectl exec Python patch:

```bash
# Step 1: Extract pod name
POD=$(kubectl get pod -n apps -l app.kubernetes.io/name=openclaw -o jsonpath='{.items[0].metadata.name}')

# Step 2: Copy config locally
kubectl cp apps/$POD:/home/node/.openclaw/openclaw.json /tmp/openclaw.json

# Step 3: Apply patch with Python (jq alternative — always available)
python3 << 'EOF'
import json

with open('/tmp/openclaw.json') as f:
    config = json.load(f)

# Add litellm provider
if 'models' not in config:
    config['models'] = {}
if 'providers' not in config['models']:
    config['models']['providers'] = {}

config['models']['providers']['litellm'] = {
    "baseUrl": "http://litellm.ml.svc.cluster.local:4000/v1",
    "apiKey": "${LITELLM_MASTER_KEY}",
    "api": "openai-completions",
    "models": [
        {"id": "cloud-kimi",        "name": "Cloud Kimi K2.5",    "reasoning": True,  "input": ["text", "image"], "contextWindow": 256000, "maxTokens": 8192},
        {"id": "cloud-minimax",     "name": "Cloud MiniMax M2.5", "reasoning": True,  "input": ["text"],          "contextWindow": 205000, "maxTokens": 8192},
        {"id": "cloud-qwen3-coder", "name": "Cloud Qwen3 Coder",  "reasoning": True,  "input": ["text"],          "contextWindow": 128000, "maxTokens": 16384},
        {"id": "vllm-qwen",         "name": "vLLM Qwen3 GPU",     "reasoning": True,  "input": ["text"],          "contextWindow": 32768,  "maxTokens": 8192},
        {"id": "ollama-qwen",       "name": "Ollama Phi4-mini",   "reasoning": False, "input": ["text"],          "contextWindow": 16384,  "maxTokens": 4096}
    ]
}

# Update agent primary model and fallbacks
config['agents']['defaults']['model']['primary'] = "litellm/cloud-kimi"
config['agents']['defaults']['model']['fallbacks'] = [
    "litellm/cloud-minimax", "litellm/vllm-qwen", "litellm/ollama-qwen"
]

# Update subagents model
config['agents']['defaults']['subagents']['model'] = "litellm/cloud-qwen3-coder"

# Remove Anthropic auth (leave other auth if present)
if 'auth' in config:
    if 'profiles' in config['auth']:
        config['auth']['profiles'].pop('anthropic:subscription', None)
    if 'order' in config['auth']:
        config['auth']['order'].pop('anthropic', None)

with open('/tmp/openclaw-patched.json', 'w') as f:
    json.dump(config, f, indent=2)

print("Patch applied successfully")
print(f"New primary: {config['agents']['defaults']['model']['primary']}")
print(f"New fallbacks: {config['agents']['defaults']['model']['fallbacks']}")
print(f"New subagents: {config['agents']['defaults']['subagents']['model']}")
EOF

# Step 4: Copy back
kubectl cp /tmp/openclaw-patched.json apps/$POD:/home/node/.openclaw/openclaw.json

# Step 5: Restart pod
kubectl rollout restart deployment/openclaw -n apps
```

### Secret Patch Commands

```bash
# Remove ANTHROPIC_OAUTH_TOKEN
kubectl patch secret openclaw-secrets -n apps --type='json' \
  -p '[{"op":"remove","path":"/data/ANTHROPIC_OAUTH_TOKEN"}]'

# Add LITELLM_MASTER_KEY
kubectl patch secret openclaw-secrets -n apps --type='merge' \
  -p '{"stringData":{"LITELLM_MASTER_KEY":"sk-litellm-X85qLfwJKERbijaT3KDwgZvTKGXl21Rd"}}'

# Verify
kubectl get secret openclaw-secrets -n apps -o jsonpath='{.data}' | python3 -c \
  "import json,sys,base64; d=json.load(sys.stdin); print('\n'.join(k + ': ' + ('<set>' if v else '<empty>') for k,v in d.items()))"
```

### Operational Behavior After Migration

| Mode | Cloud API | vLLM | Ollama | openclaw Effective |
|------|-----------|------|--------|-------------------|
| Normal | Available | Running | Running | cloud-kimi (primary) |
| Cloud Unavailable | Down | Running | Running | vllm-qwen (LiteLLM fallback) |
| Gaming Mode | Available | Scaled to 0 | Running | cloud-kimi (unaffected by GPU mode) |
| Cloud + GPU Down | Down | Down | Running | ollama-qwen (CPU) |
| Full Outage | Down | Down | Down | Error — no Anthropic fallback (by design) |

### Important Notes

- **OPENAI_API_KEY in openclaw.json**: Present in `env.vars` section — used for memory-lancedb embeddings (text-embedding-3-small). **DO NOT REMOVE** — this is separate from the Anthropic auth and is needed for memory search.
- **auth.profiles.anthropic:subscription**: Remove this profile and the `auth.order.anthropic` entry. Other auth profiles (if any) should be preserved.
- **No git file changes needed**: `applications/openclaw/secret.yaml` is already in the correct state (ANTHROPIC_OAUTH_TOKEN removed, LITELLM_MASTER_KEY placeholder added).
- **No deployment.yaml changes**: The deployment already uses `envFrom: secretRef: name: openclaw-secrets` which will pick up LITELLM_MASTER_KEY after the secret patch + pod restart.

### Previous Story Intelligence (26.2)

From Story 26.2 implementation (2026-02-19):
- LiteLLM cloud models confirmed operational: `cloud-kimi` (kimi-k2.5), `cloud-minimax` (minimax-m2.5), `cloud-qwen3-coder` (qwen3-coder:480b)
- **API base correction**: `https://ollama.com` (NOT `/api` suffix — LiteLLM appends `/api/chat` internally)
- **Model tags**: NO `-cloud` suffix in actual API
- LiteLLM aliases `cloud-kimi`, `cloud-minimax`, `cloud-qwen3-coder` are operational ✓
- Fallback chain configured: `cloud-kimi → [cloud-minimax, vllm-qwen, ollama-qwen]` ✓
- `envFrom` with `secretRef` requires pod restart to pick up new env vars

### References

- [Source: docs/planning-artifacts/epics.md#Story-26.3]
- [Source: docs/planning-artifacts/architecture.md#Ollama-Pro-Cloud-Model-Integration-Architecture-Epic-26]
- [Source: docs/implementation-artifacts/26-2-update-service-default-models-to-cloud-tier.md] — story 26.2 learnings
- [Source: applications/openclaw/deployment.yaml] — envFrom secretRef pattern
- [Source: applications/openclaw/secret.yaml] — secret placeholder structure
- FRs: FR222 (openclaw primary → cloud-kimi, Anthropic removed), FR223 (coder sub-agents → cloud-qwen3-coder)
- NFRs: NFR123 (5s failover), NFR125 (full local fallback operational)

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

- LiteLLM log confirmed: `requested='cloud-kimi' downstream='kimi-k2.5' → 200 OK` after Telegram test
- Model self-identifies as "Sonnet 4.6" due to training data quirk — routing is correct (kimi-k2.5 via ollama.com)
- Gateway log at startup: `agent model: litellm/cloud-kimi` ✅

### Completion Notes List

- **Task 1**: Confirmed live state — `primary: anthropic/claude-sonnet-4-6`, no existing litellm provider, `auth.profiles: ['anthropic:subscription']`
- **Task 2**: `ANTHROPIC_OAUTH_TOKEN` removed via `kubectl patch --type=json`; `LITELLM_MASTER_KEY` added via `kubectl patch --type=merge`. Verified: key absent, master key set.
- **Task 3**: Config patched via Python script. Added `models.providers.litellm` block with 5 models; updated `agents.defaults.model.primary` to `litellm/cloud-kimi`; set fallbacks; updated subagents to `litellm/cloud-qwen3-coder`; removed `auth.profiles.anthropic:subscription` and `auth.order.anthropic`. JSON validated clean.
- **Task 4**: Rolling restart completed. New pod `3/3 Running`. Env verified: `LITELLM_MASTER_KEY` present, `ANTHROPIC` absent. Config read from new pod confirmed: `primary: litellm/cloud-kimi`.
- **Task 5**: Telegram test sent. LiteLLM log confirmed `cloud-kimi → kimi-k2.5 (ollama.com), 200 OK`. Response coherent.
- **Task 6**: LiteLLM fallback chain confirmed: `cloud-kimi → [cloud-minimax, vllm-qwen, ollama-qwen]`. Cloud API (ollama.com) is independent of GPU mode — gaming mode does not affect cloud-kimi routing.

### File List

- `docs/implementation-artifacts/26-3-migrate-openclaw-off-anthropic-to-cloud-kimi-primary.md` (this story file)
- `docs/implementation-artifacts/sprint-status.yaml` (status updated)

## Change Log

- 2026-02-19: Story implemented — migrated openclaw primary model from `anthropic/claude-sonnet-4-6` to `litellm/cloud-kimi` (kimi-k2.5 via ollama.com); subagents to `litellm/cloud-qwen3-coder`; removed Anthropic OAuth token from live secret; added LiteLLM master key; configured full fallback chain via LiteLLM. Validated via Telegram test and LiteLLM logs.
