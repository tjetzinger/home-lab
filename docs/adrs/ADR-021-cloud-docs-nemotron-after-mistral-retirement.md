# ADR-021: cloud-docs Moves to nemotron-3-super After mistral-large-3 Retirement

**Status:** Accepted — applied 2026-10-29, follow-ups closed 2026-11-02
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

Both closed on **2026-11-02**. The decision is unchanged.

- ~~**Revisit `mistral-large-4`** once account access opens.~~ **Closed: re-tested and rejected.**
  Account access has opened — `POST /api/chat` now returns **200**, where it returned 403 "rolling out"
  on 2026-10-29 — so the condition for revisiting was met. Re-ran the ADR-013 extraction test (same
  German utility invoice, umlauts stripped, `think: false`):

  | | `/api/chat` | `think: false` honoured | German tags | `created_date` | latency |
  |---|---|---|---|---|---|
  | `nemotron-3-super` (live) | 200 | **yes** — `thinking` and `reasoning_content` both empty | German kept | extracted | 1.6s |
  | `mistral-large-4` | 200 (was 403) | **no** — full chain-of-thought in `thinking` | **translated to English**: `invoice, utility, municipal` | `null` | 9.0s |

  `mistral-large-4` fails the single property this alias is selected on: it reasons despite
  `think: false`. It also translates German tags to English — the exact reason `gemma4:31b` was
  rejected above — dropped the date field, and is 5.6x slower. **Do not adopt it.** The "natural
  same-family successor" argument does not survive measurement. Nothing short of a new non-thinking
  model, or `mistral-large-4` starting to honour the flag, should reopen this.

- ~~**Apply after review.**~~ **Closed: applied 2026-10-29, verified 2026-11-02.**
  `deployment/litellm` carries `kubectl.kubernetes.io/restartedAt: 2026-10-29T21:18:47+01:00` and the
  running pod started `2026-10-29T20:18:47Z`, so the restart followed the apply and the proxy is on
  this config. End-to-end through the proxy today: `cloud-docs` → HTTP 200 in 1.6s, valid JSON in
  `content`, `reasoning_content` and `thinking` both `None`. Open-WebUI curation verified with
  `apply-model-curation.sh --verify-only` → 12 models visible, exit 0, and `mistral-large-3:675b` is
  no longer in the picker.

### Amendment 2026-11-02

The Negative consequence "German titles/correspondents keep OCR-stripped umlauts" is **partly too
pessimistic**, measured on the same invoice: `correspondent` does stay `Stadtwerke Muenchen GmbH`, but
`nemotron-3-super` restored umlauts inside the tag list (`München`, `Fälligkeit 15.11.2026`). So the
limitation applies to fields copied verbatim from the OCR text, not to generated tags.

## Alternatives Considered

| Alternative | Why rejected |
|---|---|
| `mistral-large-4` (Ollama's recommendation) | HTTP 403 "rolling out" on 2026-10-29 — unavailable, would silently fall through. Re-tested 2026-11-02 once access opened: reachable, but ignores `think: false` and translates German tags to English, so still rejected (see Follow-ups) |
| `minimax-m3.1-flash` | Best German, but does not honour `think:false` and makes all three aliases Chinese-lab |
| `gemma4:31b` | Translated German tags to English — wrong for a German document alias |
| Keep `mistral-large-3:675b` | Retires 2026-11-09; would 410 and silently fall through |

## References

- `applications/litellm/configmap.yaml` — `cloud-docs` definition
- `applications/paperless/paperless-gpt/configmap.yaml` — `LLM_MODEL: cloud-docs`
- `applications/open-webui/model-curation.json` — picker keep/hide lists
- [ADR-013](ADR-013-cloud-model-tier-refresh.md) — role-based aliases and the original `cloud-docs` choice
