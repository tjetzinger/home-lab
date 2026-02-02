# Story 22.4: Cross-Channel Conversation Context

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **user**,
I want **to continue a conversation with my AI assistant across different messaging channels**,
So that **I can start a discussion on Telegram and pick it up on WhatsApp or Discord without losing context**.

## Acceptance Criteria

1. **Cross-channel context continuity** — Given the user has active sessions on multiple messaging channels (Telegram, WhatsApp, Discord), when the user sends a message on one channel referencing a previous conversation from another channel, then the assistant maintains conversation context across channels and the user can seamlessly continue the discussion (FR164).

2. **Prior conversation recall across channels** — Given a conversation has history on Telegram, when the same authorized user sends a follow-up message on WhatsApp or Discord, then the assistant has access to the prior conversation context and responds coherently with awareness of the earlier discussion.

3. **Context preserved during channel failover** — Given one messaging channel is disconnected, when the user switches to another active channel, then the conversation context is preserved and accessible on the new channel.

## Tasks / Subtasks

> **DRAFT TASKS** - Generated from requirements analysis + upstream documentation research. Will be validated against actual codebase when dev-story runs.

> **Research Finding:** OpenClaw documentation confirms cross-channel context is a **built-in feature**. All DM channels routed to the same agent collapse to the agent's **main session key**, meaning short-term conversation context (LLM message history) is shared across Telegram, Discord, and WhatsApp natively. Long-term memory (LanceDB + daily logs + MEMORY.md) is per-agent workspace, also shared. **No code or configuration changes expected** — this is a pure validation story.

