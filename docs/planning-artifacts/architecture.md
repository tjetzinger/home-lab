---
stepsCompleted: [1, 2, 3, 4, 5, 6, 7, 8]
workflow_completed: true
completedAt: '2025-12-27'
lastModified: '2026-02-13'
updateReason: 'Phi4-mini pivot (2026-02-13): Pivoted Ollama CPU fallback from qwen3:4b to phi4-mini (Microsoft Phi-4-mini 3.8B) — Qwen3 thinking mode cannot be disabled on CPU (5+ min latency vs 60s target). Phi4-mini: no thinking overhead, 67.3% MMLU, ~2.5GB Q4. Previous: Document Processing Pipeline Upgrade (2026-02-13) — Paperless-GPT + Docling, vLLM Qwen3-8B-AWQ. FR192-FR208, NFR107-NFR116. ADR-012.'
inputDocuments:
  - 'docs/planning-artifacts/prd.md'
  - 'docs/planning-artifacts/product-brief-home-lab-2025-12-27.md'
  - 'docs/planning-artifacts/research/domain-k8s-platform-career-positioning-research-2025-12-27.md'
  - 'docs/analysis/brainstorming-session-2025-12-27.md'
  - 'docs/analysis/brainstorming-session-2026-02-12.md'
  - 'docs/adrs/ADR-012-document-processing-pipeline-upgrade.md'
workflowType: 'architecture'
project_name: 'home-lab'
user_name: 'Tom'
date: '2025-12-27'
---

# Architecture Decision Document

_This document builds collaboratively through step-by-step discovery. Sections are appended as we work through each architectural decision together._

## Project Context Analysis

### Requirements Overview

**Functional Requirements:** 208 FRs across 26 capability areas
- Cluster Operations (6): K3s lifecycle, node management
- Workload Management (7): Deployments, Helm, ingress
- Storage Management (5): NFS, PVCs, dynamic provisioning
- Networking & Ingress (5): Traefik, MetalLB, DNS, TLS
- Observability (7): Prometheus, Grafana, Alertmanager
- Data Services (5): PostgreSQL StatefulSet
- AI/ML Workloads (6): Ollama, vLLM, GPU scheduling, graceful degradation
- Development Proxy (3): Nginx to local dev servers
- Cluster Maintenance (5): Upgrades, backups, Velero
- Portfolio & Documentation (6): ADRs, GitHub, blog
- Document Management (26): Paperless-ngx, Redis, OCR, Tika, Gotenberg, Stirling-PDF, Email integration
- Dev Containers (5): VS Code SSH, Claude Code, git worktrees
- Gaming Platform (6): Steam, Proton, mode switching, fallback routing, default ML Mode at boot
- Multi-Subnet Networking (4): Tailscale mesh, Flannel over VPN
- LiteLLM Inference Proxy (6): Three-tier fallback, Prometheus metrics
- **Tailscale Subnet Router (3): Subnet route advertising, ACL configuration**
- **Synology NAS K3s Worker (3): VMM deployment, node labeling, taints**
- **Open-WebUI (4): LiteLLM backend, model switching, chat history**
- **Kubernetes Dashboard (4): Cluster visualization, authentication**
- **Gitea Self-Hosted Git (4): PostgreSQL backend, SSH auth, NFS storage**
- **DeepSeek-R1 Reasoning Mode (4): R1-Mode, model switching, LiteLLM integration**
- **LiteLLM External Providers (4): Groq, Google AI, Mistral free tiers as parallel model options**
- **Blog Article (3): Portfolio documentation, Epic 9 completion**
- **OpenClaw Personal AI Assistant (40): Gateway, Opus 4.5 + LiteLLM fallback, Telegram/WhatsApp/Discord, mcporter/Exa MCP tools, ElevenLabs voice, multi-agent, browser automation, Canvas/A2UI, ClawdHub skills, Loki/Blackbox observability, documentation**
- **Document Processing Pipeline Upgrade (17): Paperless-GPT, Docling server, vLLM Qwen3-8B-AWQ, Ollama phi4-mini (Microsoft 3.8B), Paperless-AI removal (supersedes FR87-89, FR104-111)**

**Non-Functional Requirements:** 116 NFRs
- Reliability: 95% uptime, 5-min recovery, automatic pod rescheduling
- Security: TLS 1.2+, Tailscale-only access, encrypted secrets
- Performance: 30s Ollama response, 5s dashboard load
- Operability: Prometheus metrics, 7-day logs, single-operator management
- Documentation: ADRs required, 2-hour setup README

### Scale & Complexity

- **Primary domain:** Infrastructure/DevOps (Kubernetes home lab)
- **Complexity level:** Medium
- **Estimated architectural components:** ~15 services/systems
- **User scale:** Single operator (Tom)
- **Data scale:** Low-medium (metrics TSDB, PostgreSQL)

### Technical Constraints & Dependencies

| Constraint | Specification |
|------------|---------------|
| Compute | Proxmox host: 53GB RAM, 12 cores available |
| Storage | Synology DS920+: 8.8TB NFS, external to cluster |
| Network | 192.168.2.0/24, Gigabit, Fritz!Box router |
| GPU | RTX 3060 eGPU (Phase 2, pending NUC) |
| Remote Access | Tailscale VPN required |
| Implementation | Weekend-based phased approach |

### Cross-Cutting Concerns

1. **Remote Access (Tailscale)** - All cluster access flows through VPN
2. **TLS/HTTPS** - cert-manager + Let's Encrypt for all endpoints
3. **Observability** - All components must expose Prometheus metrics
4. **Storage Dependency** - Stateful workloads depend on NFS availability
5. **Namespace Isolation** - 8 namespaces with distinct resource profiles
6. **Documentation** - All decisions captured as ADRs for portfolio

## Infrastructure Management Approach

### Primary Technology Domain

**Domain:** Infrastructure/DevOps (Kubernetes home lab)

Traditional "starter templates" don't apply. Instead, we evaluate infrastructure provisioning and configuration management approaches.

### Selected Approach: Manual + Helm (Learning-First)

**Rationale:** Maximum learning value aligned with project goals. Build understanding before adding abstraction layers.

| Component | Approach | Tool |
|-----------|----------|------|
| VM Provisioning | Manual via Proxmox UI | Proxmox VE |
| K3s Installation | curl script | k3s.io installer |
| Simple Deployments | Raw manifests | kubectl apply |
| Complex Apps | Helm charts | helm install |
| Automation | Shell scripts | bash |
| GitOps | Deferred to Phase 2 | ArgoCD/Flux |

### Infrastructure Decisions Established

**Provisioning:**
- VMs created manually in Proxmox (learning the UI, snapshot capability)
- Static IPs configured at OS level
- SSH access enabled for remote management

**Kubernetes Management:**
- kubectl for direct cluster interaction
- Helm for packaged applications (Prometheus, Grafana, etc.)
- Raw YAML manifests for custom deployments
- Namespace-based organization

**Configuration Storage:**
- All manifests stored in Git repository
- Helm values files version controlled
- Shell scripts for repeatable operations

**Future Enhancement Path:**
- Phase 2: Add Ansible for node configuration
- Phase 2: Implement GitOps with ArgoCD
- Phase 3: Consider Terraform for Proxmox automation

## Core Architectural Decisions

### Decision Priority Analysis

**Critical Decisions (Block Implementation):**
- Storage provisioning (NFS) - Required for StatefulSets
- Ingress + TLS (Traefik + cert-manager) - Required for HTTPS access
- Observability (kube-prometheus-stack) - Required for NFR compliance

**Important Decisions (Shape Architecture):**
- PostgreSQL deployment approach
- Ollama deployment approach
- Log aggregation strategy

**Deferred Decisions (Phase 2+):**
- GitOps tooling (ArgoCD vs Flux)
- Sealed Secrets for GitOps
- Velero for full backup/restore
- vLLM deployment

### Storage Architecture

| Decision | Choice | Rationale |
|----------|--------|-----------|
| NFS Provisioner | nfs-subdir-external-provisioner | Simple, Helm-based, dynamic PVC provisioning |
| StorageClass | nfs-client (default) | Dynamic provisioning from Synology |
| Reclaim Policy | Delete | Clean up on PVC deletion |

### Observability Architecture

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Metrics Stack | kube-prometheus-stack | Full stack: Prometheus, Grafana, Alertmanager |
| Log Aggregation | Loki | Grafana-native, lightweight, integrates with stack |
| Dashboards | Included in stack | Pre-built K8s dashboards |
| Alerting | Alertmanager | Part of kube-prometheus-stack |

### Security Architecture

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Secrets Management | Native K8s secrets | Simple, K3s encrypts at rest, sufficient for MVP |
| TLS Certificates | Let's Encrypt Production | Real certs via cert-manager |
| Cluster Access | Tailscale only | No public API exposure |
| RBAC | Cluster-admin (single user) | Solo operator, full access |

### Data Architecture

| Decision | Choice | Rationale |
|----------|--------|-----------|
| PostgreSQL | Bitnami Helm chart | Production-ready, metrics included |
| Persistence | NFS-backed PVC | Synology provides redundancy |
| Backup | pg_dump to NFS | Simple, scriptable |

### AI/ML Architecture

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Primary GPU LLM** | **vLLM v0.10.2+ with Qwen3-8B-AWQ** | **FR203-204: OpenAI-compatible API, optimized GPU inference, 90% classification accuracy** |
| **GPU Worker** | **Intel NUC + RTX 3060 12GB eGPU** | **FR71: Hot-pluggable GPU worker via Tailscale** |
| **GPU Networking** | **Dual-stack: 192.168.0.x (local) + Tailscale (K3s)** | **FR71, FR74: Hot-plug capability, cross-subnet support** |
| **VRAM Usage** | **~5-6GB (Qwen3-8B-AWQ quantized)** | **Leaves 6GB headroom for KV cache; gaming requires mode switch** |
| **Graceful Degradation** | **vLLM GPU → Ollama CPU → OpenAI cloud (three-tier via LiteLLM)** | **FR114: Automatic failover chain** |
| **Ollama Role** | **CPU fallback tier (phi4-mini)** | **FR206: Always-on CPU inference on k3s-worker-02 (8GB RAM), 70% classification accuracy** |
| Model Storage | NFS PVC | Persist downloaded models |
| GPU Scheduling | NVIDIA GPU Operator | Automatic driver installation, GPU resource management |

**GPU Inference Strategy (Epic 25 — supersedes Story 12.10):**

```
┌─────────────────────────────────────────────────────────────┐
│  vLLM v0.10.2+ on GPU (k3s-gpu-worker): Qwen3-8B-AWQ      │
│  VRAM: ~5-6GB on RTX 3060 (12GB total)                     │
├─────────────────────────────────────────────────────────────┤
│  Primary Use Cases (GPU-accelerated):                       │
│  ├── Document classification (Paperless-GPT via LiteLLM)   │
│  ├── Chat inference (Open-WebUI via LiteLLM)               │
│  ├── General inference (n8n workflows)                      │
│  └── Complex reasoning tasks (thinking mode /think)        │
├─────────────────────────────────────────────────────────────┤
│  Why vLLM over Ollama for GPU:                             │
│  ├── OpenAI-compatible API (standard /v1/chat/completions) │
│  ├── Optimized GPU inference (PagedAttention)              │
│  ├── Better batching and throughput                        │
│  └── Required for AWQ quantization support                 │
├─────────────────────────────────────────────────────────────┤
│  Three-Tier Fallback (via LiteLLM):                        │
│  ├── Tier 1: vLLM GPU (30-50 tok/s, 90% accuracy)         │
│  ├── Tier 2: Ollama CPU phi4-mini (70% accuracy)           │
│  └── Tier 3: OpenAI gpt-4o-mini (cloud, pay-per-use)      │
└─────────────────────────────────────────────────────────────┘
```

