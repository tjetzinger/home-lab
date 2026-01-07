---
stepsCompleted: [1, 2, 3, 4, 5, 6, 7, 8]
workflow_completed: true
completedAt: '2025-12-27'
lastModified: '2025-12-29'
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

**Functional Requirements:** 63 FRs across 12 capability areas
- Cluster Operations (6): K3s lifecycle, node management
- Workload Management (7): Deployments, Helm, ingress
- Storage Management (5): NFS, PVCs, dynamic provisioning
- Networking & Ingress (5): Traefik, MetalLB, DNS, TLS
- Observability (7): Prometheus, Grafana, Alertmanager
- Data Services (5): PostgreSQL StatefulSet
- AI/ML Workloads (5): Ollama, vLLM, GPU scheduling
- Development Proxy (3): Nginx to local dev servers
- Cluster Maintenance (5): Upgrades, backups, Velero
- Portfolio & Documentation (6): ADRs, GitHub, blog
- Document Management (4): Paperless-ngx, Redis, OCR
- Dev Containers (5): VS Code SSH, Claude Code, git worktrees

**Non-Functional Requirements:** 27 NFRs
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
| LLM Inference | Ollama Helm chart | Official chart, CPU for MVP |
| GPU Support | Deferred to Phase 2 | Pending NUC acquisition |
| Model Storage | NFS PVC | Persist downloaded models |

### Document Management Architecture (Paperless-ngx)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Deployment | Paperless-ngx Helm chart | Community chart, production-ready |
| Backend | Redis (bundled) | Required for task queue, simpler than external |
| Database | SQLite | Sufficient for single-user, simpler ops |
| Document Storage | NFS PVC | Documents persist on Synology, snapshot-protected |
| OCR | Tesseract (bundled) | Included in Paperless-ngx image |
| Ingress | paperless.home.jetzinger.com | HTTPS via cert-manager |

**Integration Pattern:**
- Redis runs as sidecar or separate pod in `docs` namespace
- Document consumption folder mounted from NFS
- Export folder for processed documents on NFS

### Dev Containers Architecture

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Container Base | Custom Dockerfile | Tailored for VS Code + Claude Code tooling |
| Access Method | SSH via Nginx proxy | Nginx already handles routing in `dev` namespace |
| Workspace Storage | Local (emptyDir or node storage) | Fast I/O for git operations, builds |
| Provisioning | Kubernetes Deployment per container | Simple, declarative, easy to spin up/down |
| Git Worktree | Enabled in container | Multiple branches simultaneously |
| Tooling | VS Code Remote SSH + Claude Code | Standard remote dev workflow |

**Integration Pattern:**
- Nginx proxy routes SSH traffic to dev container pods
- Each dev container is a Deployment with SSH server enabled
- ConfigMaps store SSH authorized_keys
- Local storage for workspace (not NFS) for performance
- Git credentials via Kubernetes secrets

**Dev Container Lifecycle:**
```
Create: kubectl apply -f dev-container-{name}.yaml
Connect: VS Code → Remote SSH → nginx-proxy:port → container
Destroy: kubectl delete -f dev-container-{name}.yaml
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
│   │   └── pvc.yaml                   # Document storage PVC
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
| Document Management (FR55-58) | `applications/paperless/` | values, ingress, pvc |
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

**Functional Requirements:** 63/63 covered
**Non-Functional Requirements:** 27/27 covered

All requirements have explicit architectural support documented in Core Architectural Decisions and Project Structure sections.

**New Requirements (2025-12-29 Update):**
- FR55-58: Document Management (Paperless-ngx) — covered by Document Management Architecture
- FR59-63: Dev Containers — covered by Dev Containers Architecture

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
- 10 core architectural decisions made (added Paperless-ngx, Dev Containers)
- 6 implementation pattern categories defined
- 8 namespace boundaries established (added `docs`)
- 63 functional + 27 non-functional requirements supported

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

