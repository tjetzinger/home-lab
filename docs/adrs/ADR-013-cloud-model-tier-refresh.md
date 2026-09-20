# ADR-013: Cloud Model Tier Refresh with Role-Based Aliases

**Status:** Accepted
**Date:** 2026-09-20
**Decision Makers:** Tom, Claude (AI Assistant)

## Context

Ollama's account dashboard warned that `qwen3.5:397b` would retire on 2026-09-25. Investigating that
single warning revealed the cloud tier was already substantially broken, not merely at risk.

Probing `POST https://ollama.com/api/show` for every configured model returned:

| LiteLLM alias | Configured model | Status |
|---|---|---|
| `cloud-kimi` | `kimi-k2.5` | **HTTP 410 Gone** |
| `cloud-minimax` | `minimax-m2.5` | **HTTP 410 Gone** |
| `cloud-qwen3.5` | `qwen3.5:397b-cloud` | OK — retiring 2026-09-25 |
| `cloud-qwen3-coder` (openclaw) | `qwen3-coder:480b` | **HTTP 410 Gone** |

Paperless-GPT was configured with `LLM_MODEL: cloud-kimi`. That alias 410'd, fell through
`cloud-minimax` (also 410), and landed on `cloud-qwen3.5`. The Ollama usage page confirmed it: all 25 of
that week's requests were served by `qwen3.5:397b` and zero by the other two.

**This is the important failure mode.** LiteLLM treats a 410 as a routine failure and falls through
transparently, so a dead primary still answers and every health check stays green. Three aliases were
dead for weeks with no error surfaced anywhere.

The retirement would have removed the last working cloud model. The next hop, `vllm-qwen`, was also
unavailable — `k3s-gpu-worker` is `NotReady` with `vllm-server` stuck `Pending` — so Paperless would
have silently degraded to `phi4-mini` on CPU, which is not viable for German document metadata.

Two structural problems caused this:

1. **Aliases encoded vendor and version** (`cloud-kimi`, `cloud-qwen3.5`). Every retirement forces a
   rename across every consumer, so the cheap fix is to leave the alias pointing at a dead model.
2. **All three aliases came from Chinese frontier labs on similar release cadences**, so one industry
   retirement wave took out the entire chain at once.

## Decision

### 1. Role-based aliases

Aliases name the **job**, not the vendor or version:

| Alias | Role |
|---|---|
| `cloud-docs` | Document metadata extraction (Paperless-GPT) |
| `cloud-fast` | Quick general inference |
| `cloud-smart` | Frontier reasoning / agentic work (Open-WebUI default) |

A retirement now changes exactly one `model:` line in `applications/litellm/configmap.yaml`. No consumer
config, no documentation, no rename.

### 2. Vendor diversity, newest-of-family

| Alias | Model | Lab | Context |
|---|---|---|---|
| `cloud-docs` | `mistral-large-3:675b` | Mistral AI | 262K |
| `cloud-fast` | `deepseek-v4.1-flash` | DeepSeek | 1M |
| `cloud-smart` | `kimi-k3` | Moonshot | 1M |

Three different labs, each the newest member of its family.

### 3. Model selection was empirically tested, not assumed

Candidates were run against the live API with realistic Paperless prompts: a German utility invoice
(umlauts stripped to mimic OCR output) and an English services invoice, both requesting
`title / correspondent / document_type / created_date / tags` as JSON.

| Model | German | English | Latency | Verdict |
|---|---|---|---|---|
| `mistral-large-3:675b` | clean JSON, restored "München" from "Muenchen" | clean JSON | 1.9s | **Primary** |
| `deepseek-v4.1-flash` | clean JSON, restored umlauts | clean JSON | 1.1–2.0s | **Fallback 1** |
| `kimi-k3` | clean JSON, fluent German | clean JSON | 1.5–2.1s | **Fallback 2** |
| `glm-5.3-flash` | **failed** — leaked English chain-of-thought into `content`, no JSON | — | 18.5s | **Rejected** |

The `glm-5.3-flash` failure is load-bearing: it **ignored `think: false`**, the exact guard the existing
`extra_body` blocks rely on. `think: false` is therefore not a reliable blanket fix.

This makes `mistral-large-3` the correct primary for a structured-extraction workload: it is the only
finalist with **no `thinking` capability at all**, so the empty-`content`/populated-`reasoning_content`
failure mode is structurally impossible rather than merely suppressed.

### 4. Fallback chain

```
cloud-docs  → cloud-fast → cloud-smart → vllm-qwen → ollama-qwen
cloud-fast  → cloud-smart → vllm-qwen → ollama-qwen
cloud-smart → cloud-fast  → vllm-qwen → ollama-qwen
vllm-qwen   → ollama-qwen
```

