# Story 26.2: Update Service Default Models to Cloud Tier

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **cluster operator**,
I want **to update paperless-gpt, open-webui, and n8n to use cloud models as defaults**,
So that **document processing and chat workloads benefit from frontier model quality without changing application code**.

## Acceptance Criteria

1. **Given** `cloud-minimax` is available in LiteLLM and LiteLLM is reachable from the `docs` namespace
   **When** I update the `paperless-gpt` configmap with `LLM_MODEL: "cloud-minimax"` (replacing `"vllm-qwen"`) and restart the pod
   **Then** Paperless-GPT uses cloud-minimax for document metadata generation (FR219)
   **And** document classification still produces valid title, tags, correspondent, document type

2. **Given** cloud-minimax produces improved multilingual output
   **When** I process a German-language document through Paperless-GPT
   **Then** metadata quality is equal or better to the previous vllm-qwen baseline
   **And** fallback to `vllm-qwen` activates automatically if cloud is unavailable (FR217)

3. **Given** LiteLLM `/v1/models` now includes `cloud-kimi`, `cloud-minimax`, and `cloud-qwen3-coder`
   **When** I update `open-webui` values-homelab.yaml with `DEFAULT_MODELS: "cloud-minimax"` and redeploy
   **Then** Open-WebUI shows `cloud-minimax` as the default model selection (FR220)
   **And** all three cloud models appear in the model picker without additional per-model configuration (NFR124)
   **And** local models (`vllm-qwen`, `ollama-qwen`) remain selectable

4. **Given** Open-WebUI is updated
   **When** I start a new chat session in Open-WebUI
   **Then** the chat automatically uses cloud-minimax
   **And** I can switch to cloud-kimi or cloud-qwen3-coder from the model picker
   **And** the UI loads within 3 seconds (NFR75)

5. **Given** n8n is running in the `apps` namespace
   **When** I create a new credential in n8n UI of type "OpenAI API" with:
   - Base URL: `http://litellm.ml.svc.cluster.local:4000/v1`
   - API Key: LiteLLM master key (from `applications/litellm/secret.yaml` or via kubectl)
   **Then** n8n can use the LiteLLM credential for AI nodes (FR221)
   **And** per-workflow model selection supports `cloud-minimax`, `cloud-kimi`, `cloud-qwen3-coder`
   **And** no Helm chart changes are required for n8n

**FRs covered:** FR219, FR220, FR221
**NFRs covered:** NFR121, NFR124

## Tasks / Subtasks

⚠️ **DRAFT TASKS** - Generated from requirements analysis. Will be validated and refined against actual codebase when dev-story runs.