**Qwen3-8B-AWQ Performance on vLLM:**
- **Speed:** ~30-50 tok/s on RTX 3060
- **Classification:** 90% accuracy (distillabs benchmarks)
- **JSON output:** ★★★★★ (reliable structured output, NFR110: 95%+)
- **Reasoning:** ★★★★★ (strong instruction following, ~85% IFEval strict)
- **Thinking mode:** Toggle `/think` for complex documents requiring deeper reasoning
- **Multilingual:** ★★★★★ (119 languages, significantly better German support than Qwen2.5's 29)

**GPU Worker Architecture:**
```
Intel NUC (192.168.0.x local network)
  └─ Tailscale VPN (stable IP for K3s)
      └─ K3s node join via Tailscale IP
          └─ vLLM v0.10.2+ Pod scheduled with GPU resource request
              └─ NVIDIA GPU Operator manages drivers/runtime
                  └─ Qwen3-8B-AWQ loaded (~5-6GB VRAM)
```

**Hot-Plug Workflow (FR74):**
1. GPU worker boots → Tailscale connects → K3s detects node
2. Operator uncordons node: `kubectl uncordon k3s-gpu-worker`
3. vLLM Pod schedules to GPU node (GPU resource request)
4. GPU worker shutdown → Node marked NotReady → LiteLLM auto-fails over to Ollama CPU

**Ollama (CPU Fallback Tier - k3s-worker-02):**
```
k3s-worker-02 (8GB RAM)
  └─ Ollama Pod (CPU inference)
      └─ phi4-mini (Q4, ~2.5GB RAM)
          ├── 70% classification accuracy
          ├── 119 language support
          └── Always-on when GPU unavailable
```

**Integration Patterns:**
- vLLM exposes OpenAI-compatible API at `http://vllm-api.ml.svc.cluster.local:8000/v1`
- All consumers connect via LiteLLM proxy at `http://litellm.ml.svc.cluster.local:4000/v1`
- LiteLLM model alias `vllm-qwen` → `openai/Qwen/Qwen3-8B-AWQ`
- LiteLLM model alias `ollama-qwen` → `ollama/phi4-mini`
- Ollama available at `http://ollama.ml.svc.cluster.local:11434`

### Dual-Use GPU Architecture (ML + Gaming)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **GPU Sharing Model** | **Exclusive Mode Switching** | **Qwen3-8B-AWQ uses ~5-6GB, gaming needs 6-10GB - no coexistence possible** |
| **Host Gaming** | **Steam + Proton on Ubuntu 22.04** | **FR95-96: Native host performance, Windows game compatibility via Proton** |
| **Mode Switching** | **Manual script with kubectl** | **FR97: Operator-controlled, explicit state transitions** |
| **GPU Detection** | **vLLM health check + n8n routing** | **FR94, NFR50: Detect GPU unavailability within 10 seconds** |
| **Fallback Strategy** | **Three-tier via LiteLLM (vLLM → Ollama → OpenAI)** | **FR114: Automatic failover when GPU unavailable** |

**VRAM Budget (Qwen3-8B-AWQ):**
```
RTX 3060: 12GB VRAM total
├── vLLM (Qwen3-8B-AWQ): ~5-6GB
├── KV Cache headroom: ~6GB
├── Gaming (any): 6-10GB → Always requires mode switch
└── Trade-off: Efficient VRAM usage, excellent quality
```

**Operational Modes:**

| Mode | GPU Owner | vLLM Status | Inference Path | Use Case |
|------|-----------|-------------|----------------|----------|
| **ML Mode** | K8s (vLLM) | Running on GPU | GPU-accelerated (30-50 tok/s) | Default, AI/ML workloads |
| **Gaming Mode** | Host (Steam) | Scaled to 0 | Ollama CPU fallback → OpenAI cloud | Any gaming session |

**Mode Switching Architecture:**
```
┌─────────────────────────────────────────────────────────────┐
│                Intel NUC (Ubuntu 22.04)                     │
├─────────────────────────────────────────────────────────────┤
│  Host OS Layer:                                             │
│  ├── Steam + Proton (native, FR95-96)                       │
│  ├── NVIDIA Driver 535+ (shared with K8s via GPU Operator)   │
│  ├── nvidia-drm.modeset=1 (PRIME support for eGPU)          │
│  └── Mode switching script: /usr/local/bin/gpu-mode         │
├─────────────────────────────────────────────────────────────┤
│  K8s Worker Layer:                                          │
│  ├── K3s agent (joins via Tailscale)                        │
│  ├── NVIDIA GPU Operator + Device Plugin                    │
│  └── vLLM v0.10.2+ pod with Qwen3-8B-AWQ (~5-6GB VRAM)     │
└─────────────────────────────────────────────────────────────┘
```

**Mode Switching Script (FR97-99):**
```bash
#!/bin/bash
# /usr/local/bin/gpu-mode

case "$1" in
  gaming)
    # Scale down vLLM, release VRAM for Steam
    kubectl scale deployment/vllm --replicas=0 -n ml
    echo "Gaming Mode: vLLM scaled to 0, GPU available for Steam"
    ;;
  ml)
    # Restore vLLM for ML workloads
    kubectl scale deployment/vllm --replicas=1 -n ml
    echo "ML Mode: vLLM restored, GPU dedicated to inference"
    ;;
  status)
    kubectl get deployment/vllm -n ml -o jsonpath='{.spec.replicas}'
    ;;
esac
```

**n8n Fallback Routing (FR94, NFR54 - Epic 13):**
```javascript
// n8n workflow: Check vLLM GPU availability before inference
const vllmHealth = await $http.get('http://vllm.ml.svc:8000/health');
if (vllmHealth.status !== 200) {
  // Fallback to OpenAI API when GPU unavailable
  return { endpoint: 'https://api.openai.com/v1', model: 'gpt-4o-mini', mode: 'cloud' };
}
return { endpoint: 'http://vllm.ml.svc:8000/v1', model: 'Qwen/Qwen3-8B-AWQ', mode: 'gpu' };
```

**NFR Compliance:**
- NFR50: vLLM health check fails within 10s when GPU unavailable
- NFR51: Gaming Mode activation <30s (kubectl scale + VRAM release)
- NFR52: Full 12GB VRAM available for 60+ FPS gaming at 1080p
- NFR53: ML Mode restoration <2min (pod startup + model load)
- NFR54: OpenAI fallback maintains inference capability during Gaming Mode
- NFR70: ML Mode auto-activates within 5 minutes of boot (after k3s agent ready)

**Default Boot Behavior (FR119, NFR70):**

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Boot Default** | **ML Mode** | **FR119: vLLM should be available by default for inference workloads** |
| **Activation Method** | **systemd service** | **Reliable, restarts on failure, integrates with boot sequence** |
| **Dependency** | **k3s-agent.service** | **Must wait for K8s API to be available before scaling** |
| **Timeout** | **5 minutes** | **NFR70: Allows time for k3s readiness after node boot** |

```
Boot Sequence:
┌──────────────────────────────────────────────────────────┐
│  k3s-gpu-worker boot                                     │
├──────────────────────────────────────────────────────────┤
│  1. systemd starts k3s-agent.service                     │
│  2. k3s agent joins cluster via Tailscale                │
│  3. gpu-mode-default.service waits for kubectl ready     │
│  4. Runs: gpu-mode ml → scales vLLM to 1                 │
│  5. vLLM pod starts, loads Qwen3-8B-AWQ (~60-90s)       │
│  6. ML Mode active, GPU inference available              │
└──────────────────────────────────────────────────────────┘

Manual Override (anytime):
  gpu-mode gaming  → Scales vLLM to 0, GPU free for Steam
  gpu-mode ml      → Restores vLLM (or reboot)
```

**systemd Unit (gpu-mode-default.service):**
```ini
[Unit]
Description=Set GPU to ML Mode at boot (FR119)
After=network-online.target k3s-agent.service
Requires=k3s-agent.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStartPre=/bin/bash -c 'for i in {1..60}; do kubectl get nodes &>/dev/null && exit 0; sleep 5; done; exit 1'
ExecStart=/usr/local/bin/gpu-mode ml
TimeoutStartSec=300

[Install]
WantedBy=multi-user.target
```

### LiteLLM Inference Proxy Architecture (Epic 14)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Inference Proxy** | **LiteLLM** | **FR113: Unified OpenAI-compatible endpoint, handles multi-backend routing** |
| **Primary Backend** | **vLLM (GPU)** | **FR114: Highest quality/speed when GPU available (30-50 tok/s, Qwen3-8B-AWQ)** |
| **First Fallback** | **Ollama (CPU)** | **FR114: On-premises fallback, <5s latency (NFR54), no API costs** |
| **Second Fallback** | **OpenAI API** | **FR114: Cloud fallback for guaranteed availability** |
| **API Key Storage** | **Kubernetes Secret** | **FR117: Secure storage for OpenAI API credentials** |
| **Observability** | **Prometheus metrics** | **FR118: Track routing decisions, fallback events, latencies** |

**Three-Tier Fallback Architecture:**
```
┌─────────────────────────────────────────────────────────────────┐
│  LiteLLM Proxy (ml namespace)                                   │
│  Endpoint: http://litellm.ml.svc.cluster.local:4000/v1          │
├─────────────────────────────────────────────────────────────────┤
│  Unified OpenAI-compatible API for all consumers:               │
│  ├── Paperless-GPT (document classification via Docling)        │
│  ├── Open-WebUI (chat interface)                                │
│  ├── OpenClaw (AI assistant fallback)                           │
│  └── n8n workflows (automation)                                 │
├─────────────────────────────────────────────────────────────────┤
│  Fallback Chain (automatic failover):                           │
│                                                                 │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐       │
│  │   Tier 1     │    │   Tier 2     │    │   Tier 3     │       │
│  │   vLLM       │───►│   Ollama     │───►│   OpenAI     │       │
│  │   (GPU)      │    │   (CPU)      │    │   (Cloud)    │       │
│  └──────────────┘    └──────────────┘    └──────────────┘       │
│  • 30-50 tok/s       • <60s classify      • gpt-4o-mini          │
│  • Qwen3-8B-AWQ     • phi4-mini           • 100% availability    │
│  • 90% accuracy      • 70% accuracy      • Pay-per-use          │
└─────────────────────────────────────────────────────────────────┘
```

**LiteLLM Configuration Pattern:**
```yaml
# applications/litellm/config.yaml
model_list:
  - model_name: "vllm-qwen"
    litellm_params:
      model: "openai/Qwen/Qwen3-8B-AWQ"
      api_base: "http://vllm-api.ml.svc.cluster.local:8000/v1"
      api_key: "not-needed"
    model_info:
      mode: "chat"

  - model_name: "vllm-qwen"  # Same name = fallback
    litellm_params:
      model: "ollama/phi4-mini"
      api_base: "http://ollama.ml.svc.cluster.local:11434"
    model_info:
      mode: "chat"

  - model_name: "vllm-qwen"  # Same name = fallback
    litellm_params:
      model: "gpt-4o-mini"
      api_key: "os.environ/OPENAI_API_KEY"
    model_info:
      mode: "chat"

router_settings:
  routing_strategy: "simple-shuffle"  # Try in order
  num_retries: 2
  timeout: 30
  fallbacks: [{"vllm-qwen": ["vllm-qwen"]}]

general_settings:
  master_key: "os.environ/LITELLM_MASTER_KEY"
```

**Service Integration Pattern:**
```
┌─────────────────────────────────────────────────────────────────┐
│  All consumers connect via LiteLLM (unified endpoint):          │
│                                                                 │
│  Paperless-GPT ──► LiteLLM ───┬──► vLLM (GPU)    [Primary]     │
│  Open-WebUI   ──►             ├──► Ollama (CPU)   [Fallback 1] │
│  OpenClaw     ──►             └──► OpenAI (Cloud) [Fallback 2] │
│  n8n          ──►                                               │
│                                                                 │
│  (Works in all modes with graceful degradation)                 │
└─────────────────────────────────────────────────────────────────┘
```

**Consumer Configuration (all use same pattern):**
```yaml
# Paperless-GPT:
LLM_PROVIDER: openai
OPENAI_API_BASE: http://litellm.ml.svc.cluster.local:4000/v1
LLM_MODEL: vllm-qwen

# Open-WebUI:
OPENAI_API_BASE_URL: http://litellm.ml.svc.cluster.local:4000/v1
# Default model: vllm-qwen
```

**Operational Behavior by Mode:**

| Mode | vLLM | Ollama | LiteLLM Routing | Performance |
|------|------|--------|-----------------|-------------|
| **ML Mode** | Running | Running | vLLM (Tier 1) | 30-50 tok/s, 90% accuracy |
| **Gaming Mode** | Scaled to 0 | Running | Ollama (Tier 2) | <60s classify, 70% accuracy |
| **Full Outage** | Down | Down | OpenAI (Tier 3) | Cloud, pay-per-use |

**NFR Compliance (LiteLLM):**
- NFR65: Failover detection <5s via health check polling
- NFR66: <100ms latency overhead during normal operation (proxy passthrough)
- NFR67: Paperless-GPT continues (degraded) during Gaming Mode via Ollama fallback
- NFR68: OpenAI only used when both local backends unavailable
- NFR69: Health endpoint responds <1s for K8s readiness probes

**Prometheus Metrics (FR118):**
```
litellm_requests_total{model="vllm",status="success"}
litellm_requests_total{model="ollama",status="fallback"}
litellm_requests_total{model="openai",status="fallback"}
litellm_latency_seconds{model="vllm",quantile="0.95"}
litellm_fallback_events_total{from="vllm",to="ollama"}
```

### Multi-Subnet GPU Worker Network Architecture

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Networking Solution** | **Solution A: Manual Tailscale on all K3s nodes** | **Stable, community-tested; avoids experimental --vpn-auth; compatible with embedded etcd (single server)** |
| **VPN Mesh** | **Tailscale (100.64.0.0/10 CGNAT)** | **Zero-config NAT traversal, WireGuard-based, already on Synology NAS** |
| **Flannel Interface** | **`--flannel-iface tailscale0`** | **Routes pod network (flannel VXLAN) over Tailscale mesh** |
| **Node IP Advertisement** | **`--node-external-ip $(tailscale ip -4)`** | **Nodes advertise Tailscale IPs for cross-subnet communication** |
| **MTU Configuration** | **1280 bytes** | **Prevents packet fragmentation with VXLAN over Tailscale** |

**Why Solution A (Not Native --vpn-auth):**
- K3s `--vpn-auth` is **experimental** and explicitly warns "embedded etcd not supported"
- Your cluster uses **embedded etcd** (migrated from SQLite via ADR-010)
- Single-server topology satisfies etcd constraint: "all server nodes must be reachable via private IPs"
- Solution A is community-tested with documented workarounds

**Network Topology:**
```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         Tailscale Mesh (100.64.0.0/10)                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐          │
│  │ k3s-master      │    │ k3s-worker-01   │    │ k3s-worker-02   │          │
│  │ 192.168.2.20    │    │ 192.168.2.21    │    │ 192.168.2.22    │          │
│  │ 100.x.x.a       │◄──►│ 100.x.x.b       │◄──►│ 100.x.x.c       │          │
│  │ (tailscale0)    │    │ (tailscale0)    │    │ (tailscale0)    │          │
│  └────────┬────────┘    └────────┬────────┘    └────────┬────────┘          │
│           │                      │                      │                   │
│           └──────────────────────┼──────────────────────┘                   │
│                                  │                                          │
│                    ┌─────────────┴─────────────┐                            │
│                    │                           │                            │
│  ┌─────────────────▼───┐              ┌────────▼────────┐                   │
│  │ Intel NUC (GPU)     │              │ Synology NAS    │                   │
│  │ 192.168.0.25        │              │ 192.168.2.x     │                   │
│  │ 100.x.x.d           │              │ 100.x.x.e       │                   │
│  │ (tailscale0)        │              │ (subnet router) │                   │
│  │ + RTX 3060 eGPU     │              │                 │                   │
│  └─────────────────────┘              └─────────────────┘                   │
│                                                                             │
│  Network 192.168.0.0/24              Network 192.168.2.0/24                 │
│  (Intel NUC location)                (K3s cluster + NAS)                    │
└─────────────────────────────────────────────────────────────────────────────┘
```

**K3s Configuration Changes:**

*On k3s-master (192.168.2.20):*
```bash
# /etc/rancher/k3s/config.yaml
flannel-iface: tailscale0
node-external-ip: <tailscale-100.x.x.a>
tls-san:
  - <tailscale-100.x.x.a>
  - 192.168.2.20
```

*On existing workers (k3s-worker-01, k3s-worker-02):*
```bash
# /etc/rancher/k3s/config.yaml
flannel-iface: tailscale0
node-external-ip: <tailscale-100.x.x.b>  # Each worker's Tailscale IP
```

*On Intel NUC (new GPU worker):*
```bash
# /etc/rancher/k3s/config.yaml
flannel-iface: tailscale0
node-external-ip: <tailscale-100.x.x.d>
```

**Environment Configuration (all nodes):**
```bash
# /etc/environment or systemd override
NO_PROXY=127.0.0.0/8,10.0.0.0/8,100.64.0.0/10,172.16.0.0/12,192.168.0.0/16,.local,localhost
```

**Implementation Sequence (Story 12.2):**
1. Install Tailscale on k3s-master, k3s-worker-01, k3s-worker-02
2. Note each node's Tailscale IP (`tailscale ip -4`)
3. Update K3s config on each node with `flannel-iface` and `node-external-ip`
4. Add `100.64.0.0/10` to NO_PROXY environment
5. Rolling restart: one node at a time to maintain cluster availability
6. Verify flannel connectivity: `kubectl get nodes -o wide` shows Tailscale IPs
7. Install Tailscale on Intel NUC (Story 12.1 completes first)
8. Join Intel NUC to cluster: `k3s agent --server https://<master-tailscale-ip>:6443`

**Operational Considerations:**

| Consideration | Mitigation |
|---------------|------------|
| Tailscale restart breaks flannel routes | Restart K3s service after Tailscale restart |
| MTU fragmentation over VXLAN | Configure MTU 1280 on tailscale0 interface |
| `kubectl logs` timeout | Ensure NO_PROXY includes `100.64.0.0/10` |
| Node IP changes on Tailscale reconnect | Tailscale IPs are stable (CGNAT allocation persists) |

**Rollback Plan:**
If Solution A causes issues, revert by:
1. Remove `flannel-iface` and `node-external-ip` from K3s configs
2. Restart K3s on all nodes
3. Intel NUC remains isolated (cannot join cluster from different subnet)

### Document Management Architecture (Paperless-ngx)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Deployment | Paperless-ngx Helm chart | Community chart, production-ready |
| Backend | Redis (bundled) | Required for task queue, simpler than external |
| Database | **PostgreSQL (existing cluster)** | **NFR29: Scales to 5,000+ docs; leverage existing PostgreSQL deployment** |
| Document Storage | NFS PVC | Documents persist on Synology, snapshot-protected |
| OCR | Tesseract (bundled) with German + English | **FR64: German and English language support for OCR** |
| Ingress | paperless.home.jetzinger.com | HTTPS via cert-manager |
| Scaling Target | 5,000+ documents | **NFR29: Performance requirement for document scaling** |

**Integration Pattern:**
- Redis runs as sidecar or separate pod in `docs` namespace
- **PostgreSQL connection:** Use existing cluster PostgreSQL service (host: `postgresql.data.svc.cluster.local`)
- Document consumption folder mounted from NFS
- Export folder for processed documents on NFS
- **OCR languages configured:** German (deu) + English (eng) in Tesseract config

**Performance Considerations:**
- PostgreSQL backend enables efficient metadata queries for 5,000+ documents (vs SQLite)
- NFS storage tested for document upload/retrieval within NFR30 requirement (3-second search)
- OCR processing queue managed by Redis for async processing

### Office Document Processing Architecture (Tika + Gotenberg)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Text Extraction | Apache Tika (`apache/tika:latest`) | FR81: Extracts text/metadata from Office docs (Word, Excel, PowerPoint, LibreOffice) |
| PDF Conversion | Gotenberg (`gotenberg/gotenberg:8.25`) | FR82: Converts Office docs to PDF for OCR processing |
| Deployment | Separate pods in `docs` namespace | Stateless services, independent scaling |
| Tika Port | 9998 | Default Tika server port |
| Gotenberg Port | 3000 | Default Gotenberg port |
| Gotenberg Flags | `--chromium-disable-javascript=true`, `--chromium-allow-list=file:///tmp/.*` | Security hardening |

**Paperless Integration:**
```yaml
env:
  PAPERLESS_TIKA_ENABLED: "1"
  PAPERLESS_TIKA_ENDPOINT: "http://tika:9998"
  PAPERLESS_TIKA_GOTENBERG_ENDPOINT: "http://gotenberg:3000"
```

**Supported Formats:**
- Microsoft Office: .docx, .xlsx, .pptx
- LibreOffice: .odt, .ods, .odp
- Legacy: .doc, .xls, .ppt

### PDF Editor Architecture (Stirling-PDF)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| PDF Tool | Stirling-PDF Full (`stirlingtools/stirling-pdf:latest`) | FR84-85: Split, merge, rotate, compress, OCR, watermark |
| Deployment | Helm chart (`stirling-pdf/stirling-pdf-chart`) | Official chart, production-ready |
| Namespace | `docs` | Co-locate with Paperless ecosystem |
| Ingress | `stirling.home.jetzinger.com` | FR86: HTTPS via cert-manager |
| Storage | None (stateless) | PDF processing is ephemeral |
| Resources | 1 CPU, 2GB RAM | Sufficient for single-user processing |

**Helm Installation:**
```bash
helm repo add stirling-pdf https://stirling-tools.github.io/Stirling-PDF-chart
helm install stirling-pdf stirling-pdf/stirling-pdf-chart -n docs
```

**Use Case:**
- Pre-process "messy" scans before Paperless import
- Split multi-document PDFs into individual files
- Merge related documents into single PDF

### AI Document Classification Architecture (Paperless-GPT + Docling)

_Supersedes previous Paperless-AI architecture (ADR-012, 2026-02-12)_

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **AI Connector** | **icereed/paperless-gpt** | **FR192: Native Docling OCR integration, customizable prompt templates, hOCR searchable PDFs, 5 LLM backends** |
| **OCR/Parsing** | **Docling server (Granite-Docling 258M VLM)** | **FR199-201: Layout-aware PDF parsing preserving tables, code blocks, equations, reading order** |
| **LLM (GPU)** | **Qwen3-8B-AWQ via vLLM** | **FR204, NFR108: 90% classification accuracy, 30-50 tok/s on GPU** |
| **LLM (CPU Fallback)** | **phi4-mini via Ollama** | **FR206, NFR109: 70% accuracy, fits in worker-02 8GB RAM without upgrade** |
| **LLM Routing** | **LiteLLM proxy** | **FR194: vLLM → Ollama → OpenAI three-tier fallback. Downstream apps unaffected by model swap** |
| **Prompt Config** | **Web UI (hot-reload)** | **FR196, NFR112: Prompt templates editable per document type without pod restart** |
| **Processing Modes** | **Manual review + auto processing** | **FR197: `paperless-gpt` tag for manual review, `paperless-gpt-auto` for automatic** |
| Deployment | Deployment in `docs` namespace | Replaces Paperless-AI (FR208) |
| Ingress | `paperless-gpt.home.jetzinger.com` | FR198: HTTPS via cert-manager |

**Two-Stage Document Processing Pipeline (ADR-012):**

```
┌─────────────────────────────────────────────────────────────────┐
│  Stage 1: Structure Extraction (Docling)                        │
│                                                                 │
│  Incoming PDF → Docling Server (Granite-Docling 258M, CPU)     │
│  ├── Layout-aware OCR via VLM pipeline                         │
│  ├── Table structure preserved                                  │
│  ├── Code blocks, equations extracted                           │
│  ├── Reading order maintained                                   │
│  └── Output: Structured markdown/JSON                          │
├─────────────────────────────────────────────────────────────────┤
│  Stage 2: Metadata Generation (LLM via LiteLLM)               │
│                                                                 │
│  Structured text → LiteLLM proxy → Qwen3 LLM                  │
│  ├── Title extraction                                           │
│  ├── Tag classification                                         │
│  ├── Correspondent identification                               │
│  ├── Document type assignment                                   │
│  └── Custom field population                                    │
├─────────────────────────────────────────────────────────────────┤
│  Results → Paperless-ngx API (metadata written back)           │
└─────────────────────────────────────────────────────────────────┘
```

**Key Insight:** Granite-Docling (258M) and Qwen3 serve complementary roles. Granite-Docling extracts document *structure*. Qwen3 *reasons* about the extracted content to generate metadata. Each model does what it's best at.

**Complete Data Flow:**
```
Incoming doc → Paperless-ngx
       |                              |
       | (Office docs)                | (stored PDF)
       v                              v
    Gotenberg → PDF              Paperless-GPT triggered (tag-based)
                                       |
                                       v
                            Docling server (Granite-Docling 258M, CPU)
                            → structured markdown/JSON
                                       |
                                       v
                            LiteLLM proxy
                            → vLLM Qwen3-8B-AWQ (GPU, if available)
                            → Ollama phi4-mini (CPU fallback)
                                       |
                                       v
                            Title, tags, correspondent, custom fields
                            → written back to Paperless-ngx API
```

**Docling Server Configuration:**
```yaml
# Deployment in docs namespace
env:
  DOCLING_OCR_PIPELINE: "vlm"  # Granite-Docling 258M VLM pipeline
# Resources: <1GB memory, CPU-only (NFR114)
# No GPU required (FR202)
```

**Paperless-GPT Configuration:**
```yaml
# Deployment environment variables
env:
  PAPERLESS_BASE_URL: "http://paperless-paperless-ngx.docs.svc.cluster.local:8000"
  PAPERLESS_API_TOKEN: "<from-secret>"
  OCR_PROVIDER: "docling"
  DOCLING_URL: "http://docling:8000"
  LLM_PROVIDER: "openai"
  LLM_MODEL: "vllm-qwen"
  OPENAI_API_BASE: "http://litellm.ml.svc.cluster.local:4000/v1"
  OPENAI_API_KEY: "<from-litellm-secret>"
```

**Auto-populated Fields (FR195):**
- Tags: Document category, year, source
- Correspondent: Sender/organization extracted from content
- Document Type: Invoice, contract, receipt, letter, etc.
- Custom Fields: Document-specific metadata

**LLM Quality by Tier:**

| Tier | Model | Accuracy | Speed | When Used |
|------|-------|----------|-------|-----------|
| GPU (vLLM) | Qwen3-8B-AWQ | 90% | 30-50 tok/s | GPU worker online (ML mode) |
| CPU (Ollama) | phi4-mini | 70% | ~4-6 tok/s | GPU off (gaming mode / worker down) |
| Cloud (OpenAI) | gpt-4o-mini | High | Fast | Both local backends unavailable |

**NFR Compliance:**
- NFR107: Document metadata generation <5s via GPU vLLM
- NFR108: 90% auto-tagging accuracy via GPU (Qwen3-8B-AWQ)
- NFR109: 70% auto-tagging accuracy via CPU fallback (phi4-mini)
- NFR110: Qwen3 produces valid structured output 95%+ of requests
- NFR111: CPU classification completes within 60 seconds
- NFR112: Prompt template changes take effect without pod restart
- NFR113: Docling extracts structured text within 30 seconds
- NFR114: Docling runs on CPU with <1GB memory

### Email Integration Architecture

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Private Email Access | Email Bridge (containerized) | FR90, FR93: Required for IMAP access to private email providers |
| Gmail Access | Direct IMAP with App Password | FR91: Native IMAP, no container needed |
| Bridge Deployment | StatefulSet in `docs` namespace | Persistent storage for credentials/cache |
| Bridge Storage | 1Gi NFS PVC | Store bridge login state |
| Polling Interval | 10 minutes | NFR48: Regular inbox checks |
| Credentials | Kubernetes Secrets | NFR49: Secure storage for email passwords |

**Email Bridge Architecture:**
```
Email Bridge (StatefulSet)
  ├─ Port 143: IMAP
  ├─ Port 25: SMTP
  └─ PVC: /root (credentials, config, cache)
```

**Initial Setup (one-time):**
```bash
# Interactive login required first time
kubectl exec -it email-bridge-0 -n docs -- /bin/sh
# Run bridge CLI for interactive login
# Note the generated bridge password for Paperless
```

**Paperless Mail Configuration:**
| Account | IMAP Host | Port | Security |
|---------|-----------|------|----------|
| Private Email | `email-bridge.docs.svc.cluster.local` | 143 | None |
| Gmail | `imap.gmail.com` | 993 | SSL/TLS |

**Email Rule Pattern:**
- Filter: Subject contains "Invoice", "Receipt", "Statement"
- Action: Import attachment, apply tag based on sender
- Folder: Move processed emails to "Paperless" folder

### Dev Containers Architecture

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Container Base | **Single base image: Node.js, Python, Claude Code CLI, git, kubectl, helm** | **FR67: Consistent tooling across all dev containers** |
| Access Method | SSH via Nginx proxy | Nginx already handles routing in `dev` namespace |
| Workspace Storage | **Hybrid: Git repos on NFS PVC (10GB), build artifacts on emptyDir** | **FR69: Persistent workspace data; emptyDir for fast builds** |
| Resource Limits | **2 CPU cores, 4GB RAM per container** | **FR68: Resource allocation; cluster supports 2-3 containers** |
| Provisioning | Kubernetes Deployment per container | Simple, declarative, easy to spin up/down |
| Git Worktree | Enabled in container | Multiple branches simultaneously |
| Tooling | VS Code Remote SSH + Claude Code | Standard remote dev workflow |
| NetworkPolicy | **Moderate isolation: Access cluster services, no cross-container communication** | **NFR33: Security isolation; allows testing against PostgreSQL/Ollama** |

**Integration Pattern:**
- Nginx proxy routes SSH traffic to dev container pods
- Each dev container is a Deployment with SSH server enabled
- ConfigMaps store SSH authorized_keys
- **Hybrid storage:**
  - `/workspace` → NFS PVC (10GB) - Git repos, source code, persistent files
  - `/tmp`, `/build`, `node_modules` → emptyDir - Fast I/O for builds, caching
- Git credentials via Kubernetes secrets
- **NetworkPolicy allows:**
  - Egress to `data` namespace (PostgreSQL)
  - Egress to `ml` namespace (Ollama, vLLM)
  - Egress to `apps` namespace (n8n)
  - **Blocks:** Cross-container communication within `dev` namespace

**Resource Capacity:**
- Cluster supports **2-3 dev containers** simultaneously (based on worker node capacity)
- k3s-worker-01: 8GB RAM → 1-2 containers
- k3s-worker-02: Similar capacity → 1 container

**Dev Container Lifecycle:**
```
Create: kubectl apply -f dev-container-{name}.yaml
Connect: VS Code → Remote SSH → nginx-proxy:port → container
Destroy: kubectl delete -f dev-container-{name}.yaml (workspace PVC persists)
```

### Tailscale Subnet Router Architecture

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Primary Router** | **k3s-master (192.168.2.0/24)** | **FR120: Expose main cluster subnet to Tailscale network** |
| **Secondary Router** | **k3s-gpu-worker (192.168.0.0/24)** | **FR121: Expose GPU worker subnet for cross-network access** |
| **ACL Management** | **Tailscale Admin Console** | **FR122: Centralized access control for subnet routes** |
| **Failover** | **Direct Tailscale per-node** | **NFR72: Individual node access survives router failure** |

**Subnet Route Configuration:**
```bash
# On k3s-master (192.168.2.20):
sudo tailscale up --advertise-routes=192.168.2.0/24 --accept-routes

# On k3s-gpu-worker (192.168.0.25):
sudo tailscale up --advertise-routes=192.168.0.0/24 --accept-routes
```

**Network Topology with Subnet Routing:**
```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Tailscale Network (External Access)                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Remote Device (laptop, phone)                                              │
│       │                                                                     │
│       ├──► k3s-master (subnet router) ──► 192.168.2.0/24                   │
│       │         └── Synology NAS, k3s-worker-01, k3s-worker-02              │
│       │                                                                     │
│       └──► k3s-gpu-worker (subnet router) ──► 192.168.0.0/24               │
│                 └── Intel NUC local network devices                         │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Tailscale ACL Configuration (FR122):**
```json
{
  "acls": [
    {
      "action": "accept",
      "src": ["tag:admin"],
      "dst": ["192.168.2.0/24:*", "192.168.0.0/24:*"]
    }
  ],
  "tagOwners": {
    "tag:admin": ["autogroup:admin"]
  }
}
```

**NFR Compliance:**
- NFR71: Routes advertised within 60 seconds via `tailscale up` at boot
- NFR72: Each node individually accessible via Tailscale even if subnet router fails

### Synology NAS K3s Worker Architecture

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Virtualization** | **Synology Virtual Machine Manager** | **FR123: Native hypervisor on DS920+, no additional software** |
| **VM Resources** | **2 vCPU, 4GB RAM** | **NFR73: Preserve NAS primary functions (file serving, Docker)** |
| **OS Image** | **Ubuntu 22.04 LTS** | **Consistent with existing K3s workers** |
| **Node Role** | **Lightweight workloads only** | **FR124-125: Labeled and tainted for specific scheduling** |
| **Storage** | **Local VM disk (20GB)** | **K3s binaries; workload data on NFS** |

**VM Specification:**
```
┌─────────────────────────────────────────────────────────────────┐
│  Synology DS920+ (Intel Celeron J4125, 20GB RAM)               │
├─────────────────────────────────────────────────────────────────┤
│  Host Services:                                                 │
│  ├── DSM (Synology OS)                                         │
│  ├── NFS Server (primary function)                             │
│  ├── Container Manager (Docker)                                │
│  └── Virtual Machine Manager                                   │
├─────────────────────────────────────────────────────────────────┤
│  K3s Worker VM:                                                │
│  ├── Name: k3s-nas-worker                                      │
│  ├── IP: 192.168.2.23 (static)                                 │
│  ├── vCPU: 2 cores                                             │
│  ├── RAM: 4GB                                                  │
│  ├── Disk: 20GB (thin provisioned)                             │
│  └── Network: vmbr0 (bridged to LAN)                           │
└─────────────────────────────────────────────────────────────────┘
```

**Node Labels and Taints (FR124-125):**
```yaml
# Node configuration after join
kubectl label node k3s-nas-worker \
  node.kubernetes.io/role=nas-worker \
  workload-type=lightweight

kubectl taint node k3s-nas-worker \
  nas-worker=true:NoSchedule
```

**Suitable Workloads:**
- Lightweight monitoring agents
- Log collectors (Promtail)
- Storage-adjacent services (NFS-related utilities)
- NOT suitable: CPU-intensive, memory-intensive, or GPU workloads

**NFR Compliance:**
- NFR73: 2 vCPU + 4GB leaves 2 cores + 15GB for NAS operations
- NFR74: K3s agent starts within 3 minutes; VM boot adds ~60 seconds

### Open-WebUI Architecture

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Deployment** | **Helm chart (open-webui/open-webui)** | **FR126: Official chart, production-ready** |
| **Namespace** | **`apps`** | **General application, not ML-specific** |
| **Backend** | **LiteLLM unified endpoint** | **FR127: Single API for all models (local + external)** |
| **Storage** | **NFS PVC (5GB)** | **FR126, NFR76: Persistent chat history** |
| **Ingress** | **chat.home.jetzinger.com** | **FR128: HTTPS via cert-manager** |

**Integration Architecture:**
```
┌─────────────────────────────────────────────────────────────────────────────┐
│  Open-WebUI (apps namespace)                                                │
│  Endpoint: https://chat.home.jetzinger.com                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  User Interface:                                                            │
│  ├── ChatGPT-like conversation UI                                          │
│  ├── Model selector dropdown (FR129)                                        │
│  ├── Chat history with search                                               │
│  └── Multi-user support (single user for home lab)                         │
│                                                                             │
│  Backend Connection:                                                        │
│  └── LiteLLM Proxy (http://litellm.ml.svc.cluster.local:4000/v1)           │
│       │                                                                     │
│       ├── Local Models:                                                     │
│       │   ├── vLLM: Qwen3-8B-AWQ (GPU, primary)                            │
│       │   ├── vLLM: deepseek-r1:14b (GPU, R1-Mode)                         │
│       │   └── Ollama: phi4-mini (CPU, fallback)                             │
│       │                                                                     │
│       └── External Providers:                                               │
│           ├── Groq: llama-3.3-70b-versatile (fast, free tier)              │
│           ├── Google: gemini-1.5-flash (free tier)                         │
│           └── Mistral: mistral-small (free tier)                           │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Helm Values:**
```yaml
# applications/open-webui/values-homelab.yaml
replicaCount: 1

env:
  OPENAI_API_BASE_URL: "http://litellm.ml.svc.cluster.local:4000/v1"
  OPENAI_API_KEY: "not-needed-for-litellm"
  WEBUI_AUTH: "false"  # Single user, Tailscale provides auth
  ENABLE_SIGNUP: "false"

persistence:
  enabled: true
  storageClass: "nfs-client"
  size: 5Gi

ingress:
  enabled: true
  className: traefik
  hosts:
    - host: chat.home.jetzinger.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: chat-tls
      hosts:
        - chat.home.jetzinger.com
```

**NFR Compliance:**
- NFR75: Open-WebUI loads within 3 seconds (lightweight frontend)
- NFR76: Chat history on NFS survives pod restarts

### Kubernetes Dashboard Architecture

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Dashboard** | **Official Kubernetes Dashboard v2.7+** | **FR130: Lightweight, official K8s project** |
| **Namespace** | **`infra`** | **Infrastructure tooling** |
| **Authentication** | **Bearer token + Tailscale** | **FR132: Token for K8s API, Tailscale for network access** |
| **Access Mode** | **Read-only ServiceAccount** | **FR133: View-only for safety** |
| **Ingress** | **dashboard.home.jetzinger.com** | **FR131: HTTPS via cert-manager** |

**Deployment Architecture:**
```
┌─────────────────────────────────────────────────────────────────────────────┐
│  Kubernetes Dashboard (infra namespace)                                     │
│  Endpoint: https://dashboard.home.jetzinger.com                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Components:                                                                │
│  ├── kubernetes-dashboard Deployment                                        │
│  ├── dashboard-metrics-scraper (optional)                                   │
│  └── ServiceAccount: dashboard-viewer (read-only)                          │
│                                                                             │
│  Access Flow:                                                               │
│  Tailscale VPN → Traefik Ingress → Dashboard → K8s API (via SA token)      │
│                                                                             │
│  Capabilities (FR133):                                                      │
│  ├── View all namespaces                                                    │
│  ├── List pods, deployments, services                                       │
│  ├── View logs (read-only)                                                  │
│  ├── View events and resource status                                        │
│  └── NO create/delete/edit operations                                       │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**ServiceAccount Configuration:**
```yaml
# Read-only ClusterRole binding
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: dashboard-viewer
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: view  # Built-in read-only role
subjects:
  - kind: ServiceAccount
    name: dashboard-viewer
    namespace: infra
```

**NFR Compliance:**
- NFR77: Dashboard loads within 5 seconds (lightweight UI)
- NFR78: Tailscale-only access enforced via network (no public ingress)

### Gitea Self-Hosted Git Architecture

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Deployment** | **Gitea Helm chart (gitea/gitea)** | **FR134: Official chart, production-ready** |
| **Namespace** | **`dev`** | **Development tooling** |
| **Database** | **PostgreSQL (existing cluster)** | **FR134: Leverage existing PostgreSQL deployment** |
| **Storage** | **NFS PVC (50GB)** | **FR136: Repositories persist on Synology** |
| **Authentication** | **SSH keys + local accounts** | **FR137: Single-user, SSH for git operations** |
| **Ingress** | **git.home.jetzinger.com** | **FR135: HTTPS for web UI** |
| **SSH Access** | **NodePort or LoadBalancer** | **Git SSH on port 22 or 2222** |

**Integration Architecture:**
```
┌─────────────────────────────────────────────────────────────────────────────┐
│  Gitea (dev namespace)                                                      │
│  Web: https://git.home.jetzinger.com                                       │
│  SSH: git@git.home.jetzinger.com:2222                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Components:                                                                │
│  ├── Gitea Server (StatefulSet)                                            │
│  │   ├── Web UI: Repository browsing, issues, PRs                          │
│  │   └── SSH Server: Git clone/push/pull                                   │
│  ├── PostgreSQL Connection                                                  │
│  │   └── Database: gitea @ postgresql.data.svc.cluster.local               │
│  └── NFS PVC: /data/git/repositories                                       │
│                                                                             │
│  Use Cases:                                                                 │
│  ├── Mirror external repos for offline access                               │
│  ├── Private repos not suitable for GitHub                                  │
│  ├── Local CI/CD integration (future)                                       │
│  └── Backup of critical repositories                                        │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Helm Values:**
```yaml
# applications/gitea/values-homelab.yaml
gitea:
  admin:
    username: tom
    email: tom@home.jetzinger.com

postgresql:
  enabled: false  # Use external PostgreSQL

database:
  builtIn:
    postgresql:
      enabled: false
  external:
    host: postgresql.data.svc.cluster.local
    port: 5432
    database: gitea
    user: gitea
    existingSecret: gitea-db-secret

persistence:
  enabled: true
  storageClass: "nfs-client"
  size: 50Gi

service:
  ssh:
    type: LoadBalancer  # Or NodePort
    port: 2222

ingress:
  enabled: true
  className: traefik
  hosts:
    - host: git.home.jetzinger.com
      paths:
        - path: /
          pathType: Prefix
```

**NFR Compliance:**
- NFR79: Git operations complete within 10 seconds (local network, NFS storage)
- NFR80: Web interface loads within 3 seconds

### DeepSeek-R1 14B Reasoning Mode Architecture

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Model** | **DeepSeek-R1 14B (distilled)** | **FR138: Reasoning-focused, fits 12GB VRAM** |
| **Deployment** | **vLLM on GPU worker** | **FR138: Same infrastructure as Qwen 2.5 14B** |
| **Mode Name** | **R1-Mode** | **FR139: Third GPU mode alongside ML-Mode and Gaming-Mode** |
| **Switching** | **gpu-mode script** | **FR140: Extend existing mode switching** |
| **LiteLLM** | **reasoning-tier model** | **FR141: Dedicated routing for reasoning tasks** |

**Three GPU Modes:**
```
┌─────────────────────────────────────────────────────────────────────────────┐
│  GPU Mode Switching (k3s-gpu-worker)                                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐                     │
│  │  ML-Mode    │    │  R1-Mode    │    │ Gaming-Mode │                     │
│  │  (default)  │    │  (reasoning)│    │  (Steam)    │                     │
│  ├─────────────┤    ├─────────────┤    ├─────────────┤                     │
│  │ Qwen 2.5 14B│    │ DeepSeek-R1 │    │ GPU to Host │                     │
│  │ ~8-9GB VRAM │    │ ~8-10GB VRAM│    │ vLLM off    │                     │
│  │ General use │    │ Complex     │    │ Full 12GB   │                     │
│  │ Fast (35t/s)│    │ reasoning   │    │ for games   │                     │
│  └─────────────┘    └─────────────┘    └─────────────┘                     │
│        │                  │                  │                              │
│        └──────────────────┼──────────────────┘                              │
│                           │                                                 │
│                    gpu-mode script                                          │
│                    /usr/local/bin/gpu-mode                                  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Extended gpu-mode Script (FR140):**
```bash
#!/bin/bash
# /usr/local/bin/gpu-mode

VLLM_DEPLOYMENT="vllm"
NAMESPACE="ml"

case "$1" in
  ml)
    # Default mode: Qwen3-8B-AWQ for general use
    kubectl set env deployment/$VLLM_DEPLOYMENT -n $NAMESPACE \
      MODEL_NAME="Qwen/Qwen3-8B-AWQ"
    kubectl scale deployment/$VLLM_DEPLOYMENT --replicas=1 -n $NAMESPACE
    echo "ML Mode: Qwen3-8B-AWQ loaded for general inference"
    ;;
  r1)
    # Reasoning mode: DeepSeek-R1 14B for complex tasks
    kubectl set env deployment/$VLLM_DEPLOYMENT -n $NAMESPACE \
      MODEL_NAME="deepseek-ai/DeepSeek-R1-Distill-Qwen-14B"
    kubectl scale deployment/$VLLM_DEPLOYMENT --replicas=1 -n $NAMESPACE
    echo "R1 Mode: DeepSeek-R1 14B loaded for reasoning tasks"
    ;;
  gaming)
    # Gaming mode: Release GPU for Steam
    kubectl scale deployment/$VLLM_DEPLOYMENT --replicas=0 -n $NAMESPACE
    echo "Gaming Mode: vLLM scaled to 0, GPU available for Steam"
    ;;
  status)
    REPLICAS=$(kubectl get deployment/$VLLM_DEPLOYMENT -n $NAMESPACE -o jsonpath='{.spec.replicas}')
    MODEL=$(kubectl get deployment/$VLLM_DEPLOYMENT -n $NAMESPACE -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="MODEL_NAME")].value}')
    echo "Replicas: $REPLICAS, Model: $MODEL"
    ;;
  *)
    echo "Usage: gpu-mode {ml|r1|gaming|status}"
    exit 1
    ;;
