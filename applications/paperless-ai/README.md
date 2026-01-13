# Paperless-AI Integration

Story: 12.10 - Configure vLLM GPU Integration for Paperless-AI
Epic: 12 - GPU/ML Inference Platform

## Overview

Paperless-AI (clusterzx/paperless-ai) provides AI-powered document classification for Paperless-ngx. Features include:
- **Web-based configuration UI** - No YAML editing needed
- **RAG Document Chat** - Ask natural language questions about documents
- **Smart Classification** - Auto-populate title, tags, correspondent, document type
- **Multi-model Support** - Ollama, OpenAI, Azure, vLLM (custom OpenAI-compatible)

## Architecture

```
+---------------------------------------------------------------------+
|                    docs namespace                                    |
+---------------------------------------------------------------------+
|  +------------------------+      +-----------------------------+     |
|  |  Paperless-AI          |----> |  Paperless-ngx              |     |
|  |  (clusterzx)           |      |  (Document Management)      |     |
|  |  - Web UI (port 3000)  |      +-----------------------------+     |
|  |  - RAG Python Service  |                                          |
|  |  - ChromaDB (vectors)  |                                          |
|  +----------+-------------+                                          |
|             |                                                        |
+-------------+--------------------------------------------------------+
              |
              | OpenAI-compatible API
              v
+---------------------------------------------------------------------+
|                    ml namespace                                      |
+---------------------------------------------------------------------+
|  +------------------------+                                          |
|  |  vLLM                  |  Qwen/Qwen2.5-7B-Instruct-AWQ            |
|  |  (GPU Inference)       |  RTX 3060 12GB on k3s-gpu-worker         |
|  +------------------------+                                          |
+---------------------------------------------------------------------+
```

## Components

| Resource | Type | Description |
|----------|------|-------------|
| `paperless-ai` | Deployment | Main application pod |
| `paperless-ai-svc` | Service | ClusterIP service on port 3000 |
| `paperless-ai-data` | PVC | Persistent storage for config + RAG index |
| `paperless-ai-config` | ConfigMap | Connection settings |
| `paperless-ai-secrets` | Secret | Paperless API token |
| `paperless-ai-tls` | Certificate | TLS certificate for ingress |
| `paperless-ai` | IngressRoute | Traefik ingress for web UI |

## Access

| Interface | URL |
|-----------|-----|
| Web UI | https://paperless-ai.home.jetzinger.com/dashboard |
| RAG Chat | https://paperless-ai.home.jetzinger.com/rag |
| Configuration | https://paperless-ai.home.jetzinger.com/settings |

## Configuration

Configuration is primarily done via the web UI at `/settings`. Initial setup uses environment variables from the ConfigMap.

### Key Environment Variables

| Variable | Value | Description |
|----------|-------|-------------|
| `PAPERLESS_API_URL` | `http://paperless-paperless-ngx.docs.svc.cluster.local:8000/api` | Paperless API endpoint |
| `PAPERLESS_URL` | `http://paperless-paperless-ngx.docs.svc.cluster.local:8000` | Paperless base URL (for RAG) |
| `AI_PROVIDER` | `custom` | AI backend (custom = OpenAI-compatible API) |
| `CUSTOM_BASE_URL` | `http://vllm-api.ml.svc.cluster.local:8000/v1` | vLLM OpenAI-compatible API |
| `LLM_MODEL` | `Qwen/Qwen2.5-7B-Instruct-AWQ` | GPU-accelerated model |
| `SCAN_INTERVAL` | `*/30 * * * *` | Cron schedule for document scanning |
| `TAGS` | `pre-process` | Tag filter for document processing |

## Features

### Document Classification
Documents tagged with "pre-process" are automatically analyzed and classified with:
- Meaningful title based on content
- Relevant tags (up to 4)
- Correspondent identification
- Document type categorization