`openai-gpt4o` remains explicit-selection only (FR218).

### 5. Open-WebUI picker curated to 13 models

The picker carried ~33 entries: 20 live cloud models from the direct `ollamaUrls` connection plus every
LiteLLM alias including dead ones and infrastructure-only entries such as `granite-docling` (a 258m OCR
vision model). Curated to 10 cloud models plus the 3 role aliases.

Uncensored models were considered and **rejected**: Ollama Cloud carries none (all 20 catalogue entries
are aligned frontier models), and the only alternative was CPU-bound local inference on a 4Gi pod with
the GPU worker down.

## Consequences

### Positive

- Paperless-GPT runs on a model verified against its actual workload in both required languages
- A future retirement is a one-line change confined to the LiteLLM configmap
- No single lab's retirement schedule can break the whole chain
- `cloud-docs` cannot leak reasoning into `content`, by construction
- Measured 5.6s for a 14.4K-token prompt — ample headroom under the 30s `request_timeout`
- Model picker reduced from ~33 to 13 meaningful entries

### Negative

- `cloud-docs` at 675b is heavier than the 397b it replaces; `timeout` raised 60s → 90s
- Open-WebUI model visibility cannot live in Git (see Constraints), so it needs a script to reproduce
- Role aliases are less self-describing — `cloud-smart` does not reveal that it is `kimi-k3`. Mitigated
  by the mapping tables in `CLAUDE.md`, `docs/project-context.md` and `applications/litellm/README.md`

### Open-WebUI constraints discovered

Model visibility cannot be expressed declaratively in Helm values:

1. **`DEFAULT_MODELS` is a `ConfigVar`.** With `ENABLE_PERSISTENT_CONFIG=true` (default), the DB value
   wins and the env var is ignored on an existing install. It must also be set in the Admin UI.
2. **`OLLAMA_API_CONFIGS` / `OPENAI_API_CONFIGS` cannot be seeded from env vars.** The `model_ids`
   whitelist is the right mechanism but upstream never implemented JSON parsing for it
   ([issue #19017](https://github.com/open-webui/open-webui/issues/19017), closed as *not planned*).

Mitigation: `applications/open-webui/model-curation.json` is the version-controlled source of truth,
applied via the admin REST API by `scripts/open-webui/apply-model-curation.sh`. This doubles as the
recovery path if the NFS PVC is lost.

### Follow-ups not addressed here

- **No alerting on cloud-model failure.** This incident was invisible precisely because fallback worked.
  A Prometheus alert on LiteLLM fallback-event metrics would have caught it weeks earlier; the
  `prometheus` callback is already enabled. This is the highest-value follow-up.
- **`k3s-gpu-worker` is `NotReady`**, `vllm-server` `Pending` — the local GPU tier of the fallback chain
  is dead, leaving cloud as the only real inference path. See `docs/runbooks/egpu-hotplug.md`.
- **OpenClaw** is shut down and its `openclaw.json` on the `openclaw-data` PVC still references the dead
  `cloud-kimi` and `cloud-qwen3-coder`. Repoint before restarting it.

## Alternatives Considered

| Alternative | Why rejected |
|---|---|
| Swap `qwen3.5` only, keep other aliases | Leaves two 410-dead aliases in the chain, wasting failover hops and keeping the picker broken |
| Keep vendor/version alias names | Guarantees the same cross-consumer rename on the next retirement — the root cause |
| `glm-5.3-flash` as primary | Empirically leaked chain-of-thought into `content` and took 18.5s |
| All three aliases from one lab | Reproduces the correlated-retirement failure that caused this ADR |
| Add uncensored models | Ollama Cloud has none; local CPU-only inference impractical with the GPU worker down |
| `ENABLE_PERSISTENT_CONFIG=false` to force env vars | Does not fix `OLLAMA_API_CONFIGS` parsing, and makes all Admin UI changes ephemeral |

## References

- `applications/litellm/configmap.yaml` — cloud model definitions and fallback chain
- `applications/paperless/paperless-gpt/configmap.yaml` — `LLM_MODEL: cloud-docs`
- `applications/open-webui/model-curation.json` — picker keep/hide lists
- `scripts/open-webui/apply-model-curation.sh` — curation apply script
- `docs/planning-artifacts/architecture.md` — Cloud Model Tier Refresh (ADR-013) section
- [ADR-012](ADR-012-document-processing-pipeline-upgrade.md) — the pipeline this tier feeds
- [open-webui#19017](https://github.com/open-webui/open-webui/issues/19017) — env config parsing
