# Story 22.1: Enable WhatsApp Channel via Baileys

Status: blocked

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **user**,
I want **to send and receive messages with my AI assistant via WhatsApp DM**,
So that **I can interact with my personal AI from my primary messaging app**.

## Acceptance Criteria

1. **WhatsApp channel connector starts via Baileys** — When I configure WhatsApp Baileys credentials and complete the initial pairing process, the WhatsApp channel connector starts and establishes a WebSocket connection to WhatsApp servers. No inbound network exposure is required (outbound WebSocket only) (FR160).

2. **Authorized user receives LLM responses** — When an authorized user (on the allowlist in `openclaw.json`) sends a DM via WhatsApp, the message is processed by the LLM and a response is returned (FR160). The allowlist-only DM security policy applies (FR162, configured in Epic 21).

3. **Baileys auth state persists across pod restarts** — When the OpenClaw pod restarts, the Baileys auth state is restored from local-path PVC at `~/.openclaw/credentials/whatsapp/default/` and no re-pairing is required (NFR100).

4. **Auto-reconnect after network interruption** — When the WhatsApp channel experiences a network interruption and connectivity is restored, the channel automatically reconnects within 60 seconds (NFR97). The disconnection does not affect Telegram or other channels (NFR101).

**FRs covered:** FR160
**NFRs covered:** NFR97, NFR100, NFR101

## Tasks / Subtasks

> **REFINED TASKS** - Validated against actual codebase via gap analysis (2026-02-02).

