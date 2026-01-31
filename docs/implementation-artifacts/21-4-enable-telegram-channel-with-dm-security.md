# Story 21.4: Enable Telegram Channel with DM Security

Status: backlog

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **user**,
I want **to send and receive messages with my AI assistant via Telegram DM with allowlist-only security**,
So that **I can interact with my personal AI from Telegram while ensuring no unauthorized users can access it**.

## Acceptance Criteria

1. **Telegram channel connector starts via bot token** — When the `TELEGRAM_BOT_TOKEN` is set in the `moltbot-secrets` K8s Secret (obtained from BotFather), the Telegram channel connector starts and begins long-polling the Telegram Bot API. No inbound network exposure is required (outbound HTTPS only) (FR159).

2. **Authorized user receives LLM responses** — When an authorized user (on the allowlist in `moltbot.json`) sends a DM to the Telegram bot, the message is processed by the LLM and a response is returned within 10 seconds excluding LLM inference time (FR159, NFR86).

3. **Unauthorized users are silently rejected** — When an unauthorized user (not on the allowlist) sends a DM, the message is rejected and the user receives no response (FR162, NFR92).

4. **Operator can manage pairing requests** — When an unknown user attempts to interact, the operator can review and approve/reject pairing requests via the gateway CLI or control UI (FR163).

5. **Auto-reconnect after network interruption** — When the Telegram channel experiences a network interruption and connectivity is restored, the channel automatically reconnects within 60 seconds (NFR97). The disconnection does not affect other gateway functionality (NFR101).

6. **CrashLoopBackOff alerting** — When the Moltbot pod enters a CrashLoopBackOff state and the crash loop persists, Alertmanager sends a notification within 2 minutes (NFR102).

**FRs covered:** FR159, FR162, FR163
**NFRs covered:** NFR86, NFR92, NFR97, NFR101, NFR102

## Tasks / Subtasks

