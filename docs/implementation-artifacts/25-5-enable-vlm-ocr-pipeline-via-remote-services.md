# Story 25.5: Enable VLM OCR Pipeline via Remote Services

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **cluster operator**,
I want **to enable Docling's VLM pipeline for scanned/image-only PDFs by routing VLM inference through LiteLLM to Ollama serving Granite-Docling 258M**,
So that **scanned documents are processed with layout-aware OCR while maintaining the existing LiteLLM proxy pattern and graceful degradation**.

## Acceptance Criteria

1. **Given** Ollama is running on k3s-worker-02 with phi4-mini
   **When** I verify `ibm/granite-docling:258m` is available on Ollama
   **Then** the model is available alongside phi4-mini (FR210)
   **And** Ollama memory footprint increases by <500MB (NFR118)
   **And** I can verify the model responds to vision requests via `curl http://ollama:11434/v1/chat/completions`

2. **Given** Docling server is running with standard pipeline on k3s-worker-01
   **When** I add `DOCLING_SERVE_ENABLE_REMOTE_SERVICES=true` to the Docling deployment
   **And** I submit a scanned image/PDF with VLM pipeline configuration pointing to Ollama
   **Then** Docling sends VLM requests to Ollama and returns structured OCR output (FR209)
   **And** VLM inference completes within 120 seconds per page on CPU (NFR117)

3. **Given** VLM pipeline confirmed working with Ollama directly
   **When** I add a `granite-docling` model alias to LiteLLM configmap pointing to Ollama `ibm/granite-docling:258m`
   **Then** LiteLLM routes `granite-docling` requests to Ollama (FR211)
   **And** the model is NOT added to the general text fallback chain (vllm-qwen → ollama-qwen → openai)

4. **Given** LiteLLM serves granite-docling
   **When** I update the Docling VLM request to route through LiteLLM
   **Then** Docling calls LiteLLM which routes to Ollama for VLM inference (FR212)
   **And** the scanned PDF is processed with OCR text extraction via Granite-Docling 258M (FR213)
   **And** structured DocTags output is returned with extracted text content
   **And** VLM inference completes within 120 seconds per page on CPU (NFR117)
   **And** end-to-end processing completes within 10 minutes for a typical multi-page scanned document (NFR119)

5. **Given** Ollama or LiteLLM is unavailable
   **When** Docling attempts a VLM pipeline request
   **Then** Docling degrades gracefully to standard pipeline (EasyOCR) (FR214, NFR120)
   **And** no pod crash or request hang occurs

6. **Given** VLM OCR pipeline is operational via direct Docling API
   **When** I submit a scanned document using the async endpoint (`POST /v1/convert/source/async`) with VLM pipeline configuration
   **Then** Docling returns a `task_id` immediately
   **And** I can poll `/v1/status/poll/{task_id}` until processing completes
   **And** I can retrieve structured OCR results via `/v1/results/{task_id}`
   **And** multi-page scanned documents complete without sync timeout issues

