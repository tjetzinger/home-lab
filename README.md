# Home Lab: Production-Grade K3s Platform

A production-ready Kubernetes home lab running on Proxmox VE, demonstrating platform engineering skills through hands-on infrastructure operation. This project bridges my automotive systems engineering background with modern cloud-native technologies, showcasing the ability to design, deploy, and maintain production workloads on Kubernetes.

**Status:** ✅ Operational
**Cluster:** 3-node K3s v1.34.3+k3s1
**Workloads:** PostgreSQL, Ollama (LLM inference), n8n, Nginx
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
┌─────────────────────────────────────────────────────┐
│                   Tailscale VPN                     │
│              (Remote Access Layer)                  │
└────────────────────┬────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────┐
│              Traefik Ingress                        │
│         (TLS Termination, Routing)                  │
└─────┬──────────────┬─────────────┬──────────────────┘
      │              │             │
┌─────▼─────┐  ┌────▼────┐  ┌─────▼──────┐
│ Grafana   │  │  n8n    │  │  Ollama    │
│ Prometheus│  │         │  │  (LLM)     │
└───────────┘  └────┬────┘  └────────────┘
                    │
              ┌─────▼─────┐
              │ PostgreSQL│
              │  (NFS)    │
              └───────────┘
```

### Technology Stack

| Layer | Technology | Decision Rationale |
|-------|-----------|-------------------|
| **Orchestration** | K3s v1.34.3 | Lightweight, production-ready K8s. Half the memory of k0s, built-in storage/ingress. See [ADR-001](docs/adrs/ADR-001-kubernetes-distribution-selection.md) |
| **Compute** | 3x Ubuntu 22.04 LTS VMs on Proxmox | LTS stability, 5-year support window, proven KVM hypervisor |
| **Storage** | NFS from Synology DS920+ | Existing NAS asset, CSI driver maturity, snapshot support |
| **Ingress** | Traefik (K3s bundled) | Zero-config LB, native K8s integration, automatic cert renewal |
| **TLS** | cert-manager + Let's Encrypt | Industry standard, automated renewal, staging/prod environments |
| **Load Balancer** | MetalLB (Layer 2) | Simple home network setup, no BGP complexity needed |
| **Observability** | kube-prometheus-stack + Loki | Complete stack (metrics, logs, alerting), Grafana dashboards, mobile alerts |
| **GitOps** | Git as source of truth | All manifests version-controlled, Helm values files, reproducible deployments |

**Key Design Decisions:**
- **No public exposure**: Tailscale VPN-only access (security > convenience)
- **External storage**: NFS over in-cluster solutions (leverage existing NAS investment, snapshots)
- **Helm for apps**: Values files over `--set` flags (version control, repeatability)
- **ADR documentation**: Every architectural choice captured with context and alternatives

See [docs/adrs/](docs/adrs/) for detailed decision records.

---

## Quick Start

**Prerequisites:**
- 3x VMs (2 CPU, 4GB RAM each) or bare metal nodes
- Ubuntu 22.04 LTS installed on all nodes
- Network: Static IPs assigned, nodes can reach each other
- Optional: Tailscale account for remote access
- Optional: NFS server for persistent storage

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

**Next steps:** Deploy applications (PostgreSQL, Ollama, n8n) per [Epic 5](docs/implementation-artifacts/) and [Epic 6](docs/implementation-artifacts/) stories.

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
│   ├── postgres/            # PostgreSQL Helm values (Bitnami chart)
│   ├── ollama/              # LLM inference engine Helm values
│   ├── n8n/                 # Workflow automation Helm values
│   └── nginx/               # Development reverse proxy
│
├── monitoring/              # Observability stack
│   ├── prometheus/          # kube-prometheus-stack Helm values
│   ├── grafana/             # Grafana dashboards and datasources
│   └── loki/                # Log aggregation Helm values
│
├── docs/                    # Documentation
│   ├── VISUAL_TOUR.md       # 📸 Grafana screenshots & architecture diagrams
│   ├── adrs/                # Architecture Decision Records
│   ├── runbooks/            # Operational procedures
│   ├── diagrams/            # Architecture diagrams and screenshots
│   ├── planning-artifacts/  # PRD, architecture, epics
│   └── implementation-artifacts/  # Story files, sprint status
│
└── scripts/                 # Automation and utilities
    └── (future: backup, health checks, etc.)
```

**Key Files:**
- `docs/VISUAL_TOUR.md` - Grafana dashboard screenshots and architecture diagrams (visual proof of operational infrastructure)
- `infrastructure/*/values-homelab.yaml` - Helm chart customizations for this cluster
- `docs/adrs/ADR-*.md` - Architectural decisions with context and trade-offs
- `docs/runbooks/*.md` - Operational procedures for maintenance tasks
- `docs/implementation-artifacts/*.md` - Story-by-story implementation details
- `CLAUDE.md` - Project instructions for AI-assisted development workflow

