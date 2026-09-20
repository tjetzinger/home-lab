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

Open-WebUI draws models from **two independent connections**:

1. **Direct Ollama Pro cloud** (`ollamaUrls: https://ollama.com`) — enumerates the account catalogue
   live, so new models appear and retired ones drop off with no config change.
2. **LiteLLM** (`OPENAI_API_BASE_URL`) — the role aliases, which add automatic failover.

**Visible models (curated, ADR-013):**

| Model | Source | Why it is in the picker |
|-------|--------|-------------------------|
| `kimi-k3` | Cloud | Most powerful available: 1M ctx, vision + thinking + tools |
| `deepseek-v4-pro:0813` | Cloud | Top-tier reasoning, 1M ctx |
| `glm-5.3` | Cloud | Current GLM flagship, 1M ctx |
| `mistral-large-3:675b` | Cloud | Best German of the catalogue, vision |
| `minimax-m3` | Cloud | Current MiniMax flagship, 512K ctx, vision |
| `kimi-k2.7-code` | Cloud | Dedicated coding model |
| `deepseek-v4.1-flash` | Cloud | Fast tier, 1M ctx, vision |
| `gpt-oss:120b` | Cloud | Open-weight option |
| `gemma4:31b` | Cloud | Small and quick, strong multilingual |
| `nemotron-3-ultra` | Cloud | NVIDIA flagship |
| `cloud-docs` | LiteLLM | `mistral-large-3` + automatic fallback chain |
| `cloud-fast` | LiteLLM | `deepseek-v4.1-flash` + automatic fallback chain |
| `cloud-smart` | LiteLLM | `kimi-k3` + automatic fallback chain (**default model**) |

**Fallback Chain (LiteLLM aliases only):** Ollama Pro cloud → vLLM (GPU) → Ollama (CPU).
`openai-gpt4o` is explicit-selection only and not in the auto-fallback chain.

## Model curation

The picker is curated down from ~33 entries to the 13 above. The keep/hide lists live in
[`model-curation.json`](model-curation.json) and are applied with:

```bash
./scripts/open-webui/apply-model-curation.sh            # apply
./scripts/open-webui/apply-model-curation.sh --dry-run  # preview
```

**Two upstream constraints make this a script rather than Helm values — read before editing:**

1. **`DEFAULT_MODELS` is a `ConfigVar` (PersistentConfig).** With `ENABLE_PERSISTENT_CONFIG=true` (the
   default) the value stored in the Open-WebUI DB wins and the Helm env var is **ignored**. Changing it
   in `values-homelab.yaml` and running `helm upgrade` has no effect on an existing install — it must
   also be set in Admin Panel → Settings → General.
2. **`OLLAMA_API_CONFIGS` / `OPENAI_API_CONFIGS` cannot be seeded from env vars.** The `model_ids`
   whitelist they expose is the right mechanism, but upstream never implemented JSON parsing for them
   ([issue #19017](https://github.com/open-webui/open-webui/issues/19017), closed as *not planned*).

Model visibility therefore lives in the Open-WebUI DB on the NFS PVC, not in Git. The script is both
the declarative substitute and the recovery path if that PVC is ever lost. It needs an admin API key in
`open-webui-secrets` as `OPENWEBUI_API_KEY` (generate in Open-WebUI → Settings → Account, then apply
with `kubectl patch` — never `kubectl apply` the secret file).

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
