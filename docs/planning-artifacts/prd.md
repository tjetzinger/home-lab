---
stepsCompleted: [1, 2, 3, 4, 7, 8, 9, 10, 11]
workflow_completed: true
openclaw_update_completed: '2026-01-29'
openclaw_storage_update: '2026-01-30'
inputDocuments:
  - 'docs/planning-artifacts/product-brief-home-lab-2025-12-27.md'
  - 'docs/planning-artifacts/research/domain-k8s-platform-career-positioning-research-2025-12-27.md'
  - 'docs/analysis/brainstorming-session-2025-12-27.md'
  - 'external: github.com/openclaw/openclaw'
workflowType: 'prd'
lastStep: 11
briefCount: 1
researchCount: 1
brainstormingCount: 1
projectDocsCount: 0
date: '2025-12-27'
lastUpdated: '2026-01-31'
author: 'Tom'
project_name: 'home-lab'
---

# Product Requirements Document - home-lab

**Author:** Tom
**Date:** 2025-12-27 | **Last Updated:** 2026-02-13

**Changelog:**
- 2026-02-13: Pivoted Ollama CPU fallback from qwen3:4b to phi4-mini (Microsoft Phi-4-mini 3.8B). Qwen3 thinking mode cannot be reliably disabled on CPU via Ollama, causing 5+ min classification latency vs 60s target. Phi-4-mini has no thinking overhead, superior instruction following (67.3% MMLU), ~2.5GB Q4. Updated FR206, FR207, NFR109, NFR111.
- 2026-02-12: Added Document Processing Pipeline Upgrade (FR192-FR207, NFR107-NFR116) - Replace Paperless-AI with Paperless-GPT, add Docling server for layout-aware PDF parsing, upgrade vLLM to Qwen3-8B-AWQ, upgrade Ollama to phi4-mini. Two-stage pipeline: Docling extracts structure → LLM generates metadata. Supersedes FR87-89, FR104-108, FR110, NFR46-47, NFR58-62, NFR63-64.
- 2026-01-31: Added OpenClaw long-term memory with LanceDB (FR189-FR191, NFR105-NFR106) - memory-lancedb plugin with OpenAI text-embedding-3-small for automatic memory capture and recall across conversations
- 2026-01-30: Updated OpenClaw storage architecture (FR151, FR152, FR152a, FR152b, NFR100) - Changed from NFS to local persistent storage on k3s-worker-01 to eliminate network complexity and corruption vectors; added node affinity and Velero backup requirements
- 2026-01-29: Added OpenClaw personal AI assistant (FR149-FR163, NFR86-NFR97) - Self-hosted multi-channel AI assistant on K3s with Opus 4.5 primary, LiteLLM fallback, Telegram channel, MCP research tools via mcporter (Exa)
- 2026-01-15: Added Phase 2+ requirements - Tailscale subnet routers (FR120-122, NFR71-72), Synology NAS K3s worker (FR123-125, NFR73-74), Open-WebUI chat interface (FR126-129, NFR75-76), Kubernetes Dashboard (FR130-133, NFR77-78), Gitea self-hosted Git (FR134-137, NFR79-80), DeepSeek-R1 14B reasoning mode (FR138-141, NFR81-82), LiteLLM external providers Groq/Google/Mistral (FR142-145, NFR83-84), Blog article completion (FR146-148, NFR85)
- 2026-01-14: Added ML Mode default at boot for k3s-gpu-worker (FR119, NFR70) - systemd service auto-activates vLLM after k3s agent ready
- 2026-01-14: Added LiteLLM Inference Proxy (Story 14.x) - Three-tier fallback: vLLM (GPU) → Ollama (CPU) → OpenAI (cloud). Paperless-AI uses unified LiteLLM endpoint. Added FR113-118, NFR65-69.
- 2026-01-13: Added Story 12.10 (vLLM GPU Integration for Paperless-AI) - vLLM serves qwen2.5:14b on GPU, Paperless-AI uses OpenAI-compatible endpoint, Ollama downgraded to slim models, k3s-worker-02 RAM reduced. Added FR109-112, NFR63-64. Epic 12 reopened.
- 2026-01-13: Removed Story 12.10 (GPU Ollama) - Ollama stays on CPU worker for fallback availability. Removed FR109-110, updated NFR61-62 for CPU performance
- 2026-01-13: Unified LLM Architecture - Single Qwen 2.5 14B model replaces vLLM multi-model. Updated FR38, FR72-73, FR94, FR98-99, FR104 and NFR34-38, NFR50, NFR58 for unified model
- 2026-01-11: Added Multi-Subnet GPU Worker Networking - Solution A with Tailscale mesh (FR100-103, NFR55-57)
- 2026-01-11: Added Steam Gaming Platform with mode switching for shared GPU usage (FR94-99, NFR50-54)
- 2026-01-09: Added email inbox integration for private email/Gmail with Bridge container (FR90-93, NFR48-49)
- 2026-01-09: Added Stirling-PDF and Paperless-AI with GPU Ollama (FR84-89, NFR44-47)
- 2026-01-09: Added Tika/Gotenberg Office document processing (FR81-83, NFR42-43)
- 2026-01-09: Added Paperless-ngx configuration and NFS integration requirements (FR75-80, NFR39-41)
- 2026-01-08: Added Phase 2 requirements - Paperless-ngx (FR64-66, NFR28-30), Dev Containers (FR67-70, NFR31-33), GPU ML (FR71-74, NFR34-38)
- 2026-01-08: Updated FR66 - PostgreSQL backend moved from "deferred" to Epic 10, Story 10.2 (active implementation)

## Executive Summary

**home-lab** is a production-grade Kubernetes learning platform that serves dual purposes: functional home infrastructure running real workloads AND a career portfolio demonstrating the transition from Navigation Systems Project Manager to Platform Engineer.

The project applies 10+ years of automotive distributed systems experience—OTA updates, cloud navigation services, multi-platform coordination—to modern cloud-native infrastructure patterns. Built using AI-assisted engineering practices, it showcases both hands-on infrastructure capability and effective collaboration with AI development tools.

### What Makes This Special

1. **Domain Bridge**: Direct translation of automotive expertise to platform engineering:
   - OTA updates → Kubernetes deployments
   - Cloud Navigation → Distributed platforms
   - IVI reliability → SRE practices

2. **AI-Assisted Engineering**: Entire build process documented as an AI-augmented portfolio piece, demonstrating modern engineering workflows

3. **Production Mindset**: Not toy examples—real services (AI inference, observability, databases), real constraints (hardware limits, network architecture), real decisions (documented ADRs)

4. **Complete Narrative**: End-to-end documentation from brainstorming through running cluster, providing proof of capability beyond certifications

5. **Dual Purpose**: Simultaneously a learning platform for skill acquisition AND functional home infrastructure running daily workloads

## OpenClaw - Personal AI Assistant

**home-lab** extends beyond infrastructure and inference backends into a self-hosted personal AI assistant. OpenClaw provides an always-available AI companion accessible through Telegram, powered by Claude Opus 4.5 via Anthropic OAuth (Claude Code subscription) with automatic fallback to the existing LiteLLM local inference stack.

The assistant integrates MCP research tools via mcporter (Exa and others) for real-time web research, making it a capable research partner rather than just a chat interface. Running as a containerized workload on K3s, OpenClaw inherits the cluster's existing Tailscale mesh networking -- no additional VPN configuration required.

### What Makes OpenClaw Special

1. **Frontier AI on your own terms**: Opus 4.5 as primary brain with local LiteLLM fallback -- best reasoning available, with graceful degradation when the cloud is unavailable
2. **Telegram as interface**: No web UI to open -- interact with your AI assistant from the same app you already use for messaging
3. **Research-capable**: MCP tools via mcporter (Exa, etc.) give the assistant real web research abilities, not just model knowledge
4. **Zero-config networking**: Gateway runs on K3s and inherits the cluster's existing Tailscale mesh -- accessible from any Tailscale device, no public exposure
5. **Portfolio differentiator**: Demonstrates end-to-end AI infrastructure -- from GPU inference to proxy routing to a personal assistant consumers can understand

### OpenClaw Technical Stack

- **Runtime:** Node.js >= 22
- **LLM:** Anthropic Claude Opus 4.5 (OAuth, Claude Code subscription)
- **Fallback:** LiteLLM proxy (vLLM GPU -> Ollama CPU)
- **Channel:** Telegram (long polling, no inbound exposure needed)
- **MCP Tools:** mcporter with Exa research + additional research servers
- **Gateway:** WebSocket control plane on K3s
- **Ingress:** `openclaw.home.jetzinger.com` via Traefik (gateway control UI)
- **Networking:** Inherited from cluster Tailscale mesh (no additional config)
- **Deployment:** Docker container on K3s, `apps` namespace
- **Storage:** Persistent volume for `~/.clawdbot` config + workspace data

## Project Classification

**Technical Type:** Infrastructure/DevOps (Kubernetes home lab)
**Domain:** General with ML/AI workloads
**Complexity:** Medium
**Project Context:** Greenfield - new infrastructure build

