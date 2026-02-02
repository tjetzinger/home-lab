# Story 23.3: Enable Browser Automation Tool

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **user**,
I want **to ask my AI assistant to perform browser-based tasks like navigating websites, filling forms, and extracting information**,
So that **I can automate web interactions through conversation without doing them manually**.

## Acceptance Criteria

1. **Browser tool triggered via conversation** — Given the OpenClaw gateway is running (Epic 21), when a user requests a browser automation task through conversation (e.g., "check the current price of X on this website"), then the assistant triggers the built-in browser automation tool (FR174).

2. **Web navigation and interaction** — Given the browser tool is invoked, when the task involves navigating a web page, then the tool can navigate to URLs, interact with page elements, fill forms, and extract information (FR175). And the extracted information is returned to the user in the conversation.

3. **Graceful failure handling** — Given a browser automation task fails (e.g., page not loading, element not found), when the failure is detected, then the assistant informs the user of the failure with a clear error description. And the gateway remains stable (no crash).

## Tasks / Subtasks

> **REFINED TASKS** - Validated against actual codebase via gap analysis (2026-02-02).

> **Research Finding:** OpenClaw has a **built-in browser automation tool** based on Chromium via Chrome DevTools Protocol (CDP). The deployment already includes a `sandbox-browser` sidecar container (`openclaw-sandbox-browser:bookworm-slim`) with Chromium pre-installed, CDP on port 9222, VNC on 5900, and noVNC on 6080. Browser config already exists in `openclaw.json`. Manifest changes are needed for noVNC ingress exposure.

