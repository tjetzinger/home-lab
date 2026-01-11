---
stepsCompleted: [1, 2, 3, 4, 5, 6, 7, 8]
workflow_completed: true
completedAt: '2025-12-27'
lastModified: '2026-01-11'
updateReason: 'Added Dual-Use GPU Architecture for Steam Gaming Platform (FR94-99, NFR50-54): Mode switching, graceful degradation, n8n fallback routing'
inputDocuments:
  - 'docs/planning-artifacts/prd.md'
  - 'docs/planning-artifacts/product-brief-home-lab-2025-12-27.md'
  - 'docs/planning-artifacts/research/domain-k8s-platform-career-positioning-research-2025-12-27.md'
  - 'docs/analysis/brainstorming-session-2025-12-27.md'
workflowType: 'architecture'
project_name: 'home-lab'
user_name: 'Tom'
date: '2025-12-27'
---

# Architecture Decision Document

_This document builds collaboratively through step-by-step discovery. Sections are appended as we work through each architectural decision together._

## Project Context Analysis

### Requirements Overview

**Functional Requirements:** 99 FRs across 16 capability areas
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
- Document Management (19): Paperless-ngx, Redis, OCR, Tika, Gotenberg, Stirling-PDF, Paperless-AI, Email integration
- Dev Containers (5): VS Code SSH, Claude Code, git worktrees
- Gaming Platform (5): Steam, Proton, mode switching, fallback routing

**Non-Functional Requirements:** 54 NFRs
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
| LLM Inference (CPU) | Ollama Helm chart | Official chart, CPU fallback when GPU unavailable |
| **LLM Inference (GPU)** | **vLLM on RTX 3060 eGPU** | **FR38-39: Production GPU inference, 4-10x faster than CPU** |
| **GPU Worker** | **Intel NUC + RTX 3060 12GB eGPU** | **FR71: Hot-pluggable GPU worker via Tailscale** |
| **GPU Networking** | **Dual-stack: 192.168.0.x (local) + Tailscale (K3s)** | **FR71, FR74: Hot-plug capability, cross-subnet support** |
| **vLLM Models** | **DeepSeek-Coder 6.7B, Mistral 7B, Llama 3.1 8B** | **FR72: Multi-model serving for code, speed, quality** |
| **Model Serving** | **Single vLLM instance, 3 models loaded** | **Simplicity; all models in memory, instant switching** |
| **Context Window** | **8K-16K tokens per request** | **Balanced: ~10-11GB model VRAM, ~1-2GB KV cache** |
| **Graceful Degradation** | **vLLM → Ollama fallback when GPU offline** | **FR73: No downtime when GPU worker unavailable** |
| Model Storage | NFS PVC | Persist downloaded models |
| GPU Scheduling | NVIDIA GPU Operator | Automatic driver installation, GPU resource management |

**vLLM Multi-Model Configuration:**
- **DeepSeek-Coder 6.7B** (~5GB VRAM, 4-bit quantized)
  - Use case: Code generation, debugging, code review
  - Performance: ~60 tok/s
  - Endpoint: `POST /v1/completions {"model": "deepseek-coder", ...}`

- **Mistral 7B** (~5GB VRAM, 4-bit quantized)
  - Use case: Fast general-purpose inference
  - Performance: ~70-80 tok/s
  - Endpoint: `POST /v1/completions {"model": "mistral-7b", ...}`

- **Llama 3.1 8B** (~6GB VRAM, 4-bit quantized)
  - Use case: Quality reasoning, complex tasks
  - Performance: ~50-60 tok/s
  - Endpoint: `POST /v1/completions {"model": "llama-3.1-8b", ...}`

**Total VRAM:** ~16GB allocated (10-11GB models, 1-2GB KV cache, remaining headroom)

**GPU Worker Architecture:**
```
Intel NUC (192.168.0.x local network)
  └─ Tailscale VPN (stable IP for K3s)
      └─ K3s node join via Tailscale IP
          └─ vLLM Pod scheduled with GPU resource request
              └─ NVIDIA GPU Operator manages drivers/runtime
```

**Hot-Plug Workflow (FR74):**
1. GPU worker boots → Tailscale connects → K3s detects node
2. Operator uncordons node: `kubectl uncordon k3s-gpu`
3. vLLM Pod schedules to GPU node (GPU resource request)
4. GPU worker shutdown → Node marked NotReady → vLLM workloads reschedule to Ollama (CPU)

**Integration Pattern:**
- vLLM and Ollama both expose OpenAI-compatible API
- n8n workflows can route to vLLM (GPU) or Ollama (CPU) based on availability
- Model selection via API `"model"` parameter (manual or via n8n routing logic)

### Dual-Use GPU Architecture (ML + Gaming)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **GPU Sharing Model** | **Mode Switching (not parallel)** | **RTX 3060 12GB VRAM insufficient for gaming (6-8GB) + vLLM (10-11GB) simultaneously** |
| **Host Gaming** | **Steam + Proton on Ubuntu 22.04** | **FR95-96: Native host performance, Windows game compatibility via Proton** |
| **Mode Switching** | **Manual script with kubectl** | **FR97: Operator-controlled, explicit state transitions** |
| **GPU Detection** | **vLLM health check + n8n routing** | **FR94, NFR50: Detect GPU unavailability within 10 seconds** |
| **Fallback Strategy** | **Ollama CPU inference** | **NFR54: Maintain <5s inference latency during Gaming Mode** |

**Why NOT Parallel Operation:**
- RTX 3060: 12GB VRAM total
- vLLM 3-model config: 10-11GB VRAM
- Modern games: 6-8GB VRAM
- **Total exceeds 12GB** - parallel operation causes OOM crashes
- MIG (hardware isolation) not available on consumer GPUs
- Time-slicing lacks memory isolation - causes instability

