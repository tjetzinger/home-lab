# Home Lab Portfolio - Resume Companion

**Project:** Production-Grade K3s Kubernetes Learning Platform
**Author:** Thomas Jetzinger
**Purpose:** Career transition from Automotive PM to Platform Engineering
**Status:** ✅ Operational (15+ services running 24/7)

---

## Project Overview

This home lab demonstrates hands-on platform engineering capability through a production-grade Kubernetes cluster running real workloads. Built using AI-assisted development (Claude Code + BMAD framework), it serves dual purposes: functional home infrastructure AND a technical portfolio showcasing the transition from 10+ years in automotive distributed systems to cloud-native platform engineering.

### Why This Matters

**Career Context:**
- **10+ years automotive software:** 4 years as TPM (vehicle data platforms, navigation systems), 6 years as PM (organization-level program management)
- **Distributed systems experience:** OTA updates, cloud navigation services, multi-platform coordination
- **Hands-on learning:** Tutorials show theory; running real infrastructure proves operational capability

**What Makes This Different:**
- ✅ **Real workloads:** PostgreSQL, Ollama (LLM inference), n8n, Nginx—not hello-world demos
- ✅ **Production practices:** Comprehensive monitoring, mobile P1 alerts, tested backup/restore procedures
- ✅ **Decision documentation:** Architecture Decision Records (ADRs) demonstrate engineering judgment
- ✅ **AI-assisted engineering:** Systematic methodology (PRD → Architecture → Planning → Implementation)
- ✅ **Complete narrative:** End-to-end documentation from brainstorming through running cluster

---

## Skills Demonstrated

### Kubernetes Operations
- **Cluster deployment:** K3s multi-node cluster on Proxmox LXC containers
- **Workload management:** Deployments, StatefulSets, DaemonSets, Jobs
- **Scaling & troubleshooting:** Resource allocation, pod scheduling, debugging failures
- **Upgrades & rollbacks:** K3s version management, rollback procedures documented

### Infrastructure as Code
- **Helm charts:** Values-driven configuration for all deployments
- **Declarative manifests:** YAML configurations version-controlled in Git
- **GitOps principles:** Single source of truth, reproducible deployments
- **Configuration management:** Systematic approach to infrastructure changes

### Observability & Monitoring
- **Metrics collection:** Prometheus scraping cluster-wide metrics
- **Visualization:** Grafana dashboards for cluster health, node metrics, pod resources
- **Log aggregation:** Loki centralized logging with LogQL queries
- **Alerting:** Alertmanager routing P1 alerts to mobile (ntfy.sh)
- **Metrics retention:** 7-day Prometheus TSDB, configurable retention policies

### Storage Management
- **NFS integration:** External storage via Synology DS920+ (8.8TB SHR RAID)
- **Dynamic provisioning:** nfs-subdir-external-provisioner with automatic PVC creation
- **Persistent volumes:** StatefulSet data persistence for PostgreSQL, Prometheus, Grafana
- **Backup & restore:** Synology hourly snapshots, tested pg_dump procedures

### Networking & Ingress
- **LoadBalancer:** MetalLB Layer 2 mode providing external IPs (192.168.2.100-120 pool)
- **Ingress controller:** Traefik with IngressRoute CRDs for HTTP/HTTPS routing
- **TLS automation:** cert-manager + Let's Encrypt automatic certificate issuance and renewal
- **DNS management:** NextDNS rewrites for `*.home.jetzinger.com` domain
- **VPN access:** Tailscale-only access (no public internet exposure)

### Security
- **TLS everywhere:** Automatic HTTPS via cert-manager, HTTP→HTTPS redirects
- **Network isolation:** Tailscale VPN requirement, private subnet (192.168.2.0/24)
- **Certificate management:** Let's Encrypt integration, automatic renewal
- **Secrets management:** Kubernetes Secrets (sealed-secrets planned upgrade)
- **Network policies:** Pod-to-pod communication controls (partial implementation)