**Known Limitation — Paperless-GPT VLM Integration:**
Paperless-GPT v0.24.0 uses sync-only Docling API (`POST /v1/convert/file`) and does NOT pass `vlm_pipeline_model_api` in requests. This means Paperless-GPT cannot trigger VLM OCR pipeline — it continues using the standard/EasyOCR pipeline. VLM OCR is available via direct Docling API calls only. A future Paperless-GPT PR or Docling server-side defaults (issue #463) would be needed to close this gap.

**FRs covered:** FR209, FR210, FR211, FR212, FR213, FR214
**NFRs covered:** NFR117, NFR118, NFR119, NFR120

## Tasks / Subtasks

⚠️ **DRAFT TASKS** - Generated from requirements analysis. Will be validated and refined against actual codebase when dev-story runs.

- [x] Task 1: Verify Granite-Docling 258M on Ollama (AC: #1)
  - [x] 1.1 Confirm `ibm/granite-docling:258m` is already pulled on Ollama (spike pulled it on 2026-02-14)
  - [x] 1.2 Verify model responds to vision requests via OpenAI-compatible endpoint
  - [x] 1.3 Measure Ollama memory footprint with granite-docling loaded (spike showed +17Mi idle)

- [x] Task 2: Enable remote services on Docling deployment (AC: #2)
  - [x] 2.1 Add `DOCLING_SERVE_ENABLE_REMOTE_SERVICES: "true"` env var to `applications/paperless/docling/deployment.yaml`
  - [x] 2.2 Apply updated deployment: `kubectl apply -f applications/paperless/docling/deployment.yaml`
  - [x] 2.3 Wait for Docling pod rollout and verify health endpoint
  - [x] 2.4 Test VLM pipeline with direct Ollama URL using validated request format:
    ```json
    {
      "options": {
        "pipeline": "vlm",
        "vlm_pipeline_model_api": {
          "url": "http://ollama.ml.svc.cluster.local:11434/v1/chat/completions",
          "params": {"model": "ibm/granite-docling:258m", "max_completion_tokens": 4096},
          "response_format": "doctags",
          "timeout": 240
        },
        "to_formats": ["md"]
      }
    }
    ```
  - [x] 2.5 Verify structured OCR output returned within 120s/page

- [x] Task 3: Add granite-docling model to LiteLLM (AC: #3)
  - [x] 3.1 Add `granite-docling` model entry to `applications/litellm/configmap.yaml` pointing to Ollama `ibm/granite-docling:258m`
  - [x] 3.2 Ensure model is NOT in any fallback chain — standalone, explicit selection only
  - [x] 3.3 Apply configmap and restart LiteLLM pod (configmap changes require restart)
  - [x] 3.4 Verify LiteLLM routes `granite-docling` requests to Ollama

- [x] Task 4: Route Docling VLM through LiteLLM (AC: #4)
  - [x] 4.1 Test VLM pipeline with LiteLLM URL:
    ```json
    {
      "options": {
        "pipeline": "vlm",
        "vlm_pipeline_model_api": {
          "url": "http://litellm.ml.svc.cluster.local:4000/v1/chat/completions",
          "params": {"model": "granite-docling"},
          "response_format": "doctags",
          "timeout": 240
        },
        "to_formats": ["md"]
      }
    }
    ```
  - [x] 4.2 Verify end-to-end: Docling → LiteLLM → Ollama → structured DocTags output
  - [x] 4.3 Verify latency within NFR117 (120s/page) and NFR119 (10 min multi-page)

- [x] Task 5: Test graceful degradation (AC: #5)
  - [x] 5.1 Stop Ollama or make it unavailable temporarily
  - [x] 5.2 Submit VLM pipeline request to Docling
  - [x] 5.3 Verify Docling degrades gracefully (no crash, no hang)
  - [x] 5.4 Verify standard pipeline (EasyOCR) continues working during Ollama outage
  - [x] 5.5 Restore Ollama and verify VLM pipeline recovers

- [x] Task 6: Validate async Docling API for multi-page scanned documents (AC: #6)
  - [x] 6.1 Test async endpoint: `POST /v1/convert/file/async` with VLM pipeline config through LiteLLM
  - [x] 6.2 Poll task status via `GET /v1/status/poll/{task_id}` until completion
  - [x] 6.3 Retrieve results via `GET /v1/result/{task_id}` (singular) and verify structured OCR output
  - [x] 6.4 Test with 2 pages sequentially to confirm no sync timeout issues (~10s each)
  - [x] 6.5 Document async API usage pattern for future Paperless-GPT integration

- [x] Task 7: Update manifests and documentation (AC: all)
  - [x] 7.1 Add FR/NFR traceability comment headers to modified manifest files
  - [x] 7.2 Update story file with implementation details, gap analysis, and dev notes

## Gap Analysis

**Scan Date:** 2026-02-14

✅ **What Exists:**
- `applications/paperless/docling/deployment.yaml` — Docling deployment with memory optimization, no remote services env var
- `applications/litellm/configmap.yaml` — LiteLLM config with 3-tier fallback + parallel models, no granite-docling entry
- `applications/paperless/paperless-gpt/configmap.yaml` — Paperless-GPT with standard pipeline (no modification needed)
- Granite-Docling 258M already pulled on Ollama (spike validated 2026-02-14)
- Spike doc with validated request format and results

❌ **What's Missing:**
- `DOCLING_SERVE_ENABLE_REMOTE_SERVICES: "true"` in Docling deployment
- `granite-docling` model entry in LiteLLM configmap
- FR/NFR traceability headers for story 25.5

**Task Changes:** None — draft tasks accurately reflect codebase state

---

## Dev Notes

### Architecture Compliance

- **Namespace:** `docs` for Docling, `ml` for LiteLLM — modifications to existing deployments in their respective namespaces
- **LiteLLM proxy pattern:** ALL LLM/VLM calls route through LiteLLM — granite-docling is no exception (FR211, FR212)
- **No new deployments** — this story modifies existing Docling deployment + LiteLLM configmap + possibly Paperless-GPT config
- **Labels/naming:** No new resources to label — modifications only
- **Secrets:** No new secrets required — LiteLLM already has Ollama backend configured

### Critical Implementation Details

**Validation Spike Results (2026-02-14) — GO Decision:**
- docling-serve v1.12.0 accepts `vlm_pipeline_model_api` — issue #318 (schema drop) is fixed
- Docling successfully calls remote Ollama and returns structured OCR output
- `response_format: "doctags"` is a **required** field in `vlm_pipeline_model_api`
- CPU inference latency: ~90s/page (NFR117 target: 120s — within budget)
- Ollama memory: +17Mi idle with `granite-docling:258m` loaded (521MB on disk)
- Test: image of data table → correctly extracted to markdown with full table structure

**VLM Pipeline Request Format (validated):**
```json
{
  "options": {
    "pipeline": "vlm",
    "vlm_pipeline_model_api": {
      "url": "http://litellm.ml.svc.cluster.local:4000/v1/chat/completions",
      "params": {"model": "granite-docling", "max_completion_tokens": 4096},
      "response_format": "doctags",
      "timeout": 240
    },
    "to_formats": ["md"]
  }
}
```

**Key difference from standard pipeline:**
- Standard pipeline: `{"options": {"pipeline": "standard", "to_formats": ["md"]}}` — uses EasyOCR for OCR
- VLM pipeline: Adds `vlm_pipeline_model_api` block with remote model endpoint — uses Granite-Docling 258M for layout-aware OCR
- VLM is per-request configuration, not a server-level setting
- `DOCLING_SERVE_ENABLE_REMOTE_SERVICES=true` is the only server-level change needed

**Three-Tier Pipeline After This Story:**
```
Digital PDFs:  Docling (standard/EasyOCR) → LiteLLM → Qwen3/phi4-mini → metadata
Scanned PDFs:  Docling (VLM → LiteLLM → Ollama/granite-docling) → LiteLLM → Qwen3/phi4-mini → metadata
```

**Paperless-GPT VLM Limitation (researched 2026-02-14):**
Paperless-GPT v0.24.0 `ocr/docling_provider.go` uses:
- **Sync-only** endpoint: `POST /v1/convert/file` (no async support)
- Passes `pipeline` as multipart form field from `DOCLING_OCR_PIPELINE` env var
- Does **NOT** construct or send `vlm_pipeline_model_api` block
- No explicit HTTP timeout (only retry logic: 3 retries, 1-10s backoff)

This means even setting `DOCLING_OCR_PIPELINE=vlm` would tell Docling to use VLM but without
a `vlm_pipeline_model_api` endpoint, Docling has no remote model to call. Two blockers:
1. No `vlm_pipeline_model_api` in request → Docling doesn't know where VLM model lives
2. Sync endpoint 120s timeout → multi-page scanned docs at ~90s/page will timeout

**Scope decision:** VLM OCR is available via direct Docling API (sync for single-page, async for multi-page).
Paperless-GPT continues using standard/EasyOCR pipeline. Follow-up options:
- Upstream PR to Paperless-GPT adding VLM config env vars + async endpoint support
- Docling server-side VLM defaults via env vars (issue #463, open)

**Docling Async API (for multi-page VLM):**
- Submit: `POST /v1/convert/source/async` (same request body as sync)
- Poll: `GET /v1/status/poll/{task_id}` (optional `?wait=30` for long-poll)
- Results: `GET /v1/results/{task_id}` (returns structured output)
- Single-worker Docling setup avoids known multi-worker polling issues (#378, #467)

**Current Docling Deployment (file to modify):**
- `applications/paperless/docling/deployment.yaml` — Add `DOCLING_SERVE_ENABLE_REMOTE_SERVICES: "true"` env var

**Current LiteLLM ConfigMap (file to modify):**
- `applications/litellm/configmap.yaml` — Add `granite-docling` model entry (standalone, NOT in fallback chain)

**Paperless-GPT ConfigMap — NO modification needed:**
- `applications/paperless/paperless-gpt/configmap.yaml` — Stays `DOCLING_OCR_PIPELINE: "standard"` (VLM not supported by Paperless-GPT)

### Story 25.4 Learnings (Previous Story)

- **Service naming:** Use `-svc` suffix to avoid K8s env var collisions
- **LiteLLM configmap changes require pod restart** to take effect
- **Test full pipeline end-to-end** — GPU fallback validated in 25.4 (2m44s via Ollama vs 35s GPU)
- **Prompt template persistence verified** — 8 templates in `/app/prompts/` survive pod restarts via NFS PVC
- **No curl in most containers** — use ephemeral curl pods for testing
- **Architecture doc corrections:** Port 8080 (not 3000), `OPENAI_BASE_URL` (not `OPENAI_API_BASE`), Docling port 5001 (not 8000)

### Story 25.3 Learnings (Docling Story)

- **VLM pipeline NOT supported on CPU image** — use `DOCLING_SERVE_ENABLE_REMOTE_SERVICES=true` with external VLM (this story's approach)
- **Docling port is 5001** (not 8000)
- **Memory optimization already applied** — lazy loading, shared models, reduced batch sizes
- **OOM risk with multi-page PDFs** — limit is 4Gi, peaks to 1.9Gi during standard inference; VLM may increase peak
- **Standard pipeline timing:** 3-8s for 1-3 page documents
- **VLM pipeline timing (spike):** ~90s/page on CPU via Ollama

### Key Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| VLM pipeline increases Docling memory beyond 4Gi limit | VLM inference happens remotely on Ollama, not in Docling pod — Docling just sends/receives API calls |
| LiteLLM doesn't support granite-docling model format | Ollama backend already works for phi4-mini; same pattern for granite-docling (vision model served via OpenAI-compatible API) |
| Paperless-GPT can't trigger VLM pipeline | **Confirmed limitation** — v0.24.0 uses sync API, no `vlm_pipeline_model_api` support. Scoped out: VLM available via direct API only. Follow-up: upstream PR or Docling #463 |
| Sync timeout on multi-page scanned docs | Use async Docling endpoint (`/v1/convert/source/async`) with task polling for multi-page VLM processing |
| Granite-docling model evicted from Ollama memory under pressure | Model is only 258M (521MB disk); phi4-mini is ~2.5GB; k3s-worker-02 has 8GB — both fit comfortably |
| Docling issue #463 (env var defaults) still open | Not a blocker — per-request VLM config works (validated in spike) |

### Anti-Patterns to Avoid

- **NEVER** add `granite-docling` to the LiteLLM text fallback chain — it's a vision/OCR model, not a text model
- **NEVER** bypass LiteLLM for VLM calls — use `http://litellm.ml.svc.cluster.local:4000/v1/chat/completions` not Ollama directly (architectural consistency)
- **NEVER** omit `response_format: "doctags"` from VLM API config — Granite-Docling requires it
- **NEVER** set `DOCLING_OCR_PIPELINE=vlm` in Paperless-GPT configmap — Paperless-GPT cannot pass `vlm_pipeline_model_api`, so Docling would attempt VLM with no remote model configured
- **NEVER** use the sync Docling endpoint for multi-page VLM processing — use async (`/v1/convert/source/async`) to avoid 120s timeout
- **NEVER** skip FR/NFR traceability in manifest comment headers
- **DO NOT** modify Docling memory limits — VLM inference runs on Ollama, not in the Docling pod
- **DO NOT** add `max_completion_tokens` when routing through LiteLLM if LiteLLM handles it — test both approaches

### Project Structure Notes

- Docling deployment: `applications/paperless/docling/deployment.yaml` (modify: add env var)
- LiteLLM configmap: `applications/litellm/configmap.yaml` (modify: add model entry)
- Paperless-GPT configmap: `applications/paperless/paperless-gpt/configmap.yaml` (NO modification — VLM not supported)
- VLM OCR options doc: `docs/implementation-artifacts/25-3-vlm-ocr-options.md` (reference, spike results)

### References

- [Source: docs/planning-artifacts/epics.md#Story 25.5] — User story, acceptance criteria, FR/NFR mapping
- [Source: docs/implementation-artifacts/25-3-vlm-ocr-options.md] — VLM OCR options analysis, spike results, validated request format
- [Source: docs/implementation-artifacts/25-4-deploy-paperless-gpt-and-remove-paperless-ai.md] — Previous story learnings, Paperless-GPT config details
- [Source: docs/implementation-artifacts/25-3-deploy-docling-server.md] — Docling deployment details, VLM limitation on CPU image
- [Source: docs/planning-artifacts/architecture.md#AI/ML Architecture] — LiteLLM proxy pattern, fallback chain
- [Source: applications/paperless/docling/deployment.yaml] — Current Docling deployment (target for modification)
- [Source: applications/litellm/configmap.yaml] — Current LiteLLM config (target for modification)
- [Source: applications/paperless/paperless-gpt/configmap.yaml] — Paperless-GPT config (NO modification — VLM not supported)
- [Source: https://github.com/icereed/paperless-gpt/blob/main/ocr/docling_provider.go] — Paperless-GPT Docling provider (sync-only, no vlm_pipeline_model_api)
- [Source: https://github.com/docling-project/docling-serve/issues/463] — Env var defaults issue (open, follow-up for server-side VLM defaults)
- [Source: https://github.com/icereed/paperless-gpt/issues/603] — Docling v1 API migration issue (context for sync endpoint usage)

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

- Ollama vision test: first request timed out (500) due to cold model loading, succeeded on warm retry
- Wikimedia test image 429 rate-limited — switched to generated PIL test images
- Docling async results endpoint is `/v1/result/{task_id}` (singular), not `/v1/results/` (plural) as in story draft
- LiteLLM now requires auth header (LITELLM_MASTER_KEY in secret), even though master_key is commented in config.yaml
- Docling `/v1/convert/source` does not support `base64` kind — only `file`, `http`, `s3`

### Completion Notes List

- Task 1: Granite-Docling 258M verified on Ollama — model responds to vision requests, +17Mi idle memory, 1063Mi total
- Task 2: Added `DOCLING_SERVE_ENABLE_REMOTE_SERVICES=true` to Docling deployment, tested VLM pipeline with direct Ollama — 7.4s/page
- Task 3: Added `granite-docling` model entry to LiteLLM configmap (standalone, NOT in fallback chain), verified routing
- Task 4: End-to-end VLM: Docling → LiteLLM → Ollama → structured markdown output, 7.5s/page (NFR117: <120s ✅)
- Task 5: Graceful degradation confirmed — unavailable VLM backend causes Docling to fall back to standard/EasyOCR, no crash/hang
- Task 6: Async API validated with 2-page sequential test — submit, poll, retrieve all work correctly (~10s/page)
- Task 7: FR/NFR traceability headers added to both modified manifests

### File List

- `applications/paperless/docling/deployment.yaml` — Modified: added `DOCLING_SERVE_ENABLE_REMOTE_SERVICES` env var, updated FR/NFR headers
- `applications/litellm/configmap.yaml` — Modified: added `granite-docling` model entry, updated FR/NFR headers
- `docs/implementation-artifacts/25-5-enable-vlm-ocr-pipeline-via-remote-services.md` — Modified: gap analysis, task completion, dev agent record
- `docs/implementation-artifacts/sprint-status.yaml` — Modified: story status ready-for-dev → in-progress → review

## Change Log

- 2026-02-14: Gap analysis performed — no task changes needed, draft tasks match codebase reality
- 2026-02-14: All 7 tasks implemented and verified — VLM OCR pipeline operational via Docling → LiteLLM → Ollama
