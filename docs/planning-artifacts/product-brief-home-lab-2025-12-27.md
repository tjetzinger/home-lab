---
stepsCompleted: [1, 2, 3, 4, 5, 6]
workflow_completed: true
inputDocuments:
  - 'docs/analysis/brainstorming-session-2025-12-27.md'
  - 'docs/planning-artifacts/research/domain-k8s-platform-career-positioning-research-2025-12-27.md'
date: '2025-12-27'
author: 'Tom'
project_name: 'home-lab'
---

# Product Brief: home-lab

## Executive Summary

**home-lab** is a production-grade Kubernetes learning platform that serves as both a functional home infrastructure and a career portfolio demonstrating the transition from Navigation Systems Project Manager to Platform Engineer. Built using AI-assisted engineering practices, it showcases hands-on infrastructure skills while running real workloads including AI/ML inference, development proxies, and observability stacks.

The project documents the journey of applying 10+ years of automotive distributed systems experience—OTA updates, vehicle-cloud synchronization, multi-platform coordination—to modern cloud-native infrastructure patterns on Kubernetes.

---

## Core Vision

### Problem Statement

Senior technical professionals transitioning from domain-specific roles (e.g., automotive/IVI) to Platform Engineering face a credibility gap: certifications alone don't prove hands-on capability, tutorials feel too basic for experienced engineers, and cloud playgrounds are expensive and ephemeral. There's no owned, tangible proof of infrastructure skills.

### Problem Impact

- **Career stagnation**: Stuck in legacy domains while AI/cloud-native roles explode
- **Credibility gap**: "I managed systems" doesn't equal "I can build systems"
- **Skills erosion**: Experience with distributed systems goes unrecognized without modern tooling proof
- **Missed timing**: The AI infrastructure wave rewards early movers

### Why Existing Solutions Fall Short

| Approach | Why It Fails |
|----------|--------------|
| Tutorial following | Too basic, no ownership, no real decisions |
| Cloud sandboxes | Expensive, ephemeral, nothing to show |
| Certification stacking | Proves knowledge, not capability |
| Side project apps | Shows development, not infrastructure |

### Proposed Solution

A fully-documented K3s home lab that:

1. **Runs real workloads**: AI inference (Ollama, vLLM), workflow automation (n8n), development proxies, observability stack
2. **Implements production patterns**: GitOps, proper ingress, StatefulSets, GPU scheduling
3. **Documents the journey**: Architecture decisions, lessons learned, AI-assisted methodology
4. **Bridges domains**: Explicitly connects automotive distributed systems experience to Kubernetes patterns
5. **Serves as portfolio**: GitHub repo, blog content, demonstrable running infrastructure

### Key Differentiators

1. **Domain Bridge**: OTA updates → GitOps, vehicle-cloud sync → distributed systems, IVI reliability → SRE practices
2. **AI-Assisted Engineering**: Entire build process documented as AI-augmented learning case study
3. **Production Mindset**: Not toy examples—real services, real constraints, real decisions
4. **Complete Narrative**: From brainstorming to running cluster, end-to-end documentation
5. **Dual Purpose**: Learning platform AND functional home infrastructure

---

## Target Users

### Primary User: Tom (Builder/Operator)

**Profile:** Senior technical professional (10+ years IVI/Navigation) transitioning to Platform Engineering. Learns by building real infrastructure, not following tutorials.

**Goals:**
- Master Kubernetes operations through hands-on practice
- Run real workloads (AI inference, dev proxies, observability)
- Build confidence to explain any infrastructure component in interviews

**Pain Points:**
- Conceptual knowledge of distributed systems lacks K8s operational proof
- PM title doesn't signal hands-on infrastructure capability
- Tutorials feel too basic for experienced engineers

**Success Criteria:**
- Fully operational K3s cluster with production patterns
- Can confidently answer deep technical questions about the setup
- Portfolio generates inbound recruiter interest

### Primary User: Tom (Career Showcaser)

**Profile:** Active job seeker targeting Senior Platform Engineer / MLOps roles at SDV companies or cloud-native organizations.

**Goals:**
- Stand out from certification-only candidates
- Demonstrate unique automotive → cloud-native angle
- Build public visibility to attract recruiters

**Interaction Pattern:**
- Curates technical content (GitHub, blog, LinkedIn)
- Documents AI-assisted methodology as differentiator
- Shares journey posts to build following

### Secondary Users: Portfolio Audience

**Hiring Managers / Engineering Leads:**
- Seeking proof of capability, not just credentials
- Impressed by production-grade thinking and documented decisions
- Value unique domain bridge (automotive → K8s)

**Technical Interviewers:**
- Probe architecture decisions and trade-offs
- Want to see "I chose X over Y because..." reasoning
- Validate depth through ADRs and technical writing

**Tech Community / Recruiters:**
- Discover via LinkedIn, dev.to, GitHub
- Attracted to authentic career transition narrative
- AI-assisted engineering angle provides content hook

### User Journey

**Discovery:** LinkedIn post or blog article catches attention ("Automotive PM building production K8s with AI")

**Engagement:** Clicks through to GitHub repository or technical blog

**Evaluation:** Reviews architecture decisions, sees production-grade setup, reads AI methodology

**Outcome:**
- Hiring Manager → "Let's interview this candidate"
- Recruiter → "Adding to Platform Engineering pipeline"
- Community → "Following for more content"

---

## Success Metrics

### Infrastructure Success (Builder/Operator)

