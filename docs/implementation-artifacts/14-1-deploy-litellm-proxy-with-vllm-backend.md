# Story 14.1: Deploy LiteLLM Proxy with vLLM Backend

Status: done

## Story

As a **cluster operator**,
I want **to deploy LiteLLM proxy with vLLM as the primary backend**,
So that **I have a unified OpenAI-compatible endpoint for all AI inference requests**.

## Acceptance Criteria

1. **Given** the `ml` namespace exists with vLLM deployment running
   **When** I deploy LiteLLM via Kubernetes manifests
   **Then** LiteLLM pod starts successfully in the `ml` namespace
   **And** LiteLLM exposes an OpenAI-compatible API endpoint

2. **Given** LiteLLM is deployed
   **When** I configure it to use vLLM as the primary model backend
   **Then** LiteLLM correctly proxies requests to vLLM
   **And** responses are returned in OpenAI API format

3. **Given** LiteLLM is routing to vLLM
   **When** I send a chat completion request to the LiteLLM endpoint
   **Then** the response matches the model output from vLLM
   **And** latency overhead is <100ms (NFR66)

## Tasks / Subtasks

- [x] Task 1: Research LiteLLM deployment options (AC: #1)
  - [x] Review LiteLLM Docker image and configuration options
  - [x] Determine deployment method (raw manifests vs Helm)
  - [x] Identify required environment variables and config format

- [x] Task 2: Create Kubernetes deployment manifests (AC: #1)
  - [x] Create `applications/litellm/` directory structure
  - [x] Create Deployment manifest (deploy to k3s-worker-01 or k3s-worker-02, NOT gpu-worker)
  - [x] Create ConfigMap for LiteLLM configuration (model_list, routing)
  - [x] Create Service (ClusterIP on port 4000)
  - [x] Apply standard labels: `app.kubernetes.io/name: litellm`, `app.kubernetes.io/part-of: home-lab`

- [x] Task 3: Configure LiteLLM with vLLM backend (AC: #2)
  - [x] Configure model_list with vLLM endpoint: `http://vllm-api.ml.svc.cluster.local:8000/v1`
  - [x] Set model name to match vLLM model: `Qwen/Qwen2.5-7B-Instruct-AWQ`
  - [x] Configure routing_strategy for single backend (will expand in Story 14.2)

- [x] Task 4: Create IngressRoute for LiteLLM (AC: #1)
  - [x] Create Traefik IngressRoute at `litellm.home.jetzinger.com`
  - [x] Configure TLS with Let's Encrypt certificate
  - [x] Test external access via Tailscale

- [x] Task 5: Validate deployment and proxy functionality (AC: #2, #3)
  - [x] Verify LiteLLM pod is Running on non-GPU worker (k3s-worker-02)
  - [x] Test `/v1/chat/completions` endpoint through LiteLLM
  - [x] Measure latency overhead (~18ms, well under 100ms NFR66)
  - [x] Compare response format with direct vLLM response

## Gap Analysis

**Scan Date:** 2026-01-14

✅ **What Exists:**
- `ml` namespace with running services
- vLLM service: `vllm-api.ml.svc.cluster.local:8000`
- Ollama service: `ollama.ml.svc.cluster.local:11434`
- Standard deployment patterns in `applications/tika/`, `applications/stirling-pdf/`

❌ **What's Missing:**
- `applications/litellm/` directory
- All LiteLLM manifests (deployment, service, configmap, ingressroute)

**Task Changes:** None - draft tasks accurately reflect codebase state

---

## Dev Notes

### Architecture Constraints

- **Deployment Target:** k3s-worker-01 or k3s-worker-02 (NOT k3s-gpu-worker)
  - LiteLLM is a lightweight proxy, no GPU needed
  - Must remain available during Gaming Mode when GPU worker scales vLLM to 0
- **Namespace:** `ml` (same as vLLM and Ollama)
- **Port:** 4000 (LiteLLM default)

### Current ML Infrastructure

| Service | Node | Endpoint |
|---------|------|----------|
| vLLM | k3s-gpu-worker | `http://vllm-api.ml.svc.cluster.local:8000/v1` |
| Ollama | k3s-worker-02 | `http://ollama.ml.svc.cluster.local:11434` |
| LiteLLM | k3s-worker-01/02 | `http://litellm.ml.svc.cluster.local:4000/v1` (new) |

### LiteLLM Configuration Pattern

From architecture.md - use this config structure:
```yaml
model_list:
  - model_name: "default"
    litellm_params:
      model: "openai/qwen2.5:14b"
      api_base: "http://vllm-api.ml.svc.cluster.local:8000/v1"
    model_info:
      mode: "chat"

router_settings:
  routing_strategy: "simple-shuffle"
  num_retries: 2
  timeout: 30
```

### File Structure Requirements

Follow existing patterns in `applications/` directory:
```
applications/litellm/
├── deployment.yaml      # Deployment + Service
├── configmap.yaml       # LiteLLM config
├── ingressroute.yaml    # Traefik IngressRoute
└── README.md            # Optional documentation
```

### Testing Requirements

- Verify OpenAI-compatible `/v1/chat/completions` endpoint works
- Measure latency: direct vLLM vs through LiteLLM (overhead <100ms)
- Test with curl or similar tool before Paperless-AI integration

### References

- [Source: docs/planning-artifacts/architecture.md#LiteLLM Inference Proxy Architecture]
- [Source: docs/planning-artifacts/epics.md#Story 14.1]
- [Source: docs/planning-artifacts/prd.md#FR113-118]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.5 (claude-opus-4-5-20251101)

### Debug Log References

- Initial deployment required api_key fix (vLLM doesn't require auth but LiteLLM client needs a value)
- Model name mismatch: story referenced `qwen2.5:14b` but vLLM serves `Qwen/Qwen2.5-7B-Instruct-AWQ`

### Completion Notes List

- LiteLLM v1.80.16 deployed successfully
- Pod scheduled on k3s-worker-02 (non-GPU worker) via nodeAffinity
- Proxy latency overhead: ~18ms (NFR66 target: <100ms)
- TLS certificate issued and valid until Apr 2026
- Endpoint: https://litellm.home.jetzinger.com

### File List

- `applications/litellm/configmap.yaml` - LiteLLM configuration with vLLM backend
- `applications/litellm/deployment.yaml` - Deployment + Service (port 4000)
- `applications/litellm/ingressroute.yaml` - Certificate + IngressRoute for HTTPS