- [x] Task 1: Configure WhatsApp channel in openclaw.json (AC: #1, #2)
  - [x] 1.1 Add `channels.whatsapp` config to `/home/node/.openclaw/openclaw.json` — minimal valid schema: `{ dmPolicy: "allowlist", allowFrom: ["+491718664082"] }` (note: `enabled` and `streamMode` are NOT valid WhatsApp schema keys — causes gateway crash)
  - [x] 1.2 Tom's WhatsApp number: +491718664082 (E.164 format)
  - [x] 1.3 Restart pod via `kubectl rollout restart deployment/openclaw -n apps` — pod running 0 restarts
  - [x] 1.4 Doctor output confirms: `WhatsApp: not linked` (config accepted, awaiting QR pairing)

- [x] Task 2: Complete WhatsApp QR pairing (AC: #1)
  - [x] 2.1 QR pairing initiated via Control UI at `https://openclaw.home.jetzinger.com/channels`
  - [x] 2.2 Tom scanned QR code from WhatsApp app (Linked Devices)
  - [x] 2.3 Baileys auth state created: `creds.json` (1731 bytes) at `/home/node/.openclaw/credentials/whatsapp/default/` on local-path PVC
  - [x] 2.4 Doctor confirms: `WhatsApp: linked (auth age 2m)`, Web Channel: `+491718664082` (jid `491718664082:13@s.whatsapp.net`)

- [ ] Task 3: Validate DM allowlist security (AC: #2)
  - [ ] 3.1 Send a DM from Tom's WhatsApp account — expect LLM response via Opus 4.5
  - [ ] 3.2 Verify unauthorized user DMs are silently rejected (dmPolicy:allowlist enforcement)
  - [ ] 3.3 Verify response round-trip completes within reasonable time (NFR86: <10s excluding LLM inference)

- [ ] Task 4: Validate Baileys auth state persistence (AC: #3)
  - [ ] 4.1 Confirm auth state files exist at `/home/node/.openclaw/credentials/whatsapp/default/` on local-path PVC
  - [ ] 4.2 Perform pod restart via `kubectl rollout restart deployment/openclaw -n apps`
  - [ ] 4.3 Verify Baileys auth state is restored — no re-pairing required after restart
  - [ ] 4.4 Send a test WhatsApp DM after restart — verify response received

- [ ] Task 5: Validate auto-reconnect and channel isolation (AC: #4)
  - [ ] 5.1 Simulate network interruption via pod restart
  - [ ] 5.2 Verify WhatsApp reconnects within 60 seconds (NFR97)
  - [ ] 5.3 Verify Telegram channel is unaffected during WhatsApp reconnect (NFR101)
  - [ ] 5.4 Verify Control UI is unaffected during WhatsApp reconnect (NFR101)

## Gap Analysis

**Scan Date:** 2026-02-02

**What Exists:**
- OpenClaw v2026.2.1 has built-in WhatsApp/Baileys support (`@whiskeysockets/baileys` dependency)
- WhatsApp registered in channel registry with QR link pairing (`selectionLabel: "WhatsApp (QR link)"`)
- `WHATSAPP_CREDENTIALS` placeholder in `openclaw-secrets` (not used by Baileys — file-based auth)
- Deployment already has local-path PVC mounts for `.openclaw` and `clawd` directories
- Telegram channel configured with `dmPolicy: "allowlist"` — WhatsApp follows identical pattern
- CLI: `node dist/entry.js configure --section channels` for interactive WhatsApp setup
- Agent tool: `whatsapp_login` for QR code generation

**What's Missing:**
- No `channels.whatsapp` section in `openclaw.json`
- No WhatsApp auth state (credentials directory doesn't exist yet)
- Tom's WhatsApp phone number (E.164 format) for allowFrom

**Key Corrections from Draft:**
- Auth state stored at `/home/node/.openclaw/credentials/whatsapp/default/creds.json` (NOT `~/clawd/`)
- `WHATSAPP_CREDENTIALS` env var is NOT used by Baileys — auth is file-based on NFS
- Removed subtasks 1.5 (patch secret) and 2.4 (verify env var) as unnecessary
- Reordered: config first (Task 1), then QR pairing (Task 2) — gateway needs config before pairing

---

## Dev Notes

### Architecture Patterns & Constraints

- **WhatsApp Transport:** Baileys library uses outbound WebSocket connection to WhatsApp servers. No inbound network exposure, no webhook needed. This is similar to Telegram long-polling but uses WebSocket instead of HTTPS polling.
- **Baileys Auth State Persistence:** This is the PRIMARY RISK for this story. Baileys requires persistent auth state — if session data is lost, re-pairing is required (QR scan on phone). Architecture explicitly calls out NFS PVC at `~/clawd/` for storing Baileys auth state [Source: docs/planning-artifacts/architecture.md#WhatsApp Session Persistence (line ~1615)].
- **DM Security Pattern:** Same as Telegram (Story 21.5) — allowlist-only pairing per NFR92. Gateway silently drops messages from non-allowlisted users. Configure via `openclaw.json` with `dmPolicy: "allowlist"` and `allowFrom` array.
- **Secret Management:** `WHATSAPP_CREDENTIALS` placeholder already exists in `openclaw-secrets` (line 25 of `secret.yaml`). Populate via `kubectl patch` — never commit real credentials to git.
- **Config Persistence:** All WhatsApp config stored in `/home/node/.openclaw/openclaw.json` on NFS PVC (10Gi). Survives pod restarts.
- **Gateway Port:** 18789 (not 3000). Config directory is `.openclaw` (not `.clawdbot`).
- **Channel Isolation:** Architecture requires NFR101 — one channel disconnect must not affect others. WhatsApp connector should be independent of Telegram connector.
- **Networking:** WhatsApp via Baileys is outbound-only WebSocket from the pod. Architecture confirms no inbound exposure needed [Source: docs/planning-artifacts/architecture.md#Networking Architecture (line ~1460)].

### Source Tree Components

- `applications/openclaw/secret.yaml` — Already contains `WHATSAPP_CREDENTIALS` (empty placeholder at line 25). No git changes needed, only `kubectl patch` at runtime if Baileys requires env var credentials.
- `applications/openclaw/deployment.yaml` — Already injects all secrets via `envFrom.secretRef`. NFS mounts at `/home/node/.openclaw` (subPath: openclaw) and `/home/node/clawd` (subPath: clawd). No changes expected.
- `/home/node/.openclaw/openclaw.json` (on NFS) — Gateway config where WhatsApp channel will be configured. Already has Telegram channel config from Story 21.5.
- `/home/node/clawd/` (on NFS) — Baileys auth state will be stored here for persistence across pod restarts.

### Previous Story Intelligence (Story 21.5)

**Critical learnings from Telegram channel setup:**
- Gateway port is **18789** (not 3000 as architecture initially assumed)
- Config directory is `.openclaw` (not `.clawdbot` — image renamed it)
- `openclaw.json` uses specific schema — gateway schema is strict, unknown keys cause crash
- DM allowlist configured via `dmPolicy: "allowlist"` and `allowFrom` array in channel config
- Telegram channel config pattern: `enabled: true`, `dmPolicy: "allowlist"`, `allowFrom: [<user_id>]`
- Device pairing persisted at `/home/node/.openclaw/devices/paired.json`
- Auth credentials stored at `/home/node/.openclaw/agents/main/agent/auth-profiles.json`
- Gateway startup command: `node dist/index.js gateway --bind lan --port 18789 --allow-unconfigured`
- Rollout restart reconnects channels in ~30s (within 60s NFR97 threshold)
- Control UI reconnects independently of messaging channels (NFR101 confirmed)

### Git Intelligence (Recent Commits)

```
daa2338 feat: enable Telegram channel with DM allowlist security (Epic 21, Story 21.5)
bebf116 feat: configure Opus 4.5 LLM with LiteLLM fallback (Epic 21, Story 21.4)
5143e2d feat: configure Traefik ingress and Control UI for OpenClaw (Epic 21, Story 21.2)
4a005b8 feat: deploy OpenClaw gateway with NFS persistence (Epic 21, Story 21.1)
687c0e4 feat: add OpenClaw Phase 5 planning and calsync dev container
```

Pattern: Conventional commits with `feat:` prefix, referencing Epic and Story numbers.

### Testing Standards

- Verify all ACs manually via kubectl, gateway logs, WhatsApp messaging, and Loki
- No automated tests for infrastructure configuration stories — validation is operational
- Check NFR compliance: 60s reconnect (NFR97), channel isolation (NFR101), session persistence (NFR100)
- Test both authorized and unauthorized WhatsApp DM scenarios
- Verify Baileys auth state survives pod restart (critical risk area)

### Project Structure Notes

- No new K8s manifest files expected — this story configures existing infrastructure
- `applications/openclaw/secret.yaml` may need WHATSAPP_CREDENTIALS patched (NOT committed to git)
- `openclaw.json` on NFS will be extended with WhatsApp channel config
- Baileys session state stored on NFS at `~/clawd/` (already mounted)

### Dependencies

- **Requires:** Story 21.1 (deployment) - done, Story 21.2 (ingress) - done, Story 21.4 (LLM config) - done, Story 21.5 (Telegram + DM security) - done
- **External dependency:** Tom's WhatsApp account for device pairing (QR code scan)
- **Predecessor pattern:** WhatsApp channel follows the same openclaw.json configuration pattern as Telegram (Story 21.5)

### References

- [Source: docs/planning-artifacts/epics.md#Story 22.1 BDD (line ~5298)]
- [Source: docs/planning-artifacts/architecture.md#OpenClaw Personal AI Assistant Architecture (line ~1368)]
- [Source: docs/planning-artifacts/architecture.md#WhatsApp Session Persistence (line ~1615)]
- [Source: docs/planning-artifacts/architecture.md#Networking Architecture (line ~1449)]
- [Source: docs/planning-artifacts/architecture.md#Secret manifest (line ~1562)]
- [Source: docs/implementation-artifacts/21-4-enable-telegram-channel-with-dm-security.md - Previous story]
- [Source: applications/openclaw/secret.yaml - WHATSAPP_CREDENTIALS placeholder at line 25]
- [Source: applications/openclaw/deployment.yaml - envFrom secretRef + NFS mounts]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.5 (claude-opus-4-5-20251101)

### Debug Log References

- Gateway crashed on first config attempt with `enabled` and `streamMode` keys — WhatsApp schema is stricter than Telegram. Minimal valid config: `{ dmPolicy, allowFrom }` only.
- Pod auto-recovered after CrashLoopBackOff (2 restarts) then stable after config fix.

### Completion Notes List

- Task 1: WhatsApp channel config added to openclaw.json with `dmPolicy: "allowlist"` and `allowFrom: ["+491718664082"]`. Doctor confirms `WhatsApp: not linked` (awaiting QR pairing). Key learning: WhatsApp channel schema does NOT accept `enabled` or `streamMode` keys (unlike Telegram).
- Task 2: QR pairing initially completed via Control UI (Doctor: `WhatsApp: linked`), but session was invalidated with 401 Unauthorized after stream error 515. Subsequent QR pairing attempts failed — WhatsApp app reports "couldn't link device". Likely WhatsApp rate-limiting on repeated link attempts. Story blocked pending retry.
- **BLOCKED**: WhatsApp QR pairing fails after initial session invalidation. Tasks 3-5 cannot proceed without a working WhatsApp connection. Recommend retrying after a cooldown period (several hours) using port-forward method for more reliable localhost pairing.

### File List

## Change Log

- Tasks refined based on codebase gap analysis (2026-02-02): Corrected auth state path, removed unnecessary env var subtasks, reordered config-first approach
