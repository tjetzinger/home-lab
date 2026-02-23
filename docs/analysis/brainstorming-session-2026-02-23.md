---
stepsCompleted: [1, 2, 3, 4]
inputDocuments: []
session_topic: 'Self-hosting Supabase on K3s cluster to replace supabase.com for dev container pods'
session_goals: 'Deploy cluster-local Supabase with Auth, Realtime, Database, Storage, and Edge Functions for dev container backends'
selected_approach: 'ai-recommended'
techniques_used: ['Morphological Analysis', 'Constraint Mapping', 'Chaos Engineering']
ideas_generated: ['Supabase-bundled PostgreSQL', 'backend namespace', 'Full GoTrue with Resend SMTP', 'NFS storage for PostgreSQL and files', 'Realtime disabled for v1', 'Full Deno Edge Functions', 'Co-locate on worker-01', 'Worker-01 RAM 16Gi to 24Gi', 'Per-service subdomains with wildcard cert', 'Hybrid Helm strategy', 'dnsPolicy None for external access pods', 'Pin Helm chart version', 'Edge Functions resource limits 128Mi/256Mi', 'Migrate calsync then pilates']
session_active: false
workflow_completed: true
context_file: ''
---

# Brainstorming Session Results

**Facilitator:** Tom
**Date:** 2026-02-23

## Session Overview

**Topic:** Self-hosting Supabase on K3s cluster to replace supabase.com for dev container pods
**Goals:** Deploy cluster-local Supabase with full feature parity — Auth, Database, Storage, and Edge Functions — so dev containers can use a cluster-local backend instead of the external supabase.com service. Realtime deferred to v2.

### Session Setup

- Dev container pods already exist in the `dev` namespace
- Currently using supabase.com (hosted) as their backend
- Target: self-hosted Supabase within K3s with core services (Auth/GoTrue, PostgreSQL, Storage, Edge Functions)
- Existing PostgreSQL infrastructure in `data` namespace kept separate — Supabase gets its own bundled instance
- Cluster has NFS storage via Synology and local-path provisioner available

## Technique Selection

**Approach:** AI-Recommended Techniques
**Analysis Context:** Self-hosting Supabase on K3s with focus on full feature parity for dev container backends

**Recommended Techniques:**

- **Morphological Analysis:** Systematically map all deployment parameters and options for each Supabase component
- **Constraint Mapping:** Ground options against real cluster constraints (RAM, storage, existing infra, networking)
- **Chaos Engineering:** Stress-test the proposed architecture to surface failure modes and build resilience

**AI Rationale:** Complex multi-component infrastructure deployment benefits from systematic parameter exploration (Morphological), reality-grounding (Constraints), and resilience validation (Chaos) — covering the full spectrum from ideation to battle-testing.

## Technique Execution Results

### Morphological Analysis

**Interactive Focus:** Systematic parameter-by-parameter decision making across 9 deployment dimensions.

**Parameter Decisions:**

| # | Parameter | Decision | Rationale |
|---|-----------|----------|-----------|
| 1 | PostgreSQL | Supabase-bundled | Full isolation — own extensions, migrations, lifecycle. No risk to existing workloads. |
| 2 | Namespace | New `backend` namespace | Clean separation, room for future backend services beyond Supabase. |
| 3 | Auth (GoTrue) | Full deployment | Complete feature parity with supabase.com — no dev container code changes needed. |
| 4 | Storage Backend | NFS (Synology) | Durability for both PostgreSQL data and file uploads. Survives node failure. |
| 5 | Realtime | Disabled | Lean v1. Not currently used by dev containers. Easy to add later. |
| 6 | Edge Functions | Full Deno runtime | Serverless capability in-cluster. Tight resource limits to contain blast radius. |
| 7 | Node Placement | Co-locate with dev containers (worker-01) | Minimal network latency between consumer and backend. RAM upgrade makes it feasible. |
| 8 | Ingress | Per-service subdomains | `*.supabase.home.jetzinger.com` — explicit routing, follows existing cluster patterns. |
| 9 | Helm Strategy | Hybrid (chart + overrides) | Official chart for heavy lifting, custom overrides for DNS policy, affinity, resource limits. |

