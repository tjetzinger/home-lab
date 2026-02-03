# Story 24.3: Document OpenClaw Architecture (ADR & README)

Status: done

## Story

As a **portfolio audience member (hiring manager, recruiter)**,
I want **to read about the OpenClaw AI assistant architecture in the repository documentation**,
So that **I can understand the technical decisions, integration patterns, and AI-assisted engineering approach**.

## Acceptance Criteria

1. **Given** the OpenClaw system is deployed and operational
   **When** I create an ADR documenting OpenClaw architectural decisions
   **Then** the ADR is saved at `docs/adrs/ADR-011-openclaw-personal-ai-assistant.md` following the existing ADR format (FR187)
   **And** the ADR covers: deployment architecture, inverse fallback LLM pattern, outbound-only channel networking, log-based observability pattern, NFS persistence strategy, and security model

2. **Given** the ADR is written
   **When** I update the repository README
   **Then** the README includes an OpenClaw section with architecture overview (FR188)
   **And** the section describes: what OpenClaw is, how it connects to the cluster, LLM routing, messaging channels, and observability approach
   **And** the documentation is navigable by an external reviewer (NFR27)

**FRs covered:** FR187, FR188

## Tasks / Subtasks

- [x] Task 1: Create ADR-011 for OpenClaw Architecture (AC: #1)
  - [x] 1.1 Create `docs/adrs/ADR-011-openclaw-personal-ai-assistant.md` using existing ADR template
  - [x] 1.2 Document deployment architecture section (K8s manifests, namespace, node affinity)
  - [x] 1.3 Document inverse fallback LLM pattern (Opus 4.5 primary → LiteLLM fallback)
  - [x] 1.4 Document outbound-only channel networking (Telegram, Discord - no inbound exposure)
  - [x] 1.5 Document log-based observability pattern (Loki + Blackbox, no native /metrics)
  - [x] 1.6 Document NFS persistence strategy (local PVC for config/workspace)
  - [x] 1.7 Document security model (K8s Secrets, Tailscale-only access, DM allowlists)
  - [x] 1.8 Include decision drivers, alternatives considered, and consequences

- [x] Task 2: Update ADR README Index (AC: #1)
  - [x] 2.1 Add ADR-011 to `docs/adrs/README.md` in appropriate table section
  - [x] 2.2 Classify as "AI Platform Decisions (Phase 5)" category

- [x] Task 3: Add OpenClaw Section to Main README (AC: #2)
  - [x] 3.1 Add "## OpenClaw Personal AI Assistant" section to README.md
  - [x] 3.2 Include architecture diagram showing gateway, channels, LLM routing
  - [x] 3.3 Describe what OpenClaw is and its purpose in the home lab
  - [x] 3.4 Document messaging channels (Telegram, Discord)
  - [x] 3.5 Document LLM routing (Opus 4.5 → LiteLLM three-tier fallback)
  - [x] 3.6 Document observability approach (Grafana dashboard, alerts)
  - [x] 3.7 Add OpenClaw to the "Current Workloads" table

- [x] Task 4: Update Implementation Journey Table (AC: #2)
  - [x] 4.1 Add Epics 21-24 (Phase 5) to the Implementation Journey table in README
  - [x] 4.2 Include brief outcome description for each epic

- [x] Task 5: Validation (All ACs)
  - [x] 5.1 Verify ADR follows existing ADR format (compare with ADR-001 through ADR-010)
  - [x] 5.2 Verify README OpenClaw section is navigable and clear
  - [x] 5.3 Verify all links work and reference correct files
  - [x] 5.4 Verify no sensitive information exposed (secrets, tokens)

## Gap Analysis

**Scan Date:** 2026-02-03

### What Exists
- ✅ 8 ADRs exist: ADR-001 through ADR-005, ADR-008 through ADR-010
- ✅ `docs/adrs/README.md` with two table sections (Core Architectural, Operational)
- ✅ `README.md` with comprehensive sections including ML Inference Stack, Current Workloads table
- ✅ `applications/openclaw/` directory with K8s manifests (deployment, service, ingress, pvc, secret)

### What's Missing
- ❌ `docs/adrs/ADR-011-openclaw-personal-ai-assistant.md` does not exist
- ❌ No OpenClaw section in README.md
- ❌ Implementation Journey table only shows 20 epics (missing 21-24)
- ❌ Current Workloads table missing OpenClaw entry

### Task Changes
- No changes needed - draft tasks accurately reflect codebase state

---

## Dev Notes

### Architecture Context

**OpenClaw Overview:**
OpenClaw is a self-hosted personal AI assistant running on K3s, accessible via messaging channels (Telegram, Discord), powered by Claude Opus 4.5 with automatic LiteLLM fallback to local inference.

**Key Architectural Decisions to Document:**

1. **Deployment Pattern:** Single-pod Kubernetes Deployment in `apps` namespace, pinned to k3s-worker-01 via node affinity (highest resource CPU worker)

2. **Inverse Fallback LLM Pattern:** Unlike typical setups where local models are primary:
   - **Primary:** Claude Opus 4.5 via Anthropic OAuth (frontier reasoning)
   - **Fallback:** LiteLLM proxy (`litellm.ml.svc:4000`) → vLLM GPU → Ollama CPU → OpenAI cloud
   - Rationale: Best reasoning quality primary, graceful degradation for availability

3. **Outbound-Only Channel Networking:** All messaging channels (Telegram, Discord) use long-polling or WebSocket connections initiated from inside the cluster:
   - No inbound exposure required
   - No webhook URLs to manage
   - Simplified security (Tailscale-only access preserved)

4. **Log-Based Observability:** OpenClaw does not expose Prometheus `/metrics`:
   - Promtail collects stdout/stderr → Loki
   - Grafana dashboard with LogQL queries
   - Blackbox Exporter HTTP probes for uptime
   - Pattern proven in Story 24.1, 24.2

5. **Local PVC Persistence:** Config and workspace on local-path storage:
   - `~/.openclaw/` (gateway config)
   - `~/clawd/` (workspace, mcporter, session data)
   - LanceDB memory index with OpenAI embeddings
   - Velero backups for disaster recovery

6. **Security Model:**
   - K8s Secrets for all credentials (9 secret keys)
   - DM allowlist-only pairing for messaging channels
   - Tailscale VPN-only cluster access
   - No public API exposure

### Project Structure Notes

**Files to Create:**
```
docs/adrs/ADR-011-openclaw-personal-ai-assistant.md  # NEW - OpenClaw ADR
```

**Files to Modify:**
```
docs/adrs/README.md  # Add ADR-011 to index
README.md            # Add OpenClaw section, update Implementation Journey
```

**Follow Existing Patterns:**
- ADR format: `docs/adrs/ADR-001-lxc-containers-for-k3s.md` (template)
- README sections: Use similar structure to "ML Inference Stack" section
- Architecture diagrams: ASCII art consistent with existing README diagrams

### Previous Story Intelligence

**From Story 24.2:**
- Blackbox Exporter deployed: `prometheus-blackbox-exporter` Helm release
- Probe target: `http://openclaw.apps.svc.cluster.local:18789` (30s interval)
- Alert rule: `OpenClawGatewayDown` P1 in `custom-rules.yaml`
- Health check: `kubectl exec -n apps deploy/openclaw -c openclaw -- node dist/entry.js health --json`
- OpenClaw Grafana dashboard deployed with LogQL panels

**From Story 24.1:**
- Promtail collecting logs: labels `namespace=apps`, `app_kubernetes_io_name=openclaw`
- Log format: `TIMESTAMP [component] message` (plain text)
- Components: `[gateway]`, `[telegram]`, `[discord]`, `[ws]`, `[openclaw]`, `[canvas]`, `[heartbeat]`, `[browser/service]`
- Dashboard: `monitoring/grafana/dashboards/openclaw-dashboard.yaml`

**From Epic 21-23 Implementation:**
- Deployment: `applications/openclaw/deployment.yaml`
- Service: `applications/openclaw/service.yaml`
- IngressRoute: `applications/openclaw/ingressroute.yaml`
- Secret: `applications/openclaw/secret.yaml`
- PVC: `applications/openclaw/pvc.yaml`

### ADR Content Outline

```markdown
# ADR-011: OpenClaw Personal AI Assistant

**Status:** Accepted
**Date:** 2026-02-03
**Decision Makers:** Tom, Claude (AI Assistant)

## Context
- Home lab needed personal AI assistant capability
- Existing LiteLLM/vLLM stack available for fallback
- Messaging channels preferred over web-only interface

## Decision Drivers
- Frontier reasoning quality (Claude Opus 4.5)
- High availability with graceful degradation
- Security (no public API exposure)
- Operational simplicity (reuse existing observability)

## Considered Options
1. Web-only chat interface (Open-WebUI exists)
2. OpenClaw with local-only LLM
3. OpenClaw with cloud-primary + local fallback (Selected)

## Decision
Deploy OpenClaw gateway with:
- Opus 4.5 as primary LLM
- LiteLLM three-tier fallback
- Telegram + Discord channels
- Log-based observability

## Consequences
[Positive/Negative outcomes, risks]
```

### README OpenClaw Section Outline

```markdown
## OpenClaw Personal AI Assistant

OpenClaw is a self-hosted AI assistant running on the K3s cluster, accessible via
Telegram and Discord. It provides frontier-quality conversational AI with automatic
fallback to local inference when cloud APIs are unavailable.

### Architecture

[ASCII diagram showing:]
- OpenClaw Gateway (apps namespace)
- Channel Connectors (Telegram, Discord)
- LLM Routing (Opus 4.5 → LiteLLM → vLLM/Ollama/OpenAI)
- Observability (Loki, Blackbox)

### Key Features
- **Primary LLM:** Claude Opus 4.5 via Anthropic OAuth
- **Fallback Chain:** LiteLLM → vLLM (GPU) → Ollama (CPU) → OpenAI (cloud)
- **Messaging:** Telegram, Discord with DM allowlist security
- **Memory:** LanceDB with OpenAI embeddings for long-term context
- **Monitoring:** Grafana dashboard, P1 alerts via ntfy.sh

### Accessing OpenClaw
- Control UI: https://openclaw.home.jetzinger.com (Tailscale required)
- Telegram: DM @OpenClawBot (allowlisted users only)
- Discord: Bot in private server

See [ADR-011](docs/adrs/ADR-011-openclaw-personal-ai-assistant.md) for architectural decisions.
```

### References

- [Source: docs/planning-artifacts/architecture.md#OpenClaw Personal AI Assistant Architecture]
- [Source: docs/planning-artifacts/epics.md#Story 24.3]
- [Source: docs/adrs/README.md] - ADR format and index
- [Source: docs/implementation-artifacts/24-1-configure-loki-log-collection-and-grafana-dashboard.md] - Story 24.1 learnings
- [Source: docs/implementation-artifacts/24-2-configure-blackbox-exporter-and-alertmanager-rules.md] - Story 24.2 learnings
- [Source: README.md] - Existing README structure

## Dev Agent Record

### Agent Model Used

Claude Opus 4.5 (claude-opus-4-5-20251101)

### Debug Log References

- Gap analysis completed: 2026-02-03
- All tasks completed in single session

### Completion Notes List

1. **AC #1 Satisfied**: Created `docs/adrs/ADR-011-openclaw-personal-ai-assistant.md` (11KB) documenting all 6 architectural decisions: deployment architecture, inverse fallback LLM pattern, outbound-only channel networking, log-based observability, local PVC persistence, and security model. ADR follows existing format with Context, Decision Drivers, Considered Options, Decision, Consequences, and References sections.

2. **AC #2 Satisfied**: Updated `README.md` with comprehensive OpenClaw section including ASCII architecture diagram, key features table, inverse fallback pattern explanation, and access methods. Added OpenClaw to Current Workloads table and updated Implementation Journey table with Epics 21-24 (Phase 5). Updated header from "20 epics" to "24 epics".

3. **All Validation Passed**: ADR-011 matches existing ADR format (ADR-001 template), README section is navigable with 14 OpenClaw references, all links verified working, no sensitive information exposed.

### Change Log

- 2026-02-03: Gap analysis completed - no task changes needed
- 2026-02-03: Story implementation completed - all tasks done

### File List

**New Files:**
- `docs/adrs/ADR-011-openclaw-personal-ai-assistant.md` - OpenClaw architectural decisions

**Modified Files:**
- `docs/adrs/README.md` - Added ADR-011 to index under new "AI Platform Decisions (Phase 5)" section
- `README.md` - Added OpenClaw section, updated Current Workloads table, updated Implementation Journey table with Epics 21-24, updated status header to 24 epics