### AI/ML Workloads
- **LLM inference:** Ollama serving llama3.2:1b model (CPU mode)
- **Model serving:** RESTful API access at `ollama.home.jetzinger.com`
- **Workflow integration:** n8n connecting AI inference to automation pipelines
- **Future: GPU acceleration:** RTX 3060 eGPU planned for vLLM deployments

### Documentation Discipline
- **Architecture Decision Records (ADRs):** Trade-off analysis for major decisions
- **Runbooks:** Operational procedures for P1 scenarios
- **README files:** Component documentation following What/Why/Config/Access pattern
- **Visual documentation:** Grafana screenshots, architecture diagrams
- **Blog posts:** Technical write-ups connecting automotive experience to Kubernetes

---

## Technologies Used

### Orchestration & Compute
- **K3s v1.34.3:** Lightweight Kubernetes distribution
- **Proxmox VE:** Virtualization platform (LXC containers for cluster nodes)
- **Ubuntu 22.04 LTS:** Operating system for all nodes
- **3-node cluster:** 1 control plane (k3s-master), 2 workers (k3s-worker-01/02)

### Storage
- **Synology DS920+:** NAS with 8.8TB usable capacity (SHR RAID)
- **NFS:** Network file system for persistent storage
- **nfs-subdir-external-provisioner:** Dynamic PVC provisioning via Helm

### Networking
- **MetalLB:** Bare metal load balancer (Layer 2 mode)
- **Traefik:** Ingress controller (bundled with K3s)
- **cert-manager:** Automated TLS certificate management
- **Let's Encrypt:** Free, automated CA for HTTPS certificates
- **Tailscale VPN:** Zero-trust network access
- **NextDNS:** DNS rewrites for `*.home.jetzinger.com`

### Observability
- **kube-prometheus-stack:** Comprehensive monitoring bundle (Helm chart)
  - **Prometheus:** Metrics collection and storage (7-day retention)
  - **Grafana:** Metrics visualization and dashboards
  - **Alertmanager:** Alert routing and notification
  - **Node Exporter:** Host-level metrics (CPU, memory, disk, network)
  - **kube-state-metrics:** Kubernetes object state metrics
- **Loki:** Log aggregation and querying
- **ntfy.sh:** Mobile push notifications for P1 alerts

### Data & Applications
- **PostgreSQL:** Production database (Bitnami Helm chart)
- **Ollama:** LLM inference platform (llama3.2:1b model)
- **n8n:** Workflow automation with AI integration
- **Nginx:** Reverse proxy for local development

### Development & Tooling
- **Helm:** Kubernetes package manager
- **kubectl:** Kubernetes CLI
- **Git:** Version control for all infrastructure code
- **Claude Code:** AI pair programming tool
- **BMAD framework:** Systematic AI-assisted development methodology

### Future Additions
- **Paperless-ngx:** Document management system
- **Dev Containers:** Remote development environment
- **vLLM:** GPU-accelerated LLM serving (RTX 3060 eGPU)
- **GitOps (ArgoCD/Flux):** Declarative continuous deployment

---

## Architecture Highlights

### Cluster Topology
```
┌─────────────────────────────────────────────────────────────┐
│  Tailscale VPN (External Access)                             │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│  MetalLB LoadBalancer Pool: 192.168.2.100-120               │
│  ├─ Traefik Ingress: 192.168.2.100                           │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│  K3s Cluster (192.168.2.20-22)                              │
│  ├─ k3s-master (192.168.2.20) - Control Plane               │
│  ├─ k3s-worker-01 (192.168.2.21) - Worker Node              │
│  └─ k3s-worker-02 (192.168.2.22) - Worker Node              │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│  Synology DS920+ NFS (192.168.2.2)                          │
│  └─ /volume1/k8s-data (8.8TB, hourly snapshots)             │
└─────────────────────────────────────────────────────────────┘
```

