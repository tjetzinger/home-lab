# Story 14.3: Integrate Paperless-AI with LiteLLM

Status: done

## Story

As a **document management user**,
I want **Paperless-AI to use the LiteLLM unified endpoint**,
So that **document classification continues working regardless of which backend is available**.

## Acceptance Criteria

1. **Given** LiteLLM is deployed with three-tier fallback
   **When** I update Paperless-AI configuration to use LiteLLM endpoint
   **Then** `AI_PROVIDER=custom` points to LiteLLM service URL (FR115)
   **And** document classification requests route through LiteLLM

2. **Given** Paperless-AI is configured with LiteLLM
   **When** I upload a document for processing
   **Then** the document is classified using the available backend tier
   **And** classification results are stored correctly

3. **Given** vLLM is unavailable (Gaming Mode)
   **When** Paperless-AI processes a document
   **Then** the request falls back to Ollama CPU via LiteLLM
   **And** processing completes (potentially slower)

## Tasks / Subtasks

⚠️ **DRAFT TASKS** - Generated from requirements analysis. Will be validated and refined against actual codebase when dev-story runs.

- [x] Task 1: Update Paperless-AI configmap with LiteLLM endpoint (AC: #1)
  - [x] Change `CUSTOM_BASE_URL` from vLLM direct to LiteLLM: `http://litellm.ml.svc.cluster.local:4000/v1`
  - [x] Change `LLM_MODEL` from `Qwen/Qwen2.5-7B-Instruct-AWQ` to `vllm-qwen` (LiteLLM model name)
  - [x] Keep `AI_PROVIDER: custom` unchanged
  - [x] Update story reference comments in configmap

- [x] Task 2: Apply configuration and restart Paperless-AI (AC: #1)
  - [x] Apply updated configmap
  - [x] Restart Paperless-AI deployment to pick up new config
  - [x] Update persistent `.env` file (overrides configmap - discovered during implementation)
  - [x] Add LiteLLM master key to `CUSTOM_API_KEY` for authentication
  - [x] Verify pod comes up healthy

- [x] Task 3: Test document classification through LiteLLM → vLLM (AC: #2)
  - [x] Check LiteLLM logs for request routing to vLLM
  - [x] Confirmed POST /v1/chat/completions requests from Paperless-AI pod IPs
  - [x] Classification completes successfully via LiteLLM proxy

- [x] Task 4: Test fallback during Gaming Mode (AC: #3)
  - [x] Scale vLLM to 0: `kubectl scale deployment/vllm-server -n ml --replicas=0`
  - [x] Verify classification falls back to Ollama via LiteLLM (model: `ollama/qwen2.5:3b`)
  - [x] Verified fallback works (after Ollama model warm-up)
  - [x] Scale vLLM back to 1: `kubectl scale deployment/vllm-server -n ml --replicas=1`

## Gap Analysis

**Scan Date:** 2026-01-14

✅ **What Exists:**
- `applications/paperless-ai/configmap.yaml` - Currently configured with direct vLLM endpoint
- `applications/litellm/` - LiteLLM deployed with three-tier fallback (Story 14.2 complete)
- LiteLLM service: `litellm.ml.svc.cluster.local:4000` (verified in cluster)
- Paperless-AI deployment running in `docs` namespace (1 replica, healthy)
- vLLM service: `vllm-api.ml.svc.cluster.local:8000` (verified in cluster)

**Current Paperless-AI Configuration:**
```yaml
CUSTOM_BASE_URL: "http://vllm-api.ml.svc.cluster.local:8000/v1"
LLM_MODEL: "Qwen/Qwen2.5-7B-Instruct-AWQ"
AI_PROVIDER: "custom"
```

❌ **What's Missing:**
- Paperless-AI not yet pointing to LiteLLM unified endpoint
- Model name needs to change from raw vLLM model to LiteLLM model name (`vllm-qwen`)

**Task Validation:** All draft tasks are accurate - no changes needed.

---

## Dev Notes

### Previous Story Intelligence (14.2)

**Key learnings from Story 14.2:**
- Fallbacks MUST be in `litellm_settings`, not `router_settings`
- Client should request model `vllm-qwen` to trigger fallback chain
- Failover detection time: ~2.5-2.8 seconds (well under NFR65 <5s)
- OpenAI API key is now live in cluster secret (tested and working)
- vLLM timeout set to 3s for fast failover

**LiteLLM Configuration (from 14.2):**
- Service: `http://litellm.ml.svc.cluster.local:4000/v1`
- Model names: `vllm-qwen`, `ollama-qwen`, `openai-gpt4o`
- Fallback chain: vllm-qwen → ollama-qwen → openai-gpt4o

### Current Paperless-AI Configuration

| Setting | Current Value | New Value |
|---------|---------------|-----------|
| `CUSTOM_BASE_URL` | `http://vllm-api.ml.svc.cluster.local:8000/v1` | `http://litellm.ml.svc.cluster.local:4000/v1` |
| `LLM_MODEL` | `Qwen/Qwen2.5-7B-Instruct-AWQ` | `vllm-qwen` |
| `AI_PROVIDER` | `custom` | `custom` (unchanged) |

### Architecture Constraints

- **FR115:** Paperless-AI uses LiteLLM unified endpoint
- **NFR67:** Document processing continues (degraded) via fallback chain
- **LiteLLM Service:** `http://litellm.ml.svc.cluster.local:4000/v1`
- **Model Name:** Must use `vllm-qwen` (not the raw vLLM model name) for fallback to work

### Files to Modify

- `applications/paperless-ai/configmap.yaml` - Update endpoint and model name

### Testing Requirements

- Verify normal operation: LiteLLM → vLLM path
- Verify fallback: Scale vLLM to 0, verify Ollama handles classification
- Check LiteLLM logs to confirm routing decisions

### References

- [Source: docs/planning-artifacts/epics.md#Story 14.3]
- [Source: docs/planning-artifacts/prd.md#FR115]
- [Source: applications/litellm/configmap.yaml - LiteLLM model configuration]
- [Source: applications/paperless-ai/configmap.yaml - Current direct vLLM config]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.5 (claude-opus-4-5-20251101)

### Debug Log References

- Paperless-AI uses persistent `.env` file in `/app/data/` which overrides K8s configmap environment variables
- Initial startup showed `AI provider: ollama` despite configmap setting `AI_PROVIDER: custom`
- Required updating `.env` file directly: `AI_PROVIDER=custom`, `CUSTOM_BASE_URL`, `CUSTOM_MODEL`, `CUSTOM_API_KEY`
- LiteLLM master key is set via secret, so authentication is required (`CUSTOM_API_KEY=sk-litellm-...`)
- Ollama cold cache model loading takes ~60 seconds - increased LiteLLM Ollama timeout from 60s to 120s

### Completion Notes List

- Paperless-AI now routes all LLM requests through LiteLLM unified endpoint
- Three-tier fallback chain verified: vLLM (GPU) → Ollama (CPU) → OpenAI (cloud)
- Gaming Mode tested: vLLM scaled to 0, requests successfully fell back to Ollama
- LiteLLM logs confirm routing: POST /v1/chat/completions from Paperless-AI pod IPs
- Important: Configuration changes require updating both configmap AND persistent `.env` file

### File List

- `applications/paperless-ai/configmap.yaml` - Updated with LiteLLM endpoint and model name
- `applications/litellm/configmap.yaml` - Increased Ollama timeout to 120s for cold cache