**Key Insight:** Choosing Supabase-bundled PostgreSQL (vs reusing existing) was the pivotal decision — it unlocked clean isolation but required NFS for durability and a RAM upgrade for capacity.

### Constraint Mapping

**Interactive Focus:** Grounding architectural decisions against real cluster constraints.

**Constraints Resolved:**

| # | Constraint | Resolution |
|---|-----------|------------|
| 1 | DNS & Networking | `dnsPolicy: None` on GoTrue, Edge Functions, Kong — proven fix for `*.jetzinger.com` wildcard interception |
| 2 | Storage & Persistence | NFS (Synology) for PostgreSQL and file storage — survives node failure |
| 3 | Resource Limits | Worker-01 RAM upgrade from 16Gi → 24Gi in Proxmox (39Gi available on host) |
| 4 | Secrets Management | Existing pattern — placeholder YAML in `secrets/`, real values via `kubectl patch`, never committed |
| 5 | Ingress & TLS | Wildcard cert `*.supabase.home.jetzinger.com` via cert-manager + 5 IngressRoutes |
| 6 | Dev Container Migration | 2 containers (calsync, pilates) — update 3 env vars each, re-seed schemas |
| 7 | Backup & Recovery | Skip for now — re-seed if needed, add pg_dump cronjob later |

**Additional Decisions:**
- **SMTP:** Resend via SMTP relay for GoTrue email confirmations (free tier, 100 emails/day)
- **Email links:** Auth confirmation URLs only reachable via Tailnet (acceptable for dev)

**Key Insight:** The wildcard DNS interception issue (`*.jetzinger.com`) is the most critical constraint — it affects every Supabase pod that makes external calls. The proven `dnsPolicy: None` fix must be applied via Helm overrides.

### Chaos Engineering

**Interactive Focus:** Stress-testing the proposed architecture against failure scenarios.

**Failure Scenarios Tested:**

| # | Scenario | Verdict | Mitigation |
|---|----------|---------|------------|
| 1 | Worker-01 reboots | Accepted | Auto-recovery via kubelet. Pods crashloop until PostgreSQL ready — acceptable for dev. NFS data intact. |
| 2 | NFS (Synology) offline | Accepted | Same risk tolerance as existing NFS workloads (Paperless, etc.). Cluster-wide event, not Supabase-specific. |
| 3 | JWT secret rotation/leak | Accepted | Rotation requires updating 3 places (Supabase secret + calsync + pilates configs). Leak risk low due to Tailscale-only access. |
| 4 | Edge Functions OOM | Mitigated | Resource limits: 128Mi request / 256Mi limit. Isolated blast radius, automatic restart. |
| 5 | Helm chart upgrade breaks things | Mitigated | Pin chart version explicitly. Always `helm diff` before upgrading. NFS data survives PVC recreation. |

**Key Insight:** No critical vulnerabilities found. The architecture is resilient enough for a dev environment. The main operational awareness item is JWT rotation requiring coordinated updates across 3 configs.

### Creative Facilitation Narrative

This session took a methodical infrastructure challenge and systematically decomposed it through three complementary lenses. Morphological Analysis mapped the full decision space (9 parameters × 3 options each = 19,683 theoretical combinations), then constraint mapping grounded those decisions against reality, and chaos engineering validated the final architecture won't fall over in practice. The progression from divergent exploration to convergent validation produced a deployment blueprint that's both comprehensive and pragmatic.

### Session Highlights

