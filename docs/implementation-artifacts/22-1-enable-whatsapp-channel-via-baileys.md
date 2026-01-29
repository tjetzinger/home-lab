# Story 22.1: Enable WhatsApp Channel via Baileys

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **user**,
I want **to send and receive messages with my AI assistant via WhatsApp DM**,
So that **I can interact with my personal AI from my primary messaging app**.

## Acceptance Criteria

1. **WhatsApp channel connector starts via Baileys** — When I configure WhatsApp Baileys credentials and complete the initial pairing process, the WhatsApp channel connector starts and establishes a WebSocket connection to WhatsApp servers. No inbound network exposure is required (outbound WebSocket only) (FR160).

2. **Authorized user receives LLM responses** — When an authorized user (on the allowlist in `moltbot.json`) sends a DM via WhatsApp, the message is processed by the LLM and a response is returned (FR160). The allowlist-only DM security policy applies (FR162, configured in Epic 21).

3. **Baileys auth state persists across pod restarts** — When the Moltbot pod restarts, the Baileys auth state is restored from NFS PVC at `~/clawd/` and no re-pairing is required (NFR100).

4. **Auto-reconnect after network interruption** — When the WhatsApp channel experiences a network interruption and connectivity is restored, the channel automatically reconnects within 60 seconds (NFR97). The disconnection does not affect Telegram or other channels (NFR101).

**FRs covered:** FR160
**NFRs covered:** NFR97, NFR100, NFR101

## Tasks / Subtasks

> **DRAFT TASKS** - Generated from requirements analysis. Will be validated and refined against actual codebase when dev-story runs.