| Metric | Target | Measurement |
|--------|--------|-------------|
| Cluster uptime | 95%+ | Prometheus alerts |
| Services running | All planned services deployed | kubectl get pods |
| GPU workloads operational | Ollama/vLLM responding | API health checks |
| Storage reliability | No data loss | NFS mount status |

### Learning Success

| Metric | Target | Measurement |
|--------|--------|-------------|
| Component explanation confidence | 100% of infrastructure | Self-assessment / mock interviews |
| Independent troubleshooting | Resolve issues without tutorials | Real incident tracking |
| CKA certification | Pass | Exam result |
| Implementation pace | 1 topic per weekend | Phase completion tracking |

### Career Success (Primary Objective)

| Metric | Target | Measurement |
|--------|--------|-------------|
| Inbound recruiter interest | 2+ messages/month mentioning portfolio | LinkedIn inbox |
| Interview requests | Job offer within 6 months | Application tracking |
| Interview confidence | Fluent architecture discussion | Self-assessment |
| Salary achievement | Senior Platform Engineer range ($180K-$250K or equivalent) | Offer letter |

### Content/Visibility Success

| Metric | Target | Measurement |
|--------|--------|-------------|
| GitHub repository stars | 50+ | GitHub stats |
| Blog post reach | 500+ views per post | Analytics |
| LinkedIn engagement | 50+ reactions per post | LinkedIn stats |
| Follower growth | 500+ new followers | LinkedIn/dev.to tracking |

### Key Performance Indicators (KPIs)

**Leading Indicators (predict success):**
- Weekly GitHub commits (shows active development)
- Content publishing cadence (1-2 posts per month)
- LinkedIn profile views trend (shows visibility growth)

**Lagging Indicators (confirm success):**
- Job offer received
- "Saw your home-lab project" in recruiter message
- Interview questions based on portfolio content

### North Star Metric

**Primary success indicator:** Receiving a job offer for Senior Platform Engineer / MLOps role where the interviewer references the home-lab portfolio as a deciding factor.

---

## MVP Scope

### Core Features

**Infrastructure Layer:**

| Component | Scope | Priority |
|-----------|-------|----------|
| K3s Cluster | Control plane + 2 workers (VMs) | P0 |
| NFS Storage | Synology integration, PVCs | P0 |
| Traefik | Ingress + HTTPS + cert-manager | P0 |
| MetalLB | Load balancer for bare metal | P0 |
| Rancher | Cluster management UI | P1 |

**Observability Layer:**

| Component | Scope | Priority |
|-----------|-------|----------|
| Prometheus | Metrics collection | P0 |
| Grafana | Dashboards, visualization | P0 |
| Loki | Log aggregation | P2 |

**Data Layer:**

| Component | Scope | Priority |
|-----------|-------|----------|
| PostgreSQL | StatefulSet, NFS-backed | P1 |

**AI/ML Layer:**

| Component | Scope | Priority |
|-----------|-------|----------|
| GPU Worker | NUC + RTX 3060 (when acquired) | P1 |
| NVIDIA Operator | GPU scheduling | P1 |
| Ollama | LLM inference | P1 |
| vLLM | Production inference server | P2 |
| n8n | Workflow automation | P1 |

**Dev Tooling:**

| Component | Scope | Priority |
|-----------|-------|----------|
| Nginx | Reverse proxy → local dev servers | P1 |
| Renovate/Keel | Auto-updates | P2 |

**Content/Portfolio:**

| Component | Scope | Priority |
|-----------|-------|----------|
| GitHub Repo | Structured, documented, public | P0 |
| First Blog Post | AI-assisted methodology article | P0 |
| ADRs | Architecture decision records | P1 |

### Out of Scope for MVP

| Item | Reason |
|------|--------|
| GitOps (ArgoCD/Flux) | Learn kubectl/Helm first, add as enhancement |
| Service Mesh (Istio/Linkerd) | Overkill for home lab, future exploration |
| Self-hosted blog platform | Use dev.to/Medium first, self-host later |
| HA control plane | Single master sufficient for learning |
| Distributed storage (Longhorn/Rook) | NFS simpler, Synology handles redundancy |

### MVP Success Criteria

The MVP is complete when:

- [ ] K3s cluster running with control plane + 2 workers
- [ ] All planned services deployed and healthy
- [ ] Observability stack showing real metrics
- [ ] PostgreSQL running as StatefulSet with NFS persistence
- [ ] At least one AI workload (Ollama) responding
- [ ] Nginx proxying to local dev servers
- [ ] First blog post published
- [ ] GitHub repo public and documented

### Future Vision

**Post-MVP Enhancements:**

| Phase | Enhancement | Value Add |
|-------|-------------|-----------|
| GitOps | ArgoCD/Flux integration | Declarative deployments, audit trail |
| Advanced ML | vLLM optimization, RAG pipelines | Production-grade AI inference |
| Self-hosted Blog | Hugo/Astro on cluster | Portfolio meta-demonstration |
| CI/CD | GitHub Actions + cluster runners | Full DevOps pipeline |
| Service Mesh | Istio/Linkerd exploration | Advanced networking patterns |

**Long-term Vision (12+ months):**

- Complete CKA + CKS certification with hands-on cluster as study platform
- Published case study: "Building Production-Grade Infrastructure with AI-Assisted Engineering"
- Recognized portfolio leading to Senior Platform Engineer / MLOps role
- Community following from authentic career transition content
- Home lab as ongoing experimentation platform for emerging technologies

