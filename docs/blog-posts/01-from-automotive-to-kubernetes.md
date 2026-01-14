# From Automotive Software to Kubernetes: Building a Production-Grade K3s Home Lab

**Published:** [TBD - awaiting dev.to publication]
**Author:** Thomas Jetzinger
**Reading Time:** ~10 minutes
**Word Count:** ~2,180 words

---

After a decade managing cloud-based automotive programs—starting as a Technical Program Manager for vehicle data platforms and navigation systems, then advancing to organizational-level program management—I found myself debugging Kubernetes pod crashes at 2am. The irony? The distributed systems challenges felt remarkably familiar.

Career transitions in tech are rarely about learning new concepts—most patterns transfer between domains. The challenge is proving capability without years of titles. After years managing teams and programs, I needed hands-on proof. Tutorials don't demonstrate operational capability. Running real infrastructure does.

This post is written for hiring managers evaluating career transitions, technical interviewers assessing platform engineering capabilities, and fellow career changers looking for transparent learning paths.

This isn't a tutorial completion with empty dashboards. My cluster runs PostgreSQL, Ollama for LLM inference, n8n workflow automation, and Nginx—24/7, with real metrics and actual workload data. The infrastructure was built using AI-assisted development with the BMAD framework (PRD → Architecture → Planning → Implementation), not ad-hoc prompting. And it follows production practices: comprehensive monitoring, mobile P1 alerts, and tested backup/restore procedures.

I'll share the technical decisions, what worked (and what didn't), how I used AI systematically to build production-grade infrastructure, and why automotive program management translates better to platform engineering than you'd think.

---

## Technical Approach

### Cluster Architecture

I chose LXC containers over full VMs for performance—they share the host kernel, eliminating hypervisor overhead. ADR-001 documents the trade-off: accept slightly reduced isolation for near-native performance. When you're learning Kubernetes on modest hardware, efficiency matters.

The cluster runs K3s v1.34.3 across three nodes: k3s-master (control plane) and two workers (k3s-worker-01/02). I chose K3s over full Kubernetes for several reasons: it's lightweight, ships as a single binary for easier management, includes Traefik by default (reducing complexity), and has strong industry adoption for edge and IoT deployments—patterns familiar from automotive systems.

Network configuration uses MetalLB in Layer 2 mode with an IP pool of 192.168.2.100-120, providing LoadBalancer services on the private 192.168.2.0/24 subnet. All external access routes through Tailscale VPN—no public internet exposure, security-first from day one.

### Storage Solution

Every platform engineer asks: "Why external NFS instead of Longhorn?" The answer is pragmatic: I already had a Synology DS920+ with 8.8TB of usable capacity configured in SHR (Synology Hybrid RAID). Why add operational complexity when I have production-grade storage sitting on the network?

The Synology runs hourly snapshots for disaster recovery and provides persistent storage via NFS to the cluster. I deployed nfs-subdir-external-provisioner via Helm, creating a StorageClass that automatically provisions PersistentVolumes for application claims. This setup taught me storage class configuration, NFS provisioner architecture, and the trade-offs between external and in-cluster storage solutions.

ADR-002 documents the decision: leveraging existing infrastructure over distributed storage systems like Longhorn. The learning goal was Kubernetes storage concepts, not managing Ceph or distributed filesystems. Sometimes the best engineering decision is knowing what NOT to build.

### Networking & Ingress

K3s bundles Traefik as the default ingress controller, and I saw no reason to replace it. The pragmatic choice turned into a learning opportunity—Traefik's IngressRoute CRDs taught me custom resource patterns beyond basic Ingress objects.

MetalLB provides LoadBalancer services in Layer 2 mode with an IP pool of 192.168.2.100-120 on my private subnet. DNS rewrites via NextDNS point `*.home.jetzinger.com` to the MetalLB IP, routing traffic through Traefik to the appropriate services.

The biggest surprise? cert-manager + Let's Encrypt integration was effortless. I expected TLS certificate management to be painful—manual renewals, complex automation, DNS-01 challenges. Reality: cert-manager handles everything automatically. Define a ClusterIssuer, add an annotation to your Ingress, and valid HTTPS certificates appear. Some Kubernetes ecosystem tools genuinely "just work."

### Observability Stack

I deployed the observability stack early using kube-prometheus-stack, a Helm chart that bundles Prometheus, Grafana, Alertmanager, and supporting components. The deployment was straightforward—the real work was configuring it for production operations.

Prometheus scrapes metrics from all workloads with 7-day retention, Loki aggregates logs centrally, and Alertmanager routes P1 alerts to my mobile phone via ntfy.sh. I didn't just install monitoring tools—I tested the alert pipeline, configured retention policies, and validated backup procedures. The Grafana screenshots in [docs/VISUAL_TOUR.md](https://github.com/tjetzinger/home-lab/blob/master/docs/VISUAL_TOUR.md) show real metrics from running workloads, not empty tutorial dashboards.

