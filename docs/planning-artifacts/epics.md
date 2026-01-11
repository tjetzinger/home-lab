---
stepsCompleted: [1, 2, 3, 4]
workflow_completed: true
completedAt: '2026-01-08'
lastModified: '2026-01-11'
inputDocuments:
  - 'docs/planning-artifacts/prd.md'
  - 'docs/planning-artifacts/architecture.md'
workflowType: 'epics-and-stories'
date: '2025-12-27'
author: 'Tom'
project_name: 'home-lab'
updateReason: 'Epic 12 updated with Solution A networking (FR100-103, NFR55-57): Tailscale mesh on all K3s nodes for cross-subnet GPU worker'
currentStep: 'Workflow Complete - Phase 3 epic added'
---

# home-lab - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for home-lab, decomposing the requirements from the PRD and Architecture into implementable stories.

## Requirements Inventory

### Functional Requirements

**Cluster Operations (6 FRs)**
- FR1: Operator can deploy a K3s control plane on a dedicated VM
- FR2: Operator can add worker nodes to the cluster
- FR3: Operator can remove worker nodes from the cluster without data loss
- FR4: Operator can view cluster node status and health
- FR5: Operator can access the cluster remotely via Tailscale
- FR6: Operator can run kubectl commands from any Tailscale-connected device

**Workload Management (7 FRs)**
- FR7: Operator can deploy containerized applications to the cluster
- FR8: Operator can deploy applications using Helm charts
- FR9: Operator can expose applications via ingress with HTTPS
- FR10: Operator can configure automatic TLS certificate provisioning
- FR11: Operator can assign workloads to specific namespaces
- FR12: Operator can scale deployments up or down
- FR13: Operator can view pod logs and events

**Storage Management (5 FRs)**
- FR14: Operator can provision persistent volumes from NFS storage
- FR15: Operator can create PersistentVolumeClaims for applications
- FR16: System provisions storage dynamically via StorageClass
- FR17: Operator can verify storage mount health
- FR18: Operator can backup persistent data to Synology snapshots

**Networking & Ingress (5 FRs)**
- FR19: Operator can expose services via LoadBalancer using MetalLB
- FR20: Operator can configure ingress routes via Traefik
- FR21: Operator can access services via *.home.jetzinger.com domain
- FR22: System resolves internal DNS via NextDNS rewrites
- FR23: Operator can view Traefik dashboard for ingress status

**Observability (7 FRs)**
- FR24: Operator can view cluster metrics in Grafana dashboards
- FR25: Operator can query Prometheus for historical metrics
- FR26: System collects metrics from all nodes via Node Exporter
- FR27: System collects Kubernetes object metrics via kube-state-metrics
- FR28: System sends alerts via Alertmanager when thresholds exceeded
- FR29: Operator can receive mobile notifications for P1 alerts
- FR30: Operator can view alert history and status

**Data Services (5 FRs)**
- FR31: Operator can deploy PostgreSQL as a StatefulSet
- FR32: PostgreSQL persists data to NFS storage
- FR33: Operator can backup PostgreSQL to NFS
- FR34: Operator can restore PostgreSQL from backup
- FR35: Applications can connect to PostgreSQL within cluster

**AI/ML Workloads (14 FRs)**
- FR36: Operator can deploy Ollama for LLM inference
- FR37: Applications can query Ollama API for completions
- FR38: Operator can deploy vLLM for production inference
- FR39: GPU workloads can request GPU resources via NVIDIA Operator
- FR40: Operator can deploy n8n for workflow automation
- FR71: GPU worker (Intel NUC + RTX 3060 eGPU) joins cluster via Tailscale overlay network
- FR72: vLLM serves DeepSeek-Coder 6.7B, Mistral 7B, and Llama 3.1 8B models simultaneously
- FR73: vLLM workloads gracefully degrade to Ollama CPU when GPU worker unavailable
- FR74: Operator can hot-plug GPU worker (add/remove on demand without cluster disruption)
- FR94: vLLM gracefully degrades when GPU is unavailable due to host workloads (Steam gaming)
- FR100: All K3s nodes (master, workers, GPU worker) run Tailscale for full mesh connectivity
- FR101: K3s configured with `--flannel-iface tailscale0` to route pod network over Tailscale
- FR102: K3s nodes advertise Tailscale IPs via `--node-external-ip` for cross-subnet communication
- FR103: NO_PROXY environment includes Tailscale CGNAT range (100.64.0.0/10) for kubectl logs

**Gaming Platform (5 FRs)**
- FR95: Intel NUC runs Steam on host Ubuntu OS (not containerized)
- FR96: Steam uses Proton for Windows game compatibility
- FR97: Operator can switch between Gaming Mode and ML Mode via script
- FR98: Gaming Mode scales vLLM pods to 0 and enables Ollama CPU fallback
- FR99: ML Mode restores vLLM pods when Steam/gaming exits

**Development Proxy (3 FRs)**
- FR41: Operator can configure Nginx to proxy to local dev servers
- FR42: Developer can access local dev servers via cluster ingress
- FR43: Operator can add/remove proxy targets without cluster restart

**Cluster Maintenance (5 FRs)**
- FR44: Operator can upgrade K3s version on nodes
- FR45: Operator can backup cluster state via Velero
- FR46: Operator can restore cluster from Velero backup
- FR47: System applies security updates to node OS automatically
- FR48: Operator can view upgrade history and rollback if needed

**Portfolio & Documentation (6 FRs)**
- FR49: Audience can view public GitHub repository
- FR50: Audience can read architecture decision records (ADRs)
- FR51: Audience can view Grafana dashboard screenshots
- FR52: Audience can read technical blog posts about the build
- FR53: Operator can document decisions as ADRs in repository
- FR54: Operator can publish blog posts to dev.to or similar platform

**Document Management - Paperless-ngx (7 FRs)**
- FR55: Operator can deploy Paperless-ngx with Redis backend
- FR56: Paperless-ngx persists documents to NFS storage
- FR57: User can access Paperless-ngx via ingress with HTTPS
- FR58: User can upload, tag, and search scanned documents
- FR64: Paperless-ngx performs OCR on uploaded documents with German and English language support
- FR65: System handles thousands of documents with ongoing scanning and manual upload workflow
- FR66: Paperless-ngx uses PostgreSQL backend for metadata storage (deferred to future epic)

**Dev Containers (9 FRs)**
- FR59: Nginx proxy routes to dev containers in `dev` namespace
- FR60: Operator can provision dev containers with git worktree support
- FR61: Developer can connect VS Code to dev container via Nginx proxy
- FR62: Developer can run Claude Code inside dev containers
- FR63: Dev containers use local storage for workspace data
- FR67: Dev containers use single base image with Node.js, Python, Claude Code CLI, git, kubectl, helm
- FR68: Each dev container allocated 2 CPU cores and 4GB RAM
- FR69: Dev containers mount persistent 10GB volumes for workspace data
- FR70: Dev containers isolated via NetworkPolicy (accessible only via nginx proxy)

### NonFunctional Requirements

**Reliability (6 NFRs)**
- NFR1: Cluster achieves 95%+ uptime measured monthly
- NFR2: Control plane recovers from VM restart within 5 minutes
- NFR3: Worker node failure does not cause service outage (pods reschedule)
- NFR4: NFS storage remains accessible during Synology firmware updates
- NFR5: Alertmanager sends P1 alerts within 1 minute of threshold breach
- NFR6: Cluster state can be restored from Velero backup within 30 minutes

**Security (6 NFRs)**
- NFR7: All ingress traffic uses TLS 1.2+ with valid certificates
- NFR8: Cluster API access requires Tailscale VPN connection
- NFR9: No services exposed to public internet without ingress authentication
- NFR10: Kubernetes secrets encrypted at rest (K3s default)
- NFR11: Node OS security updates applied within 7 days of release
- NFR12: kubectl access requires valid kubeconfig (no anonymous access)

**Performance (5 NFRs)**
- NFR13: Ollama API responds within 30 seconds for typical prompts
- NFR14: Grafana dashboards load within 5 seconds
- NFR15: Pod scheduling completes within 30 seconds of deployment
- NFR16: NFS-backed PVCs mount within 10 seconds
- NFR17: Traefik routes requests with <100ms added latency

**Operability (6 NFRs)**
- NFR18: All cluster components emit Prometheus metrics
- NFR19: Pod logs retained for 7 days minimum
- NFR20: K3s upgrades complete with zero data loss
- NFR21: New services deployable without cluster restart
- NFR22: Runbooks exist for all P1 alert scenarios
- NFR23: Single operator can manage entire cluster (no team required)

**Documentation Quality (4 NFRs)**
- NFR24: All architecture decisions documented as ADRs
- NFR25: README provides working cluster setup in <2 hours
- NFR26: All deployed services have documented purpose and configuration
- NFR27: Repository navigable by external reviewer (hiring manager)

**Document Management - Paperless-ngx (3 NFRs)**
- NFR28: Paperless-ngx OCR processes German and English text with 95%+ accuracy
- NFR29: Document library scales to 5,000+ documents without performance degradation
- NFR30: Document search returns results within 3 seconds for full-text queries

**Dev Containers (3 NFRs)**
- NFR31: Dev container provisioning completes within 90 seconds (image pull + volume mount)
- NFR32: Persistent volumes retain workspace data across container restarts
- NFR33: Dev containers isolated via NetworkPolicy (no cross-container communication)

**GPU/ML Infrastructure (9 NFRs)**
- NFR34: vLLM achieves 50+ tokens/second for Mistral 7B and Llama 3.1 8B on RTX 3060
- NFR35: vLLM handles 2-3 concurrent inference requests without significant performance degradation
- NFR36: GPU worker joins cluster and becomes Ready within 2 minutes of boot via Tailscale
- NFR37: NVIDIA GPU Operator installs and configures GPU drivers automatically (no manual setup)
- NFR38: vLLM serves multiple models simultaneously (DeepSeek-Coder 6.7B, Mistral 7B, Llama 3.1 8B)
- NFR50: vLLM detects GPU unavailability (host workload) within 10 seconds
- NFR55: Tailscale mesh establishes full connectivity between all K3s nodes within 60 seconds of node boot
- NFR56: Pod-to-pod communication works across subnets (192.168.2.x ↔ 192.168.0.x) via Tailscale overlay
- NFR57: MTU configured at 1280 bytes to prevent VXLAN fragmentation over Tailscale tunnel

**Gaming Platform (4 NFRs)**
- NFR51: Gaming Mode activation completes within 30 seconds (pod scale-down + VRAM release)
- NFR52: ML Mode restoration completes within 2 minutes (pod scale-up + model load)
- NFR53: Steam games achieve 60+ FPS at 1080p with exclusive GPU access
- NFR54: Graceful degradation to Ollama CPU maintains <5 second inference latency

### Additional Requirements

**From Architecture Document:**

