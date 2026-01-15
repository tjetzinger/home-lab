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

After Story 17.2, Open-WebUI will connect to LiteLLM:
```yaml
env:
  OPENAI_API_BASE_URL: "http://litellm.ml.svc.cluster.local:4000/v1"
  OPENAI_API_KEY: "sk-dummy"
```

### Ingress (Story 17.3)

HTTPS access via `chat.home.jetzinger.com` configured in Story 17.3.

## Stories

| Story | Description | Status |
|-------|-------------|--------|
| 17.1 | Deploy with persistent storage | Done |
| 17.2 | Configure LiteLLM backend | Backlog |
| 17.3 | Configure HTTPS ingress | Backlog |

## Requirements

- FR126: Deployed in `apps` namespace with persistent storage
- FR127: LiteLLM backend integration (Story 17.2)
- FR128: HTTPS ingress access (Story 17.3)
- FR129: Model switching support (Story 17.2)
- NFR75: Page load < 3 seconds
- NFR76: Chat history survives pod restarts
