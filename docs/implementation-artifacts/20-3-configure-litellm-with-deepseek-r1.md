# Story 20.3: Configure LiteLLM with DeepSeek-R1

Status: done

## Story

As a **application developer**,
I want **DeepSeek-R1 accessible via LiteLLM**,
So that **applications can request reasoning-focused inference**.

## Acceptance Criteria

1. **Given** DeepSeek-R1 is deployed via vLLM
   **When** I add it to LiteLLM configuration
   **Then** `deepseek-r1` model is available in LiteLLM
   **And** this validates FR141

2. **Given** LiteLLM is configured
   **When** I request `deepseek-r1` model via API
   **Then** request routes to vLLM with DeepSeek-R1 (when in R1-Mode)
   **And** response includes reasoning chain

3. **Given** mode is not R1-Mode (ML-Mode or Gaming-Mode)
   **When** I request `deepseek-r1` model
   **Then** request fails gracefully with clear error
   **And** application can fallback to `default` model

## Tasks / Subtasks

- [x] Task 1: Add DeepSeek-R1 model definition to LiteLLM configmap (AC: #1)
  - [x] Add `vllm-r1` model entry to model_list after vllm-qwen
  - [x] Configure with openai/casperhansen/deepseek-r1-distill-qwen-7b-awq
  - [x] Use same api_base as vllm-qwen (same vLLM service)
  - [x] Set timeout: 60 (R1 generates longer reasoning chains)

- [x] Task 2: Apply configuration to cluster (AC: #1)
  - [x] Apply updated configmap with kubectl apply
  - [x] Restart LiteLLM pod to load new config
  - [x] Verify /models endpoint shows vllm-r1

- [x] Task 3: Test inference in R1-Mode (AC: #2)
  - [x] Switch to R1-Mode using gpu-mode r1
  - [x] Test chat completion with vllm-r1 via LiteLLM
  - [x] Verify response includes <think> reasoning tags

- [x] Task 4: Test mode mismatch behavior (AC: #3)
  - [x] Switch to ML-Mode using gpu-mode ml
  - [x] Request vllm-r1 - verify error response (HTTP 404)
  - [x] Document expected behavior in README

- [x] Task 5: Update LiteLLM README with R1 documentation (AC: #3)
  - [x] Add R1 mode section documenting model availability
  - [x] Document <think> tag response format
  - [x] Add mode-dependent availability table

## Gap Analysis

**Scan Date:** 2026-01-16
**Status:** Validated and tasks refined

### What Exists:
- `applications/litellm/configmap.yaml` - LiteLLM configuration with 7 models
- `applications/litellm/deployment.yaml` - LiteLLM proxy deployment
- `applications/vllm/deployment-r1.yaml` - DeepSeek-R1 vLLM deployment
- `applications/vllm/service.yaml` - vLLM service (`vllm-api`) on port 8000
- `scripts/gpu-worker/gpu-mode` - Mode switching script (Story 20.2)
- Existing fallback chain: `vllm-qwen` → `ollama-qwen` → `openai-gpt4o`

### What's Missing:
- `vllm-r1` model entry in configmap.yaml for DeepSeek-R1
- Documentation of mode-dependent model availability in README

### Task Changes Applied:
- Reordered tasks: Apply config (Task 2) before testing (Task 3-4)
- Simplified Task 2: No routing config needed, same endpoint as vllm-qwen
- Added Task 5: README documentation for R1 mode availability

### Key Implementation Notes:
- Same vLLM endpoint, different model loaded based on gpu-mode
- Model name in vLLM changes: `Qwen/Qwen2.5-7B-Instruct-AWQ` vs `casperhansen/deepseek-r1-distill-qwen-7b-awq`
- LiteLLM needs model entry pointing to the correct model name
- When mode mismatch occurs, vLLM returns 404 (model not found)

---

## Dev Notes

### LiteLLM Model Configuration Pattern

From existing vllm-qwen entry:
```yaml
- model_name: vllm-qwen
  litellm_params:
    model: openai/Qwen/Qwen2.5-7B-Instruct-AWQ
    api_base: http://vllm-api.ml.svc.cluster.local:8000/v1
    api_key: sk-none
    timeout: 30
  model_info:
    mode: chat
```

For DeepSeek-R1:
```yaml
- model_name: vllm-r1
  litellm_params:
    model: openai/casperhansen/deepseek-r1-distill-qwen-7b-awq
    api_base: http://vllm-api.ml.svc.cluster.local:8000/v1
    api_key: sk-none
    timeout: 60  # R1 may generate longer reasoning chains
  model_info:
    mode: chat
```

### Mode-Dependent Model Availability

| Mode | vllm-qwen | vllm-r1 |
|------|-----------|---------|
| ML-Mode | Available | Unavailable (404) |
| R1-Mode | Unavailable (404) | Available |
| Gaming-Mode | Unavailable (503) | Unavailable (503) |

Applications should:
1. Check mode before requesting specific model
2. Or use fallback chain starting with vllm-qwen (always tries first)

### DeepSeek-R1 Response Format

DeepSeek-R1 models output reasoning in `<think>` tags:
```
<think>
Let me analyze this step by step...
First, I need to consider...
</think>

The answer is...
```

Applications should parse or display these tags appropriately.

### Project Structure Notes

- **Config location:** `applications/litellm/configmap.yaml`
- **Service endpoint:** `litellm.ml.svc.cluster.local:4000`
- **vLLM endpoint:** `vllm-api.ml.svc.cluster.local:8000`
- **Namespace:** `ml`

### References

**Project Sources:**
- [Source: docs/planning-artifacts/epics.md#Story 20.3]
- [Source: docs/planning-artifacts/architecture.md#DeepSeek-R1 14B Reasoning Mode Architecture]
- [Source: applications/litellm/configmap.yaml - Current LiteLLM config]
- [Source: applications/vllm/deployment-r1.yaml - R1 deployment (Story 20.1)]
- [Source: docs/implementation-artifacts/20-1-deploy-deepseek-r1-14b-via-vllm.md - Previous story]
- [Source: docs/implementation-artifacts/20-2-implement-r1-mode-in-gpu-mode-script.md - Mode switching]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.5 (claude-opus-4-5-20251101)

### Debug Log References

- Tested inference via LiteLLM in R1-Mode: Response included `</think>` tag (reasoning visible)
- Tested mode mismatch: HTTP 404 returned when requesting vllm-r1 in ML-Mode
- Deployed updated gpu-mode script to k3s-gpu-worker for mode switching

### Completion Notes List

- Added `vllm-r1` model entry to LiteLLM configmap pointing to DeepSeek-R1 AWQ model
- Model uses same vLLM service endpoint as vllm-qwen (model switching handled by gpu-mode)
- Set timeout to 60s to accommodate longer reasoning chains
- Verified model loads correctly: LiteLLM logs show "vllm-r1" in initialized models
- R1-Mode inference test successful: DeepSeek-R1 responded with step-by-step reasoning
- Mode mismatch properly handled: HTTP 404 with clear error message
- Updated README with comprehensive R1 documentation including availability table

### File List

| File | Action | Description |
|------|--------|-------------|
| `applications/litellm/configmap.yaml` | Modify | Added vllm-r1 model entry for DeepSeek-R1, updated header with FR141 |
| `applications/litellm/README.md` | Modify | Added R1 mode documentation, availability table, response format, usage example |
