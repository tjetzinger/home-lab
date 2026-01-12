# vLLM - GPU-Accelerated LLM Inference

GPU-accelerated inference server running on Intel NUC with RTX 3060 eGPU.

## Overview

| Component | Value |
|-----------|-------|
| Namespace | `ml` |
| Model | `TheBloke/deepseek-coder-6.7B-instruct-AWQ` |
| Quantization | AWQ (4-bit, marlin kernel) |
| VRAM Usage | ~3.7 GB |
| Performance | ~47-48 tok/s |
| Endpoint | https://vllm.home.jetzinger.com |

## Model Details

**DeepSeek-Coder-6.7B-Instruct (AWQ)**
- 6.7B parameter code generation model
- AWQ 4-bit quantization reduces VRAM from ~13GB to ~3.7GB
- Optimized for code completion, generation, and explanation
- 8192 token context length

## API Endpoints

### List Models
```bash
curl https://vllm.home.jetzinger.com/v1/models
```

### Code Completion
```bash
curl -X POST https://vllm.home.jetzinger.com/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "TheBloke/deepseek-coder-6.7B-instruct-AWQ",
    "prompt": "def fibonacci(n):",
    "max_tokens": 100,
    "temperature": 0.1
  }'
```

### Chat Completions (OpenAI-compatible)
```bash
curl -X POST https://vllm.home.jetzinger.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "TheBloke/deepseek-coder-6.7B-instruct-AWQ",
    "messages": [{"role": "user", "content": "Write a Python function to reverse a string"}],
    "max_tokens": 200
  }'
```

### Swagger UI
Interactive API documentation: https://vllm.home.jetzinger.com/docs

## Infrastructure

### GPU Worker Node
- **Node:** k3s-gpu-worker (Intel NUC)
- **GPU:** RTX 3060 12GB (eGPU via Thunderbolt)
- **CUDA:** 12.2
- **Driver:** 535.274.02

### Kubernetes Resources
- Deployment with `runtimeClassName: nvidia`
- NodeSelector: `nvidia.com/gpu=true`
- Toleration: `gpu=true:NoSchedule`
- HostPath volume for model cache persistence

## Graceful Degradation

vLLM supports graceful degradation to Ollama CPU when the GPU becomes unavailable (maintenance, hot-plug, gaming mode).

### Architecture

```
Normal Operation:
  n8n Workflow → vLLM (GPU) → Fast inference (~47 tok/s)

GPU Unavailable:
  n8n Workflow → Health Check → vLLM DOWN → Ollama (CPU) → Slower inference (<5s)
```

### Health Check

```bash
# Check vLLM availability
curl http://vllm-api.ml.svc.cluster.local:8000/health
# Returns 200 OK when ready
```

### Fallback Configuration

The `llm-fallback-config` ConfigMap provides endpoint configuration for n8n workflows:

| Key | Value | Purpose |
|-----|-------|---------|
| `VLLM_ENDPOINT` | http://vllm-api.ml.svc.cluster.local:8000 | Primary GPU endpoint |
| `VLLM_HEALTH_ENDPOINT` | http://vllm-api.ml.svc.cluster.local:8000/health | Health check |
| `OLLAMA_ENDPOINT` | http://ollama.ml.svc.cluster.local:11434 | CPU fallback |
| `OLLAMA_GENERATE_ENDPOINT` | http://ollama.ml.svc.cluster.local:11434/api/generate | Text generation |

### n8n Fallback Routing Pattern

Use this pattern in n8n Code nodes before HTTP Request nodes:

```javascript
// Check vLLM health (GPU)
const healthCheck = async () => {
  try {
    const response = await $http.get('http://vllm-api.ml.svc.cluster.local:8000/health', {
      timeout: 5000
    });
    return response.status === 200;
  } catch (error) {
    return false;
  }
};

const vllmAvailable = await healthCheck();

if (vllmAvailable) {
  // Use GPU-accelerated vLLM
  return {
    endpoint: 'http://vllm-api.ml.svc.cluster.local:8000/v1/completions',
    mode: 'gpu',
    model: 'TheBloke/deepseek-coder-6.7B-instruct-AWQ'
  };
} else {
  // Fallback to CPU Ollama
  return {
    endpoint: 'http://ollama.ml.svc.cluster.local:11434/api/generate',
    mode: 'cpu',
    model: 'llama3.2:1b'
  };
}
```

### Timing Requirements

| Metric | Target | Actual |
|--------|--------|--------|
| GPU unavailability detection | <10s (NFR50) | ~5s |
| Ollama CPU inference latency | <5s (NFR54) | ~4.2s |

## Files

| File | Purpose |
|------|---------|
| `deployment.yaml` | vLLM deployment with GPU resources |
| `service.yaml` | ClusterIP service on port 8000 |
| `ingress.yaml` | IngressRoute + TLS certificate |
| `pvc.yaml` | PVC for model cache (optional, using hostPath) |
| `pdb.yaml` | PodDisruptionBudget for graceful drain |
| `fallback-config.yaml` | ConfigMap with fallback endpoints for n8n |

## Story Reference

- **Epic 12:** GPU/ML Inference Platform
- **Story 12.4:** Deploy vLLM with 3-Model Configuration
- **Requirements:** FR38, FR72, NFR34 (50+ tok/s)