**Operational Modes:**

| Mode | GPU Owner | vLLM Status | Inference Path | Use Case |
|------|-----------|-------------|----------------|----------|
| **ML Mode** | K8s (vLLM) | Running (1 replica) | GPU-accelerated | Default, AI/ML workloads |
| **Gaming Mode** | Host (Steam) | Scaled to 0 | Ollama CPU fallback | Gaming sessions |

**Mode Switching Architecture:**
```
┌─────────────────────────────────────────────────────────────┐
│                Intel NUC (Ubuntu 22.04)                     │
├─────────────────────────────────────────────────────────────┤
│  Host OS Layer:                                             │
│  ├── Steam + Proton (native, FR95-96)                       │
│  ├── NVIDIA Driver 535+ (shared with K8s)                   │
│  ├── nvidia-drm.modeset=1 (PRIME support for eGPU)          │
│  └── Mode switching script: /usr/local/bin/gpu-mode         │
├─────────────────────────────────────────────────────────────┤
│  K8s Worker Layer:                                          │
│  ├── K3s agent (joins via Tailscale)                        │
│  ├── NVIDIA GPU Operator + Device Plugin                    │
│  └── vLLM pods (scaled based on mode)                       │
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

**n8n Fallback Routing (FR94, NFR54):**
```javascript
// n8n workflow: Check GPU availability before inference
const vllmHealth = await $http.get('http://vllm.ml.svc:8000/health');
if (vllmHealth.status !== 200) {
  // Fallback to Ollama CPU
  return { endpoint: 'http://ollama.ml.svc:11434', mode: 'cpu' };
}
return { endpoint: 'http://vllm.ml.svc:8000', mode: 'gpu' };
```

**NFR Compliance:**
- NFR50: vLLM health check fails within 10s when GPU unavailable
- NFR51: Gaming Mode activation <30s (kubectl scale + VRAM release)
- NFR52: Full 12GB VRAM available for 60+ FPS gaming at 1080p
- NFR53: ML Mode restoration <2min (pod startup + model load)
- NFR54: Ollama CPU maintains <5s inference latency

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

### AI Document Classification Architecture (Paperless-AI)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| AI Connector | `paperless-metadata-ollama-processor` | FR87: Connects Paperless to Ollama for auto-tagging |
| LLM Backend | Ollama on GPU worker (Intel NUC + RTX 3060) | FR88: GPU-accelerated inference for fast classification |
| Deployment | Deployment in `docs` namespace | Watches Paperless API for new documents |
| Model | Mistral 7B or Llama 3.1 8B | Balance of speed and quality for classification |

**Integration Pattern:**
```
New Document → Paperless API → Paperless-AI → Ollama (GPU) → Update Tags/Correspondent/Type
```

**Auto-populated Fields (FR89):**
- Tags: Document category, year, source
- Correspondent: Sender/organization extracted from content
- Document Type: Invoice, contract, receipt, letter, etc.

**Environment Variables:**
```yaml
env:
  PAPERLESS_URL: "http://paperless:8000"
  PAPERLESS_API_TOKEN: "<from-secret>"
  OLLAMA_URL: "http://ollama.ml.svc.cluster.local:11434"
  OLLAMA_MODEL: "mistral:7b"
```

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
│   │   └── paperless-ai-deployment.yaml # AI auto-tagging service
│   ├── stirling-pdf/
│   │   ├── values-homelab.yaml        # Stirling-PDF Helm config
│   │   └── ingress.yaml               # stirling.home.jetzinger.com
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
| Document Management (FR55-93) | `applications/paperless/`, `applications/stirling-pdf/` | values, ingress, pvc, tika, gotenberg, bridge, paperless-ai |
| Dev Containers (FR59-63) | `applications/dev-containers/` | Dockerfile, template, ssh config |

### Namespace Boundaries

| Namespace | Components | Purpose |
|-----------|------------|---------|
| `kube-system` | K3s core, Traefik | System-managed |
| `infra` | MetalLB, cert-manager | Core infrastructure |
| `monitoring` | Prometheus, Grafana, Loki, Alertmanager | Observability |
| `data` | PostgreSQL | Stateful data services |
| `apps` | n8n | General applications |
| `ml` | Ollama | AI/ML workloads |
| `docs` | Paperless-ngx, Redis | Document management |
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

**Functional Requirements:** 99/99 covered
**Non-Functional Requirements:** 54/54 covered

All requirements have explicit architectural support documented in Core Architectural Decisions and Project Structure sections.

**Requirements Updates:**
- FR55-66: Document Management (Paperless-ngx core) — covered by Document Management Architecture
- FR59-63: Dev Containers — covered by Dev Containers Architecture
- FR71-74: vLLM GPU — covered by AI/ML Architecture
- FR75-80: Paperless configuration & NFS integration — covered by Document Management Architecture
- FR81-83: Tika/Gotenberg Office docs — covered by Office Document Processing Architecture
- FR84-86: Stirling-PDF — covered by PDF Editor Architecture
- FR87-89: Paperless-AI with GPU Ollama — covered by AI Document Classification Architecture
- FR90-93: Email integration (private email/Gmail) — covered by Email Integration Architecture
- FR94: vLLM graceful degradation (host GPU usage) — covered by Dual-Use GPU Architecture
- FR95-99: Steam Gaming Platform — covered by Dual-Use GPU Architecture
- NFR50-54: Gaming Platform performance requirements — covered by Dual-Use GPU Architecture

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
- [x] Critical decisions documented (10 core decisions)
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
- 15 core architectural decisions made (added Dual-Use GPU Architecture for Steam Gaming Platform)
- 6 implementation pattern categories defined
- 8 namespace boundaries established
- 99 functional + 54 non-functional requirements supported

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