---

## Operational Excellence

### Monitoring and Alerts

- **Metrics:** Prometheus scraping all cluster components, custom ServiceMonitors for apps
- **Dashboards:** Grafana with K8s cluster overview, node metrics, pod resources
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
- **Runbooks:** Comprehensive procedures for all P1 maintenance scenarios

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

**How I used it:**
```bash
# Example: Deploy PostgreSQL with full context awareness
claude: "Deploy PostgreSQL following the architecture spec"
# Claude reads: architecture.md, PRD requirements, Helm patterns
# Claude creates: values-homelab.yaml, deployment docs, backup procedures
# Claude validates: Against NFR requirements, existing patterns
```

### BMAD Methodology: Structured Implementation

BMAD is a multi-agent AI workflow framework that enforces systematic software delivery. Located in `_bmad/`, it orchestrates the entire development lifecycle:

**Phase 1: Discovery**
- Product requirements (PRD)
- User journeys and personas
- Success criteria definition

**Phase 2: Architecture**
- Technology selection with trade-off analysis
- Component design and integration patterns
- Decision capture as ADRs

**Phase 3: Planning**
- Break down into epics (major capabilities)
- Decompose epics into user stories
- Estimate complexity and dependencies

**Phase 4: Implementation** *(This is where the magic happens)*
```bash
# Workflow for each story:
1. /create-story          # Generate story file from epic
2. /dev-story             # Implement with gap analysis
3. /code-review           # Adversarial quality check
4. Document & iterate     # Update ADRs, runbooks
```

**Example: Story 5.1 (Deploy PostgreSQL)**
1. **Story creation**: BMAD reads PRD + Architecture, generates comprehensive story file with tasks
2. **Gap analysis**: Scans codebase, validates assumptions, refines tasks based on reality
3. **Implementation**: Creates Helm values, tests deployment, validates backup/restore
4. **Documentation**: Updates runbooks, ADRs, validates against NFR requirements
5. **Code review**: Adversarial agent finds issues (missing resource limits, backup validation gaps)
6. **Iteration**: Fix issues, re-validate, mark story complete

### Why This Approach Works

**Systematic, Not Ad-Hoc:**
Every decision is documented (ADRs), every procedure has a runbook, every story maps to requirements. No "we should probably document this later" technical debt.

**Quality Built-In:**
- Gap analysis catches incorrect assumptions before implementation
- Code review finds security issues, missing tests, non-compliance
- Every story has acceptance criteria validated before marking done

**Transferable Skills:**
This isn't "AI did everything." It's learning to:
- Structure problems for AI collaboration
- Review AI-generated solutions critically
- Maintain quality standards with AI assistance
- Document architectural thinking systematically