- [ ] Task 1: Validate short-term context sharing across channels (AC: #1, #2)
  - [ ] 1.1 Send a multi-turn conversation on Telegram establishing a specific topic (e.g., planning a trip to Japan)
  - [ ] 1.2 Switch to Discord and send a follow-up message continuing the same topic without re-explaining context
  - [ ] 1.3 Verify the assistant responds coherently with full awareness of the Telegram conversation
  - [ ] 1.4 Test reverse direction: start a new topic on Discord, continue on Telegram

- [ ] Task 2: Validate long-term memory recall across channels (AC: #1, #2)
  - [ ] 2.1 On Telegram, tell the assistant a distinctive fact (e.g., "Remember that my dog's name is Luna and she's a golden retriever")
  - [ ] 2.2 Verify auto-capture via `openclaw ltm stats` (memory count incremented)
  - [ ] 2.3 Start a new session (`/new` in Control UI or wait for session expiry)
  - [ ] 2.4 On Discord, ask "What's my dog's name?" — verify LanceDB auto-recall retrieves the memory from the Telegram conversation

- [ ] Task 3: Validate context preservation during channel failover (AC: #3)
  - [ ] 3.1 Establish a conversation on Telegram
  - [ ] 3.2 Simulate channel disruption via pod restart (`kubectl rollout restart deployment/openclaw -n apps`)
  - [ ] 3.3 Send follow-up message on Discord after pod recovers — verify context is preserved
  - [ ] 3.4 Verify Telegram channel also recovers and retains context (NFR97: <60s reconnect)

- [ ] Task 4: Document findings (AC: #1, #2, #3)
  - [ ] 4.1 Record which context layers cross channels (short-term session, LanceDB, daily logs, MEMORY.md)
  - [ ] 4.2 Note any limitations (e.g., session compaction behavior, context window limits)
  - [ ] 4.3 If WhatsApp becomes available (Story 22.1 unblocked), note as optional future validation

## Gap Analysis

_This section will be populated by dev-story when gap analysis runs._

---

## Dev Notes

### Architecture Patterns & Constraints

- **Cross-Channel Context is Built-In:** OpenClaw documentation confirms that all DM channels routed to the same agent collapse to the agent's **main session key**. This means Telegram, Discord, and WhatsApp DMs share the same short-term conversation context (LLM message history) natively. No configuration required.
- **Session Model:** Sessions live at `~/.openclaw/agents/<agentId>/sessions/`. DMs use the "main" session key regardless of source channel. Group chats get isolated sessions. This architecture means single-user DMs across all channels are a single continuous conversation.
- **Three Layers of Shared Context (all per-agent, cross-channel):**
  1. **Short-term session context** — LLM message history in the active session. Shared across channels via unified main session key.
  2. **LanceDB long-term memory** — Vector store with auto-capture/auto-recall (`memory-lancedb` plugin, OpenAI `text-embedding-3-small`, 1536-dim). Memories from any channel are retrievable from any other channel.
  3. **Markdown memory** — Daily logs (`memory/YYYY-MM-DD.md`) and curated long-term memory (`MEMORY.md`) in the agent workspace. Read at session start, shared across all channels.
- **`session-memory` Hook:** Built-in hook that saves session context to `~/.openclaw/workspace/memory/` when `/new` is issued. Bridges short-term session context into persistent Markdown memory. Complements LanceDB vector memory.
- **Single-User Architecture:** OpenClaw runs in single-user mode (Tom only). All channels use allowlist-only DM security (NFR92). Identity resolution is trivial — one authorized user, one agent, one main session.
- **Channel Connectors:** Telegram (long-polling), Discord (discord.js WebSocket), WhatsApp (Baileys WebSocket, currently blocked). Each operates independently per NFR101. Cross-channel context is handled by the shared session and memory layers, not by channel interconnection.
- **Context Management:** OpenClaw uses "adaptive" context pruning — soft-trims oversized tool results at `softTrimRatio`, hard-clears oldest eligible results at `hardClearRatio`. Session compaction can cause context loss if not managed (upstream Issue #5429).
- **No Configuration Changes Expected:** This is a validation-only story. The cross-channel feature works by design through the unified session model.

### Source Tree Components

- `/home/node/.openclaw/openclaw.json` (on PVC) — Gateway config. No changes expected for this story.
- `/home/node/.openclaw/agents/main/sessions/` (on PVC) — Session store with unified main session key across channels.
- `/home/node/.openclaw/memory/lancedb/memories.lance/` (on PVC) — LanceDB vector store (shared across channels).
- `~/.openclaw/workspace/memory/` (on PVC) — Markdown daily logs and MEMORY.md (shared across channels).
- `applications/openclaw/deployment.yaml` — Current deployment. No changes expected.

### Previous Story Intelligence (Story 22.2 — Discord)

**Critical learnings from Discord channel setup:**
- Gateway schema is strict — unknown keys cause crash. Each channel has its own valid schema.
- Discord DM config is nested: `channels.discord.dm.policy` (different from Telegram/WhatsApp flat `dmPolicy`).
- Discord DM allowFrom uses Discord user IDs (numeric strings).
- Doctor command (`node dist/entry.js doctor`) is the best way to verify channel status.
- Pod restarts take ~2s for Discord to reconnect (within 60s NFR97 threshold).
- Channel isolation confirmed (NFR101): Telegram unaffected during Discord reconnect.
- All three channels (Telegram, Discord, and when available WhatsApp) operate independently.

### Previous Story Intelligence (Story 21.3 — LanceDB Memory)

**Critical learnings from LanceDB setup:**
- Plugin uses OpenAI embeddings API (`text-embedding-3-small`), NOT local Xenova as originally architected.
- Config structure: `plugins.entries["memory-lancedb"].config` with `embedding.apiKey`, `embedding.model`, `autoCapture: true`, `autoRecall: true`.
- CLI: `openclaw ltm stats|list|search` for memory management.
- Auto-recall hook (`before_agent_start`) injects `<relevant-memories>` context before LLM inference.
- Auto-capture hook (`agent_end`) stores conversation context after each turn.
- Memory persistence confirmed across pod restarts (NFR106).
- Pod memory: 531Mi (within 4Gi limit).

### Git Intelligence (Recent Commits)

```
8ee07e0 chore: mark Epic 21 as done in sprint status
9628ce3 feat: enable Telegram channel with DM security for OpenClaw (Epic 21, Story 21.5)
1eb550f feat: configure Opus 4.5 LLM for OpenClaw gateway (Epic 21, Story 21.4)
f1d892b feat: implement Story 21.3 LanceDB long-term memory for OpenClaw (Epic 21)
aeb00ad feat: create story 22.1 Enable WhatsApp Channel via Baileys (Epic 22)
```

Pattern: Conventional commits with `feat:` prefix, referencing Epic and Story numbers.

### Testing Standards

- Verify all ACs manually via multi-channel messaging tests (Telegram + Discord)
- No automated tests — validation is operational
- Test both short-term context (same session, immediate follow-up) and long-term memory (new session, LanceDB recall)
- Use `openclaw ltm stats` and `openclaw ltm search` to verify memory capture and retrieval
- Verify pod restart preserves both session state and long-term memory

### Project Structure Notes

- This is a **pure validation story** — cross-channel context is a built-in OpenClaw feature via the unified main session key
- **No code changes expected.** No K8s manifest changes expected. No `openclaw.json` changes expected.
- Story 22.1 (WhatsApp) is blocked — tests focus on Telegram + Discord, with WhatsApp as optional future validation

### Dependencies

- **Requires:** Story 21.3 (LanceDB memory) - done, Story 21.5 (Telegram) - done, Story 22.2 (Discord) - done
- **Optional:** Story 22.1 (WhatsApp) - blocked (tests work with Telegram + Discord only)
- **No external dependencies** — all required channels already configured

### Upstream Documentation Research

Research performed during story creation confirmed cross-channel context is built-in:

- **Unified session key:** "Direct chats collapse to the agent's main session key" — all DM channels share one session.
- **Multi-channel inbox:** "You can start a conversation on one platform and continue on another, as OpenClaw maintains context across all connections."
- **Per-agent isolation:** Sessions, memory, and workspace are per-agent. All channels routed to the same agent share context.
- **`session-memory` hook:** Saves session context to Markdown files in workspace on `/new` command. Complements LanceDB.
- **Context management:** Adaptive pruning with soft/hard trim ratios. Upstream Issue #5429 notes risk of silent compaction context loss.

### References

- [Source: docs/planning-artifacts/epics.md#Story 22.4 BDD (line ~5451)]
- [Source: docs/planning-artifacts/epics.md#FR164 (line ~171)]
- [Source: docs/planning-artifacts/architecture.md#Long-Term Memory Architecture (line ~1511)]
- [Source: docs/planning-artifacts/architecture.md#Memory Backend (line ~1387)]
- [Source: docs/planning-artifacts/architecture.md#Channel Connectors (line ~1399)]
- [Source: docs/implementation-artifacts/21-3-configure-long-term-memory-with-lancedb.md - LanceDB implementation details]
- [Source: docs/implementation-artifacts/22-2-enable-discord-channel.md - Discord channel setup and schema learnings]
- [Source: docs/implementation-artifacts/22-1-enable-whatsapp-channel-via-baileys.md - WhatsApp blocked status and schema learnings]
- [Upstream: https://docs.openclaw.ai/concepts/multi-agent - Multi-agent routing and session model]
- [Upstream: https://docs.openclaw.ai/gateway/configuration - Gateway configuration and context management]
- [Upstream: https://docs.openclaw.ai/cli/hooks - session-memory hook documentation]
- [Upstream: https://github.com/openclaw/openclaw/issues/5429 - Silent compaction context loss issue]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.5 (claude-opus-4-5-20251101)

### Debug Log References

### Completion Notes List

### File List
