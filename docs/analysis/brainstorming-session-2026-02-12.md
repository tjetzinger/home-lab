---
stepsCompleted: [1, 2, 3]
inputDocuments: []
session_topic: 'Paperless-ngx + Paperless-GPT + Docling + LLM integration architecture'
session_goals: 'Explore tool synergies, identify best LLM fit, evaluate improvement over current Paperless-AI setup'
selected_approach: 'ai-recommended'
techniques_used: ['Morphological Analysis', 'Six Thinking Hats']
ideas_generated: ['Option C architecture', 'two-stage pipeline', 'vLLM upgrade path']
context_file: ''
---

# Brainstorming Session Results

**Facilitator:** Tom
**Date:** 2026-02-12

## Session Overview

**Topic:** Paperless-ngx + Paperless-GPT + Docling + LLM integration architecture
**Goals:** Explore how Paperless-GPT and Docling complement Paperless-ngx, identify the best LLM fit for the pipeline, and determine whether this improves on the current Paperless-AI setup

### Context Guidance

_Existing infrastructure: K3s cluster with Paperless-ngx in docs namespace, Paperless-AI (clusterzx/paperless-ai) with ChromaDB RAG, 3-tier LLM inference via LiteLLM (vLLM GPU → Ollama CPU → OpenAI cloud), RTX 3060 12GB VRAM on GPU worker._

### Session Setup

_Brainstorming session focused on evaluating Paperless-GPT as an alternative to Paperless-AI, Docling as a document parsing/preprocessing layer, and optimal LLM selection given hardware constraints (12GB VRAM, Qwen 2.5 7B AWQ currently deployed)._

## Technique Selection

**Approach:** AI-Recommended Techniques
**Analysis Context:** Technical architecture evaluation with multiple integration variables and hardware constraints

**Recommended Techniques:**

- **Morphological Analysis:** Systematically map all tool combinations (Paperless-GPT/AI, Docling, LLM models) across integration dimensions to identify all viable architectures
- **Six Thinking Hats:** Evaluate promising combinations from 6 perspectives — facts, benefits, risks, creativity, gut-feel, and process

**AI Rationale:** Complex multi-tool evaluation with hardware constraints requires structured exploration (Morphological Analysis), balanced multi-perspective assessment (Six Thinking Hats). First Principles Thinking was dropped as the architecture decision converged naturally during the first two techniques.

## Technique Execution Results

### Morphological Analysis

**Parameters explored:** 5 dimensions systematically mapped with all viable options.

#### Final Architecture Matrix (Option C)

| # | Parameter | Decision | Rationale |
|---|-----------|----------|-----------|
| **1** | AI Processing Tool | **Paperless-GPT** (replaces Paperless-AI) | Native Docling integration, 5 LLM backends, customizable prompt templates, hOCR searchable PDFs, manual review + auto processing workflows |
| **2** | OCR/Parsing | **Docling server** (Granite-Docling 258M VLM pipeline) + **Gotenberg** kept | Two-stage pipeline: Docling extracts document structure (tables, code, equations) → LLM reasons about content. Gotenberg retained for Office→PDF conversion (non-overlapping purpose) |
| **3** | LLM for Metadata | **Qwen3-8B-AWQ via vLLM** (GPU, primary) / **qwen3:4b via Ollama** (CPU, fallback) | GPU usually off → LiteLLM auto-routes to Ollama. qwen3:8b (90% classification accuracy) on GPU when available; qwen3:4b (70%) fits current worker-02 (8GB) without upgrade |
| **4** | LLM Routing | **LiteLLM proxy** — vLLM GPU → Ollama qwen3:4b fallback | Preserves existing 3-tier fallback. Downstream apps (Open-WebUI, OpenClaw) need zero reconfiguration — LiteLLM model aliases absorb the change |
| **5** | Deployment | **Replace** — remove Paperless-AI, deploy Paperless-GPT | Clean swap. RAG chat (ChromaDB) is lost but metadata generation is the core value |

#### Key Insights from Morphological Analysis

