# ADR-012: Document Processing Pipeline Upgrade

**Status:** Accepted
**Date:** 2026-02-12
**Decision Makers:** Tom, Claude (AI Assistant)

## Context

The home-lab document management stack uses Paperless-ngx for document storage with Paperless-AI (clusterzx/paperless-ai) for LLM-powered metadata generation. The current pipeline has several limitations:

- **Paperless-AI has no OCR provider integration** — it relies entirely on Paperless-ngx's built-in OCR (Tesseract), which loses document structure (tables, code blocks, equations)
- **The GPU worker is usually off** — vLLM (Qwen2.5-7B-AWQ) is the primary inference tier, but the RTX 3060 GPU worker is typically powered down, making the Ollama CPU fallback (qwen2.5:3b) the de facto workhorse
- **qwen2.5:3b produces poor metadata** — <70% classification accuracy, struggles with instruction following, creates duplicate correspondents, ignores tag constraints
- **vLLM v0.5.5 is outdated** — cannot run newer model architectures (Qwen3)
- **No searchable PDF generation** — scanned documents lack text layers for search

The existing infrastructure provides:
- Paperless-ngx with Tika (Office text extraction) + Gotenberg (Office→PDF conversion)
- LiteLLM proxy with three-tier fallback (vLLM GPU → Ollama CPU → OpenAI cloud)
- RTX 3060 12GB VRAM on Intel NUC GPU worker
- Ollama on k3s-worker-02 (4 cores, 8GB RAM)

## Decision Drivers

- **Metadata quality** — Need reliable, accurate document classification (titles, tags, correspondents)
- **GPU-off resilience** — Must produce acceptable metadata when GPU worker is unavailable
- **Document structure preservation** — Tables, equations, and complex layouts should be parsed correctly
- **Minimal infrastructure changes** — Avoid Proxmox VM resizes or new hardware
- **Downstream compatibility** — Open-WebUI, OpenClaw, and other LiteLLM consumers must not require reconfiguration

## Considered Options

### Option A: Qwen3-8B on GPU, keep qwen2.5:3b on Ollama

**Pros:**
- No worker-02 upgrade needed
- qwen3:8b (90% accuracy) on GPU when available
- Minimal change — just swap the vLLM model

**Cons:**
- GPU usually off → most documents processed by qwen2.5:3b (<70% accuracy)
- No improvement to the daily workhorse path

### Option B: Qwen3-8B on Ollama CPU (upgraded worker-02)

**Pros:**
- 90% accuracy all the time, regardless of GPU state
- Consistent quality

**Cons:**
- Requires Proxmox upgrade: worker-02 from 4c/8GB → 8c/16GB
- qwen3:8b on CPU = ~1-3 tok/s on 4 cores, ~4-6 tok/s on 8 cores — slow
- GPU tier would still run the older Qwen2.5-7B

### Option C: Qwen3-8B on GPU, qwen3:4b on Ollama (Selected)

**Pros:**
- No worker-02 upgrade needed — qwen3:4b (Q4, ~2.5GB) fits in current 8GB
- GPU on: 90% accuracy (qwen3:8b), 30-50 tok/s
- GPU off: 70% accuracy (qwen3:4b), still better than current qwen2.5:3b (<70%)
- Both tiers improve over current setup
- Same Qwen family → consistent prompt behavior

**Cons:**
- 70% on CPU fallback is not 90% — quality gap when GPU is off
- Acceptable: GPU can be spun up for quality-critical batches

## Decision

**Selected: Option C** — Deploy Qwen3-8B-AWQ on GPU via vLLM, qwen3:4b on Ollama CPU as fallback. Additionally:

1. **Replace Paperless-AI with Paperless-GPT** — Native Docling OCR provider integration, customizable prompt templates, hOCR searchable PDF generation, 5 LLM backend support
2. **Deploy Docling server** with Granite-Docling 258M VLM pipeline for layout-aware PDF parsing
3. **Upgrade vLLM** from v0.5.5 to v0.10.2+ (required for Qwen3 model support)
4. **Keep Tika and Gotenberg** — Tika handles email/Office format extraction, Gotenberg converts Office→PDF. Neither overlaps with Docling.