**Technical Stack:**
- Orchestration: K3s on Proxmox VMs
- Storage: NFS via Synology DS920+
- Networking: Traefik ingress, MetalLB, Tailscale
- Observability: Prometheus, Grafana
- AI/ML: vLLM (Qwen3-8B-AWQ GPU), Ollama (phi4-mini CPU fallback), LiteLLM proxy, n8n
- GPU: NVIDIA RTX 3060 via eGPU (future)
- Gaming: Steam + Proton on Intel NUC host OS (shared GPU with K8s)
- Document Management: Paperless-ngx, Paperless-GPT, Docling (Granite-Docling 258M)
- Development: Dev Containers via Nginx proxy (VS Code + Claude Code)

## Success Criteria

### User Success Definition

**Aha Moments** - The project succeeds when:

1. **`kubectl get pods` moment**: Running `kubectl get pods` and seeing all services healthy across the cluster—proof that you built and operate real infrastructure, not just followed tutorials

2. **Recruiter mention moment**: Receiving a message from a recruiter or hiring manager that explicitly references the home-lab portfolio—validation that the career bridge strategy works

### Business Success (Career Objectives)

| Metric | Target | Timeline |
|--------|--------|----------|
| Job offer | Senior Platform Engineer / MLOps role | 6 months |
| Salary target | $180K-$250K range (or equivalent) | With offer |
| Inbound recruiter interest | 2+ messages/month citing portfolio | Ongoing |
| Interview confidence | Fluent architecture discussion | Before interviews |

### Technical Success

| Metric | Target | Measurement |
|--------|--------|-------------|
| Cluster uptime | 95%+ | Prometheus alerts |
| All planned services | Deployed and healthy | `kubectl get pods` |
| GPU workloads | Ollama (Qwen 2.5 14B) responding | API health checks |
| Storage reliability | No data loss | NFS mount status |
| Component explanation | 100% of infrastructure | Self-assessment |

### Measurable Outcomes

**Leading Indicators (predict success):**
- Weekly GitHub commits (active development)
- Content publishing cadence (1-2 posts/month)
- LinkedIn profile views trend (visibility growth)

**Lagging Indicators (confirm success):**
- Job offer received citing portfolio
- "Saw your home-lab project" in recruiter message
- Interview questions based on portfolio content

### Product Scope

**MVP (Minimum Viable Product):**
- K3s cluster: control plane + 2 workers
- Full infrastructure stack: NFS, Traefik, MetalLB
- Observability: Prometheus + Grafana
- Data: PostgreSQL StatefulSet
- AI workloads: Ollama operational
- Dev tooling: Nginx reverse proxy
- Portfolio: GitHub repo public, first blog post published

**Growth Phase:**
- GPU worker with NVIDIA Operator
- GPU-accelerated Ollama (Qwen 2.5 14B)
- Rancher cluster management
- n8n workflow automation
- GitOps (ArgoCD/Flux)
- CKA certification achieved

**Vision:**
- Complete CKA + CKS certifications
- Published case study on AI-assisted infrastructure building
- Community following from career transition content
- Ongoing experimentation platform for emerging technologies

## User Journeys

### Journey 1: Tom the Builder - First Cluster Victory

Tom has been a Navigation Systems PM for over a decade, coordinating complex distributed systems across millions of vehicles. He knows distributed architecture deeply—but through specifications, vendor meetings, and architecture reviews. Not through `kubectl`. When recruiters ask "have you built infrastructure?" he hesitates. Certifications feel hollow. Tutorials feel like painting by numbers.

One Friday evening, Tom opens his terminal in the basement office. The Proxmox host hums quietly. He's read about K3s for weeks. Tonight, he builds.

The first VM spins up—`k3s-master` at 192.168.2.20. A single curl command. His heart races watching the installation scroll by. Then the moment: `kubectl get nodes`. One node. Ready. He built that.

Saturday morning, he adds the first worker. `kubectl get nodes` now shows two. He deploys nginx—watches it schedule to the worker, not the master. He understands *why* it scheduled there because he configured it that way. This isn't a tutorial telling him what to type. This is his cluster, his decisions.

By Sunday evening, Traefik serves HTTPS traffic to `hello.home.jetzinger.com`. He shows his wife on her phone—a real website, running on infrastructure he built in their basement. The domains of automotive OTA and Kubernetes deployments suddenly collapse into one understanding: they're the same distributed systems problem, just different tools.

**Requirements revealed:** VM provisioning documentation, network configuration, incremental deployment path, validation checkpoints.

### Journey 2: Tom the Operator - 2am Incident Response

Three months in. Tom's cluster runs Ollama, Prometheus, PostgreSQL, and a dozen other services. It's become infrastructure he relies on daily.

At 2:17am, his phone buzzes. Alertmanager: "PostgreSQL pod CrashLoopBackOff." Half-asleep, Tom reaches for his laptop. Tailscale connects him to the home network from bed.

`kubectl get pods -n data` — PostgreSQL is cycling. `kubectl describe pod` reveals: NFS mount timeout. The Synology had rebooted for a firmware update.

Tom's automotive instincts kick in. This is the same pattern as vehicle-cloud sync failures—when the backend goes away, clients retry with backoff. He checks the NFS provisioner logs, sees it reconnecting. He knows not to panic-restart everything.

Within 10 minutes, NFS recovers. PostgreSQL stabilizes. Tom adds a runbook entry: "NFS recovery procedure" and tweaks the Prometheus alert to include Synology health. He falls back asleep knowing he diagnosed and resolved a real production incident—exactly the story he'll tell in interviews.

**Requirements revealed:** Monitoring stack, alerting, remote access via Tailscale, runbooks, service dependency mapping.

### Journey 3: Tom the Career Showcaser - The Recruiter Message

Four months into the build. Tom's GitHub repo has 47 stars. His dev.to article "From OTA Updates to GitOps: What Navigation Systems Taught Me About Kubernetes" got 2,400 views. LinkedIn shows 89 profile views this week—up 340% from before.

Tuesday morning, a LinkedIn message: "Hi Tom, I'm hiring for a Senior Platform Engineer at [SDV Startup]. Your home-lab project caught my attention—especially the automotive background combined with hands-on K8s. Would you be open to a conversation?"

Tom smiles. This is the moment. Not "saw your CKA certification" but "saw your home-lab project."

The interview goes differently than his previous attempts. When asked about StatefulSet challenges, he doesn't recite documentation—he tells the PostgreSQL NFS story. When asked about monitoring, he shares his Grafana dashboard screenshots. When asked "why should we hire you over someone with more K8s years?" he explains how coordinating OTA updates across 3 million vehicles taught him distributed systems thinking that no amount of cluster time replaces.

The offer comes two weeks later. Senior Platform Engineer. The salary meets his target. The hiring manager's feedback: "We loved that he built real infrastructure and could explain every decision."

**Requirements revealed:** Public GitHub repository, technical blog content, ADRs, visual proof (dashboards), narrative connecting automotive to K8s.

### Journey 4: The Hiring Manager - Portfolio Discovery

Sarah leads Platform Engineering at an SDV startup. She's reviewed 47 resumes this month. Most blur together: CKA certified, 3 years Kubernetes, "passionate about cloud-native." Same keywords, no differentiation.

She opens Tom's LinkedIn from a referral. The headline catches her: "Navigation Systems → Platform Engineering." Automotive background? Interesting. She clicks through to the GitHub link.

The README isn't a wall of commands—it's a story. Problem statement, architecture decisions, lessons learned. She clicks into the `/docs/adrs` folder. ADR-003: "Why NFS over Longhorn" shows genuine trade-off analysis. This person thinks, not just executes.

The Grafana screenshots show real metrics from real services. The blog post about translating OTA patterns to Kubernetes deployments demonstrates deep understanding of both domains. This isn't tutorial completion—this is engineering judgment.

Sarah forwards Tom's profile to her team with a note: "Interview this one. He actually built something and can explain why."

**Requirements revealed:** Professional README, ADRs with rationale, visible running infrastructure, domain-bridging content, navigable repository structure.

### Journey Requirements Summary

| Journey | Key Capabilities Required |
|---------|--------------------------|
| Builder - First Victory | Documented setup path, incremental deployment, validation checkpoints |
| Operator - Incident | Monitoring stack, alerting, remote access, runbooks, dependency mapping |
| Career Showcaser | GitHub presence, blog content, ADRs, visual proof, narrative structure |
| Portfolio Audience | Professional documentation, easy navigation, clear decision rationale |

## Infrastructure Requirements

### Cluster Architecture

**Topology:** Multi-node, single master (learning-focused, not HA)

| Node | Role | IP | Resources |
|------|------|-----|-----------|
| k3s-master | Control plane | 192.168.2.20 | 2 vCPU, 4GB RAM, 32GB disk |
| k3s-worker-01 | General compute | 192.168.2.21 | 4 vCPU, 8GB RAM, 50GB disk |
| k3s-worker-02 | General compute | 192.168.2.22 | 4 vCPU, 8GB RAM, 50GB disk |
| k3s-gpu-worker | GPU/ML workloads | 192.168.0.25 (Tailscale: 100.x.x.d) | Intel NUC + RTX 3060 eGPU (different subnet) |