esac
```

**LiteLLM Configuration (FR141):**
```yaml
# Extended model_list for R1-Mode
model_list:
  - model_name: "vllm-qwen"  # General inference
    litellm_params:
      model: "openai/Qwen/Qwen3-8B-AWQ"
      api_base: "http://vllm-api.ml.svc.cluster.local:8000/v1"

  - model_name: "reasoning"  # Complex reasoning tasks
    litellm_params:
      model: "openai/deepseek-ai/DeepSeek-R1-Distill-Qwen-14B"
      api_base: "http://vllm-api.ml.svc.cluster.local:8000/v1"
```

**NFR Compliance:**
- NFR81: Model loading completes within 90 seconds (similar to Qwen3-8B-AWQ)
- NFR82: DeepSeek-R1 achieves 30+ tokens/second on RTX 3060

### LiteLLM External Providers Architecture

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Groq** | **llama-3.3-70b-versatile** | **FR142: Fast inference, generous free tier (6000 req/day), parallel model** |
| **Google AI** | **gemini-1.5-flash** | **FR143: Free tier, good for general tasks, parallel model** |
| **Mistral** | **mistral-small-latest** | **FR144: Free tier, European provider, parallel model** |
| **Secrets** | **Kubernetes Secrets** | **FR145: Secure API key storage** |
| **Rate Limiting** | **LiteLLM built-in** | **NFR84: Stay within free tier quotas** |
| **Integration** | **Parallel models (not fallback)** | **External providers are independent model choices, NOT part of fallback chain** |

**Architecture: Fallback Chain + Parallel Models:**
```
┌─────────────────────────────────────────────────────────────────────────────┐
│  LiteLLM Hybrid Architecture                                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  FALLBACK CHAIN (automatic failover for "default" model):                   │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ vLLM (GPU) ──▶ Ollama (CPU) ──▶ OpenAI (paid, emergency)           │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  PARALLEL MODELS (explicit selection by application):                       │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ groq/llama-3.3-70b-versatile    (fast, 6000 req/day free)          │   │
│  │ gemini/gemini-1.5-flash         (1500 req/day free)                │   │
│  │ mistral/mistral-small-latest    (free tier)                        │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  Usage Examples:                                                            │
│  • Request "default" model → uses fallback chain                           │
│  • Request "groq/llama-3.3-70b" → direct to Groq                          │
│  • Request "gemini/gemini-1.5-flash" → direct to Google AI                │
│  • Open-WebUI can offer all models in dropdown                             │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**LiteLLM Configuration:**
```yaml
# applications/litellm/config.yaml (extended)
model_list:
  # === FALLBACK CHAIN (model_name: "vllm-qwen") ===
  # Tier 1: Local GPU (primary)
  - model_name: "vllm-qwen"
    litellm_params:
      model: "openai/Qwen/Qwen3-8B-AWQ"
      api_base: "http://vllm-api.ml.svc.cluster.local:8000/v1"
      api_key: "not-needed"

  # Tier 2: Local CPU (fallback)
  - model_name: "vllm-qwen"
    litellm_params:
      model: "ollama/phi4-mini"
      api_base: "http://ollama.ml.svc.cluster.local:11434"

  # Tier 3: Paid (emergency only)
  - model_name: "vllm-qwen"
    litellm_params:
      model: "gpt-4o-mini"
      api_key: "os.environ/OPENAI_API_KEY"

  # === PARALLEL MODELS (independent, explicit selection) ===
  # Groq - Fast inference, free tier
  - model_name: "groq/llama-3.3-70b-versatile"
    litellm_params:
      model: "groq/llama-3.3-70b-versatile"
      api_key: "os.environ/GROQ_API_KEY"

  - model_name: "groq/mixtral-8x7b-32768"
    litellm_params:
      model: "groq/mixtral-8x7b-32768"
      api_key: "os.environ/GROQ_API_KEY"

  # Google AI - Gemini models, free tier
  - model_name: "gemini/gemini-1.5-flash"
    litellm_params:
      model: "gemini/gemini-1.5-flash"
      api_key: "os.environ/GOOGLE_AI_API_KEY"

  - model_name: "gemini/gemini-1.5-pro"
    litellm_params:
      model: "gemini/gemini-1.5-pro"
      api_key: "os.environ/GOOGLE_AI_API_KEY"

  # Mistral - European provider, free tier
  - model_name: "mistral/mistral-small-latest"
    litellm_params:
      model: "mistral/mistral-small-latest"
      api_key: "os.environ/MISTRAL_API_KEY"

router_settings:
  routing_strategy: "simple-shuffle"
  num_retries: 3
  timeout: 30
  fallbacks: [{"default": ["default"]}]  # Only "default" has fallback

# Rate limiting to stay within free tiers
litellm_settings:
  max_budget: 0  # No spend limit (free tiers)
  budget_duration: "1d"
```

