# ADR-022: Local Uncensored Chat Model as a vLLM GPU Mode

**Status:** Accepted — applied 2026-11-24
**Date:** 2026-11-24
**Decision Makers:** Tom, Claude (AI Assistant)
**Relates to:** [ADR-013](ADR-013-cloud-model-tier-refresh.md) (reverses its "uncensored models rejected"),
[ADR-020](ADR-020-clear-standing-alerts.md) (same GeForce forward-compat limit)

## Context

Tom asked for `huihui_ai/gemma-4-abliterated:12b-qat` to be usable in Open WebUI, together with
current releases of Open WebUI and Ollama.

ADR-013 rejected uncensored models because Ollama Cloud carries none and the only alternative was CPU
inference with the GPU worker down. The GPU worker is back (it had been cordoned since ~2026-11-06), so
that reason no longer holds.

Three facts shaped the decision:

1. **CPU is not viable for chat.** phi4-mini (2.5 GB) measured 5.3 tok/s on the CPU Ollama. A 7.6 GB
   model would manage ~1.5–3 tok/s, and Open WebUI's always-on Exa search adds 2–4k prompt tokens that
   prefill at ~9 tok/s — minutes before the first word.
2. **The GPU cannot hold two models.** vLLM (Qwen3-8B-AWQ) uses 10.8 of the RTX 3060's 12 GB.
3. **Every other GPU workload already runs on vLLM** and is switched by `gpu-mode`.

## Decision

### 1. Run Gemma on vLLM as a third model mode: `gpu-mode gemma`

Tom chose consistency: the same engine and the same switch as `ml` and `r1`, rather than a second
Ollama release on the GPU. `applications/vllm/deployment-gemma.yaml` is applied by `gpu-mode gemma`
exactly like `deployment-r1.yaml`. `gpu-mode`'s R1 logic became a generic `model_mode` used by both.

