# vLLM - GPU-Accelerated LLM Inference

GPU-accelerated inference server running on Intel NUC with RTX 3060 eGPU.

## Overview

| Component | Value |
|-----------|-------|
| Namespace | `ml` |
| ML Model | `Qwen/Qwen3-8B-AWQ` |
| R1 Model | `casperhansen/deepseek-r1-distill-qwen-7b-awq` |
| Quantization | AWQ 4-bit (marlin kernel) |
| vLLM Version | v0.8.5.post1 |
| VRAM Usage | ~6 GB (ML), ~5.2 GB (R1) |
| Performance | 30-50 tok/s (ML), ~55 tok/s (R1) |
| Endpoint | https://vllm.home.jetzinger.com |

## Models

### Qwen3-8B-AWQ (ML Mode - Default)

- 8B parameter multilingual model (119 languages)
- AWQ 4-bit quantization (~6GB VRAM)
- Optimized for document classification, chat, and general inference
- 8192 token context length (configured, native supports 32K)
- 90% classification accuracy for document metadata
- Supports thinking mode via `/think` and `/no_think` prompt tags

### DeepSeek-R1-Distill-Qwen-7B-AWQ (R1 Mode)

- 7B parameter reasoning model distilled from DeepSeek-R1 671B
- AWQ 4-bit quantization (~5.2GB VRAM, ~8.5GB total with KV cache)
- Optimized for chain-of-thought reasoning tasks
- Explicit tokenizer override: `deepseek-ai/DeepSeek-R1-Distill-Qwen-7B`
- Outputs reasoning with `<think>` tags

## API Endpoints

### List Models
```bash
curl https://vllm.home.jetzinger.com/v1/models
```

### Chat Completions (OpenAI-compatible)
```bash
curl -X POST https://vllm.home.jetzinger.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen3-8B-AWQ",
    "messages": [{"role": "user", "content": "Classify this document and return title, tags, correspondent as JSON."}],
    "max_tokens": 200,
    "temperature": 0.1
  }'
```

### R1 Reasoning Request
```bash
curl -X POST https://vllm.home.jetzinger.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "casperhansen/deepseek-r1-distill-qwen-7b-awq",
    "messages": [{"role": "user", "content": "Solve: What is 15 + 27? Think step by step."}],
    "max_tokens": 300,
    "temperature": 0.1
  }'
```

### Swagger UI
Interactive API documentation: https://vllm.home.jetzinger.com/docs

## Infrastructure

### GPU Worker Node
- **Node:** k3s-gpu-worker (Intel NUC)
- **GPU:** RTX 3060 12GB (eGPU via Thunderbolt)
- **VRAM Budget:** ~6GB model + ~6GB KV cache headroom

### Kubernetes Resources
- Deployment with `runtimeClassName: nvidia`
- NodeSelector: `nvidia.com/gpu=true`
- Toleration: `gpu=true:NoSchedule`
- Strategy: `Recreate` (exclusive GPU access)
- HostPath volume for model cache persistence (`/var/lib/vllm/huggingface`)
- emptyDir with Memory medium for `/dev/shm` (shared memory)

## GPU Mode Switching

### Available Modes

| Mode | Model | VRAM | Performance | Use Case |
|------|-------|------|-------------|----------|
| `ml` (default) | Qwen/Qwen3-8B-AWQ | ~6 GB | 30-50 tok/s | Document classification, chat, general |
| `r1` | casperhansen/deepseek-r1-distill-qwen-7b-awq | ~5.2 GB | ~55 tok/s | Chain-of-thought reasoning |
| `gaming` | (scaled to 0) | 0 GB | N/A | Release GPU for Steam |

### Commands
```bash
gpu-mode ml       # Switch to Qwen3 (default at boot)
gpu-mode r1       # Switch to DeepSeek-R1 reasoning
gpu-mode gaming   # Release GPU for gaming
gpu-mode status   # Show current mode and GPU status
```

### Default Boot Behavior
`gpu-mode-default.service` auto-activates ML mode at boot.

## Graceful Degradation

Three-tier fallback via LiteLLM proxy:

```
Normal:     App → LiteLLM → vLLM (GPU, 30-50 tok/s)
GPU Off:    App → LiteLLM → Ollama (CPU, <60s classify)
Full Down:  App → LiteLLM → OpenAI (cloud, pay-per-use)
```

**Important:** All consumers connect via LiteLLM proxy at `http://litellm.ml.svc.cluster.local:4000/v1`, never directly to vLLM.

### Health Check
```bash
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

## Files

| File | Purpose |
|------|---------|
| `deployment.yaml` | vLLM deployment with Qwen3-8B-AWQ (ML mode) |
| `deployment-r1.yaml` | vLLM deployment with DeepSeek-R1 (R1 mode) |
| `service.yaml` | ClusterIP service on port 8000 |
| `ingress.yaml` | IngressRoute + TLS certificate |
| `pvc.yaml` | PVC for model cache (optional, using hostPath) |
| `pdb.yaml` | PodDisruptionBudget for graceful drain |
| `fallback-config.yaml` | ConfigMap with fallback endpoints for n8n |

## Story Reference

- **Epic 25:** Document Processing Pipeline Upgrade
- **Story 25.1:** Upgrade vLLM to Support Qwen3
- **Requirements:** FR203, FR204, NFR107, NFR110, NFR115, NFR116
- **Previous:** Epic 12 (GPU/ML Platform), Epic 20 (DeepSeek-R1)
