---
stepsCompleted: [1, 2, 3, 4]
inputDocuments: []
session_topic: 'Home Lab Kubernetes Cluster with K3s'
session_goals: 'Generate solutions and gain insights for running Docker containers'
selected_approach: 'AI-Recommended Techniques'
techniques_used: ['First Principles Thinking', 'Morphological Analysis', 'Constraint Mapping']
ideas_generated: ['multi-node-single-master', 'dedicated-vm-control-plane', 'nfs-primary-storage', 'vpn-rescue-hatch', 'nextdns-rewrites', 'gpu-dedicated-namespace', 'phased-weekend-approach']
workflow_completed: true
session_active: false
context_file: ''
---

# Brainstorming Session Results

**Facilitator:** Tom
**Date:** 2025-12-27

## Session Overview

**Topic:** Home Lab Kubernetes Cluster with K3s
**Goals:** Generate solutions and gain insights for running Docker containers

### Session Setup

This brainstorming session focuses on exploring a home lab Kubernetes cluster using K3s to orchestrate Docker containers. The primary objectives are to discover practical solutions for setup, architecture, and configuration while gaining insights into best practices suitable for a home lab environment.

**Potential Exploration Areas:**
- Cluster architecture and node configuration
- Storage solutions (persistent volumes, NFS, local-path)
- Networking and ingress strategies
- Container deployment patterns
- Monitoring and observability
- Security considerations
- High availability and backup strategies
- Resource optimization for home lab constraints

## Technique Selection

**Approach:** AI-Recommended Techniques
**Analysis Context:** Home Lab Kubernetes Cluster with K3s with focus on generating solutions and insights

**Recommended Techniques:**

1. **First Principles Thinking:** Strip away assumptions about home lab K8s clusters and rebuild from fundamental requirements - ensures we solve the right problem
2. **Morphological Analysis:** Systematically explore all parameter combinations (storage, networking, nodes, ingress, monitoring) for comprehensive solution coverage
3. **Constraint Mapping:** Map real home lab constraints (hardware, budget, power, time) and find optimal pathways through them

**AI Rationale:** This sequence progresses from foundational clarity (what do you actually need?) through systematic exploration (what are all the options?) to practical refinement (what works within your constraints). Ideal for technical infrastructure planning where both breadth of options and practical feasibility matter.

## Technique 1: First Principles Thinking

### Core Purpose Identified
- **Primary driver:** Learning lab - okay if things break, but they shouldn't
- **Philosophy:** Learn production-grade practices by implementing them, not just reading

### Workload Landscape
| Type | Examples |
|------|----------|
| Stateless | Web apps, APIs, dashboards |
| Stateful | Databases |
| Network-critical | Reverse proxy, VPN |
| Resource-hungry | AI/ML experiments |

### Hardware Landscape
| Node | Role | Architecture |
|------|------|--------------|
| Synology NAS | Storage backbone, always-on | x86 |
| Raspberry Pi | Low-power, lightweight always-on services | ARM64 |
| Intel NUC + eGPU | AI/ML powerhouse, experiments | x86 + GPU |
| Virtual Machines | Flexible compute | x86 |

### First Principles Discovered

1. **Learning-first, but done right** - Freedom to break things, but goal is learning production practices by implementing them
2. **Core infra isolated from experiments** - VPN/proxy cannot go down because NUC is training models
3. **Multi-architecture reality** - ARM (Pi) + x86 (NUC, VMs) means workload placement is deliberate
4. **Natural hardware tiers** - Always-on (Pi, NAS) vs Compute (NUC, VMs)
5. **VPN outside cluster** - Rescue hatch stays independent; Traefik inside for learning ingress

## Technique 2: Morphological Analysis

### Complete Configuration Matrix

