# Story 26.1: Configure LiteLLM with Ollama Pro Cloud Models

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **cluster operator**,
I want **to add three Ollama Pro cloud models to LiteLLM with proper secret management and fallback chains**,
So that **all services have access to frontier cloud AI with automatic local fallback when the cloud is unavailable**.

## Acceptance Criteria

1. **Given** LiteLLM is running in the `ml` namespace with existing `litellm-secrets`
   **When** I add `OLLAMA_API_KEY` to the secret via `kubectl patch secret litellm-secrets -n ml --type='merge' -p '{"stringData":{"OLLAMA_API_KEY":"<key>"}}'`
   **Then** the key is stored securely as a Kubernetes secret (FR215)
   **And** no `kubectl apply` with placeholder values is performed (NFR122)

2. **Given** `OLLAMA_API_KEY` is in the secret
   **When** I update the LiteLLM configmap to add three cloud model entries:
   - `cloud-kimi` → `ollama_chat/kimi-k2.5:<tag>-cloud` at `https://ollama.com/api`
   - `cloud-minimax` → `ollama_chat/minimax-m2.5:<tag>-cloud` at `https://ollama.com/api`
   - `cloud-qwen3-coder` → `ollama_chat/qwen3-coder:480b-cloud` at `https://ollama.com/api`
   **Then** LiteLLM reloads and all three models appear in `/v1/models` response (FR216)
   **And** each entry has `timeout: 60` and `api_key: os.environ/OLLAMA_API_KEY`

3. **Given** the cloud models are registered in LiteLLM
   **When** I update the `fallbacks` section in `litellm_settings`:
   - `cloud-kimi` → `["cloud-minimax", "vllm-qwen", "ollama-qwen"]`
   - `cloud-minimax` → `["vllm-qwen", "ollama-qwen"]`
   - `cloud-qwen3-coder` → `["vllm-qwen", "ollama-qwen"]`
   **Then** LiteLLM falls back to local tier when cloud API is unavailable (FR217)
   **And** failover activates within 5 seconds (NFR123)

4. **Given** the fallback chains are configured
   **When** I remove `openai-gpt4o` from any automatic fallback chain entries (retaining it as explicit-only)
   **Then** `openai-gpt4o` is no longer part of any automatic routing (FR218)
   **And** it remains available as a direct model selection

5. **Given** the full cloud configuration is applied
   **When** I send a test inference request to `cloud-kimi` via the LiteLLM endpoint
   **Then** the response returns within 60 seconds (NFR121)
   **And** LiteLLM Prometheus metrics record the cloud model request

6. **Given** the exact Ollama Pro model tags are unknown at planning time
   **When** I obtain the `OLLAMA_API_KEY` and access the Ollama Pro account
   **Then** I verify exact model tags via `ollama ls --cloud` or the Ollama Pro dashboard
   **And** update configmap entries with confirmed tags before applying

## Tasks / Subtasks