**Kubernetes Secret (FR145):**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: litellm-api-keys
  namespace: ml
type: Opaque
stringData:
  GROQ_API_KEY: "gsk_..."
  GOOGLE_AI_API_KEY: "AIza..."
  MISTRAL_API_KEY: "..."
  OPENAI_API_KEY: "sk-..."  # Emergency fallback for "default" model
```

**NFR Compliance:**
- NFR83: External provider requests route within 5 seconds
- NFR84: Rate limiting configured per provider to stay within free tiers

### OpenClaw Personal AI Assistant Architecture

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Deployment** | **Kubernetes Deployment in `apps` namespace, pinned to k3s-worker-01** | **FR149, FR152a: Official Docker image (Node.js >= 22), node affinity to highest resource CPU worker** |
| **Container Image** | **Official openclaw/openclaw Docker image** | **No custom build required; mcporter + MCP servers configured at runtime via workspace persistence** |
| **Storage** | **Local PVC (10Gi, local-path) on k3s-worker-01 for `~/.openclaw` + `~/clawd/`** | **FR151-152, FR152b: Config, workspace, WhatsApp session state, ClawdHub skills persist across restarts; backed up via Velero** |
| **Ingress** | **`openclaw.home.jetzinger.com` via Traefik IngressRoute** | **FR150: Gateway control UI + WebChat accessible via Tailscale** |
| **Primary LLM** | **Claude Opus 4.5 via Anthropic OAuth** | **FR155: Frontier reasoning as primary brain (Claude Code subscription)** |
| **Fallback LLM** | **LiteLLM proxy (`litellm.ml.svc:4000`)** | **FR156: Automatic failover to existing three-tier local stack (vLLM GPU → Ollama CPU → OpenAI)** |
| **Messaging Channels** | **Telegram + WhatsApp (Baileys) + Discord (discord.js)** | **FR159-161: All use outbound long-polling/WebSocket — no inbound exposure needed** |
| **MCP Tools** | **mcporter with Exa + additional research servers** | **FR165-166: Web research via MCP, installed to local workspace for persistence** |
| **Voice** | **ElevenLabs TTS/STT** | **FR169: Voice interaction via API, streaming responses** |
| **Multi-Agent** | **OpenClaw native sub-agent routing** | **FR171-173: Specialized agents callable from main conversation** |
| **Browser Tool** | **OpenClaw built-in browser automation** | **FR174-175: Web navigation, form filling, data extraction** |
| **Skills** | **ClawdHub marketplace integration** | **FR177-180: Install/sync skills to local workspace** |
| **Secrets** | **Kubernetes Secrets (9 secret keys)** | **NFR91: Anthropic OAuth, Telegram, WhatsApp, Discord, ElevenLabs, Exa, OpenAI (embeddings), LiteLLM fallback URL, gateway auth token** |
| **DM Security** | **Allowlist-only pairing** | **NFR92: Single-user lockdown across all channels** |
| **Observability** | **Loki logs + Blackbox Exporter (no native /metrics)** | **FR181-185: Log-derived Grafana panels + HTTP probe for uptime** |
| **Memory Backend** | **`memory-lancedb` plugin with OpenAI embeddings** | **FR189-191: Auto-capture/recall across conversations; `text-embedding-3-small` (1536-dim, ~300-500ms/embed via API); OPENAI_API_KEY in K8s Secret** |

**Deployment Architecture:**
```
┌─────────────────────────────────────────────────────────────────────────────┐
│  OpenClaw Gateway (apps namespace)                                           │
│  Web: https://openclaw.home.jetzinger.com                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Container: openclaw/openclaw (Node.js >= 22)                                │
│  ├── Gateway Control UI (WebChat + config management)                      │
│  ├── Agent Engine (Opus 4.5 primary, LiteLLM fallback)                    │
│  ├── Channel Connectors:                                                    │
│  │   ├── Telegram (long-polling, FR159)                                    │
│  │   ├── WhatsApp via Baileys (long-polling, FR160)                        │
│  │   └── Discord via discord.js (WebSocket, FR161)                         │
│  ├── MCP Tools via mcporter:                                                │
│  │   ├── Exa (web research, FR165)                                         │
│  │   └── Additional research servers (FR166)                               │
│  ├── Voice: ElevenLabs TTS/STT (FR169)                                     │
│  ├── Browser Automation Tool (FR174)                                        │
│  ├── Canvas/A2UI Rich Content (FR176)                                       │
│  └── ClawdHub Skills (FR177-180)                                            │
│                                                                             │
│  Persistent Storage (Local PVC 10Gi on k3s-worker-01):                      │
│  ├── ~/.openclaw/ (gateway config)                                          │
│  ├── ~/clawd/ (agent workspace, mcporter config, session data)             │
│  ├── WhatsApp Baileys auth state                                            │
│  └── ClawdHub installed skills                                              │
│  Note: Backed up via Velero cluster backups (FR152b)                        │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**LLM Routing Architecture (Inverse Fallback Pattern):**
```
┌─────────────────────────────────────────────────────────────────────────────┐
│  OpenClaw LLM Provider Routing                                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  PRIMARY: Claude Opus 4.5 (Anthropic OAuth)                                │
│  ├── Frontier reasoning, best quality                                       │
│  ├── Outbound HTTPS to api.anthropic.com                                   │
│  ├── OAuth credentials from K8s Secret                                      │
│  └── Handles MCP tool orchestration natively                               │
│                                                                             │
│           │ (on Anthropic unavailability)                                    │
│           ▼                                                                 │
│                                                                             │
│  FALLBACK: LiteLLM Proxy (litellm.ml.svc:4000/v1)                         │
│  ├── Uses existing three-tier fallback chain:                               │
│  │   ├── Tier 1: vLLM GPU (Qwen3-8B-AWQ, 30-50 tok/s)                    │
│  │   ├── Tier 2: Ollama CPU (phi4-mini, 70% accuracy)                      │
│  │   └── Tier 3: OpenAI (gpt-4o-mini, emergency)                          │
│  └── Internal cluster DNS resolution (NFR99)                               │
│                                                                             │
│  NOTE: This is the INVERSE of the existing pattern.                        │
│  Existing services: local primary → cloud fallback                         │
│  OpenClaw: cloud primary → local fallback                                   │
│  Reason: Opus 4.5 reasoning quality justifies cloud-first for personal AI  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Networking Architecture (Outbound-Only Channels):**
```
┌─────────────────────────────────────────────────────────────────────────────┐
│  OpenClaw Network Flows                                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  INBOUND (Tailscale only):                                                  │
│  └── Traefik → openclaw.home.jetzinger.com → Gateway Control UI             │
│                                                                             │
│  OUTBOUND (from pod, no inbound exposure needed):                           │
│  ├── Telegram Bot API (HTTPS long-polling)                                  │
│  ├── WhatsApp (Baileys WebSocket to WhatsApp servers)                      │
│  ├── Discord (discord.js WebSocket to Discord gateway)                      │
│  ├── Anthropic API (HTTPS, OAuth)                                           │
│  ├── ElevenLabs API (HTTPS, streaming)                                      │
│  ├── Exa API (HTTPS, research queries)                                      │
│  └── Additional MCP server endpoints (HTTPS)                               │
│                                                                             │
│  INTERNAL (cluster DNS):                                                    │
│  └── litellm.ml.svc.cluster.local:4000 (LLM fallback)                     │
│                                                                             │
│  NO additional Tailscale or VPN configuration required (NFR99)              │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Observability Architecture (Log-Based Pattern):**
```
┌─────────────────────────────────────────────────────────────────────────────┐
│  OpenClaw Observability (No native /metrics endpoint)                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  LOG-BASED MONITORING (Loki + Grafana):                                     │
│  ├── Promtail collects gateway stdout/stderr → Loki                        │
│  ├── Grafana dashboard with LogQL queries:                                  │
│  │   ├── Message volume per channel (Telegram/WhatsApp/Discord)            │
│  │   ├── LLM provider usage (Opus 4.5 vs LiteLLM ratio)                   │
│  │   ├── MCP tool invocation counts (Exa queries)                          │
│  │   ├── Error rates and types (auth failures, disconnects)                │
│  │   └── Session activity and agent routing                                │
│  └── NFR103: 7-day log retention via existing Loki config                  │
│                                                                             │
│  BLACKBOX MONITORING (Prometheus Blackbox Exporter):                        │
│  ├── HTTP probe: openclaw.home.jetzinger.com (30s interval)                 │
│  ├── Tracks: uptime, response latency, TLS validity                        │
│  └── NFR104: Alert after 3 consecutive failures                            │
│                                                                             │
│  ALERTMANAGER RULES (FR185):                                                │
│  ├── OpenClawGatewayDown: Blackbox probe fails 3x → P1                     │
│  ├── OpenClawHighErrorRate: >10% error rate in logs → P2                    │
│  └── OpenClawAuthExpiry: OAuth token warnings in logs → P2                  │
│                                                                             │
│  NOTE: This is a NEW observability pattern for the cluster.                │
│  Existing pattern: Prometheus scrape /metrics → Grafana                    │
│  OpenClaw pattern: Loki logs + Blackbox HTTP probe → Grafana                │
│  Reason: OpenClaw doesn't expose Prometheus metrics natively                │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Long-Term Memory Architecture (Auto-Recall/Capture):**
```
┌─────────────────────────────────────────────────────────────────────────────┐
│  OpenClaw Memory Subsystem (memory-lancedb plugin)                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  PLUGIN CONFIGURATION (openclaw.json):                                     │
│  ├── plugins.slots.memory = "memory-lancedb"                              │
│  └── plugins.entries.memory-lancedb.config:                                │
│      embedding.apiKey = "${OPENAI_API_KEY}"                                │
│      embedding.model = "text-embedding-3-small"                            │
│      autoCapture = true, autoRecall = true                                 │
│                                                                             │
│  AUTO-CAPTURE (on every conversation turn):                                │
│  ├── User message → embed via OpenAI API (1536-dim, ~300-500ms)           │
│  ├── Assistant response → extract key facts (rule-based triggers)          │
│  └── Store vectors + metadata → LanceDB on local PVC                      │
│                                                                             │
│  AUTO-RECALL (on every new message):                                       │
│  ├── Embed incoming message → vector similarity search                     │
│  ├── Retrieve top-k relevant memories from LanceDB                        │
│  └── Inject as context before LLM inference (transparent to user)         │
│                                                                             │
│  STORAGE (on openclaw-data PVC, k3s-worker-01):                           │
│  ├── ~/.openclaw/memory/lancedb/memories.lance/ (LanceDB vector store)    │
│  └── Persists across pod restarts (NFR106)                                │
│                                                                             │
│  EMBEDDING STACK (OpenAI API):                                             │
│  ├── openai npm package (in extension node_modules)                        │
│  ├── text-embedding-3-small (1536-dimensional)                             │
│  ├── Latency: ~300-500ms per embed (cloud API round-trip)                 │
│  └── OPENAI_API_KEY from K8s Secret (env var substitution)                │
│                                                                             │
│  ALTERNATIVES CONSIDERED:                                                  │
│  ├── memory-core (default): Manual search only, no auto-recall — rejected │
│  │   for personal AI use case requiring cross-conversation learning        │
│  ├── Local Xenova embeddings: Plugin does not support local provider      │
│  │   — only OpenAI-compatible embedding APIs supported in v2026.1.29      │
│  └── LiteLLM-routed embeddings: Could proxy OpenAI embedding calls       │
│      through LiteLLM to local models — future option if cost concerns     │
│                                                                             │
│  OPERATIONAL MANAGEMENT (CLI: openclaw ltm):                               │
│  ├── openclaw ltm stats   — show memory count (FR191)                     │
│  ├── openclaw ltm list    — list stored memories                          │
│  └── openclaw ltm search  — semantic search over memories                 │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Kubernetes Manifests:**

