---
title: 'OpenClaw Chrome Extension with Local Node Host'
slug: 'openclaw-chrome-ext-node-host'
created: '2026-02-03'
status: 'ready-for-dev'
stepsCompleted: [1, 2, 3, 4]
tech_stack:
  - openclaw-cli (npm package)
  - chrome-extension (MV3, unpacked)
  - systemd user service
  - node.js v22+
files_to_modify:
  - ~/.openclaw/node.json (created by openclaw node)
  - ~/.config/systemd/user/openclaw-node.service (new)
  - /home/node/.openclaw/openclaw.json (on K8s PVC - add chrome profile)
code_patterns:
  - Node host connects outbound to gateway via WebSocket (wss://openclaw.home.jetzinger.com)
  - Chrome extension connects to local relay (localhost:18792)
  - Gateway auto-routes browser calls to paired node with browser proxy
  - Pairing requires approval via `openclaw nodes approve <requestId>`
  - Config editing via kubectl exec with Node.js inline scripts
test_patterns:
  - Manual verification via Telegram conversation
  - Browser automation test on safe page first, then facebook.com
---

# Tech-Spec: OpenClaw Chrome Extension with Local Node Host

**Created:** 2026-02-03

## Overview

### Problem Statement

Need to automate Facebook Business Manager ad campaign creation via OpenClaw, but Facebook requires Tom's logged-in browser session. The K8s-hosted sandbox browser (`sandbox-browser` sidecar) is isolated and won't have access to Tom's FB login cookies/session.

### Solution

Install OpenClaw CLI on the local desktop machine (this machine), run a node host that connects outbound to the K8s gateway via WebSocket/Tailscale, and install the Chrome extension that connects to the local relay. The agent can then control Tom's desktop Chrome tabs where he's logged into Facebook Business Manager.

### Scope

**In Scope:**
- Install OpenClaw CLI on local machine via npm
- Run `openclaw node` connecting to K8s gateway (wss://openclaw.home.jetzinger.com)
- Approve node pairing from K8s gateway
- Set up systemd user service for auto-start on login
- Install Chrome extension (load unpacked in developer mode)
- Add `chrome` browser profile to gateway config pointing at node
- Test controlling local tabs via Telegram/Discord conversation

**Out of Scope:**
- K8s deployment changes (no relay port exposure needed — node connects outbound)
- Replacing sandbox browser (keep both profiles: `sandbox` for clean tasks, `chrome` for logged-in)
- Facebook API integration (pure browser automation approach)
- Storing Facebook credentials in cluster

## Context for Development

### Codebase Patterns

- OpenClaw gateway runs in K8s at `openclaw.home.jetzinger.com` (port 18789 via Traefik ingress)
- Gateway already has `sandbox` browser profile for the sidecar (CDP at localhost:9222)
- Traefik handles WebSocket upgrades natively — no middleware needed
- Node host architecture: node connects outbound via WSS, gateway proxies browser commands
- Node automatically advertises browser proxy (relay at localhost:18792)
- Chrome extension uses Chrome DevTools Protocol (CDP) via local relay
- Config editing pattern: `kubectl exec` with Node.js inline scripts to modify `openclaw.json` on PVC
- Pending node pair requests expire after 5 minutes

### Files to Reference

| File | Purpose |
| ---- | ------- |
| `applications/openclaw/deployment.yaml` | K8s deployment (no changes needed) |
| `applications/openclaw/ingressroute.yaml` | Traefik ingress for gateway WebSocket |
| `applications/openclaw/service.yaml` | ClusterIP service exposing port 18789 |
| `/home/node/.openclaw/openclaw.json` (on PVC) | Gateway config — add `chrome` profile |
| `~/.openclaw/node.json` | Local node config (created by openclaw node) |
| `~/.openclaw/exec-approvals.json` | Local execution approvals |
| `~/.config/systemd/user/openclaw-node.service` | New systemd user service (to create) |

### Technical Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Architecture** | Local Node Host | Documented approach, relay stays local, no K8s changes |
| **Node Transport** | WSS via Traefik ingress | Secure TLS, uses existing ingress, no port exposure needed |
| **Service Manager** | systemd user service | Auto-start on login, standard Linux, no root needed |
| **Browser Profiles** | Keep both `sandbox` + `chrome` | Different use cases — clean vs logged-in |
| **Extension Install** | Unpacked (developer mode) | Official method, updates via `openclaw browser extension install` |
| **Node ID** | Auto-generated | Let OpenClaw manage node identity |

## Implementation Plan

### Tasks

- [ ] **Task 1: Install OpenClaw CLI**
  - Action: Install globally via npm
  - Command: `npm install -g openclaw@latest`
  - Verify: `openclaw --version` returns version info
  - Notes: Requires Node.js ≥22 (already installed: v22.21.1)

- [ ] **Task 2: Add chrome browser profile to gateway config**
  - File: `/home/node/.openclaw/openclaw.json` (on K8s PVC)
  - Action: Add `chrome` profile with `driver: "extension"` and empty `cdpUrl`
  - Command:
    ```bash
    kubectl exec -n apps deployment/openclaw -c openclaw -- \
      node -e "
        const fs = require('fs');
        const cfg = JSON.parse(fs.readFileSync('/home/node/.openclaw/openclaw.json'));
        cfg.browser.profiles.chrome = {
          driver: 'extension',
          cdpUrl: ''
        };
        fs.writeFileSync('/home/node/.openclaw/openclaw.json', JSON.stringify(cfg, null, 2));
        console.log('Chrome browser profile added');
      "
    ```
  - Notes: Empty `cdpUrl` tells gateway to use node's browser proxy

- [ ] **Task 3: Restart gateway to pick up config**
  - Action: Rolling restart of OpenClaw deployment
  - Command: `kubectl rollout restart deployment/openclaw -n apps`
  - Verify: `kubectl get pods -n apps -l app.kubernetes.io/name=openclaw` shows 2/2 Running
  - Notes: Takes ~30s for channels to reconnect

- [ ] **Task 4: Start node host in foreground (test connection)**
  - Action: Run node connecting to gateway with TLS
  - Command: `openclaw node run --host openclaw.home.jetzinger.com --tls`
  - Verify: Logs show "Connected to gateway" or similar
  - Notes: Keep this terminal open; pairing request valid for 5 minutes

- [ ] **Task 5: Approve node pairing from gateway**
  - Action: List pending requests and approve the node
  - Commands:
    ```bash
    # List pending (in another terminal)
    kubectl exec -n apps deployment/openclaw -c openclaw -- openclaw nodes pending

    # Approve (use the requestId from pending list)
    kubectl exec -n apps deployment/openclaw -c openclaw -- openclaw nodes approve <requestId>
    ```
  - Verify: Node terminal shows "Paired successfully" or reconnects with token
  - Notes: Must be done within 5 minutes of Task 4

- [ ] **Task 6: Verify node is paired and connected**
  - Action: Check node status from gateway
  - Command: `kubectl exec -n apps deployment/openclaw -c openclaw -- openclaw nodes status`
  - Verify: Node appears in list with "connected" status
  - Notes: Can stop the foreground node after verification (Ctrl+C)

- [ ] **Task 7: Install Chrome extension files**
  - Action: Install extension to local path
  - Command: `openclaw browser extension install`
  - Verify: `openclaw browser extension path` returns `~/.openclaw/extensions/chrome-relay/`
  - Notes: Creates manifest.json and extension files

- [ ] **Task 8: Load extension in Chrome (manual)**
  - Action: Load unpacked extension in Chrome developer mode
  - Steps:
    1. Open Chrome, go to `chrome://extensions`
    2. Enable "Developer mode" (top-right toggle)
    3. Click "Load unpacked"
    4. Select path from Task 7 (`~/.openclaw/extensions/chrome-relay/`)
    5. Pin the extension to toolbar
  - Verify: Extension icon appears in toolbar (should show "!" until relay is running)
  - Notes: Manual step — cannot be automated

- [ ] **Task 9: Create systemd user service**
  - File: `~/.config/systemd/user/openclaw-node.service`
  - Action: Create service file for auto-start on login
  - Content:
    ```ini
    [Unit]
    Description=OpenClaw Node Host
    After=network-online.target
    Wants=network-online.target

    [Service]
    Type=simple
    ExecStart=/home/tt/.local/share/npm/bin/openclaw node run --host openclaw.home.jetzinger.com --tls
    Restart=on-failure
    RestartSec=10
    Environment=NODE_ENV=production

    [Install]
    WantedBy=default.target
    ```
  - Notes: Adjust ExecStart path based on where npm installed openclaw

- [ ] **Task 10: Enable and start systemd service**
  - Action: Enable service for auto-start and start it now
  - Commands:
    ```bash
    systemctl --user daemon-reload
    systemctl --user enable openclaw-node.service
    systemctl --user start openclaw-node.service
    ```
  - Verify: `systemctl --user status openclaw-node.service` shows "active (running)"
  - Notes: Service runs as user, no sudo needed

- [ ] **Task 11: Test browser control via Telegram**
  - Action: Verify agent can control attached Chrome tabs
  - Steps:
    1. Start Chrome (if not running)
    2. Navigate to a test page (e.g., `https://example.com`)
    3. Click extension icon on that tab to attach
    4. Send message to Telegram bot: "use my chrome browser to read the page title"
    5. Verify agent returns "Example Domain" or similar
  - Verify: Agent successfully reads and reports page content
  - Notes: Extension icon should change from "!" to checkmark when attached

- [ ] **Task 12: Test form interaction**
  - Action: Verify agent can click and type
  - Steps:
    1. Navigate to a form page (e.g., `https://www.google.com`)
    2. Attach extension to tab
    3. Ask agent: "use my chrome browser to type 'hello world' in the search box"
    4. Verify text appears in search box
  - Verify: Agent successfully types in the form field
  - Notes: Test on safe pages before Facebook Business Manager

### Acceptance Criteria

- [ ] **AC1:** Given OpenClaw CLI is installed, when `openclaw --version` is run, then version info is displayed (e.g., "2026.2.x")

- [ ] **AC2:** Given the gateway config is updated, when the gateway restarts, then `browser.profiles.chrome` exists with `driver: "extension"`

- [ ] **AC3:** Given the node host is running, when it connects to the gateway, then a pending pair request appears in `openclaw nodes pending`

- [ ] **AC4:** Given a pending pair request exists, when `openclaw nodes approve <id>` is run, then the node becomes paired and shows in `openclaw nodes status`

- [ ] **AC5:** Given the Chrome extension is loaded, when the extension icon is clicked on a tab, then the tab becomes attached (icon changes state)

- [ ] **AC6:** Given a tab is attached and node is connected, when the user asks the agent "read the page title from my chrome browser", then the agent returns the correct page title

- [ ] **AC7:** Given a tab is attached, when the user asks the agent to type text in a form field, then the text appears in the browser

- [ ] **AC8:** Given the systemd service is enabled, when the user logs in, then `openclaw node` starts automatically and connects to the gateway

- [ ] **AC9:** Given both browser profiles exist, when the user specifies "sandbox" or "chrome", then the agent uses the correct browser (isolated K8s vs local desktop)

## Additional Context

### Dependencies

| Dependency | Status | Notes |
|------------|--------|-------|
| OpenClaw Gateway (K8s) | ✅ Running | `openclaw.home.jetzinger.com` |
| Tailscale | ✅ Running | This machine: `x1` (100.120.108.72) |
| Node.js ≥22 | ✅ v22.21.1 | Meets requirement |
| Chrome | ✅ Installed | On this machine |
| OpenClaw CLI | ❌ Not installed | Task 1 |
| npm | ✅ Available | Comes with Node.js |
| systemd user session | ✅ Available | Standard on Linux desktop |

### Testing Strategy

**Manual Testing:**
1. Install CLI, verify `openclaw --version` works
2. Start node in foreground, verify it connects (check logs)
3. Approve pairing from K8s gateway within 5 minutes
4. Verify node shows as paired: `openclaw nodes status`
5. Install Chrome extension, verify toolbar icon appears
6. Attach extension to a test tab (e.g., example.com)
7. Ask agent via Telegram: "read the page title from my chrome browser"
8. Verify agent can read content from attached tab
9. Test clicking and typing on a safe page (Google search)
10. Navigate to facebook.com, test basic interaction
11. Set up systemd service, verify auto-start on login
12. Reboot or logout/login, verify node reconnects automatically

**No Automated Tests:** This is infrastructure setup with manual verification.

### Notes

**Security Considerations:**
- The relay only listens on localhost:18792 — never exposed to network
- Extension requires explicit attachment per tab (click toolbar icon)
- If attached to main Chrome profile, agent has access to all logged-in sessions
- Consider using a dedicated Chrome profile for FB automation if security is a concern
- Node stores pairing token at `~/.openclaw/` — treat as sensitive

**Operational Notes:**
- Pending pair requests expire after 5 minutes — approve quickly!
- To use chrome profile in conversation: "use my chrome browser to..."
- Gateway auto-routes to node with browser proxy if `chrome` profile is used
- If extension shows "!" it means relay not running — check node service
- Both profiles remain available: `sandbox` for clean tasks, `chrome` for logged-in

**Future Considerations (Out of Scope):**
- Dedicated Chrome profile for FB automation (more isolation)
- Multiple node hosts on different machines
- Automated FB campaign templates via conversation