- **Granite-Docling (258M) and Qwen3 are complementary, not competing.** Granite-Docling extracts document structure; Qwen3 reasons about content to generate metadata. Each model does what it's best at.
- **Gotenberg stays.** It converts Office docs → PDF. Docling extracts from PDF. No overlap.
- **Docling runs inside its own server pod** with the VLM pipeline enabled (`DOCLING_OCR_PIPELINE=vlm`). Paperless-GPT consumes it via `OCR_PROVIDER=docling`.
- **No worker-02 Proxmox upgrade needed.** qwen3:4b (Q4, ~2.5GB) fits comfortably in current 8GB RAM.
- **DeepSeek-R1 deployment unchanged.** Only the `ml` GPU mode model changes; `r1` mode stays as-is.

### Six Thinking Hats

#### White Hat (Facts)

- `Qwen/Qwen3-8B-AWQ` confirmed available on HuggingFace (official, Apache 2.0)
- vLLM v0.5.5 (current) does NOT support Qwen3 — minimum **vLLM >= 0.8.5** required
- Qwen docs recommend `pip install "vllm>=0.8.5"`, native qwen3 module exists from v0.10.2+
- LiteLLM consumers: **Open-WebUI** (default model `vllm-qwen`), **Paperless-AI** (being replaced), **OpenClaw** (fallback URL only)
- GPU modes are mutually exclusive — only one model in 12GB VRAM at a time (`ml` or `r1`)
- Paperless-GPT officially recommends `qwen3:8b` for Ollama metadata generation

#### Yellow Hat (Benefits)

- No worker-02 upgrade needed — qwen3:4b fits in 8GB
- Massive quality jump when GPU is on — qwen3:8b (90% accuracy) vs current qwen2.5:7b
- Fallback still improves — qwen3:4b (70%) beats current qwen2.5:3b (<70%), better instruction following
- Zero downstream app reconfiguration — LiteLLM model aliases absorb the change
- Docling adds layout-aware PDF parsing — tables, equations, code blocks extracted before LLM sees the document
- Paperless-GPT prompt templates are tunable per document type via web UI
- Same Qwen family across tiers — consistent prompt behavior between GPU and CPU
- qwen3 trained on 119 languages (vs 29 for qwen2.5) — significantly better German document support

#### Black Hat (Risks)

| Risk | Severity | Mitigation |
|------|----------|------------|
| vLLM upgrade 0.5.5 → 0.10+ may break CLI args or defaults | Medium | Test `--enforce-eager`, `--quantization awq_marlin` compatibility. DeepSeek-R1 deployment also benefits. |
| Paperless-GPT is newer, less battle-tested than Paperless-AI | Medium | Active community (1.9k stars), but early adopter of Docling integration |
| Losing RAG chat (ChromaDB) | Low | Metadata generation is the core value; RAG can be rebuilt later with Docling's higher-fidelity document chunks |
| Docling server adds another pod to docs namespace | Low | Granite-Docling 258M is tiny, CPU-only, minimal resources |
| GPU usually off — most documents processed by weaker qwen3:4b | Medium | 70% accuracy is acceptable for batch processing; GPU can be spun up for quality-critical batches |

#### Red Hat (Gut Feel)

Two-stage pipeline (Docling for structure, LLM for reasoning) is the right separation of concerns. Option C is pragmatic — improves both tiers without infrastructure changes.

#### Green Hat (Creative Possibilities)

- CronJob to auto-start GPU worker when document queue exceeds a threshold
- Docling's structured output could feed a better RAG system later — replacing ChromaDB with higher-fidelity document chunks
- qwen3's thinking mode (`/think`) could be toggled for complex documents that need deeper reasoning

#### Blue Hat (Process Summary)

Decision is solid. Two blockers verified and resolved:
1. Qwen3-8B-AWQ exists on HuggingFace (official)
2. vLLM needs upgrade to >= 0.8.5 (currently v0.5.5)

## Data Flow Architecture

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

## LLM Quality Comparison: Current vs Proposed

### qwen2.5:3b (current Ollama) → qwen3:4b (proposed Ollama fallback)

| Dimension | qwen2.5:3b | qwen3:4b |
|-----------|-----------|----------|
| Classification accuracy | <70% | ~70% |
| Instruction following | Struggles with complex prompts | Significantly improved |
| Multilingual | 29 languages | 119 languages |
| Training data | ~18T tokens | ~36T tokens |
| Context window | 32K | 128K |

### qwen2.5:7b AWQ (current vLLM) → qwen3:8b AWQ (proposed vLLM)