*Deployment (FR149):*
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: openclaw
  namespace: apps
  labels:
    app.kubernetes.io/name: openclaw
    app.kubernetes.io/instance: openclaw-gateway
    app.kubernetes.io/part-of: home-lab
    app.kubernetes.io/managed-by: kubectl
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: openclaw
  strategy:
    type: RollingUpdate
  template:
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: kubernetes.io/hostname
                    operator: In
                    values:
                      - k3s-worker-01
      containers:
        - name: openclaw
          image: openclaw/openclaw:latest
          command: ["node", "dist/index.js", "gateway", "--bind", "lan", "--port", "18789", "--allow-unconfigured"]
          ports:
            - containerPort: 18789
              name: gateway
            - containerPort: 18790
              name: bridge
          env:
            - name: HOME
              value: /home/node
            - name: TERM
              value: xterm-256color
          envFrom:
            - secretRef:
                name: openclaw-secrets
          volumeMounts:
            - name: openclaw-data
              mountPath: /home/node/.openclaw
              subPath: openclaw
            - name: openclaw-data
              mountPath: /home/node/clawd
              subPath: clawd
      volumes:
        - name: openclaw-data
          persistentVolumeClaim:
            claimName: openclaw-data
```

*Secret (NFR91):*
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: openclaw-secrets
  namespace: apps
type: Opaque
stringData:
  ANTHROPIC_OAUTH_TOKEN: "<from-oauth-flow>"
  TELEGRAM_BOT_TOKEN: "<from-botfather>"
  WHATSAPP_CREDENTIALS: "<from-baileys-pairing>"
  DISCORD_BOT_TOKEN: "<from-discord-dev-portal>"
  ELEVENLABS_API_KEY: "<from-elevenlabs>"
  EXA_API_KEY: "<from-exa>"
  LITELLM_FALLBACK_URL: "http://litellm.ml.svc.cluster.local:4000/v1"
  CLAWDBOT_GATEWAY_TOKEN: "<gateway-auth-token>"
```

