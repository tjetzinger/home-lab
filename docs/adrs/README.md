# Architecture Decision Records (ADRs)

This directory contains Architecture Decision Records (ADRs) documenting significant architectural and operational decisions made during the home-lab K3s platform development.

## What is an ADR?

An Architecture Decision Record captures an important architectural decision made along with its context and consequences. ADRs provide:

- **Context** - Why the decision was needed
- **Options considered** - What alternatives were evaluated
- **Decision rationale** - Why we chose this option over others
- **Trade-offs** - Positive and negative consequences of the decision
- **Implementation guidance** - How to apply the decision

ADRs are immutable once accepted. If a decision changes, a new ADR supersedes the old one.

## ADR Index

### Core Architectural Decisions (Phase 1)

These ADRs document foundational architectural choices that shape the entire platform:

| ADR | Title | Description | Status |
|-----|-------|-------------|--------|
| [ADR-001](ADR-001-lxc-containers-for-k3s.md) | LXC Containers for K3s Nodes | Use LXC containers instead of QEMU VMs for K3s nodes (resource efficiency, faster provisioning) | Accepted |
| [ADR-002](ADR-002-nfs-over-longhorn.md) | External NFS Storage over Longhorn | Use Synology NFS for persistent storage instead of Longhorn distributed storage (operational simplicity, existing hardware) | Accepted |
| [ADR-003](ADR-003-traefik-ingress.md) | Traefik Ingress Controller (K3s Bundled) | Use K3s bundled Traefik instead of nginx-ingress or Istio (zero installation, cert-manager integration) | Accepted |
| [ADR-004](ADR-004-kube-prometheus-stack.md) | kube-prometheus-stack for Observability | Use all-in-one kube-prometheus-stack instead of individual components (pre-integrated, production-ready dashboards) | Accepted |
| [ADR-005](ADR-005-manual-helm-over-gitops.md) | Manual Helm Deployment over GitOps (Phase 1) | Use manual `helm upgrade` and `kubectl apply` instead of ArgoCD/Flux (learning-first approach, simpler troubleshooting) | Accepted |

### Operational Decisions (Implementation & Maintenance)

These ADRs document operational decisions made during implementation and ongoing maintenance:

| ADR | Title | Description | Status |
|-----|-------|-------------|--------|
| [ADR-008](ADR-008-fix-k3s-prometheus-alerts.md) | Fix K3s Prometheus Alerts | Suppress false-positive K3s component alerts (etcd, kube-controller-manager, kube-scheduler not running as pods in K3s) | Accepted |
| [ADR-009](ADR-009-k3s-svclb-monitoring.md) | K3s SVCLB Monitoring | Handle K3s ServiceLB (svclb) pod metrics and alerting (daemonset pods for MetalLB load balancing) | Accepted |
| [ADR-010](ADR-010-k3s-sqlite-to-etcd-migration.md) | K3s SQLite to etcd Migration | Migrate K3s datastore from SQLite to etcd for production-grade high availability and backup capabilities | Accepted |

## ADR Lifecycle

### Status Definitions

- **Proposed** - Decision under consideration, not yet implemented
- **Accepted** - Decision approved and implemented
- **Deprecated** - Decision no longer recommended but still in use
- **Superseded** - Decision replaced by a newer ADR (links to successor)

### When to Create an ADR

Create an ADR when making decisions that:
- Affect the overall architecture or system structure
- Introduce new technologies or frameworks
- Change deployment or operational patterns
- Impact security, performance, or reliability
- Require significant effort to reverse

Examples:
- ✅ Choosing between K3s and vanilla Kubernetes
- ✅ Selecting Traefik over nginx-ingress
- ✅ Deciding storage strategy (NFS vs Longhorn)
- ❌ Updating a ConfigMap value
- ❌ Adding a new application (unless it introduces new patterns)

## How to Add a New ADR

### 1. Determine ADR Number

Find the next available ADR number by checking this index. Numbers are sequential but may have gaps (e.g., ADR-001, ADR-002, ADR-008).

### 2. Create ADR File

Create a new file: `ADR-{NNN}-{short-title}.md`

**Naming conventions:**
- Use three-digit zero-padded number (e.g., ADR-011, not ADR-11)
- Use kebab-case for title (e.g., `nfs-over-longhorn`, not `NFS_Over_Longhorn`)
- Keep title short and descriptive (3-6 words)

### 3. Use the ADR Template

Copy the structure from [ADR-001](ADR-001-lxc-containers-for-k3s.md) as a template:

```markdown
# ADR-{NNN}: {Title}

**Status:** Accepted | Proposed | Deprecated | Superseded by ADR-XXX
**Date:** YYYY-MM-DD
**Decision Makers:** Tom, Claude (AI Assistant)

## Context

[Why this decision was needed, background, constraints]

## Decision Drivers

- Driver 1
- Driver 2

## Considered Options

### Option 1: {Name}
**Pros:**
- Pro 1
**Cons:**
- Con 1

### Option 2: {Name} (Selected)
**Pros:**
- Pro 1
**Cons:**
- Con 1

## Decision

[Clear statement of what was chosen and implementation approach]

## Consequences

### Positive
- Positive outcome 1

### Negative
- Negative outcome 1

### Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Risk 1 | Mitigation 1 |

## Implementation Notes

[Code examples, configuration, deployment commands]

## References

[Links to related documentation, stories, external resources]
```

### 4. Key Principles

**Context is Critical:**
- Explain WHY the decision was needed
- Describe constraints and requirements that shaped the decision
- Provide enough background that someone unfamiliar can understand the problem

**Evaluate Alternatives:**
- Document all options seriously considered (2-4 options typical)
- Include pros/cons for EACH option (even rejected ones)
- Show trade-off analysis: "I traded X for Y because..."

**Consequences Matter:**
- Document both positive AND negative outcomes
- Identify risks with concrete mitigation strategies
- Be honest about limitations of the chosen approach

**Implementation Guidance:**
- Include code examples, configuration snippets, deployment commands
- Reference related stories, runbooks, or documentation
- Provide clear "next steps" for someone implementing the decision

### 5. Update This Index

Add the new ADR to the appropriate table above:
- **Core Architectural Decisions** - Foundational platform choices
- **Operational Decisions** - Implementation or maintenance decisions

### 6. Commit to Git

```bash
git add docs/adrs/ADR-{NNN}-{title}.md docs/adrs/README.md
git commit -m "Add ADR-{NNN}: {Title}"
git push
```

## Portfolio Context

These ADRs serve dual purposes:

1. **Operational documentation** - Capturing decisions for future reference and onboarding
2. **Career portfolio** - Demonstrating engineering judgment, trade-off analysis, and decision-making skills

For portfolio purposes, ADRs show:
- Systematic decision-making process ("I considered X, Y, Z and chose Y because...")
- Trade-off awareness (acknowledging cons of chosen solution)
- Risk management (identifying and mitigating potential issues)
- Production thinking (references to NFRs, scalability, operational concerns)

**For technical interviewers:**
Reading these ADRs shows how the author approaches architectural decisions, evaluates alternatives, and balances competing concerns - critical skills for senior engineering roles.

## References

- [Architecture Decision Document](../planning-artifacts/architecture.md) - Complete system architecture
- [Product Requirements (PRD)](../planning-artifacts/prd.md) - Requirements driving architectural decisions
- [Epics & Stories](../planning-artifacts/epics.md) - Implementation breakdown
- [Michael Nygard's ADR Process](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions) - Original ADR methodology