- [ ] Task 1: Obtain WhatsApp Baileys credentials (AC: #1)
  - [ ] 1.1 Research Baileys pairing process — determine if phone-based QR scan or multi-device pairing code is required
  - [ ] 1.2 Exec into moltbot pod and initiate Baileys pairing (likely via gateway CLI or config)
  - [ ] 1.3 Complete WhatsApp device pairing on Tom's phone (QR code scan or link code)
  - [ ] 1.4 Verify Baileys auth state files are created on NFS at `/home/node/clawd/` (or appropriate Baileys session path)
  - [ ] 1.5 Patch `WHATSAPP_CREDENTIALS` into `moltbot-secrets` K8s Secret via `kubectl patch` if needed (NOT committed to git)

- [ ] Task 2: Configure WhatsApp channel in moltbot.json (AC: #1, #2)
  - [ ] 2.1 Exec into the moltbot pod and edit `/home/node/.moltbot/moltbot.json`
  - [ ] 2.2 Add WhatsApp channel configuration (following the same pattern as Telegram channel from Story 21.4)
  - [ ] 2.3 Configure dmPolicy=allowlist with Tom's WhatsApp number/ID in allowFrom
  - [ ] 2.4 Verify the gateway reads `WHATSAPP_CREDENTIALS` from environment variable (injected via K8s Secret envFrom) if required
  - [ ] 2.5 Restart pod or trigger config hot-reload to activate WhatsApp connector
  - [ ] 2.6 Verify gateway logs show WhatsApp channel connected via Baileys WebSocket

- [ ] Task 3: Validate DM allowlist security (AC: #2)
  - [ ] 3.1 Send a DM from Tom's WhatsApp account — expect LLM response via Opus 4.5
  - [ ] 3.2 Verify unauthorized user DMs are silently rejected (dmPolicy:allowlist enforcement)
  - [ ] 3.3 Verify response round-trip completes within reasonable time (NFR86: <10s excluding LLM inference)

- [ ] Task 4: Validate Baileys auth state persistence (AC: #3)
  - [ ] 4.1 Identify where Baileys stores auth state files on NFS (expected: `/home/node/clawd/` subpath)
  - [ ] 4.2 Perform pod restart via `kubectl rollout restart deployment/moltbot -n apps`
  - [ ] 4.3 Verify Baileys auth state is restored — no re-pairing required after restart
  - [ ] 4.4 Send a test WhatsApp DM after restart — verify response received

- [ ] Task 5: Validate auto-reconnect and channel isolation (AC: #4)
  - [ ] 5.1 Simulate network interruption via pod restart
  - [ ] 5.2 Verify WhatsApp reconnects within 60 seconds (NFR97)
  - [ ] 5.3 Verify Telegram channel is unaffected during WhatsApp reconnect (NFR101)
  - [ ] 5.4 Verify Control UI is unaffected during WhatsApp reconnect (NFR101)

## Gap Analysis

_This section will be populated by dev-story when gap analysis runs._

---

## Dev Notes

### Architecture Patterns & Constraints

- **WhatsApp Transport:** Baileys library uses outbound WebSocket connection to WhatsApp servers. No inbound network exposure, no webhook needed. This is similar to Telegram long-polling but uses WebSocket instead of HTTPS polling.
- **Baileys Auth State Persistence:** This is the PRIMARY RISK for this story. Baileys requires persistent auth state — if session data is lost, re-pairing is required (QR scan on phone). Architecture explicitly calls out NFS PVC at `~/clawd/` for storing Baileys auth state [Source: docs/planning-artifacts/architecture.md#WhatsApp Session Persistence (line ~1615)].
- **DM Security Pattern:** Same as Telegram (Story 21.4) — allowlist-only pairing per NFR92. Gateway silently drops messages from non-allowlisted users. Configure via `moltbot.json` with `dmPolicy: "allowlist"` and `allowFrom` array.
- **Secret Management:** `WHATSAPP_CREDENTIALS` placeholder already exists in `moltbot-secrets` (line 25 of `secret.yaml`). Populate via `kubectl patch` — never commit real credentials to git.
- **Config Persistence:** All WhatsApp config stored in `/home/node/.moltbot/moltbot.json` on NFS PVC (10Gi). Survives pod restarts.
- **Gateway Port:** 18789 (not 3000). Config directory is `.moltbot` (not `.clawdbot`).
- **Channel Isolation:** Architecture requires NFR101 — one channel disconnect must not affect others. WhatsApp connector should be independent of Telegram connector.
- **Networking:** WhatsApp via Baileys is outbound-only WebSocket from the pod. Architecture confirms no inbound exposure needed [Source: docs/planning-artifacts/architecture.md#Networking Architecture (line ~1460)].

### Source Tree Components

- `applications/moltbot/secret.yaml` — Already contains `WHATSAPP_CREDENTIALS` (empty placeholder at line 25). No git changes needed, only `kubectl patch` at runtime if Baileys requires env var credentials.
- `applications/moltbot/deployment.yaml` — Already injects all secrets via `envFrom.secretRef`. NFS mounts at `/home/node/.moltbot` (subPath: moltbot) and `/home/node/clawd` (subPath: clawd). No changes expected.
- `/home/node/.moltbot/moltbot.json` (on NFS) — Gateway config where WhatsApp channel will be configured. Already has Telegram channel config from Story 21.4.
- `/home/node/clawd/` (on NFS) — Baileys auth state will be stored here for persistence across pod restarts.

### Previous Story Intelligence (Story 21.4)

**Critical learnings from Telegram channel setup:**
- Gateway port is **18789** (not 3000 as architecture initially assumed)
- Config directory is `.moltbot` (not `.clawdbot` — image renamed it)
- `moltbot.json` uses specific schema — gateway schema is strict, unknown keys cause crash
- DM allowlist configured via `dmPolicy: "allowlist"` and `allowFrom` array in channel config
- Telegram channel config pattern: `enabled: true`, `dmPolicy: "allowlist"`, `allowFrom: [<user_id>]`
- Device pairing persisted at `/home/node/.moltbot/devices/paired.json`
- Auth credentials stored at `/home/node/.moltbot/agents/main/agent/auth-profiles.json`
- Gateway startup command: `node dist/index.js gateway --bind lan --port 18789 --allow-unconfigured`
- Rollout restart reconnects channels in ~30s (within 60s NFR97 threshold)
- Control UI reconnects independently of messaging channels (NFR101 confirmed)

### Git Intelligence (Recent Commits)

```
daa2338 feat: enable Telegram channel with DM allowlist security (Epic 21, Story 21.4)
bebf116 feat: configure Opus 4.5 LLM with LiteLLM fallback (Epic 21, Story 21.3)
5143e2d feat: configure Traefik ingress and Control UI for Moltbot (Epic 21, Story 21.2)
4a005b8 feat: deploy Moltbot gateway with NFS persistence (Epic 21, Story 21.1)
687c0e4 feat: add Moltbot Phase 5 planning and calsync dev container
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
- `applications/moltbot/secret.yaml` may need WHATSAPP_CREDENTIALS patched (NOT committed to git)
- `moltbot.json` on NFS will be extended with WhatsApp channel config
- Baileys session state stored on NFS at `~/clawd/` (already mounted)

### Dependencies

- **Requires:** Story 21.1 (deployment) - done, Story 21.2 (ingress) - done, Story 21.3 (LLM config) - done, Story 21.4 (Telegram + DM security) - done
- **External dependency:** Tom's WhatsApp account for device pairing (QR code scan)
- **Predecessor pattern:** WhatsApp channel follows the same moltbot.json configuration pattern as Telegram (Story 21.4)

### References

- [Source: docs/planning-artifacts/epics.md#Story 22.1 BDD (line ~5298)]
- [Source: docs/planning-artifacts/architecture.md#Moltbot Personal AI Assistant Architecture (line ~1368)]
- [Source: docs/planning-artifacts/architecture.md#WhatsApp Session Persistence (line ~1615)]
- [Source: docs/planning-artifacts/architecture.md#Networking Architecture (line ~1449)]
- [Source: docs/planning-artifacts/architecture.md#Secret manifest (line ~1562)]
- [Source: docs/implementation-artifacts/21-4-enable-telegram-channel-with-dm-security.md - Previous story]
- [Source: applications/moltbot/secret.yaml - WHATSAPP_CREDENTIALS placeholder at line 25]
- [Source: applications/moltbot/deployment.yaml - envFrom secretRef + NFS mounts]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.5 (claude-opus-4-5-20251101)

### Debug Log References

### Completion Notes List

### File List
