# Open-WebUI

ChatGPT-like web interface for LLM models via LiteLLM.

## Overview

Open-WebUI provides a polished chat interface similar to ChatGPT, connected to our LiteLLM proxy for unified model access.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  User Browser                                                   │
│  https://chat.home.jetzinger.com                               │
└─────────────────────┬───────────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────────┐
│  Traefik Ingress (Story 17.3)                                   │
└─────────────────────┬───────────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────────┐
│  Open-WebUI (apps namespace)                                    │
│  ├── Web Interface                                              │
│  ├── Chat History (SQLite on NFS)                              │
│  └── OpenAI-compatible API client                               │
└─────────────────────┬───────────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────────┐
│  LiteLLM Proxy (ml namespace)                                   │
│  ├── vLLM (GPU - local)                                        │
│  ├── Ollama (CPU - fallback)                                   │
│  └── External providers (Groq, Google, Mistral)                │
└─────────────────────────────────────────────────────────────────┘
```

## Deployment

### Prerequisites

- Kubernetes cluster with `apps` namespace
- NFS storage class (`nfs-client`)
- LiteLLM running in `ml` namespace (for Story 17.2)

### Install

```bash
# Add Open-WebUI Helm repo
helm repo add open-webui https://helm.openwebui.com/
helm repo update

# Deploy Open-WebUI
helm upgrade --install open-webui open-webui/open-webui \
  -f values-homelab.yaml \
  -n apps
```

### Verify

```bash
# Check pods
kubectl get pods -n apps -l app.kubernetes.io/name=open-webui

# Check PVC
kubectl get pvc -n apps

# Port-forward for testing
kubectl port-forward -n apps svc/open-webui 8080:80
# Access: http://localhost:8080
```

## Configuration

### Persistence

Chat history stored on NFS at `/app/backend/data`:
- SQLite database for conversations
- User settings and preferences
- Uploaded files

### LiteLLM Integration (Story 17.2)

Open-WebUI connects to LiteLLM for unified model access:

```yaml
extraEnvVars:
  - name: OPENAI_API_BASE_URL
    value: "http://litellm.ml.svc.cluster.local:4000/v1"
  - name: OPENAI_API_KEY
    valueFrom:
      secretKeyRef:
        name: open-webui-secrets
        key: OPENAI_API_KEY
```

**Available Models via LiteLLM:**

| Model | Type | Description |
|-------|------|-------------|
| `vllm-qwen` | Fallback Primary | Qwen2.5-7B on GPU (fast) |
| `ollama-qwen` | Fallback Secondary | Qwen2.5:3b on CPU |
| `openai-gpt4o` | Fallback Tertiary | GPT-4o-mini (cloud) |
| `groq/llama-3.3-70b-versatile` | Parallel | Groq fast inference |
| `groq/mixtral-8x7b-32768` | Parallel | MoE model, 32k context |
| `gemini/gemini-2.0-flash` | Parallel | Google AI fast |
| `gemini/gemini-2.5-flash` | Parallel | Google AI latest |
| `mistral/mistral-small-latest` | Parallel | European provider |

**Fallback Chain:** vLLM (GPU) → Ollama (CPU) → OpenAI (cloud)

When requesting `vllm-qwen`, LiteLLM automatically falls back to `ollama-qwen` if GPU unavailable, then to `openai-gpt4o` as last resort.

### Ingress (Story 17.3)

HTTPS access via `chat.home.jetzinger.com`:

```bash
# Apply ingress resources
kubectl apply -f ingressroute.yaml

# Verify certificate
kubectl get certificate -n apps open-webui-tls

# Verify ingress routes
kubectl get ingressroute -n apps | grep open-webui
```

**Ingress Components:**
- Certificate: `open-webui-tls` (Let's Encrypt via cert-manager)
- IngressRoute: `open-webui-ingress` (HTTPS on websecure entrypoint)
- HTTP Redirect: `open-webui-ingress-redirect` (HTTP to HTTPS)

**Access:**
- URL: `https://chat.home.jetzinger.com`
- HTTP automatically redirects to HTTPS (308)
- Valid TLS certificate from Let's Encrypt

## Stories

| Story | Description | Status |
|-------|-------------|--------|
| 17.1 | Deploy with persistent storage | Done |
| 17.2 | Configure LiteLLM backend | Done |
| 17.3 | Configure HTTPS ingress | Done |

## Requirements

- FR126: Deployed in `apps` namespace with persistent storage
- FR127: LiteLLM backend integration (Story 17.2)
- FR128: HTTPS ingress access (Story 17.3)
- FR129: Model switching support (Story 17.2)
- NFR75: Page load < 3 seconds
- NFR76: Chat history survives pod restarts
