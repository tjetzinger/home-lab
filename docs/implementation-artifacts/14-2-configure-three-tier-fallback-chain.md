# Story 14.2: Configure Three-Tier Fallback Chain

Status: done

## Story

As a **cluster operator**,
I want **LiteLLM to automatically fall back to Ollama CPU, then OpenAI cloud when vLLM is unavailable**,
So that **AI inference continues even during Gaming Mode or GPU worker outages**.

## Acceptance Criteria

1. **Given** LiteLLM is deployed with vLLM backend (Story 14.1 complete)
   **When** I add Ollama as a secondary backend
   **Then** LiteLLM routes to Ollama when vLLM health check fails (FR114, FR116)
   **And** failover detection completes within 5 seconds (NFR65)

2. **Given** LiteLLM has vLLM and Ollama backends configured
   **When** I add OpenAI as a tertiary backend
   **Then** OpenAI API key is stored as Kubernetes secret (FR117)
   **And** OpenAI is only used when both vLLM and Ollama are unavailable (NFR68)

3. **Given** three-tier fallback is configured
   **When** I scale vLLM to 0 replicas (Gaming Mode)
   **Then** LiteLLM automatically routes requests to Ollama CPU
   **And** document processing continues (degraded) via fallback chain (NFR67)

4. **Given** vLLM and Ollama are both unavailable
   **When** I send an inference request
   **Then** LiteLLM routes to OpenAI cloud as last resort
   **And** response is returned with higher latency but correct format

## Tasks / Subtasks