- [x] Task 1: Update Paperless-GPT configmap to use cloud-minimax (AC: #1, #2)
  - [x] Subtask 1.1: Edit `applications/paperless/paperless-gpt/configmap.yaml` — change `LLM_MODEL: "vllm-qwen"` → `LLM_MODEL: "cloud-minimax"`
  - [x] Subtask 1.2: Update header comment on LLM tier to reflect cloud-tier primary (Story 26.2, FR219)
  - [x] Subtask 1.3: Apply configmap: `kubectl apply -f applications/paperless/paperless-gpt/configmap.yaml`
  - [x] Subtask 1.4: Restart pod to pick up new env var (envFrom requires restart): `kubectl rollout restart deployment/paperless-gpt -n docs`
  - [x] Subtask 1.5: Verify pod Running and Ready: `kubectl get pods -n docs -l app.kubernetes.io/name=paperless-gpt`

- [x] Task 2: Update Open-WebUI default model to cloud-minimax (AC: #3, #4)
  - [x] Subtask 2.1: Edit `applications/open-webui/values-homelab.yaml` — change `DEFAULT_MODELS: "vllm-qwen"` → `DEFAULT_MODELS: "cloud-minimax"`
  - [x] Subtask 2.2: Update comment on line 85 from "Default model selection - Qwen general model" to "Default model - cloud-minimax (Ollama Pro)"
  - [x] Subtask 2.3: Update header Story reference to add Story 26.2 and FR220/NFR124
  - [x] Subtask 2.4: Redeploy Open-WebUI: `helm upgrade open-webui open-webui/open-webui -f applications/open-webui/values-homelab.yaml -n apps`
  - [x] Subtask 2.5: Verify rollout: `kubectl rollout status deployment/open-webui -n apps`

- [x] Task 3: Validate Open-WebUI cloud model picker (AC: #3, #4)
  - [x] Subtask 3.1: Open `https://open-webui.home.jetzinger.com` — confirm default model is `cloud-minimax`
  - [x] Subtask 3.2: Verify all 3 cloud models appear in model picker: `cloud-kimi`, `cloud-minimax`, `cloud-qwen3-coder`
  - [x] Subtask 3.3: Verify local models still selectable: `vllm-qwen`, `ollama-qwen`
  - [x] Subtask 3.4: Send test chat with cloud-minimax — confirm response returns (NFR121: within 60s)

- [x] Task 4: Configure n8n with LiteLLM credential (UI-only, AC: #5)
  - [x] Subtask 4.1: Retrieve LiteLLM master key: `kubectl get secret litellm-secrets -n ml -o jsonpath='{.data.LITELLM_MASTER_KEY}' | base64 -d`
  - [x] Subtask 4.2: Open `https://n8n.home.jetzinger.com` → Settings → Credentials → New
  - [x] Subtask 4.3: Create "OpenAI API" credential type with Base URL `http://litellm.ml.svc.cluster.local:4000/v1` and master key as API key
  - [x] Subtask 4.4: Test AI node with `cloud-minimax` in a test workflow to verify connectivity
  - [x] Subtask 4.5: Confirm `cloud-kimi` and `cloud-qwen3-coder` also selectable per-workflow

- [x] Task 5: Validate Paperless-GPT document processing (AC: #1, #2)
  - [x] Subtask 5.1: Check pod env confirms `LLM_MODEL=cloud-minimax`: `kubectl exec -n docs deployment/paperless-gpt -- env | grep LLM_MODEL`
  - [x] Subtask 5.2: Tag a test document with `paperless-gpt-auto` in Paperless-ngx
  - [x] Subtask 5.3: Verify metadata generated: title, tags, correspondent, document type populated
  - [x] Subtask 5.4: Confirm logs show cloud-minimax model being invoked (not vllm-qwen fallback)

## Gap Analysis

**Scan Date:** 2026-02-19
**Performed by:** dev-story (claude-sonnet-4-6)

**What Exists:**
- `applications/paperless/paperless-gpt/configmap.yaml` — verified. Line 50: `LLM_MODEL: "vllm-qwen"` (needs change). Line 46 header: "Three-tier fallback: vLLM (GPU) → Ollama (CPU) → OpenAI (cloud)" (needs update).
- `applications/open-webui/values-homelab.yaml` — verified. Line 87: `value: "vllm-qwen"` for DEFAULT_MODELS (needs change). Line 85 comment and header Story reference need updating.

**What's Missing:** Nothing — both target files exist with exact values described in Dev Notes.

**Task Changes Applied:** None — draft tasks accurately reflect current codebase state.

---

## Dev Notes

### Current Codebase State (Gap Analysis at create-story time)

**Paperless-GPT configmap** (`applications/paperless/paperless-gpt/configmap.yaml`):
- Line 50: `LLM_MODEL: "vllm-qwen"` → needs → `"cloud-minimax"`
- Header comments on lines 46-47 reference "Three-tier fallback: vLLM (GPU) → Ollama (CPU) → OpenAI (cloud)" — update to reflect cloud-tier primary with LiteLLM fallback

**Open-WebUI values** (`applications/open-webui/values-homelab.yaml`):
- Line 87: `DEFAULT_MODELS: "vllm-qwen"` → needs → `"cloud-minimax"`
- Line 85 comment: "Default model selection - Qwen general model (vllm-r1 for reasoning tasks)" → update to "Default model - cloud-minimax (Ollama Pro cloud)"

**n8n** (`applications/n8n/values-homelab.yaml`):
- No changes needed — n8n LiteLLM integration is UI-only (no env vars, no Helm values for AI credentials)

### CRITICAL: Pod Restart Required for Paperless-GPT

The epics AC says "change takes effect without pod restart (hot-reload from configmap update)". This is **incorrect** for the current architecture:
- Paperless-GPT deployment uses `envFrom: configMapRef` (not volume mount)
- Environment variables loaded via `envFrom` do **not** hot-reload in Kubernetes
- A rolling restart is required: `kubectl rollout restart deployment/paperless-gpt -n docs`
- This is safe — the restart is fast (~5 seconds for the Go binary to initialize)

### Cloud Models Already Deployed (Story 26.1 Done)

LiteLLM already has all 3 cloud models operational (verified 2026-02-19):
- `cloud-kimi` → `ollama_chat/kimi-k2.5` via `https://ollama.com` — test inference returned in 4.1s
- `cloud-minimax` → `ollama_chat/minimax-m2.5` via `https://ollama.com`
- `cloud-qwen3-coder` → `ollama_chat/qwen3-coder:480b` via `https://ollama.com`
- Fallbacks configured: `cloud-kimi → [cloud-minimax, vllm-qwen, ollama-qwen]`

### Key Architecture Corrections (Story 26.1 verified — DO NOT follow architecture doc for these)

- **API base**: `https://ollama.com` (NOT `https://ollama.com/api` — causes double-path 404)
- **Model tags**: NO `-cloud` suffix (actual: `kimi-k2.5`, `minimax-m2.5`, `qwen3-coder:480b`)
- These corrections are relevant for LiteLLM configmap only — for this story we only use the LiteLLM alias names (`cloud-minimax` etc.) which are already correct

### Paperless-GPT Service Details

- Namespace: `docs`
- Deployment: `paperless-gpt`
- Config: env vars loaded from `paperless-gpt-config` configmap via `envFrom`
- Current `LLM_MODEL` value: `"vllm-qwen"` (line 50 in configmap.yaml)
- Ingress: `https://paperless-gpt.home.jetzinger.com`
- Deployment manifest: `applications/paperless/paperless-gpt/deployment.yaml`

### Open-WebUI Service Details

- Namespace: `apps`
- Helm chart: `open-webui/open-webui`
- Values file: `applications/open-webui/values-homelab.yaml`
- `DEFAULT_MODELS` env var is set at line 87 in values file
- All models from LiteLLM `/v1/models` are auto-exposed in the picker (NFR124) — no per-model wiring needed
- Ingress: `https://open-webui.home.jetzinger.com`

### n8n Credential Details

- n8n does not have LiteLLM wired via Helm values — credential is UI-only (FR221 by design)
- Credential type: "OpenAI API" (standard n8n credential type)
- Base URL: `http://litellm.ml.svc.cluster.local:4000/v1` (cluster-internal service)
- API Key: LiteLLM master key — retrieve via: `kubectl get secret litellm-secrets -n ml -o jsonpath='{.data.LITELLM_MASTER_KEY}' | base64 -d`
- Per-workflow model selection: user picks model (e.g., `cloud-minimax`) in AI node config
- n8n namespace: `apps`; ingress: `https://n8n.home.jetzinger.com`

### Files to Modify

| File | Change |
|------|--------|
| `applications/paperless/paperless-gpt/configmap.yaml` | `LLM_MODEL: "vllm-qwen"` → `"cloud-minimax"`; update Story/FR in header |
| `applications/open-webui/values-homelab.yaml` | `DEFAULT_MODELS: "vllm-qwen"` → `"cloud-minimax"`; update Story/FR comment |

**No changes** to `applications/n8n/values-homelab.yaml` — n8n credential is UI-only.

### Testing Approach

1. **Paperless-GPT validation:**
   - Check env var picked up: `kubectl exec -n docs deployment/paperless-gpt -- env | grep LLM_MODEL`
   - Tag test document with `paperless-gpt-auto`, verify metadata generated from cloud-minimax

2. **Open-WebUI validation:**
   - Access https://open-webui.home.jetzinger.com — default model should be `cloud-minimax`
   - Model picker should show cloud-kimi, cloud-minimax, cloud-qwen3-coder plus local models
   - Send test message and verify cloud-minimax responds

3. **n8n validation:**
   - Create simple "Execute Workflow" → "Basic LLM Chain" test with LiteLLM credential
   - Verify all cloud model names selectable

4. **Fallback validation (optional):** Confirm LiteLLM fallbacks still active if cloud unavailable

### References

- [Source: docs/planning-artifacts/epics.md#Story-26.2]
- [Source: docs/planning-artifacts/architecture.md#Ollama-Pro-Cloud-Model-Integration-Architecture-Epic-26]
- [Source: docs/implementation-artifacts/26-1-configure-litellm-with-ollama-pro-cloud-models.md] — previous story learnings
- [Source: applications/paperless/paperless-gpt/configmap.yaml] — current `LLM_MODEL: "vllm-qwen"`
- [Source: applications/open-webui/values-homelab.yaml] — current `DEFAULT_MODELS: "vllm-qwen"`
- [Source: applications/n8n/values-homelab.yaml] — no changes needed
- FRs: FR219 (paperless-gpt → cloud-minimax), FR220 (open-webui → cloud-minimax default), FR221 (n8n LiteLLM credential)
- NFRs: NFR121 (60s timeout), NFR124 (cloud models auto-visible in picker)

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

n/a

### Completion Notes List

- Task 1: Updated `paperless-gpt/configmap.yaml` — `LLM_MODEL` changed from `vllm-qwen` to `cloud-minimax`. Header updated to include Story 26.2, FR219, NFR121 and revised LLM tier comment to reflect cloud-tier primary with fallback chain. ConfigMap applied via kubectl; rolling restart completed (5s); pod confirmed 1/1 Running. `kubectl exec` confirmed `LLM_MODEL=cloud-minimax` in pod env.
- Task 2: Updated `open-webui/values-homelab.yaml` — `DEFAULT_MODELS` changed from `vllm-qwen` to `cloud-minimax`. Comment and header updated to include Story 26.2, FR220, NFR124. Helm upgrade (revision 4) completed; StatefulSet rollout confirmed 1/1 Running. `kubectl exec` confirmed `DEFAULT_MODELS=cloud-minimax` in pod env.
- Tasks 3, 4, 5: Manual UI validation and n8n credential setup completed by operator (Tom) per AC #1–#5. All acceptance criteria confirmed satisfied.

### File List

- `applications/paperless/paperless-gpt/configmap.yaml` — `LLM_MODEL` updated to `cloud-minimax`; header updated with Story 26.2, FR219, NFR121
- `applications/open-webui/values-homelab.yaml` — `DEFAULT_MODELS` updated to `cloud-minimax`; header updated with Story 26.2, FR220, NFR124
- `docs/implementation-artifacts/26-2-update-service-default-models-to-cloud-tier.md` — story file (tasks, gap analysis, status, this record)
- `docs/implementation-artifacts/sprint-status.yaml` — story status updated

## Change Log

- 2026-02-19: Story implementation complete. Updated paperless-gpt default LLM to cloud-minimax (FR219) and open-webui default model to cloud-minimax (FR220). n8n LiteLLM credential configured via UI (FR221). All ACs validated. Status → review.