**This is not the model Tom named.** The Ollama tag is a GGUF of huihui-ai's QAT variant and has no
vLLM-loadable 4-bit build. vLLM serves
[`nicklas373/Huihui-gemma-4-12B-it-abliterated-AWQ`](https://huggingface.co/nicklas373/Huihui-gemma-4-12B-it-abliterated-AWQ):
the same huihui-ai abliterated Gemma 4 12B, W4A16 compressed-tensors (group 32), quantized by a third
party (llm-compressor 0.12.0, 5k downloads, 0 likes at the time). Accepted by Tom on that basis.

### 2. Upgrade vLLM v0.8.5.post1 → v0.34.0 and the host driver 570 → 580

`Gemma4UnifiedForConditionalGeneration` first appears in vLLM v0.30. The path there was not direct:

| Attempt | Result |
|---|---|
| `v0.32.0-cu129` (newest CUDA-12 image; v0.33+ are CUDA 13 only) | Crashed on import: its `torchcodec` is a CUDA-13 build (`libnvrtc.so.13` missing), raising `OSError`, which vLLM's import guard does not catch |
| Same, with a shim making `torchcodec` raise `ImportError` | `Error 804: forward compatibility was attempted on non supported HW` — CUDA 12.9 on a 12.8 driver needs forward compat, which GeForce cards never support (ADR-020's validator failure is the same thing) |
| Host `nvidia-driver-580-server` **580.178.04** + `v0.34.0` (CUDA 13) | Works for all three modes. The shim was dropped |

The 570-server packages became transitional packages depending on 580. The i386 GL/compute/decode/
encode/fbc libraries were installed alongside, so Steam keeps working (not re-tested in a game).

### 3. Fitting Gemma into 12 GB

Weights take 8.11 GiB. Gemma 4's 8 full-attention layers use 512-dim heads and the 40 sliding-window
layers cost a near-fixed amount, so an 8K context needs 1.71 GiB of KV and 6K still needs 1.68 GiB.
v0.34 also sizes the KV cache **after** warmup, from memory actually free.

| Setting | KV available | Result |
|---|---|---|
| util 0.92, defaults | 1.36 GiB | refused |
| util 0.94, 6144 ctx | 1.59 GiB | refused (needs 1.68) |
| `--kv-cache-dtype fp8` | — | refused: Triton backend needs SM89+, RTX 3060 is SM86 |
| util 0.96, defaults | 0.59 GiB after warmup | refused: the 256-sequence sampler warmup over a 262k vocabulary ate ~1.2 GiB |
| util 0.97, `--max-num-seqs 4`, 2048 batched tokens | 0.95 GiB | refused: 1.31 GiB kept for activations |
| **util 0.97, `--max-num-seqs 4`, `--max-num-batched-tokens 512`** | **1.69 GiB** | **runs: 17,964 KV tokens, 8K context** |

`--language-model-only` skips the vision and audio encoders. Text chat only.

### 4. Reach it through a LiteLLM role alias: `local-uncensored`

Not a second `ollamaUrl` in Open WebUI. The alias follows ADR-013's role naming, so a later model swap
changes one `model:` line. It sends `chat_template_kwargs.enable_thinking: false` (the template default
is already off). It is **outside every fallback chain in both directions**: an uncensored model must
never answer for a cloud alias, and a cloud model must never silently answer a prompt meant to stay
local. Outside `gpu-mode gemma` a request fails with vLLM's "model does not exist" — intended.

### 5. Open WebUI: builtin tools and web search off for this model

`model-curation.json` keep entries can now carry `capabilities` and `params` overrides, applied and
verified from SQLite by `apply-model-curation.sh`. `local-uncensored` sets `builtin_tools: false` (made
small local models slow on the laptop) and `web_search: false` (would send every prompt to Exa).
`web_search` is enforced by the browser, not the server: an API client sending `features.web_search`
itself still gets a search.

> **Amended 2026-11-24:** web search switched **on** for `local-uncensored` at Tom's request
> (`web_search: true`). Prompts now go to Exa like every other model's; builtin tools stay off.

### 6. Same pass: Open WebUI and the CPU Ollama to current releases

| Component | Before | After |
|---|---|---|
| Open WebUI | 0.11.3 (chart 16.5.0) | **0.13.4** (chart 18.4.0), image tag now pinned |
| Ollama (CPU) | 0.13.5 (chart 1.37.0) | **0.40.17** (chart 1.96.0); 0.40.18 skipped, same-day release |
| vLLM | v0.8.5.post1 | **v0.34.0** |
| NVIDIA driver (k3s-gpu-worker) | 570.211.01 | **580.178.04** |

Open WebUI ran 15 schema migrations (`d4c1a8e37b62` → `9f6c2a8d1b43`). The pre-upgrade backup was an
online SQLite copy, `webui-pre-0.13.4-20261124-152807.db` on the data PVC, because the planned
scale-down was not permitted at the time.

`values-homelab.yaml` had not rendered since commit `91b7283`: the chart runs `extraEnvVars` through
`tpl`, and `{{CURRENT_DATE}}` in the query-generation template failed as an undefined function. The
placeholders are now escaped as Go-template string literals.

## Measured

| Mode / path | Throughput |
|---|---|
| `local-uncensored` via LiteLLM, 370-token answer | **22.9 tok/s** end to end (vLLM reports 22.5 tok/s generation) |
| `vllm-qwen` (`ml`) via LiteLLM | 36.9 tok/s |
| `vllm-r1` (`r1`) via LiteLLM | 59.3 tok/s |
| phi4-mini, CPU Ollama | 5.3 tok/s |

Mode switch times: `ml` 69 s, `r1` 102 s (NFR81 target 90 s), `gemma` 72 s from cache.
Gemma runs with `--enforce-eager` like the other modes; CUDA graphs would cost memory it does not have.

## Consequences

### Positive

- One engine, one switch: all three GPU models are vLLM manifests selected by `gpu-mode`
- vLLM is current instead of 19 months behind; the eGPU runbook's open upgrade item is closed
- No fallback in either direction. (Web search was off to keep prompts local; switched on 2026-11-24)

### Negative

- In `gemma` mode `vllm-qwen` is offline, so the cloud aliases' local fallback ends at CPU `ollama-qwen`
  — the same trade as gaming mode
- Gemma runs at 0.97 of VRAM with batch 4 and 512-token prefill chunks. There is no headroom for a
  longer context or a busier desktop session on that GPU
- The quantization is a third party's, of the non-QAT variant. Quality is untested beyond smoke prompts
- The host driver is now a manual dependency of the vLLM image: any image built for a newer CUDA than
  the driver fails with error 804 on this card

### Incidents during the change

- **Disk eviction.** Pre-pulling the 11 GB `v0.32.0-cu129` image took the NUC from 42 GB to ~11.7 GB
  free, under the kubelet's 5% eviction threshold. It evicted the running vLLM pod and image-GC'd both
  vLLM images. Six unreferenced model caches (39.6 GB, January experiments) were deleted; 62 GB free now.
- **`gpu-mode-default.service` never ran.** It was `After=graphical.target` but
  `WantedBy=multi-user.target`. A target is implicitly ordered after the units it wants, so
  multi-user → unit → graphical → multi-user was a cycle; systemd logged `Found ordering cycle` and
  deleted the job at every boot. Fixed: `After=display-manager.service k3s-agent.service`,
  `WantedBy=graphical.target`. Verified by a reboot from `gemma` mode: the service switched to `ml`
  on its own (132 s, NFR52 target 120 s).

## Follow-ups

- `gpu-mode`'s health check and `status` model list `exec` into the Ollama pod and call `curl`, which the
  Ollama image does not ship (0.13.5 or 0.40.17). Both always report "could not verify"
- Steam on driver 580 not yet tested in a game
- R1 load time 102 s exceeds NFR81 (90 s) on v0.34

## Alternatives Considered

| Alternative | Why rejected |
|---|---|
| CPU Ollama on k3s-worker-01 (24 GiB) | ~1.5–3 tok/s and minutes of prefill with web search on |
| Second Ollama release on the GPU, switched by a new mode | Works with the exact GGUF and the old driver, but a second engine on the GPU; Tom preferred consistency |
| Ollama replacing vLLM on the GPU | Biggest change: retires vLLM and reworks every mode |
| Stay on driver 570 with a CUDA-12 vLLM | No CUDA-12.8 image has Gemma 4; cu129 needs forward compat (error 804) |
| 4K context instead of tuning | Would have fit at util 0.94, but halves usable chat length; the tuned 8K config works |
| Second `ollamaUrl` in Open WebUI | Pulls phi4-mini, granite-docling and a dead cloud stub into the picker; thinking control left to the browser |

## References

- `applications/vllm/deployment-gemma.yaml` — the Gemma manifest and its memory budget
- `applications/vllm/deployment.yaml`, `deployment-r1.yaml` — v0.34.0
- `scripts/gpu-worker/gpu-mode` — `gemma` mode, generic `model_mode`
- `applications/litellm/configmap.yaml` — `local-uncensored`
- `applications/open-webui/model-curation.json`, `scripts/open-webui/apply-model-curation.sh` — per-model overrides
- `applications/open-webui/values-homelab.yaml`, `applications/ollama/values-homelab.yaml` — version pins
