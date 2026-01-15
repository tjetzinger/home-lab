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
│   ┌─────────┐    ┌─────────┐    ┌─────────┐                    │
│   │ vLLM    │───▶│ Ollama  │───▶│ OpenAI  │                    │
│   │ (GPU)   │    │ (CPU)   │    │ (Cloud) │                    │
│   └─────────┘    └─────────┘    └─────────┘                    │
│                                                                  │
│   PARALLEL MODELS (explicit selection)                          │
│   ┌─────────┐  ┌─────────┐  ┌─────────┐                        │
│   │  Groq   │  │ Gemini  │  │ Mistral │                        │
│   └─────────┘  └─────────┘  └─────────┘                        │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Available Models

### Fallback Chain Models
These models participate in automatic failover. Request `vllm-qwen` and if unavailable, LiteLLM automatically routes to the next tier.

| Model Name | Backend | Timeout | Description |
|------------|---------|---------|-------------|
| `vllm-qwen` | vLLM (GPU) | 3s | Primary - Qwen2.5-7B on RTX 3060 |
| `ollama-qwen` | Ollama (CPU) | 120s | Fallback - Qwen2.5:3b on CPU |
| `openai-gpt4o` | OpenAI Cloud | 30s | Emergency - gpt-4o-mini |

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
    "model": "vllm-qwen",
    "messages": [{"role": "user", "content": "Hello"}]
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
  -d '{"model": "vllm-qwen", "messages": [{"role": "user", "content": "test"}]}'
```

## References

- [LiteLLM Documentation](https://docs.litellm.ai/)
- [Story 14.1-14.6](../docs/implementation-artifacts/) - Implementation stories
- [Architecture](../docs/planning-artifacts/architecture.md) - System architecture
