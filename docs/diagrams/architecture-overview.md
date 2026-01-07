# Home Lab K3s Architecture Overview

This diagram shows the complete architecture of the home-lab K3s platform.

```mermaid
graph TB
    subgraph External["External Access"]
        Internet[Internet]
        Tailscale[Tailscale VPN<br/>Subnet Router]
    end

    subgraph Network["Network Layer (192.168.2.0/24)"]
        MetalLB[MetalLB<br/>IP Pool: .100-.120<br/>Layer 2 Mode]
        Traefik[Traefik Ingress<br/>LoadBalancer IP: .100<br/>HTTPS/TLS Termination]
        NextDNS[NextDNS Rewrites<br/>*.home.jetzinger.com → 192.168.2.100]
    end

    subgraph Control["Control Plane"]
        Master[k3s-master<br/>192.168.2.20<br/>2 vCPU, 4GB RAM<br/>Ubuntu 22.04 LTS]
    end

    subgraph Workers["Worker Nodes"]
        Worker1[k3s-worker-01<br/>192.168.2.21<br/>4 vCPU, 8GB RAM<br/>Ubuntu 22.04 LTS]
        Worker2[k3s-worker-02<br/>192.168.2.22<br/>4 vCPU, 8GB RAM<br/>Ubuntu 22.04 LTS]
    end

    subgraph Storage["External Storage"]
        Synology[Synology DS920+<br/>192.168.2.10<br/>NFS: /volume1/k8s-data<br/>8.8TB Available<br/>Hourly Snapshots]
        NFSProv[NFS Provisioner<br/>StorageClass: nfs-client<br/>Dynamic PVC Provisioning]
    end

    subgraph NS_System["kube-system namespace"]
        K3sCore[K3s Components<br/>etcd, API Server<br/>Controller Manager<br/>Scheduler]
        TraefikPod[Traefik<br/>DaemonSet]
    end

    subgraph NS_Infra["infra namespace"]
        MetalLBPod[MetalLB<br/>Controller + Speaker]
        CertMgr[cert-manager<br/>Let's Encrypt Integration<br/>Auto TLS Renewal]
    end

    subgraph NS_Monitor["monitoring namespace"]
        Prometheus[Prometheus<br/>Metrics Collection<br/>7-day Retention]
        Grafana[Grafana<br/>Dashboards & Visualization<br/>grafana.home.jetzinger.com]
        Alertmgr[Alertmanager<br/>P1 Alerts → ntfy.sh<br/>Mobile Notifications]
        Loki[Loki<br/>Log Aggregation<br/>7-day Retention]
    end

    subgraph NS_Data["data namespace"]
        Postgres[PostgreSQL<br/>Bitnami Helm Chart<br/>NFS-backed PVC<br/>pg_dump Backups]
    end

    subgraph NS_Apps["apps namespace"]
        N8N[n8n<br/>Workflow Automation<br/>PostgreSQL Backend<br/>n8n.home.jetzinger.com]
    end

    subgraph NS_ML["ml namespace"]
        Ollama[Ollama<br/>LLM Inference (CPU)<br/>Models: llama3.2:1b<br/>ollama.home.jetzinger.com]
    end

    subgraph NS_Dev["dev namespace"]
        Nginx[Nginx Reverse Proxy<br/>Hot-reload Config<br/>nginx.home.jetzinger.com]
    end

    %% External connections
    Internet -.->|Tailscale Tunnel| Tailscale
    Tailscale -->|VPN Access| NextDNS
    NextDNS -->|DNS Resolution| Traefik

    %% Network flow
    Traefik -->|Route Traffic| Grafana
    Traefik -->|Route Traffic| N8N
    Traefik -->|Route Traffic| Ollama
    Traefik -->|Route Traffic| Nginx
    MetalLB -->|LoadBalancer Service| Traefik

    %% Control plane connections
    Master -->|Manages| Worker1
    Master -->|Manages| Worker2
    Master -.->|Hosts| K3sCore

    %% Storage connections
    Synology -->|NFS Mount| NFSProv
    NFSProv -->|Provision PVCs| Prometheus
    NFSProv -->|Provision PVCs| Postgres
    NFSProv -->|Provision PVCs| Loki
    NFSProv -->|Provision PVCs| N8N
    NFSProv -->|Provision PVCs| Ollama

    %% Monitoring connections
    Prometheus -->|Scrape Metrics| K3sCore
    Prometheus -->|Scrape Metrics| Postgres
    Prometheus -->|Scrape Metrics| Ollama
    Prometheus -->|Scrape Metrics| N8N
    Prometheus -->|Send Alerts| Alertmgr
    Grafana -->|Query Metrics| Prometheus
    Grafana -->|Query Logs| Loki

    %% Application connections
    N8N -->|Database Queries| Postgres
    N8N -->|LLM Inference| Ollama

    %% Cert-manager integration
    CertMgr -.->|Issue Certs| Traefik

    classDef external fill:#e1f5ff,stroke:#01579b,stroke-width:2px
    classDef network fill:#fff3e0,stroke:#e65100,stroke-width:2px
    classDef control fill:#f3e5f5,stroke:#4a148c,stroke-width:2px
    classDef worker fill:#e8f5e9,stroke:#1b5e20,stroke-width:2px
    classDef storage fill:#fff9c4,stroke:#f57f17,stroke-width:2px
    classDef namespace fill:#fce4ec,stroke:#880e4f,stroke-width:2px

    class Internet,Tailscale external
    class MetalLB,Traefik,NextDNS network
    class Master control
    class Worker1,Worker2 worker
    class Synology,NFSProv storage
    class K3sCore,MetalLBPod,CertMgr,Prometheus,Grafana,Alertmgr,Loki,Postgres,N8N,Ollama,Nginx,TraefikPod namespace
```

