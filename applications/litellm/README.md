# LiteLLM Proxy

LiteLLM provides a unified OpenAI-compatible API endpoint for all inference models in the home-lab cluster.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        LiteLLM Proxy                             │
│                  (litellm.home.jetzinger.com)                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   FALLBACK CHAIN (automatic failover)                           │
│   ┌──────────────┐   ┌─────────┐   ┌─────────┐                 │
│   │ Ollama Pro   │──▶│  vLLM   │──▶│ Ollama  │                 │
│   │ (Cloud)      │   │  (GPU)  │   │  (CPU)  │                 │
│   └──────────────┘   └─────────┘   └─────────┘                 │
│    cloud-docs                                                    │
│    cloud-fast                                                    │
│    cloud-smart                                                   │
│                                                                  │
│   PARALLEL MODELS (explicit selection)                          │
│   ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────────┐          │
│   │  Groq   │ │ Gemini  │ │ Mistral │ │ openai-gpt4o│          │
│   └─────────┘ └─────────┘ └─────────┘ └─────────────┘          │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Available Models

### Cloud Tier (primary) — ADR-013

Role-based aliases backed by Ollama Pro cloud models. Request the **role**, never the vendor model
name: when Ollama retires a tag, only the `model:` line in `configmap.yaml` changes.

| Model Name | Backing model | Timeout | Description |
|------------|---------------|---------|-------------|
| `cloud-docs` | `mistral-large-3:675b` | 90s | Document metadata extraction (Paperless-GPT). Strongest German; no thinking mode, so it cannot leak reasoning into an empty `content` field |
| `cloud-fast` | `deepseek-v4.1-flash` | 60s | Quick general inference, 1M context |
| `cloud-smart` | `kimi-k3` | 60s | Frontier reasoning / agentic work (Open-WebUI default), 1M context |

Each alias is the newest model of a **different lab** (Mistral AI / DeepSeek / Moonshot) so a single
lab's retirement wave cannot break the whole chain.

### Local Tier (fallback)

| Model Name | Backend | Timeout | Description |
|------------|---------|---------|-------------|
| `vllm-qwen` | vLLM (GPU) | 60s | Qwen3-8B-AWQ on RTX 3060 |
| `ollama-qwen` | Ollama (CPU) | 300s | phi4-mini on CPU, 128K context |
| `openai-gpt4o` | OpenAI Cloud | 30s | gpt-4o-mini — **explicit selection only**, NOT in the auto-fallback chain (FR218) |

### Fallback chain

```
cloud-docs → cloud-fast → cloud-smart → vllm-qwen → ollama-qwen
cloud-fast → cloud-smart → vllm-qwen → ollama-qwen
cloud-smart → cloud-fast → vllm-qwen → ollama-qwen
vllm-qwen  → ollama-qwen
```

> **Silent fallback warning.** A retired cloud model returns HTTP 410 and LiteLLM transparently falls
> through to the next tier, so a broken alias still answers and looks healthy. In Sept 2026 three
> aliases were dead for weeks before anyone noticed. Always confirm which model actually served a
> request via the `model` field in the response body, not by the absence of errors.

### Mode-Dependent Models (vLLM R1)
The vLLM backend can serve different models depending on the active GPU mode. The `vllm-r1` model is only available when the GPU worker is in **R1-Mode**.

| Model Name | Backend | Timeout | Description | GPU Mode Required |
|------------|---------|---------|-------------|-------------------|
| `vllm-r1` | vLLM (GPU) | 60s | DeepSeek-R1 7B reasoning model | R1-Mode |

#### Mode-Dependent Availability

| GPU Mode | `vllm-qwen` | `vllm-r1` |
|----------|-------------|-----------|
| ML-Mode | Available | ❌ HTTP 404 |
| R1-Mode | ❌ HTTP 404 | Available |
| Gaming-Mode | ❌ HTTP 503 | ❌ HTTP 503 |

Check current mode: `ssh k3s-gpu-worker "gpu-mode status"`

Switch modes: `ssh k3s-gpu-worker "gpu-mode ml"` or `gpu-mode r1` or `gpu-mode gaming`

#### DeepSeek-R1 Response Format
DeepSeek-R1 outputs its reasoning process in `<think>` tags before the final answer:

```
<think>
Let me analyze this step by step...
First, I need to consider...
</think>

The answer is...
```

Applications should parse or display these tags appropriately for reasoning transparency.

### Parallel Models
These models are independent and must be requested explicitly by name. They do NOT participate in the fallback chain.

| Model Name | Provider | Free Tier Limit | Description |
|------------|----------|-----------------|-------------|
| `groq/llama-3.3-70b-versatile` | Groq | 6,000 req/day | Fast inference, large model |
| `groq/mixtral-8x7b-32768` | Groq | 6,000 req/day | MoE model, 32k context |
| `gemini/gemini-2.0-flash` | Google AI | 1,500 req/day | Fast, general purpose |
| `gemini/gemini-2.5-flash` | Google AI | 1,500 req/day | Latest, more capable |
| `mistral/mistral-small-latest` | Mistral | varies | European provider |