- [x] Task 1: Verify exact Ollama Pro cloud model tags (AC: #6)
  - [x] Subtask 1.1: Obtain `OLLAMA_API_KEY` from ollama.com → Settings → Keys
  - [x] Subtask 1.2: Verified tags via `GET https://ollama.com/api/tags` with Bearer auth
  - [x] Subtask 1.3: Confirmed exact tags: `kimi-k2.5` (no size variant), `minimax-m2.5` (no size variant), `qwen3-coder:480b` (no -cloud suffix — architecture doc assumption was incorrect; actual API uses no -cloud suffix)

- [x] Task 2: Patch litellm-secrets with OLLAMA_API_KEY (AC: #1)
  - [x] Subtask 2.1: Run `kubectl patch secret litellm-secrets -n ml --type='merge' -p '{"stringData":{"OLLAMA_API_KEY":"<key>"}}'`
  - [x] Subtask 2.2: Verified key stored (first 5 chars confirmed via base64 decode)

- [x] Task 3: Update LiteLLM configmap with cloud model entries (AC: #2, #4)
  - [x] Subtask 3.1: Added `cloud-kimi` with `ollama_chat/kimi-k2.5`, `api_base: https://ollama.com`, `api_key: os.environ/OLLAMA_API_KEY`, `timeout: 60`
  - [x] Subtask 3.2: Added `cloud-minimax` with same pattern and `ollama_chat/minimax-m2.5`
  - [x] Subtask 3.3: Added `cloud-qwen3-coder` with `ollama_chat/qwen3-coder:480b`
  - [x] Subtask 3.4: Updated configmap header with Story 26.1, FR215-FR218, NFR121-NFR123

- [x] Task 4: Update fallbacks in litellm_settings (AC: #3, #4)
  - [x] Subtask 4.1: Replaced single-line fallbacks with expanded 4-entry block
  - [x] Subtask 4.2: New fallbacks: cloud-kimi→[cloud-minimax,vllm-qwen,ollama-qwen], cloud-minimax→[vllm-qwen,ollama-qwen], cloud-qwen3-coder→[vllm-qwen,ollama-qwen], vllm-qwen→[ollama-qwen]
  - [x] Subtask 4.3: openai-gpt4o removed from all fallback entries; retained in model_list for explicit selection

- [x] Task 5: Update secret.yaml placeholder documentation (AC: #1)
  - [x] Subtask 5.1: Added `OLLAMA_API_KEY: "placeholder-update-via-kubectl-patch"` and kubectl patch comment to `applications/litellm/secret.yaml`; updated story reference in header

- [x] Task 6: Apply configmap and restart LiteLLM (AC: #2, #3)
  - [x] Subtask 6.1: Applied configmap — `configmap/litellm-config configured`
  - [x] Subtask 6.2: Restarted LiteLLM deployment
  - [x] Subtask 6.3: Rollout completed successfully

- [x] Task 7: Validate cloud models are accessible (AC: #5)
  - [x] Subtask 7.1: All 3 cloud models appear in `/v1/models`: cloud-kimi, cloud-minimax, cloud-qwen3-coder
  - [x] Subtask 7.2: Test inference to cloud-kimi: response "Hello" in 4.1s, `model: cloud-kimi` confirmed (not fallback)
  - [x] Subtask 7.3: Prometheus metrics confirmed: `requested_model="cloud-kimi"` with `status_code="200"`

## Gap Analysis

**Scan timestamp:** 2026-02-19

### What Exists
- `applications/litellm/configmap.yaml` — 9 model entries in `model_list` (vllm-qwen, vllm-r1, ollama-qwen, openai-gpt4o, granite-docling, groq×2, gemini×2, mistral×1); current `fallbacks` single-line at line 183
- `applications/litellm/secret.yaml` — contains LITELLM_MASTER_KEY, DATABASE_URL, OPENAI_API_KEY, GROQ_API_KEY, GEMINI_API_KEY, MISTRAL_API_KEY with kubectl patch documentation

### What's Missing
- `cloud-kimi`, `cloud-minimax`, `cloud-qwen3-coder` model entries (not present)
- Expanded 4-entry `fallbacks` block (current is 2-entry single-line)
- `OLLAMA_API_KEY` placeholder + kubectl patch documentation in secret.yaml
- Story 26.1 and FR215-FR218 in configmap header

### Task Changes Applied
**NO CHANGES** — Draft tasks accurately reflect current codebase state.

---

## Dev Notes

### Critical Architecture Rules (DO NOT DEVIATE)

**Provider and API Base:**
- Provider: `ollama_chat` — NOT `openai`, NOT `ollama` (those won't work with Ollama cloud API)
- API base: `https://ollama.com/api` — CRITICAL: `/api` suffix is required. `https://ollama.com` without suffix returns 404.
- [Source: docs/planning-artifacts/architecture.md#Ollama-Pro-Cloud-Model-Integration-Architecture-Epic-26]

**Model Tag Format:**
- Tags MUST use `-cloud` suffix: `{model}:XXb-cloud` (e.g., `kimi-k2.5:32b-cloud`)
- Omitting `-cloud` suffix returns "model not found" from the Ollama API
- Exact numeric parameter size (the `XXb` part) must be verified at implementation via Ollama Pro dashboard or `ollama ls --cloud`
- Exception: `qwen3-coder:480b-cloud` — architecture explicitly specifies `480b-cloud` (not `qwen3-coder-next`)
- [Source: docs/planning-artifacts/architecture.md#Ollama-Pro-Cloud-Model-Integration-Architecture-Epic-26]

**Secret Management:**
- `OLLAMA_API_KEY` MUST be applied via `kubectl patch` ONLY — never via `kubectl apply` with placeholder value
- This is a hard cluster-wide rule (see MEMORY.md: Critical Secrets Management)
- [Source: docs/planning-artifacts/architecture.md#LiteLLM-Secret-Patch, MEMORY.md]

**Fallback Chain:**
- Current fallbacks line (to be replaced): `fallbacks: [{"vllm-qwen": ["ollama-qwen"]}, {"ollama-qwen": ["openai-gpt4o"]}]`
- openai-gpt4o MUST stay in model_list (needed for explicit selection by users) — only removed from auto-fallback
- [Source: applications/litellm/configmap.yaml:183, FR218]

### Files to Modify

| File | Change |
|------|--------|
| `applications/litellm/configmap.yaml` | Add 3 cloud model entries to `model_list`; update `fallbacks` in `litellm_settings` |
| `applications/litellm/secret.yaml` | Add `OLLAMA_API_KEY` placeholder + kubectl patch documentation |

### Current LiteLLM Configmap State

Current `model_list` ends with Mistral models (line ~162). Cloud model entries insert before the `router_settings` block. Current `fallbacks` is a single line at line 183:
```yaml
fallbacks: [{"vllm-qwen": ["ollama-qwen"]}, {"ollama-qwen": ["openai-gpt4o"]}]
```

This must be replaced with an expanded YAML block for 4 fallback entries. Example pattern (from architecture):
```yaml
fallbacks:
  - {"cloud-kimi":        ["cloud-minimax", "vllm-qwen", "ollama-qwen"]}
  - {"cloud-minimax":     ["vllm-qwen", "ollama-qwen"]}
  - {"cloud-qwen3-coder": ["vllm-qwen", "ollama-qwen"]}
  - {"vllm-qwen":         ["ollama-qwen"]}
# openai-gpt4o: explicit parallel only — removed from auto-fallback (FR218)
```

### LiteLLM Configmap Pattern (from existing entries)

```yaml
- model_name: cloud-kimi
  litellm_params:
    model: ollama_chat/kimi-k2.5:<CONFIRMED-TAG>-cloud  # verify exact tag first
    api_base: https://ollama.com/api
    api_key: os.environ/OLLAMA_API_KEY
    timeout: 60
  model_info:
    mode: chat
```

### Testing Approach

1. **Pre-deployment validation:** `kubectl diff -f applications/litellm/configmap.yaml` to review changes
2. **Model availability check:** `GET /v1/models` — all three cloud model names must appear
3. **Inference test:** POST to `/v1/chat/completions` with `model: cloud-kimi`
4. **Metrics check:** `GET /metrics` should show `litellm_requests_total{model="cloud-kimi",...}`
5. **Fallback test (optional):** Set wrong api_key temporarily, verify fallback to `vllm-qwen` within 5s

### LiteLLM Deployment Details

- Namespace: `ml`
- Deployment: `litellm`
- Service endpoint (cluster-internal): `http://litellm.ml.svc.cluster.local:4000/v1`
- Master key: `sk-litellm-X85qLfwJKERbijaT3KDwgZvTKGXl21Rd` (in `applications/litellm/secret.yaml`)
- Config hot-reload: LiteLLM supports config hot-reload, but rolling restart is more reliable for configmap changes

### Recent Work Context (from git)

- Story 25.5 (VLM OCR via remote): added `granite-docling` model entry to LiteLLM configmap — same `model_list` + pattern this story follows
- Story 25.4 (Paperless-GPT): Paperless-GPT uses `OPENAI_API_BASE: litellm.ml.svc...` and `LLM_MODEL: vllm-qwen` configmap pattern
- All recent work: single-namespace manifest files, `kubectl apply -f` pattern for deployment

### Project Structure Notes

- Alignment: `applications/litellm/` contains all LiteLLM manifests (configmap.yaml, deployment.yaml, secret.yaml, ingressroute.yaml)
- Naming: cloud model names follow `cloud-{provider-shortname}` pattern (e.g., `cloud-kimi`, `cloud-minimax`)
- Comments: configmap.yaml header section lists Story references and FR/NFR numbers — add Story 26.1 and FR215-FR218 to header
- Secret pattern: empty placeholder in git, real value applied via `kubectl patch` only

### References

- [Source: docs/planning-artifacts/architecture.md#Ollama-Pro-Cloud-Model-Integration-Architecture-Epic-26]
- [Source: docs/planning-artifacts/epics.md#Story-26.1]
- [Source: docs/analysis/brainstorming-session-2026-02-19.md]
- [Source: applications/litellm/configmap.yaml] — current config to modify
- [Source: applications/litellm/secret.yaml] — secret placeholder to update
- FRs: FR215 (OLLAMA_API_KEY secret), FR216 (model_list entries), FR217 (fallback chains), FR218 (remove openai-gpt4o from auto-fallback)
- NFRs: NFR121 (60s timeout), NFR122 (kubectl patch only), NFR123 (5s failover)

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

- Discovered `api_base: https://ollama.com/api` caused double-path error (`/api/api/chat`). LiteLLM's `ollama_chat` provider appends `/api/chat` internally. Fixed to `api_base: https://ollama.com`.
- Architecture doc stated `-cloud` suffix required on model tags — incorrect. Actual Ollama Pro API returns model names without `-cloud` suffix (verified via `/api/tags`).

### Completion Notes List

- OLLAMA_API_KEY patched into `litellm-secrets` via `kubectl patch --type='merge'` (NFR122 compliant)
- 3 cloud models added to model_list: cloud-kimi (`ollama_chat/kimi-k2.5`), cloud-minimax (`ollama_chat/minimax-m2.5`), cloud-qwen3-coder (`ollama_chat/qwen3-coder:480b`)
- Fallback chain expanded from 2-entry to 4-entry; cloud models are now primary tier
- openai-gpt4o removed from auto-fallback (FR218); remains in model_list for explicit selection
- Inference validated: cloud-kimi returned response in 4.1s with correct model attribution
- Prometheus metrics confirmed tracking cloud model requests

### File List

- `applications/litellm/configmap.yaml` — added 3 cloud model entries, updated fallbacks, updated header
- `applications/litellm/secret.yaml` — added OLLAMA_API_KEY placeholder + kubectl patch documentation

## Change Log

- 2026-02-19: Tasks refined based on codebase gap analysis; Status → in-progress (claude-sonnet-4-6)
- 2026-02-19: Implemented all 7 tasks; discovered and corrected api_base format (no /api suffix) and model tag format (no -cloud suffix); Status → review (claude-sonnet-4-6)