- **Implementation Approach**: Manual + Helm (Learning-First) - VMs provisioned manually via Proxmox UI, K3s via curl installer
- **NFS Provisioner**: nfs-subdir-external-provisioner via Helm with dynamic StorageClass
- **Observability Stack**: kube-prometheus-stack (includes Prometheus, Grafana, Alertmanager, Node Exporter, kube-state-metrics)
- **Log Aggregation**: Loki with Promtail for log collection
- **PostgreSQL**: Bitnami Helm chart with NFS-backed PVC
- **Ollama**: Official Helm chart, CPU for MVP (GPU deferred to Phase 2)
- **Backup Strategy**: etcd snapshots (K3s built-in) + pg_dump to NFS + Git repository for manifests
- **TLS**: cert-manager with Let's Encrypt Production issuer
- **Naming Patterns**: {app}-{component} for resources, Kubernetes recommended labels (app.kubernetes.io/*)
- **Repository Structure**: Layer-based (infrastructure/, applications/, monitoring/, docs/, scripts/)
- **Helm Values Pattern**: values-homelab.yaml for each chart
- **Implementation Sequence**: K3s → NFS → cert-manager → MetalLB → kube-prometheus-stack → Loki → PostgreSQL → Ollama → Nginx

**Namespace Strategy:**
| Namespace | Purpose |
|-----------|---------|
| kube-system | K3s core, Traefik |
| infra | MetalLB, cert-manager, NFS provisioner |
| monitoring | Prometheus, Grafana, Loki, Alertmanager |
| data | PostgreSQL |
| apps | n8n |
| ml | Ollama, vLLM (GPU workloads) |
| docs | Paperless-ngx, Redis |
| dev | Nginx proxy, dev containers |

**Phase 2 Architecture Additions:**

**Document Management (Paperless-ngx):**
- Backend: PostgreSQL (shared with existing cluster database, not Redis)
- OCR: Tesseract with German (deu) + English (eng) language packs
- Storage: NFS PVC for documents (snapshot-protected)
- Scaling: PostgreSQL backend supports 5,000+ documents
- Deployment: Community Helm chart with custom values

**Dev Containers:**
- Base image: Single Dockerfile with Node.js, Python, Claude Code CLI, git, kubectl, helm
- Access: SSH via Nginx proxy (nginx already handles routing in `dev` namespace)
- Storage: Hybrid model (Git repos on NFS PVC 10GB, build artifacts on emptyDir)
- Resources: 2 CPU cores, 4GB RAM per container
- Capacity: Cluster supports 2-3 dev containers simultaneously
- NetworkPolicy: Moderate isolation (access cluster services, no cross-container communication)
- Lifecycle: Kubernetes Deployment per container, SSH server enabled

**GPU/ML Infrastructure (vLLM + RTX 3060):**
- GPU Worker: Intel NUC + RTX 3060 12GB eGPU
- GPU Networking: Solution A - Manual Tailscale on all K3s nodes for full mesh connectivity
- K3s Configuration: `--flannel-iface tailscale0` + `--node-external-ip <tailscale-ip>`
- MTU: 1280 bytes (prevents VXLAN fragmentation over Tailscale)
- NO_PROXY: Must include `100.64.0.0/10` for kubectl logs/exec to work
- Models: DeepSeek-Coder 6.7B, Mistral 7B, Llama 3.1 8B (4-bit quantized)
- Model Serving: Single vLLM instance, 3 models loaded in memory
- Context Window: 8K-16K tokens per request
- VRAM Allocation: ~16GB total (10-11GB models, 1-2GB KV cache, remaining headroom)
- Hot-plug Capability: GPU worker can join/leave cluster without disruption
- Graceful Degradation: vLLM workloads fall back to Ollama CPU when GPU offline
- GPU Scheduling: NVIDIA GPU Operator for automatic driver installation

**Node Topology:**
| Node | Role | Physical IP | Tailscale IP |
|------|------|-------------|--------------|
| k3s-master | Control plane | 192.168.2.20 | 100.x.x.a |
| k3s-worker-01 | General compute | 192.168.2.21 | 100.x.x.b |
| k3s-worker-02 | General compute | 192.168.2.22 | 100.x.x.c |
| k3s-gpu-worker | GPU (Intel NUC) | 192.168.0.25 | 100.x.x.d |

**MetalLB IP Pool:** 192.168.2.100-120

### FR Coverage Map

| FR | Epic | Description |
|----|------|-------------|
| FR1 | Epic 1 | Deploy K3s control plane on VM |
| FR2 | Epic 1 | Add worker nodes to cluster |
| FR3 | Epic 1 | Remove worker nodes without data loss |
| FR4 | Epic 1 | View cluster node status and health |
| FR5 | Epic 1 | Access cluster remotely via Tailscale |
| FR6 | Epic 1 | Run kubectl from Tailscale-connected device |
| FR7 | Epic 4 | Deploy containerized applications (validated with Prometheus) |
| FR8 | Epic 5 | Deploy applications using Helm charts (validated with PostgreSQL) |
| FR9 | Epic 3 | Expose applications via ingress with HTTPS |
| FR10 | Epic 3 | Configure automatic TLS certificate provisioning |
| FR11 | Epic 4 | Assign workloads to specific namespaces |
| FR12 | Epic 6 | Scale deployments up or down |
| FR13 | Epic 6 | View pod logs and events |
| FR14 | Epic 2 | Provision persistent volumes from NFS |
| FR15 | Epic 2 | Create PersistentVolumeClaims for applications |
| FR16 | Epic 2 | System provisions storage dynamically via StorageClass |
| FR17 | Epic 2 | Verify storage mount health |
| FR18 | Epic 2 | Backup persistent data to Synology snapshots |
| FR19 | Epic 3 | Expose services via LoadBalancer using MetalLB |
| FR20 | Epic 3 | Configure ingress routes via Traefik |
| FR21 | Epic 3 | Access services via *.home.jetzinger.com domain |
| FR22 | Epic 3 | System resolves internal DNS via NextDNS |
| FR23 | Epic 3 | View Traefik dashboard for ingress status |
| FR24 | Epic 4 | View cluster metrics in Grafana dashboards |
| FR25 | Epic 4 | Query Prometheus for historical metrics |
| FR26 | Epic 4 | System collects metrics from all nodes via Node Exporter |
| FR27 | Epic 4 | System collects K8s object metrics via kube-state-metrics |
| FR28 | Epic 4 | System sends alerts via Alertmanager |
| FR29 | Epic 4 | Receive mobile notifications for P1 alerts |
| FR30 | Epic 4 | View alert history and status |
| FR31 | Epic 5 | Deploy PostgreSQL as StatefulSet |
| FR32 | Epic 5 | PostgreSQL persists data to NFS storage |
| FR33 | Epic 5 | Backup PostgreSQL to NFS |
| FR34 | Epic 5 | Restore PostgreSQL from backup |
| FR35 | Epic 5 | Applications can connect to PostgreSQL |
| FR36 | Epic 6 | Deploy Ollama for LLM inference |
| FR37 | Epic 6 | Applications can query Ollama API |
| FR38 | Epic 12 | Deploy vLLM for production inference |
| FR39 | Epic 12 | GPU workloads request GPU resources via NVIDIA Operator |
| FR40 | Epic 6 | Deploy n8n for workflow automation |
| FR41 | Epic 7 | Configure Nginx to proxy to local dev servers |
| FR42 | Epic 7 | Access local dev servers via cluster ingress |
| FR43 | Epic 7 | Add/remove proxy targets without cluster restart |
| FR44 | Epic 8 | Upgrade K3s version on nodes |
| FR45 | Epic 8 | Backup cluster state via Velero |
| FR46 | Epic 8 | Restore cluster from Velero backup |
| FR47 | Epic 8 | System applies security updates to node OS |
| FR48 | Epic 8 | View upgrade history and rollback if needed |
| FR49 | Epic 9 | Audience can view public GitHub repository |
| FR50 | Epic 9 | Audience can read ADRs |
| FR51 | Epic 9 | Audience can view Grafana dashboard screenshots |
| FR52 | Epic 9 | Audience can read technical blog posts |
| FR53 | Epic 9 | Document decisions as ADRs in repository |
| FR54 | Epic 9 | Publish blog posts to dev.to or similar |
| FR55 | Epic 10 | Deploy Paperless-ngx with Redis backend |
| FR56 | Epic 10 | Paperless-ngx persists documents to NFS |
| FR57 | Epic 10 | Access Paperless-ngx via ingress with HTTPS |
| FR58 | Epic 10 | Upload, tag, and search scanned documents |
| FR59 | Epic 11 | Nginx proxy routes to dev containers |
| FR60 | Epic 11 | Provision dev containers with git worktree support |
| FR61 | Epic 11 | Connect VS Code to dev container via Nginx |
| FR62 | Epic 11 | Run Claude Code inside dev containers |
| FR63 | Epic 11 | Dev containers use local storage for workspace |
| FR64 | Epic 10 | Paperless-ngx performs OCR with German and English support |
| FR65 | Epic 10 | System handles thousands of documents |
| FR66 | Epic 10 | Paperless-ngx uses PostgreSQL backend for metadata (deferred to future) |
| FR67 | Epic 11 | Dev containers use single base image with standard tools |
| FR68 | Epic 11 | Each dev container allocated 2 CPU cores and 4GB RAM |
| FR69 | Epic 11 | Dev containers mount persistent 10GB volumes |
| FR70 | Epic 11 | Dev containers isolated via NetworkPolicy |
| FR71 | Epic 12 | GPU worker joins cluster via Tailscale overlay network |
| FR72 | Epic 12 | vLLM serves 3 models simultaneously (DeepSeek-Coder, Mistral, Llama) |
| FR73 | Epic 12 | vLLM workloads degrade gracefully to Ollama CPU when GPU offline |
| FR74 | Epic 12 | Operator can hot-plug GPU worker without cluster disruption |
| FR94 | Epic 12 | vLLM gracefully degrades when GPU unavailable due to host workloads |
| FR95 | Epic 13 | Intel NUC runs Steam on host Ubuntu OS |
| FR96 | Epic 13 | Steam uses Proton for Windows game compatibility |
| FR97 | Epic 13 | Operator can switch between Gaming Mode and ML Mode via script |
| FR98 | Epic 13 | Gaming Mode scales vLLM pods to 0 and enables CPU fallback |
| FR99 | Epic 13 | ML Mode restores vLLM pods when gaming exits |
| FR100 | Epic 12 | All K3s nodes run Tailscale for full mesh connectivity |
| FR101 | Epic 12 | K3s configured with --flannel-iface tailscale0 |
| FR102 | Epic 12 | K3s nodes advertise Tailscale IPs via --node-external-ip |
| FR103 | Epic 12 | NO_PROXY includes Tailscale CGNAT range (100.64.0.0/10) |

**Coverage Summary:** 103 FRs total, 57 NFRs total
- **Phase 1 (Epic 1-9):** 54 FRs completed
- **Phase 2 (Epic 10-12):** 43 FRs (20 original + 23 additions)
  - Epic 10 (Paperless-ngx): FR55-58, FR64-66, FR75-93
  - Epic 11 (Dev Containers): FR59-63, FR67-70
  - Epic 12 (GPU/ML): FR38-39, FR71-74, FR94, FR100-103
- **Phase 3 (Epic 13):** 5 FRs
  - Epic 13 (Steam Gaming): FR95-99

## Epic List

### Epic 1: Foundation - K3s Cluster with Remote Access
Tom has a working multi-node K3s cluster he can access from anywhere via Tailscale.
**FRs covered:** FR1, FR2, FR3, FR4, FR5, FR6

### Epic 2: Storage & Persistence
Tom can provision persistent NFS storage for any application needing data persistence.
**FRs covered:** FR14, FR15, FR16, FR17, FR18

### Epic 3: Ingress, TLS & Service Exposure
Tom can expose any service with HTTPS via *.home.jetzinger.com domains.
**FRs covered:** FR9, FR10, FR19, FR20, FR21, FR22, FR23

### Epic 4: Observability Stack
Tom can monitor the cluster, view dashboards, and receive P1 alerts on his phone.
**FRs covered:** FR7, FR11, FR24, FR25, FR26, FR27, FR28, FR29, FR30

### Epic 5: PostgreSQL Database Service
Tom has a production-grade PostgreSQL database with backup and restore capability.
**FRs covered:** FR8, FR31, FR32, FR33, FR34, FR35

### Epic 6: AI Inference Platform
Tom can run LLM inference (Ollama) and workflow automation (n8n) on the cluster.
**FRs covered:** FR12, FR13, FR36, FR37, FR40

### Epic 7: Development Proxy
Tom can access local development servers through cluster ingress.
**FRs covered:** FR41, FR42, FR43

### Epic 8: Cluster Operations & Maintenance
Tom can upgrade K3s, backup/restore the cluster, and maintain long-term operations.
**FRs covered:** FR44, FR45, FR46, FR47, FR48

### Epic 9: Portfolio & Public Showcase
Tom has a polished public portfolio that demonstrates capability to hiring managers and recruiters.
**FRs covered:** FR49, FR50, FR51, FR52, FR53, FR54

### Epic 10: Document Management System (Paperless-ngx Ecosystem) [Phase 2]

**User Outcome:** Tom can digitize, organize, and search thousands of scanned documents with OCR support for German and English, AI-powered auto-tagging, Office document processing, PDF editing, and automatic email attachment import—replacing physical paper filing with a comprehensive digital archive.

**FRs covered:** FR55-58, FR64-66, FR75-93
- FR55: Deploy Paperless-ngx with Redis backend
- FR56: Documents persist to NFS storage
- FR57: Access via HTTPS ingress
- FR58: Upload, tag, and search documents
- FR64: OCR with German and English language support
- FR65: Handle thousands of documents (ongoing workflow)
- FR66: PostgreSQL backend for metadata
- FR75: Single-user operation with folder-based organization
- FR76: Duplicate document detection on import
- FR77: NFS mount for consume folders from workstation
- FR78: Auto-import from consume folders within 30 seconds
- FR79: CSRF protection for web interface
- FR80: CORS restricted to authorized origins
- FR81: Apache Tika for Office document text extraction
- FR82: Gotenberg for Office-to-PDF conversion
- FR83: Direct import of Word, Excel, PowerPoint, LibreOffice formats
- FR84: Stirling-PDF for PDF manipulation
- FR85: Split, merge, rotate, compress PDFs via web UI
- FR86: Stirling-PDF ingress with HTTPS
- FR87: Paperless-AI connects to GPU Ollama (Intel NUC + RTX 3060)
- FR88: LLM-based auto-tagging via GPU-accelerated inference
- FR89: Auto-populate correspondents and document types
- FR90: Monitor private email inbox via IMAP
- FR91: Monitor Gmail inbox via IMAP
- FR92: Auto-import email attachments (PDF, Office docs)
- FR93: Email bridge container for IMAP access

**NFRs covered:** NFR28-30, NFR39-49
- NFR28: 95%+ OCR accuracy (German/English)
- NFR29: Scale to 5,000+ documents
- NFR30: 3-second full-text search
- NFR39: NFS polling mode (inotify incompatible)
- NFR40: 10-second polling interval
- NFR41: 2 parallel OCR workers
- NFR42: GPU inference throughput 50+ tokens/sec
- NFR43: AI classification within 10 seconds per document

**Implementation Notes:**
- PostgreSQL backend (shared cluster database)
- Tesseract OCR with German (deu) + English (eng) language packs
- NFS storage with Synology snapshot protection
- gabe565 Helm chart for Paperless-ngx
- Apache Tika + Gotenberg for Office document processing
- Stirling-PDF via official Helm chart
- Paperless-AI connector to GPU Ollama on Intel NUC
- Email bridge for private email + Gmail direct IMAP

---

### Epic 11: Dev Containers Platform [Phase 2]

**User Outcome:** Tom can develop remotely using isolated dev containers with VS Code and Claude Code, accessing full development tooling via SSH through the cluster's Nginx proxy with persistent workspace storage.

**FRs covered:** FR59, FR60, FR61, FR62, FR63, FR67, FR68, FR69, FR70
- FR59: Nginx proxy routes to dev containers
- FR60: Provision dev containers with git worktree support
- FR61: Connect VS Code via Nginx proxy
- FR62: Run Claude Code inside dev containers
- FR63: Use local storage for workspace data
- FR67: Single base image (Node.js, Python, Claude Code CLI, git, kubectl, helm)
- FR68: 2 CPU cores, 4GB RAM per container
- FR69: Persistent 10GB volumes for workspace data
- FR70: NetworkPolicy isolation (accessible only via nginx proxy)

**NFRs covered:** NFR31, NFR32, NFR33
- NFR31: 90-second provisioning time
- NFR32: Persistent workspace data across restarts
- NFR33: NetworkPolicy isolation (no cross-container communication)

**Implementation Notes:**
- Single base Docker image with standard dev tools
- Hybrid storage: NFS PVC (10GB) for git repos, emptyDir for build artifacts
- SSH access via Nginx stream proxy
- Cluster capacity: 2-3 concurrent dev containers
- NetworkPolicy: Access cluster services, blocked cross-container

---

### Epic 12: GPU/ML Inference Platform (vLLM + RTX 3060) [Phase 2]

**User Outcome:** Tom can run GPU-accelerated LLM inference with vLLM serving multiple models simultaneously on a hot-pluggable GPU worker, with automatic graceful degradation to Ollama CPU when the GPU worker is offline or host is using the GPU for gaming, enabling fast AI inference for n8n workflows, Paperless-ngx document classification, and development tasks.

**FRs covered:** FR38, FR39, FR71-74, FR87-89, FR94, FR100-103
- FR38: Deploy vLLM for production inference
- FR39: GPU workloads request GPU resources via NVIDIA Operator
- FR71: GPU worker (Intel NUC + RTX 3060) joins cluster via Tailscale mesh (Solution A)
- FR72: vLLM serves DeepSeek-Coder 6.7B, Mistral 7B, Llama 3.1 8B simultaneously
- FR73: Graceful degradation to Ollama CPU when GPU offline
- FR74: Hot-plug GPU worker (add/remove without cluster disruption)
- FR87: Paperless-AI connects to GPU Ollama (Intel NUC + RTX 3060)
- FR88: LLM-based auto-tagging via GPU-accelerated inference
- FR89: Auto-populate correspondents and document types from content
- FR94: vLLM gracefully degrades when GPU unavailable due to host workloads (Steam gaming)
- FR100: All K3s nodes run Tailscale for full mesh connectivity
- FR101: K3s configured with `--flannel-iface tailscale0` for pod networking
- FR102: K3s nodes advertise Tailscale IPs via `--node-external-ip`
- FR103: NO_PROXY includes Tailscale CGNAT range (100.64.0.0/10)

**NFRs covered:** NFR34-38, NFR42-43, NFR50, NFR55-57
- NFR34: 50+ tokens/second throughput (Mistral, Llama)
- NFR35: Handle 2-3 concurrent inference requests
- NFR36: GPU worker joins cluster in 2 minutes via Tailscale
- NFR37: NVIDIA GPU Operator installs drivers automatically
- NFR38: Multi-model serving (3 models in memory)
- NFR42: GPU inference throughput 50+ tokens/sec for document classification
- NFR43: AI classification within 10 seconds per document
- NFR50: vLLM detects GPU unavailability within 10 seconds
- NFR55: Tailscale mesh establishes connectivity within 60 seconds
- NFR56: Pod-to-pod communication across subnets (192.168.0.x ↔ 192.168.2.x)
- NFR57: MTU 1280 bytes for VXLAN over Tailscale

**Implementation Notes:**
- Intel NUC + RTX 3060 eGPU (12GB VRAM) on 192.168.0.25
- **Solution A Networking:** Tailscale mesh on ALL K3s nodes (master, workers, GPU worker)
- K3s config: `--flannel-iface tailscale0 --node-external-ip <tailscale-ip>`
- Cross-subnet: 192.168.0.x (Intel NUC) ↔ 192.168.2.x (K3s cluster) via Tailscale
- 3 models (4-bit quantized): DeepSeek-Coder 6.7B, Mistral 7B, Llama 3.1 8B
- VRAM allocation: ~10-11GB models, ~1-2GB KV cache
- Context window: 8K-16K tokens per request
- NVIDIA GPU Operator for automatic driver management
- Fallback routing: vLLM (GPU) → Ollama (CPU) when GPU worker unavailable
- Paperless-AI connector for document auto-classification via Ollama
- Dual-use GPU: Shared between K8s ML workloads and host Steam gaming

---

### Epic 13: Steam Gaming Platform (Dual-Use GPU) [Phase 3]

**User Outcome:** Tom can use the Intel NUC + RTX 3060 for both Steam gaming (Windows games via Proton) AND ML inference (vLLM), switching between modes with a simple script that gracefully scales down K8s workloads when gaming and restores them afterward.

**FRs covered:** FR95-99
- FR95: Intel NUC runs Steam on host Ubuntu OS (not containerized)
- FR96: Steam uses Proton for Windows game compatibility
- FR97: Operator can switch between Gaming Mode and ML Mode via script
- FR98: Gaming Mode scales vLLM pods to 0 and enables Ollama CPU fallback
- FR99: ML Mode restores vLLM pods when Steam/gaming exits

**NFRs covered:** NFR51-54
- NFR51: Gaming Mode activation completes within 30 seconds (pod scale-down + VRAM release)
- NFR52: ML Mode restoration completes within 2 minutes (pod scale-up + model load)
- NFR53: Steam games achieve 60+ FPS at 1080p with exclusive GPU access
- NFR54: Graceful degradation to Ollama CPU maintains <5 second inference latency

**Implementation Notes:**
- Steam runs on host Ubuntu OS (graphics workloads don't containerize well)
- Mode switching via `/usr/local/bin/gpu-mode gaming|ml` script
- RTX 3060 12GB VRAM cannot run gaming (6-8GB) + vLLM (10-11GB) simultaneously
- n8n workflows detect GPU unavailability and route to Ollama CPU fallback
- Gaming Mode: `kubectl scale deployment/vllm --replicas=0 -n ml`
- ML Mode: `kubectl scale deployment/vllm --replicas=1 -n ml`
- NVIDIA driver configured with `nvidia-drm.modeset=1` for PRIME support

---

## Epic 1: Foundation - K3s Cluster with Remote Access

Tom has a working multi-node K3s cluster he can access from anywhere via Tailscale.

---

### Story 1.1: Create K3s Control Plane

As a **cluster operator**,
I want **to deploy a K3s control plane on a dedicated VM**,
So that **I have a working Kubernetes cluster foundation**.

**Acceptance Criteria:**

**Given** Proxmox host is running with available resources
**When** I create a VM with 2 vCPU, 4GB RAM, 32GB disk at 192.168.2.20
**Then** the VM boots successfully with Ubuntu Server
**And** SSH access is available

**Given** the control plane VM is running
**When** I run the K3s installation script with `--write-kubeconfig-mode 644`
**Then** K3s server starts successfully
**And** `kubectl get nodes` shows the master node as Ready
**And** the node token is available at `/var/lib/rancher/k3s/server/node-token`

**Given** the K3s control plane is running
**When** I check cluster health with `kubectl get componentstatuses`
**Then** all components report Healthy status

---

### Story 1.2: Add First Worker Node

As a **cluster operator**,
I want **to add a worker node to the cluster**,
So that **workloads can be scheduled on dedicated compute resources**.

**Acceptance Criteria:**

**Given** K3s control plane is running and accessible
**When** I create a VM with 4 vCPU, 8GB RAM, 50GB disk at 192.168.2.21
**Then** the VM boots successfully with Ubuntu Server
**And** SSH access is available

**Given** the worker VM is running and can reach the control plane
**When** I run the K3s agent installation with the server URL and node token
**Then** the agent joins the cluster successfully
**And** `kubectl get nodes` shows k3s-worker-01 as Ready

**Given** both nodes are Ready
**When** I deploy a test pod without node selector
**Then** the pod schedules to the worker node (not master)
**And** the pod reaches Running state

---

### Story 1.3: Add Second Worker Node

As a **cluster operator**,
I want **to add a second worker node to the cluster**,
So that **I have redundancy and can test multi-node scheduling**.

**Acceptance Criteria:**

**Given** K3s cluster has master and one worker running
**When** I create a VM with 4 vCPU, 8GB RAM, 50GB disk at 192.168.2.22
**Then** the VM boots successfully with Ubuntu Server
**And** SSH access is available

**Given** the second worker VM is running
**When** I run the K3s agent installation with the server URL and node token
**Then** the agent joins the cluster successfully
**And** `kubectl get nodes` shows 3 nodes all in Ready state

**Given** three nodes are Ready
**When** I deploy a Deployment with 3 replicas
**Then** pods are distributed across worker nodes
**And** no pods schedule to the master node (unless toleration set)

---

### Story 1.4: Configure Remote kubectl Access

As a **cluster operator**,
I want **to run kubectl commands from any Tailscale-connected device**,
So that **I can manage the cluster remotely without SSH**.

**Acceptance Criteria:**

**Given** K3s cluster is running with all nodes Ready
**When** I copy `/etc/rancher/k3s/k3s.yaml` to my local `~/.kube/config`
**Then** the kubeconfig file contains valid cluster credentials

**Given** the kubeconfig references `127.0.0.1:6443`
**When** I update the server URL to `https://192.168.2.20:6443`
**Then** kubectl can connect to the cluster from the local network

**Given** Tailscale is configured with subnet routing to 192.168.2.0/24
**When** I run `kubectl get nodes` from a Tailscale-connected laptop outside the home network
**Then** the command succeeds and shows all 3 nodes
**And** response time is under 2 seconds

**Given** remote kubectl access is working
**When** I attempt kubectl without valid kubeconfig
**Then** access is denied (NFR12: no anonymous access)

---

### Story 1.5: Document Node Removal Procedure

As a **cluster operator**,
I want **to safely remove a worker node without data loss**,
So that **I can perform maintenance or replace failed nodes**.

**Acceptance Criteria:**

**Given** cluster has 3 nodes with pods running on all workers
**When** I run `kubectl drain k3s-worker-02 --ignore-daemonsets --delete-emptydir-data`
**Then** all non-DaemonSet pods are evicted from the node
**And** pods reschedule to k3s-worker-01

**Given** node is drained
**When** I run `kubectl delete node k3s-worker-02`
**Then** the node is removed from cluster
**And** `kubectl get nodes` shows only 2 nodes

**Given** node removal is complete
**When** I check application health
**Then** all applications remain accessible
**And** no data loss has occurred (NFR3)

**Given** the procedure is validated
**When** I document it in `docs/runbooks/node-removal.md`
**Then** the runbook includes drain, delete, and rejoin steps
**And** recovery procedure is documented

---

## Epic 2: Storage & Persistence

Tom can provision persistent NFS storage for any application needing data persistence.

---

### Story 2.1: Deploy NFS Storage Provisioner

As a **cluster operator**,
I want **to deploy an NFS provisioner that creates PersistentVolumes automatically**,
So that **applications can request storage without manual PV creation**.

**Acceptance Criteria:**

**Given** Synology NFS share is configured at 192.168.2.2:/volume1/k8s-data
**When** I verify NFS connectivity from a worker node with `showmount -e 192.168.2.2`
**Then** the k8s-data export is visible
**And** worker nodes are in the allowed hosts list

**Given** NFS is accessible from all cluster nodes
**When** I deploy nfs-subdir-external-provisioner via Helm with `values-homelab.yaml`
**Then** the provisioner pod starts in the `infra` namespace
**And** pod status shows Running

**Given** the provisioner is running
**When** I check for StorageClass with `kubectl get storageclass`
**Then** `nfs-client` StorageClass exists
**And** it is marked as the default StorageClass

**Given** the StorageClass is configured
**When** I inspect StorageClass details
**Then** reclaim policy is set to Delete
**And** provisioner is set to `cluster.local/nfs-subdir-external-provisioner`

---

### Story 2.2: Create and Test PersistentVolumeClaim

As a **cluster operator**,
I want **to create PersistentVolumeClaims that automatically provision storage**,
So that **applications can persist data without manual intervention**.

**Acceptance Criteria:**

**Given** NFS provisioner is running with default StorageClass
**When** I create a PVC requesting 1Gi of storage
**Then** the PVC status transitions to Bound within 30 seconds
**And** a corresponding PV is automatically created

**Given** the PVC is Bound
**When** I create a test pod that mounts the PVC
**Then** the pod starts successfully
**And** the volume mounts within 10 seconds (NFR16)

**Given** the test pod is running with mounted volume
**When** I write a file to the mounted path
**Then** the file persists on the Synology NFS share
**And** the file path follows pattern `{namespace}-{pvc-name}-{pv-id}/`

**Given** data is written to the volume
**When** I delete and recreate the pod (same PVC)
**Then** the previously written data is still accessible
**And** no data loss occurs

---

### Story 2.3: Verify Storage Mount Health

As a **cluster operator**,
I want **to verify NFS mount health across the cluster**,
So that **I can detect storage issues before they affect applications**.

**Acceptance Criteria:**

**Given** NFS provisioner and test PVC are deployed
**When** I run `kubectl get pv` and `kubectl get pvc --all-namespaces`
**Then** all PVs show Available or Bound status
**And** all PVCs show Bound status

**Given** pods are using NFS-backed volumes
**When** I exec into a pod and run `df -h` on the mount point
**Then** the NFS mount is visible with correct capacity
**And** used/available space is reported accurately

**Given** NFS storage is operational
**When** Synology performs a firmware update (simulated by brief NFS restart)
**Then** existing mounts recover automatically
**And** pods do not crash (NFR4)

**Given** I need ongoing health visibility
**When** I create a storage health check script at `scripts/health-check.sh`
**Then** the script validates NFS connectivity, PV/PVC status, and mount health
**And** returns exit code 0 for healthy, non-zero for issues

---

### Story 2.4: Configure Synology Snapshots for Backup

As a **cluster operator**,
I want **to configure Synology snapshots for the k8s-data volume**,
So that **I can recover from accidental data deletion or corruption**.

**Acceptance Criteria:**

**Given** Synology DS920+ is accessible via web UI
**When** I configure Snapshot Replication for /volume1/k8s-data
**Then** hourly snapshots are scheduled
**And** retention policy keeps 24 hourly + 7 daily snapshots

**Given** snapshots are configured
**When** an hourly snapshot runs
**Then** the snapshot completes successfully
**And** snapshot is visible in Synology Snapshot Replication

**Given** data exists in a PVC
**When** I accidentally delete files from the NFS mount
**Then** I can restore from a Synology snapshot via the web UI
**And** the data is recovered without affecting running pods

**Given** backup strategy is validated
**When** I document the procedure in `docs/runbooks/nfs-restore.md`
**Then** the runbook includes snapshot location, restore steps, and verification
**And** recovery time objective is documented

---

## Epic 3: Ingress, TLS & Service Exposure

Tom can expose any service with HTTPS via *.home.jetzinger.com domains.

---

### Story 3.1: Deploy MetalLB for LoadBalancer Services

As a **cluster operator**,
I want **to deploy MetalLB so Services of type LoadBalancer get external IPs**,
So that **I can expose services outside the cluster on my home network**.

**Acceptance Criteria:**

**Given** K3s cluster is running with all nodes Ready
**When** I deploy MetalLB via Helm with `values-homelab.yaml` to the `infra` namespace
**Then** the MetalLB controller and speaker pods start successfully
**And** all pods show Running status

**Given** MetalLB is running
**When** I apply an IPAddressPool for range 192.168.2.100-192.168.2.120
**Then** the pool is created successfully
**And** `kubectl get ipaddresspools -n infra` shows the pool

**Given** MetalLB and IP pool are configured
**When** I apply an L2Advertisement for the pool
**Then** MetalLB can announce IPs via ARP on the home network

**Given** MetalLB is fully configured
**When** I create a test Service of type LoadBalancer
**Then** the Service receives an external IP from the pool (e.g., 192.168.2.100)
**And** the IP is reachable from other devices on the home network

---

### Story 3.2: Configure Traefik Ingress Controller

As a **cluster operator**,
I want **to configure Traefik as my ingress controller with a dashboard**,
So that **I can route HTTP traffic to services and monitor ingress status**.

**Acceptance Criteria:**

**Given** K3s is installed (Traefik is included by default)
**When** I check for Traefik in kube-system namespace
**Then** Traefik pods are running
**And** Traefik Service exists with LoadBalancer type

**Given** MetalLB is configured
**When** I verify Traefik Service external IP
**Then** Traefik has an IP from the MetalLB pool (e.g., 192.168.2.100)
**And** port 80 and 443 are accessible from the home network

**Given** Traefik is running with external IP
**When** I enable the Traefik dashboard via IngressRoute
**Then** the dashboard is accessible at traefik.home.jetzinger.com
**And** I can view routers, services, and middlewares

**Given** Traefik dashboard is accessible
**When** I review ingress routing latency
**Then** Traefik adds less than 100ms latency to requests (NFR17)

---

### Story 3.3: Deploy cert-manager with Let's Encrypt

As a **cluster operator**,
I want **to deploy cert-manager that automatically provisions TLS certificates**,
So that **all my services can use valid HTTPS without manual certificate management**.

**Acceptance Criteria:**

**Given** cluster is running with ingress working
**When** I deploy cert-manager via Helm to the `infra` namespace
**Then** cert-manager controller, webhook, and cainjector pods are Running
**And** CRDs for Certificate, Issuer, ClusterIssuer are installed

**Given** cert-manager is running
**When** I create a ClusterIssuer for Let's Encrypt Production with HTTP-01 challenge
**Then** the ClusterIssuer shows Ready status
**And** `kubectl describe clusterissuer letsencrypt-prod` shows no errors

**Given** ClusterIssuer is ready
**When** I create a test Certificate resource for test.home.jetzinger.com
**Then** cert-manager requests a certificate from Let's Encrypt
**And** the Certificate status shows Ready within 2 minutes
**And** a Secret containing tls.crt and tls.key is created

**Given** certificates are provisioned automatically
**When** I inspect the certificate
**Then** it uses TLS 1.2 or higher (NFR7)
**And** certificate is valid and not self-signed

---

### Story 3.4: Configure DNS with NextDNS Rewrites

As a **cluster operator**,
I want **to configure NextDNS to resolve *.home.jetzinger.com to my cluster ingress**,
So that **I can access services by name from any device on my network**.

**Acceptance Criteria:**

**Given** Traefik has external IP 192.168.2.100 (or similar from MetalLB pool)
**When** I log into NextDNS dashboard
**Then** I can access the Rewrites configuration section

**Given** NextDNS Rewrites section is accessible
**When** I add a rewrite rule: `*.home.jetzinger.com` -> `192.168.2.100`
**Then** the rule is saved successfully
**And** the rule appears in the active rewrites list

**Given** DNS rewrite is configured
**When** I query `nslookup grafana.home.jetzinger.com` from a network device
**Then** the query resolves to 192.168.2.100
**And** any subdomain of home.jetzinger.com resolves to the same IP

**Given** DNS is working
**When** I access http://traefik.home.jetzinger.com from a browser
**Then** the request reaches Traefik
**And** the Traefik dashboard loads (or appropriate response)

---

### Story 3.5: Create First HTTPS Ingress Route

As a **cluster operator**,
I want **to create an HTTPS ingress route with automatic TLS**,
So that **I can verify the complete ingress pipeline works end-to-end**.

**Acceptance Criteria:**

**Given** MetalLB, Traefik, cert-manager, and DNS are all configured
**When** I deploy a simple nginx pod and Service in the `dev` namespace
**Then** the pod is Running and Service is created

**Given** the test service exists
**When** I create an IngressRoute for hello.home.jetzinger.com with TLS enabled
**Then** the IngressRoute is created with annotation for cert-manager
**And** cert-manager provisions a certificate for hello.home.jetzinger.com

**Given** the IngressRoute and certificate are ready
**When** I access https://hello.home.jetzinger.com in a browser
**Then** the page loads with valid HTTPS (green padlock)
**And** certificate shows issued by Let's Encrypt
**And** no certificate warnings appear

**Given** HTTPS is working
**When** I access http://hello.home.jetzinger.com (plain HTTP)
**Then** the request redirects to HTTPS automatically
**And** the final response is served over TLS 1.2+ (NFR7)

---

## Epic 4: Observability Stack

Tom can monitor the cluster, view dashboards, and receive P1 alerts on his phone.

---

### Story 4.1: Deploy kube-prometheus-stack

As a **cluster operator**,
I want **to deploy the complete Prometheus monitoring stack**,
So that **I have metrics collection, storage, and visualization ready**.

**Acceptance Criteria:**

**Given** cluster has NFS storage and ingress configured
**When** I create the `monitoring` namespace
**Then** the namespace is created with appropriate labels
**And** this validates FR11 (assign workloads to specific namespaces)

**Given** the monitoring namespace exists
**When** I deploy kube-prometheus-stack via Helm with `values-homelab.yaml`
**Then** the following pods start in the monitoring namespace:
- prometheus-server
- grafana
- alertmanager
- node-exporter (DaemonSet on all nodes)
- kube-state-metrics
**And** all pods reach Running status within 5 minutes

**Given** the stack is deployed
**When** I check node-exporter pods
**Then** one pod runs on each node (master, worker-01, worker-02)
**And** this validates FR26 (metrics from all nodes)

**Given** kube-state-metrics is running
**When** I query Prometheus for `kube_pod_info`
**Then** metrics for all cluster pods are available
**And** this validates FR27 (K8s object metrics)

**Given** all components are running
**When** I verify this is a containerized application deployment
**Then** this validates FR7 (deploy containerized applications)

---

### Story 4.2: Configure Grafana Dashboards and Ingress

As a **cluster operator**,
I want **to access Grafana dashboards via HTTPS**,
So that **I can visualize cluster metrics from any device**.

**Acceptance Criteria:**

**Given** kube-prometheus-stack is deployed with Grafana
**When** I create an IngressRoute for grafana.home.jetzinger.com with TLS
**Then** cert-manager provisions a certificate
**And** Grafana is accessible via HTTPS

**Given** Grafana is accessible
**When** I log in with the default admin credentials
**Then** the Grafana home page loads within 5 seconds (NFR14)
**And** I can change the admin password

**Given** I'm logged into Grafana
**When** I navigate to the Dashboards section
**Then** pre-built Kubernetes dashboards are available:
- Kubernetes / Compute Resources / Cluster
- Kubernetes / Compute Resources / Namespace
- Node Exporter / Nodes
**And** dashboards show real cluster data

**Given** dashboards are working
**When** I add Prometheus as a data source (if not auto-configured)
**Then** Prometheus data source shows "Data source is working"
**And** I can query metrics via Explore view
**And** this validates FR24 (view cluster metrics in Grafana)

---

### Story 4.3: Verify Prometheus Metrics and Queries

As a **cluster operator**,
I want **to query Prometheus for historical metrics**,
So that **I can analyze trends and troubleshoot issues**.

**Acceptance Criteria:**

**Given** Prometheus is running and scraping targets
**When** I create an IngressRoute for prometheus.home.jetzinger.com with TLS
**Then** Prometheus UI is accessible via HTTPS

**Given** Prometheus UI is accessible
**When** I navigate to Status -> Targets
**Then** all scrape targets show "UP" status:
- kubernetes-nodes
- kubernetes-pods
- node-exporter
- kube-state-metrics
**And** this validates NFR18 (all components emit Prometheus metrics)

**Given** targets are healthy
**When** I query `node_memory_MemAvailable_bytes` in the query interface
**Then** results show memory data for all 3 nodes
**And** data points span the retention period

**Given** historical data is available
**When** I query `rate(container_cpu_usage_seconds_total[5m])`
**Then** CPU usage rate data is returned
**And** I can view data from the past hour
**And** this validates FR25 (query Prometheus for historical metrics)

---

### Story 4.4: Configure Alertmanager with Alert Rules

As a **cluster operator**,
I want **to configure alert rules for critical cluster conditions**,
So that **I'm notified when issues require attention**.

**Acceptance Criteria:**

**Given** kube-prometheus-stack is deployed with Alertmanager
**When** I create an IngressRoute for alertmanager.home.jetzinger.com with TLS
**Then** Alertmanager UI is accessible via HTTPS

**Given** Alertmanager UI is accessible
**When** I view the Alerts page
**Then** I can see configured alert rules and their status

**Given** kube-prometheus-stack includes default rules
**When** I review PrometheusRule resources
**Then** rules exist for:
- P1: NodeDown, TargetDown
- P2: PodCrashLoopBackOff, HighMemoryPressure
- P3: CertificateExpirySoon, DiskSpaceWarning

**Given** alert rules are configured
**When** I add custom rules in `monitoring/prometheus/custom-rules.yaml` for:
- PostgreSQL unhealthy (P1)
- NFS unreachable (P1)
**Then** the custom PrometheusRule is applied
**And** rules appear in Prometheus UI under Alerts

**Given** alert rules are active
**When** I simulate an alert condition (e.g., scale down a deployment to cause missing target)
**Then** alert fires within 1 minute (NFR5)
**And** alert appears in Alertmanager UI
**And** this validates FR28 (system sends alerts when thresholds exceeded)

**Given** alerts are firing
**When** I view Alertmanager UI
**Then** I can see alert history, active alerts, and silenced alerts
**And** this validates FR30 (view alert history and status)

---

### Story 4.5: Setup Mobile Notifications for P1 Alerts

As a **cluster operator**,
I want **to receive mobile notifications for P1 alerts**,
So that **I'm immediately aware of critical issues even when away from my desk**.

**Acceptance Criteria:**

**Given** Alertmanager is running with alert rules
**When** I configure Alertmanager with a notification receiver (Pushover, Slack, or ntfy)
**Then** the receiver configuration is valid
**And** Alertmanager shows no configuration errors

**Given** notification receiver is configured
**When** I create a route that sends P1 (critical) alerts to the mobile receiver
**Then** the route is applied via Alertmanager ConfigMap or Secret
**And** the routing tree shows P1 alerts going to mobile

**Given** routing is configured
**When** I trigger a test P1 alert (e.g., manually fire NodeDown)
**Then** I receive a notification on my mobile device within 2 minutes
**And** the notification includes alert name, severity, and cluster context

**Given** mobile notifications are working
**When** the test alert resolves
**Then** I receive a resolution notification
**And** this validates FR29 (receive mobile notifications for P1 alerts)

**Given** notification flow is validated
**When** I document the setup in `docs/runbooks/alertmanager-setup.md`
**Then** the runbook includes receiver configuration and testing steps

---

### Story 4.6: Deploy Loki for Log Aggregation

As a **cluster operator**,
I want **to aggregate and query logs from all pods**,
So that **I can troubleshoot issues using centralized logging**.

**Acceptance Criteria:**

**Given** kube-prometheus-stack is deployed
**When** I deploy Loki via Helm with `values-homelab.yaml` to the monitoring namespace
**Then** Loki and Promtail pods start successfully
**And** Promtail runs as DaemonSet on all nodes

**Given** Loki is running
**When** I configure Loki as a data source in Grafana
**Then** the data source shows "Data source is working"
**And** LogQL queries return results

**Given** Loki is receiving logs
**When** I query `{namespace="monitoring"}` in Grafana Explore
**Then** logs from monitoring namespace pods are returned
**And** logs include timestamps, labels, and log content

**Given** log aggregation is working
**When** I configure Loki retention for 7 days
**Then** logs older than 7 days are automatically pruned
**And** this satisfies NFR19 (7-day log retention)

**Given** logging is operational
**When** I use Loki to troubleshoot a pod issue
**Then** I can filter logs by namespace, pod, container
**And** I can search for specific error messages

---

## Epic 5: PostgreSQL Database Service

Tom has a production-grade PostgreSQL database with backup and restore capability.

---

### Story 5.1: Deploy PostgreSQL via Bitnami Helm Chart

As a **cluster operator**,
I want **to deploy PostgreSQL using the Bitnami Helm chart**,
So that **I have a production-ready database with sensible defaults**.

**Acceptance Criteria:**

**Given** cluster has NFS storage provisioner and monitoring configured
**When** I create the `data` namespace
**Then** the namespace is created with appropriate labels

**Given** the data namespace exists
**When** I deploy Bitnami PostgreSQL via Helm with `values-homelab.yaml`
**Then** the PostgreSQL StatefulSet is created
**And** the postgres-0 pod starts successfully
**And** this validates FR8 (deploy applications using Helm charts)

**Given** PostgreSQL pod is running
**When** I check the pod details with `kubectl describe pod postgres-0 -n data`
**Then** the pod shows as a StatefulSet member
**And** this validates FR31 (deploy PostgreSQL as StatefulSet)

**Given** PostgreSQL is deployed
**When** I check the Service created
**Then** a ClusterIP service `postgres` exists in the data namespace
**And** port 5432 is exposed

**Given** PostgreSQL is running
**When** I connect with `kubectl exec -it postgres-0 -n data -- psql -U postgres`
**Then** the psql prompt appears
**And** I can run `\l` to list databases

---

### Story 5.2: Configure NFS Persistence for PostgreSQL

As a **cluster operator**,
I want **PostgreSQL data to persist on NFS storage**,
So that **data survives pod restarts and node failures**.

**Acceptance Criteria:**

**Given** PostgreSQL Helm chart is configured
**When** I set `primary.persistence.storageClass: nfs-client` in values-homelab.yaml
**Then** the chart requests storage from the NFS provisioner

**Given** PostgreSQL is deployed with NFS persistence
**When** I check PVCs with `kubectl get pvc -n data`
**Then** a PVC for PostgreSQL data exists and shows Bound status
**And** the PVC uses the nfs-client StorageClass

**Given** PVC is bound
**When** I check the Synology NFS share
**Then** a directory exists for the PostgreSQL PVC
**And** PostgreSQL data files are visible
**And** this validates FR32 (PostgreSQL persists data to NFS)

**Given** data is on NFS
**When** I delete the PostgreSQL pod with `kubectl delete pod postgres-0 -n data`
**Then** the StatefulSet recreates the pod
**And** the new pod mounts the same PVC
**And** all previously created databases and data are intact

**Given** persistence is validated
**When** I simulate a worker node failure (drain the node running postgres)
**Then** PostgreSQL pod reschedules to another node
**And** data remains accessible via NFS

---

### Story 5.3: Setup PostgreSQL Backup with pg_dump

As a **cluster operator**,
I want **to backup PostgreSQL databases to NFS automatically**,
So that **I can recover from data corruption or accidental deletion**.

**Acceptance Criteria:**

**Given** PostgreSQL is running with data
**When** I create a test database and table with sample data
**Then** the data is queryable via psql

**Given** test data exists
**When** I create a CronJob that runs pg_dump daily to an NFS-backed PVC
**Then** the CronJob is created in the data namespace
**And** the CronJob manifest is saved at `applications/postgres/backup-cronjob.yaml`

**Given** the backup CronJob exists
**When** I trigger a manual run with `kubectl create job --from=cronjob/postgres-backup manual-backup -n data`
**Then** the backup job runs successfully
**And** a .sql.gz file is created in the backup PVC

**Given** backup file exists
**When** I verify the backup file on Synology NFS share
**Then** the file contains valid SQL dump
**And** file size is reasonable for the data volume
**And** this validates FR33 (backup PostgreSQL to NFS)

**Given** backups are working
**When** I check backup retention
**Then** the script retains the last 7 daily backups
**And** older backups are automatically deleted

---

### Story 5.4: Validate PostgreSQL Restore Procedure

As a **cluster operator**,
I want **to restore PostgreSQL from a backup**,
So that **I can recover from disasters with documented procedures**.

**Acceptance Criteria:**

**Given** a valid pg_dump backup exists on NFS
**When** I document the restore procedure in `docs/runbooks/postgres-restore.md`
**Then** the runbook includes step-by-step restore instructions

**Given** runbook is documented
**When** I intentionally drop the test database
**Then** the database is deleted and data is lost

**Given** data loss has occurred
**When** I follow the restore runbook to restore from backup
**Then** I can copy the backup file into the postgres pod
**And** I can run `psql -U postgres < backup.sql` to restore

**Given** restore command completes
**When** I verify the restored data
**Then** the test database exists again
**And** all rows in the test table are restored
**And** this validates FR34 (restore PostgreSQL from backup)

**Given** restore is validated
**When** I measure restore time for the test database
**Then** restore time is documented in the runbook
**And** the procedure works within acceptable time bounds

---

### Story 5.5: Test Application Connectivity to PostgreSQL

As a **cluster operator**,
I want **applications to connect to PostgreSQL within the cluster**,
So that **workloads can use the database as their data store**.

**Acceptance Criteria:**

**Given** PostgreSQL is running in the data namespace
**When** I deploy a test pod in the apps namespace with psql client
**Then** the pod starts successfully

**Given** the test pod is running
**When** I exec into the pod and connect to `postgres.data.svc.cluster.local:5432`
**Then** the connection succeeds
**And** I can authenticate with PostgreSQL credentials

**Given** connectivity works
**When** I create a database and user for an application
**Then** the application-specific credentials work
**And** the application can perform CRUD operations

**Given** application connectivity is validated
**When** I document connection strings in `docs/runbooks/postgres-connectivity.md`
**Then** the runbook includes:
- Internal DNS: `postgres.data.svc.cluster.local`
- Port: 5432
- How to retrieve credentials from Secret
**And** this validates FR35 (applications can connect to PostgreSQL)

**Given** documentation is complete
**When** future applications need PostgreSQL
**Then** they can follow the documented pattern

---

## Epic 6: AI Inference Platform

Tom can run LLM inference (Ollama) and workflow automation (n8n) on the cluster.

---

### Story 6.1: Deploy Ollama for LLM Inference

As a **cluster operator**,
I want **to deploy Ollama for running LLM inference**,
So that **I can serve AI models from my home cluster**.

**Acceptance Criteria:**

**Given** cluster has NFS storage and ingress configured
**When** I create the `ml` namespace
**Then** the namespace is created with appropriate labels

**Given** the ml namespace exists
**When** I deploy Ollama via Helm with `values-homelab.yaml`
**Then** the Ollama deployment is created in the ml namespace
**And** the Ollama pod starts successfully

**Given** Ollama pod is running
**When** I configure an NFS-backed PVC for model storage
**Then** the PVC is bound to Ollama at `/root/.ollama`
**And** downloaded models persist across pod restarts

**Given** Ollama is deployed with persistent storage
**When** I create an IngressRoute for ollama.home.jetzinger.com with TLS
**Then** Ollama API is accessible via HTTPS
**And** this validates FR36 (deploy Ollama for LLM inference)

**Given** Ollama is accessible
**When** I exec into the pod and run `ollama pull llama3.2:1b`
**Then** the model downloads and is stored on NFS
**And** subsequent pod restarts don't require re-downloading

---

### Story 6.2: Test Ollama API and Model Inference

As a **cluster operator**,
I want **to query the Ollama API for completions**,
So that **applications can leverage LLM capabilities**.

**Acceptance Criteria:**

**Given** Ollama is running with a model loaded
**When** I send a POST request to `https://ollama.home.jetzinger.com/api/generate`
**Then** the API responds with a 200 status

**Given** the API is responding
**When** I send a prompt like `{"model": "llama3.2:1b", "prompt": "Hello, how are you?"}`
**Then** Ollama returns a generated response
**And** response time is under 30 seconds for typical prompts (NFR13)

**Given** API inference works
**When** I query the `/api/tags` endpoint
**Then** it returns the list of available models
**And** the model I pulled is in the list

**Given** external access works
**When** I test the API from a Tailscale-connected device outside the home network
**Then** the API is accessible and returns valid responses
**And** this validates FR37 (applications can query Ollama API)

**Given** inference is validated
**When** I create a simple test script that queries Ollama
**Then** the script can be used for health checks
**And** the script is saved at `scripts/ollama-health.sh`

---

### Story 6.3: Deploy n8n for Workflow Automation

As a **cluster operator**,
I want **to deploy n8n for workflow automation**,
So that **I can create automated workflows that leverage cluster services**.

**Acceptance Criteria:**

**Given** cluster has storage, ingress, and database configured
**When** I deploy n8n via Helm with `values-homelab.yaml` to the `apps` namespace
**Then** the n8n deployment is created
**And** the n8n pod starts successfully

**Given** n8n requires persistent storage
**When** I configure an NFS-backed PVC for n8n data
**Then** the PVC is bound and mounted
**And** workflow data persists across restarts

**Given** n8n is running
**When** I create an IngressRoute for n8n.home.jetzinger.com with TLS
**Then** n8n UI is accessible via HTTPS
**And** I can log in to the n8n interface

**Given** n8n UI is accessible
**When** I create a simple test workflow that calls the Ollama API
**Then** the workflow executes successfully
**And** Ollama response is captured in workflow output
**And** this validates FR40 (deploy n8n for workflow automation)

**Given** n8n is operational
**When** I document the setup in `docs/runbooks/n8n-setup.md`
**Then** the runbook includes deployment details and initial configuration

---

### Story 6.4: Validate Scaling and Log Access

As a **cluster operator**,
I want **to scale deployments and view pod logs**,
So that **I can manage workload capacity and troubleshoot issues**.

**Acceptance Criteria:**

**Given** Ollama is deployed as a Deployment (not StatefulSet)
**When** I run `kubectl scale deployment ollama -n ml --replicas=2`
**Then** a second Ollama pod starts
**And** both pods reach Running state
**And** this validates FR12 (scale deployments up or down)

**Given** multiple Ollama pods are running
**When** I scale back down with `kubectl scale deployment ollama -n ml --replicas=1`
**Then** one pod terminates gracefully
**And** the remaining pod continues serving requests

**Given** pods are running
**When** I run `kubectl logs ollama-xxx -n ml`
**Then** pod logs are displayed showing Ollama activity
**And** I can see model loading and inference requests

**Given** logs are accessible
**When** I run `kubectl logs ollama-xxx -n ml --follow`
**Then** logs stream in real-time
**And** new inference requests appear as they happen

**Given** events are tracked
**When** I run `kubectl get events -n ml --sort-by=.lastTimestamp`
**Then** I can see recent events for the namespace
**And** pod scheduling, scaling, and health events are visible
**And** this validates FR13 (view pod logs and events)

---

## Epic 7: Development Proxy

Tom can access local development servers through cluster ingress.

---

### Story 7.1: Deploy Nginx Reverse Proxy

As a **cluster operator**,
I want **to deploy Nginx as a reverse proxy to local development servers**,
So that **I can access my dev machines through the cluster**.

**Acceptance Criteria:**

**Given** cluster has ingress and TLS configured
**When** I create the `dev` namespace
**Then** the namespace is created with appropriate labels

**Given** the dev namespace exists
**When** I create a ConfigMap with initial proxy configuration
**Then** the ConfigMap contains nginx.conf with upstream definitions
**And** the ConfigMap is saved at `applications/nginx/configmap.yaml`

**Given** the ConfigMap exists
**When** I deploy Nginx with the ConfigMap mounted
**Then** the Nginx deployment is created in the dev namespace
**And** the Nginx pod starts successfully
**And** the deployment manifest is saved at `applications/nginx/deployment.yaml`

**Given** Nginx pod is running
**When** I check the nginx configuration inside the pod
**Then** the proxy configuration from ConfigMap is loaded
**And** this validates FR41 (configure Nginx to proxy to local dev servers)

**Given** Nginx is deployed
**When** I create a Service of type ClusterIP for Nginx
**Then** the Service exposes port 80
**And** the Service is accessible within the cluster

---

### Story 7.2: Configure Ingress for Dev Proxy Access

As a **developer**,
I want **to access my local dev servers via cluster ingress URLs**,
So that **I can test services with real HTTPS and domain names**.

**Acceptance Criteria:**

**Given** Nginx proxy is running in the dev namespace
**When** I create an IngressRoute for dev.home.jetzinger.com with TLS
**Then** cert-manager provisions a certificate
**And** the ingress is saved at `applications/nginx/ingress.yaml`

**Given** ingress is configured
**When** I configure Nginx to proxy `/app1` to a local dev server (e.g., 192.168.2.50:3000)
**Then** the upstream is defined in the ConfigMap
**And** location block routes `/app1` to the upstream

**Given** proxy route is configured
**When** I access https://dev.home.jetzinger.com/app1 from any device
**Then** the request is proxied to the local dev server
**And** the response is returned through the cluster
**And** this validates FR42 (access local dev servers via cluster ingress)

**Given** basic proxying works
**When** I add additional proxy targets (e.g., `/app2` -> 192.168.2.51:8080)
**Then** multiple dev servers are accessible through the same ingress
**And** each path routes to the correct backend

**Given** proxy is working
**When** I test from a Tailscale-connected device outside home network
**Then** dev servers are accessible remotely via the cluster proxy
**And** HTTPS is enforced on all requests

---

### Story 7.3: Enable Hot-Reload Configuration

As a **cluster operator**,
I want **to add or remove proxy targets without restarting the cluster or pods**,
So that **I can quickly update dev proxy routing**.

**Acceptance Criteria:**

**Given** Nginx is deployed with ConfigMap-based configuration
**When** I update the ConfigMap with a new proxy target
**Then** the ConfigMap is updated in the cluster

**Given** ConfigMap is updated
**When** I send a reload signal to Nginx (via nginx -s reload or pod exec)
**Then** Nginx reloads its configuration without restart
**And** existing connections are not interrupted

**Given** manual reload works
**When** I configure Nginx to watch for config changes (inotify or sidecar)
**Then** configuration changes are detected automatically
**And** Nginx reloads within 30 seconds of ConfigMap update
**And** this validates FR43 (add/remove proxy targets without cluster restart)

**Given** hot-reload is working
**When** I remove a proxy target from the ConfigMap
**Then** the route stops working after reload
**And** 404 is returned for the removed path

**Given** configuration is dynamic
**When** I document the process in `docs/runbooks/dev-proxy.md`
**Then** the runbook includes:
- How to add a new proxy target
- How to trigger reload
- How to verify routing
**And** examples are provided for common scenarios

---

## Epic 8: Cluster Operations & Maintenance

Tom can upgrade K3s, backup/restore the cluster, and maintain long-term operations.

---

### Story 8.1: Configure K3s Upgrade Procedure

As a **cluster operator**,
I want **to upgrade K3s version on nodes safely**,
So that **I can apply security patches and new features without downtime**.

**Acceptance Criteria:**

**Given** K3s cluster is running a specific version
**When** I check the current version with `kubectl version`
**Then** the server and client versions are displayed
**And** I can identify if an upgrade is available

**Given** an upgrade is planned
**When** I document the upgrade procedure in `docs/runbooks/k3s-upgrade.md`
**Then** the runbook includes:
- Pre-upgrade checklist (backup, health check)
- Master node upgrade steps
- Worker node upgrade steps (one at a time)
- Rollback procedure

**Given** the runbook is documented
**When** I upgrade the master node first using the K3s install script with `INSTALL_K3S_VERSION`
**Then** the master node restarts with the new version
**And** `kubectl get nodes` shows the master with updated version
**And** control plane recovers within 5 minutes (NFR2)

**Given** master is upgraded
**When** I upgrade worker nodes one at a time (drain -> upgrade -> uncordon)
**Then** pods reschedule during drain
**And** each worker rejoins with the new version
**And** no data loss occurs (NFR20)
**And** this validates FR44 (upgrade K3s version on nodes)

**Given** all nodes are upgraded
**When** I verify cluster health
**Then** all nodes show Ready with matching versions
**And** all pods are Running

---

### Story 8.2: Setup Cluster State Backup

As a **cluster operator**,
I want **to backup cluster state regularly**,
So that **I can recover from control plane failures**.

**Acceptance Criteria:**

**Given** K3s is running with etcd as the datastore
**When** I verify K3s snapshot configuration
**Then** automatic snapshots are enabled (K3s default)
**And** snapshots are stored at `/var/lib/rancher/k3s/server/db/snapshots`

**Given** automatic snapshots are running
**When** I check snapshot files on the master node
**Then** multiple timestamped snapshot files exist
**And** snapshots are taken every 12 hours by default

**Given** default snapshots work
**When** I configure K3s to snapshot to NFS for off-node storage
**Then** the `--etcd-snapshot-dir` points to NFS mount
**And** snapshots are accessible even if master fails

**Given** NFS backup is configured
**When** I create a manual snapshot with `k3s etcd-snapshot save`
**Then** a new snapshot file is created
**And** the snapshot is verified as valid
**And** this validates FR45 (backup cluster state)

**Given** backup is working
**When** I document the backup configuration in `docs/runbooks/cluster-backup.md`
**Then** the runbook includes snapshot location, manual snapshot command, and verification steps

---

### Story 8.3: Validate Cluster Restore Procedure

As a **cluster operator**,
I want **to restore the cluster from a backup**,
So that **I can recover from catastrophic control plane failures**.

**Acceptance Criteria:**

**Given** etcd snapshots exist on NFS
**When** I document the restore procedure in `docs/runbooks/cluster-restore.md`
**Then** the runbook includes:
- When to use restore (vs rebuild)
- Snapshot selection criteria
- Step-by-step restore commands
- Post-restore verification

**Given** restore procedure is documented
**When** I simulate control plane failure (stop K3s, delete etcd data)
**Then** the cluster becomes unavailable
**And** kubectl commands fail

**Given** cluster is down
**When** I restore from snapshot using `k3s server --cluster-reset --cluster-reset-restore-path=<snapshot>`
**Then** K3s restarts with the restored state
**And** the restore completes within 30 minutes (NFR6)

**Given** restore completes
**When** I verify cluster state
**Then** `kubectl get nodes` shows all nodes
**And** `kubectl get pods --all-namespaces` shows workloads
**And** application data is intact
**And** this validates FR46 (restore cluster from backup)

**Given** restore is validated
**When** I rejoin worker nodes if needed
**Then** workers reconnect to the restored master
**And** full cluster operation resumes

---

### Story 8.4: Configure Automatic OS Security Updates

As a **cluster operator**,
I want **node operating systems to apply security updates automatically**,
So that **vulnerabilities are patched without manual intervention**.

**Acceptance Criteria:**

**Given** Ubuntu Server is running on all nodes
**When** I install and configure unattended-upgrades package
**Then** the package is installed on master and all workers
**And** security updates are enabled in configuration

**Given** unattended-upgrades is installed
**When** I configure `/etc/apt/apt.conf.d/50unattended-upgrades`
**Then** only security updates are applied (not all updates)
**And** automatic reboot is disabled (manual control)
**And** email notifications are configured (optional)

**Given** configuration is applied
**When** I verify with `unattended-upgrade --dry-run`
**Then** pending security updates are listed
**And** no non-security updates are included

**Given** unattended-upgrades is working
**When** a security update is released
**Then** it is applied within 7 days (NFR11)
**And** this validates FR47 (system applies security updates automatically)

**Given** updates are automatic
**When** I need to track what was updated
**Then** logs are available at `/var/log/unattended-upgrades/`
**And** I can view upgrade history
**And** this partially validates FR48 (view upgrade history)

---

### Story 8.5: Document Rollback and History Procedures

As a **cluster operator**,
I want **to view upgrade history and rollback if needed**,
So that **I can recover from problematic upgrades**.

**Acceptance Criteria:**

**Given** K3s has been upgraded
**When** I check K3s version history
**Then** I can see current version with `k3s --version`
**And** previous versions are noted in upgrade runbook

**Given** upgrade history is tracked
**When** I document rollback procedures in `docs/runbooks/k3s-rollback.md`
**Then** the runbook includes:
- When to rollback vs restore
- Rollback using previous K3s binary
- Rollback using etcd snapshot
- Post-rollback verification

**Given** a problematic upgrade occurs
**When** I follow the rollback procedure
**Then** I can reinstall the previous K3s version
**And** cluster returns to previous state
**And** this validates FR48 (view upgrade history and rollback if needed)

**Given** OS updates need rollback
**When** I document package rollback in runbook
**Then** apt history commands are documented
**And** package downgrade procedure is included

**Given** all runbooks are complete
**When** I review the docs/runbooks/ directory
**Then** runbooks exist for all P1 alert scenarios
**And** this validates NFR22 (runbooks for P1 scenarios)

---

## Epic 9: Portfolio & Public Showcase

Tom has a polished public portfolio that demonstrates capability to hiring managers and recruiters.

---

### Story 9.1: Structure Public GitHub Repository

As a **portfolio audience member**,
I want **to view a well-organized public GitHub repository**,
So that **I can understand the project structure and navigate easily**.

**Acceptance Criteria:**

**Given** the home-lab project exists locally
**When** I structure the repository following the architecture
**Then** the following directories exist:
- `infrastructure/` (k3s, nfs, metallb, cert-manager)
- `applications/` (postgres, ollama, nginx, n8n)
- `monitoring/` (prometheus, loki)
- `docs/` (adrs, runbooks, diagrams)
- `scripts/`

**Given** the structure is created
**When** I create a comprehensive README.md
**Then** the README includes:
- Project overview and purpose
- Architecture diagram or link
- Quick start guide
- Directory structure explanation
- Link to blog posts
**And** setup can be understood in <2 hours (NFR25)

**Given** README is complete
**When** I add a .gitignore file
**Then** sensitive files are excluded (kubeconfig, secrets, .env)
**And** generated files are excluded

**Given** repository is structured
**When** I push to GitHub and make the repository public
**Then** the repository is accessible at github.com/{username}/home-lab
**And** this validates FR49 (audience can view public GitHub repository)

**Given** repository is public
**When** a hiring manager visits the repository
**Then** they can navigate the structure intuitively (NFR27)
**And** the professional README makes a strong first impression

---

### Story 9.2: Create Architecture Decision Records

As a **portfolio audience member**,
I want **to read architecture decision records**,
So that **I can understand the reasoning behind technical choices**.

**Acceptance Criteria:**

**Given** docs/adrs/ directory exists
**When** I create ADRs for key decisions made during the project
**Then** ADRs are created following pattern `ADR-{NNN}-{short-title}.md`
**And** this validates FR53 (document decisions as ADRs)

**Given** ADR template is established
**When** I write ADR-001-k3s-over-k8s.md
**Then** the ADR includes:
- Title and date
- Status (accepted)
- Context (why this decision was needed)
- Decision (what was chosen)
- Consequences (trade-offs and implications)

**Given** first ADR is complete
**When** I create additional ADRs for:
- ADR-002-nfs-over-longhorn.md
- ADR-003-traefik-ingress.md
- ADR-004-kube-prometheus-stack.md
- ADR-005-manual-helm-over-gitops.md
**Then** all major architectural decisions are documented
**And** this validates NFR24 (all decisions documented as ADRs)

**Given** ADRs are written
**When** a technical interviewer reads them
**Then** they can see "I chose X over Y because..." reasoning
**And** trade-off analysis demonstrates engineering judgment
**And** this validates FR50 (audience can read ADRs)

**Given** ADRs are complete
**When** I add an index to docs/adrs/README.md
**Then** all ADRs are listed with brief descriptions
**And** the index links to each ADR

---

### Story 9.3: Capture and Document Grafana Screenshots

As a **portfolio audience member**,
I want **to view Grafana dashboard screenshots**,
So that **I can see the running infrastructure without access to the cluster**.

**Acceptance Criteria:**

**Given** Grafana is running with dashboards populated
**When** I capture screenshots of key dashboards:
- Kubernetes Cluster Overview
- Node Resource Usage
- Pod Status Dashboard
- Custom home-lab dashboard
**Then** screenshots are saved as PNG files

**Given** screenshots are captured
**When** I save them to `docs/diagrams/screenshots/`
**Then** files are named descriptively (e.g., `grafana-cluster-overview.png`)
**And** file sizes are optimized for web viewing

**Given** screenshots are saved
**When** I add them to the README or a dedicated docs page
**Then** images are embedded or linked
**And** each screenshot has a caption explaining what it shows
**And** this validates FR51 (audience can view Grafana dashboard screenshots)

**Given** screenshots show real data
**When** a hiring manager views them
**Then** they see proof of running infrastructure
**And** they can see metrics from actual workloads

**Given** visual documentation is complete
**When** I create an architecture diagram using Excalidraw or similar
**Then** the diagram shows cluster topology, network flow, and components
**And** the diagram is saved to `docs/diagrams/architecture-overview.png`

---

### Story 9.4: Write and Publish First Technical Blog Post

As a **portfolio audience member**,
I want **to read technical blog posts about the build**,
So that **I can understand the journey and learn from the experience**.

**Acceptance Criteria:**

**Given** the cluster is operational with workloads running
**When** I outline a blog post about the project
**Then** the outline covers:
- Introduction (career context, why this project)
- Technical approach (K3s, home lab setup)
- Key learnings (what worked, what didn't)
- Connection to automotive experience
- Call to action (links to repo, next steps)

**Given** outline is complete
**When** I write the full blog post (1500-2500 words)
**Then** the post is technically accurate
**And** the narrative connects automotive to Kubernetes
**And** AI-assisted methodology is mentioned as differentiator

**Given** blog post is written
**When** I publish to dev.to (or similar platform)
**Then** the post is publicly accessible
**And** the post includes link to GitHub repository
**And** this validates FR54 (publish blog posts to dev.to or similar)

**Given** post is published
**When** I share on LinkedIn
**Then** the post reaches professional network
**And** this validates FR52 (audience can read technical blog posts)

**Given** first post is complete
**When** I link the post from the GitHub README
**Then** visitors can find the blog content
**And** the portfolio has complete narrative arc

---

### Story 9.5: Document All Deployed Services

As a **portfolio audience member**,
I want **to understand the purpose and configuration of each service**,
So that **I can evaluate the depth of implementation**.

**Acceptance Criteria:**

**Given** all services are deployed
**When** I create documentation for each major component
**Then** each component has a README or doc section explaining:
- What it does
- Why it was chosen
- Key configuration decisions
- How to access/use it

**Given** component documentation exists
**When** I organize it under appropriate directories
**Then** `infrastructure/*/README.md` documents infra components
**And** `applications/*/README.md` documents applications
**And** `monitoring/*/README.md` documents observability stack
**And** this validates NFR26 (all services documented)

**Given** documentation is complete
**When** I create a portfolio summary page at `docs/PORTFOLIO.md`
**Then** the page provides:
- High-level project summary
- Skills demonstrated
- Technologies used
- Links to key sections
**And** this serves as a "resume companion" document

**Given** all documentation is in place
**When** a hiring manager spends 10 minutes reviewing
**Then** they can understand scope, depth, and quality
**And** they have enough context to prepare interview questions
**And** this validates NFR27 (navigable by external reviewer)

---

## Phase 2 Epic Details

### Epic 10: Document Management System (Paperless-ngx Ecosystem)

**User Outcome:** Tom has a comprehensive self-hosted document management system with scanning, tagging, searching, AI-powered classification, Office document processing, PDF editing, and automatic email import.

**FRs Covered:** FR55-58, FR64-66, FR75-93
**NFRs Covered:** NFR28-30, NFR39-49

---

#### Story 10.1: Deploy Paperless-ngx with Redis Backend

**As a** platform engineer
**I want** Paperless-ngx deployed with Redis for task queuing
**So that** the document management system can process uploads and OCR tasks asynchronously

**Acceptance Criteria:**

**Given** cluster has `docs` namespace
**When** I deploy Paperless-ngx via gabe565 Helm chart
**Then** the following resources are created:
- Deployment: `paperless-ngx` (1 replica)
- Deployment: `redis` (1 replica for task queue)
- Service: `paperless-ngx` (port 8000)
- Service: `redis` (port 6379)

**Given** Paperless-ngx is deployed
**When** I check Helm values configuration
**Then** the chart uses:
- Image: `ghcr.io/paperless-ngx/paperless-ngx:latest`
- Redis connection: `redis://redis:6379`
- Environment variables set for PAPERLESS_URL, PAPERLESS_SECRET_KEY

**Given** pods are running
**When** I execute `kubectl get pods -n docs`
**Then** both `paperless-ngx-*` and `redis-*` pods show status Running
**And** this validates FR55 (deploy Paperless-ngx with Redis)

**Story Points:** 5

---

#### Story 10.2: Configure PostgreSQL Backend

**As a** platform engineer
**I want** Paperless-ngx to use the existing cluster PostgreSQL database instead of SQLite
**So that** the system can scale to 5,000+ documents with efficient metadata queries

**Acceptance Criteria:**

**Given** cluster PostgreSQL is running in `data` namespace
**When** I configure Paperless-ngx database connection
**Then** Helm values include:
```yaml
env:
  PAPERLESS_DBENGINE: postgresql
  PAPERLESS_DBHOST: postgresql.data.svc.cluster.local
  PAPERLESS_DBNAME: paperless
  PAPERLESS_DBUSER: paperless_user
  PAPERLESS_DBPORT: "5432"
```

**Given** PostgreSQL credentials are configured
**When** I create database and user in PostgreSQL
**Then** database `paperless` exists with user `paperless_user`
**And** credentials are stored in `secrets/paperless-secrets.yaml` (gitignored)
**And** this validates FR66 (PostgreSQL backend for metadata)

**Given** Paperless-ngx is upgraded with PostgreSQL config
**When** I check pod logs
**Then** logs show successful PostgreSQL connection
**And** logs show database migration completion
**And** no SQLite-related errors appear
**And** this validates NFR29 (scales to 5,000+ documents)

**Story Points:** 3

---

#### Story 10.3: Configure OCR with German and English Support

**As a** user
**I want** Paperless-ngx to perform OCR on scanned documents in German and English
**So that** I can search document contents in both languages

**Acceptance Criteria:**

**Given** Paperless-ngx is running
**When** I configure OCR language support
**Then** Helm values include:
```yaml
env:
  PAPERLESS_OCR_LANGUAGE: deu+eng
  PAPERLESS_OCR_MODE: skip
```

**Given** OCR is configured
**When** I upload a test PDF with German text
**Then** Paperless-ngx processes the document
**And** OCR extracts German text searchable in the interface
**And** this validates NFR28 (95%+ OCR accuracy for German and English)

**Given** OCR processing is complete
**When** I search for a German keyword from the document
**Then** search returns results within 3 seconds
**And** this validates NFR30 (search performance target)

**Story Points:** 5

---

#### Story 10.4: Configure NFS Persistent Storage

**As a** platform engineer
**I want** Paperless-ngx to store documents on NFS
**So that** documents persist across pod restarts and benefit from Synology snapshots

**Acceptance Criteria:**

**Given** NFS StorageClass exists (`nfs-client`)
**When** I configure Paperless-ngx PVC via Helm values
**Then** the following PVCs are created:
- `paperless-data` (50GB) - for uploaded documents
- `paperless-media` (20GB) - for thumbnails and exports

**Given** PVCs are bound
**When** I check volume mounts
**Then** Paperless-ngx pod mounts:
- `/usr/src/paperless/data` → `paperless-data` PVC
- `/usr/src/paperless/media` → `paperless-media` PVC

**Given** storage is mounted
**When** I upload a test document
**Then** the document file appears in Synology NFS share under `/volume1/k8s-data/docs-paperless-data-*/`
**And** this validates FR56 (Paperless persists to NFS)

**Given** Synology snapshots are configured
**When** I verify snapshot schedule
**Then** hourly snapshots include Paperless document directories
**And** documents are protected from accidental deletion

**Story Points:** 3

---

#### Story 10.5: Configure Ingress with HTTPS

**As a** user
**I want** to access Paperless-ngx via HTTPS at `paperless.home.jetzinger.com`
**So that** I can securely browse and upload documents from any Tailscale-connected device

**Acceptance Criteria:**

**Given** Traefik and cert-manager are operational
**When** I create IngressRoute for Paperless-ngx
**Then** the manifest defines:
```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: paperless-https
  namespace: docs
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`paperless.home.jetzinger.com`)
      kind: Rule
      services:
        - name: paperless-ngx
          port: 8000
  tls:
    certResolver: letsencrypt
```

**Given** IngressRoute is applied
**When** I access `https://paperless.home.jetzinger.com` from Tailscale device
**Then** the Paperless-ngx login page loads with valid TLS certificate
**And** this validates FR57 (HTTPS access via ingress)

**Given** I log in to Paperless-ngx
**When** I browse the document library
**Then** the interface loads without TLS warnings
**And** I can upload, tag, and search documents
**And** this validates FR58 (upload, tag, search functionality)

**Story Points:** 3

---

#### Story 10.6: Validate Document Management Workflow

**As a** user
**I want** to verify the complete document lifecycle
**So that** I can confidently migrate from manual file storage to Paperless-ngx

**Acceptance Criteria:**

**Given** Paperless-ngx is fully operational
**When** I upload 10 test documents (mix of scanned PDFs and manual uploads)
**Then** all documents appear in the library within 30 seconds
**And** OCR processing completes for scanned documents

**Given** documents are processed
**When** I create tags: "Invoices", "Contracts", "Medical", "Taxes"
**Then** I can assign multiple tags to each document
**And** tags appear in the sidebar for filtering

**Given** documents are tagged
**When** I perform full-text search for specific keywords
**Then** search returns relevant documents within 3 seconds
**And** search highlights matching text in document previews

**Given** the system handles 10 documents
**When** I scale to 100 documents (simulate realistic usage)
**Then** interface remains responsive (<5s page load)
**And** this validates NFR29 (scales to 5,000+ documents)

**Given** I verify backup coverage
**When** I check Synology snapshots
**Then** all uploaded documents are included in hourly snapshots
**And** I can access previous versions via Synology UI

**Story Points:** 5

---

#### Story 10.7: Configure Single-User Mode with NFS Polling

**As a** platform engineer
**I want** Paperless-ngx configured for single-user operation with NFS-compatible polling
**So that** documents dropped into consume folders via NFS mount are automatically imported

**Acceptance Criteria:**

**Given** Paperless-ngx is deployed with NFS storage
**When** I configure single-user and polling settings
**Then** Helm values include:
```yaml
env:
  PAPERLESS_CONSUMER_SUBDIRS_AS_TAGS: "true"
  PAPERLESS_CONSUMER_RECURSIVE: "true"
  PAPERLESS_CONSUMER_DELETE_DUPLICATES: "true"
  PAPERLESS_CONSUMER_POLLING: "10"
  PAPERLESS_CONSUMER_POLLING_DELAY: "5"
  PAPERLESS_CONSUMER_POLLING_RETRY_COUNT: "5"
```
**And** this validates FR75 (single-user folder-based organization)
**And** this validates FR76 (duplicate document detection)
**And** this validates NFR39 (NFS polling mode required)
**And** this validates NFR40 (10-second polling interval)

**Given** consume folder is NFS-mounted on workstation
**When** I verify NFS mount path from `/etc/fstab`
**Then** the consume PVC is accessible at `/mnt/paperless`
**And** scanner/desktop can drop files into this directory
**And** this validates FR77 (NFS mount from workstation)

**Given** NFS polling is configured
**When** I drop a test PDF into the consume folder
**Then** Paperless-ngx detects the file within 10 seconds
**And** document appears in library within 30 seconds of detection
**And** this validates FR78 (auto-import within 30 seconds)

**Implementation Notes:**
- NFS does not support inotify, polling is required
- Polling interval: 10 seconds (PAPERLESS_CONSUMER_POLLING)
- Polling delay: 5 seconds wait after file change before consuming
- Retry count: 5 attempts if file is locked during upload

**Story Points:** 3

---

#### Story 10.8: Implement Security Hardening

**As a** platform engineer
**I want** CSRF and CORS protection enabled for Paperless-ngx
**So that** the web interface is protected against cross-site attacks

**Acceptance Criteria:**

**Given** Paperless-ngx is deployed with ingress
**When** I configure security hardening settings
**Then** Helm values include:
```yaml
env:
  PAPERLESS_CSRF_TRUSTED_ORIGINS: "https://paperless.home.jetzinger.com"
  PAPERLESS_CORS_ALLOWED_HOSTS: "https://paperless.home.jetzinger.com"
  PAPERLESS_COOKIE_PREFIX: "paperless_ngx"
  PAPERLESS_ENABLE_HTTP_REMOTE_USER: "false"
```
**And** this validates FR79 (CSRF protection enabled)
**And** this validates FR80 (CORS restricted to authorized origins)

**Given** security settings are applied
**When** I attempt cross-origin request from unauthorized domain
**Then** request is rejected with CORS error
**And** CSRF token validation is enforced on form submissions

**Story Points:** 2

---

#### Story 10.9: Deploy Office Document Processing (Tika + Gotenberg)

**As a** user
**I want** Paperless-ngx to process Office documents (Word, Excel, PowerPoint)
**So that** I can import business documents directly without manual PDF conversion

**Acceptance Criteria:**

**Given** cluster has `docs` namespace
**When** I deploy Apache Tika and Gotenberg
**Then** the following resources are created:
- Deployment: `tika` (1 replica, image: `apache/tika:latest`)
- Service: `tika` (port 9998)
- Deployment: `gotenberg` (1 replica, image: `gotenberg/gotenberg:8`)
- Service: `gotenberg` (port 3000)

**Given** Tika and Gotenberg are running
**When** I configure Paperless-ngx integration
**Then** Helm values include:
```yaml
env:
  PAPERLESS_TIKA_ENABLED: "true"
  PAPERLESS_TIKA_ENDPOINT: "http://tika:9998"
  PAPERLESS_TIKA_GOTENBERG_ENDPOINT: "http://gotenberg:3000"
```
**And** this validates FR81 (Apache Tika for text extraction)
**And** this validates FR82 (Gotenberg for PDF conversion)

**Given** Office processing is configured
**When** I upload a .docx, .xlsx, or .pptx file
**Then** Paperless-ngx converts the file to PDF via Gotenberg
**And** text is extracted via Tika for full-text search
**And** document appears in library with searchable content
**And** this validates FR83 (direct Office format import)

**Given** OCR workers are configured
**When** I check processing performance
**Then** PAPERLESS_TASK_WORKERS is set to 2
**And** this validates NFR41 (2 parallel OCR workers)

**Implementation Notes:**
- Tika: Text and metadata extraction from Office docs
- Gotenberg: PDF conversion with Chromium engine (Office-to-PDF)
- Gotenberg flags: `--chromium-disable-javascript=true` for security
- Both services are internal, no ingress required

**Story Points:** 5

---

#### Story 10.10: Deploy Stirling-PDF

**As a** user
**I want** Stirling-PDF deployed for PDF manipulation
**So that** I can split, merge, rotate, and compress PDFs via web interface

**Acceptance Criteria:**

**Given** cluster has `docs` namespace
**When** I deploy Stirling-PDF via Helm
**Then** I run:
```bash
helm repo add stirling-pdf https://stirling-tools.github.io/Stirling-PDF-chart
helm install stirling-pdf stirling-pdf/stirling-pdf-chart \
  --namespace docs \
  -f applications/stirling-pdf/values-homelab.yaml
```
**And** Deployment `stirling-pdf` is created with 1 replica
**And** Service `stirling-pdf` is created on port 8080

**Given** Stirling-PDF is deployed
**When** I create Helm values file
**Then** configuration includes:
```yaml
env:
  SECURITY_ENABLELOGIN: "false"
  SYSTEM_DEFAULTLOCALE: "de-DE"
persistence:
  enabled: false  # Stateless operation
```

**Given** Stirling-PDF is running
**When** I create IngressRoute for HTTPS access
**Then** `stirling.home.jetzinger.com` routes to Stirling-PDF service
**And** TLS certificate is provisioned via cert-manager
**And** this validates FR84 (Stirling-PDF deployed)
**And** this validates FR86 (ingress with HTTPS)

**Given** Stirling-PDF is accessible
**When** I use the web interface
**Then** I can split, merge, rotate, and compress PDFs
**And** this validates FR85 (PDF manipulation capabilities)

**Implementation Notes:**
- Official Helm chart: `stirling-pdf/stirling-pdf-chart`
- Stateless operation (no persistent storage needed)
- German locale (de-DE) matches user preference
- No authentication (internal Tailscale network only)

**Story Points:** 3

---

#### Story 10.11: Configure Email Integration

**As a** user
**I want** Paperless-ngx to monitor my email inboxes for document attachments
**So that** invoices and documents sent via email are automatically imported

**Acceptance Criteria:**

**Given** cluster has `docs` namespace
**When** I deploy email bridge container for private email provider
**Then** the following resources are created:
- StatefulSet: `email-bridge` (1 replica)
- Service: `email-bridge` (ports: 143 IMAP, 25 SMTP)
- PVC: for credential storage (1Gi)

**Given** email bridge is running
**When** I configure bridge credentials
**Then** I exec into pod and run bridge CLI
**And** I login with email account
**And** bridge generates IMAP credentials

**Given** email accounts are configured
**When** I set up Paperless-ngx mail fetcher via UI
**Then** Mail Accounts include:
- Private Email: IMAP server via bridge, bridge credentials
- Gmail: IMAP server `imap.gmail.com:993`, App Password authentication
**And** this validates FR90 (monitor private email inbox)
**And** this validates FR91 (monitor Gmail inbox)
**And** this validates FR93 (email bridge container)

**Given** mail rules are configured
**When** I create mail rules for document consumption
**Then** rules filter by subject/sender for invoices, statements, contracts
**And** PDF and Office attachments are extracted and imported
**And** this validates FR92 (auto-import email attachments)

**Given** email integration is active
**When** I receive an email with PDF attachment
**Then** attachment appears in Paperless-ngx within mail check interval
**And** document is tagged based on mail rule configuration

**Implementation Notes:**
- Email Bridge: Required for private email IMAP access
- Gmail: Direct IMAP with App Password (OAuth not supported)
- Mail fetcher runs on configurable schedule (hourly default)
- Credentials stored in Kubernetes secrets (gitignored)

**Story Points:** 5

---

### Epic 11: Dev Containers Platform

**User Outcome:** Tom can provision isolated development containers accessible via custom domains, supporting remote VS Code and Claude Code workflows.

**FRs Covered:** FR59, FR60, FR61, FR62, FR63, FR67, FR68, FR69, FR70
**NFRs Covered:** NFR31, NFR32, NFR33

---

#### Story 11.1: Create Dev Container Base Image

**As a** platform engineer
**I want** a standardized dev container base image with all required tools
**So that** new dev containers can be provisioned consistently

**Acceptance Criteria:**

**Given** I need a base image for dev containers
**When** I create a Dockerfile
**Then** it includes the following components:
```dockerfile
FROM ubuntu:22.04
RUN apt-get update && apt-get install -y \
    openssh-server curl git sudo vim
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs
RUN apt-get install -y python3.11 python3-pip
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && chmod +x kubectl && mv kubectl /usr/local/bin/
RUN curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
RUN npm install -g @anthropic-ai/claude-code
RUN useradd -m -s /bin/bash dev && echo "dev ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
EXPOSE 22
CMD ["/usr/sbin/sshd", "-D"]
```

**Given** Dockerfile is created
**When** I build the image
**Then** the build completes without errors
**And** image is tagged as `dev-container-base:latest`

**Given** image is built
**When** I verify installed tools
**Then** the image includes:
- Node.js 20.x with npm
- Python 3.11 with pip
- kubectl (latest stable)
- helm 3
- Claude Code CLI (`claude-code --version` works)
- git, sudo, vim, SSH server

**Given** image is verified
**When** I push to local registry or rebuild for each deployment
**Then** the image is available for dev container deployments
**And** this validates FR67 (single base image with all tools)

**Story Points:** 5

---

#### Story 11.2: Deploy Dev Containers for Belego and Pilates

**As a** developer
**I want** two dev containers deployed (one for Belego, one for Pilates projects)
**So that** I can develop both projects in isolated environments

**Acceptance Criteria:**

**Given** base image exists
**When** I deploy dev container for Belego
**Then** the following resources are created in `dev` namespace:
- Deployment: `dev-container-belego` (1 replica)
- Service: `dev-container-belego-svc` (port 22 for SSH)
- Resources: 2 CPU cores, 4GB RAM (FR68)

**Given** Belego container is deployed
**When** I deploy dev container for Pilates
**Then** the following resources are created:
- Deployment: `dev-container-pilates` (1 replica)
- Service: `dev-container-pilates-svc` (port 22 for SSH)
- Resources: 2 CPU cores, 4GB RAM

**Given** both containers are running
**When** I execute `kubectl get pods -n dev`
**Then** both `dev-container-belego-*` and `dev-container-pilates-*` show status Running
**And** each pod has SSH server listening on port 22

**Given** I verify resource allocation
**When** I check pod resource requests
**Then** cluster allocates 4 CPU cores and 8GB RAM total
**And** resources are within cluster capacity (k3s-worker nodes have sufficient resources)

**Story Points:** 5

---

#### Story 11.3: Configure Persistent Storage for Workspaces

**As a** developer
**I want** persistent 10GB volumes for each dev container
**So that** my git repos and workspace data survive container restarts

**Acceptance Criteria:**

**Given** NFS StorageClass exists
**When** I configure PVCs for dev containers
**Then** the following PVCs are created:
- `dev-belego-workspace` (10GB, nfs-client StorageClass)
- `dev-pilates-workspace` (10GB, nfs-client StorageClass)

**Given** PVCs are bound
**When** I check volume mounts in deployments
**Then** each dev container mounts:
- `/home/dev/workspace` → respective PVC

**Given** volumes are mounted
**When** I SSH into Belego container and create test files
**Then** files persist in `/home/dev/workspace`
**And** files appear in Synology NFS share under `/volume1/k8s-data/dev-*-workspace-*/`

**Given** container is restarted
**When** I delete the pod and wait for recreation
**Then** new pod mounts the same PVC
**And** test files are still present in `/home/dev/workspace`
**And** this validates NFR32 (workspace data persists across restarts)

**Story Points:** 3

---

#### Story 11.4: Configure Nginx SSH Proxy with Custom Domains

**As a** developer
**I want** SSH access to dev containers via custom domains on different ports
**So that** I can use VS Code Remote SSH with familiar domain names

**Acceptance Criteria:**

**Given** dev containers are running
**When** I deploy Nginx with stream module
**Then** the ConfigMap includes:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
  namespace: dev
data:
  nginx.conf: |
    load_module /usr/lib/nginx/modules/ngx_stream_module.so;
    events {}
    stream {
      upstream dev-belego {
        server dev-container-belego-svc.dev.svc.cluster.local:22;
      }
      upstream dev-pilates {
        server dev-container-pilates-svc.dev.svc.cluster.local:22;
      }
      server {
        listen 2222;
        proxy_pass dev-belego;
      }
      server {
        listen 2223;
        proxy_pass dev-pilates;
      }
    }
```

**Given** Nginx proxy is deployed
**When** I create IngressRoutes for HTTP/HTTPS access
**Then** the following domains are configured:
- `dev.belego.app` → Nginx service (Belego HTTP traffic)
- `dev.app.pilates4.golf` → Nginx service (Pilates HTTP - all 4 subdomains)
- `dev.blog.pilates4.golf` → Nginx service (same backend)
- `dev.join.pilates4.golf` → Nginx service (same backend)
- `dev.www.pilates4.golf` → Nginx service (same backend)

**Given** IngressRoutes use custom domains
**When** I configure NextDNS with wildcard rewrites
**Then** the following DNS entries point to MetalLB IP (192.168.2.100):
- `*.belego.app` → 192.168.2.100
- `*.pilates4.golf` → 192.168.2.100

**Given** DNS is configured
**When** I SSH to `dev.belego.app:2222`
**Then** I connect to Belego dev container
**And** when I SSH to any Pilates domain on port 2223
**Then** I connect to the same Pilates dev container
**And** this validates FR59, FR61 (Nginx proxy routes to dev containers)

**Story Points:** 8

---

#### Story 11.5: Configure NetworkPolicy for Container Isolation

**As a** platform engineer
**I want** dev containers isolated via NetworkPolicy
**So that** containers cannot communicate directly and are only accessible via Nginx proxy

**Acceptance Criteria:**

**Given** dev containers are running
**When** I create NetworkPolicy for `dev` namespace
**Then** the policy defines:
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: dev-container-isolation
  namespace: dev
spec:
  podSelector:
    matchLabels:
      app: dev-container
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: nginx
    ports:
    - protocol: TCP
      port: 22
  egress:
  - to:
    - namespaceSelector: {}
      podSelector:
        matchLabels:
          k8s-app: kube-dns
    ports:
    - protocol: UDP
      port: 53
  - to:
    - namespaceSelector:
        matchLabels:
          name: data
    ports:
    - protocol: TCP
      port: 5432
  - to:
    - namespaceSelector:
        matchLabels:
          name: ml
    ports:
    - protocol: TCP
      port: 11434
```

**Given** NetworkPolicy is applied
**When** I test connectivity from Belego container
**Then** the container can:
- Reach DNS (kube-dns)
- Connect to PostgreSQL in `data` namespace (port 5432)
- Connect to Ollama in `ml` namespace (port 11434)

**Given** NetworkPolicy is enforced
**When** I test blocked connectivity
**Then** the container cannot:
- Connect to other dev containers directly (SSH blocked)
- Reach external internet without explicit egress rule

**Given** isolation is verified
**When** I confirm access via Nginx proxy
**Then** SSH connections work via Nginx stream module on ports 2222/2223
**And** this validates NFR33 (NetworkPolicy isolation)

**Story Points:** 5

---

#### Story 11.6: Validate VS Code Remote SSH Configuration

**As a** developer
**I want** VS Code Remote SSH working with both dev containers
**So that** I can develop remotely with full IDE features

**Acceptance Criteria:**

**Given** dev containers are accessible via SSH
**When** I configure VS Code SSH config
**Then** `~/.ssh/config` includes:
```ssh-config
Host belego-dev
  HostName dev.belego.app
  Port 2222
  User dev
  IdentityFile ~/.ssh/id_rsa

Host pilates-dev
  HostName dev.app.pilates4.golf
  Port 2223
  User dev
  IdentityFile ~/.ssh/id_rsa
```

**Given** SSH config is created
**When** I connect to `belego-dev` via VS Code Remote SSH
**Then** VS Code connects successfully
**And** I can browse `/home/dev/workspace`
**And** this validates FR61 (VS Code connection)

**Given** VS Code is connected
**When** I open a terminal in VS Code
**Then** I can run `claude-code --version`
**And** Claude Code CLI responds with version information
**And** this validates FR62 (Claude Code inside dev containers)

**Given** I clone a git repo in workspace
**When** I restart the container
**Then** the cloned repo persists in `/home/dev/workspace`
**And** this validates FR60, FR63 (git worktree support and local storage)

**Given** both containers are validated
**When** I measure provisioning time
**Then** new dev container ready within 90 seconds (image pull + volume mount)
**And** this validates NFR31 (provisioning performance)

**Story Points:** 5

---

### Epic 12: GPU/ML Inference Platform

**User Outcome:** AI/ML workflows can access GPU-accelerated inference via vLLM and Ollama, with Paperless-AI document classification and graceful fallback to CPU-based Ollama when GPU unavailable or host is using GPU for gaming.

**FRs Covered:** FR38, FR39, FR71-74, FR87-89, FR94, FR100-103
**NFRs Covered:** NFR34-38, NFR42-43, NFR50, NFR55-57

---

#### Story 12.1: Install Ubuntu 22.04 on Intel NUC and Configure eGPU

**As a** platform engineer
**I want** Ubuntu 22.04 installed on the Intel NUC with RTX 3060 eGPU configured
**So that** the hardware is ready to join the K3s cluster with GPU capabilities

**Acceptance Criteria:**

**Given** I have Intel NUC hardware and RTX 3060 eGPU
**When** I install Ubuntu 22.04 LTS
**Then** the OS is installed with:
- Static IP: 192.168.0.25 (Intel NUC local network)
- Hostname: `k3s-gpu-worker`
- SSH access configured with key-based authentication
- System updates applied: `sudo apt update && sudo apt upgrade -y`

**Given** OS is installed
**When** I connect the eGPU via Thunderbolt
**Then** `boltctl list` shows the eGPU enclosure
**And** I authorize the device: `boltctl authorize <device-uuid>`
**And** `lspci | grep NVIDIA` shows RTX 3060

**Given** eGPU is detected
**When** I install NVIDIA drivers
**Then** I run:
```bash
sudo apt install nvidia-driver-535
sudo reboot
```
**And** after reboot, `nvidia-smi` shows RTX 3060 with 12GB VRAM
**And** driver version is 535+ (CUDA 12.2+ compatible)
**And** nvidia-persistenced daemon is enabled: `sudo systemctl enable --now nvidia-persistenced`

**Given** drivers are installed
**When** I configure system hardening
**Then** UFW firewall allows SSH and K3s ports
**And** unattended upgrades are enabled
**And** eGPU auto-connects on boot

**Story Points:** 5

---

#### Story 12.2: Configure Tailscale Mesh on All K3s Nodes (Solution A)

**As a** platform engineer
**I want** Tailscale installed on all K3s nodes with flannel configured over the mesh
**So that** the Intel NUC GPU worker can join the cluster from a different subnet (192.168.0.x → 192.168.2.x)

**Acceptance Criteria:**

**AC1: Install Tailscale on Existing K3s Nodes**
**Given** K3s cluster is running (master, worker-01, worker-02)
**When** I install Tailscale on each node
**Then** I run on each node:
```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```
**And** each node gets a Tailscale IP (100.x.x.a, 100.x.x.b, 100.x.x.c)
**And** all nodes appear in Tailscale admin console
**And** this validates FR100 (all K3s nodes run Tailscale)

**AC2: Configure K3s Master with Tailscale**
**Given** Tailscale is running on k3s-master
**When** I update K3s server config
**Then** I add to `/etc/rancher/k3s/config.yaml`:
```yaml
flannel-iface: tailscale0
node-external-ip: <tailscale-100.x.x.a>
tls-san:
  - <tailscale-100.x.x.a>
  - 192.168.2.20
```
**And** I add to `/etc/environment`:
```bash
NO_PROXY=127.0.0.0/8,10.0.0.0/8,100.64.0.0/10,172.16.0.0/12,192.168.0.0/16,.local,localhost
```
**And** I restart K3s: `sudo systemctl restart k3s`
**And** this validates FR101, FR102, FR103

**AC3: Configure K3s Workers with Tailscale**
**Given** Tailscale is running on k3s-worker-01 and k3s-worker-02
**When** I update K3s agent config on each worker
**Then** I add to `/etc/rancher/k3s/config.yaml`:
```yaml
flannel-iface: tailscale0
node-external-ip: <tailscale-100.x.x.b>  # Each worker's Tailscale IP
```
**And** I add NO_PROXY to `/etc/environment` (same as master)
**And** I restart K3s agent: `sudo systemctl restart k3s-agent`
**And** rolling restart: one node at a time, verify Ready before next

**AC4: Verify Cluster Connectivity**
**Given** all nodes restarted with Tailscale config
**When** I verify cluster status
**Then** `kubectl get nodes -o wide` shows all nodes with Tailscale IPs (100.x.x.*)
**And** pods can communicate across nodes (test with busybox ping)
**And** this validates NFR55, NFR56

**AC5: Join Intel NUC GPU Worker**
**Given** Intel NUC has Tailscale running (from Story 12.1)
**When** I install K3s agent on Intel NUC
**Then** I run:
```bash
TAILSCALE_IP=$(tailscale ip -4)
curl -sfL https://get.k3s.io | K3S_URL=https://<master-tailscale-ip>:6443 \
  K3S_TOKEN=<cluster-token> sh -s - agent \
  --flannel-iface tailscale0 \
  --node-external-ip=$TAILSCALE_IP
```
**And** node joins: `kubectl get nodes` shows `k3s-gpu-worker` as Ready
**And** this validates FR71 (GPU worker joins via Tailscale mesh)

**AC6: Apply GPU Labels and Taints**
**Given** k3s-gpu-worker has joined
**When** I apply labels and taints
**Then** I run:
```bash
kubectl label nodes k3s-gpu-worker gpu=nvidia
kubectl taint nodes k3s-gpu-worker nvidia.com/gpu=present:NoSchedule
```
**And** `kubectl describe node k3s-gpu-worker` shows labels and taints applied

**Story Points:** 8

---

#### Story 12.3: Install NVIDIA Container Toolkit and GPU Operator

**As a** platform engineer
**I want** NVIDIA Container Toolkit and GPU Operator deployed
**So that** Kubernetes can schedule GPU workloads with proper runtime support

**Acceptance Criteria:**

**Given** NUC is joined to cluster
**When** I install NVIDIA Container Toolkit on NUC
**Then** I run:
```bash
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | \
  sudo tee /etc/apt/sources.list.d/nvidia-docker.list
sudo apt update && sudo apt install -y nvidia-container-toolkit
sudo systemctl restart k3s-agent
```

**Given** container toolkit is installed
**When** I deploy NVIDIA GPU Operator via Helm
**Then** I run:
```bash
helm repo add nvidia https://helm.ngc.nvidia.com/nvidia && helm repo update
helm upgrade --install gpu-operator nvidia/gpu-operator \
  -n gpu-operator --create-namespace \
  --set driver.enabled=false \
  --set toolkit.enabled=true
```
**And** operator pods are running: `kubectl get pods -n gpu-operator`

**Given** GPU Operator is deployed
**When** I create RuntimeClass for GPU workloads
**Then** I apply:
```yaml
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: nvidia
handler: nvidia
```

**Given** RuntimeClass is created
**When** I verify GPU visibility
**Then** `kubectl describe node k3s-gpu-worker | grep nvidia.com/gpu` shows: `nvidia.com/gpu: 1`
**And** this validates FR39, NFR37 (GPU resources available, automatic driver setup)

**Story Points:** 8

---

#### Story 12.4: Deploy vLLM with 3-Model Configuration

**As a** ML engineer
**I want** vLLM deployed serving DeepSeek-Coder 6.7B, Mistral 7B, and Llama 3.1 8B
**So that** AI workflows can access GPU-accelerated inference via API

**Acceptance Criteria:**

**Given** GPU Operator is operational
**When** I deploy vLLM in `ml` namespace
**Then** the Deployment manifest includes:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vllm-server
  namespace: ml
spec:
  replicas: 1
  template:
    spec:
      runtimeClassName: nvidia
      nodeSelector:
        gpu: nvidia
      tolerations:
      - key: nvidia.com/gpu
        operator: Exists
        effect: NoSchedule
      containers:
      - name: vllm
        image: vllm/vllm-openai:latest
        args:
        - --model
        - deepseek-ai/deepseek-coder-6.7b-instruct
        - --gpu-memory-utilization
        - "0.9"
        resources:
          limits:
            nvidia.com/gpu: 1
```

**Given** vLLM is deployed
**When** I create Service and IngressRoute
**Then** Service exposes port 8000
**And** IngressRoute configured:
```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: vllm-https
  namespace: ml
spec:
  entryPoints:
  - websecure
  routes:
  - match: Host(`vllm.home.jetzinger.com`)
    kind: Rule
    services:
    - name: vllm-api
      port: 8000
  tls:
    certResolver: letsencrypt
```

**Given** vLLM is accessible
**When** I test inference
**Then** `curl https://vllm.home.jetzinger.com/v1/models` returns model list
**And** inference response time <500ms for typical prompts
**And** this validates FR38, FR72, NFR38 (vLLM deployment, multi-model support)

**Story Points:** 13

---

#### Story 12.5: Configure Hot-Plug and Graceful Degradation

**As a** platform engineer
**I want** eGPU hot-plug support with automatic Ollama CPU fallback
**So that** AI workflows continue during GPU maintenance without manual intervention

**Acceptance Criteria:**

**Given** vLLM is deployed
**When** I create PodDisruptionBudget
**Then** the PDB allows graceful pod termination:
```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: vllm-pdb
  namespace: ml
spec:
  maxUnavailable: 1
  selector:
    matchLabels:
      app: vllm
```

**Given** Ollama is already deployed (Epic 6)
**When** I configure load balancing between vLLM and Ollama
**Then** Service selector matches both backends
**And** traffic routes to available inference backend

**Given** GPU node monitoring is configured
**When** I create PrometheusRule for GPU node down
**Then** alert triggers when GPU worker is unavailable for 2 minutes
**And** alert routes to ntfy.sh for mobile notification

**Given** I create eGPU disconnect procedure
**When** I document runbook in `docs/runbooks/egpu-hotplug.md`
**Then** runbook includes:
- Disconnect: `kubectl drain k3s-gpu-worker --ignore-daemonsets`, unplug eGPU
- Reconnect: Plug eGPU, verify `nvidia-smi`, `kubectl uncordon k3s-gpu-worker`

**Given** procedure is tested
**When** I disconnect eGPU
**Then** vLLM traffic fails over to Ollama CPU
**And** when I reconnect eGPU
**Then** vLLM resumes GPU inference
**And** this validates FR73, FR74 (graceful degradation, hot-plug capability)

**Story Points:** 8

---

#### Story 12.6: GPU Metrics and Performance Validation

**As a** platform engineer
**I want** GPU metrics exported to Prometheus with Grafana dashboards
**So that** GPU utilization and inference performance can be monitored

**Acceptance Criteria:**

**Given** GPU Operator is deployed
**When** I enable DCGM Exporter
**Then** I run:
```bash
helm upgrade gpu-operator nvidia/gpu-operator \
  -n gpu-operator \
  --set dcgmExporter.enabled=true
```
**And** `kubectl get pods -n gpu-operator | grep dcgm` shows exporter running

**Given** DCGM Exporter is running
**When** I create ServiceMonitor for Prometheus
**Then** the ServiceMonitor scrapes DCGM metrics every 30s
**And** Prometheus targets show `dcgm-exporter` as UP

**Given** metrics are scraped
**When** I import NVIDIA DCGM Exporter Dashboard (Grafana ID: 12239)
**Then** dashboard shows:
- GPU utilization (%)
- GPU memory usage (MB/12288MB)
- GPU temperature (°C)
- Power consumption (W)
- SM clock speed (MHz)

**Given** dashboard is configured
**When** I perform performance validation
**Then** I verify:
- **NFR34**: GPU utilization >80% during concurrent inference requests
- **NFR35**: 50+ tokens/second for Mistral 7B and Llama 3.1 8B
- **NFR36**: GPU worker joins cluster within 2 minutes of boot
- Inference latency <500ms for typical requests (128 token output)

**Given** validation is complete
**When** I capture screenshots
**Then** GPU metrics screenshots saved to `docs/screenshots/gpu-metrics.png`
**And** dashboard is accessible at `grafana.home.jetzinger.com`

**Story Points:** 8

---

#### Story 12.7: Deploy Paperless-AI with GPU Ollama Integration

**As a** user
**I want** Paperless-ngx documents auto-classified using GPU-accelerated LLM inference
**So that** tags, correspondents, and document types are automatically populated from content

**Acceptance Criteria:**

**Given** GPU worker (Intel NUC + RTX 3060) is running Ollama
**When** I verify Ollama GPU availability
**Then** `kubectl get pods -n ml -l app=ollama` shows running pod on GPU worker
**And** `ollama list` shows llama3.2:1b or larger model loaded
**And** GPU is utilized for inference (NVIDIA SMI shows memory usage)

**Given** Ollama is GPU-accelerated
**When** I deploy Paperless-AI connector
**Then** the following resources are created:
- Deployment: `paperless-ai` (1 replica, image: `douaberigoale/paperless-metadata-ollama-processor`)
- ConfigMap: `paperless-ai-config` (connection settings)
- Secret: `paperless-ai-secrets` (Paperless API token)

**Given** Paperless-AI is deployed
**When** I configure environment variables
**Then** configuration includes:
```yaml
env:
  PAPERLESS_URL: "http://paperless-ngx.docs.svc.cluster.local:8000"
  PAPERLESS_API_TOKEN: "<api-token>"
  OLLAMA_URL: "http://ollama.ml.svc.cluster.local:11434"
  OLLAMA_MODEL: "llama3.2:1b"
  PROCESS_PREDEFINED_DOCUMENTS: "true"
  ADD_AI_PROCESSED_TAG: "true"
```
**And** this validates FR87 (Paperless-AI connects to GPU Ollama)

**Given** Paperless-AI is connected
**When** I upload a new document to Paperless-ngx
**Then** document content is sent to Ollama for classification
**And** inference uses GPU acceleration (NFR42: 50+ tokens/sec)
**And** classification completes within 10 seconds (NFR43)
**And** this validates FR88 (LLM-based auto-tagging)

**Given** AI classification is working
**When** I check document metadata after processing
**Then** tags are auto-populated based on document content
**And** correspondent is identified from letterhead/sender
**And** document type is classified (invoice, contract, statement, etc.)
**And** `ai-processed` tag is added to document
**And** this validates FR89 (auto-populate correspondents and types)

**Given** processing pipeline is validated
**When** I monitor GPU metrics during document processing
**Then** Grafana dashboard shows GPU utilization spikes during inference
**And** processing throughput meets NFR42 (50+ tokens/second)
**And** per-document latency meets NFR43 (<10 seconds)

**Implementation Notes:**
- Paperless-AI: `douaberigoale/paperless-metadata-ollama-processor` Docker image
- Ollama must be running on GPU worker for acceptable performance
- Model: llama3.2:1b for balance of speed and accuracy
- API token generated in Paperless-ngx admin UI
- Processor polls for new documents or uses webhook

**Story Points:** 5

---

### Epic 13: Steam Gaming Platform (Dual-Use GPU)

**User Outcome:** Tom can use the Intel NUC + RTX 3060 for both Steam gaming (Windows games via Proton) AND ML inference (vLLM), switching between modes with a simple script that gracefully scales down K8s workloads when gaming and restores them afterward.

**FRs Covered:** FR95-99
**NFRs Covered:** NFR51-54

---

#### Story 13.1: Install Steam and Proton on Intel NUC

**As a** gamer
**I want** Steam installed on the Intel NUC host with Proton enabled
**So that** I can play Windows games using the RTX 3060 eGPU

**Acceptance Criteria:**

**Given** Intel NUC is running Ubuntu 22.04 with RTX 3060 eGPU configured
**When** I install Steam from the official repository
**Then** `sudo apt install steam` completes successfully
**And** Steam client launches and authenticates
**And** this validates FR95 (Steam on host Ubuntu OS)

**Given** Steam is installed
**When** I enable Steam Play for all titles
**Then** Settings → Steam Play → "Enable Steam Play for all other titles" is checked
**And** Proton version is set (Proton Experimental or Proton 9.0+)
**And** this validates FR96 (Proton for Windows game compatibility)

**Given** Proton is enabled
**When** I download and launch a Windows game
**Then** game launches using Proton compatibility layer
**And** game renders on RTX 3060 eGPU
**And** `nvidia-smi` shows game process using GPU memory

**Given** Steam gaming is working
**When** I configure `nvidia-drm.modeset=1` for PRIME support
**Then** `/etc/modprobe.d/nvidia-drm.conf` contains `options nvidia-drm modeset=1`
**And** after reboot, GPU is available for both Steam and K8s workloads

**Implementation Notes:**
- Steam runs on host OS (not containerized) - graphics workloads need direct GPU access
- Proton uses WINE + DXVK for DirectX translation
- `nvidia-drm.modeset=1` required for proper eGPU support
- Test with a known Proton-compatible game (e.g., Hades, Stardew Valley)

**Story Points:** 3

---

#### Story 13.2: Configure Mode Switching Script

**As a** platform operator
**I want** a script to switch between Gaming Mode and ML Mode
**So that** I can easily transition the GPU between gaming and K8s ML workloads

**Acceptance Criteria:**

**Given** Intel NUC has both Steam and K3s agent installed
**When** I create `/usr/local/bin/gpu-mode` script
**Then** script accepts `gaming` or `ml` argument
**And** script is executable: `chmod +x /usr/local/bin/gpu-mode`
**And** this validates FR97 (mode switching script)

**Given** script is created
**When** I run `gpu-mode gaming`
**Then** script executes: `kubectl scale deployment/vllm --replicas=0 -n ml`
**And** vLLM pods terminate and release GPU memory
**And** script outputs: "Gaming Mode: vLLM scaled to 0, GPU available for Steam"
**And** completion time is <30 seconds (NFR51)
**And** this validates FR98 (Gaming Mode)

**Given** Gaming Mode is active
**When** I run `gpu-mode ml`
**Then** script executes: `kubectl scale deployment/vllm --replicas=1 -n ml`
**And** vLLM pod starts and loads models
**And** script outputs: "ML Mode: vLLM restored, GPU dedicated to inference"
**And** completion time is <2 minutes (NFR52)
**And** this validates FR99 (ML Mode restoration)

**Given** mode switching works
**When** I verify GPU availability after switching
**Then** `nvidia-smi` shows expected GPU usage:
- Gaming Mode: GPU available (0% VRAM from K8s)
- ML Mode: vLLM using ~10-11GB VRAM

**Implementation Notes:**
```bash
#!/bin/bash
# /usr/local/bin/gpu-mode
case "$1" in
  gaming)
    kubectl scale deployment/vllm --replicas=0 -n ml
    echo "Gaming Mode: vLLM scaled to 0, GPU available for Steam"
    ;;
  ml)
    kubectl scale deployment/vllm --replicas=1 -n ml
    echo "ML Mode: vLLM restored, GPU dedicated to inference"
    ;;
  *)
    echo "Usage: gpu-mode [gaming|ml]"
    exit 1
    ;;
esac
```

**Story Points:** 5

---

#### Story 13.3: Integrate n8n Fallback Routing

**As a** platform operator
**I want** n8n workflows to automatically route to Ollama CPU when GPU is unavailable
**So that** AI inference continues working (with degraded performance) during gaming

**Acceptance Criteria:**

**Given** n8n workflows use vLLM for inference
**When** I configure fallback detection
**Then** workflows check vLLM availability before sending requests
**And** timeout is set to 10 seconds (NFR50)

**Given** fallback detection is configured
**When** vLLM is unavailable (Gaming Mode)
**Then** workflows automatically route to Ollama CPU endpoint
**And** inference latency is <5 seconds (NFR54)
**And** user receives results (with potentially lower quality)

**Given** fallback routing works
**When** I monitor n8n during mode transitions
**Then** no workflow failures occur during Gaming Mode
**And** Grafana alerts show "GPU unavailable - using CPU fallback"

**Implementation Notes:**
- n8n workflow nodes: HTTP Request with error handling
- Primary: `http://vllm.ml.svc.cluster.local:8000/v1/completions`
- Fallback: `http://ollama.ml.svc.cluster.local:11434/api/generate`
- Health check endpoint for vLLM availability

**Story Points:** 3

---

#### Story 13.4: Validate Gaming Performance

**As a** gamer
**I want** Steam games to achieve 60+ FPS at 1080p
**So that** the gaming experience is smooth with exclusive GPU access

**Acceptance Criteria:**

**Given** Gaming Mode is active (vLLM scaled to 0)
**When** I launch a graphics-intensive game
**Then** game renders at 60+ FPS at 1080p (NFR53)
**And** `nvidia-smi` shows full GPU availability
**And** no VRAM conflicts with K8s workloads

**Given** gaming is in progress
**When** I monitor system resources
**Then** GPU temperature stays within safe limits (<85°C)
**And** game runs smoothly without stuttering
**And** no K8s pods are competing for GPU resources

**Given** gaming session ends
**When** I switch back to ML Mode
**Then** `gpu-mode ml` restores vLLM within 2 minutes (NFR52)
**And** vLLM health check passes
**And** n8n workflows resume using GPU inference

**Given** performance is validated
**When** I document tested games
**Then** README includes list of validated games with settings:
- Game name, Proton version, resolution, FPS achieved
- Any required tweaks or compatibility notes

**Implementation Notes:**
- Test with a mix of game types (indie, AAA)
- Benchmark games: Hades, Civilization VI, or similar
- Document any Proton GE requirements for specific titles
- GPU: RTX 3060 12GB should handle most 1080p gaming comfortably

**Story Points:** 2

---

## Phase 1 Epic Details (Completed)

### Epic 1: Foundation - K3s Cluster with Remote Access

Tom has a working multi-node K3s cluster he can access from anywhere via Tailscale.

---

## Summary

| Epic | Title | Stories | FRs Covered | NFRs Covered |
|------|-------|---------|-------------|--------------|
| 1 | Foundation - K3s Cluster | 5 | FR1-6 | - |
| 2 | Storage & Persistence | 4 | FR14-18 | NFR4, NFR16 |
| 3 | Ingress, TLS & Service Exposure | 5 | FR9-10, FR19-23 | NFR7, NFR17 |
| 4 | Observability Stack | 6 | FR7, FR11, FR24-30 | NFR5, NFR14, NFR18 |
| 5 | PostgreSQL Database Service | 5 | FR8, FR31-35 | NFR20 |
| 6 | AI Inference Platform | 4 | FR12-13, FR36-37, FR40 | NFR13 |
| 7 | Development Proxy | 3 | FR41-43 | - |
| 8 | Cluster Operations & Maintenance | 5 | FR44-48 | NFR2, NFR11, NFR20, NFR22 |
| 9 | Portfolio & Public Showcase | 5 | FR49-54 | NFR24, NFR25, NFR26, NFR27 |
| **Phase 1 Total** | | **42 stories** | **54 FRs** | **19 NFRs** |
| | | | | |
| 10 | Document Management System (Paperless-ngx Ecosystem) | 11 | FR55-58, FR64-66, FR75-86, FR90-93 | NFR28-30, NFR39-41 |
| 11 | Dev Containers Platform | 6 | FR59-63, FR67-70 | NFR31-33 |
| 12 | GPU/ML Inference Platform (vLLM + RTX 3060) | 7 | FR38-39, FR71-74, FR87-89 | NFR34-38, NFR42-43 |
| **Phase 2 Total** | | **24 stories** | **39 FRs** | **19 NFRs** |
| | | | | |
| **Grand Total** | | **66 stories** | **93 FRs** | **38 NFRs** |

**Phase 1 Status:** ✅ Completed (Epics 1-9)
**Phase 2 Status:** ✅ Ready for Implementation (Epics 10-12 - all stories created)

---

**Workflow Complete:** All Phase 2 epics and stories have been created with detailed acceptance criteria, including the expanded Paperless-ngx ecosystem (Office processing, PDF editing, AI classification, email integration). Ready to add to sprint-status.yaml and begin implementation.