## Usage Examples

### Using Fallback Chain (Recommended for Applications)
```bash
# Request to primary model - auto-fails over if unavailable
curl -X POST https://litellm.home.jetzinger.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "cloud-docs",
    "messages": [{"role": "user", "content": "Hello"}]
  }'
```

### Using R1 Reasoning Model
```bash
# First, ensure GPU is in R1-Mode: ssh k3s-gpu-worker "gpu-mode r1"
# Request reasoning model (outputs <think> tags with chain-of-thought)
curl -X POST https://litellm.home.jetzinger.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "vllm-r1",
    "messages": [{"role": "user", "content": "Solve this step by step: If a train travels 120km in 2 hours, what is its average speed?"}],
    "max_tokens": 500
  }'
```

### Using Parallel Models (Explicit Selection)
```bash
# Direct request to Groq (fast inference)
curl -X POST https://litellm.home.jetzinger.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "groq/llama-3.3-70b-versatile",
    "messages": [{"role": "user", "content": "Hello"}]
  }'

# Direct request to Gemini
curl -X POST https://litellm.home.jetzinger.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gemini/gemini-2.0-flash",
    "messages": [{"role": "user", "content": "Hello"}]
  }'

# Direct request to Mistral
curl -X POST https://litellm.home.jetzinger.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "mistral/mistral-small-latest",
    "messages": [{"role": "user", "content": "Hello"}]
  }'
```

### List Available Models
```bash
curl https://litellm.home.jetzinger.com/v1/models | jq '.data[].id'
```

## Configuration

### Files
- `configmap.yaml` - Model definitions and LiteLLM settings
- `secret.yaml` - API keys (placeholders - update via kubectl patch)
- `deployment.yaml` - Kubernetes deployment and service

### Updating API Keys
API keys are stored as placeholders in git. Update them in the cluster:

```bash
# Groq API Key
kubectl patch secret litellm-secrets -n ml --type='json' \
  -p='[{"op": "add", "path": "/stringData/GROQ_API_KEY", "value": "gsk_your-key"}]'

# Gemini API Key
kubectl patch secret litellm-secrets -n ml --type='json' \
  -p='[{"op": "add", "path": "/stringData/GEMINI_API_KEY", "value": "your-key"}]'

# Mistral API Key
kubectl patch secret litellm-secrets -n ml --type='json' \
  -p='[{"op": "add", "path": "/stringData/MISTRAL_API_KEY", "value": "your-key"}]'

# OpenAI API Key (for fallback)
kubectl patch secret litellm-secrets -n ml --type='json' \
  -p='[{"op": "add", "path": "/stringData/OPENAI_API_KEY", "value": "sk-your-key"}]'
```

### Applying Configuration Changes
```bash
# Apply configmap changes
kubectl apply -f applications/litellm/configmap.yaml

# Restart deployment to pick up changes
kubectl rollout restart deployment/litellm -n ml

# Verify pod is healthy
kubectl get pods -n ml -l app=litellm
```

## Rate Limits and Quotas

External providers have free tier quotas. LiteLLM does not enforce daily limits natively - monitor usage via Prometheus.

| Provider | Daily Limit | Sustained Rate |
|----------|-------------|----------------|
| Groq | 6,000 req/day | ~4 req/min |
| Google AI | 1,500 req/day | ~1 req/min |
| Mistral | varies | varies |

### Monitoring
- Prometheus metrics: `litellm_proxy_total_requests_metric_total{requested_model="..."}`
- Grafana dashboard: LiteLLM Dashboard shows request rates per model

## Health Endpoints

| Endpoint | Purpose |
|----------|---------|
| `/health/liveliness` | Liveness probe |
| `/health/readiness` | Readiness probe |
| `/metrics/` | Prometheus metrics (note trailing slash) |

## Troubleshooting

### Model Not Available
```bash
# Check if API key is set
kubectl get secret litellm-secrets -n ml -o jsonpath='{.data.GROQ_API_KEY}' | base64 -d

# Check LiteLLM logs
kubectl logs -n ml -l app=litellm --tail=100
```

### Failover Not Working
```bash
# Check vLLM status
kubectl get pods -n ml -l app=vllm

# Check Ollama status
kubectl get pods -n ml -l app=ollama

# Test fallback chain
curl https://litellm.home.jetzinger.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "cloud-docs", "messages": [{"role": "user", "content": "test"}]}'
```

## References

- [LiteLLM Documentation](https://docs.litellm.ai/)
- [Story 14.1-14.6](../docs/implementation-artifacts/) - Implementation stories
- [Architecture](../docs/planning-artifacts/architecture.md) - System architecture
