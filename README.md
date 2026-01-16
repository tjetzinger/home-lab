# Home Lab: Production-Grade K3s Platform

A production-ready Kubernetes home lab running on Proxmox VE, demonstrating platform engineering skills through hands-on infrastructure operation. This project bridges my automotive systems engineering background with modern cloud-native technologies, showcasing the ability to design, deploy, and maintain production workloads on Kubernetes.

**Status:** ✅ Operational (20 epics complete)
**Cluster:** 5-node K3s v1.34.3+k3s1 (including GPU worker)
**Workloads:** Full ML inference stack, Document management, Workflow automation, Git hosting
**Observability:** Prometheus, Grafana, Loki, Alertmanager

---

## Why This Project?

After years working on IVI systems (In-Vehicle Infotainment) and LBS Navigation Systems—building embedded, mobile, and cloud solutions for online routing—I'm expanding into cloud-native platform engineering. This lab serves as a hands-on portfolio demonstrating Kubernetes infrastructure deployment and operations. It's a working environment that I use daily, monitor, maintain, and continuously improve.

### What Makes This Different

- **Real operational complexity**: Persistent storage, TLS certificates, load balancing, log aggregation, alerts
- **Production practices**: GitOps, ADRs, runbooks, backup/restore procedures, upgrade testing
- **AI-assisted workflow**: Leveraging Claude Code and BMAD methodology for systematic implementation
- **Engineering judgment**: Every decision documented with trade-off analysis (see [ADRs](docs/adrs/))
- **Automotive → K8s bridge**: Applying systems thinking from real-time embedded work to distributed systems

---

## Architecture Overview

### High-Level Design

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           Tailscale VPN                                  │
│                      (Remote Access Layer)                               │
└────────────────────────────┬────────────────────────────────────────────┘
                             │
┌────────────────────────────▼────────────────────────────────────────────┐
│                      Traefik Ingress                                     │
│                 (TLS Termination, Routing)                               │
└───┬─────────┬─────────┬─────────┬─────────┬─────────┬─────────┬────────┘
    │         │         │         │         │         │         │
┌───▼───┐ ┌───▼───┐ ┌───▼───┐ ┌───▼───┐ ┌───▼───┐ ┌───▼───┐ ┌───▼───┐
│Grafana│ │Open-  │ │Paper- │ │ Gitea │ │  n8n  │ │Stirling│ │ K8s   │
│       │ │WebUI  │ │less   │ │       │ │       │ │  PDF  │ │Dashbd │
└───────┘ └───┬───┘ └───┬───┘ └───────┘ └───┬───┘ └───────┘ └───────┘
              │         │                   │
         ┌────▼─────────▼───────────────────▼────┐
         │           LiteLLM Proxy               │
         │    (Unified OpenAI-compatible API)    │
         └────┬─────────────┬───────────────┬────┘
              │             │               │
         ┌────▼────┐  ┌─────▼─────┐  ┌──────▼──────┐
         │  vLLM   │  │  Ollama   │  │   OpenAI    │
         │  (GPU)  │  │  (CPU)    │  │   (Cloud)   │
         │ Primary │  │ Fallback  │  │  Emergency  │
         └────┬────┘  └───────────┘  └─────────────┘
              │
    ┌─────────▼─────────┐
    │   RTX 3060 eGPU   │
    │   (12GB VRAM)     │
    │  k3s-gpu-worker   │
    └───────────────────┘
              │
         ┌────▼────┐
         │ Postgres│──────┐
         │  (NFS)  │      │
         └─────────┘      │
                          │
              ┌───────────▼───────────┐
              │    Synology DS920+    │
              │   (NFS + k3s-nas VM)  │
              └───────────────────────┘
