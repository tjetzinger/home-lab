# Story 9.6: Write Comprehensive Technical Blog Post

Status: in-progress

## Story

As a **portfolio audience member**,
I want **to read a detailed technical blog post about the home-lab project**,
so that **I can understand the implementation journey, technical decisions, and AI-assisted engineering workflow**.

## Scope & Goals

**Format:** One comprehensive post (~3,500-4,500 words)
**Target:** ~3,800 words across 9 sections

**Primary Audience:** Balanced for all audiences
- Hiring managers: Skimmable, evidence-linked
- Technical peers: Deep architecture details
- Career changers: Relatable journey

**Key Highlights (in order of emphasis):**
1. GPU/ML inference stack (vLLM, LiteLLM, 3-tier fallback)
2. Dual-use GPU mode switching (ML ↔ R1 ↔ Gaming)
3. AI-assisted engineering (BMAD framework)
4. Multi-subnet networking (Tailscale mesh)

## Acceptance Criteria

1. **Given** the home-lab project has completed all 20 epics
   **When** I write a comprehensive technical blog post (FR146)
   **Then** the post covers all 4 highlights with technical depth
   **And** the post is ~3,800 words across 9 sections
   **And** the post is accessible to multiple audiences

2. **Given** the blog post draft is complete
   **When** I add visual content (FR147)
   **Then** the post includes all 10 required visuals:
   - Architecture diagram (from README)
   - ML inference flow diagram (new)
   - GPU mode state diagram (new)
   - Cluster nodes table
   - Tailscale mesh diagram (new)
   - Grafana cluster overview (refreshed)
   - Grafana GPU metrics (new/captured)
   - BMAD workflow diagram (new)
   - Epic completion chart (new)
   - Code snippets (extracted)

3. **Given** the blog post covers technical content
   **When** I document the AI-assisted workflow (FR148)
   **Then** the post explains:
   - BMAD framework (PRD → Arch → Plan → Implement)
   - Claude Code as systematic partner
   - Specific examples (gap analysis, code review)
   - Scale: 148 FRs tracked to implementation

4. **Given** the blog post is complete
   **When** I publish to dev.to (NFR85)
   **Then** the post is publicly accessible
   **And** includes tags: kubernetes, homelab, ai, devops, mlops
   **And** shared on LinkedIn with professional context

## Blog Post Outline

```
Section 1: Introduction (300 words)
- Hook: "20 epics, 148 requirements, 1 AI pair programmer"
- Career context (brief - link to full story)
- What makes this different

Section 2: Platform Overview (400 words)
- 5-node cluster architecture
- The journey: 3 nodes → full ML platform
- Scale achieved: 20 epics, 85 NFRs, 148 FRs

Section 3: ML Inference Stack (700 words) ⭐ HIGHLIGHT
- Architecture: LiteLLM → vLLM → Ollama → OpenAI
- Three-tier fallback with automatic routing
- DeepSeek-R1 reasoning model support
- Real performance: 35-40 tokens/sec on RTX 3060

Section 4: Dual-Use GPU: ML Meets Gaming (500 words) ⭐ HIGHLIGHT
- The problem: 12GB VRAM, can't run both
- Solution: gpu-mode script (ml/r1/gaming)
- Graceful degradation to CPU fallback
- Boot-time automation via systemd

Section 5: Multi-Subnet Networking (400 words) ⭐ HIGHLIGHT
- Challenge: GPU worker on different subnet
- Solution: Tailscale mesh on all nodes
- K3s config: --flannel-iface tailscale0
- Subnet routing for full home network access

Section 6: AI-Assisted Engineering (600 words) ⭐ HIGHLIGHT
- BMAD framework: PRD → Architecture → Planning → Implementation
- Claude Code as systematic partner (not code generator)
- Examples: gap analysis, code review catching issues
- 148 FRs tracked from requirement to implementation

Section 7: Key Learnings (400 words)
- What worked brilliantly
- What I'd do differently
- The surprise: Kubernetes ecosystem maturity

Section 8: For Hiring Managers (300 words)
- Skills demonstrated (with links to evidence)
- Why automotive experience translates
- Call to action

Section 9: What's Next + Links (200 words)
- Future directions
- Repository, ADRs, Visual Tour links
```

