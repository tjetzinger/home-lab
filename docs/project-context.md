---
project_name: 'home-lab'
user_name: 'Tom'
date: '2026-02-13'
sections_completed: ['technology_stack', 'k8s_manifest_rules', 'ingress_tls', 'secret_management', 'storage_patterns', 'ml_inference', 'dns_gotchas', 'workflow_rules', 'namespace_boundaries', 'anti_patterns']
status: 'complete'
rule_count: 42
optimized_for_llm: true
---

# Project Context for AI Agents

_Critical rules and patterns for implementing Kubernetes resources in the home-lab cluster. Focus on unobvious details that agents might miss._

---

## Technology Stack & Versions

| Component | Version/Tool | Notes |
|-----------|-------------|-------|
| Kubernetes | K3s (embedded etcd) | NOT full k8s - some APIs differ |
| Ingress | Traefik (CRD-based IngressRoute) | NOT standard Ingress resource |
| TLS | cert-manager + Let's Encrypt prod | ClusterIssuer: `letsencrypt-prod` |
| Load Balancer | MetalLB | Bare metal L2 mode |
| Storage | nfs-subdir-external-provisioner | StorageClass: `nfs-client` (default) |
| Local Storage | Rancher local-path | For node-local PVCs (e.g., openclaw) |
| Monitoring | kube-prometheus-stack + Loki | Namespace: `monitoring` |
| Database | PostgreSQL (Bitnami Helm) | Namespace: `data` |
| GPU Inference | vLLM v0.5.5 → v0.10.2+ (Epic 25) | Qwen3-8B-AWQ on RTX 3060 |
| CPU Inference | Ollama | qwen3:4b on k3s-worker-02 |
| Inference Proxy | LiteLLM | Three-tier fallback: vLLM → Ollama → OpenAI |
| VPN | Tailscale | All cluster access via VPN only |
| GPU Operator | NVIDIA GPU Operator | On k3s-gpu-worker only |

## Critical Implementation Rules

### Kubernetes Manifest Conventions

Every YAML manifest MUST include a comment header block:
```yaml
# {App Name} {Resource Type} for home-lab
# Namespace: {namespace}
#
# Story: {story_id} - {story_title}
# Epic: {epic_number} - {epic_title}
#
# FRs:
# - {FR_ID}: {description}
#
# NFRs:
# - {NFR_ID}: {description}
```

All resources MUST include Kubernetes recommended labels:
```yaml
labels:
  app.kubernetes.io/name: {app}
  app.kubernetes.io/instance: {app}-{component}
  app.kubernetes.io/part-of: home-lab
  app.kubernetes.io/component: {component}
  app.kubernetes.io/managed-by: helm  # or kubectl
```

- Resource naming: `{app}-{component}` (e.g., `vllm-server`, `litellm-config`)
- Multi-document YAML: Use `---` separator, group related resources in one file
- Deployments using GPU: Set `strategy.type: Recreate` (exclusive GPU access)

### IngressRoute Pattern (NOT standard Ingress)

Traefik uses CRD-based IngressRoute, NOT standard `networking.k8s.io/v1 Ingress`. Every exposed service needs 3 resources in a single file:

1. **Certificate** (`cert-manager.io/v1/Certificate`)
2. **HTTPS IngressRoute** (`traefik.io/v1alpha1/IngressRoute`, entryPoint: `websecure`)
3. **HTTP→HTTPS redirect** (`traefik.io/v1alpha1/IngressRoute`, entryPoint: `web`)

Domain pattern: `{service}.home.jetzinger.com`

Critical: The redirect IngressRoute needs a middleware reference:
```yaml
middlewares:
  - name: https-redirect
    namespace: {namespace}  # Must match the namespace
```

### Secret Management

- **NEVER commit secrets to git** — `.gitignore` blocks `*-secrets.yaml`, `*-secret.yaml`, `secrets/`
- Secrets directory: `secrets/` (gitignored) with `TEMPLATE.yaml` as reference
- Pattern: Raw K8s `Secret` with `stringData` (not base64-encoded `data`)
- Secret naming: `{app}-secrets` (e.g., `litellm-secrets`, `paperless-secrets`)
- API keys: Use `kubectl patch secret` to update without committing to git
- Helm secrets: Separate `*-secrets.yaml` files merged via `-f` flag

### Storage Patterns

- **NFS** (`nfs-client` StorageClass): Default for most workloads. PVCs dynamically provisioned from Synology DS920+
- **local-path** (Rancher): For node-local workloads requiring low latency (e.g., openclaw on k3s-worker-01)
- **hostPath**: Only for GPU model cache (`/var/lib/vllm/huggingface`) — NOT for general use
- **emptyDir with Memory medium**: For `/dev/shm` in GPU pods (vLLM needs shared memory)
- Always specify `resources.requests.storage` in PVCs