| Parameter | Choice | Rationale |
|-----------|--------|-----------|
| **Cluster Topology** | Multi-node, single master | Learn distributed scheduling without HA complexity |
| **Control Plane** | Dedicated VM | Isolated, snapshot-able, easy to rebuild |
| **Workers** | NUC + eGPU, 1+ VMs | Scalable compute, GPU for ML |
| **Outside Cluster** | Pi (VPN), Synology (NFS) | Rescue hatch + storage provider |
| **Storage** | NFS-primary (Synology) | Simple, centralized, Synology handles redundancy |
| **CNI** | Flannel (K3s default) | Start simple, swap later if needed |
| **Ingress** | Traefik (K3s default) | Built-in, dashboard, automatic HTTPS |
| **Monitoring** | Prometheus + Grafana | Full observability, industry standard |
| **Deployment** | kubectl + Helm → GitOps later | Learn fundamentals first |
| **GPU** | NVIDIA Operator, dedicated namespace | RTX 3060, isolated ML workloads |

### Node Architecture

| Component | Role | In Cluster? |
|-----------|------|-------------|
| VM #1 | Control plane (master) | Yes - server |
| Intel NUC + eGPU | Worker - AI/ML, GPU workloads | Yes - agent |
| VM #2+ | Worker - general compute | Yes - agent |
| Raspberry Pi | VPN (rescue hatch) | No - standalone |
| Synology NAS | NFS storage provider | No - external |

### Key Architectural Decisions
- **x86-only cluster** - No ARM architecture headaches
- **GPU isolation** - Dedicated namespace for ML experiments
- **Storage centralized** - Synology NFS, not distributed storage
- **Defaults where sensible** - Flannel, Traefik from K3s

## Technique 3: Constraint Mapping

### Hardware Constraints

| Component | Specs | Assessment |
|-----------|-------|------------|
| NUC | i5-1135G7, 16GB RAM, 256GB SSD + RTX 3060 eGPU | ⚠️ 16GB modest for ML; pending acquisition |
| VM Host (Proxmox) | i7-10810U, 53GB available RAM, 12 cores | ✅ Can run many VMs |
| Synology DS920+ | 8.8TB free, RAID1, NVMe cache | ✅ Solid storage |
| Network | Gigabit | ⚠️ Adequate, NFS may bottleneck under heavy I/O |

### Environment Constraints
- **Power/Heat/Noise:** Not a concern - cool basement location
- **UPS:** Protected on NAS and Proxmox host
- **Time:** Weekends only, deep dive one topic at a time

### Network Architecture

| Component | Solution |
|-----------|----------|
| Subnet | 192.168.2.0/24 (existing) |
| Router | Fritz!Box 6660 |
| Remote Access | Tailscale subnet routers (NAS + Pi) |
| DNS | NextDNS with Rewrites for *.home.jetzinger.com |
| Domain | jetzinger.com (for certs) |

### IP Allocation Plan

| Device | IP |
|--------|-----|
| Fritz!Box | 192.168.2.1 |
| Synology NAS | 192.168.2.2 |
| Raspberry Pi | 192.168.2.162 |
| Proxmox Host | 192.168.2.167 |
| k3s-master (VM) | 192.168.2.20 |
| k3s-worker-01 (VM) | 192.168.2.21 |
| k3s-worker-02 (VM) | 192.168.2.22 |
| k3s-nuc (future) | 192.168.2.30 |
| MetalLB Pool | 192.168.2.100-120 |

### Dependencies

| Dependency | Status |
|------------|--------|
| Hardware | ⚠️ NUC pending - can start without it |
| Domain | ✅ jetzinger.com ready |
| Network | ✅ Fixed IPs available |
| Migration | ✅ Clean slate |

### Identified Pathways

**Recommended: Start Now (No NUC)**
- Weekend 1: K3s control plane VM + 1 worker VM
- Weekend 2: NFS storage integration with Synology
- Weekend 3: Traefik + domain setup + HTTPS
- Weekend 4: Prometheus + Grafana
- Weekend 5+: Deploy apps, learn, iterate
- Later: Add NUC as GPU worker when acquired

## Idea Organization and Prioritization

### Thematic Summary