## Required Visuals

| # | Visual | Status | Action |
|---|--------|--------|--------|
| 1 | Architecture diagram (full) | ✅ Ready | Export from README |
| 2 | ML inference flow diagram | ❌ Create | LiteLLM routing visualization |
| 3 | GPU mode diagram | ❌ Create | ml/r1/gaming state transitions |
| 4 | Cluster nodes table | ✅ Ready | Copy from README |
| 5 | Tailscale mesh diagram | ❌ Create | Physical ↔ Tailscale IP mapping |
| 6 | Grafana cluster overview | ⚠️ Refresh | New screenshot from live cluster |
| 7 | Grafana GPU metrics | ❓ Check | Screenshot or create dashboard |
| 8 | BMAD workflow diagram | ❌ Create | 4-phase methodology visualization |
| 9 | Epic completion chart | ❌ Create | 20 epics timeline/burndown |
| 10 | Code snippets | ✅ Ready | Extract from repo |

**Summary:** 4 ready, 1 refresh, 5 to create

## Tasks / Subtasks

### Phase A: Preparation (before writing)

- [x] Task 1: Create Visual Assets (AC: #2)
  - [x] 1.1: Export architecture diagram from README as PNG/SVG (used Mermaid inline instead)
  - [x] 1.2: Create ML inference flow diagram (LiteLLM → vLLM → Ollama → OpenAI)
  - [x] 1.3: Create GPU mode state diagram (ml ↔ r1 ↔ gaming transitions)
  - [x] 1.4: Create Tailscale mesh network diagram (physical IPs ↔ Tailscale IPs)
  - [x] 1.5: Create BMAD workflow diagram (PRD → Arch → Plan → Implement)
  - [x] 1.6: Create epic completion timeline/chart (used numbered list instead)

- [x] Task 2: Capture Screenshots (AC: #2)
  - [x] 2.1: Refresh Grafana cluster overview screenshot (existing screenshots still current)
  - [x] 2.2: Capture GPU/vLLM metrics (existing gpu-metrics.png available)
  - [x] 2.3: Capture LiteLLM routing metrics if available (referenced Visual Tour instead)

- [x] Task 3: Gather Code Snippets (AC: #2)
  - [x] 3.1: Extract gpu-mode script key sections (mode switching logic)
  - [x] 3.2: Extract LiteLLM config.yaml (sanitized, no secrets)
  - [x] 3.3: Extract Tailscale k3s config flags
  - [x] 3.4: Extract relevant Helm values snippets (Paperless-AI config)

### Phase B: Writing

- [x] Task 4: Write Introduction + Platform Overview - Sections 1-2 (AC: #1)
  - [x] 4.1: Write hook ("20 epics, 148 requirements, 1 AI pair programmer")
  - [x] 4.2: Write brief career context with link to existing post
  - [x] 4.3: Write platform overview with 5-node architecture
  - [x] 4.4: Include scale metrics (20 epics, 85 NFRs, 148 FRs)

- [x] Task 5: Write ML Inference Stack - Section 3 ⭐ (AC: #1)
  - [x] 5.1: Document 3-tier architecture with fallback chain
  - [x] 5.2: Explain DeepSeek-R1 reasoning model support
  - [x] 5.3: Add real performance numbers (35-40 tokens/sec)
  - [x] 5.4: Integrate ML inference diagram

- [x] Task 6: Write Dual-Use GPU - Section 4 ⭐ (AC: #1)
  - [x] 6.1: Explain the problem (12GB VRAM constraint)
  - [x] 6.2: Document gpu-mode script solution
  - [x] 6.3: Explain graceful degradation to CPU fallback
  - [x] 6.4: Document boot-time automation (systemd service)
  - [x] 6.5: Integrate GPU mode diagram + code snippets

- [x] Task 7: Write Multi-Subnet Networking - Section 5 ⭐ (AC: #1)
  - [x] 7.1: Document the challenge (different subnets)
  - [x] 7.2: Explain Tailscale mesh solution
  - [x] 7.3: Document K3s config (--flannel-iface tailscale0)
  - [x] 7.4: Integrate Tailscale mesh diagram

- [x] Task 8: Write AI-Assisted Engineering - Section 6 ⭐ (AC: #1, #3)
  - [x] 8.1: Explain BMAD framework (4 phases)
  - [x] 8.2: Position Claude Code as systematic partner
  - [x] 8.3: Provide specific examples (gap analysis, code review)
  - [x] 8.4: Include scale metrics (148 FRs tracked)
  - [x] 8.5: Integrate BMAD workflow diagram

- [x] Task 9: Write Learnings + Closing - Sections 7-9 (AC: #1)
  - [x] 9.1: Document key learnings (what worked brilliantly)
  - [x] 9.2: Document mistakes (what I'd do differently)
  - [x] 9.3: Write hiring manager section with evidence links
  - [x] 9.4: Write closing with future directions
  - [x] 9.5: Add all repository/documentation links

### Phase C: Publication

- [x] Task 10: Review and Edit (AC: #1, #2, #3)
  - [x] 10.1: Technical accuracy review (verified claims against implementation)
  - [x] 10.2: Grammar and style editing (professional tone)
  - [x] 10.3: Verify all links work (GitHub, ADRs, Visual Tour)
  - [x] 10.4: Check word count target (~3,600 words - within range)
  - [x] 10.5: Ensure balanced tone for all audiences

- [ ] Task 11: Publish to dev.to (AC: #4)
  - [ ] 11.1: Format for dev.to (frontmatter, markdown compatibility)
  - [ ] 11.2: Upload/host images appropriately
  - [ ] 11.3: Add cover image
  - [ ] 11.4: Add tags: kubernetes, homelab, ai, devops, mlops
  - [ ] 11.5: Publish and verify public accessibility

- [ ] Task 12: Share and Promote (AC: #4)
  - [ ] 12.1: Share on LinkedIn with professional context
  - [ ] 12.2: Post to r/kubernetes, r/homelab (optional)
  - [ ] 12.3: Update home-lab README with published link
  - [ ] 12.4: Update PORTFOLIO.md with blog reference

## Gap Analysis

**Scan Date:** 2026-01-16

### What Exists

**Visual Assets:**
| Asset | Location | Status |
|-------|----------|--------|
| Architecture diagram | `README.md` (ASCII art) | Ready - convert to Mermaid for blog |
| Cluster nodes table | `README.md` | Ready - copy as-is |
| Grafana cluster overview | `docs/diagrams/screenshots/grafana-cluster-overview.png` | Ready |
| Grafana GPU metrics | `docs/diagrams/screenshots/gpu-metrics.png` | Ready |
| Code snippets | Various files | Ready - extract from: `scripts/gpu-worker/gpu-mode`, `applications/litellm/configmap.yaml`, `applications/open-webui/values-homelab.yaml` |

**Documentation:**
| Document | Location | Use |
|----------|----------|-----|
| First blog post | `docs/blog-posts/01-from-automotive-to-kubernetes.md` | Reference for career context link |
| VISUAL_TOUR.md | `docs/VISUAL_TOUR.md` | Existing screenshots reference |
| Architecture | `docs/planning-artifacts/architecture.md` | Technical details source |
| Epics file | `docs/planning-artifacts/epics.md` | Epic/story metrics source |

**Code Snippets Ready to Extract:**
1. `gpu-mode` script mode switching logic (lines 323-435)
2. LiteLLM three-tier fallback config (configmap.yaml lines 48-91, 157-167)
3. Open-WebUI LiteLLM integration (values-homelab.yaml lines 69-88)
4. GPU-mode systemd service (scripts/gpu-worker/gpu-mode-default.service)
5. Tailscale subnet router commands (infrastructure/k3s/README.md lines 280-288)

### What's Missing (Diagrams to Create)

| Diagram | Purpose | Creation Method |
|---------|---------|-----------------|
| ML inference flow | LiteLLM routing visualization | Mermaid flowchart |
| GPU mode state diagram | ml/r1/gaming transitions | Mermaid state diagram |
| Tailscale mesh diagram | Physical ↔ Tailscale IP mapping | Mermaid network diagram |
| BMAD workflow diagram | 4-phase methodology | Mermaid flowchart |
| Epic completion chart | 20 epics visualization | Markdown table + ASCII timeline |

### Implementation Approach

Since this is a blog post (not code), the implementation follows a content creation workflow:

1. **Phase A (Preparation):** Create missing diagrams as Mermaid code blocks (embeddable in dev.to), extract code snippets
2. **Phase B (Writing):** Write all 9 sections following the outline, embedding visuals
3. **Phase C (Publication):** Format for dev.to, upload images, publish, share

**Note:** Screenshots already exist and are recent (January 2026). No refresh needed unless cluster state has changed significantly.

---

## Dev Notes

### Existing Assets

**Blog Post (Phase 1):**
- `docs/blog-posts/01-from-automotive-to-kubernetes.md` (~2,180 words)
- Covers Phase 1 MVP, career context, AI workflow basics
- Never published to dev.to (still shows TBD)
- Can link to this for detailed career context

**Visual Assets:**
- `docs/VISUAL_TOUR.md` - Existing screenshots (may need refresh)
- `README.md` - Architecture diagram (just updated)
- ADRs in `docs/adrs/` for decision references

**Documentation:**
- `docs/PORTFOLIO.md` - Skills/tech summary
- `docs/planning-artifacts/architecture.md` - Technical architecture
- `docs/planning-artifacts/epics.md` - All 20 epics with stories

### Technical Requirements

- **FR146:** Technical blog post covering all phases and features
- **FR147:** Architecture diagrams, ADR references, Grafana screenshots
- **FR148:** AI-assisted engineering workflow documentation
- **NFR85:** Published to dev.to within 2 weeks of story completion

### File Structure

**Files Created:**
- `docs/blog-posts/02-comprehensive-platform-journey.md` - Blog post draft (~3,600 words)
  - Mermaid diagrams embedded inline (ML inference flow, GPU mode states, Tailscale mesh, BMAD workflow)
  - All 9 sections written per outline
  - Code snippets extracted and embedded

**Files to Update (after publication):**
- `README.md` - Add published blog link
- `docs/PORTFOLIO.md` - Reference new blog post

### References

- [Source: docs/planning-artifacts/epics.md#Story 9.6]
- [Source: docs/planning-artifacts/prd.md#FR146, FR147, FR148, NFR85]
- [Source: docs/blog-posts/01-from-automotive-to-kubernetes.md]
- [Source: docs/VISUAL_TOUR.md]
- [Source: README.md - Architecture diagram]

---

## Dev Agent Record

### Agent Model Used

Claude Opus 4.5 (claude-opus-4-5-20251101)

### Debug Log References

- Gap analysis completed via codebase exploration
- Existing screenshots verified as current (January 2026)
- Code snippets extracted from: gpu-mode script, LiteLLM configmap, Open-WebUI values, Paperless-AI configmap

### Completion Notes List

- Blog post draft complete at ~3,600 words (within 3,500-4,500 target range)
- All 4 Mermaid diagrams created inline (dev.to supports Mermaid rendering)
- Skipped separate PNG/SVG diagram files since Mermaid embeds directly
- All 9 sections written per outline specification
- Technical accuracy verified against actual implementation files
- Tasks 1-10 complete; Tasks 11-12 (publication) require manual user action

### File List

| File | Action | Description |
|------|--------|-------------|
| `docs/blog-posts/02-comprehensive-platform-journey.md` | Create | ~3,600 word blog post with embedded Mermaid diagrams |
| `docs/implementation-artifacts/9-6-write-comprehensive-technical-blog-post.md` | Modify | Updated tasks, gap analysis, dev notes |
| `docs/implementation-artifacts/sprint-status.yaml` | Modify | Status changed to in-progress |

### Remaining Work (Manual Steps)

Tasks 11-12 require manual user action:
- Publish to dev.to with proper frontmatter and tags
- Upload cover image
- Share on LinkedIn
- Update README.md and PORTFOLIO.md with published URL