### Namespace Organization
| Namespace | Purpose | Components |
|-----------|---------|------------|
| `kube-system` | K3s core | Traefik, CoreDNS, metrics-server |
| `infra` | Infrastructure | MetalLB, cert-manager, NFS provisioner |
| `monitoring` | Observability | Prometheus, Grafana, Loki, Alertmanager |
| `data` | Databases | PostgreSQL |
| `apps` | Applications | n8n |
| `ml` | AI/ML | Ollama |
| `dev` | Development | Nginx proxy, dev containers |

### Data Flow: External Access
```
User → Tailscale VPN → 192.168.2.100 (MetalLB)
  → Traefik Ingress (TLS termination via cert-manager)
    → IngressRoute (hostname-based routing)
      → Kubernetes Service → Pods
```

### Observability Pipeline
```
Cluster Components → Prometheus (scrape metrics every 30s)
  → TSDB (7-day retention) → Grafana Dashboards
    → Alertmanager (evaluate alert rules)
      → ntfy.sh (mobile P1 alerts)

Application Logs → Loki (log aggregation)
  → Grafana Explore (LogQL queries)
```

---

## Quick Stats

| Metric | Value |
|--------|-------|
| **Cluster Nodes** | 3 (1 control plane, 2 workers) |
| **Deployed Services** | 15+ production workloads |
| **Namespaces** | 7 (kube-system, infra, monitoring, data, apps, ml, dev) |
| **Storage** | 8.8TB NFS (Synology, hourly snapshots) |
| **Monitoring** | 7-day metrics retention, P1 mobile alerts |
| **Documentation** | 4 ADRs, 1 blog post, 12 component READMEs |
| **Uptime Target** | 95%+ (Prometheus-validated) |
| **TLS Certificates** | Automatic (cert-manager + Let's Encrypt) |
| **Access Method** | Tailscale VPN only (no public exposure) |

---

## Documentation Navigation

### Architecture & Decisions
- **[Architecture Decision Records](adrs/)** - Why decisions were made, alternatives considered, trade-offs
  - [ADR-001: LXC Containers for K3s Nodes](adrs/ADR-001-lxc-containers-for-k3s.md)
  - [ADR-002: External NFS Over Longhorn](adrs/ADR-002-nfs-over-longhorn.md)
  - [ADR-003: Traefik Ingress Controller](adrs/ADR-003-traefik-ingress.md)
  - [ADR-004: kube-prometheus-stack](adrs/ADR-004-kube-prometheus-stack.md)
  - [ADR-005: Manual Helm Over GitOps](adrs/ADR-005-manual-helm-over-gitops.md)

### Visual Proof
- **[Visual Tour](VISUAL_TOUR.md)** - Grafana screenshots, architecture diagrams
  - Kubernetes Cluster Overview dashboard
  - Node-level resource metrics
  - Pod resource consumption
  - Workload performance metrics

### Blog Posts & Learnings
- **[Blog Posts](blog-posts/)** - Technical write-ups and career narrative
  - [From Automotive Software to Kubernetes: Building a Production-Grade K3s Home Lab](blog-posts/01-from-automotive-to-kubernetes.md)

### Implementation Details
- **[Implementation Stories](implementation-artifacts/)** - Story-by-story build documentation
  - Epic 1: Foundation (K3s Cluster with Remote Access)
  - Epic 2: Storage & Persistence
  - Epic 3: Ingress, TLS & Service Exposure
  - Epic 4: Observability Stack
  - Epic 5: PostgreSQL Database Service
  - Epic 6: AI Inference Platform
  - Epic 7: Development Proxy
  - Epic 8: Cluster Operations & Maintenance
  - Epic 9: Portfolio & Public Showcase

### Component Documentation
#### Infrastructure
- [K3s Cluster](../infrastructure/k3s/README.md) - Kubernetes cluster setup and configuration
- [NFS Storage](../infrastructure/nfs/README.md) - Dynamic PVC provisioning via Synology
- [MetalLB](../infrastructure/metallb/README.md) - LoadBalancer for bare metal
- [Traefik Ingress](../infrastructure/traefik/README.md) - HTTP/HTTPS routing and TLS
- [cert-manager](../infrastructure/cert-manager/README.md) - Automated TLS certificates

#### Applications
- [PostgreSQL](../applications/postgres/README.md) - Production database service
- [Ollama](../applications/ollama/README.md) - LLM inference platform
- [n8n](../applications/n8n/README.md) - Workflow automation
- [Nginx](../applications/nginx/README.md) - Development reverse proxy

#### Monitoring
- [Prometheus](../monitoring/prometheus/README.md) - Metrics collection and storage
- [Grafana](../monitoring/grafana/README.md) - Visualization and dashboards
- [Loki](../monitoring/loki/README.md) - Log aggregation

---

## For Hiring Managers

### 10-Minute Review Guide

**Goal:** Understand project scope, technical depth, and engineering capability

**Recommended Path:**
1. **Start here:** `README.md` (project overview, quick start)
2. **Skills summary:** This document (`docs/PORTFOLIO.md`)
3. **Visual proof:** [Visual Tour](VISUAL_TOUR.md) (Grafana screenshots, architecture diagram)
4. **Decision-making:** [ADR-002: NFS Over Longhorn](adrs/ADR-002-nfs-over-longhorn.md) (trade-off analysis example)
5. **Career narrative:** [Blog Post: Automotive to Kubernetes](blog-posts/01-from-automotive-to-kubernetes.md)

**Key Questions Answered:**
- ✅ **Does the cluster actually run?** Yes → See Grafana screenshots showing 15+ services with real metrics
- ✅ **Is this production-ready?** Yes → Monitoring, alerting, backups, TLS, tested restore procedures
- ✅ **Can they make architecture decisions?** Yes → ADRs document trade-offs and alternatives considered
- ✅ **Do they understand operations?** Yes → Runbooks, rollback procedures, P1 alert handling
- ✅ **How do automotive skills transfer?** Blog post connects distributed systems experience to K8s

### Interview Question Preparation

**Cluster Architecture:**
- "Walk me through your cluster topology" → 3-node K3s, MetalLB, Traefik, NFS storage
- "Why K3s instead of full Kubernetes?" → ADR-001 (efficiency for home lab, learning focused)
- "How do you handle ingress traffic?" → Traefik (bundled with K3s) + cert-manager for TLS

**Storage:**
- "Why external NFS instead of Longhorn?" → ADR-002 (leverage existing Synology, avoid operational complexity)
- "How do you handle backups?" → Synology hourly snapshots + tested pg_dump procedures

**Monitoring & Observability:**
- "How do you know if something breaks?" → kube-prometheus-stack with P1 mobile alerts (ntfy.sh)
- "Show me your monitoring" → Grafana at `grafana.home.jetzinger.com` (screenshots in Visual Tour)

**Security:**
- "How is the cluster accessed?" → Tailscale VPN only, no public internet exposure
- "How do you manage TLS certificates?" → cert-manager + Let's Encrypt automation

**Operational Maturity:**
- "Have you tested disaster recovery?" → Yes, documented in Story 8.3 (cluster state restore)
- "How do you upgrade the cluster?" → Documented procedure (Story 8.1), tested rollback (Story 8.5)

---

## Contact & Links

**LinkedIn:** [linkedin.com/in/tjetzinger](https://www.linkedin.com/in/tjetzinger/)
**GitHub:** [github.com/tjetzinger/home-lab](https://github.com/tjetzinger/home-lab)
**Email:** thomas@jetzinger.com

**Career Goal:** Senior Platform Engineer / MLOps Engineer role leveraging 10+ years distributed systems experience

---

**Last Updated:** 2026-01-08
**Cluster Status:** ✅ Operational (K3s v1.34.3)
**Documentation Status:** ✅ Complete (Epic 9 - Portfolio & Public Showcase)
