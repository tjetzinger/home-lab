---
stepsCompleted: [1, 2, 3, 4, 7, 8, 9, 10, 11]
workflow_completed: true
inputDocuments:
  - 'docs/planning-artifacts/product-brief-home-lab-2025-12-27.md'
  - 'docs/planning-artifacts/research/domain-k8s-platform-career-positioning-research-2025-12-27.md'
  - 'docs/analysis/brainstorming-session-2025-12-27.md'
workflowType: 'prd'
lastStep: 10
briefCount: 1
researchCount: 1
brainstormingCount: 1
projectDocsCount: 0
date: '2025-12-27'
lastUpdated: '2026-01-14'
author: 'Tom'
project_name: 'home-lab'
---

# Product Requirements Document - home-lab

**Author:** Tom
**Date:** 2025-12-27 | **Last Updated:** 2026-01-14

**Changelog:**
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
- AI/ML: Ollama (Qwen 2.5 14B unified model), n8n
- GPU: NVIDIA RTX 3060 via eGPU (future)
- Gaming: Steam + Proton on Intel NUC host OS (shared GPU with K8s)
- Document Management: Paperless-ngx
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

### AI-Powered Document Classification (Paperless-AI)

- FR87: Paperless-AI deployed connecting Paperless-ngx to Ollama on GPU worker (Intel NUC + RTX 3060)
- FR88: Documents auto-tagged using LLM-based classification via GPU-accelerated inference
- FR89: Correspondents and document types auto-populated from document content
- FR104: Ollama configured with Qwen 2.5 14B model for reliable JSON-structured document metadata extraction (Story 12.8)
- FR105: Paperless-AI model configurable via ConfigMap without code changes (Story 12.8)
- FR106: clusterzx/paperless-ai deployed with web-based configuration UI replacing basic processor (Story 12.9)
- FR107: RAG-based document chat enables natural language queries across document archive (Story 12.9)
- FR108: Document classification rules configurable via web interface without YAML editing (Story 12.9)

### vLLM GPU Integration (Story 12.10)

- FR109: vLLM deployed with qwen2.5:14b model on GPU worker (k3s-gpu-worker) for primary inference
- FR110: Paperless-AI configured with `AI_PROVIDER=custom` pointing to LiteLLM unified endpoint
- FR111: Ollama serves slim models (llama3.2:1b, qwen2.5:3b) as first fallback tier
- FR112: k3s-worker-02 resources reduced from 32GB to 8GB RAM after vLLM migration

### LiteLLM Inference Proxy (Story 14.x)

- FR113: LiteLLM proxy deployed in `ml` namespace providing unified OpenAI-compatible endpoint
- FR114: LiteLLM configured with three-tier fallback: vLLM (GPU) → Ollama (CPU) → OpenAI (cloud)
- FR115: Paperless-AI configured to use LiteLLM endpoint instead of direct vLLM connection
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

### AI Classification Performance (Paperless-AI)

- NFR46: Document classification completes within 60 seconds using GPU-accelerated Ollama
- NFR47: Auto-tagging accuracy achieves 80%+ for common document types (invoices, contracts, receipts)
- NFR58: Qwen 2.5 14B produces valid JSON output for 95%+ of document classification requests (Story 12.8)
- NFR59: RAG document search returns relevant context within 5 seconds (Story 12.9)
- NFR60: Web UI configuration changes take effect without pod restart (Story 12.9)
- NFR61: CPU Ollama with Qwen 2.5 14B achieves acceptable inference speed for document classification (Story 12.8)
- NFR62: Document classification latency <60 seconds with CPU Ollama (acceptable for batch processing) (Story 12.8)

### vLLM GPU Performance (Story 12.10)

- NFR63: vLLM achieves <5 second document classification latency with GPU-accelerated qwen2.5:14b
- NFR64: vLLM serves qwen2.5:14b with 35-40 tokens/second throughput on RTX 3060

### LiteLLM Inference Proxy (Story 14.x)

- NFR65: LiteLLM failover detection completes within 5 seconds of backend unavailability
- NFR66: LiteLLM adds <100ms latency to inference requests during normal operation
- NFR67: Paperless-AI document processing continues (degraded) during Gaming Mode via fallback chain
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