| Dimension | Qwen2.5-7B-AWQ | Qwen3-8B-AWQ |
|-----------|----------------|--------------|
| Classification accuracy | ~74% MMLU | ~76% MMLU (matches Qwen2.5-14B) |
| Classification benchmarks | Not tested | 90% (distillabs) |
| Instruction following | Good | Strong (~85% IFEval strict) |
| Thinking mode | No | Yes — toggle `/think` for complex docs |
| Multilingual | 29 languages | 119 languages |

## Gains vs Losses

| Gained | Lost |
|--------|------|
| Docling layout-aware PDF parsing (tables, code, equations) | ChromaDB RAG chat |
| Searchable PDF generation (hOCR) | |
| Customizable prompt templates (web UI) | |
| Native Docling OCR provider in Paperless-GPT | |
| qwen3:8b on GPU (90% accuracy, thinking mode) | |
| qwen3:4b on CPU (70% accuracy, better than qwen2.5:3b) | |
| Manual review + auto processing tag workflows | |
| 119-language support (improved German) | |

## LiteLLM Dependency Map

| Consumer App | Namespace | Connection | Impact of Model Swap |
|-------------|-----------|------------|---------------------|
| **Open-WebUI** | apps | `http://litellm.ml.svc:4000/v1`, default model `vllm-qwen` | Transparent — gets qwen3 instead of qwen2.5, no config change |
| **Paperless-AI** | docs | `http://litellm.ml.svc:4000/v1`, model `vllm-qwen` | Being replaced by Paperless-GPT |
| **OpenClaw** | apps | `http://litellm.ml.svc:4000/v1` (fallback URL) | Minimal — only used as fallback path |

## Implementation Checklist

| Step | Change | Risk | Notes |
|------|--------|------|-------|
| 1 | Upgrade vLLM image `v0.5.5` → `v0.10.2+` | Medium | Test CLI arg compatibility. Benefits DeepSeek-R1 too. |
| 2 | Swap vLLM model to `Qwen/Qwen3-8B-AWQ` | Low | Drop-in replacement in deployment.yaml |
| 3 | Update LiteLLM configmap model paths | Low | `vllm-qwen` alias stays, actual model path changes |
| 4 | Swap Ollama model: `qwen2.5:3b` → `qwen3:4b` | Low | `ollama pull qwen3:4b`, update LiteLLM configmap |
| 5 | Deploy Docling server pod in docs namespace | New | Granite-Docling VLM pipeline, CPU-only, minimal resources |
| 6 | Deploy Paperless-GPT with Docling OCR provider | New | Configure `OCR_PROVIDER=docling`, `DOCLING_URL`, LLM via LiteLLM |
| 7 | Remove Paperless-AI deployment | Low | Delete deployment, configmap, service, ingress |

## GPU Mode Reference (Post-Implementation)

| GPU Mode | vLLM Model | Ollama Fallback | Use Case |
|----------|-----------|-----------------|----------|
| `ml` | Qwen3-8B-AWQ (new) | qwen3:4b | General inference, document classification |
| `r1` | DeepSeek-R1 7B AWQ (unchanged) | qwen3:4b | Reasoning tasks via Open-WebUI |
| `gaming` / off | nothing | qwen3:4b | GPU released, CPU handles all inference |

## Sources

- [Paperless-GPT GitHub](https://github.com/icereed/paperless-gpt)
- [Paperless-GPT DeepWiki](https://deepwiki.com/icereed/paperless-gpt/1.2-installation-and-configuration)
- [Docling Project GitHub](https://github.com/docling-project/docling)
- [IBM Granite-Docling Announcement](https://www.ibm.com/new/announcements/granite-docling-end-to-end-document-conversion)
- [Qwen3 Announcement](https://qwenlm.github.io/blog/qwen3/)
- [Qwen3-8B-AWQ on HuggingFace](https://huggingface.co/Qwen/Qwen3-8B-AWQ)
- [Qwen3 Technical Report](https://arxiv.org/pdf/2505.09388)
- [Qwen vLLM Deployment Guide](https://qwen.readthedocs.io/en/latest/deployment/vllm.html)
- [Distillabs SLM Benchmarks](https://www.distillabs.ai/blog/we-benchmarked-12-small-language-models-across-8-tasks-to-find-the-best-base-model-for-fine-tuning)
- [Small Language Models Guide 2026](https://localaimaster.com/blog/small-language-models-guide-2026)