- [x] Task 1: Verify browser sidecar is running and CDP accessible (AC: #1)
  - [x] 1.1 Pod shows 2/2 Running (openclaw + sandbox-browser)
  - [x] 1.2 CDP endpoint accessible: Chrome/144.0.7559.109 at localhost:9222
  - [x] 1.3 Sandbox-browser logs show operational Chromium (OOM score warnings are harmless, Vulkan warning expected — no GPU)

- [x] Task 2: Browser configuration already present in openclaw.json (AC: #1)
  - [x] 2.1 Config verified: `browser.enabled: true`, `defaultProfile: "sandbox"`, `profiles.sandbox.cdpUrl: "http://localhost:9222"`
  - [x] 2.2 No changes needed — config was pre-configured during initial deployment

- [x] Task 3: Validate browser automation via conversation (AC: #1, #2)
  - [x] 3.1 Browser task request sent via Telegram — assistant invoked browser tool
  - [x] 3.2 Gateway logs confirm `[browser/service]` ready and tool invocations
  - [x] 3.3 Page navigation works — assistant returns extracted content
  - [x] 3.4 Browser interaction validated by Tom via Telegram
  - [x] 3.5 Information extraction confirmed working

- [x] Task 4: Expose noVNC browser debugging via Traefik ingress (AC: #2)
  - [x] 4.1 Added `novnc` port (6080) to `applications/openclaw/service.yaml`
  - [x] 4.2 Added `openclaw-browser.home.jetzinger.com` to Certificate dnsNames in `applications/openclaw/ingressroute.yaml`
  - [x] 4.3 Added IngressRoute `openclaw-browser-ingress` for `openclaw-browser.home.jetzinger.com` → service port 6080 (websecure, TLS via `openclaw-tls`)
  - [x] 4.4 Added HTTP-to-HTTPS redirect IngressRoute `openclaw-browser-ingress-redirect`
  - [x] 4.5 NextDNS rewrite added by Tom: `openclaw-browser.home.jetzinger.com` → `192.168.2.100`
  - [x] 4.6 Manifests applied: service configured, certificate configured, IngressRoutes created
  - [x] 4.7 cert-manager issued certificate with both SANs via DNS-01/Cloudflare — Ready: True
  - [x] 4.8 `https://openclaw-browser.home.jetzinger.com` loads noVNC web interface (added `redirectRegex` middleware to redirect `/` → `/vnc_lite.html`)

- [x] Task 5: Validate failure handling (AC: #3)
  - [x] 5.1 Failure handling validated by Tom via Telegram — assistant reports errors clearly
  - [x] 5.2 Gateway remains stable after browser failures (0 restarts, pod 2/2 Running)
  - [x] 5.3 Telegram, Discord, TTS, and sub-agents continue working after browser errors

## Gap Analysis

**Scan Date:** 2026-02-02

**What Exists:**
- Pod running 2/2 containers (openclaw + sandbox-browser), STATUS Running, 0 restarts
- CDP endpoint accessible at `localhost:9222` — Chrome/144.0.7559.109
- Browser config already present in `openclaw.json`: `enabled: true`, `defaultProfile: "sandbox"`, `profiles.sandbox.cdpUrl: "http://localhost:9222"`, `profiles.sandbox.color: "#4a9eff"`
- Service `openclaw` has ports `gateway` (18789) and `bridge` (18790) — no `novnc` port
- IngressRoutes: `openclaw-ingress` and `openclaw-ingress-redirect` exist — no browser ingress

**What's Missing:**
- `novnc` port (6080) not exposed in Service
- No IngressRoute for `openclaw-browser.home.jetzinger.com`
- No Certificate SAN for browser subdomain
- NextDNS rewrite for `openclaw-browser.home.jetzinger.com`
- Browser automation not yet validated via conversation

**Task Changes:** Tasks 1-2 marked complete (already done). Tasks 3-5 kept as-is.

---

## Dev Notes

### Architecture Patterns & Constraints

- **Browser Tool is Built-In:** OpenClaw natively supports browser automation via Chromium CDP. No plugins or extensions needed. Config lives under `browser` in `openclaw.json`.
- **Sidecar Architecture:** The browser runs as a sidecar container (`sandbox-browser`) in the same pod as the gateway. They communicate via `localhost:9222` (CDP). This is already deployed in the current `deployment.yaml`.
- **Docker Images Already Built:** Both `openclaw:2026.2.1` and `openclaw-sandbox-browser:bookworm-slim` are already built and transferred to `k3s-worker-01` via `ctr`. No new image builds needed.
- **Shared Memory:** The sidecar has `/dev/shm` (256Mi emptyDir, Memory medium) for Chromium rendering. Already configured in `deployment.yaml`.
- **Schema Strictness:** OpenClaw uses TypeBox strict validation. Unknown keys crash the gateway (learned from Story 22.1). Only use documented config keys for the `browser` section.
- **Config Editing Pattern:** Use `kubectl exec` with Node.js inline scripts to modify `openclaw.json` on PVC, then `kubectl rollout restart` (established pattern from Stories 23.1, 23.2).

### Browser Configuration Schema

```json
{
  "browser": {
    "enabled": true,
    "defaultProfile": "sandbox",
    "headless": false,
    "noSandbox": false,
    "evaluateEnabled": true,
    "profiles": {
      "sandbox": {
        "cdpUrl": "http://localhost:9222"
      }
    }
  }
}
```

**Key options:**
- `enabled`: Boolean, enable/disable browser tool (default: `true`)
- `defaultProfile`: Profile name to use (use `"sandbox"` for the sidecar)
- `headless`: Run headless (default: `false` — sidecar manages headless mode)
- `evaluateEnabled`: Allow JS evaluation in browser context (default: `true`)
- `profiles.sandbox.cdpUrl`: CDP endpoint URL (`http://localhost:9222` for sidecar)

**Minimal config recommended** — start with `enabled`, `defaultProfile`, and `profiles.sandbox.cdpUrl` only. Add optional fields only if needed (schema strictness).

### Browser Capabilities

- **Navigate:** Open URLs, follow links, go back/forward
- **Interact:** Click elements, type text, fill forms, select dropdowns, drag
- **Extract:** Read page content, take screenshots, generate PDFs
- **Profiles:** Multiple named profiles (only `sandbox` needed for sidecar)
- **Debugging:** VNC (port 5900), noVNC web UI (port 6080) for visual debugging

### noVNC Ingress (Browser Debugging UI)

Expose the noVNC web interface via Traefik at `openclaw-browser.home.jetzinger.com` instead of port-forward:
- Add `novnc` port (6080) to `applications/openclaw/service.yaml`
- Add SAN `openclaw-browser.home.jetzinger.com` to the existing Certificate in `applications/openclaw/ingressroute.yaml`
- Add IngressRoute + HTTP redirect for the new subdomain (same pattern as existing `openclaw-ingress`)
- noVNC uses WebSockets — Traefik handles `Upgrade: websocket` headers natively, no middleware needed
- Add NextDNS rewrite for the new subdomain

### Source Tree Components

- `applications/openclaw/deployment.yaml` — Already has sandbox-browser sidecar. **No changes needed.**
- `applications/openclaw/service.yaml` — Add `novnc` port (6080) for noVNC ingress.
- `applications/openclaw/ingressroute.yaml` — Add `openclaw-browser.home.jetzinger.com` SAN to Certificate, add IngressRoute + redirect for browser UI.
- `applications/openclaw/README.md` — Update browser debugging section to reference ingress URL instead of port-forward.
- `/home/node/.openclaw/openclaw.json` (on PVC) — Add `browser` config section.

### Previous Story Intelligence (Story 23.2 — Sub-Agent Routing)

**Critical learnings:**
- Config changes require pod restart via `kubectl rollout restart deployment/openclaw -n apps`
- Config editing via `kubectl exec` with Node.js inline scripts works reliably
- Gateway validates config at startup — check logs for errors
- OpenClaw config schema is strict (unknown keys crash — learned from Story 22.1)
- Doctor command (`node dist/entry.js doctor`) verifies component status
- `memory-lancedb` plugin load failure is a pre-existing issue with Docker image v2026.2.1, not related

### Previous Story Intelligence (Story 23.1 — Voice/ElevenLabs)

**Critical learnings:**
- Config validation is strict — enum values required, not booleans
- Auto-detection behavior can cause unexpected provider selection (OPENAI_API_KEY triggered OpenAI TTS instead of ElevenLabs)
- Test on actual messaging channel (Telegram) for end-to-end validation
- Pod restart takes ~2s for channels to reconnect

### Git Intelligence (Recent Commits)

```
bfde90e feat: enable voice interaction and sub-agent routing for OpenClaw (Epic 23, Stories 23.1-23.2)
c2eaa35 feat: complete Epic 22 stories — Discord channel, cross-channel context, and OpenClaw updates
```

Pattern: Conventional commits with `feat:` prefix, referencing Epic and Story numbers.

### Testing Standards

- Verify all ACs manually via kubectl, gateway logs, and messaging tests
- No automated tests — validation is operational
- Test browser automation via explicit conversation request on Telegram
- Verify extracted content is returned to user in conversation
- Verify existing functionality (TTS, Discord, Telegram, sub-agents) unaffected after browser enable
- Test failure scenarios to confirm gateway stability

### Project Structure Notes

- `applications/openclaw/service.yaml` and `applications/openclaw/ingressroute.yaml` modified for noVNC ingress
- No new secrets needed — browser tool uses no external API keys
- `openclaw.json` on PVC will be extended with `browser` config section
- NextDNS rewrite needed for `openclaw-browser.home.jetzinger.com`

### Dependencies

- **Requires:** Story 21.1 (deployment) - done, Story 21.2 (ingress) - done
- **Sidecar already deployed:** `sandbox-browser` container in `deployment.yaml` since initial deployment
- **No external dependencies** — browser automation is built into OpenClaw + sidecar image

### References

- [Source: docs/planning-artifacts/epics.md#Story 23.3 BDD (line ~5546)]
- [Source: docs/planning-artifacts/epics.md#FR174-FR175 (line ~1131)]
- [Source: docs/planning-artifacts/architecture.md#Browser Tool (line ~1382)]
- [Source: docs/planning-artifacts/architecture.md#Browser Automation Tool FR174 (line ~1407)]
- [Source: applications/openclaw/deployment.yaml - sandbox-browser sidecar (lines 92-129)]
- [Source: applications/openclaw/README.md - Post-Deploy Browser Configuration (lines 48-73)]
- [Source: docs/implementation-artifacts/23-2-configure-multi-agent-sub-agent-routing.md - Previous story learnings]
- [Source: docs/implementation-artifacts/23-1-enable-voice-interaction-via-elevenlabs.md - Previous story learnings]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.5 (claude-opus-4-5-20251101)

### Change Log

- Gap analysis performed — Tasks 1-2 already complete, Tasks 3-5 kept (2026-02-02)
- Task 4 complete: noVNC ingress via Traefik at openclaw-browser.home.jetzinger.com (2026-02-02)
- All tasks complete — browser automation validated by Tom via Telegram (2026-02-02)

### Debug Log References

### Completion Notes List

- Task 1: Browser sidecar verified running (2/2, Chrome 144.0.7559.109, CDP at localhost:9222) — pre-existing
- Task 2: Browser config already present in openclaw.json (`enabled: true`, sandbox profile) — pre-existing
- Task 3: Browser automation validated by Tom via Telegram — navigation, interaction, extraction all working
- Task 4: noVNC exposed via Traefik at `openclaw-browser.home.jetzinger.com` — Service port added, Certificate SAN added (DNS-01/Cloudflare), IngressRoute + redirect created, `redirectRegex` middleware redirects `/` to `/vnc_lite.html`
- Task 5: Failure handling validated by Tom — clear error reporting, gateway stable, no impact on other channels
- Note: Earlier browser tool errors (`page.evaluate: Invalid evaluate function`) were transient JS eval failures, not infrastructure issues — cleared after pod restart

### File List

- `applications/openclaw/service.yaml` — Added `novnc` port (6080)
- `applications/openclaw/ingressroute.yaml` — Added `openclaw-browser.home.jetzinger.com` Certificate SAN, `novnc-root-redirect` Middleware, `openclaw-browser-ingress` IngressRoute, `openclaw-browser-ingress-redirect` IngressRoute
- `applications/openclaw/README.md` — Updated browser debugging section with ingress URL