*Persistent Volume (FR151-152, FR152a, FR152b):*
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: openclaw-data
  namespace: apps
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: local-path
  resources:
    requests:
      storage: 10Gi
# Note: Local storage binds to k3s-worker-01 via node affinity in Deployment
# Velero cluster backups include this PVC for disaster recovery
```

*IngressRoute (FR150):*
```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: openclaw
  namespace: apps
spec:
  entryPoints: [websecure]
  routes:
    - match: Host(`openclaw.home.jetzinger.com`)
      kind: Rule
      services:
        - name: openclaw
          port: 18789
  tls:
    certResolver: letsencrypt
```

**WhatsApp Session Persistence (Risk Mitigation):**

WhatsApp via Baileys requires persistent auth state. If the pod restarts without preserving Baileys session data, re-pairing is required. The NFS PVC at `~/clawd/` stores Baileys auth state, ensuring session survives pod restarts. This is the primary risk mitigation for FR160.

**NFR Compliance:**
- NFR86: Gateway message processing <10s (Node.js event loop, no heavy compute)
- NFR87: Control UI loads <3s (lightweight web UI served by gateway)
- NFR88: LiteLLM fallback <5s (existing LiteLLM health check + failover)
- NFR89: mcporter Exa queries <30s (external API + LLM processing)
- NFR90: ElevenLabs streaming begins <5s (API latency)
- NFR91: All 8 credential types in K8s Secrets (no plaintext ConfigMaps)
- NFR92: Allowlist-only DM pairing via `openclaw.json` config
- NFR93: Traefik IngressRoute accessible only via Tailscale mesh
- NFR94: OAuth token auto-refresh; manual refresh via control UI (FR158)
- NFR95: Secrets excluded from Loki log collection (gateway redacts by default)
- NFR96: Anthropic OAuth auto-reconnect <30s on transient failures
- NFR97: Channel auto-reconnect <60s (Telegram/WhatsApp/Discord)
- NFR98: mcporter graceful timeout recovery (no gateway crash)
- NFR99: LiteLLM reachable via `litellm.ml.svc` K8s DNS from `apps` namespace
- NFR100: NFS PVC preserves all state across pod restarts
- NFR101: Channel isolation (one channel disconnect doesn't affect others)
- NFR102: Pod CrashLoopBackOff triggers Alertmanager within 2 minutes
- NFR103: Loki retains OpenClaw logs 7 days (existing retention policy)
- NFR104: Blackbox Exporter 30s probe interval, alert after 3 failures
- NFR105: Memory embedding latency <500ms via OpenAI API (text-embedding-3-small); local Xenova not supported by plugin
- NFR106: LanceDB memory data persists across pod restarts via local PVC

**Repository Structure Addition:**
```
applications/
  └── openclaw/
      ├── deployment.yaml           # OpenClaw gateway Deployment
      ├── service.yaml              # ClusterIP service (ports 18789/18790)
      ├── ingressroute.yaml         # openclaw.home.jetzinger.com
      ├── pvc.yaml                  # 10Gi NFS for config + workspace
      ├── secret.yaml               # API credentials (gitignored)
      └── blackbox-probe.yaml       # Prometheus Blackbox target