**Creative Strengths:** Pragmatic decision-making — consistently chose the simplest viable option (disable Realtime, skip backups, accept crashloops) while investing complexity only where it matters (NFS for durability, DNS policy overrides, RAM upgrade).
**Breakthrough Moments:** Recognizing that reusing existing PostgreSQL would require swapping the image to `supabase/postgres` across all workloads — making "bundled" the cleaner isolation choice despite the resource cost.
**Energy Flow:** Steady and focused throughout — parameter-by-parameter decisions kept momentum without decision fatigue.

## Idea Organization and Prioritization

### Thematic Organization

**Theme 1: Core Architecture**
- Supabase-bundled PostgreSQL with full isolation
- New `backend` namespace for clean separation
- Hybrid Helm strategy (official chart + custom overrides)

**Theme 2: Component Selection**
- Full GoTrue auth with Resend SMTP relay
- Full Deno Edge Functions with tight resource limits
- Realtime disabled for lean v1

**Theme 3: Infrastructure & Placement**
- Co-locate all Supabase pods on worker-01 with dev containers
- Worker-01 RAM upgrade 16Gi → 24Gi (Proxmox has capacity)
- NFS (Synology) for PostgreSQL and file storage durability
- Wildcard cert `*.supabase.home.jetzinger.com` with 5 IngressRoutes

**Theme 4: Operational Resilience**
- `dnsPolicy: None` on GoTrue, Edge Functions, Kong
- Pin Helm chart version + `helm diff` before upgrades
- Edge Functions resource limits (128Mi request / 256Mi limit)
- Crashloop-tolerant startup (no dependency ordering)

**Theme 5: Migration Path**
- 2 containers to migrate: calsync, pilates
- 3 env vars per container: `SUPABASE_URL`, `ANON_KEY`, `SERVICE_ROLE_KEY`
- Schema re-seeding on new instance
- JWT rotation: 3 places to update

### Prioritization Results

**Top Priority (implementation order):**
1. Bump worker-01 RAM to 24Gi in Proxmox
2. Create `backend` namespace + secrets placeholder
3. Deploy Supabase via Helm with hybrid overrides (`dnsPolicy`, node affinity, resource limits)
4. Wildcard cert + 5 IngressRoutes
5. Validate Studio dashboard access
6. Migrate calsync (first guinea pig)
7. Migrate pilates
8. Decommission supabase.com dependency

**Quick Wins:**
- Wildcard cert uses existing cert-manager setup (already has `dnsPolicy` fix)
- Secrets follow existing LiteLLM-style pattern (no new tooling)
- `dnsPolicy: None` is a copy-paste from cert-manager values

**Breakthrough Concepts:**
- `backend` namespace as a general-purpose "backend services for dev containers" layer — Supabase today, potentially more services later
- Hybrid Helm approach gives best of both worlds — chart automation + cluster-specific surgical overrides

### Supabase Service Ingress Map

| Subdomain | Routes to | Purpose |
|-----------|-----------|---------|
| `api.supabase.home.jetzinger.com` | PostgREST | REST API |
| `auth.supabase.home.jetzinger.com` | GoTrue | Authentication |
| `studio.supabase.home.jetzinger.com` | Supabase Studio | Dashboard UI |
| `storage.supabase.home.jetzinger.com` | Storage API | File uploads/downloads |
| `functions.supabase.home.jetzinger.com` | Edge Functions | Deno serverless runtime |

## Session Summary and Insights

**Key Achievements:**
- Complete deployment blueprint for self-hosted Supabase on K3s
- 9 architectural parameters systematically evaluated and locked in
- 7 cluster constraints identified and resolved
- 5 failure scenarios stress-tested with clear mitigations
- 8-step implementation order ready for execution

**Session Reflections:**
The three-technique approach (Morphological → Constraint → Chaos) provided excellent coverage. Morphological Analysis prevented premature decisions by forcing all options onto the table. Constraint Mapping caught the critical DNS interception issue and RAM limitation before they could become deployment blockers. Chaos Engineering confirmed the architecture is appropriately resilient for a dev environment without over-engineering. The result is a pragmatic, well-validated deployment plan.
