---
stepsCompleted: [1, 2, 3, 4]
session_active: false
workflow_completed: true
inputDocuments: []
session_topic: 'Ollama pro subscription cloud model integration into K3s home-lab'
session_goals: 'Feasibility assessment of Ollama pod cloud model support + cluster-wide adoption architecture for minimax-m2.5, kimi-k2.5, qwen3-coder-next across openclaw, paperless-gpt, litellm, vllm, n8n and other services'
selected_approach: 'ai-recommended'
techniques_used: ['constraint-mapping', 'solution-matrix', 'decision-tree-mapping']
ideas_generated: [8]
context_file: ''
---

# Brainstorming Session Results

**Facilitator:** Tom
**Date:** 2026-02-19

## Session Overview

**Topic:** Ollama pro subscription cloud model integration into K3s home-lab
**Goals:** Feasibility assessment + cluster-wide adoption architecture for minimax-m2.5, kimi-k2.5, qwen3-coder-next across openclaw, paperless-gpt, litellm, vllm, n8n and other services

### Session Setup

Two-phase session: discovery (what's technically possible?) → design (how to wire it up across the cluster).

## Technique Selection

**Approach:** AI-Recommended Techniques
**Analysis Context:** Complex technical integration problem with multiple interdependencies (3 models × 6+ services), unknown Ollama cloud model behavior, K3s networking constraints

**Recommended Techniques:**

- **Constraint Mapping:** Separate real vs. imagined constraints — directly answers feasibility question
- **Solution Matrix:** Grid of models × services × integration approaches to find optimal pairings
- **Decision Tree Mapping:** Translate matrix findings into concrete if/then implementation decisions

---

## Technique Execution Results

### Technique 1: Constraint Mapping

**Research source:** https://docs.ollama.com/ (cloud, api, authentication pages)

**Real Constraints (confirmed):**
- minimax-m2.5, kimi-k2.5, qwen3-coder-next are **cloud-only models** — executed on Ollama's servers, not locally
- Hardware on k3s nodes is irrelevant — these models never run locally regardless of specs
- Authentication requires `OLLAMA_API_KEY` (Bearer token) — must be added as a K8s Secret
- Ollama pod CAN proxy cloud models if `OLLAMA_API_KEY` is set (transparent routing)
- Two base URLs exist: `http://localhost:11434` (local) and `https://ollama.com/api` (cloud)

**Imagined Constraints (eliminated):**
- ~~Needing to replace the Ollama pod~~ — it stays, serves local models unchanged
- ~~Different API format~~ — cloud models use the same OpenAI-compatible Ollama API
- ~~Hardware limitations~~ — irrelevant for cloud-executed models

**Key Architectural Decision:**
- **Path A** (Ollama pod proxies cloud) — rejected: pod adds latency for no benefit
- **Path B** (LiteLLM direct cloud) — rejected: Ollama pod loses visibility
- **Path C** (LiteLLM as explicit gatekeeper) — **selected**: LiteLLM explicitly controls cloud vs local routing. Clean separation, Ollama pod retains local-only focus.

**New routing order:** `Ollama cloud → vLLM (GPU) → Ollama (CPU)`

---

### Technique 2: Solution Matrix

**Current service LLM wiring (from codebase):**

| Service | Current endpoint | Current model | Integration path |
|---------|-----------------|---------------|-----------------|
| paperless-gpt | LiteLLM | `vllm-qwen` | configmap `LLM_MODEL` |
| open-webui | LiteLLM | `vllm-qwen` | Helm `DEFAULT_MODELS` |
| openclaw | Anthropic direct (primary) + LiteLLM fallback | Claude Opus 4.5 | `openclaw.json` on PVC |
| n8n | Not wired | — | n8n UI credentials |
| vLLM | — | — | Provider only, not consumer |

**Model-to-service assignments:**

| Service | Cloud Model | Rationale |
|---------|-------------|-----------|
| **openclaw** (primary) | `minimax-m2.5` | Best general-purpose for the AI assistant's varied tasks |
| **openclaw** (coder sub-agents) | `qwen3-coder-next` | Purpose-built for agentic coding workflows + browser sandbox |
| **paperless-gpt** | `minimax-m2.5` | Strong multilingual (German docs), real-world productivity focus |
| **open-webui** | All models (user selects) | Chat UI — expose full model list, `minimax-m2.5` as default |
| **n8n** | All models (user selects per workflow) | Varied automation — model configurable per workflow node |

---

### Technique 3: Decision Tree Mapping

**Complete implementation decision tree:**

```
ROOT: Integrate Ollama cloud models as primary across cluster
│
├── [1] LiteLLM configmap: Add cloud provider + 3 model entries
│   ├── Provider: ollama_chat, api_base: https://ollama.com
│   ├── api_key: os.environ/OLLAMA_API_KEY
│   ├── Add: cloud-minimax      (minimax-m2.5)
│   ├── Add: cloud-kimi         (kimi-k2.5)
│   ├── Add: cloud-qwen3-coder  (qwen3-coder-next)
│   ├── Fallback per model: ["vllm-qwen", "ollama-qwen"]
│   └── openai-gpt4o: removed from auto-fallback, kept as explicit parallel only
│
├── [2] litellm-secrets: patch OLLAMA_API_KEY
│   └── kubectl patch secret litellm-secrets -n ml --type='merge'
│       -p '{"stringData":{"OLLAMA_API_KEY":"<key>"}}'
│
├── [3] paperless-gpt configmap
│   └── LLM_MODEL: "vllm-qwen" → "cloud-minimax"
│       Fallback chain: cloud-minimax → vllm-qwen → ollama-qwen
│
├── [4] open-webui values
│   ├── DEFAULT_MODELS: "vllm-qwen" → "cloud-minimax"
│   └── All 3 cloud models auto-visible via LiteLLM /v1/models
│       (no per-model wiring needed)
│
├── [5] openclaw: primary model switch
│   ├── Currently: Claude Opus 4.5 via direct Anthropic API (openclaw.json on PVC)
│   ├── Primary → cloud-minimax via LiteLLM
│   ├── Coder sub-agents → cloud-qwen3-coder via LiteLLM
│   ├── Mechanism: kubectl exec + edit openclaw.json (same as browser config pattern)
│   └── ⚠️  VERIFY FIRST: inspect live openclaw.json before patching
│
└── [6] n8n: no Helm changes required
    ├── Add OpenAI-compatible credential in n8n UI:
    │   base_url: http://litellm.ml.svc.cluster.local:4000/v1
    │   api_key: sk-litellm-X85qLfwJKERbijaT3KDwgZvTKGXl21Rd
    └── Per workflow: user types model name in LLM node
        Available names: cloud-minimax / cloud-kimi / cloud-qwen3-coder
```

**Final routing architecture:**
```
LiteLLM (gatekeeper)
├── cloud-minimax      → ollama.com → vllm-qwen → ollama-qwen
├── cloud-kimi         → ollama.com → vllm-qwen → ollama-qwen
├── cloud-qwen3-coder  → ollama.com → vllm-qwen → ollama-qwen
├── vllm-qwen          → vLLM GPU   → ollama-qwen           (direct, unchanged)
├── ollama-qwen        → Ollama CPU                          (direct, unchanged)
├── granite-docling    → Ollama CPU                          (Docling VLM, unchanged)
└── [parallel]  groq/*, gemini/*, mistral/*                  (explicit selection only)
```

---

### Session Highlights

**Key breakthrough:** Ollama cloud models are hybrid (remote execution, local API surface) — the Ollama pod needs zero changes. LiteLLM absorbs the entire cloud routing concern.

**Architectural clarity:** Moving cloud to primary tier inverts the original fallback chain without breaking any existing infrastructure. All local models remain fully operational as fallbacks.

**Open item:** openclaw.json on PVC must be inspected live before migration — config key names for LLM provider and sub-agent model are unknown until examined.

---

## Idea Organization and Prioritization

### Thematic Clusters

**Theme 1: LiteLLM Core (foundation layer)**
- Add `OLLAMA_API_KEY` to `litellm-secrets` via `kubectl patch`
- Add 3 cloud model entries: `cloud-minimax`, `cloud-kimi`, `cloud-qwen3-coder`
- New fallback chain per cloud model: `ollama.com → vllm-qwen → ollama-qwen`
- Remove `openai-gpt4o` from auto-fallback (keep as explicit parallel only)
- *Pattern insight: single config change unlocks cloud access for all services simultaneously*

**Theme 2: Straightforward Service Config (2 one-line edits)**
- `paperless-gpt` configmap: `LLM_MODEL: "cloud-minimax"`
- `open-webui` values: `DEFAULT_MODELS: "cloud-minimax"`, full model list auto-exposed
- *Pattern insight: both services already route through LiteLLM — zero architecture change*

**Theme 3: Runtime / UI Config (no Helm changes)**
- `n8n`: add OpenAI-compatible credential in UI pointing to LiteLLM
- `openclaw`: inspect live `openclaw.json` → update primary + coder sub-agent model keys
- *Pattern insight: config lives outside git — requires live cluster operations*

### Prioritization

| Priority | Action | Rationale |
|----------|--------|-----------|
| **P1** | LiteLLM configmap + secret | Hard dependency for everything else |
| **P2** | paperless-gpt configmap | Immediate value, 1-line change |
| **P3** | open-webui values | Immediate value, 1-line change |
| **P4** | n8n UI credential | No Helm deploy needed, quick UI setup |
| **P5** | openclaw.json migration | Requires investigation, currently functional on Claude |

### Quick Wins
- Items P1–P4 can be completed in a single session once the `OLLAMA_API_KEY` is obtained from ollama.com/settings/keys
- P2 and P3 are each single-line changes in already-known files

### Breakthrough Concept
The key insight: **cloud models don't require a new integration pattern** — Ollama's cloud API is OpenAI-compatible, LiteLLM already knows how to speak it. The entire cluster upgrade reduces to adding one secret key and ~30 lines of LiteLLM config.

---

## Action Plan

### Step 1: Obtain API key
- Log in to ollama.com → Settings → Keys → Create key
- Note the key value (used in Step 2)

### Step 2: Patch litellm-secrets
```bash
kubectl patch secret litellm-secrets -n ml --type='merge' \
  -p '{"stringData":{"OLLAMA_API_KEY":"<your-ollama-api-key>"}}'
```

### Step 3: Update litellm/configmap.yaml
Add to `model_list`:
```yaml
- model_name: cloud-minimax
  litellm_params:
    model: ollama_chat/minimax-m2.5
    api_base: https://ollama.com
    api_key: os.environ/OLLAMA_API_KEY
    timeout: 60
  model_info:
    mode: chat

- model_name: cloud-kimi
  litellm_params:
    model: ollama_chat/kimi-k2.5
    api_base: https://ollama.com
    api_key: os.environ/OLLAMA_API_KEY
    timeout: 60
  model_info:
    mode: chat

- model_name: cloud-qwen3-coder
  litellm_params:
    model: ollama_chat/qwen3-coder-next
    api_base: https://ollama.com
    api_key: os.environ/OLLAMA_API_KEY
    timeout: 60
  model_info:
    mode: chat
```

Update `litellm_settings.fallbacks`:
```yaml
fallbacks:
  - {"cloud-minimax":      ["vllm-qwen", "ollama-qwen"]}
  - {"cloud-kimi":         ["vllm-qwen", "ollama-qwen"]}
  - {"cloud-qwen3-coder":  ["vllm-qwen", "ollama-qwen"]}
  - {"vllm-qwen":          ["ollama-qwen"]}
```

### Step 4: Update paperless-gpt/configmap.yaml
```yaml
LLM_MODEL: "cloud-minimax"   # was: "vllm-qwen"
```

### Step 5: Update open-webui/values-homelab.yaml
```yaml
DEFAULT_MODELS: "cloud-minimax"   # was: "vllm-qwen"
```
All three cloud models auto-appear in the model picker via LiteLLM `/v1/models`.

### Step 6: Add n8n credential (UI)
- n8n UI → Credentials → New → OpenAI API
- Base URL: `http://litellm.ml.svc.cluster.local:4000/v1`
- API Key: `sk-litellm-X85qLfwJKERbijaT3KDwgZvTKGXl21Rd`
- In each workflow LLM node: set model to `cloud-minimax`, `cloud-kimi`, or `cloud-qwen3-coder`

### Step 7: Migrate openclaw (requires investigation)
```bash
# Inspect current config first
kubectl exec -n apps deployment/openclaw -c openclaw -- \
  cat /home/node/.openclaw/openclaw.json | python3 -m json.tool
```
- Identify LLM provider and model config keys
- Update primary model → `cloud-minimax` via LiteLLM endpoint
- Update coder sub-agent model → `cloud-qwen3-coder` via LiteLLM endpoint
- Currently functional on Claude Opus 4.5 — migrate when ready

---

## Session Summary

**What we set out to do:** Determine if the Ollama pod can run cloud models, and design how to route minimax-m2.5, kimi-k2.5, and qwen3-coder-next as primary models across the cluster.

**What we discovered:**
1. Cloud models are remotely executed on Ollama's servers — hardware is irrelevant
2. LiteLLM is the right integration point, not the Ollama pod
3. The entire migration is ~30 lines of config + 1 secret key
4. openclaw requires a live inspection before migration (all others are fully mapped)

**Final architecture:**
```
LiteLLM (gatekeeper)
├── cloud-minimax      → ollama.com → vllm-qwen → ollama-qwen
├── cloud-kimi         → ollama.com → vllm-qwen → ollama-qwen
├── cloud-qwen3-coder  → ollama.com → vllm-qwen → ollama-qwen
├── vllm-qwen          → vLLM GPU   → ollama-qwen
├── ollama-qwen        → Ollama CPU
├── granite-docling    → Ollama CPU  (Docling VLM, unchanged)
└── [parallel]  groq/*, gemini/*, mistral/*  (explicit selection only)
```

**Service model assignments:**
- `paperless-gpt` → `cloud-minimax` (German doc productivity)
- `open-webui` → all models, default `cloud-minimax`
- `openclaw` primary → `cloud-minimax`, coder sub-agents → `cloud-qwen3-coder`
- `n8n` → all models, configurable per workflow
