# VLM OCR for Docling: Implementation Options

Status: **Option A selected — spike validated (2026-02-14)**

## Context

Docling's VLM pipeline (`pipeline: vlm`) does NOT work on the CPU image (known issues #262, #296, #399).
The standard pipeline with EasyOCR handles basic OCR, but for advanced layout-aware OCR on scanned
documents, an external VLM is needed via `DOCLING_SERVE_ENABLE_REMOTE_SERVICES=true`.

Docling uses **OpenAI-compatible vision API** format for remote VLM calls, configured per-request
via the `vlm_pipeline_model_api` field (NOT `picture_description_api`, which only annotates pictures
in the standard pipeline):

```json
{
  "sources": [{"kind": "http", "url": "..."}],
  "options": {
    "pipeline": "vlm",
    "vlm_pipeline_model_api": {
      "url": "http://litellm.ml.svc:4000/v1/chat/completions",
      "params": {"model": "granite-docling", "max_completion_tokens": 4096},
      "response_format": "doctags",
      "timeout": 240
    },
    "to_formats": ["md"]
  }
}
```

## Current Infrastructure

- **Docling:** CPU image (v1.12.0) on k3s-worker-01, standard pipeline only
- **GPU worker:** k3s-gpu-worker, RTX 3060 12GB VRAM, vLLM with Qwen3-8B-AWQ (~6-8GB)
- **Ollama:** k3s-worker-02, CPU fallback, phi4-mini + ibm/granite-docling:258m
- **LiteLLM:** ml namespace, vLLM -> Ollama -> Cloud fallback chain
- **VLM model:** Granite-Docling 258M (`ibm/granite-docling:258m`), 521MB on disk, natively on Ollama

## Decision: Option A — Docling → LiteLLM → Ollama

Selected for architectural consistency. All LLM/VLM calls route through LiteLLM. Spike validated end-to-end on 2026-02-14.

## Spike Results (2026-02-14)

| Test | Result |
|------|--------|
| `vlm_pipeline_model_api` accepted by API schema | **PASS** — issue #318 fixed in v1.12.0 |
| Docling calls remote Ollama | **PASS** — confirmed in pod logs |
| VLM OCR extracts structured text from image | **PASS** — table correctly parsed to markdown |
| `response_format` field | **Required** — must be `"doctags"` for Granite-Docling |
| CPU inference latency | **~90s/page** (single image with table) |
| Ollama memory delta (idle) | **+17Mi** (model: 521MB on disk) |
| Ollama memory delta (inference) | Not yet measured under load |

**Validated request format:**
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

**Test output (image of accessibility data table):**
```markdown
| Disability Category | Participants | Ballots Completed | Ballots Incomplete/Terminated | Accuracy        | Time to complete        |
|---------------------|-------------|--------------------|-----------------------------|-----------------|------------------------|
| Blind               | 5           | 1                  | 4                           | 34.5%, n=1      | 1199 sec, n=1          |
| Low Vision          | 5           | 2                  | 3                           | 98.3% n=2       | 1716 sec, n=3          |
| Dexterity           | 5           | 4                  | 1                           | 98.3%, n=4      | 1672.1 sec, n=4        |
| Mobility            | 3           | 3                  | 0                           | 95.4%, n=3      | 1416 sec, n=3          |
```

## Open Questions (Resolved)

- ~~Is Granite-Docling 258M available as GGUF for Ollama import?~~ → **YES**, natively on Ollama as `ibm/granite-docling:258m` — no import needed
- ~~Can vLLM multi-model serve both Qwen3-8B-AWQ and Granite-Docling simultaneously?~~ → **NO**, vLLM doesn't support multi-model on same GPU. Moot point — 258M model runs fine on CPU via Ollama
- ~~Does `granite3.2-vision:2b` (Ollama) produce compatible output for Docling's VLM pipeline?~~ → **Not needed** — the actual Granite-Docling 258M is on Ollama natively
- ~~What is the actual API request format Docling sends to the remote VLM?~~ → **Validated** — uses `vlm_pipeline_model_api` with required `response_format: "doctags"`, OpenAI-compatible chat completions format

## Remaining Implementation (Phase 2-3)

1. Persist `DOCLING_SERVE_ENABLE_REMOTE_SERVICES=true` in Docling deployment.yaml
2. Add `granite-docling` model alias to LiteLLM configmap (Ollama backend)
3. Update Docling VLM requests to route through LiteLLM instead of Ollama directly
4. Test graceful degradation when Ollama is unavailable
5. Validate Paperless-GPT end-to-end with scanned documents
6. Consider Docling async API for multi-page scanned documents (sync timeout is 120s)

## Options Evaluated (for reference)

### Option A: Docling → LiteLLM → Ollama (SELECTED)

Route VLM calls through LiteLLM proxy to Ollama serving `ibm/granite-docling:258m` on CPU.

**Pros:** Consistent with ML stack architecture, future GPU tier possible, model natively on Ollama
**Cons:** ~90s/page CPU latency, extra LiteLLM hop
**Verdict:** Selected. Spike validated. Latency acceptable for batch processing.

### Option B: Docling GPU Image on GPU Worker

Deploy `ghcr.io/docling-project/docling-serve-cu128` (~11.4GB) on k3s-gpu-worker.

**Pros:** Self-contained, fastest inference (~2-5s/page)
**Cons:** 11.4GB image, GPU memory contention with vLLM, gpu-mode complexity
**Verdict:** Rejected. Too heavy for a 258M model, breaks LiteLLM proxy pattern.

### Option C: Docling → Ollama Direct

Call Ollama directly bypassing LiteLLM.

**Pros:** Simplest (2 config changes), same latency as Option A
**Cons:** Breaks LiteLLM proxy pattern, no fallback routing
**Verdict:** Rejected. Marginal simplification doesn't justify breaking architectural consistency.

## References

- Docling remote services: https://github.com/docling-project/docling-serve/blob/main/docs/usage.md
- Granite-Docling model (Ollama): https://ollama.com/ibm/granite-docling:258m
- Granite-Docling model (HuggingFace): https://huggingface.co/ibm-granite/granite-docling-258m-preview
- GGUF weights: https://huggingface.co/ggml-org/granite-docling-258M-GGUF
- Docling VLM pipeline docs: https://docling-project.github.io/docling/examples/vlm_pipeline_api_model/
- Docling GitHub issues: #262, #296 (VLM on CPU), #318 (schema drop — fixed v1.12.0), #370, #463 (env vars — open)
