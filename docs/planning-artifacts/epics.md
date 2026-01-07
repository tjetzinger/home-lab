---
stepsCompleted: [1, 2, 3, 4]
workflow_completed: true
completedAt: '2025-12-28'
lastModified: '2025-12-29'
inputDocuments:
  - 'docs/planning-artifacts/prd.md'
  - 'docs/planning-artifacts/architecture.md'
workflowType: 'epics-and-stories'
date: '2025-12-27'
author: 'Tom'
project_name: 'home-lab'
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

**AI/ML Workloads (5 FRs)**
- FR36: Operator can deploy Ollama for LLM inference
- FR37: Applications can query Ollama API for completions
- FR38: Operator can deploy vLLM for production inference (Phase 2)
- FR39: GPU workloads can request GPU resources via NVIDIA Operator (Phase 2)
- FR40: Operator can deploy n8n for workflow automation

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

**Document Management (4 FRs)**
- FR55: Operator can deploy Paperless-ngx with Redis backend
- FR56: Paperless-ngx persists documents to NFS storage
- FR57: User can access Paperless-ngx via ingress with HTTPS
- FR58: User can upload, tag, and search scanned documents

**Dev Containers (5 FRs)**
- FR59: Nginx proxy routes to dev containers in `dev` namespace
- FR60: Operator can provision dev containers with git worktree support
- FR61: Developer can connect VS Code to dev container via Nginx proxy
- FR62: Developer can run Claude Code inside dev containers
- FR63: Dev containers use local storage for workspace data

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
| infra | MetalLB, cert-manager |
| monitoring | Prometheus, Grafana, Loki, Alertmanager |
| data | PostgreSQL |
| apps | n8n |
| ml | Ollama |
| docs | Paperless-ngx, Redis |
| dev | Nginx proxy, dev containers |

**Node Topology:**
| Node | Role | IP |
|------|------|-----|
| k3s-master | Control plane | 192.168.2.20 |
| k3s-worker-01 | General compute | 192.168.2.21 |
| k3s-worker-02 | General compute | 192.168.2.22 |

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
| FR38 | Phase 2 | Deploy vLLM for production inference (deferred) |
| FR39 | Phase 2 | GPU workloads request GPU resources (deferred) |
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
| FR59 | Epic 10 | Nginx proxy routes to dev containers |
| FR60 | Epic 10 | Provision dev containers with git worktree support |
| FR61 | Epic 10 | Connect VS Code to dev container via Nginx |
| FR62 | Epic 10 | Run Claude Code inside dev containers |
| FR63 | Epic 10 | Dev containers use local storage for workspace |

**Coverage Summary:** 61 of 63 FRs covered in MVP (FR38, FR39 deferred to Phase 2)

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

### Epic 10: Document Management & Dev Environment
Tom can manage scanned documents with Paperless-ngx and develop remotely using dev containers with VS Code and Claude Code.
**FRs covered:** FR55, FR56, FR57, FR58, FR59, FR60, FR61, FR62, FR63

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

## Epic 10: Document Management & Dev Environment

Tom can manage scanned documents with Paperless-ngx and develop remotely using dev containers with VS Code and Claude Code.

---

### Story 10.1: Deploy Paperless-ngx with Redis Backend

As a **cluster operator**,
I want **to deploy Paperless-ngx for document management**,
So that **I can digitize, organize, and search scanned documents**.

**Acceptance Criteria:**

**Given** cluster has NFS storage and ingress configured
**When** I create the `docs` namespace
**Then** the namespace is created with appropriate labels

**Given** the docs namespace exists
**When** I deploy Paperless-ngx via Helm with `values-homelab.yaml`
**Then** the Paperless-ngx deployment is created
**And** Redis pod starts as backend for task queue
**And** all pods reach Running status

**Given** Paperless-ngx requires persistent storage
**When** I configure NFS-backed PVCs for:
- Document consumption folder
- Document storage folder
- Data folder (SQLite database)
**Then** all PVCs are bound to NFS provisioner
**And** this validates FR55 (deploy Paperless-ngx with Redis)

**Given** Paperless-ngx is running
**When** I create an IngressRoute for paperless.home.jetzinger.com with TLS
**Then** cert-manager provisions a certificate
**And** Paperless-ngx UI is accessible via HTTPS
**And** this validates FR57 (access via ingress with HTTPS)

---

### Story 10.2: Configure Document Storage and Verify Functionality

As a **user**,
I want **to upload, tag, and search documents in Paperless-ngx**,
So that **I can manage my paperwork digitally**.

**Acceptance Criteria:**

**Given** Paperless-ngx is accessible via HTTPS
**When** I log in with the admin credentials
**Then** the Paperless-ngx dashboard loads
**And** I can access all menu items

**Given** I'm logged into Paperless-ngx
**When** I upload a scanned PDF document
**Then** Paperless-ngx processes the document with OCR
**And** the document appears in the document list
**And** text content is extracted and searchable

**Given** documents are uploaded
**When** I add tags and correspondents to documents
**Then** the metadata is saved
**And** I can filter documents by tag or correspondent

**Given** multiple documents exist
**When** I search for text that appears in a document
**Then** the search returns matching documents
**And** search results highlight the matched text
**And** this validates FR58 (upload, tag, and search documents)

**Given** documents are stored
**When** I check the NFS share on Synology
**Then** document files are visible in the Paperless storage directory
**And** this validates FR56 (documents persist to NFS)

**Given** Paperless-ngx is operational
**When** I document the setup in `docs/runbooks/paperless-setup.md`
**Then** the runbook includes deployment, configuration, and usage instructions

