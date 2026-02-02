# Story 23.2: Configure Multi-Agent Sub-Agent Routing

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an **operator**,
I want **to configure specialized sub-agents that the AI assistant can delegate tasks to**,
So that **different types of requests are handled by purpose-built agents with distinct capabilities**.

## Acceptance Criteria

1. **Sub-agent configuration and registration** — Given the OpenClaw gateway is running (Epic 21), when the operator configures specialized sub-agents in `openclaw.json` with distinct capabilities (e.g., coding assistant, research specialist, writing editor), then the sub-agents are registered and available to the main agent (FR171).

2. **Explicit sub-agent invocation** — Given sub-agents are configured, when a user explicitly invokes a specific sub-agent (e.g., "ask the coding agent to review this"), then the request is routed to the specified sub-agent and the response is returned to the user (FR172).

3. **Context-based routing** — Given sub-agents are configured, when a user sends a message that matches a sub-agent's domain (e.g., a code review request when a coding sub-agent exists), then the system routes the task to the appropriate sub-agent based on context (FR173). And the user receives the sub-agent's specialized response.

4. **Fallback to main agent** — Given no sub-agent matches the request, when a general conversation message is sent, then the main agent handles the request directly without sub-agent routing.

## Tasks / Subtasks

> **REFINED TASKS** - Validated against actual codebase via gap analysis (2026-02-02).