## Architecture Highlights

### Cluster Topology
- **3-node K3s cluster**: 1 control plane + 2 worker nodes
- **K3s version**: v1.34.3+k3s1
- **OS**: Ubuntu 22.04 LTS across all nodes
- **Network**: Private 192.168.2.0/24 subnet

### Network & Ingress
- **External Access**: Tailscale VPN only (no public internet exposure)
- **DNS**: NextDNS rewrites for `*.home.jetzinger.com` domains
- **Load Balancing**: MetalLB Layer 2 mode (IP pool: 192.168.2.100-120)
- **Ingress**: Traefik (K3s bundled) with automatic TLS via cert-manager
- **TLS Certificates**: Let's Encrypt (auto-renewal, 90-day duration)

### Storage Architecture
- **External NFS**: Synology DS920+ (8.8TB available)
- **Dynamic Provisioning**: nfs-subdir-external-provisioner
- **StorageClass**: `nfs-client` (default)
- **Backup Strategy**: Synology hourly snapshots + application-specific backups

### Observability Stack
- **Metrics**: Prometheus (7-day retention, NFS-backed)
- **Visualization**: Grafana with pre-built K8s dashboards
- **Logging**: Loki for centralized log aggregation
- **Alerting**: Alertmanager → ntfy.sh for mobile P1 alerts
- **Monitoring Coverage**: All nodes, pods, and services instrumented

### Application Workloads
- **Database**: PostgreSQL (Bitnami Helm chart, NFS persistence, pg_dump backups)
- **AI/ML**: Ollama for LLM inference (CPU mode, llama3.2:1b model)
- **Workflow Automation**: n8n (PostgreSQL backend, integrated with Ollama)
- **Development**: Nginx reverse proxy for local dev servers

### Namespace Organization
| Namespace | Purpose | Key Components |
|-----------|---------|----------------|
| `kube-system` | K3s core | etcd, API server, Traefik |
| `infra` | Infrastructure | MetalLB, cert-manager |
| `monitoring` | Observability | Prometheus, Grafana, Loki, Alertmanager |
| `data` | Data services | PostgreSQL |
| `apps` | Applications | n8n |
| `ml` | AI/ML workloads | Ollama |
| `dev` | Development | Nginx proxy |

### Security & Access
- **API Access**: kubectl via Tailscale VPN only (no public exposure)
- **Service Access**: All ingress routes require Tailscale connection
- **TLS**: Enforced for all HTTPS traffic (cert-manager + Let's Encrypt)
- **Secrets**: Kubernetes secrets with K3s default encryption at rest
- **OS Updates**: Automatic security patches via unattended-upgrades

### Design Decisions
See [Architecture Decision Records (ADRs)](../adrs/) for detailed rationale:
- [ADR-001: LXC Containers for K3s Nodes](../adrs/ADR-001-lxc-containers-for-k3s.md)
- [ADR-002: External NFS Storage over Longhorn](../adrs/ADR-002-nfs-over-longhorn.md)
- [ADR-003: Traefik Ingress Controller](../adrs/ADR-003-traefik-ingress.md)
- [ADR-004: kube-prometheus-stack for Observability](../adrs/ADR-004-kube-prometheus-stack.md)
- [ADR-005: Manual Helm Deployment over GitOps](../adrs/ADR-005-manual-helm-over-gitops.md)

---

**To export this diagram as PNG:**
1. View this file on GitHub (Mermaid renders automatically)
2. Take screenshot, or use [Mermaid Live Editor](https://mermaid.live/) to export as PNG/SVG
3. Save to `docs/diagrams/architecture-overview.png`