**Outside Cluster (by design):**
- Raspberry Pi (192.168.2.162): VPN rescue hatch—if cluster dies, remote access survives
- Synology DS920+ (192.168.2.2): NFS storage provider, 8.8TB RAID1

### Networking Architecture

| Component | Solution | Rationale |
|-----------|----------|-----------|
| CNI | Flannel (K3s default) | Start simple, swap if needed |
| Ingress | Traefik (K3s default) | Built-in, dashboard, automatic HTTPS |
| Load Balancer | MetalLB | Required for bare-metal LoadBalancer services |
| LB IP Pool | 192.168.2.100-120 | Reserved range on home subnet |
| Remote Access | Tailscale mesh (Solution A) | All K3s nodes run Tailscale for cross-subnet GPU worker |
| DNS | NextDNS with Rewrites | *.home.jetzinger.com → cluster ingress |
| TLS | cert-manager + Let's Encrypt | Automatic HTTPS for all services |

**Multi-Subnet Networking (Solution A):**

Intel NUC GPU worker is on 192.168.0.0/24, K3s cluster on 192.168.2.0/24. To enable pod networking across subnets:

| Node | Physical IP | Tailscale IP | Role |
|------|-------------|--------------|------|
| k3s-master | 192.168.2.20 | 100.x.x.a | Control plane |
| k3s-worker-01 | 192.168.2.21 | 100.x.x.b | General compute |
| k3s-worker-02 | 192.168.2.22 | 100.x.x.c | General compute |
| Intel NUC | 192.168.0.25 | 100.x.x.d | GPU worker |

K3s config: `--flannel-iface tailscale0 --node-external-ip <tailscale-ip>`

### Storage Architecture

| Type | Provider | Use Case |
|------|----------|----------|
| NFS (primary) | Synology DS920+ | Persistent volumes, shared data |
| Local-path | K3s default | Ephemeral, non-critical workloads |
| PVC Strategy | Dynamic provisioning | NFS CSI driver with StorageClass |

**Design Decision:** NFS over distributed storage (Longhorn/Rook) because Synology handles redundancy, simpler to operate, and sufficient for home lab scale.

### Namespace Strategy

| Namespace | Purpose | Resource Limits |
|-----------|---------|-----------------|
| `kube-system` | K3s core components | Default |
| `infra` | Traefik, MetalLB, cert-manager | Moderate |
| `monitoring` | Prometheus, Grafana, Alertmanager | Moderate |
| `data` | PostgreSQL, future databases | High memory |
| `apps` | General applications, n8n | Moderate |
| `ml` | Ollama (Qwen 2.5 14B), GPU workloads | GPU-enabled, high resources |
| `docs` | Paperless-ngx, Redis | Moderate |
| `dev` | Nginx reverse proxy, dev containers, git worktrees | High |

### Security Model

| Concern | Approach |
|---------|----------|
| Secrets | Native K8s secrets (initial), Sealed Secrets (future) |
| Network Policies | Default allow (learning phase), progressive tightening |
| RBAC | Cluster-admin for Tom (single user) |
| External Access | Tailscale only, no public exposure except via ingress |
| TLS | Enforced for all ingress routes |

### Observability Stack

| Component | Role | Integration |
|-----------|------|-------------|
| Prometheus | Metrics collection | ServiceMonitors for all workloads |
| Grafana | Visualization | Pre-built dashboards + custom |
| Alertmanager | Alert routing | Phone notifications via Pushover/Slack |
| Node Exporter | Node metrics | DaemonSet on all nodes |
| kube-state-metrics | K8s object metrics | Cluster-wide |

**Alert Priorities:**
- P1: Node down, PostgreSQL unhealthy, NFS unreachable
- P2: Pod CrashLoopBackOff, high memory pressure
- P3: Certificate expiry warning, disk usage >80%

### GPU/ML Infrastructure

| Component | Specification |
|-----------|---------------|
| Hardware | Intel NUC11TNKi5 + RTX 3060 eGPU (12GB VRAM) |
| Operator | NVIDIA GPU Operator |
| Scheduling | Dedicated `ml` namespace with GPU resource requests |
| Primary Workloads | Ollama (Qwen 2.5 14B unified inference) |
| Resource Strategy | GPU exclusive to ML namespace |

### Backup & Recovery

| What | How | Frequency |
|------|-----|-----------|
| Cluster state | Velero + NFS backend | Daily |
| PostgreSQL | pg_dump to NFS | Daily |
| Persistent volumes | Synology snapshots | Hourly |
| Configuration | Git repository | Every change |

**Recovery Priority:**
1. Control plane (rebuild from scratch if needed)
2. Stateful workloads (PostgreSQL, configs)
3. Stateless workloads (redeploy from manifests)

### Upgrade Strategy

| Component | Approach |
|-----------|----------|
| K3s | Manual upgrade, one node at a time, test in place |
| Applications | Helm chart version bumps via Renovate (future) |
| Node OS | Ubuntu unattended-upgrades for security only |
| Breaking changes | Test on worker-02 first, promote if stable |

## Scoping & Phased Development

### MVP Strategy

**Approach:** Platform MVP - Build foundation that demonstrates capability

**Philosophy:** The "product" is both the infrastructure AND the portfolio documenting it. MVP success means a working cluster that can be shown to hiring managers.

**Resource Model:** Solo builder, weekend implementation, AI-assisted engineering

### Phase 1: MVP Scope