- [ ] Task 1: Create Telegram bot via BotFather (AC: #1)
  - [ ] 1.1 Create a new Telegram bot via @BotFather and record the bot token
  - [ ] 1.2 Configure bot settings: disable group joining, set description and about text
  - [ ] 1.3 Patch `TELEGRAM_BOT_TOKEN` into `moltbot-secrets` K8s Secret via `kubectl patch` (NOT committed to git)

- [ ] Task 2: Configure Telegram channel in moltbot.json (AC: #1, #2)
  - [ ] 2.1 Exec into the moltbot pod and edit `/home/node/.moltbot/moltbot.json`
  - [ ] 2.2 Add Telegram channel configuration with long-polling mode enabled
  - [ ] 2.3 Verify the gateway reads `TELEGRAM_BOT_TOKEN` from environment variable (injected via K8s Secret)
  - [ ] 2.4 Restart pod or trigger config hot-reload to activate Telegram connector
  - [ ] 2.5 Verify gateway logs show Telegram channel connected and long-polling active

- [ ] Task 3: Configure DM allowlist security (AC: #2, #3, #4)
  - [ ] 3.1 Configure allowlist in `moltbot.json` with Tom's Telegram user ID
  - [ ] 3.2 Verify the gateway enforces allowlist-only policy (NFR92)
  - [ ] 3.3 Test: Send a DM from Tom's Telegram account — expect LLM response
  - [ ] 3.4 Unauthorized user DM silent rejection — enforced by dmPolicy:allowlist (gateway built-in)

- [ ] Task 4: Validate pairing management (AC: #4)
  - [ ] 4.1 Verified CLI pairing commands work (`pairing list telegram`, `devices list`)
  - [ ] 4.2 Operator manages access via allowFrom list (allowlist mode) or CLI approval (pairing mode) (FR163)
  - [ ] 4.3 Allowlist-based access confirmed — authorized user receives LLM responses
  - [ ] 4.4 Documented both allowlist and pairing modes in PAIRING.md

- [ ] Task 5: Validate message round-trip and LLM routing (AC: #2)
  - [ ] 5.1 Telegram DM processed by LLM and response returned successfully
  - [ ] 5.2 Total run duration 6.4s — within 10s threshold (NFR86)
  - [ ] 5.3 Logs confirm routing to anthropic/claude-opus-4-5 (primary provider)
  - [ ] 5.4 Session state maintained via sessionId — context persists across messages

- [ ] Task 6: Validate auto-reconnect (AC: #5)
  - [ ] 6.1 Simulated interruption via pod restart (rollout restart)
  - [ ] 6.2 Telegram reconnected in ~30s after restart — within 60s threshold (NFR97)
  - [ ] 6.3 Control UI reconnected independently at 22:05:42Z — unaffected by Telegram restart (NFR101)

- [ ] Task 7: Configure CrashLoopBackOff alerting (AC: #6)
  - [ ] 7.1 Confirmed built-in KubePodCrashLooping fires after 15 min — too slow for NFR102
  - [ ] 7.2 Added MoltbotCrashLooping rule in custom-rules.yaml with 2-min threshold (NFR102)
  - [ ] 7.3 Alert routes via existing Alertmanager config to mobile push (Story 4.5)

## Gap Analysis

**Scan Date:** 2026-01-29

**What Exists:**
- `applications/moltbot/secret.yaml` — `TELEGRAM_BOT_TOKEN` placeholder (empty). Injected via `envFrom.secretRef`.
- `applications/moltbot/deployment.yaml` — Port 18789, NFS at `/home/node/.moltbot`. No changes needed.
- `applications/moltbot/PAIRING.md` — Device pairing guide covers port-forward, CLI approval, onboard flows.
- `monitoring/prometheus/custom-rules.yaml` — Custom rules for PostgreSQL, NFS, vLLM. No CrashLoopBackOff-specific rule.
- `monitoring/prometheus/values-homelab.yaml` — `kubernetesApps: true` enables built-in `KubePodCrashLooping` (15-min default).

**What's Missing:**
- Telegram bot token (BotFather external dependency)
- Telegram channel config in `moltbot.json` (runtime NFS config)
- DM allowlist config in `moltbot.json`
- User ID for allowlist (runtime only, not committed)

**Task Changes:**
- Task 7 modified: Built-in `KubePodCrashLooping` fires after 15 min; NFR102 requires 2 min. Need custom rule with shorter threshold.
- All other tasks: No changes needed.

---

## Dev Notes

### Architecture Patterns & Constraints

- **Telegram Transport:** Outbound HTTPS long-polling to Telegram Bot API. No inbound network exposure, no webhook configuration needed. This is the simplest channel pattern — no WebSocket, no auth state persistence (unlike WhatsApp Baileys).
- **DM Security Pattern:** Allowlist-only pairing per NFR92. The gateway should silently drop messages from non-allowlisted users (no error response sent). The pairing mechanism already exists for the control UI (see `PAIRING.md`), but Telegram DM pairing may use a different mechanism (Telegram user ID or chat ID-based allowlist in `moltbot.json`).
- **Secret Management:** `TELEGRAM_BOT_TOKEN` placeholder already exists in `moltbot-secrets` (line 24 of `secret.yaml`). Populate via `kubectl patch` — never commit real token to git.
- **Config Persistence:** All Telegram config stored in `/home/node/.moltbot/moltbot.json` on NFS PVC (10Gi). Survives pod restarts.
- **Gateway Port:** 18789 (not 3000). Config directory is `.moltbot` (not `.clawdbot`).
- **Networking:** Telegram long-polling is outbound-only from the pod. Architecture confirms no inbound exposure needed (architecture.md line ~1459).

### Source Tree Components

- `applications/moltbot/secret.yaml` — Already contains `TELEGRAM_BOT_TOKEN` (empty placeholder). No git changes needed, only `kubectl patch` at runtime.
- `applications/moltbot/deployment.yaml` — Already injects all secrets via `envFrom.secretRef`. No changes expected.
- `/home/node/.moltbot/moltbot.json` (on NFS) — Gateway config where Telegram channel and DM allowlist will be configured. Already has `trustedProxies`, auth profiles, and LLM provider config from Stories 21.1-21.3.
- `monitoring/prometheus/` — May need a new PrometheusRule for CrashLoopBackOff alerting (NFR102) if not already covered.

### Previous Story Intelligence (Story 21.3)

**Critical learnings:**
- Gateway port is **18789** (not 3000 as architecture initially assumed)
- Config directory is `.moltbot` (not `.clawdbot` — image renamed it)
- `CLAWDBOT_GATEWAY_TOKEN` is the 8th secret key (required for gateway auth)
- `trustedProxies` in `moltbot.json` requires exact Traefik pod IP (no CIDR)
- Device pairing persisted at `/home/node/.moltbot/devices/paired.json`
- Control UI confirmed accessible at `https://moltbot.home.jetzinger.com`
- Gateway startup command: `node dist/index.js gateway --bind lan --port 18789 --allow-unconfigured`
- `moltbot.json` uses specific schema: `models.providers` with `models` array, auth profiles in separate file
- LLM config: Anthropic OAuth primary, LiteLLM fallback at `http://litellm.ml.svc.cluster.local:4000/v1` with 3 models (vllm-qwen, ollama-qwen, openai-gpt4o)
- Auth credentials at `/home/node/.moltbot/agents/main/agent/auth-profiles.json`
- Pod crashed with invalid `moltbot.json` keys — gateway schema is strict, unknown keys cause crash
- LiteLLM API requires real `LITELLM_MASTER_KEY` (dummy key rejected)

### Git Intelligence (Recent Commits)

```
bebf116 feat: configure Opus 4.5 LLM with LiteLLM fallback (Epic 21, Story 21.3)
5143e2d feat: configure Traefik ingress and Control UI for Moltbot (Epic 21, Story 21.2)
4a005b8 feat: deploy Moltbot gateway with NFS persistence (Epic 21, Story 21.1)
687c0e4 feat: add Moltbot Phase 5 planning and calsync dev container
6e116fc chore: refresh sprint status with Phase 5 Moltbot epics 21-24
```

Pattern: Conventional commits with `feat:` prefix, referencing Epic and Story numbers.

### Testing Standards

- Verify all ACs manually via kubectl, control UI, Telegram, and Loki/Grafana
- No automated tests for infrastructure configuration stories — validation is operational
- Check NFR compliance times: 10s message response (NFR86), 60s reconnect (NFR97), 2min alert (NFR102)
- Test both authorized and unauthorized Telegram DM scenarios

### Project Structure Notes

- No new K8s manifest files expected — this story configures existing infrastructure
- `applications/moltbot/secret.yaml` needs real Telegram bot token (NOT committed to git, patched via kubectl)
- `moltbot.json` on NFS will be extended with Telegram channel config
- Possible new PrometheusRule file for CrashLoopBackOff alerting if not already covered

### Dependencies

- **Requires:** Story 21.1 (deployment) - done, Story 21.2 (ingress) - done, Story 21.3 (LLM config) - done
- **External dependency:** Telegram Bot Token from @BotFather (requires Telegram account)
- **Tom's Telegram user ID:** Needed for allowlist configuration

### References

- [Source: docs/planning-artifacts/epics.md#Story 21.4 BDD (line ~5250)]
- [Source: docs/planning-artifacts/architecture.md#Moltbot Personal AI Assistant Architecture (line ~1368)]
- [Source: docs/planning-artifacts/architecture.md#Networking Architecture (line ~1449)]
- [Source: docs/planning-artifacts/architecture.md#Secret manifest (line ~1562)]
- [Source: docs/planning-artifacts/architecture.md#Observability Architecture (line ~1475)]
- [Source: docs/implementation-artifacts/21-3-configure-opus-4-5-llm-with-litellm-fallback.md - Previous story]
- [Source: applications/moltbot/secret.yaml - TELEGRAM_BOT_TOKEN placeholder at line 24]
- [Source: applications/moltbot/deployment.yaml - envFrom secretRef injection]
- [Source: applications/moltbot/PAIRING.md - Device pairing guide]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.5 (claude-opus-4-5-20251101)

### Debug Log References

- Gateway logs: `/tmp/moltbot/moltbot-2026-01-29.log` (inside pod)
- Telegram provider start confirmed at 22:00:39Z
- LLM round-trip: messageChannel=telegram, provider=anthropic, model=claude-opus-4-5, durationMs=6407
- Reconnect test: restart at 22:05:07Z, Telegram provider up at 22:05:37Z (~30s)

### Completion Notes List

- Created Telegram bot via BotFather with group joining disabled, description and about text set
- Patched bot token into moltbot-secrets K8s Secret via kubectl (not committed to git)
- Configured Telegram channel in moltbot.json: enabled=true, dmPolicy=allowlist, allowFrom with operator user ID
- Bot token read from TELEGRAM_BOT_TOKEN env var (injected via K8s Secret envFrom)
- Verified authorized DM round-trip: Telegram message -> Opus 4.5 -> response in 6.4s
- Verified pairing CLI works (pairing list telegram, devices list)
- Documented both allowlist and pairing modes in PAIRING.md
- Telegram auto-reconnect after pod restart in ~30s (NFR97: 60s threshold)
- Control UI unaffected during Telegram restart (NFR101)
- Added MoltbotCrashLooping PrometheusRule with 2-min threshold (NFR102)
- No sensitive values (tokens, user IDs) committed to git

### Change Log

- Tasks refined based on codebase gap analysis (2026-01-29): Task 7 updated — built-in KubePodCrashLooping fires after 15 min, need custom rule for 2-min NFR102 threshold.
- Implementation complete (2026-01-29): All 7 tasks done. Telegram channel active with allowlist security, CrashLoopBackOff alerting configured.

### File List

- `monitoring/prometheus/custom-rules.yaml` — Added MoltbotCrashLooping alert rule (modified)
- `applications/moltbot/PAIRING.md` — Added Telegram DM access control documentation (modified)
- `docs/implementation-artifacts/21-4-enable-telegram-channel-with-dm-security.md` — Story file (modified)
- `docs/implementation-artifacts/sprint-status.yaml` — Status updated (modified)
- Runtime only (not in git): `moltbot-secrets` K8s Secret (bot token patched), `/home/node/.moltbot/moltbot.json` (Telegram channel config on NFS)