### RAG Document Chat
The `/rag` interface provides semantic search across all documents:
- ChromaDB vector storage for embeddings
- BM25 + cross-encoder reranking
- Natural language questions about document content

## Deployment

```bash
# Apply all manifests
kubectl apply -f applications/paperless-ai/

# Check status
kubectl get pods -n docs -l app.kubernetes.io/name=paperless-ai
kubectl logs -n docs -l app.kubernetes.io/name=paperless-ai

# Access web UI (requires DNS rewrite for *.home.jetzinger.com)
open https://paperless-ai.home.jetzinger.com/dashboard
```

## RAG Indexing

RAG indexing runs automatically but can be triggered manually:

```bash
# Check indexing status
kubectl exec -n docs deploy/paperless-ai -- curl -s http://localhost:8000/indexing/status

# Start indexing
kubectl exec -n docs deploy/paperless-ai -- curl -s -X POST -H "Content-Type: application/json" -d '{}' http://localhost:8000/indexing/start

# Search documents
kubectl exec -n docs deploy/paperless-ai -- curl -s -X POST -H "Content-Type: application/json" \
  -d '{"query": "What receipts do I have?"}' http://localhost:8000/search
```

## API Token Regeneration

If you need to regenerate the Paperless API token:

```bash
# Generate new token
kubectl exec -n docs deployment/paperless-paperless-ngx -- \
  python /usr/src/paperless/src/manage.py drf_create_token tjetzinger -r

# Update secret
kubectl create secret generic paperless-ai-secrets -n docs \
  --from-literal=PAPERLESS_API_TOKEN=<new-token> \
  --dry-run=client -o yaml | kubectl apply -f -

# Restart Paperless-AI
kubectl rollout restart deployment/paperless-ai -n docs
```

## Performance Notes

- **Model:** Qwen/Qwen2.5-7B-Instruct-AWQ (4-bit quantized, ~5GB VRAM)
- **Inference:** GPU-accelerated on k3s-gpu-worker (RTX 3060 12GB)
- **Classification Time:** ~1.6 seconds per document (GPU inference)
- **Throughput:** ~33 tokens/second
- **RAG Search:** <1 second (vector search + reranking)

**Performance Comparison:**
| Backend | Model | Classification Time | Improvement |
|---------|-------|--------------------:|------------:|
| Ollama (CPU) | qwen2.5:14b | ~13 minutes | baseline |
| vLLM (GPU) | Qwen2.5-7B-AWQ | ~1.6 seconds | **500x faster** |

## Troubleshooting

### vLLM Connection Issues
If classification fails:
1. Check vLLM pod is running: `kubectl get pods -n ml -l app=vllm-server`
2. Verify API connectivity: `kubectl exec -n docs deploy/paperless-ai -- curl -s http://vllm-api.ml.svc.cluster.local:8000/v1/models`
3. Check vLLM logs: `kubectl logs -n ml deploy/vllm-server`

### RAG "API configuration missing"
1. Ensure `PAPERLESS_URL` (without /api suffix) is in .env
2. Trigger indexing manually via API
3. Check Python RAG service logs

### Classification Slow or Failing
1. Verify GPU is available: `kubectl exec -n ml deploy/vllm-server -- nvidia-smi`
2. Check vLLM health: `kubectl exec -n docs deploy/paperless-ai -- curl -s http://vllm-api.ml.svc.cluster.local:8000/health`
3. Monitor GPU memory: model should use ~5GB of 12GB VRAM

## References

- [clusterzx/paperless-ai GitHub](https://github.com/clusterzx/paperless-ai)
- [Docker Hub](https://hub.docker.com/r/clusterzx/paperless-ai)
- [Wiki](https://github.com/clusterzx/paperless-ai/wiki)
- [vLLM Documentation](https://docs.vllm.ai/)
- [vLLM OpenAI API](https://docs.vllm.ai/en/stable/serving/openai_compatible_server.html)
- [Paperless-ngx API](https://docs.paperless-ngx.com/api/)