**Core Infrastructure:**
- K3s cluster: 1 control plane + 2 workers (VMs on Proxmox)
- NFS storage via Synology DS920+
- Traefik ingress with HTTPS (cert-manager + Let's Encrypt)
- MetalLB for LoadBalancer services

**Observability:**
- Prometheus metrics collection
- Grafana dashboards
- Alertmanager for notifications

**Workloads:**
- PostgreSQL StatefulSet with NFS persistence
- Ollama for LLM inference
- Nginx reverse proxy to local dev servers
- Paperless-ngx for document management (Redis + NFS storage)
- Dev containers via Nginx proxy for VS Code remote + Claude Code

**Portfolio Deliverables:**
- Public GitHub repository with documentation
- First technical blog post published
- Architecture Decision Records (ADRs)

**MVP Success Criteria:**
- All nodes showing Ready status
- All planned services healthy
- Remote access working via Tailscale
- At least one recruiter/hiring manager views portfolio

### Phase 2: Growth Scope

- Intel NUC with RTX 3060 eGPU as GPU worker
- NVIDIA GPU Operator for GPU scheduling
- GPU-accelerated Ollama inference
- Rancher for cluster management UI
- n8n for workflow automation
- GitOps implementation (ArgoCD or Flux)
- CKA certification achieved

### Phase 3: Vision Scope

- CKS certification
- Published case study: "Building Production-Grade Infrastructure with AI-Assisted Engineering"
- Self-hosted blog running on cluster
- Community following from content
- Advanced ML/RAG pipelines

### Risk Mitigation

| Risk | Impact | Mitigation |
|------|--------|------------|
| NFS bottleneck | Medium | Monitor performance, Longhorn as backup plan |
| GPU complexity | Low | Deferred to Phase 2, MVP works without GPU |
| Hardware delays | Low | MVP runs entirely on VMs |
| Time constraints | Medium | Phased weekend approach, one topic at a time |
| Portfolio invisibility | High | Publish early, iterate publicly, share on LinkedIn |

## Functional Requirements

### Cluster Operations

- FR1: Operator can deploy a K3s control plane on a dedicated VM
- FR2: Operator can add worker nodes to the cluster
- FR3: Operator can remove worker nodes from the cluster without data loss
- FR4: Operator can view cluster node status and health
- FR5: Operator can access the cluster remotely via Tailscale
- FR6: Operator can run kubectl commands from any Tailscale-connected device

### Workload Management

- FR7: Operator can deploy containerized applications to the cluster
- FR8: Operator can deploy applications using Helm charts
- FR9: Operator can expose applications via ingress with HTTPS
- FR10: Operator can configure automatic TLS certificate provisioning
- FR11: Operator can assign workloads to specific namespaces
- FR12: Operator can scale deployments up or down
- FR13: Operator can view pod logs and events

### Storage Management

- FR14: Operator can provision persistent volumes from NFS storage
- FR15: Operator can create PersistentVolumeClaims for applications
- FR16: System provisions storage dynamically via StorageClass
- FR17: Operator can verify storage mount health
- FR18: Operator can backup persistent data to Synology snapshots

### Networking & Ingress

- FR19: Operator can expose services via LoadBalancer using MetalLB
- FR20: Operator can configure ingress routes via Traefik
- FR21: Operator can access services via *.home.jetzinger.com domain
- FR22: System resolves internal DNS via NextDNS rewrites
- FR23: Operator can view Traefik dashboard for ingress status

### Observability

- FR24: Operator can view cluster metrics in Grafana dashboards
- FR25: Operator can query Prometheus for historical metrics
- FR26: System collects metrics from all nodes via Node Exporter
- FR27: System collects Kubernetes object metrics via kube-state-metrics
- FR28: System sends alerts via Alertmanager when thresholds exceeded
- FR29: Operator can receive mobile notifications for P1 alerts
- FR30: Operator can view alert history and status

### Data Services

- FR31: Operator can deploy PostgreSQL as a StatefulSet
- FR32: PostgreSQL persists data to NFS storage
- FR33: Operator can backup PostgreSQL to NFS
- FR34: Operator can restore PostgreSQL from backup
- FR35: Applications can connect to PostgreSQL within cluster

### AI/ML Workloads

- FR36: Operator can deploy Ollama for LLM inference
- FR37: Applications can query Ollama API for completions
- FR38: Operator can deploy Ollama with Qwen 2.5 14B for unified GPU inference
- FR39: GPU workloads can request GPU resources via NVIDIA Operator
- FR40: Operator can deploy n8n for workflow automation
- FR71: GPU worker (Intel NUC + RTX 3060 eGPU) joins cluster via Tailscale mesh (Solution A: all nodes run Tailscale)
- FR72: Ollama serves Qwen 2.5 14B as unified model for all inference tasks (code, classification, general)
- FR73: GPU Ollama gracefully degrades to CPU Ollama when GPU worker unavailable
- FR74: Operator can hot-plug GPU worker (add/remove on demand without cluster disruption)
- FR94: Ollama gracefully degrades to CPU when GPU is unavailable due to host workloads (Steam gaming)

### Document Management Configuration (Paperless-ngx)

- FR75: Paperless-ngx configured for single-user operation with folder-based organization via consume subdirectories
- FR76: Duplicate documents automatically detected and rejected on import

### Workstation Integration (Paperless-ngx)

- FR77: Operator can mount Paperless consume folders via NFS from local workstation
- FR78: Scanner/desktop uploads to consume folders auto-imported within 30 seconds

### Security Hardening (Paperless-ngx)

- FR79: CSRF protection enabled for Paperless-ngx web interface
- FR80: CORS restricted to authorized origins only

### Office Document Processing (Paperless-ngx)

- FR81: Apache Tika deployed for text/metadata extraction from Office documents
- FR82: Gotenberg deployed for Office-to-PDF conversion
- FR83: Paperless-ngx imports Word, Excel, PowerPoint, and LibreOffice formats directly

### PDF Editor Integration (Stirling-PDF)

- FR84: Stirling-PDF deployed via Helm chart for PDF manipulation
- FR85: User can split, merge, rotate, and compress PDFs via web interface
- FR86: Stirling-PDF accessible via ingress with HTTPS

### AI-Powered Document Classification (Paperless-AI) — SUPERSEDED by Epic 25

- FR87: ~~Paperless-AI deployed connecting Paperless-ngx to Ollama on GPU worker~~ → Superseded by FR192 (Paperless-GPT)
- FR88: ~~Documents auto-tagged using LLM-based classification via GPU-accelerated inference~~ → Superseded by FR195
- FR89: ~~Correspondents and document types auto-populated from document content~~ → Superseded by FR195
- FR104: ~~Ollama configured with Qwen 2.5 14B model for reliable JSON-structured document metadata extraction~~ → Superseded by FR199, FR201
- FR105: ~~Paperless-AI model configurable via ConfigMap without code changes~~ → Superseded by FR196
- FR106: ~~clusterzx/paperless-ai deployed with web-based configuration UI~~ → Superseded by FR192
- FR107: ~~RAG-based document chat enables natural language queries across document archive~~ → Removed (RAG chat not in scope for Paperless-GPT)
- FR108: ~~Document classification rules configurable via web interface~~ → Superseded by FR196

### Document Processing Pipeline Upgrade (Epic 25)

#### Paperless-GPT Deployment

- FR192: Paperless-GPT deployed in `docs` namespace replacing Paperless-AI as the AI document processing tool
- FR193: Paperless-GPT configured with Docling as OCR provider (`OCR_PROVIDER=docling`)
- FR194: Paperless-GPT connected to LiteLLM proxy for LLM inference (`LLM_PROVIDER=openai`, endpoint `http://litellm.ml.svc.cluster.local:4000/v1`)
- FR195: Documents auto-classified with title, tags, correspondent, document type, and custom fields via LLM
- FR196: Prompt templates customizable via Paperless-GPT web UI without pod restart
- FR197: Paperless-GPT supports manual review workflow via `paperless-gpt` tag and automatic processing via `paperless-gpt-auto` tag
- FR198: Paperless-GPT accessible via ingress at `paperless-gpt.home.jetzinger.com` with HTTPS

#### Docling Server Deployment

- FR199: Docling server deployed in `docs` namespace with Granite-Docling 258M VLM pipeline (`DOCLING_OCR_PIPELINE=vlm`)
- FR200: Docling provides layout-aware PDF parsing preserving table structure, code blocks, equations, and reading order
- FR201: Docling outputs structured markdown/JSON consumed by Paperless-GPT for LLM metadata generation
- FR202: Docling runs on CPU (no GPU required) with minimal resource footprint

#### vLLM Qwen3 Upgrade

- FR203: vLLM image upgraded from `v0.5.5` to `v0.10.2+` for Qwen3 model support
- FR204: vLLM ML-mode model upgraded from `Qwen/Qwen2.5-7B-Instruct-AWQ` to `Qwen/Qwen3-8B-AWQ`
- FR205: LiteLLM configmap updated with Qwen3-8B-AWQ model path for `vllm-qwen` alias (downstream apps unaffected)

#### Ollama Qwen3 Upgrade

- FR206: Ollama model upgraded from `qwen2.5:3b` to `phi4-mini` (Microsoft Phi-4-mini 3.8B) for improved CPU fallback quality
- FR207: LiteLLM configmap updated with `phi4-mini` model for `ollama-qwen` alias

#### Paperless-AI Removal

- FR208: Paperless-AI deployment, configmap, service, and ingress removed from `docs` namespace

### vLLM GPU Integration (Story 12.10) — Partially Superseded by Epic 25

- FR109: ~~vLLM deployed with qwen2.5:14b model on GPU worker~~ → Superseded by FR204 (Qwen3-8B-AWQ)
- FR110: ~~Paperless-AI configured with `AI_PROVIDER=custom` pointing to LiteLLM~~ → Superseded by FR194 (Paperless-GPT → LiteLLM)
- FR111: ~~Ollama serves slim models (llama3.2:1b, qwen2.5:3b) as first fallback tier~~ → Superseded by FR206 (phi4-mini)
- FR112: k3s-worker-02 resources reduced from 32GB to 8GB RAM after vLLM migration (unchanged)

### LiteLLM Inference Proxy (Story 14.x)

- FR113: LiteLLM proxy deployed in `ml` namespace providing unified OpenAI-compatible endpoint
- FR114: LiteLLM configured with three-tier fallback: vLLM (GPU) → Ollama (CPU) → OpenAI (cloud)
- FR115: ~~Paperless-AI configured to use LiteLLM endpoint~~ → Superseded by FR194 (Paperless-GPT → LiteLLM)
- FR116: LiteLLM automatically routes to next fallback tier when primary backend health check fails
- FR117: OpenAI API key stored securely via Kubernetes secret for cloud fallback tier
- FR118: LiteLLM exposes Prometheus metrics for inference routing and fallback events

### Email Inbox Integration (Paperless-ngx)

- FR90: Paperless-ngx monitors private email inbox via IMAP for document attachments
- FR91: Paperless-ngx monitors Gmail inbox via IMAP for document attachments
- FR92: Email attachments (PDF, Office docs) auto-imported into document library
- FR93: Email bridge deployed as container providing IMAP access for private email providers

### Gaming Platform (Steam)

- FR95: Intel NUC runs Steam on host Ubuntu OS (not containerized)
- FR96: Steam uses Proton for Windows game compatibility
- FR97: Operator can switch between Gaming Mode and ML Mode via script
- FR98: Gaming Mode scales Ollama pods to 0 and enables CPU fallback
- FR99: ML Mode restores GPU Ollama pods when Steam/gaming exits
- FR119: k3s-gpu-worker boots into ML Mode by default via systemd service (vLLM scaled to 1 at startup)

### Multi-Subnet GPU Worker Networking (Solution A)

- FR100: All K3s nodes (master, workers, GPU worker) run Tailscale for full mesh connectivity
- FR101: K3s configured with `--flannel-iface tailscale0` to route pod network over Tailscale mesh
- FR102: K3s nodes advertise Tailscale IPs via `--node-external-ip` for cross-subnet communication
- FR103: NO_PROXY environment includes Tailscale CGNAT range (100.64.0.0/10) on all nodes

### Development Proxy

- FR41: Operator can configure Nginx to proxy to local dev servers
- FR42: Developer can access local dev servers via cluster ingress
- FR43: Operator can add/remove proxy targets without cluster restart

### Cluster Maintenance

- FR44: Operator can upgrade K3s version on nodes
- FR45: Operator can backup cluster state via Velero
- FR46: Operator can restore cluster from Velero backup
- FR47: System applies security updates to node OS automatically
- FR48: Operator can view upgrade history and rollback if needed

### Portfolio & Documentation

- FR49: Audience can view public GitHub repository
- FR50: Audience can read architecture decision records (ADRs)
- FR51: Audience can view Grafana dashboard screenshots
- FR52: Audience can read technical blog posts about the build
- FR53: Operator can document decisions as ADRs in repository
- FR54: Operator can publish blog posts to dev.to or similar platform

### Document Management (Paperless-ngx)

- FR55: Operator can deploy Paperless-ngx with Redis backend
- FR56: Paperless-ngx persists documents to NFS storage
- FR57: User can access Paperless-ngx via ingress with HTTPS
- FR58: User can upload, tag, and search scanned documents
- FR64: Paperless-ngx performs OCR on uploaded documents with German and English language support
- FR65: System handles thousands of documents with ongoing scanning and manual upload workflow
- FR66: Paperless-ngx uses PostgreSQL backend for metadata storage (Epic 10, Story 10.2)

### Dev Containers

- FR59: Nginx proxy routes to dev containers in `dev` namespace
- FR60: Operator can provision dev containers with git worktree support
- FR61: Developer can connect VS Code to dev container via Nginx proxy
- FR62: Developer can run Claude Code inside dev containers
- FR63: Dev containers use local storage for workspace data
- FR67: Dev containers use single base image with Node.js, Python, Claude Code CLI, git, kubectl, helm
- FR68: Each dev container allocated 2 CPU cores and 4GB RAM
- FR69: Dev containers mount persistent 10GB volumes for workspace data
- FR70: Dev containers isolated via NetworkPolicy (accessible only via nginx proxy)

### Tailscale Subnet Router

- FR120: k3s-master configured as Tailscale subnet router advertising 192.168.2.0/24 to Tailscale network
- FR121: k3s-gpu-worker configured as Tailscale subnet router advertising 192.168.0.0/24 to Tailscale network
- FR122: Tailscale ACLs configured to allow subnet route access for authorized users

### Synology NAS K3s Worker

- FR123: K3s worker VM deployed on Synology DS920+ using Virtual Machine Manager
- FR124: NAS worker node labeled for lightweight/storage-adjacent workloads only
- FR125: NAS worker node tainted to prevent general workload scheduling

### Open-WebUI Application

- FR126: Open-WebUI deployed in `apps` namespace with persistent storage for chat history
- FR127: Open-WebUI configured to use LiteLLM as backend for unified model access
- FR128: Open-WebUI accessible via ingress at `chat.home.jetzinger.com` with HTTPS
- FR129: Open-WebUI supports switching between local models (vLLM, Ollama) and external providers (Groq, Google, Mistral)

### Kubernetes Dashboard

- FR130: Kubernetes Dashboard deployed in `infra` namespace
- FR131: Dashboard accessible via ingress at `dashboard.home.jetzinger.com` with HTTPS
- FR132: Dashboard authentication via bearer token or Tailscale identity
- FR133: Dashboard provides read-only view of all namespaces, pods, and resources

### Gitea Self-Hosted Git

- FR134: Gitea deployed in `dev` namespace with PostgreSQL backend
- FR135: Gitea accessible via ingress at `git.home.jetzinger.com` with HTTPS
- FR136: Gitea persists repositories and data to NFS storage
- FR137: Gitea configured for single-user operation with SSH key authentication

### DeepSeek-R1 14B Reasoning Mode

- FR138: DeepSeek-R1 14B model deployed via vLLM on GPU worker for reasoning tasks
- FR139: R1-Mode added as third GPU mode alongside ML-Mode and Gaming-Mode
- FR140: Mode switching script updated to support R1-Mode (scales vLLM to DeepSeek-R1 model)
- FR141: LiteLLM configured with DeepSeek-R1 as reasoning-tier model

### LiteLLM External Providers

- FR142: LiteLLM configured with Groq free tier as parallel model option (not fallback)
- FR143: LiteLLM configured with Google AI Studio (Gemini) free tier as parallel model option
- FR144: LiteLLM configured with Mistral API free tier as parallel model option
- FR145: API keys for external providers stored securely via Kubernetes secrets

### Blog Article Completion (Epic 9)

- FR146: Technical blog post published covering Phase 1 MVP and new feature additions
- FR147: Blog post includes architecture diagrams, ADR references, and Grafana screenshots
- FR148: Blog post documents AI-assisted engineering workflow used throughout project

## Non-Functional Requirements

### Reliability

- NFR1: Cluster achieves 95%+ uptime measured monthly
- NFR2: Control plane recovers from VM restart within 5 minutes
- NFR3: Worker node failure does not cause service outage (pods reschedule)
- NFR4: NFS storage remains accessible during Synology firmware updates
- NFR5: Alertmanager sends P1 alerts within 1 minute of threshold breach
- NFR6: Cluster state can be restored from Velero backup within 30 minutes

### Security

- NFR7: All ingress traffic uses TLS 1.2+ with valid certificates
- NFR8: Cluster API access requires Tailscale VPN connection
- NFR9: No services exposed to public internet without ingress authentication
- NFR10: Kubernetes secrets encrypted at rest (K3s default)
- NFR11: Node OS security updates applied within 7 days of release
- NFR12: kubectl access requires valid kubeconfig (no anonymous access)

### Performance

- NFR13: Ollama API responds within 30 seconds for typical prompts
- NFR14: Grafana dashboards load within 5 seconds
- NFR15: Pod scheduling completes within 30 seconds of deployment
- NFR16: NFS-backed PVCs mount within 10 seconds
- NFR17: Traefik routes requests with <100ms added latency

### Operability

- NFR18: All cluster components emit Prometheus metrics
- NFR19: Pod logs retained for 7 days minimum
- NFR20: K3s upgrades complete with zero data loss
- NFR21: New services deployable without cluster restart
- NFR22: Runbooks exist for all P1 alert scenarios
- NFR23: Single operator can manage entire cluster (no team required)

### Documentation Quality

- NFR24: All architecture decisions documented as ADRs
- NFR25: README provides working cluster setup in <2 hours
- NFR26: All deployed services have documented purpose and configuration
- NFR27: Repository navigable by external reviewer (hiring manager)

### Document Management (Paperless-ngx)

- NFR28: Paperless-ngx OCR processes German and English text with 95%+ accuracy
- NFR29: Document library scales to 5,000+ documents without performance degradation
- NFR30: Document search returns results within 3 seconds for full-text queries

### Dev Containers

- NFR31: Dev container provisioning completes within 90 seconds (image pull + volume mount)
- NFR32: Persistent volumes retain workspace data across container restarts
- NFR33: Dev containers isolated via NetworkPolicy (no cross-container communication)

### GPU/ML Infrastructure

- NFR34: Ollama achieves 35-40 tokens/second for Qwen 2.5 14B on RTX 3060
- NFR35: Ollama handles 2-3 concurrent inference requests without significant performance degradation
- NFR36: GPU worker joins cluster and becomes Ready within 2 minutes of boot via Tailscale
- NFR37: NVIDIA GPU Operator installs and configures GPU drivers automatically (no manual setup)
- NFR38: Ollama serves Qwen 2.5 14B as unified model for all tasks (code, classification, general)
- NFR50: Ollama detects GPU unavailability (host workload) within 10 seconds

### NFS Compatibility (Paperless-ngx)

- NFR39: Consumer polling mode used for NFS mounts (inotify not supported over NFS)
- NFR40: Consumer polling interval ≤10 seconds for responsive document imports

### Document Processing Performance (Paperless-ngx)

- NFR41: 2 parallel OCR workers for document processing throughput
- NFR42: Tika service responds within 30 seconds for typical Office documents
- NFR43: Gotenberg PDF conversion completes within 60 seconds for complex documents

### PDF Editor Performance (Stirling-PDF)

- NFR44: Stirling-PDF web interface loads within 5 seconds
- NFR45: PDF merge/split operations complete within 30 seconds for documents up to 100 pages

### AI Classification Performance (Paperless-AI) — SUPERSEDED by Epic 25

- NFR46: ~~Document classification completes within 60 seconds using GPU-accelerated Ollama~~ → Superseded by NFR107
- NFR47: ~~Auto-tagging accuracy achieves 80%+ for common document types~~ → Superseded by NFR108, NFR109
- NFR58: ~~Qwen 2.5 14B produces valid JSON output for 95%+~~ → Superseded by NFR110
- NFR59: ~~RAG document search returns relevant context within 5 seconds~~ → Removed (RAG not in Paperless-GPT scope)
- NFR60: ~~Web UI configuration changes take effect without pod restart~~ → Superseded by NFR112
- NFR61: ~~CPU Ollama with Qwen 2.5 14B achieves acceptable inference speed~~ → Superseded by NFR111
- NFR62: ~~Document classification latency <60 seconds with CPU Ollama~~ → Superseded by NFR111

### Document Processing Pipeline Performance (Epic 25)

#### Paperless-GPT Performance

- NFR107: Document metadata generation completes within 5 seconds via GPU vLLM (Qwen3-8B-AWQ)
- NFR108: Auto-tagging accuracy achieves 90%+ for common document types via GPU inference (Qwen3-8B-AWQ)
- NFR109: Auto-tagging accuracy achieves 70%+ via CPU fallback (phi4-mini on Ollama)
- NFR110: Qwen3 models produce valid structured output for 95%+ of classification requests
- NFR111: CPU Ollama (phi4-mini) completes document classification within 60 seconds (batch processing acceptable)
- NFR112: Paperless-GPT prompt template changes take effect without pod restart

#### Docling Server Performance

- NFR113: Docling server extracts structured text from PDFs within 30 seconds for typical documents
- NFR114: Docling Granite-Docling VLM pipeline runs on CPU with <1GB memory footprint

#### vLLM Upgrade Compatibility

- NFR115: vLLM v0.10.2+ maintains compatibility with existing CLI arguments (`--enforce-eager`, `--quantization awq_marlin`)
- NFR116: vLLM upgrade does not disrupt DeepSeek-R1 deployment (R1 mode continues to function)

### vLLM GPU Performance (Story 12.10) — Partially Superseded by Epic 25

- NFR63: ~~vLLM achieves <5 second document classification latency with qwen2.5:14b~~ → Superseded by NFR107 (Qwen3-8B-AWQ)
- NFR64: ~~vLLM serves qwen2.5:14b with 35-40 tokens/second~~ → Updated: Qwen3-8B-AWQ expected 30-50 tok/s on RTX 3060

### LiteLLM Inference Proxy (Story 14.x)

- NFR65: LiteLLM failover detection completes within 5 seconds of backend unavailability
- NFR66: LiteLLM adds <100ms latency to inference requests during normal operation
- NFR67: ~~Paperless-AI document processing continues (degraded) during Gaming Mode~~ → Updated: Paperless-GPT document processing continues (degraded) during Gaming Mode via fallback chain
- NFR68: OpenAI fallback tier only activated when both vLLM and Ollama are unavailable
- NFR69: LiteLLM health endpoint responds within 1 second for readiness probes

### Email Integration (Paperless-ngx)

- NFR48: Email inboxes checked every 10 minutes for new attachments
- NFR49: Email credentials stored securely via Kubernetes secrets

### Gaming Platform (Steam)

- NFR51: Gaming Mode activation completes within 30 seconds (pod scale-down + VRAM release)
- NFR52: ML Mode restoration completes within 2 minutes (pod scale-up + model load)
- NFR53: Steam games achieve 60+ FPS at 1080p with exclusive GPU access
- NFR54: Graceful degradation to Ollama CPU maintains <5 second inference latency
- NFR70: ML Mode auto-activates within 5 minutes of k3s-gpu-worker boot (after k3s agent ready)

### Multi-Subnet GPU Worker Networking (Solution A)

- NFR55: Tailscale mesh establishes full connectivity within 60 seconds of node boot
- NFR56: Pod-to-pod communication works across different physical subnets (192.168.0.x ↔ 192.168.2.x) via Tailscale
- NFR57: MTU configured at 1280 bytes to prevent VXLAN packet fragmentation over Tailscale

### Tailscale Subnet Router

- NFR71: Subnet routes advertised within 60 seconds of node boot
- NFR72: Subnet router failover: if one router goes down, network segment remains accessible via direct Tailscale connection

### Synology NAS K3s Worker

- NFR73: NAS worker VM allocated maximum 2 vCPU, 4GB RAM to preserve NAS primary functions
- NFR74: NAS worker node joins cluster within 3 minutes of VM boot

### Open-WebUI Application

- NFR75: Open-WebUI web interface loads within 3 seconds
- NFR76: Chat history persisted to NFS storage surviving pod restarts

### Kubernetes Dashboard

- NFR77: Dashboard loads cluster overview within 5 seconds
- NFR78: Dashboard access restricted to Tailscale network only

### Gitea Self-Hosted Git

- NFR79: Gitea repository operations (clone, push, pull) complete within 10 seconds for typical repos
- NFR80: Gitea web interface loads within 3 seconds

### DeepSeek-R1 14B Reasoning Mode

- NFR81: R1-Mode model loading completes within 90 seconds
- NFR82: DeepSeek-R1 achieves 30+ tokens/second on RTX 3060 for reasoning tasks

### LiteLLM External Providers

- NFR83: External provider failover activates within 5 seconds when local models unavailable
- NFR84: Rate limiting configured to stay within free tier quotas per provider

### Blog Article Completion (Epic 9)

- NFR85: Blog post published to dev.to or equivalent platform within 2 weeks of Epic completion

## OpenClaw Success Criteria

### User Success

**Aha Moment:** Successfully completing a real research task through Telegram -- asking OpenClaw a complex question and receiving a well-sourced, Exa-researched answer directly in the chat.

| Metric | Target | Measurement |
|--------|--------|-------------|
| Research task completion | OpenClaw returns sourced answers via Exa MCP tools | Manual validation of research quality |
| Telegram responsiveness | Bot responds to messages within 10 seconds (excluding LLM inference time) | Telegram message timestamps |
| Daily usability | Usable as primary research assistant | Self-assessment after 1 week |
| Fallback transparency | Clear indication when operating on LiteLLM fallback vs Opus 4.5 | Bot response metadata |

### Business Success (Portfolio)

| Metric | Target | Measurement |
|--------|--------|-------------|
| Portfolio showcase | OpenClaw documented as home-lab feature with architecture diagram | GitHub repo docs |
| Blog content | OpenClaw integration included in technical blog post | Published article |
| Interview talking point | Can explain OpenClaw architecture end-to-end (container, LLM routing, MCP tools, Telegram) | Self-assessment |
| Differentiator impact | Demonstrates "AI infrastructure serving a real personal assistant" narrative | Recruiter/interviewer feedback |

### Technical Success

| Metric | Target | Measurement |
|--------|--------|-------------|
| Container health | OpenClaw pod running stable in `apps` namespace | `kubectl get pods -n apps` |
| Opus 4.5 connectivity | Anthropic OAuth authentication working | Gateway logs |
| LiteLLM fallback | Automatic failover to local LiteLLM when Anthropic unavailable | Simulated outage test |
| MCP tools | mcporter with Exa + additional research servers returning results | `mcporter list` + test query |
| Ingress | `openclaw.home.jetzinger.com` serving gateway control UI | Browser access via Tailscale |
| Persistent config | Config and workspace data survive pod restarts | Pod restart test |
| Telegram channel | Bot registered, paired, responding to DMs | Telegram test message |
| WhatsApp channel | Bot connected via Baileys, responding to DMs | WhatsApp test message |
| Discord channel | Bot connected via discord.js, responding to DMs | Discord test message |
| Browser automation | Dedicated browser tool functional for web tasks | Browser action test |
| Voice capabilities | ElevenLabs voice integration working | Voice interaction test |
| Multi-agent | Specialized sub-agents callable from main agent | Sub-agent invocation test |
| Canvas/A2UI | Rich content presentation working | Canvas render test |
| ClawdHub | Skills installable and syncable from marketplace | `clawdhub install` test |
| Observability | Prometheus metrics collected, Grafana dashboard operational | Dashboard review |

### Measurable Outcomes

**Leading Indicators:**
- OpenClaw pod uptime (Prometheus)
- Daily Telegram/WhatsApp/Discord message count (gateway logs)
- Research query success rate

**Lagging Indicators:**
- "I use OpenClaw daily" self-assessment after 2 weeks
- OpenClaw mentioned in recruiter conversations
- Blog post views for OpenClaw-related content

## OpenClaw Product Scope

### MVP - Minimum Viable Product

**Core Infrastructure:**
- OpenClaw Gateway running as Docker container on K3s in `apps` namespace
- Persistent volume for `~/.clawdbot` config and workspace
- Traefik IngressRoute for gateway control UI (`openclaw.home.jetzinger.com`)
- Prometheus metrics for OpenClaw gateway health
- Grafana dashboard for bot usage and LLM routing

**LLM Configuration:**
- Opus 4.5 configured as primary LLM via Anthropic OAuth
- LiteLLM fallback integration when Anthropic is unavailable
- Anthropic API credentials stored as Kubernetes secret

**Messaging Channels:**
- Telegram channel connected and responding to DMs
- WhatsApp channel (via Baileys)
- Discord channel (via discord.js)
- DM pairing security hardened (allowlist-only across all channels)

**MCP Research Tools:**
- mcporter installed with Exa MCP server configured
- Additional MCP research servers beyond Exa

**Advanced Capabilities:**
- Browser automation tool for web tasks
- Voice capabilities (ElevenLabs integration)
- Multi-agent setup with specialized sub-agents
- Canvas/A2UI for rich content presentation
- ClawdHub skill marketplace integration

**Documentation:**
- Basic documentation in repo (ADR + README section)

### Growth Features (Post-MVP)

- Portfolio blog post covering OpenClaw architecture
- OpenClaw integration showcased in technical blog post
- Additional messaging channels (Signal, Google Chat, Teams)

### Vision (Future)

- macOS/iOS companion app integration
- Node network across multiple devices
- Custom skill development for home-lab specific tasks
- OpenClaw as entry point for cluster operations (kubectl via bot)

## OpenClaw User Journeys

### Journey 5: Tom the Researcher - The 2am Rabbit Hole

Tom is reading a Hacker News thread about a new Kubernetes networking approach. The thread references three papers, two GitHub repos, and a blog post he hasn't seen. He's in bed, phone in hand -- opening a laptop feels like too much friction.

He opens Telegram and types: "Research the current state of eBPF-based CNI plugins for Kubernetes. Compare Cilium, Calico eBPF, and any newer alternatives. Focus on performance benchmarks and home lab suitability."

OpenClaw picks it up instantly. Opus 4.5 orchestrates the Exa MCP tools -- searching for recent benchmarks, pulling documentation, cross-referencing GitHub stars and release activity. Thirty seconds later, Tom's Telegram lights up with a structured response: a comparison table, three sourced links, and a recommendation that Cilium's recent 1.16 release added features relevant to his K3s setup.

Tom asks a follow-up: "Would switching from Flannel to Cilium break my existing Tailscale mesh networking?" OpenClaw researches the specific interaction between Cilium and Tailscale, finds a community discussion on the exact topic, and summarizes the migration path with caveats.

By the time Tom falls asleep, he has a clear picture of whether this is worth pursuing -- all without leaving his messaging app. The next morning, he forwards the OpenClaw conversation to his laptop and creates an ADR draft.

**Requirements revealed:** Telegram channel, Opus 4.5 as primary LLM, Exa MCP research tools, conversational follow-ups, structured response formatting, mcporter configuration.

### Journey 6: Tom the Multi-Channel User - Seamless Context

Tom is at his desk working on a home-lab feature when a thought hits him. He types into Discord (where he's already active in dev communities): "What are the best practices for running Node.js >= 22 containers on K3s with limited memory?"

OpenClaw responds in Discord with a concise answer. Later, on his commute, he opens WhatsApp and asks: "Continue that Node.js container question -- what about health check patterns?" OpenClaw picks up the context from the earlier Discord session and continues the conversation seamlessly.

That evening, he's on the couch with his phone. A Telegram message to OpenClaw: "Summarize everything we discussed today about Node.js containers into bullet points for my ADR." OpenClaw consolidates the cross-channel conversation into a clean summary.

**Requirements revealed:** WhatsApp, Discord, and Telegram channels, cross-session context, DM pairing security (allowlist-only), session history access.

### Journey 7: Tom the Voice User - Hands-Free Research

Tom is soldering a cable for his eGPU enclosure. Both hands occupied. He activates OpenClaw's voice mode through his phone: "Hey, what's the recommended Thunderbolt cable length for an RTX 3060 eGPU setup? Any signal degradation issues?"

OpenClaw speaks back through ElevenLabs: "Based on my research, Thunderbolt 3 cables up to 0.7 meters maintain full 40Gbps bandwidth. Beyond that, active cables are recommended. For your RTX 3060 eGPU setup, the community reports stable performance at up to 2 meters with certified active cables."

Tom asks a follow-up verbally, and the conversation continues hands-free while he finishes the hardware work.

**Requirements revealed:** ElevenLabs voice integration, voice wake/talk mode, hands-free operation, research capabilities in voice context.

### Journey 8: Tom the Operator - OpenClaw Goes Down

It's Saturday morning. Tom opens Telegram and sends a message to OpenClaw. No response. He checks his phone -- no error, just silence.

He opens `openclaw.home.jetzinger.com` in his browser via Tailscale. The gateway control UI shows the pod is running but the Anthropic OAuth connection has expired. He checks Grafana -- the OpenClaw dashboard shows the auth failure started 3 hours ago, and LiteLLM fallback kicked in but the local models couldn't handle the mcporter research tool calls.

Tom refreshes the OAuth token through the gateway control UI. Within seconds, OpenClaw responds to his pending Telegram message with an apology and the answer he was waiting for. He makes a mental note to add an alert rule for auth token expiry.

Later, he documents the incident in a runbook and adds a Prometheus alert for Anthropic connectivity. This becomes another portfolio story -- real operational experience with AI infrastructure.

**Requirements revealed:** Traefik ingress for gateway control UI, Prometheus metrics, Grafana dashboard, LiteLLM fallback behavior, OAuth token management, persistent config, alerting integration.

### Journey 9: Tom the Portfolio Showcaser - "You Built a Personal AI Assistant?"

During a technical interview for a Senior Platform Engineer role, the interviewer asks: "Tell me about a complex system you've built end-to-end."

Tom pulls up his home-lab repo. "Beyond the K3s cluster and ML inference stack, I run a personal AI assistant called OpenClaw. It's a self-hosted, containerized Node.js application running on my cluster. The primary brain is Claude Opus 4.5 via Anthropic OAuth, with automatic fallback to my local LiteLLM proxy -- that's vLLM on GPU falling back to Ollama on CPU. I interact with it through Telegram, WhatsApp, and Discord."

The interviewer leans forward. "How does it do research?"

"It uses mcporter to integrate MCP servers -- primarily Exa for web research. The agent can search the web, cross-reference sources, and deliver structured answers. I use it daily for technical research. The whole thing runs in a Docker container on K3s with Traefik ingress, local persistent storage, and full Prometheus observability."

"That's... not a typical home lab project."

"Exactly. It demonstrates the full stack -- from GPU inference to API routing to a consumer-facing AI product. Every architectural decision is documented as an ADR."

**Requirements revealed:** Portfolio documentation, architecture diagram, ADR for OpenClaw decisions, demonstrable running system, clear technical narrative.

### OpenClaw Journey Requirements Summary

| Journey | Key Capabilities Required |
|---------|--------------------------|
| Researcher - 2am Rabbit Hole | Telegram, Opus 4.5, Exa MCP research, structured responses, conversational follow-ups |
| Multi-Channel User | WhatsApp + Discord + Telegram, cross-session context, DM pairing security |
| Voice User | ElevenLabs voice, hands-free operation, voice + research integration |
| Operator - OpenClaw Goes Down | Gateway control UI, Prometheus/Grafana, LiteLLM fallback, OAuth management, alerting |
| Portfolio Showcaser | Documentation, ADR, architecture diagram, demonstrable system, interview narrative |

## OpenClaw Infrastructure Requirements

### Project-Type Overview

OpenClaw is deployed as a containerized Node.js application on the existing K3s cluster pinned to k3s-worker-01 via node affinity. It follows the established deployment patterns: Helm/kubectl manifests, local persistent storage, Traefik ingress, Kubernetes Secrets, and full observability integration.

### Container & Runtime

- Official OpenClaw Docker image (Node.js >= 22)
- No custom image build required
- mcporter installed at runtime or via workspace persistence
- Container runs in `apps` namespace alongside Open-WebUI and n8n

### Authentication & Secrets

Kubernetes Secrets (existing pattern) for:
- Anthropic OAuth credentials (Claude Code subscription)
- Telegram Bot API token
- WhatsApp session credentials
- Discord bot token
- ElevenLabs API key
- Exa API key
- Additional MCP server API keys

### Storage & Persistence

Local persistent volumes on k3s-worker-01 via `local-path` storage class:
- `~/.clawdbot/openclaw.json` -- gateway configuration
- `~/clawd/` -- agent workspace (skills, session data, mcporter config)
- WhatsApp session state (Baileys requires persistent auth state)
- ClawdHub installed skills
- Backed up via Velero cluster backups (disaster recovery)

### Networking

- **Ingress:** `openclaw.home.jetzinger.com` via Traefik IngressRoute (gateway control UI + WebChat)
- **Outbound:** Telegram, WhatsApp, Discord long-polling (no inbound exposure needed)
- **Outbound:** Anthropic API, ElevenLabs API, Exa API, additional MCP server endpoints
- **Internal:** LiteLLM fallback via `litellm.ml.svc` cluster service
- **Tailscale:** Inherited from cluster -- no additional VPN configuration

### Observability

**Log-based monitoring (Loki + Grafana):**
- Gateway logs collected by existing Loki stack
- Grafana dashboard with log-derived panels:
  - Message volume per channel (Telegram, WhatsApp, Discord)
  - LLM provider usage (Opus 4.5 vs LiteLLM fallback ratio)
  - MCP tool invocation counts (Exa research queries)
  - Error rates and types (auth failures, channel disconnects)
  - Session activity and agent routing

**Blackbox monitoring (Prometheus Blackbox Exporter):**
- HTTP probe on gateway control UI (`openclaw.home.jetzinger.com`)
- Uptime and response latency tracking
- Alertmanager rules for:
  - Gateway unreachable (pod down or crash loop)
  - Sustained high error rate in logs
  - Anthropic OAuth token expiry warnings

**Note:** OpenClaw does not expose a native Prometheus `/metrics` endpoint. Observability is achieved through log analysis via Loki and blackbox probing via Prometheus.

### Resource Allocation

- No specific CPU/memory constraints
- Scheduled on any available worker node (no node affinity required)
- Standard K3s resource defaults apply

### Implementation Considerations

- **Namespace:** `apps` (alongside existing application workloads)
- **Node Affinity:** Pinned to k3s-worker-01 (highest resource CPU worker)
- **Deployment method:** Kubernetes manifests (Deployment, Service, IngressRoute, PVC, Secret)
- **Configuration:** `openclaw.json` persisted on local storage
- **Updates:** Rolling deployment strategy, config changes via `gateway config.patch` or pod restart
- **DM Security:** Allowlist-only pairing across all channels -- single-user lockdown

## OpenClaw Scoping & Phased Development

### MVP Strategy & Philosophy

**MVP Approach:** Platform MVP -- deploy the complete OpenClaw foundation as a fully operational personal AI assistant from day one. Since OpenClaw is an existing product being deployed (not built from scratch), the MVP encompasses full feature enablement through configuration rather than implementation.

**Resource Requirements:** Single operator (Tom), weekend deployment cadence consistent with existing home-lab patterns.

### MVP Implementation Phases

#### Phase 1a: Core Gateway
- Deploy official OpenClaw Docker container on K3s (`apps` namespace, k3s-worker-01 node affinity)
- Configure Opus 4.5 as primary LLM via Anthropic OAuth
- Connect Telegram channel (first channel, lowest friction)
- Local persistent storage on k3s-worker-01 (config + workspace)
- Traefik IngressRoute for gateway control UI (`openclaw.home.jetzinger.com`)
- Kubernetes Secrets for credentials
- Basic Loki log collection

#### Phase 1b: Research & Fallback
- Install and configure mcporter with Exa MCP server
- Add additional MCP research servers
- Configure LiteLLM fallback integration (`litellm.ml.svc`)
- Harden DM pairing security (allowlist-only)

#### Phase 1c: Multi-Channel & Advanced
- Connect WhatsApp channel (Baileys)
- Connect Discord channel (discord.js)
- Configure ElevenLabs voice integration
- Set up multi-agent with specialized sub-agents
- Enable browser automation tool
- Configure Canvas/A2UI for rich content presentation
- Integrate ClawdHub skill marketplace

#### Phase 1d: Observability & Documentation
- Build Grafana dashboard with Loki log-derived panels
- Configure Blackbox Exporter HTTP probes
- Set up Alertmanager rules (gateway down, auth expiry, error rate)
- Write ADR for OpenClaw architectural decisions
- Update README with OpenClaw section

### Post-MVP Features (Phase 2: Growth)

- Portfolio blog post covering OpenClaw architecture
- OpenClaw integration showcased in technical blog post
- Additional messaging channels (Signal, Google Chat, Teams)

### Future Vision (Phase 3: Expansion)

- macOS/iOS companion app integration
- Node network across multiple devices
- Custom skill development for home-lab specific tasks
- OpenClaw as entry point for cluster operations (kubectl via bot)

### Risk Mitigation Strategy

| Risk | Impact | Mitigation |
|------|--------|------------|
| Anthropic OAuth complexity in container | Can't authenticate Opus 4.5 | Start with API key fallback, migrate to OAuth |
| WhatsApp Baileys session persistence | Frequent re-pairing required | Local persistent volume for auth state |
| mcporter in container runtime | MCP tools unavailable | Pre-install via workspace persistence or init container |
| ElevenLabs latency | Voice feels sluggish | Acceptable for v1; optimize later |
| Multi-agent resource usage | Pod memory spikes | Monitor via Loki, set resource limits if needed |

## OpenClaw Functional Requirements

### Gateway & Core Infrastructure

- FR149: Operator can deploy OpenClaw Gateway as a Docker container on K3s in the `apps` namespace
- FR150: Operator can access the OpenClaw gateway control UI via `openclaw.home.jetzinger.com` through Traefik ingress
- FR151: Operator can configure OpenClaw via `openclaw.json` persisted on local persistent storage
- FR152: System preserves all OpenClaw configuration and workspace data across pod restarts via local persistent volume
- FR152a: System schedules OpenClaw pod to k3s-worker-01 (highest resource CPU worker) using node affinity
- FR152b: Velero cluster backups include OpenClaw local PVC for disaster recovery
- FR153: Operator can view gateway status and health via the control UI
- FR154: Operator can restart the gateway via the control UI

### LLM Provider Management

- FR155: System routes all conversations to Claude Opus 4.5 via Anthropic OAuth as the primary LLM
- FR156: System automatically falls back to LiteLLM proxy (`litellm.ml.svc`) when Anthropic is unavailable
- FR157: User can identify which LLM provider (Opus 4.5 or LiteLLM fallback) is handling a given conversation
- FR158: Operator can manage Anthropic OAuth credentials through the gateway control UI

### Messaging Channels

- FR159: User can send and receive messages with OpenClaw via Telegram DM
- FR160: User can send and receive messages with OpenClaw via WhatsApp DM
- FR161: User can send and receive messages with OpenClaw via Discord DM
- FR162: System enforces allowlist-only DM pairing across all messaging channels
- FR163: Operator can approve or reject pairing requests via the gateway CLI
- FR164: User can continue a conversation context across different messaging channels

### MCP Research Tools

- FR165: User can request web research and receive sourced answers via Exa MCP tools
- FR166: Operator can install and configure additional MCP research servers via mcporter
- FR167: User can invoke any configured MCP tool through natural language conversation
- FR168: System returns structured, sourced responses when using research tools

### Voice Capabilities

- FR169: User can interact with OpenClaw via voice input and receive spoken responses through ElevenLabs
- FR170: User can switch between text and voice modes within a conversation

### Multi-Agent & Advanced

- FR171: Operator can configure specialized sub-agents with distinct capabilities
- FR172: User can invoke specific sub-agents through the main conversation
- FR173: System routes tasks to appropriate sub-agents based on context
- FR174: User can trigger browser automation tasks through conversation
- FR175: System can navigate web pages, fill forms, and extract information via the browser tool
- FR176: System can present rich content via Canvas/A2UI

### Skills & Marketplace

- FR177: Operator can install skills from ClawdHub marketplace
- FR178: Operator can update and sync installed skills via ClawdHub
- FR179: User can invoke installed skills through slash commands or natural conversation
- FR180: Operator can enable, disable, and configure individual skills via `openclaw.json`

### Observability & Operations

- FR181: System collects gateway logs into Loki for analysis
- FR182: Operator can view OpenClaw operational dashboard in Grafana with log-derived metrics
- FR183: Grafana dashboard displays message volume per channel, LLM provider usage, MCP tool invocations, and error rates
- FR184: Prometheus Blackbox Exporter probes the gateway control UI for uptime monitoring
- FR185: Alertmanager sends alerts when the gateway is unreachable, error rate is sustained, or OAuth tokens are expiring
- FR186: Operator can view OpenClaw health snapshot via `openclaw health --json`

### Long-Term Memory

- FR189: Operator can configure OpenClaw to use the `memory-lancedb` plugin with OpenAI embeddings (`text-embedding-3-small`) for automatic memory capture and recall, replacing the default `memory-core` plugin
- FR190: System automatically captures conversation context into a LanceDB vector store and recalls relevant memories on subsequent conversations without the user or agent explicitly invoking memory tools
- FR191: Operator can manage the memory index via `openclaw ltm` CLI commands (stats, list, search) from inside the pod

### Documentation & Portfolio

- FR187: Repository includes an ADR documenting OpenClaw architectural decisions
- FR188: Repository README includes a OpenClaw section with architecture overview

## OpenClaw Non-Functional Requirements

### Performance

- NFR86: OpenClaw gateway responds to incoming Telegram/WhatsApp/Discord messages within 10 seconds (excluding LLM inference time)
- NFR87: Gateway control UI loads within 3 seconds via Traefik ingress
- NFR88: LiteLLM fallback activates within 5 seconds of detecting Anthropic unavailability
- NFR89: mcporter MCP tool invocations (Exa research) return results within 30 seconds
- NFR90: Voice responses via ElevenLabs begin streaming within 5 seconds of request

### Security

- NFR91: All API credentials (Anthropic OAuth, Telegram, WhatsApp, Discord, ElevenLabs, Exa) stored as Kubernetes Secrets, never in plaintext ConfigMaps
- NFR92: DM pairing enforces allowlist-only policy -- unapproved senders receive no response
- NFR93: Gateway control UI accessible only via Tailscale mesh (no public exposure)
- NFR94: OAuth tokens rotated and refreshed automatically; manual refresh available via control UI
- NFR95: No API keys or secrets exposed in Loki logs or Grafana dashboards

### Integration

- NFR96: Anthropic OAuth maintains persistent connection; automatic reconnection on transient failures within 30 seconds
- NFR97: Telegram, WhatsApp, and Discord channels automatically reconnect after network interruptions within 60 seconds
- NFR98: mcporter MCP server connections recover gracefully from timeouts without crashing the gateway
- NFR99: LiteLLM internal cluster service (`litellm.ml.svc`) reachable from `apps` namespace via standard K8s DNS resolution

### Reliability

- NFR100: OpenClaw pod restarts cleanly after k3s-worker-01 reboot with all configuration and workspace intact from local storage
- NFR101: Gateway survives individual channel disconnections without affecting other channels
- NFR102: Pod crash loop triggers Alertmanager notification within 2 minutes
- NFR103: Loki retains OpenClaw gateway logs for a minimum of 7 days
- NFR104: Blackbox Exporter probe interval of 30 seconds with alerting after 3 consecutive failures

### Memory

- NFR105: Memory embedding latency does not exceed 500ms per message using OpenAI API (`text-embedding-3-small`); local Xenova not supported by memory-lancedb plugin
- NFR106: LanceDB memory data persists across pod restarts via local PVC (`openclaw-data`) on k3s-worker-01