This is production thinking: monitoring isn't decoration, it's operational readiness. When PostgreSQL runs out of disk space at 2am, I want an alert on my phone, not a surprise the next morning.

### Workloads

The cluster runs real services, not hello-world demos:

- **PostgreSQL** (Bitnami Helm): Persistent storage for n8n, backed by NFS with tested pg_dump backup procedures
- **Ollama** (llama3.2:1b, CPU mode): LLM inference for workflow automation and project work
- **n8n**: Workflow automation with PostgreSQL backend, integrated with Ollama for AI-enhanced workflows
- **Nginx**: Reverse proxy for local development with hot-reload configuration

These workloads run 24/7 because they serve actual use cases. The Grafana dashboards show resource consumption from services under load, not idle pods waiting for tutorial steps. This is the difference between a portfolio project and production infrastructure: one demonstrates capability, the other proves it.

### AI-Assisted Development

This project was built using the BMAD framework with Claude Code—a systematic 4-phase approach that prevents common AI pitfalls. Phase 1 defines requirements in a PRD with user stories. Phase 2 documents architecture decisions in ADRs, capturing trade-offs before implementation. Phase 3 creates detailed epics and stories with gap analysis to prevent duplicate code. Phase 4 executes implementation with adversarial code review as a quality gate.

The systematic methodology makes the difference. When implementing PostgreSQL (Story 5.1), the code review workflow's explicit security checklist caught that the database service was exposed without a NetworkPolicy—a production security vulnerability I would have missed with ad-hoc prompting. Gap analysis ensures Claude Code reads existing architecture decisions before suggesting solutions, preventing conflicts with documented ADRs.

AI-assisted doesn't mean AI-generated. Claude Code follows my architecture, validates against my codebase, and catches mistakes I would make manually. The framework is the multiplier—it turns AI from a code generator into a systematic development partner.

---

## Key Learnings

Building production-grade infrastructure taught me lessons that tutorials never could. Some decisions proved brilliant. Others I'd change immediately. Here's what worked, what didn't, and what genuinely surprised me.

### What Worked

**K3s was the right choice.** Lightweight distribution with bundled Traefik reduced complexity without sacrificing Kubernetes learning. Resource efficiency meant running production workloads on modest hardware—no cloud bill, no performance compromises.

**AI pair programming accelerated learning dramatically.** The BMAD framework provided systematic structure while Claude Code maintained context across long implementation sessions. Quality gates like gap analysis and code review caught mistakes. What would have taken months took days—not because AI wrote all the code, but because the methodology prevented detours and dead ends.

**Deploying observability first enabled faster debugging.** Prometheus, Grafana, and Loki were installed early, before application workloads. When PostgreSQL issues appeared, I had metrics and logs immediately. Debugging without observability is guesswork; debugging with it is systematic.

**Documentation-first approach pays dividends.** Writing ADRs before implementation forced clarity on trade-offs. Runbooks proved I understood operations, not just deployment. The README became a portfolio narrative, and GitHub became evidence for hiring managers. Documentation isn't overhead—it's the product.

**Version control everything, even Helm values.** Git as single source of truth enables reproducible deployments and infrastructure as code. Mistakes committed to git become learning documentation. Current challenge: credential management (working on sealed-secrets solution).

### What Didn't Work

**Credential management should have been day one.** I'm currently using plain Kubernetes secrets—storing passwords as base64-encoded values in the cluster. This works, but it's not production-grade. Sealed Secrets or external secret management (like HashiCorp Vault) should have been implemented from the start, not retrofitted later.

The mistake wasn't technical—it was prioritization. I told myself "I'll add proper secret management later" and focused on getting workloads running. Retrofitting security is always harder than building it in. The lesson: some infrastructure decisions can't be deferred. Authentication, secrets management, and network policies are foundational, not features.

Why share this? Because mistakes demonstrate experience. Knowing what to do differently next time is wisdom. Perfect portfolios are suspicious—real infrastructure engineers have learned from production incidents and architectural regrets.

### Surprises

**The Kubernetes ecosystem tooling is genuinely excellent.** I expected fragmented documentation, complex Helm charts, and endless troubleshooting. Reality: kube-prometheus-stack deployed in minutes with comprehensive defaults. Bitnami's PostgreSQL chart had production-ready configurations out of the box. The documentation quality rivals mature commercial platforms. Open source infrastructure has matured significantly.