**Evidence of Capability:**
Look at any story file in `docs/implementation-artifacts/`:
- Comprehensive context (requirements, architecture, previous learnings)
- Gap analysis results (what exists vs. what's needed)
- Detailed dev notes (libraries, patterns, trade-offs)
- Change log and completion validation

This demonstrates **systems thinking** and **engineering discipline** - exactly what platform engineering roles require.

### Repository as Evidence

Every file in this repo tells part of the story:

- **`docs/planning-artifacts/`**: Shows requirements analysis and planning rigor
- **`docs/adrs/`**: Demonstrates architectural thinking and decision-making
- **`docs/implementation-artifacts/`**: Proves systematic execution and quality validation
- **`docs/runbooks/`**: Exhibits operational maturity and maintenance planning
- **`infrastructure/` + `applications/`**: Real, working code following consistent patterns

**For hiring managers:** This isn't a tutorial follow-along. It's a methodology-driven project that produces production-quality infrastructure with systematic documentation. The AI accelerated delivery, but the engineering judgment, architectural decisions, and operational discipline are human.

---

## Engineering Learnings

### Trade-offs and Decisions

**K3s vs. k0s vs. kubeadm:**
Chose K3s for lower resource overhead (critical for home lab), built-in components (Traefik, local storage), and production pedigree (Rancher/SUSE). Trade-off: Less flexibility in component choice vs. kubeadm. Worth it for the operational simplicity.

**NFS vs. Longhorn vs. Rook/Ceph:**
Chose external NFS to leverage existing Synology NAS with mature snapshot capabilities. Trade-off: Performance lower than Longhorn, but snapshots and capacity management offloaded to proven NAS. Avoided Rook/Ceph complexity overkill for single-site home lab.

**MetalLB Layer 2 vs. BGP:**
Chose Layer 2 mode for simplicity in home network without router BGP support. Trade-off: Single active LB (no HA), but acceptable for non-critical home workloads. Would use BGP in enterprise with proper routing infrastructure.

**Traefik (bundled) vs. nginx-ingress:**
Kept K3s bundled Traefik to reduce components and leverage zero-config LB integration. Trade-off: Less community momentum than nginx-ingress, but excellent K8s native integration and automatic Let's Encrypt.

**AI-Assisted Development:**
Used Claude Code with BMAD methodology for systematic implementation. Every story planned, implemented, reviewed, and documented. Trade-off: More upfront planning time, but significantly higher quality and completeness. The discipline of ADRs and runbooks forces deeper understanding.

### What Went Well

- **Systematic approach:** BMAD workflow (epics → stories → implementation) kept project organized and prevented scope creep
- **Documentation-first:** Writing ADRs and runbooks as I built forced clarity on decisions and procedures
- **Git as source of truth:** Never lost configuration, easy rollback, reproducible deployments
- **Real production practices:** Treating home lab like prod infrastructure built transferable habits

### What I'd Do Differently

- **Earlier monitoring:** Should have deployed observability stack before apps. Debugging without metrics/logs was painful.
- **Terraform for VMs:** Manual Proxmox VM creation was tedious. Would automate with Terraform next time.
- **Sealed Secrets:** Currently using plain Kubernetes secrets. Would implement SealedSecrets or external secret management earlier.
- **Resource limits:** Several pod OOMKills in early days. Now enforce resource requests/limits in all deployments.

---

## Links and References

### Documentation

- **Portfolio Summary (Resume Companion):** [docs/PORTFOLIO.md](docs/PORTFOLIO.md) - High-level project summary, skills demonstrated, technologies used
- **Visual Tour (Screenshots & Diagrams):** [docs/VISUAL_TOUR.md](docs/VISUAL_TOUR.md) - Grafana dashboards and architecture diagrams
- **Architecture Decision Records:** [docs/adrs/](docs/adrs/) - Technical choices with trade-off analysis
- **Operational Runbooks:** [docs/runbooks/](docs/runbooks/) - P1 scenario procedures
- **Implementation Stories:** [docs/implementation-artifacts/](docs/implementation-artifacts/) - Story-by-story build documentation
- **PRD and Planning:** [docs/planning-artifacts/](docs/planning-artifacts/) - Requirements and architecture
- **Component READMEs:**
  - Infrastructure: [K3s](infrastructure/k3s/README.md) | [NFS](infrastructure/nfs/README.md) | [MetalLB](infrastructure/metallb/README.md) | [Traefik](infrastructure/traefik/README.md) | [cert-manager](infrastructure/cert-manager/README.md)
  - Applications: [PostgreSQL](applications/postgres/README.md) | [Ollama](applications/ollama/README.md) | [n8n](applications/n8n/README.md) | [Nginx](applications/nginx/README.md)
  - Monitoring: [Prometheus](monitoring/prometheus/README.md) | [Grafana](monitoring/grafana/README.md) | [Loki](monitoring/loki/README.md)

### External Resources

- **Blog Posts:** [docs/blog-posts/](docs/blog-posts/) - Technical write-ups and career narrative
  - [From Automotive Software to Kubernetes: Building a Production-Grade K3s Home Lab](docs/blog-posts/01-from-automotive-to-kubernetes.md)
- **LinkedIn:** [linkedin.com/in/tjetzinger](https://www.linkedin.com/in/tjetzinger/)

### Key Technologies

- [K3s Documentation](https://docs.k3s.io/)
- [Helm Charts](https://helm.sh/)
- [kube-prometheus-stack](https://github.com/prometheus-operator/kube-prometheus)
- [Traefik Ingress](https://doc.traefik.io/traefik/providers/kubernetes-ingress/)
- [cert-manager](https://cert-manager.io/)
- [MetalLB](https://metallb.universe.tf/)

---

## Current Workloads

| Application | Purpose | Status | URL |
|------------|---------|--------|-----|
| **Grafana** | Metrics visualization | ✅ Running | https://grafana.home.jetzinger.com |
| **Prometheus** | Metrics collection | ✅ Running | ClusterIP only |
| **Alertmanager** | Alert routing | ✅ Running | ClusterIP only |
| **Loki** | Log aggregation | ✅ Running | ClusterIP only |
| **PostgreSQL** | Relational database | ✅ Running | ClusterIP only |
| **Ollama** | LLM inference | ✅ Running | https://ollama.home.jetzinger.com |
| **n8n** | Workflow automation | ✅ Running | https://n8n.home.jetzinger.com |
| **Nginx** | Dev reverse proxy | ✅ Running | https://nginx.home.jetzinger.com |

**Future:** Paperless-ngx document management (planned)

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