---

### Story 10.3: Deploy Dev Container Infrastructure

As a **cluster operator**,
I want **to deploy dev containers that can be accessed via SSH**,
So that **I can develop remotely using VS Code and Claude Code**.

**Acceptance Criteria:**

**Given** cluster has Nginx proxy running in `dev` namespace
**When** I create a Dockerfile for the dev container base image
**Then** the Dockerfile includes:
- Ubuntu base with development tools
- SSH server configured
- Git with worktree support
- Node.js, Python, and other dev dependencies
- Claude Code CLI installed
**And** the Dockerfile is saved at `applications/dev-containers/base-image/Dockerfile`

**Given** the base image Dockerfile exists
**When** I build and push the image to a registry (or use local)
**Then** the image is available for Kubernetes deployments

**Given** the dev container image is available
**When** I create a Deployment template for dev containers
**Then** the template includes:
- SSH server on port 22
- Local storage (emptyDir) for workspace
- Git credentials mounted from Secret
- SSH authorized_keys from ConfigMap
**And** the template is saved at `applications/dev-containers/dev-container-template.yaml`
**And** this validates FR60 (provision dev containers with git worktree support)

**Given** template is ready
**When** I deploy a dev container instance
**Then** the pod starts successfully
**And** SSH server is listening on port 22
**And** workspace directory uses local storage (not NFS)
**And** this validates FR63 (local storage for workspace)

---

### Story 10.4: Configure Nginx SSH Routing for Dev Containers

As a **cluster operator**,
I want **Nginx to route SSH connections to dev containers**,
So that **VS Code can connect remotely via the existing proxy**.

**Acceptance Criteria:**

**Given** Nginx is running in the dev namespace
**When** I configure Nginx stream module for TCP/SSH proxying
**Then** the nginx.conf includes stream block for SSH
**And** configuration is saved at `applications/dev-containers/nginx-stream-config.yaml`

**Given** Nginx stream is configured
**When** I add upstream definitions for dev container pods
**Then** each dev container gets a unique port mapping (e.g., 2222 -> container1:22, 2223 -> container2:22)
**And** this validates FR59 (Nginx routes to dev containers)

**Given** SSH routing is configured
**When** I expose the Nginx SSH ports via LoadBalancer or NodePort
**Then** SSH ports are accessible from the home network
**And** SSH ports are accessible via Tailscale

**Given** SSH routing is working
**When** I test SSH connection to a dev container through Nginx
**Then** `ssh -p 2222 user@dev.home.jetzinger.com` connects successfully
**And** I land in the dev container workspace

**Given** routing is validated
**When** I document the port mapping in `docs/runbooks/dev-containers.md`
**Then** the runbook includes:
- How to add a new dev container
- Port assignment conventions
- SSH connection examples

---

### Story 10.5: Validate VS Code and Claude Code Workflow

As a **developer**,
I want **to connect VS Code to dev containers and use Claude Code**,
So that **I can develop remotely with AI assistance**.

**Acceptance Criteria:**

**Given** dev container is running with SSH accessible via Nginx
**When** I configure VS Code Remote-SSH extension with:
- Host: dev.home.jetzinger.com
- Port: 2222 (or assigned port)
- User: dev (or configured user)
**Then** VS Code connects to the dev container
**And** this validates FR61 (connect VS Code via Nginx proxy)

**Given** VS Code is connected to dev container
**When** I open a terminal in VS Code
**Then** the terminal runs inside the dev container
**And** I have access to development tools (git, node, python, etc.)

**Given** terminal is available
**When** I run `claude` command in the terminal
**Then** Claude Code CLI starts
**And** I can interact with Claude Code for development tasks
**And** this validates FR62 (run Claude Code inside dev containers)

**Given** Claude Code is working
**When** I use git worktree to create a new branch workspace
**Then** `git worktree add ../feature-branch feature-branch` creates a new worktree
**And** I can switch VS Code to the new worktree directory
**And** both worktrees are on local storage for fast I/O

**Given** the workflow is validated
**When** I test the complete cycle:
1. SSH into dev container via VS Code
2. Clone a repository
3. Create a git worktree for a feature
4. Use Claude Code to assist with development
5. Commit and push changes
**Then** the entire workflow completes successfully
**And** all FRs for dev containers are validated (FR59-63)

**Given** workflow is complete
**When** I update the runbook with the VS Code setup
**Then** `docs/runbooks/dev-containers.md` includes:
- VS Code Remote-SSH configuration
- Claude Code usage examples
- Git worktree workflow

---

## Summary

| Epic | Title | Stories | FRs Covered |
|------|-------|---------|-------------|
| 1 | Foundation - K3s Cluster | 5 | FR1-6 |
| 2 | Storage & Persistence | 4 | FR14-18 |
| 3 | Ingress, TLS & Service Exposure | 5 | FR9-10, FR19-23 |
| 4 | Observability Stack | 6 | FR7, FR11, FR24-30 |
| 5 | PostgreSQL Database Service | 5 | FR8, FR31-35 |
| 6 | AI Inference Platform | 4 | FR12-13, FR36-37, FR40 |
| 7 | Development Proxy | 3 | FR41-43 |
| 8 | Cluster Operations & Maintenance | 5 | FR44-48 |
| 9 | Portfolio & Public Showcase | 5 | FR49-54 |
| 10 | Document Management & Dev Environment | 5 | FR55-63 |
| **Total** | | **47 stories** | **61 FRs** |

**Deferred to Phase 2:** FR38 (vLLM), FR39 (GPU/NVIDIA Operator)