```

### Backup & Recovery Architecture

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Cluster State | etcd snapshots (K3s) to NFS | Built-in, automatic (every 12h), 14-snapshot retention, stored on `/mnt/k3s-snapshots` |
| Manifests | Git repository | Version controlled, re-deployable |
| PostgreSQL | pg_dump to NFS | Scriptable, Synology snapshots |
| PVC Data | Synology snapshots | Hourly, handled by NAS |

**K3s Snapshot Details (Story 8.2):**
- **Datastore:** Embedded etcd (migrated from sqlite via ADR-010)
- **Storage:** NFS mount at `/mnt/k3s-snapshots` (Synology DS920+)
- **Schedule:** Every 12 hours (00:00 and 12:00 UTC) via `etcd-snapshot-schedule-cron`
- **Retention:** 14 snapshots (7 days of history)
- **Dual Protection:** K3s snapshots + Synology hourly snapshots of NFS volume
- **Manual Snapshots:** `k3s etcd-snapshot save --name <name>` before major changes
- **Configuration:** `/etc/rancher/k3s/config.yaml` on k3s-master
- **Runbook:** `docs/runbooks/cluster-backup.md`

### Decision Impact Analysis

**Implementation Sequence:**
1. K3s cluster setup (foundation)
2. NFS provisioner (enables StatefulSets)
3. cert-manager + Let's Encrypt (enables HTTPS)
4. MetalLB (enables LoadBalancer services)
5. kube-prometheus-stack (observability)
6. Loki (log aggregation)
7. PostgreSQL (data layer)
8. Ollama (AI workloads)
9. Nginx proxy (dev tooling)

**Cross-Component Dependencies:**
- PostgreSQL, Ollama, Loki all depend on NFS provisioner
- All ingress routes depend on cert-manager
- Grafana dashboards depend on Prometheus data sources
- Alertmanager depends on Prometheus rules

## Implementation Patterns & Consistency Rules

### Naming Patterns

**Kubernetes Resource Naming:**
- Pattern: `{app}-{component}`
- Examples: `postgres-primary`, `prometheus-server`, `traefik-ingress`
- Rationale: Clear, consistent, sortable in kubectl output

**Label Conventions (Kubernetes Recommended):**
```yaml
labels:
  app.kubernetes.io/name: postgres
  app.kubernetes.io/instance: postgres-primary
  app.kubernetes.io/component: database
  app.kubernetes.io/part-of: home-lab
  app.kubernetes.io/managed-by: helm
```

**Ingress Naming:**
- Pattern: `{service}.home.jetzinger.com`
- Examples: `grafana.home.jetzinger.com`, `ollama.home.jetzinger.com`
- All services get dedicated subdomains via NextDNS rewrites

### Structure Patterns

**Repository Organization:**
```
home-lab/
├── infrastructure/     # Core cluster components
│   ├── k3s/           # K3s installation scripts
│   ├── nfs/           # NFS provisioner
│   ├── metallb/       # Load balancer
│   └── cert-manager/  # TLS certificates
├── applications/       # Workload deployments
│   ├── postgres/      # Database
│   ├── ollama/        # LLM inference
│   ├── nginx/         # Dev proxy
│   └── n8n/           # Workflow automation
├── monitoring/         # Observability stack
│   ├── prometheus/    # kube-prometheus-stack
│   └── loki/          # Log aggregation
├── docs/              # Documentation
│   ├── adrs/          # Architecture decisions
│   ├── runbooks/      # Operational procedures
│   └── diagrams/      # Visual documentation
└── scripts/           # Automation scripts
```

**Helm Values Management:**
- Each chart directory contains `values-homelab.yaml`
- All values version controlled in Git
- No inline `--set` flags in production deployments

### Format Patterns

**ADR Naming:**
- Pattern: `ADR-{NNN}-{short-title}.md`
- Examples: `ADR-001-nfs-over-longhorn.md`, `ADR-002-traefik-ingress.md`

**Runbook Naming:**
- Pattern: `{component}-{operation}.md`
- Examples: `postgres-backup.md`, `cluster-recovery.md`, `nfs-troubleshooting.md`

### Process Patterns

**Deployment Process:**
1. Update values file in Git
2. Apply with Helm: `helm upgrade --install {name} {chart} -f values-homelab.yaml -n {namespace}`
3. Verify with kubectl: `kubectl get pods -n {namespace}`
4. Document any issues in runbooks

**Troubleshooting Process:**
1. Check pod status: `kubectl get pods -n {namespace}`
2. Check logs: `kubectl logs {pod} -n {namespace}`
3. Check events: `kubectl describe pod {pod} -n {namespace}`
4. Consult runbook if exists
5. Document resolution if new issue

### Enforcement Guidelines

**All AI Agents MUST:**
- Use `{app}-{component}` naming for all K8s resources
- Apply Kubernetes recommended labels to all resources
- Place manifests in correct layer folder
- Create `values-homelab.yaml` for all Helm deployments
- Use subdomain pattern for ingress routes
- Document decisions as ADRs when making architectural choices

## Project Structure & Boundaries

### Complete Project Directory Structure

```
home-lab/
├── README.md                           # Project overview, quick start
├── .gitignore                          # Git ignore patterns
├── docs/                               # Project documentation & BMAD outputs
│
├── infrastructure/                     # Core cluster components
│   ├── k3s/
│   │   ├── install-master.sh          # Control plane setup script
│   │   ├── install-worker.sh          # Worker join script
│   │   └── kubeconfig-setup.sh        # Local kubectl config
│   ├── nfs/
│   │   ├── values-homelab.yaml        # NFS provisioner config
│   │   └── storageclass.yaml          # Default StorageClass
│   ├── metallb/
│   │   ├── values-homelab.yaml        # MetalLB config
│   │   └── ip-pool.yaml               # IP address pool
│   └── cert-manager/
│       ├── values-homelab.yaml        # cert-manager config
│       └── cluster-issuer.yaml        # Let's Encrypt issuer
│
├── applications/                       # Workload deployments
│   ├── postgres/
│   │   ├── values-homelab.yaml        # Bitnami PostgreSQL config
│   │   └── backup-cronjob.yaml        # pg_dump automation
│   ├── ollama/
│   │   ├── values-homelab.yaml        # Ollama config
│   │   └── ingress.yaml               # ollama.home.jetzinger.com
│   ├── nginx/
│   │   ├── deployment.yaml            # Nginx reverse proxy
│   │   ├── configmap.yaml             # Proxy configurations
│   │   └── ingress.yaml               # dev.home.jetzinger.com
│   ├── n8n/
│   │   ├── values-homelab.yaml        # n8n workflow config
│   │   └── ingress.yaml               # n8n.home.jetzinger.com
│   ├── paperless/
│   │   ├── values-homelab.yaml        # Paperless-ngx Helm config
│   │   ├── ingress.yaml               # paperless.home.jetzinger.com
│   │   ├── pvc.yaml                   # Document storage PVC
│   │   ├── tika-deployment.yaml       # Apache Tika for Office docs
│   │   ├── gotenberg-deployment.yaml  # PDF conversion service
│   │   ├── email-bridge/              # Private email IMAP bridge (StatefulSet)
│   │   ├── paperless-gpt/            # AI metadata generation (replaces paperless-ai)
│   │   │   ├── deployment.yaml       # Paperless-GPT with Docling OCR
│   │   │   ├── service.yaml          # ClusterIP service
│   │   │   └── ingressroute.yaml     # paperless-gpt.home.jetzinger.com
│   │   └── docling/                  # Layout-aware document parser
│   │       ├── deployment.yaml       # Docling server with Granite-Docling 258M
│   │       └── service.yaml          # ClusterIP service
│   ├── stirling-pdf/
│   │   ├── values-homelab.yaml        # Stirling-PDF Helm config
│   │   └── ingress.yaml               # stirling.home.jetzinger.com
│   ├── openclaw/
│   │   ├── deployment.yaml            # OpenClaw gateway Deployment
│   │   ├── service.yaml               # ClusterIP service (port 3000)
│   │   ├── ingressroute.yaml          # openclaw.home.jetzinger.com
│   │   ├── pvc.yaml                   # 10Gi NFS for config + workspace
│   │   ├── secret.yaml                # API credentials (gitignored)
│   │   └── blackbox-probe.yaml        # Prometheus Blackbox target
│   └── dev-containers/
│       ├── base-image/
│       │   └── Dockerfile             # Dev container base image
│       ├── dev-container-template.yaml # Template for new containers
│       ├── ssh-configmap.yaml         # SSH authorized_keys
│       └── nginx-stream-config.yaml   # Nginx TCP/SSH routing
│
├── monitoring/                         # Observability stack
│   ├── prometheus/
│   │   ├── values-homelab.yaml        # kube-prometheus-stack config
│   │   └── custom-rules.yaml          # Alert rules
│   └── loki/
│       ├── values-homelab.yaml        # Loki config
│       └── promtail-config.yaml       # Log collection
│
├── docs/                               # Documentation
│   ├── adrs/                          # Architecture Decision Records
│   │   ├── ADR-001-k3s-over-k8s.md
│   │   ├── ADR-002-nfs-over-longhorn.md
│   │   └── ADR-003-traefik-ingress.md
│   ├── runbooks/                      # Operational procedures
│   │   ├── cluster-recovery.md
│   │   ├── nfs-troubleshooting.md
│   │   └── postgres-backup.md
│   └── diagrams/                      # Visual documentation
│       └── architecture-overview.excalidraw
│
└── scripts/                            # Automation scripts
    ├── deploy-all.sh                  # Full stack deployment
    ├── backup-cluster.sh              # etcd + PVC backup
    └── health-check.sh                # Cluster health validation