**Traefik IngressRoute CRDs teach advanced patterns.** I expected nginx-ingress to be "the standard" and Traefik to be second-tier. Reality: Traefik's CRD-based IngressRoute model teaches Kubernetes extension patterns that translate to other operators and controllers. Sometimes non-standard choices accelerate learning—not despite being different, but because of it.

**Resource constraints drive better design.** I expected unlimited cloud resources would accelerate learning. Reality: running 15+ services on nodes with 4-8GB RAM forces thoughtful resource allocation, pod prioritization, and workload optimization. Constraints breed operational discipline. Home lab limitations are features, not bugs.

---

## How Automotive Experience Translates

The hiring manager question is inevitable: "You've been in automotive for a decade—why should we believe you can do platform engineering?" Fair question. Here's why the skills transfer better than the titles suggest.

### Architecture Thinking

Navigation systems can't have downtime—drivers depend on them. That requirement taught me high-availability thinking: redundancy, health checks, graceful degradation. Kubernetes workloads face identical constraints. The patterns transfer directly: replica sets, liveness probes, rolling updates.

Vehicle data platforms process telemetry streams from millions of vehicles in real-time. Kubernetes orchestrates distributed workloads with the same architectural patterns: event-driven processing, distributed state management, resource allocation under constraints. The scale differs, but the problem domain is identical.

Designing backend APIs to coordinate location data across mobile clients, vehicle systems, and cloud services is platform engineering. Kubernetes service meshes solve the same challenges: routing, load balancing, service discovery. I was doing distributed systems architecture in automotive—I just didn't call it cloud-native infrastructure.

### Reliability Focus

Automotive program management taught me risk-thinking at scale. ASPICE quality frameworks and SLA commitments don't allow "we'll fix it later"—you identify failure modes, quantify risk, and build mitigation before deployment. Platform engineering demands the same discipline. Kubernetes cluster failures affect real workloads; automotive system failures affect real vehicles. The consequence severity differs, but the risk management mindset is identical.

Monitoring isn't optional—it's operational validation. In automotive, telemetry proves deployed systems function correctly across millions of vehicles. In Kubernetes, observability proves distributed workloads operate within parameters. Prometheus scraping metrics, Grafana visualizing trends, Alertmanager routing P1 alerts—these are the same validation patterns I used for vehicle data platforms, just applied to containers instead of cars.

### Documentation Discipline

Program management in automotive demands systematic documentation: requirements with rationale, risk registers, trade-off analysis, program status tracking. ASPICE compliance isn't bureaucracy—it's ensuring decisions are defensible, traceable, and transferable when team members change. This discipline translates perfectly to ADRs in Kubernetes.

Architecture Decision Records capture the same systematic thinking: document WHY a decision was made, evaluate alternatives, record trade-offs, preserve context for future maintainers. ADR-002 explains why I chose external NFS over Longhorn—not to justify perfection, but to show I evaluated options and understood consequences. The format changes (program docs → markdown files), but the rigor is identical.

Why do hiring managers care? It demonstrates transferable skills beyond domain knowledge. Systematic decision-making, operational maturity, and documentation discipline aren't automotive-specific—they're engineering fundamentals. A PM who documents risks and trade-offs can architect infrastructure the same way.

---

## Let's Connect

Making a career transition? **Let's talk.** Connect with me on [LinkedIn](https://www.linkedin.com/in/tjetzinger/) for career transition discussions and platform engineering insights. I'm actively networking with hiring managers, technical interviewers, and fellow engineers navigating the automotive → cloud-native journey.

Want to see the code? The full project lives on [GitHub](https://github.com/tjetzinger/home-lab). Browse the implementation, review the Architecture Decision Records, or check out the [Visual Tour](https://github.com/tjetzinger/home-lab/blob/master/docs/VISUAL_TOUR.md) for Grafana screenshots showing real operational metrics. If this helps your own journey, star the repo.

**This is post 1 of a series.** Upcoming deep dives:
- Why I Chose External NFS Over Longhorn (ADR-002 expansion)
- AI-Assisted Infrastructure: What Worked and What Didn't
- From Manual Helm to GitOps: Planning the Next Phase
- Kubernetes Backup & Restore: Testing Your Runbooks Before You Need Them

For technical discussion, I'm on Reddit: **r/kubernetes**, **r/homelab**, **r/devops**. Questions, feedback, and corrections welcome—let's learn together.

---

**Related Documentation:**
- [GitHub Repository](https://github.com/tjetzinger/home-lab)
- [Visual Tour (Grafana Screenshots)](https://github.com/tjetzinger/home-lab/blob/master/docs/VISUAL_TOUR.md)
- [Architecture Decision Records](https://github.com/tjetzinger/home-lab/tree/master/docs/adrs)
- [Project README](https://github.com/tjetzinger/home-lab/blob/master/README.md)