```

### Cluster Nodes

| Node | Role | Specs | Purpose |
|------|------|-------|---------|
| `k3s-master` | Control plane | 192.168.2.20 | API server, etcd, scheduler |
| `k3s-worker-01` | CPU worker | 192.168.2.21 | General workloads |
| `k3s-worker-02` | CPU worker | 192.168.2.22 | General workloads |
| `k3s-gpu-worker` | GPU worker | Intel NUC + RTX 3060 eGPU (12GB) | ML inference (vLLM) |
| `k3s-nas-worker` | NAS worker | Synology DS920+ VM | Storage-adjacent workloads |

### Technology Stack

| Layer | Technology | Decision Rationale |
|-------|-----------|-------------------|
| **Orchestration** | K3s v1.34.3 | Lightweight, production-ready K8s. Half the memory of k0s, built-in storage/ingress. See [ADR-001](docs/adrs/ADR-001-kubernetes-distribution-selection.md) |
| **Compute** | 5x nodes (VMs + bare metal) | Mixed: Proxmox VMs, Intel NUC with eGPU, Synology NAS VM |
| **GPU Inference** | vLLM + NVIDIA Container Toolkit | High-performance LLM serving with AWQ quantization |
| **LLM Proxy** | LiteLLM | Unified OpenAI-compatible API with automatic failover |
| **Storage** | NFS from Synology DS920+ | Existing NAS asset, CSI driver maturity, snapshot support |
| **Ingress** | Traefik (K3s bundled) | Zero-config LB, native K8s integration, automatic cert renewal |
| **TLS** | cert-manager + Let's Encrypt | Industry standard, automated renewal, staging/prod environments |
| **Load Balancer** | MetalLB (Layer 2) | Simple home network setup, no BGP complexity needed |
| **Observability** | kube-prometheus-stack + Loki | Complete stack (metrics, logs, alerting), Grafana dashboards, mobile alerts |
| **GitOps** | Git as source of truth | All manifests version-controlled, Helm values files, reproducible deployments |

**Key Design Decisions:**
- **No public exposure**: Tailscale VPN-only access (security > convenience)
- **External storage**: NFS over in-cluster solutions (leverage existing NAS investment, snapshots)
- **Three-tier ML inference**: vLLM (GPU) → Ollama (CPU) → OpenAI (cloud) with automatic failover
- **Helm for apps**: Values files over `--set` flags (version control, repeatability)
- **ADR documentation**: Every architectural choice captured with context and alternatives

See [docs/adrs/](docs/adrs/) for detailed decision records.

---

## ML Inference Stack

The cluster runs a sophisticated ML inference platform with automatic failover:

```
LiteLLM Proxy → vLLM (GPU, primary) → Ollama (CPU, fallback) → OpenAI (cloud, emergency)
```

**GPU Modes** (switchable on k3s-gpu-worker):
- `ml` - Qwen 2.5 7B AWQ (general inference, 8K context)
- `r1` - DeepSeek-R1 7B AWQ (reasoning tasks with chain-of-thought)
- `gaming` - vLLM scaled to 0, GPU released for Steam

```bash
# Check current mode
ssh k3s-gpu-worker "gpu-mode status"

# Switch modes
ssh k3s-gpu-worker "gpu-mode ml"      # General inference
ssh k3s-gpu-worker "gpu-mode r1"      # Reasoning model
ssh k3s-gpu-worker "gpu-mode gaming"  # Release GPU
```

**Consumers:**
- **Open-WebUI**: ChatGPT-like interface at https://chat.home.jetzinger.com
- **Paperless-AI**: Document classification and RAG queries
- **n8n**: Workflow automation with LLM integration

---

## Quick Start

**Prerequisites:**
- 3x VMs (2 CPU, 4GB RAM each) or bare metal nodes
- Ubuntu 22.04 LTS installed on all nodes
- Network: Static IPs assigned, nodes can reach each other
- Optional: Tailscale account for remote access
- Optional: NFS server for persistent storage
- Optional: NVIDIA GPU for ML inference

**Time to working cluster:** ~90 minutes (tested)

### Step 1: Control Plane Setup

```bash
# On k3s-master node (192.168.2.20)
git clone https://github.com/tjetzinger/home-lab.git
cd home-lab/infrastructure/k3s
chmod +x install-master.sh
sudo ./install-master.sh