| Theme | Key Decisions |
|-------|---------------|
| **Architecture** | Multi-node single master, dedicated VM control plane, x86-only |
| **Infrastructure** | NFS storage, Flannel CNI, Traefik ingress, Prometheus+Grafana |
| **Network** | Tailscale subnet routers, NextDNS with rewrites, MetalLB |
| **GPU/ML** | NVIDIA GPU Operator, dedicated namespace, RTX 3060 eGPU |

### Breakthrough Concepts

1. **VPN as Rescue Hatch** - Pi runs VPN outside cluster; if K3s dies, you can still get in
2. **Learning by Doing Right** - Freedom to break things, but implementing production patterns
3. **NextDNS Rewrites** - Cloud DNS handles local names; no local DNS infrastructure needed
4. **Phased Weekend Approach** - One deep dive per weekend, sustainable learning pace

### Prioritized Implementation Pathway

| Phase | Weekend | Focus | Deliverable |
|-------|---------|-------|-------------|
| Foundation | 1 | K3s cluster | Control plane + 1 worker VM running |
| Foundation | 2 | Storage | NFS integration with Synology working |
| Core Services | 3 | Ingress | Traefik + HTTPS + NextDNS rewrites |
| Core Services | 4 | Observability | Prometheus + Grafana dashboards |
| Applications | 5+ | Apps | Deploy real workloads, iterate |
| GPU | Future | ML | NUC + GPU Operator + ML namespace |

## Action Plan: Weekend 1

**Goal:** Working K3s cluster with control plane + 1 worker

### VM Specifications

| VM | IP | Resources |
|----|-----|-----------|
| k3s-master | 192.168.2.20 | 2 vCPU, 4GB RAM, 32GB disk |
| k3s-worker-01 | 192.168.2.21 | 4 vCPU, 8GB RAM, 50GB disk |

### Steps

1. **Create VMs in Proxmox**
   - Ubuntu 22.04 LTS or Debian 12
   - Set static IPs as planned
   - Enable SSH access

2. **Install K3s Server (on master)**
   ```bash
   curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644
   ```

3. **Get Join Token**
   ```bash
   sudo cat /var/lib/rancher/k3s/server/node-token
   ```

4. **Join Worker**
   ```bash
   curl -sfL https://get.k3s.io | K3S_URL=https://192.168.2.20:6443 K3S_TOKEN=<token> sh -
   ```

5. **Verify Cluster**
   ```bash
   kubectl get nodes
   # Both should show Ready
   ```

6. **Deploy Test Workload**
   ```bash
   kubectl create deployment nginx --image=nginx
   kubectl get pods -o wide
   # Should schedule on worker
   ```

### Success Criteria
- [ ] Both nodes show `Ready` status
- [ ] Pod scheduled on worker node
- [ ] kubectl works from laptop via Tailscale

## Session Summary and Insights

### Key Achievements

- **Complete Architecture Design** - Every component decided with clear rationale
- **Validated Against Constraints** - Hardware, network, time all considered
- **Clear Implementation Path** - Phased weekend approach with specific steps
- **Network Deep Dive** - Tailscale + NextDNS solution eliminates complexity

### Creative Breakthroughs

1. Recognizing the tension between "learning lab" and "99% uptime" - resolved with tiered isolation
2. VPN outside cluster as rescue hatch - simple but critical insight
3. NextDNS rewrites discovery - eliminated need for local DNS infrastructure
4. x86-only cluster decision - avoiding ARM complexity for learning focus

### Session Reflections

This brainstorming session transformed a vague "I want a K3s home lab" into a comprehensive, validated architecture with:
- 5 first principles guiding all decisions
- 10 configuration parameters systematically explored
- All constraints mapped and mitigated
- Clear weekend-by-weekend implementation plan

The collaborative exploration surfaced insights that wouldn't emerge from just following tutorials - particularly around the network architecture (Tailscale + NextDNS) and the philosophical balance between learning and reliability.