### Two-Stage Pipeline Architecture

```
Incoming doc → Paperless-ngx
       |                              |
       | (Office docs)                | (stored PDF)
       v                              v
    Gotenberg → PDF              Paperless-GPT triggered (tag-based)
                                       |
                                       v
                            Docling server (Granite-Docling 258M, CPU)
                            → structured markdown/JSON
                                       |
                                       v
                            LiteLLM proxy
                            → vLLM Qwen3-8B-AWQ (GPU, if available)
                            → Ollama qwen3:4b (CPU fallback)
                                       |
                                       v
                            Title, tags, correspondent, custom fields
                            → written back to Paperless-ngx API
```

**Key insight:** Granite-Docling (258M) and Qwen3 serve complementary roles. Granite-Docling extracts document *structure* (tables, equations, reading order). Qwen3 *reasons* about the extracted content to generate metadata. Each model does what it's best at.

## Consequences

### Positive

- **Both inference tiers improve:** GPU goes from Qwen2.5-7B to Qwen3-8B (90% accuracy). CPU goes from qwen2.5:3b to qwen3:4b (70%, up from <70%).
- **No infrastructure changes:** qwen3:4b fits in worker-02's existing 8GB RAM. No Proxmox VM resize.
- **Zero downstream reconfiguration:** LiteLLM model aliases (`vllm-qwen`, `ollama-qwen`) absorb the change. Open-WebUI, OpenClaw get better responses transparently.
- **Layout-aware parsing:** Docling preserves table structure, code blocks, and equations — critical for technical documents.
- **Searchable PDFs:** Paperless-GPT can generate hOCR text layers for scanned documents.
- **Customizable prompts:** Web UI for prompt template editing without YAML/pod restarts.
- **119 language support:** Qwen3 trained on 119 languages vs 29 for Qwen2.5 — significantly better German document handling.

### Negative

- **RAG chat lost:** Paperless-AI's ChromaDB-based RAG document chat is removed. Can be rebuilt later with Docling's higher-fidelity document chunks.
- **vLLM major version jump:** 0.5.5 → 0.10.2+ is a significant upgrade. CLI arguments and defaults may change. DeepSeek-R1 deployment must be verified.
- **Paperless-GPT is newer:** Less battle-tested than Paperless-AI (though actively maintained, 1.9k GitHub stars).
- **New pod added:** Docling server adds one pod to the docs namespace (lightweight — <1GB memory, CPU-only).

### Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| vLLM CLI args break on upgrade | Test `--enforce-eager`, `--quantization awq_marlin` on v0.10.2 before applying to production |
| DeepSeek-R1 breaks on new vLLM | Verify `deployment-r1.yaml` works with upgraded image before removing old version |
| Paperless-GPT Docling integration issues | Active GitHub community; Docling is a first-class OCR provider, not experimental |
| GPU off most of the time | 70% accuracy on qwen3:4b is acceptable for batch processing; spin up GPU for quality-critical runs |

## Related Decisions

- **ADR-002:** NFS over Longhorn (storage strategy unchanged)
- **ADR-005:** Manual Helm over GitOps (deployment approach unchanged)
- **Epic 10:** Paperless-ngx deployment (foundation for this upgrade)
- **Epic 12:** GPU/ML inference platform (vLLM/Ollama architecture being upgraded)
- **Epic 14:** LiteLLM inference proxy (routing layer preserved)
- **Epic 25:** Implementation stories for this decision

## References

- [Paperless-GPT GitHub](https://github.com/icereed/paperless-gpt)
- [Docling Project GitHub](https://github.com/docling-project/docling)
- [IBM Granite-Docling Announcement](https://www.ibm.com/new/announcements/granite-docling-end-to-end-document-conversion)
- [Qwen3-8B-AWQ on HuggingFace](https://huggingface.co/Qwen/Qwen3-8B-AWQ)
- [Qwen vLLM Deployment Guide](https://qwen.readthedocs.io/en/latest/deployment/vllm.html)
- [Brainstorming Session](docs/analysis/brainstorming-session-2026-02-12.md)