```

### Requirements to Structure Mapping

| FR Category | Directory | Key Files |
|-------------|-----------|-----------|
| Cluster Operations (FR1-6) | `infrastructure/k3s/` | install scripts, kubeconfig |
| Storage Management (FR14-18) | `infrastructure/nfs/` | values, storageclass |
| Networking & Ingress (FR19-23) | `infrastructure/metallb/`, `cert-manager/` | values, issuer |
| Observability (FR24-30) | `monitoring/prometheus/`, `loki/` | values, rules |
| Data Services (FR31-35) | `applications/postgres/` | values, backup job |
| AI/ML Workloads (FR36-40) | `applications/ollama/`, `n8n/` | values, ingress |
| Development Proxy (FR41-43) | `applications/nginx/` | deployment, configmap |
| Portfolio & Documentation (FR49-54) | `docs/` | ADRs, runbooks |
| Document Management (FR55-93, FR192-208) | `applications/paperless/`, `applications/stirling-pdf/` | values, ingress, pvc, tika, gotenberg, bridge, paperless-gpt, docling |
| Dev Containers (FR59-63) | `applications/dev-containers/` | Dockerfile, template, ssh config |
| OpenClaw AI Assistant (FR149-188) | `applications/openclaw/` | deployment, service, ingressroute, pvc, secret, blackbox-probe |

### Namespace Boundaries

| Namespace | Components | Purpose |
|-----------|------------|---------|
| `kube-system` | K3s core, Traefik | System-managed |
| `infra` | MetalLB, cert-manager | Core infrastructure |
| `monitoring` | Prometheus, Grafana, Loki, Alertmanager | Observability |
| `data` | PostgreSQL | Stateful data services |
| `apps` | n8n, Open-WebUI, OpenClaw | General applications |
| `ml` | vLLM, Ollama, LiteLLM | AI/ML inference |
| `docs` | Paperless-ngx, Paperless-GPT, Docling, Tika, Gotenberg, Redis | Document management |
| `dev` | Nginx proxy, dev containers | Development tools + remote dev environments |

### Network Boundaries

**Ingress Flow:**
```
Internet → Tailscale → Home Network → Traefik (NodePort) → Services
```

**Service Discovery:**
- Internal: `{service}.{namespace}.svc.cluster.local`
- External: `{service}.home.jetzinger.com` via Traefik ingress

**Network Policies:** Default allow (MVP), progressive tightening in Phase 2

### Storage Boundaries

**NFS Mount Structure:**
```
Synology: /volume1/k8s-data/
├── {namespace}-{pvc-name}-{pv-id}/    # Auto-created by provisioner
│   ├── monitoring-prometheus-data/
│   ├── monitoring-loki-data/
│   ├── data-postgres-data/
│   └── ml-ollama-models/
```

**StorageClass:** `nfs-client` (default, dynamic provisioning)

## Architecture Validation Results

### Coherence Validation ✅

**Decision Compatibility:** All technology choices are compatible
- K3s ecosystem (Flannel, Traefik) works as integrated unit
- Helm charts are standard, well-maintained projects
- NFS + Synology is proven storage pattern

**Pattern Consistency:** All patterns align with decisions
- Naming, labeling, and structure patterns are uniform
- No contradictory conventions identified

**Structure Alignment:** Project structure supports architecture
- Layer-based organization matches deployment model
- Namespace boundaries reflect directory structure

### Requirements Coverage ✅

**Functional Requirements:** 208/208 covered
**Non-Functional Requirements:** 116/116 covered

All requirements have explicit architectural support documented in Core Architectural Decisions and Project Structure sections.

**Requirements Updates:**
- FR55-66: Document Management (Paperless-ngx core) — covered by Document Management Architecture
- FR59-63: Dev Containers — covered by Dev Containers Architecture
- FR71-74: vLLM GPU — covered by AI/ML Architecture
- FR75-80: Paperless configuration & NFS integration — covered by Document Management Architecture
- FR81-83: Tika/Gotenberg Office docs — covered by Office Document Processing Architecture
- FR84-86: Stirling-PDF — covered by PDF Editor Architecture
- FR87-89: ~~Paperless-AI with GPU Ollama~~ — superseded by FR192-208 (Paperless-GPT + Docling, Epic 25)
- FR90-93: Email integration (private email/Gmail) — covered by Email Integration Architecture
- FR94: vLLM graceful degradation (host GPU usage) — covered by Dual-Use GPU Architecture
- FR95-99: Steam Gaming Platform — covered by Dual-Use GPU Architecture
- FR100-103: Multi-Subnet GPU Worker Networking — covered by Multi-Subnet GPU Worker Network Architecture
- **FR104-108: ~~Paperless-AI model upgrade + migration~~ — superseded by FR192-208 (Paperless-GPT + Docling, Epic 25)**
- **FR109-111: ~~vLLM GPU + Ollama slim models~~ — superseded by FR203-207 (Qwen3-8B-AWQ + phi4-mini, Epic 25)**
- **FR112: k3s-worker-02 resource reduction — unchanged**
- **FR113-118: LiteLLM Inference Proxy with three-tier fallback (vLLM → Ollama → OpenAI), OpenAI API key secret, Prometheus metrics — covered by LiteLLM Inference Proxy Architecture (Epic 14). FR115 superseded by FR194 (Paperless-GPT → LiteLLM)**
- **FR119: k3s-gpu-worker boots into ML Mode by default via systemd service — covered by Dual-Use GPU Architecture (Default Boot Behavior)**
- **FR120-122: Tailscale Subnet Routers for 192.168.2.0/24 and 192.168.0.0/24 — covered by Tailscale Subnet Router Architecture**
- **FR123-125: Synology NAS K3s Worker VM with labels/taints — covered by Synology NAS K3s Worker Architecture**
- **FR126-129: Open-WebUI with LiteLLM backend, model switching — covered by Open-WebUI Architecture**
- **FR130-133: Kubernetes Dashboard with read-only access — covered by Kubernetes Dashboard Architecture**
- **FR134-137: Gitea self-hosted Git with PostgreSQL — covered by Gitea Self-Hosted Git Architecture**
- **FR138-141: DeepSeek-R1 14B R1-Mode, gpu-mode script extension — covered by DeepSeek-R1 14B Reasoning Mode Architecture**
- **FR142-145: LiteLLM External Providers (Groq, Google, Mistral) — covered by LiteLLM External Providers Architecture**
- **FR146-148: Blog Article completion (Epic 9) — portfolio documentation requirement**
- NFR50-54: Gaming Platform performance requirements — covered by Dual-Use GPU Architecture
- NFR55-57: Multi-Subnet networking requirements — covered by Multi-Subnet GPU Worker Network Architecture
- **NFR46-47, NFR58-64: ~~Paperless-AI classification/GPU performance~~ — superseded by NFR107-116 (Paperless-GPT + Docling pipeline, Epic 25)**
- **NFR65-69: LiteLLM failover latency (<5s), proxy overhead (<100ms), degraded operation during Gaming Mode, health endpoint response time — covered by LiteLLM Inference Proxy Architecture (Epic 14)**
- **NFR70: ML Mode auto-activates within 5 minutes of k3s-gpu-worker boot — covered by Dual-Use GPU Architecture (Default Boot Behavior)**
- **NFR71-72: Tailscale Subnet Router route advertisement and failover — covered by Tailscale Subnet Router Architecture**
- **NFR73-74: NAS Worker VM resources and join time — covered by Synology NAS K3s Worker Architecture**
- **NFR75-76: Open-WebUI load time and persistent chat history — covered by Open-WebUI Architecture**
- **NFR77-78: Kubernetes Dashboard load time and Tailscale-only access — covered by Kubernetes Dashboard Architecture**
- **NFR79-80: Gitea operation speed and web interface load time — covered by Gitea Self-Hosted Git Architecture**
- **NFR81-82: DeepSeek-R1 model loading and inference speed — covered by DeepSeek-R1 14B Reasoning Mode Architecture**
- **NFR83-84: External provider failover and rate limiting — covered by LiteLLM External Providers Architecture**
- **NFR85: Blog Article publication timeline — portfolio documentation requirement**
- **FR149-154: OpenClaw Gateway & Core Infrastructure — covered by OpenClaw Personal AI Assistant Architecture**
- **FR155-158: OpenClaw LLM Provider Management (Opus 4.5 + LiteLLM fallback) — covered by OpenClaw Personal AI Assistant Architecture**
- **FR159-164: OpenClaw Messaging Channels (Telegram, WhatsApp, Discord, cross-channel) — covered by OpenClaw Personal AI Assistant Architecture**
- **FR165-168: OpenClaw MCP Research Tools (mcporter, Exa) — covered by OpenClaw Personal AI Assistant Architecture**
- **FR169-170: OpenClaw Voice Capabilities (ElevenLabs) — covered by OpenClaw Personal AI Assistant Architecture**
- **FR171-176: OpenClaw Multi-Agent & Advanced (sub-agents, browser, Canvas/A2UI) — covered by OpenClaw Personal AI Assistant Architecture**
- **FR177-180: OpenClaw Skills & Marketplace (ClawdHub) — covered by OpenClaw Personal AI Assistant Architecture**
- **FR181-186: OpenClaw Observability & Operations (Loki, Blackbox, Alertmanager) — covered by OpenClaw Personal AI Assistant Architecture**
- **FR187-188: OpenClaw Documentation & Portfolio (ADR, README) — covered by OpenClaw Personal AI Assistant Architecture**
- **NFR86-90: OpenClaw Performance (message response, UI load, fallback, MCP, voice) — covered by OpenClaw Personal AI Assistant Architecture**
- **NFR91-95: OpenClaw Security (K8s Secrets, allowlist DM, Tailscale-only, OAuth refresh, no secrets in logs) — covered by OpenClaw Personal AI Assistant Architecture**
- **NFR96-99: OpenClaw Integration (OAuth reconnect, channel reconnect, MCP recovery, cluster DNS) — covered by OpenClaw Personal AI Assistant Architecture**
- **NFR100-104: OpenClaw Reliability (NFS persistence, channel isolation, crash alerting, log retention, blackbox probing) — covered by OpenClaw Personal AI Assistant Architecture**
- **FR189-191: OpenClaw Long-Term Memory (LanceDB auto-recall/capture, OpenAI text-embedding-3-small, CLI management) — covered by OpenClaw Personal AI Assistant Architecture**
- **NFR105-106: OpenClaw Memory (embedding latency, LanceDB persistence) — covered by OpenClaw Personal AI Assistant Architecture**
- **FR192-198: Paperless-GPT deployment with Docling OCR, LiteLLM integration, prompt templates, manual/auto processing, ingress — covered by AI Document Classification Architecture (Paperless-GPT + Docling)**
- **FR199-202: Docling server with Granite-Docling 258M VLM pipeline, layout-aware parsing, CPU-only — covered by AI Document Classification Architecture (Paperless-GPT + Docling)**
- **FR203-204: vLLM upgrade v0.10.2+ with Qwen3-8B-AWQ — covered by AI/ML Architecture + AI Document Classification Architecture**
- **FR205, FR207: LiteLLM configmap updates for Qwen3 model aliases — covered by LiteLLM Inference Proxy Architecture**
- **FR206: Ollama upgrade from qwen2.5:3b to phi4-mini — covered by AI/ML Architecture**
- **FR208: Paperless-AI removal — covered by AI Document Classification Architecture (Paperless-GPT + Docling)**
- **NFR107-108: Paperless-GPT GPU metadata generation speed and accuracy — covered by AI Document Classification Architecture**
- **NFR109, NFR111: CPU fallback accuracy (70%) and classification latency (<60s) — covered by AI Document Classification Architecture**
- **NFR110: Qwen3 structured output validity (95%+) — covered by AI Document Classification Architecture**
- **NFR112: Prompt template hot-reload — covered by AI Document Classification Architecture**
- **NFR113-114: Docling performance and memory footprint — covered by AI Document Classification Architecture**
- **NFR115-116: vLLM upgrade CLI compatibility and DeepSeek-R1 continuity — covered by AI/ML Architecture + DeepSeek-R1 Architecture**

### Implementation Readiness ✅

**Confidence Level:** HIGH

This architecture is ready for implementation because:
- All critical decisions are documented with rationale
- Implementation patterns prevent agent conflicts
- Project structure is complete and specific
- FR-to-structure mapping enables traceability

### Architecture Completeness Checklist

**✅ Requirements Analysis**
- [x] Project context thoroughly analyzed
- [x] Scale and complexity assessed (Medium)
- [x] Technical constraints identified (Proxmox, Synology, network)
- [x] Cross-cutting concerns mapped (Tailscale, TLS, observability)

**✅ Architectural Decisions**
- [x] Critical decisions documented (18 core decisions)
- [x] Technology stack fully specified (Helm charts identified)
- [x] Integration patterns defined (namespace, network, storage)
- [x] Implementation sequence established

**✅ Implementation Patterns**
- [x] Naming conventions established
- [x] Structure patterns defined
- [x] Process patterns documented (deploy, troubleshoot)
- [x] Enforcement guidelines specified

**✅ Project Structure**
- [x] Complete directory structure defined
- [x] Component boundaries established (8 namespaces)
- [x] Integration points mapped
- [x] Requirements to structure mapping complete

### First Implementation Steps

1. Create VMs in Proxmox (k3s-master, k3s-worker-01)
2. Run `infrastructure/k3s/install-master.sh`
3. Run `infrastructure/k3s/install-worker.sh`
4. Verify with `kubectl get nodes`
5. Deploy NFS provisioner from `infrastructure/nfs/`

## Architecture Completion Summary

### Workflow Completion

**Architecture Decision Workflow:** COMPLETED ✅
**Total Steps Completed:** 8
**Date Completed:** 2025-12-27
**Document Location:** `docs/planning-artifacts/architecture.md`

### Final Architecture Deliverables

**Complete Architecture Document**
- All architectural decisions documented with rationale
- Implementation patterns ensuring AI agent consistency
- Complete project structure with all files and directories
- Requirements to architecture mapping
- Validation confirming coherence and completeness

**Implementation Ready Foundation**
- 27 core architectural decisions made (updated 2026-02-13: Paperless-GPT + Docling replaces Paperless-AI, ADR-012)
- 6 implementation pattern categories defined
- 8 namespace boundaries established
- 208 functional + 116 non-functional requirements supported

**AI Agent Implementation Guide**
- Technology stack with Helm chart references
- Consistency rules preventing implementation conflicts
- Project structure with clear boundaries
- Integration patterns and communication standards

### Implementation Handoff

**For AI Agents:**
This architecture document is your complete guide for implementing home-lab. Follow all decisions, patterns, and structures exactly as documented.

**First Implementation Priority:**
```bash
# Weekend 1: K3s Cluster Setup
# 1. Create VMs in Proxmox
# 2. Install K3s master
curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644
# 3. Get join token
sudo cat /var/lib/rancher/k3s/server/node-token
# 4. Join worker
curl -sfL https://get.k3s.io | K3S_URL=https://192.168.2.20:6443 K3S_TOKEN=<token> sh -
```

**Development Sequence:**
1. Initialize K3s cluster (Weekend 1)
2. Deploy NFS provisioner (Weekend 2)
3. Setup Traefik + cert-manager (Weekend 3)
4. Deploy observability stack (Weekend 4)
5. Deploy applications following patterns

---

**Architecture Status:** READY FOR IMPLEMENTATION ✅

