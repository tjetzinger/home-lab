# ADR-021: cloud-docs Moves to nemotron-3-super After mistral-large-3 Retirement

**Status:** Accepted
**Date:** 2026-10-29
**Decision Makers:** Tom, Claude (AI Assistant)
**Relates to:** [ADR-013](ADR-013-cloud-model-tier-refresh.md) (partially supersedes)

## Context

On 2026-10-29 Ollama emailed that three cloud models retire on **2026-11-09**:

| Retiring model | Ollama's recommended replacement |
|---|---|
| `minimax-m2.7` | `minimax-m3.1-flash` |
| `mistral-large-3:675b` | `mistral-large-4` |
| `nemotron-3-nano:30b` | `gemma4:31b` |

Only one of these is used by the cluster. A repo scan found `minimax-m2.7` and
`nemotron-3-nano:30b` referenced only in superseded documents. `mistral-large-3:675b` is the live
backing model for the **`cloud-docs`** LiteLLM alias (Paperless-GPT document metadata), set by
[ADR-013](ADR-013-cloud-model-tier-refresh.md).

ADR-013 chose `mistral-large-3` for `cloud-docs` on one load-bearing property: it was the **only
finalist with no `thinking` capability**, which made the empty-`content` / populated-`reasoning_content`
failure mode *structurally impossible* rather than merely suppressed. The same ADR documented that
`think: false` is not a reliable blanket guard — `glm-5.3-flash` ignored it and leaked
chain-of-thought into `content`.

So this is **not** the one-line swap ADR-013's role-based aliases normally allow: the recommended
replacement, and in fact the entire remaining catalogue, breaks that invariant.

## Investigation

All probes ran against the live Ollama Cloud API with the cluster's `OLLAMA_API_KEY`, following
ADR-013's method (German utility invoice with umlauts stripped to mimic OCR, plus an English services
invoice, both requesting `title / correspondent / document_type / created_date / tags` as JSON).

### 1. The "no thinking model" invariant is no longer satisfiable

`POST /api/show` capabilities for every plausible replacement:

| Model | `thinking` capability |
|---|---|
| `mistral-large-3:675b` (retiring) | **no** |
| `mistral-large-4` | yes |
| `gemma4:31b` | yes |
| `minimax-m3.1-flash` | yes |
| `nemotron-3-super` | yes |
| `nemotron-3-ultra` | yes |
| `deepseek-v4-pro` | yes |
| `kimi-k2.6` | yes |
| `glm-5.3` | yes |

`mistral-large-3:675b` was the last non-thinking model in the catalogue. The best achievable guarantee
is now a model that **fully honours `think: false`** (reasoning never runs), not one where thinking is
absent by construction.

### 2. The recommended replacement is unavailable

`mistral-large-4` returns `/api/show` 200, but `POST /api/chat` returns **HTTP 403**:

```
This model is currently being rolled out and is not yet available to you. Please check back later.
```

A swap to `mistral-large-4` would therefore 403 on every request and fall through the chain silently —
the exact invisible-failure mode ADR-013 exists to prevent.

### 3. Extraction test (`think: false`)

| Model | Lab | JSON (DE/EN) | `think:false` honoured | German quality |
|---|---|---|---|---|
| `nemotron-3-super` | NVIDIA | valid / valid | **yes** (empty thinking trace) | German tags kept; umlauts left as `Muenchen` |
| `minimax-m3.1-flash` | MiniMax | valid / valid | no — still reasoned, but into the separate `thinking` field; `content` stayed clean | **best** — restored `München` / `fällig`, German tags |
| `gemma4:31b` | Google | valid / valid | yes | weak — left umlauts stripped **and translated German tags to English** |

## Decision

**`cloud-docs` → `ollama_chat/nemotron-3-super` with `extra_body: {think: false}`.**

Rationale, in priority order:

1. **Structural safety.** `nemotron-3-super` fully honours `think: false` (verified: empty thinking
   trace on both prompts), so reasoning never runs and cannot steal the `content` field. This is the
   closest remaining substitute for ADR-013's "impossible by construction" guarantee.
2. **Vendor diversity restored.** The three aliases are now `nemotron-3-super` (NVIDIA),
   `deepseek-v4.1-flash` (DeepSeek), `kimi-k3` (Moonshot) — three different labs again. Picking
   `minimax-m3.1-flash` would have made all three Chinese-lab models, reviving the correlated-retirement
   risk ADR-013's §2 was written to avoid.
3. **German is adequate.** `nemotron-3-super` keeps German tags and extracts correct fields; it does
   not cosmetically restore umlauts (`Muenchen`, not `München`). That is a display nicety, not a
   correctness issue, and is outweighed by (1) and (2).

`gemma4:31b` was rejected: it translated German tags to English, defeating the purpose of a
German-first document alias.

`think: false` is **required** in the config, not optional — without it the model reasons.

## Consequences

### Positive
- `cloud-docs` keeps a working, verified primary ahead of the 2026-11-09 retirement.
- No consumer config changes (role-based aliases, per ADR-013) — Paperless-GPT keeps `LLM_MODEL: cloud-docs`.
- Vendor diversity across the three aliases is restored.
- The ADR-013 fallback-alerting rules already cover a silent `cloud-docs` failure if this model ever misbehaves.

### Negative
- `cloud-docs` no longer has the "thinking impossible by construction" guarantee; it now depends on
  `nemotron-3-super` continuing to honour `think: false` across model updates. If a future update
  breaks that, the `LiteLLMCloudPrimaryFallingBack` alert is the backstop.
- German titles/correspondents keep OCR-stripped umlauts (`Muenchen`) instead of restoring them.

### Follow-ups
- **Revisit `mistral-large-4`** once account access opens (it is "rolling out"). It is the natural
  same-family successor, but it is a thinking model, so re-run the extraction test with `think: false`
  before adopting — do not assume it honours the flag.
- **Apply after review:** `kubectl --context default -n ml apply -f applications/litellm/configmap.yaml`
  then `kubectl --context default -n ml rollout restart deployment/litellm`. Re-apply the Open-WebUI
  curation with `scripts/open-webui/apply-model-curation.sh` so the retired `mistral-large-3:675b`
  drops out of the picker.

## Alternatives Considered

| Alternative | Why rejected |
|---|---|
| `mistral-large-4` (Ollama's recommendation) | HTTP 403 "rolling out" — unavailable, would silently fall through |
| `minimax-m3.1-flash` | Best German, but does not honour `think:false` and makes all three aliases Chinese-lab |
| `gemma4:31b` | Translated German tags to English — wrong for a German document alias |
| Keep `mistral-large-3:675b` | Retires 2026-11-09; would 410 and silently fall through |

## References

- `applications/litellm/configmap.yaml` — `cloud-docs` definition
- `applications/paperless/paperless-gpt/configmap.yaml` — `LLM_MODEL: cloud-docs`
- `applications/open-webui/model-curation.json` — picker keep/hide lists
- [ADR-013](ADR-013-cloud-model-tier-refresh.md) — role-based aliases and the original `cloud-docs` choice