> **Research Finding:** OpenClaw has two distinct multi-agent concepts: (1) **Multi-Agent** — separate agents with isolated workspaces routed via `bindings[]` by channel/account/peer, and (2) **Sub-Agents** — background task runners spawned from the main agent via `sessions_spawn` tool. The AC requirements (explicit invocation, context-based routing) map to the **sub-agent** model where the main agent uses `sessions_spawn` to delegate tasks. Sub-agents are configured via `agents.defaults.subagents` and `agents.list[].subagents` in `openclaw.json`. Known bug: `sessions_spawn` model override not applied (Issue #6295).

- [x] Task 1: Configure sub-agent settings in openclaw.json (AC: #1)
  - [x] 1.1 Added `agents.defaults.subagents.model: "anthropic/claude-sonnet-4-5"` (default for all sub-agents). Existing `maxConcurrent: 8` kept as-is.
  - [x] 1.2 Added `agents.defaults.subagents.archiveAfterMinutes: 60` for auto-cleanup
  - [x] 1.3 Added `agents.list[0].subagents.allowAgents: ["*"]` to enable sub-agent spawning to any agent
  - [x] 1.4 Added `tools.subagents.tools.deny: ["gateway", "cron"]` (default safety restrictions)
  - [x] 1.5 Pod restarted via `kubectl rollout restart` — rollout successful, 0 config errors, all channels OK

- [x] Task 2: Verify agent identity and workspace for sub-agent awareness (AC: #1)
  - [x] 2.1 Main agent identity confirmed: name "Ari", emoji "⚡", avatar "avatar.jpg" — no changes needed
  - [x] 2.2 Doctor command confirms: "Agents: main (default)" — `sessions_spawn` available by default to top-level agents
  - [x] 2.3 AGENTS.md (7.8KB) exists in workspace — sub-agents receive it automatically. No changes needed.

- [x] Task 3: Validate explicit sub-agent invocation (AC: #2)
  - [x] 3.1 Tom sent explicit sub-agent delegation request via Telegram
  - [x] 3.2 `sessions_spawn` tool called with task description — confirmed working
  - [x] 3.3 Sub-agent ran in isolated session and announced result back
  - [x] 3.4 Result appeared in the original chat channel — validated by Tom

- [x] Task 4: Validate context-based routing (AC: #3)
  - [x] 4.1 Tom sent domain-specific message — main agent autonomously spawned sub-agents
  - [x] 4.2 Context-based routing is LLM-driven (Opus 4.5 decides when to delegate) — working as designed
  - [x] 4.3 Complex research task with parallel sub-agent execution — validated by Tom

- [x] Task 5: Validate fallback and isolation (AC: #4)
  - [x] 5.1 Simple conversational message — main agent responded directly without sub-agent
  - [x] 5.2 Sub-agent session auto-archive configured at 60 minutes
  - [x] 5.3 Existing channels (Telegram, Discord) unaffected by sub-agent config — confirmed via doctor command
  - [x] 5.4 TTS (Story 23.1) coexists with sub-agent config — no conflicts

## Gap Analysis

**Scan Date:** 2026-02-02

**What Exists:**
- `agents` config section present with `defaults.model.primary: "anthropic/claude-opus-4-5"`, `defaults.maxConcurrent: 4`, `defaults.subagents.maxConcurrent: 8`
- `agents.list[0]`: main agent with identity (name: "Ari", emoji: "⚡", avatar: "avatar.jpg")
- `tools.web.search.apiKey` configured
- `AGENTS.md` (7.8KB) in workspace — generic OpenClaw template, no sub-agent delegation instructions
- `TOOLS.md` in workspace
- TTS configured (`messages.tts.provider: "elevenlabs"`, `auto: "always"`)
- All channel plugins active (Telegram, Discord, WhatsApp)

**What's Missing:**
- `agents.defaults.subagents.model` — not set (sub-agents inherit main model)
- `agents.defaults.subagents.archiveAfterMinutes` — not set (using default)
- `agents.list[0].subagents.allowAgents` — not set (restricts spawning)
- `tools.subagents` — no sub-agent tool restrictions configured

**Task Changes:** Task 1 modified (partial config exists, targeted additions needed). Task 2 modified (identity verified, reduced to verification only).

---

## Dev Notes

### Architecture Patterns & Constraints

- **Two Multi-Agent Concepts in OpenClaw:**
  1. **Multi-Agent (agents.list + bindings):** Separate agents with isolated workspaces, auth profiles, and sessions. Routed by channel/account/peer via `bindings[]`. Use case: multiple personas (home vs work assistant).
  2. **Sub-Agents (sessions_spawn):** Background task runners spawned from existing agent. Run in temporary isolated sessions, announce results back. Use case: parallel research, long tasks, delegation. This is what the ACs describe.

- **Sub-Agent Lifecycle:**
  - Spawned via `sessions_spawn` tool (non-blocking, returns `{ status: "accepted", runId, childSessionKey }`)
  - Runs in session: `agent:<agentId>:subagent:<uuid>`
  - Cannot spawn nested sub-agents (no fan-out)
  - Does NOT get session tools by default (no `sessions_spawn`, `sessions_send`)
  - Only receives AGENTS.md + TOOLS.md (no SOUL.md, USER.md, IDENTITY.md)
  - Announces result back to requester chat channel when complete
  - Auto-archived after `archiveAfterMinutes` (default: 60)

- **Sub-Agent Config Schema:**
  ```json
  {
    "agents": {
      "defaults": {
        "subagents": {
          "model": "provider/model-name",
          "maxConcurrent": 8,
          "archiveAfterMinutes": 60
        }
      },
      "list": [{
        "id": "main",
        "subagents": {
          "model": "provider/sub-agent-model",
          "maxConcurrent": 1,
          "allowAgents": ["*"]
        }
      }]
    },
    "tools": {
      "subagents": {
        "tools": {
          "deny": ["gateway", "cron"],
          "allow": ["read", "exec", "process"]
        }
      }
    }
  }
  ```

- **Context-Based Routing is LLM-Driven:** The main agent's LLM decides when to call `sessions_spawn` based on the task. There is no declarative "route code requests to coding agent" config. The main agent must be prompted (via AGENTS.md or system prompt) to understand when delegation is appropriate.

- **Known Bug (Issue #6295, Feb 2026):** `sessions_spawn` model parameter and `agents.defaults.subagents.model` config are NOT being applied — sub-agents always inherit the main agent's model. Workaround: accept that sub-agents use the same model as main agent (Opus 4.5).

- **Schema Strictness:** OpenClaw uses TypeBox strict validation. Unknown keys crash the gateway (learned from Story 22.1). Only use documented config keys.

- **Secret Management:** No new secrets needed for sub-agents — they inherit parent agent auth and API keys.

### Source Tree Components

- `/home/node/.openclaw/openclaw.json` (on PVC) — Gateway config where sub-agent settings will be added.
- `/home/node/.openclaw/workspace/AGENTS.md` (on PVC) — Agent workspace file that sub-agents receive. May need content describing delegation patterns.
- `applications/openclaw/deployment.yaml` — Current deployment. No changes expected.

### Previous Story Intelligence (Story 23.1 — Voice/ElevenLabs)

**Critical learnings from voice interaction setup:**
- Config changes require pod restart via `kubectl rollout restart deployment/openclaw -n apps`
- Config editing via `kubectl exec` with Node.js inline scripts works reliably
- Gateway validates config at startup — check logs for errors
- OpenClaw config schema is strict (enum values, not booleans; unknown keys crash)
- `auto: "always"` was the correct TTS setting — auto-TTS pipeline handles delivery
- ElevenLabs TTS and sub-agent config should coexist without conflict

### Previous Story Intelligence (Story 22.2 — Discord)

**Critical learnings:**
- Gateway schema is strict — unknown keys cause crash
- Doctor command (`node dist/entry.js doctor`) is the best way to verify channel status
- Pod restarts take ~2s for channels to reconnect

### Git Intelligence (Recent Commits)

```
c2eaa35 feat: complete Epic 22 stories — Discord channel, cross-channel context, and OpenClaw updates
8ee07e0 chore: mark Epic 21 as done in sprint status
9628ce3 feat: enable Telegram channel with DM security for OpenClaw (Epic 21, Story 21.5)
1eb550f feat: configure Opus 4.5 LLM for OpenClaw gateway (Epic 21, Story 21.4)
f1d892b feat: implement Story 21.3 LanceDB long-term memory for OpenClaw (Epic 21)
```

Pattern: Conventional commits with `feat:` prefix, referencing Epic and Story numbers.

### Testing Standards

- Verify all ACs manually via kubectl, gateway logs, and messaging tests
- No automated tests — validation is operational
- Test sub-agent spawning via explicit invocation on Telegram
- Verify sub-agent results announce back to original chat
- Verify existing functionality (TTS, Discord, Telegram, LanceDB) unaffected

### Project Structure Notes

- No new K8s manifest files expected — this story configures existing infrastructure
- `openclaw.json` on PVC will be extended with sub-agent config sections
- No new secrets needed — sub-agents inherit parent auth

### Dependencies

- **Requires:** Story 21.1 (deployment) - done, Story 21.4 (LLM config) - done, Story 21.5 (Telegram) - done
- **Optional:** Story 22.2 (Discord) - done (for multi-channel testing)
- **No external dependencies** — sub-agent support is built into OpenClaw

### Upstream Documentation Research

Research confirmed sub-agent routing is built-in OpenClaw functionality:

- **Sub-agents vs Multi-agents:** Two distinct concepts. Sub-agents are background task runners via `sessions_spawn`. Multi-agents are separate persona agents routed via `bindings[]`.
- **Config location:** `agents.defaults.subagents` and `agents.list[].subagents` in `openclaw.json`
- **Tool:** `sessions_spawn` with parameters: `task` (required), `label`, `agentId`, `model`, `thinking`, `runTimeoutSeconds`, `cleanup`
- **Isolation:** Sub-agents run in temporary sessions, cannot spawn nested sub-agents, get minimal prompt (AGENTS.md + TOOLS.md only)
- **Result delivery:** Announces back to requester chat channel when complete
- **Tool restrictions:** Configure via `tools.subagents.tools.deny` and `tools.subagents.tools.allow`
- **Known bug:** Issue #6295 — model override not applied to sub-agents (Feb 2026)

### References

- [Source: docs/planning-artifacts/epics.md#Story 23.2 BDD (line ~5517)]
- [Source: docs/planning-artifacts/epics.md#FR171-FR173 (line ~1128)]
- [Source: docs/planning-artifacts/architecture.md#Multi-Agent (line ~1381)]
- [Source: docs/planning-artifacts/architecture.md#Session activity and agent routing (line ~1491)]
- [Source: docs/implementation-artifacts/23-1-enable-voice-interaction-via-elevenlabs.md - Previous story learnings]
- [Source: docs/implementation-artifacts/22-2-enable-discord-channel.md - Discord channel and schema learnings]
- [Upstream: https://docs.openclaw.ai/concepts/multi-agent - Multi-agent routing documentation]
- [Upstream: https://docs.openclaw.ai/tools/subagents - Sub-agent tool documentation]
- [Upstream: https://docs.openclaw.ai/gateway/configuration - Gateway configuration schema]
- [Upstream: https://github.com/openclaw/openclaw/issues/6295 - sessions_spawn model override bug]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.5 (claude-opus-4-5-20251101)

### Debug Log References

- Gateway startup: no config validation errors after adding sub-agent settings
- `[gateway] agent model: anthropic/claude-opus-4-5` — main agent model confirmed
- Doctor: `Agents: main (default)` — agent registered with sub-agent support
- Telegram OK, Discord OK — channels unaffected by sub-agent config
- `memory-lancedb` plugin load failure — pre-existing issue (Docker image v2026.2.1), not related to this story

### Completion Notes List

- Task 1: Sub-agent config added to openclaw.json — `agents.defaults.subagents.model: "anthropic/claude-sonnet-4-5"`, `archiveAfterMinutes: 60`, `allowAgents: ["*"]`, `tools.subagents.tools.deny: ["gateway", "cron"]`
- Task 2: Agent identity and workspace verified — Ari identity, AGENTS.md, sessions_spawn all in place
- Task 3: Explicit sub-agent invocation validated by Tom on Telegram — `sessions_spawn` working, results announced back
- Task 4: Context-based routing validated — Opus 4.5 autonomously delegates to sub-agents for complex/parallel tasks
- Task 5: Fallback confirmed — simple messages handled directly by main agent, channels and TTS unaffected
- Note: Sub-agent model override bug (Issue #6295) means sub-agents currently inherit Opus 4.5 from main agent despite Sonnet 4.5 config

### Change Log

- Gap analysis performed — tasks refined (2026-02-02)
- Task 1-2 complete: Sub-agent config and verification done (2026-02-02)
- All tasks complete — sub-agent routing working, validated by Tom (2026-02-02)

### File List

**On-cluster (not in git):**
- PVC `openclaw-data` subPath `openclaw/openclaw.json` — Added `agents.defaults.subagents` (model, archiveAfterMinutes), `agents.list[0].subagents` (allowAgents), `tools.subagents` (deny list)