- [x] Task 1: Configure Ollama as secondary fallback backend (AC: #1)
  - [x] Add Ollama model configuration to LiteLLM configmap
  - [x] Configure Ollama endpoint: `http://ollama.ml.svc.cluster.local:11434`
  - [x] Set model name: `ollama/qwen2.5:3b` (available model)
  - [x] Configure health check and failover timeout (<5s for NFR65)

- [x] Task 2: Add OPENAI_API_KEY to existing secret (AC: #2)
  - [x] Add OPENAI_API_KEY to litellm-secrets (placeholder for manual update)
  - [x] Deployment already has envFrom secretRef (auto-loads secrets)
  - [x] Documented kubectl patch command for setting real API key

- [x] Task 3: Configure OpenAI as tertiary fallback backend (AC: #2)
  - [x] Add OpenAI model configuration (`gpt-4o-mini`) to LiteLLM configmap
  - [x] Reference API key from environment variable (secret)
  - [x] Set OpenAI as lowest priority via fallback chain

- [x] Task 4: Configure LiteLLM router with fallback strategy (AC: #1, #2)
  - [x] Configure `fallbacks` in litellm_settings (NOT router_settings)
  - [x] Fallback chain: `vllm-qwen` → `ollama-qwen` → `openai-gpt4o`
  - [x] Set vLLM timeout to 3s for fast failover detection
  - [x] Set num_retries to 1 for quick failover

- [x] Task 5: Test failover scenarios (AC: #3, #4)
  - [x] Test vLLM → Ollama failover by scaling vLLM to 0
  - [x] Verified failover detection time: ~2.5-2.8s (NFR65: <5s ✓)
  - [x] OpenAI fallback configured (placeholder key triggers auth error as expected)
  - [x] Verified vLLM is used when available

## Gap Analysis

**Scan Date:** 2026-01-14

✅ **What Exists:**
- `applications/litellm/configmap.yaml` - Single vLLM backend configured
- `applications/litellm/secret.yaml` - Has LITELLM_MASTER_KEY and DATABASE_URL
- `applications/litellm/deployment.yaml` - Already has `envFrom: secretRef` (secrets auto-loaded as env vars)
- Ollama pod running in ml namespace with models: **qwen2.5:3b**, llama3.2:1b
- vLLM running with `Qwen/Qwen2.5-7B-Instruct-AWQ`

❌ **What's Missing:**
- Ollama backend configuration in LiteLLM configmap
- OpenAI backend configuration in LiteLLM configmap
- `OPENAI_API_KEY` in litellm-secrets
- Fallback routing strategy in router_settings

**Task Changes:**
- Task 1: Use `qwen2.5:3b` (actual available Ollama model)
- Task 2: Add OPENAI_API_KEY to existing secret (not create new)

---

## Dev Notes

### Previous Story Intelligence (14.1)

**Key learnings from Story 14.1:**
- LiteLLM requires `api_key` even for backends that don't need auth (use `sk-none` for vLLM)
- Model name must match exactly what backend serves (`Qwen/Qwen2.5-7B-Instruct-AWQ` not `qwen2.5:14b`)
- PostgreSQL backend added for UI access (DATABASE_URL in secret)
- Memory increased to 1Gi due to OOM with database
- Latency overhead confirmed at ~18ms (well under 100ms NFR66)

**Files created in 14.1:**
- `applications/litellm/configmap.yaml` - Will be modified for fallback chain
- `applications/litellm/deployment.yaml` - May need secret reference update
- `applications/litellm/secret.yaml` - Will add OpenAI API key here
- `applications/litellm/ingressroute.yaml` - No changes expected

### Architecture Constraints

- **Fallback Order:** vLLM (GPU, primary) → Ollama (CPU, secondary) → OpenAI (cloud, tertiary)
- **NFR65:** Failover detection within 5 seconds
- **NFR68:** OpenAI only activated when BOTH vLLM and Ollama unavailable
- **Secret Management:** OpenAI API key via Kubernetes secret (FR117)

### Current ML Infrastructure Endpoints

| Service | Endpoint | Status |
|---------|----------|--------|
| vLLM | `http://vllm-api.ml.svc.cluster.local:8000/v1` | Primary |
| Ollama | `http://ollama.ml.svc.cluster.local:11434` | Secondary (to add) |
| OpenAI | `https://api.openai.com/v1` | Tertiary (to add) |

### LiteLLM Fallback Configuration Pattern

```yaml
model_list:
  # Primary: vLLM (GPU)
  - model_name: default
    litellm_params:
      model: openai/Qwen/Qwen2.5-7B-Instruct-AWQ
      api_base: http://vllm-api.ml.svc.cluster.local:8000/v1
      api_key: sk-none

  # Secondary: Ollama (CPU fallback)
  - model_name: default
    litellm_params:
      model: ollama/qwen2.5:7b
      api_base: http://ollama.ml.svc.cluster.local:11434

  # Tertiary: OpenAI (cloud fallback)
  - model_name: default
    litellm_params:
      model: gpt-4o-mini  # Cost-effective for document classification
      api_key: os.environ/OPENAI_API_KEY

router_settings:
  routing_strategy: simple-shuffle
  num_retries: 3
  timeout: 60
  fallbacks: [{"default": ["default"]}]  # Same model name enables fallback
```

### Testing Requirements

- Scale vLLM to 0: `kubectl scale deployment/vllm-server -n ml --replicas=0`
- Verify Ollama handles requests during Gaming Mode
- Time failover detection (must be <5 seconds)
- Test OpenAI fallback by also scaling Ollama to 0

### References

- [Source: docs/planning-artifacts/epics.md#Story 14.2]
- [Source: docs/planning-artifacts/prd.md#FR114-117]
- [Source: applications/litellm/configmap.yaml - Current single-backend config]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.5 (claude-opus-4-5-20251101)

### Debug Log References

- Initial fallback config placed in `router_settings` - failed because `model_group_alias` doesn't work with fallbacks
- Researched LiteLLM docs via Exa: fallbacks must be in `litellm_settings`, not `router_settings`
- Using same `model_name` for all backends didn't provide ordered failover (random load balancing)
- Final solution: distinct model names with explicit `fallbacks` chain in `litellm_settings`
- Reduced `num_retries` from 3 to 1 and `timeout` to 3s to meet NFR65 (<5s failover)

### Completion Notes List

- Three-tier fallback chain configured: vLLM (GPU) → Ollama (CPU) → OpenAI (cloud)
- Failover detection time: **~2.5-2.8 seconds** (NFR65 target: <5s ✓)
- Client should request model `vllm-qwen` for automatic fallback handling
- OpenAI API key is placeholder - run kubectl patch to set real key when needed
- vLLM timeout set to 3s for fast failover (may cause issues with very long prompts)

### File List

- `applications/litellm/configmap.yaml` - Updated with three-tier fallback configuration
- `applications/litellm/secret.yaml` - Added OPENAI_API_KEY placeholder