### ML Inference Stack Rules

**LiteLLM model aliasing** — Consumers MUST use LiteLLM aliases, NEVER direct model paths:
- Request `vllm-qwen` → auto-routes to best available tier
- Request `vllm-r1` → DeepSeek-R1 reasoning model (GPU only)
- NEVER request `openai/Qwen/Qwen3-8B-AWQ` directly

**LiteLLM endpoint**: `http://litellm.ml.svc.cluster.local:4000/v1` — all apps connect here, not to vLLM/Ollama directly

**GPU mode switching** on k3s-gpu-worker:
```bash
gpu-mode ml      # Qwen3-8B-AWQ (default at boot)
gpu-mode r1      # DeepSeek-R1 7B (reasoning)
gpu-mode gaming   # vLLM scaled to 0, GPU free
gpu-mode status   # Show current mode
```
- ML and R1 modes are mutually exclusive (12GB VRAM limit)
- Gaming mode: vLLM replicas set to 0, LiteLLM auto-fails over to Ollama

**Fallback chain configuration** in LiteLLM:
```yaml
fallbacks: [{"vllm-qwen": ["ollama-qwen"]}, {"ollama-qwen": ["openai-gpt4o"]}]
```

### DNS Gotchas

**`*.jetzinger.com` wildcard DNS interception:**
- Node `resolv.conf` adds `jetzinger.com` to pod search domains
- With K8s default `ndots:5`, short hostnames try appending search domains first
- `registry-1.docker.io.jetzinger.com` matches wildcard → resolves to wrong IP (192.168.2.2)
- **Fix for DinD/external DNS containers**: Use `dnsPolicy: None` with explicit DNS config excluding `jetzinger.com` from search domains

**CoreDNS local records:**
- Add entries to `coredns` ConfigMap `NodeHosts` data
- Works with `reload 15s` — auto-reloads without pod restart
- K3s manages NodeHosts via objectset annotations

### Development Workflow Rules

- **Helm deployments**: Always use `values-homelab.yaml` — NEVER use inline `--set` flags in production
- **Helm install pattern**: `helm upgrade --install {name} {chart} -f values-homelab.yaml -n {namespace}`
- **Raw manifests**: `kubectl apply -f {file}.yaml`
- **Commit messages**: `<type>: <description>` (types: feat, fix, refactor, docs, test, chore, perf, ci)
- **ADRs**: `docs/adrs/ADR-{NNN}-{short-title}.md` for all architectural decisions
- **Database changes**: Always work with migration files
- **Git is single source of truth**: All manifests and Helm values version controlled

### Namespace Boundaries

| Namespace | Purpose | Key Services |
|-----------|---------|-------------|
| `kube-system` | K3s core | Traefik, CoreDNS |
| `infra` | Infrastructure | MetalLB, cert-manager |
| `monitoring` | Observability | Prometheus, Grafana, Loki, Alertmanager |
| `data` | Stateful data | PostgreSQL |
| `apps` | Applications | n8n, Open-WebUI, OpenClaw |
| `ml` | AI/ML inference | vLLM, Ollama, LiteLLM |
| `docs` | Document mgmt | Paperless-ngx, Paperless-GPT, Docling, Tika, Gotenberg, Stirling-PDF |
| `dev` | Development | Nginx proxy, dev containers |

NEVER deploy cross-domain resources into the wrong namespace.

### Critical Anti-Patterns

- **NEVER use standard `Ingress` resource** — Traefik uses `IngressRoute` CRD
- **NEVER hardcode model paths** in app configs — always go through LiteLLM aliases
- **NEVER use `--set` in Helm** — put all values in `values-homelab.yaml`
- **NEVER commit secrets** — use `secrets/` directory (gitignored) or `kubectl patch`
- **NEVER use `hostPath` for general storage** — use NFS PVCs or local-path StorageClass
- **NEVER skip FR/NFR traceability** in manifest comment headers
- **NEVER assume GPU is available** — always design for Ollama CPU fallback
- **NEVER expose services without TLS** — all ingress uses Let's Encrypt certs
- **NEVER use public IP exposure** — all access via Tailscale VPN
- **NEVER create DinD containers without `dnsPolicy: None`** — wildcard DNS interception will break image pulls

---

## Usage Guidelines

**For AI Agents:**

- Read this file before implementing any Kubernetes resources
- Follow ALL rules exactly as documented
- When in doubt, prefer the more restrictive option
- Reference `docs/planning-artifacts/architecture.md` for detailed architectural decisions
- Reference `docs/planning-artifacts/prd.md` for requirement details (FR/NFR)

**For Humans:**

- Keep this file lean and focused on agent needs
- Update when technology stack changes (model upgrades, new services)
- Review after each epic for outdated rules
- Remove rules that become obvious over time

Last Updated: 2026-02-13
