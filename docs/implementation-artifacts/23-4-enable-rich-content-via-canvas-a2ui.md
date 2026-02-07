# Story 23.4: Enable Rich Content via Canvas/A2UI

Status: in-progress

## Story

As a **user**,
I want **my AI assistant to present rich, structured content beyond plain text**,
So that **I can receive visually organized information like tables, diagrams, or interactive elements when appropriate**.

## Acceptance Criteria

1. **Given** the OpenClaw gateway is running (Epic 21)
   **When** a response benefits from rich content presentation (e.g., comparison tables, structured data, visual layouts)
   **Then** the assistant uses Canvas/A2UI to present the content in a rich format (FR176)

2. **Given** the messaging channel does not support rich content rendering
   **When** rich content is generated
   **Then** the assistant falls back to a well-formatted text representation

## Tasks / Subtasks

- [ ] Task 1: Build OpenClaw Android companion app from source (AC: #1)
  - [ ] 1.1 Clone OpenClaw v2026.2.1 source repo on a build machine
  - [ ] 1.2 Build the Android APK: `cd apps/android && ./gradlew :app:assembleDebug`
  - [ ] 1.3 Transfer APK to Android device and install
  - [ ] 1.4 Verify app launches and shows gateway discovery/settings screen

- [ ] Task 2: Pair Android node with gateway via Tailscale (AC: #1)
  - [ ] 2.1 Ensure Android device is on Tailscale network (can reach k3s-worker-01)
  - [ ] 2.2 Configure gateway endpoint manually in Android app settings (use Tailscale IP of k3s-worker-01 + port 18789)
  - [ ] 2.3 Initiate pairing from Android app
  - [ ] 2.4 Approve pairing on gateway: `kubectl exec -n apps deployment/openclaw -c openclaw -- node dist/entry.js nodes approve <requestId>`
  - [ ] 2.5 Verify node appears as connected: `kubectl exec -n apps deployment/openclaw -c openclaw -- node dist/entry.js nodes status`

- [ ] Task 3: Verify Canvas host is serving and accessible (AC: #1)
  - [ ] 3.1 Confirm canvas host is enabled in gateway logs (look for "canvas host mounted" message)
  - [ ] 3.2 Verify A2UI endpoint responds: `curl http://localhost:18789/__openclaw__/a2ui/` from within the pod
  - [ ] 3.3 Verify Canvas WebSocket path is active: `/__openclaw__/ws`
  - [ ] 3.4 Describe the Android node's capabilities: `node dist/entry.js nodes describe <nodeId>` — confirm canvas commands listed

- [ ] Task 4: Test Canvas/A2UI rich content rendering on Android (AC: #1)
  - [ ] 4.1 Send a message via Telegram requesting structured content (e.g., "Show me a comparison of K3s vs K8s in a rich table")
  - [ ] 4.2 Verify the agent uses the canvas tool to push A2UI content to the Android node
  - [ ] 4.3 Confirm rich content renders on the Android Canvas (tables, structured layouts)
  - [ ] 4.4 Test A2UI push directly via CLI: `node dist/entry.js nodes canvas a2ui push --node <id> --text "Hello Canvas"`
  - [ ] 4.5 Test canvas snapshot: `node dist/entry.js nodes canvas snapshot --node <id>`

- [ ] Task 5: Validate text fallback for messaging channels (AC: #2)
  - [ ] 5.1 Request rich content via Telegram — verify well-formatted text (markdown tables, structured text)
  - [ ] 5.2 Request rich content via Discord — verify appropriate text fallback
  - [ ] 5.3 Confirm Canvas content goes to Android node while Telegram/Discord get text

- [ ] Task 6: Verify no regressions (AC: #1, #2)
  - [ ] 6.1 Verify existing functionality: Telegram, Discord, voice (ElevenLabs), sub-agents, browser automation
  - [ ] 6.2 Verify pod stability (2/2 containers Running, no CrashLoopBackOff)
  - [ ] 6.3 Check gateway logs for new errors after node pairing

- [ ] Task 7: Update documentation (AC: #1)
  - [ ] 7.1 Update `applications/openclaw/README.md` with Android companion app + Canvas/A2UI section
  - [ ] 7.2 Document node pairing procedure (Tailscale cross-network setup)
  - [ ] 7.3 Document Canvas capabilities and channel rendering behavior

## Gap Analysis

**Scan Date:** 2026-02-03

**What Exists:**
- Canvas tool already registered in agent tool set (`dist/agents/openclaw-tools.js`)
- Canvas host enabled by default in gateway (no config needed)
- A2UI renderer exists at `/__openclaw__/a2ui` and `/__openclaw__/canvas` paths
- Canvas tool supports: `present`, `hide`, `navigate`, `eval`, `snapshot`, `a2ui_push`, `a2ui_reset`
- Tool is in `group:ui` policy group alongside `browser`
- Gateway serves A2UI static files and WebSocket connections for paired nodes

**What's Missing:**
- No paired node exists — Canvas tool requires a paired companion app (macOS/iOS/Android) as render target
- Android companion app not yet built or installed
- No node pairing configured in gateway
- A2UI bundle (`a2ui.bundle.js`) missing from `/app/dist/canvas-host/a2ui/` (exists only in `/app/src/`)

**Task Changes Applied:**
- REMOVED: Original Tasks 1-2 (research + config changes) — Canvas is already enabled, no `openclaw.json` changes needed
- ADDED: Tasks 1-2 (build Android app + pair node) — required to have a Canvas render target
- MODIFIED: Tasks 3-5 (testing) — adjusted to test via paired Android node instead of webchat
- KEPT: Tasks 6-7 (regressions + docs) — still needed

---

## Dev Notes

### Architecture Patterns & Constraints

- **Canvas requires a paired node:** The `canvas` tool calls `resolveNodeId()` for every action. Without a paired macOS/iOS/Android companion app, there is no render target.
- **Canvas host is already enabled:** Gateway starts canvas host by default (`canvasHostEnabled` = true unless `OPENCLAW_SKIP_CANVAS_HOST=1` or `canvasHost.enabled = false`). No config changes to `openclaw.json` are needed.
- **A2UI protocol:** Declarative JSON-based protocol (v0.8). Supports `surfaceUpdate`, `dataModelUpdate`, `beginRendering`, `createSurface`. Renders structured UIs on paired nodes.
- **Canvas tool actions:** `present` (show canvas), `hide`, `navigate` (load URL), `eval` (run JS), `snapshot` (capture), `a2ui_push` (push A2UI JSONL), `a2ui_reset`.
- **Android app requirements:** minSdk 31 (Android 12+), Kotlin + Jetpack Compose. Build from source — no Play Store listing yet.
- **Cross-network pairing:** Android on Tailscale can reach the gateway at k3s-worker-01's Tailscale IP. mDNS won't work cross-network; manual endpoint configuration required.
- **Shared session:** Android node uses `main` session key — chat history shared across Telegram/Discord/WebChat/Android.
- **TypeBox strict validation:** Still applies — do NOT add unknown keys to `openclaw.json`. Canvas does not need config changes.

### Config Editing Pattern (from Story 23.3)

```bash
# No openclaw.json changes needed for Canvas — it's already enabled
# If needed for future tuning:
kubectl exec -n apps deployment/openclaw -c openclaw -- \
  node -e "
    const fs = require('fs');
    const cfg = JSON.parse(fs.readFileSync('/home/node/.openclaw/openclaw.json'));
    // canvasHost config (optional, only if overriding defaults):
    // cfg.canvasHost = { enabled: true, root: '/custom/path' };
    fs.writeFileSync('/home/node/.openclaw/openclaw.json', JSON.stringify(cfg, null, 2));
  "
kubectl rollout restart deployment/openclaw -n apps
```

### Node Management Commands

```bash
# List nodes
kubectl exec -n apps deployment/openclaw -c openclaw -- node dist/entry.js nodes status

# List pending pairing requests
kubectl exec -n apps deployment/openclaw -c openclaw -- node dist/entry.js nodes pending

# Approve pairing
kubectl exec -n apps deployment/openclaw -c openclaw -- node dist/entry.js nodes approve <requestId>

# Describe node capabilities
kubectl exec -n apps deployment/openclaw -c openclaw -- node dist/entry.js nodes describe <nodeId>

# Test canvas
kubectl exec -n apps deployment/openclaw -c openclaw -- node dist/entry.js nodes canvas a2ui push --node <id> --text "Test"
kubectl exec -n apps deployment/openclaw -c openclaw -- node dist/entry.js nodes canvas snapshot --node <id>
```

### Previous Story Intelligence (Story 23.3 — Browser Automation)

- Config changes require pod restart — but no config changes needed for this story
- `memory-lancedb` plugin load failure is pre-existing, not related
- Pod restart takes ~2s for channels to reconnect
- Always test on actual messaging channels for end-to-end validation
- Verify existing functionality after any changes

### Git Intelligence (Recent Commits)

```
48322a4 feat: enable browser automation and noVNC ingress for OpenClaw (Epic 23, Story 23.3)
bfde90e feat: enable voice interaction and sub-agent routing for OpenClaw (Epic 23, Stories 23.1-23.2)
```

### Project Structure Notes

- `applications/openclaw/deployment.yaml` — No changes needed
- `applications/openclaw/service.yaml` — No changes needed
- `applications/openclaw/ingressroute.yaml` — No changes needed
- `applications/openclaw/README.md` — Update with Android node + Canvas docs

### References

- [Source: docs/planning-artifacts/epics.md#Epic 23, Story 23.4]
- [Source: docs/planning-artifacts/architecture.md#OpenClaw Architecture]
- [Source: docs/planning-artifacts/prd.md#FR176]
- [Source: https://docs.openclaw.ai/platforms/android]
- [Source: https://github.com/openclaw/openclaw/tree/main/apps/android]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.5 (claude-opus-4-5-20251101)

### Debug Log References

### Completion Notes List

### File List