# Verify control plane
sudo kubectl get nodes
sudo kubectl get pods -n kube-system
```

See [docs/implementation-artifacts/1-1-create-k3s-control-plane.md](docs/implementation-artifacts/1-1-create-k3s-control-plane.md) for detailed walkthrough.

### Step 2: Worker Nodes

```bash
# On each worker node (192.168.2.21, 192.168.2.22)
chmod +x install-worker.sh
sudo K3S_URL=https://192.168.2.20:6443 \
     K3S_TOKEN=<token-from-master> \
     ./install-worker.sh

# Verify cluster
kubectl get nodes
# Should show: k3s-master, k3s-worker-01, k3s-worker-02
```

See [docs/implementation-artifacts/1-2-add-first-worker-node.md](docs/implementation-artifacts/1-2-add-first-worker-node.md) and [1-3-add-second-worker-node.md](docs/implementation-artifacts/1-3-add-second-worker-node.md).

### Step 3: Remote Access (Optional)

```bash
# Configure local kubectl to access cluster remotely via Tailscale
./infrastructure/k3s/kubeconfig-setup.sh
kubectl get nodes  # Should work from your laptop now
```

See [docs/implementation-artifacts/1-4-configure-remote-kubectl-access.md](docs/implementation-artifacts/1-4-configure-remote-kubectl-access.md).

### Step 4: Core Infrastructure

Deploy storage, load balancing, and TLS:

```bash
# NFS Storage Provisioner
helm upgrade --install nfs-subdir-external-provisioner \
  nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
  -f infrastructure/nfs/values-homelab.yaml \
  -n kube-system

# MetalLB Load Balancer
helm upgrade --install metallb metallb/metallb \
  -f infrastructure/metallb/values-homelab.yaml \
  -n infra --create-namespace

# cert-manager for TLS
helm upgrade --install cert-manager jetstack/cert-manager \
  -f infrastructure/cert-manager/values-homelab.yaml \
  -n infra --set installCRDs=true
```

Detailed procedures: [Epic 2 stories](docs/implementation-artifacts/) (2-1 through 2-4) and [Epic 3 stories](docs/implementation-artifacts/) (3-1 through 3-5).

### Step 5: Monitoring Stack

```bash
# kube-prometheus-stack (Prometheus + Grafana + Alertmanager)
helm upgrade --install kube-prometheus-stack \
  prometheus-community/kube-prometheus-stack \
  -f monitoring/prometheus/values-homelab.yaml \
  -n monitoring --create-namespace

# Loki for log aggregation
helm upgrade --install loki grafana/loki-stack \
  -f monitoring/loki/values-homelab.yaml \
  -n monitoring

# Access Grafana
kubectl get ingress -n monitoring
# Visit https://grafana.home.jetzinger.com
```

See [Epic 4 stories](docs/implementation-artifacts/) (4-1 through 4-6) for observability setup details.

### Verification

```bash
# Check all nodes healthy
kubectl get nodes

# Check system pods running
kubectl get pods -n kube-system
kubectl get pods -n infra
kubectl get pods -n monitoring

# Verify storage class
kubectl get storageclass

# Check TLS certificates
kubectl get certificate -A

# Test ingress
curl https://grafana.home.jetzinger.com
```

---

## Repository Structure

```
home-lab/
├── infrastructure/           # Core cluster components
│   ├── k3s/                 # Control plane and worker install scripts
│   ├── nfs/                 # NFS CSI provisioner Helm values
│   ├── metallb/             # MetalLB load balancer config
│   ├── cert-manager/        # TLS certificate automation
│   └── traefik/             # Ingress controller config (K3s bundled)
│
├── applications/            # Workload deployments
│   ├── vllm/                # GPU inference engine (Qwen, DeepSeek-R1)
│   ├── litellm/             # LLM proxy with fallback chain
│   ├── ollama/              # CPU fallback inference
│   ├── open-webui/          # ChatGPT-like interface
│   ├── paperless/           # Document management (Paperless-ngx)
│   ├── paperless-ai/        # AI-powered document classification
│   ├── gitea/               # Self-hosted Git
│   ├── postgres/            # PostgreSQL database
│   ├── n8n/                 # Workflow automation
│   ├── stirling-pdf/        # PDF tools
│   ├── gotenberg/           # Document conversion
│   ├── tika/                # Content extraction
│   ├── nginx/               # Development reverse proxy
│   └── dev-containers/      # Remote development environments
│
├── monitoring/              # Observability stack
│   ├── prometheus/          # kube-prometheus-stack Helm values
│   ├── grafana/             # Grafana dashboards and datasources
│   └── loki/                # Log aggregation Helm values
│
├── scripts/                 # Automation and utilities
│   └── gpu-worker/          # GPU mode switching scripts
│
├── docs/                    # Documentation
│   ├── VISUAL_TOUR.md       # Grafana screenshots & architecture diagrams
│   ├── adrs/                # Architecture Decision Records
│   ├── runbooks/            # Operational procedures
│   ├── planning-artifacts/  # PRD, architecture, epics
│   └── implementation-artifacts/  # Story files, sprint status
│
└── _bmad/                   # BMAD AI workflow framework
```

**Key Files:**
- `docs/VISUAL_TOUR.md` - Grafana dashboard screenshots and architecture diagrams
- `infrastructure/*/values-homelab.yaml` - Helm chart customizations
- `docs/adrs/ADR-*.md` - Architectural decisions with trade-offs
- `docs/runbooks/*.md` - Operational procedures
- `docs/implementation-artifacts/*.md` - Story-by-story implementation
- `CLAUDE.md` - AI-assisted development instructions

---

## Operational Excellence

### Monitoring and Alerts

- **Metrics:** Prometheus scraping all cluster components, custom ServiceMonitors for apps
- **Dashboards:** Grafana with K8s cluster overview, node metrics, pod resources, GPU utilization
- **Logs:** Loki aggregating logs from all namespaces, queryable via Grafana
- **Alerts:** Alertmanager configured for P1 scenarios (disk full, pod crashes, certificate expiry)
- **Notifications:** Mobile push alerts via ntfy.sh for critical issues

See [Epic 4](docs/implementation-artifacts/) stories for observability implementation.

### Backup and Recovery

- **Cluster state:** etcd snapshots via K3s built-in, restored and tested
- **PostgreSQL:** pg_dump scheduled backups to NFS, restore procedure validated
- **NFS volumes:** Synology snapshot schedules (hourly, daily, weekly retention)
- **Configuration:** All manifests and Helm values in Git (infrastructure as code)

See runbooks: [cluster-backup.md](docs/runbooks/cluster-backup.md), [cluster-restore.md](docs/runbooks/cluster-restore.md), [postgres-backup.md](docs/runbooks/postgres-backup.md).

### Maintenance Procedures

- **K3s upgrades:** Tested procedure with rollback plan (see [k3s-upgrade.md](docs/runbooks/k3s-upgrade.md))
- **OS patching:** Automatic security updates via unattended-upgrades
- **Certificate renewal:** Automated via cert-manager, manual renewal documented
- **GPU mode switching:** Documented procedure for ML ↔ Gaming mode transitions

See [Epic 8](docs/implementation-artifacts/) stories for operational procedures.

---

## Development Methodology

This project demonstrates systematic AI-assisted infrastructure development using **Claude Code** and the **BMAD (Build-Measure-Achieve-Document)** methodology. Every component was implemented through structured planning, execution, and documentation cycles.

### Claude Code: AI-Powered Development

[Claude Code](https://claude.com/claude-code) is Anthropic's official CLI tool that integrates Claude AI directly into the development workflow. Unlike generic AI chat interfaces, Claude Code:

- **Understands full project context**: Reads architecture docs, PRDs, and codebase structure
- **Executes tasks autonomously**: Creates files, runs commands, validates changes
- **Follows project conventions**: Adheres to patterns defined in `CLAUDE.md` and architecture docs
- **Maintains conversation context**: Long-running sessions with automatic summarization

### BMAD Methodology: Structured Implementation

BMAD is a multi-agent AI workflow framework that enforces systematic software delivery. Located in `_bmad/`, it orchestrates the entire development lifecycle:

**Phase 1: Discovery** → Product requirements, user journeys, success criteria
**Phase 2: Architecture** → Technology selection, component design, ADRs
**Phase 3: Planning** → Epics, user stories, complexity estimation
**Phase 4: Implementation** → Story execution with gap analysis and code review

```bash
# Workflow for each story:
1. /create-story          # Generate story file from epic
2. /dev-story             # Implement with gap analysis
3. /code-review           # Adversarial quality check
4. Document & iterate     # Update ADRs, runbooks
```

**For hiring managers:** This isn't a tutorial follow-along. It's a methodology-driven project that produces production-quality infrastructure with systematic documentation. The AI accelerated delivery, but the engineering judgment, architectural decisions, and operational discipline are human.

---

## Current Workloads

| Application | Purpose | Namespace | URL |
|------------|---------|-----------|-----|
| **Grafana** | Metrics visualization | monitoring | https://grafana.home.jetzinger.com |
| **Open-WebUI** | ChatGPT-like interface | apps | https://chat.home.jetzinger.com |
| **Paperless-ngx** | Document management | docs | https://paperless.home.jetzinger.com |
| **Paperless-AI** | AI document classification | docs | https://paperless-ai.home.jetzinger.com |
| **Gitea** | Self-hosted Git | apps | https://git.home.jetzinger.com |
| **n8n** | Workflow automation | apps | https://n8n.home.jetzinger.com |
| **Stirling-PDF** | PDF tools | docs | https://pdf.home.jetzinger.com |
| **K8s Dashboard** | Cluster visualization | kubernetes-dashboard | https://dashboard.home.jetzinger.com |
| **LiteLLM** | LLM proxy | ml | https://litellm.home.jetzinger.com |
| **vLLM** | GPU inference | ml | ClusterIP only |
| **Ollama** | CPU inference | ml | ClusterIP only |
| **PostgreSQL** | Relational database | data | ClusterIP only |
| **Prometheus** | Metrics collection | monitoring | ClusterIP only |
| **Alertmanager** | Alert routing | monitoring | ClusterIP only |
| **Loki** | Log aggregation | monitoring | ClusterIP only |

---

## Links and References

### Documentation

- **Portfolio Summary:** [docs/PORTFOLIO.md](docs/PORTFOLIO.md) - High-level project summary
- **Visual Tour:** [docs/VISUAL_TOUR.md](docs/VISUAL_TOUR.md) - Screenshots and diagrams
- **Architecture Decision Records:** [docs/adrs/](docs/adrs/) - Technical choices
- **Operational Runbooks:** [docs/runbooks/](docs/runbooks/) - P1 procedures
- **Implementation Stories:** [docs/implementation-artifacts/](docs/implementation-artifacts/) - Build documentation
- **PRD and Planning:** [docs/planning-artifacts/](docs/planning-artifacts/) - Requirements and architecture

### External Resources

- **Blog Posts:** [docs/blog-posts/](docs/blog-posts/) - Technical write-ups
- **LinkedIn:** [linkedin.com/in/tjetzinger](https://www.linkedin.com/in/tjetzinger/)

### Key Technologies

- [K3s Documentation](https://docs.k3s.io/)
- [vLLM Documentation](https://docs.vllm.ai/)
- [LiteLLM Documentation](https://docs.litellm.ai/)
- [Helm Charts](https://helm.sh/)
- [kube-prometheus-stack](https://github.com/prometheus-operator/kube-prometheus)

---

## Contact and Feedback

**Tom Jetzinger**
Platform Engineering | Kubernetes | Systems Architecture

Questions about this lab, my transition from automotive to cloud-native, or how I implemented specific features? I'm happy to discuss!

- **LinkedIn:** [linkedin.com/in/tjetzinger](https://www.linkedin.com/in/tjetzinger/)
- **Email:** thomas@jetzinger.com
- **GitHub:** [@tjetzinger](https://github.com/tjetzinger)

---

## License

This project is shared for educational and portfolio purposes. Configuration files and documentation are MIT licensed. See individual component licenses for third-party software.

**Note:** Secrets, API keys, and kubeconfig files are excluded via `.gitignore`. This repository contains no sensitive credentials.
