# OpenClaw Device Pairing Guide

When running the OpenClaw gateway in Kubernetes behind Traefik, the Control UI
requires a one-time device pairing before it can connect. This is because the
gateway only auto-approves connections from `localhost` or `*.ts.net` hosts.
Connections through Traefik arrive with a non-local hostname
(`openclaw.home.jetzinger.com`), so they need explicit approval.

Pairing is persisted on the NFS volume and survives pod restarts.

## Prerequisites

- OpenClaw gateway running in the `apps` namespace
- `gateway.trustedProxies` configured in `/home/node/.openclaw/openclaw.json`
  with the current Traefik pod IP (see [Proxy Setup](#proxy-setup) below)

## Option A: Port-Forward (Recommended)

The simplest approach. Local connections are auto-approved by the gateway.

```bash
# 1. Forward the gateway port to localhost
kubectl port-forward -n apps deployment/openclaw 18789:18789

# 2. Open in browser — pairing is automatic
open http://localhost:18789

# 3. Once the Control UI connects, close the port-forward (Ctrl+C)
# 4. Access via Traefik from now on — the device is paired
open https://openclaw.home.jetzinger.com
```

## Option B: CLI Approval

Approve a pending pairing request from inside the pod.

```bash
# 1. Open the Control UI via Traefik (it will show "pairing required")
open https://openclaw.home.jetzinger.com

# 2. Check for pending pairing requests
kubectl exec -n apps deployment/openclaw -- \
  cat /home/node/.openclaw/devices/pending.json

# 3. Approve the device using the gateway's approval function
kubectl exec -n apps deployment/openclaw -- node -e '
const fs = require("fs");
const crypto = require("crypto");
const dir = "/home/node/.openclaw/devices";
const pending = JSON.parse(fs.readFileSync(dir + "/pending.json", "utf8"));
const paired = JSON.parse(fs.readFileSync(dir + "/paired.json", "utf8"));
const reqId = Object.keys(pending)[0];
if (!reqId) { console.log("No pending requests"); process.exit(0); }
const req = pending[reqId];
const now = Date.now();
paired[req.deviceId] = {
  deviceId: req.deviceId, publicKey: req.publicKey,
  platform: req.platform, clientId: req.clientId,
  clientMode: req.clientMode, role: req.role,
  roles: req.roles, scopes: req.scopes,
  remoteIp: req.remoteIp,
  tokens: { operator: { token: crypto.randomBytes(32).toString("hex"),
    role: "operator", scopes: req.scopes, createdAtMs: now } },
  createdAtMs: now, approvedAtMs: now
};
delete pending[reqId];
fs.writeFileSync(dir + "/paired.json", JSON.stringify(paired, null, 2));
fs.writeFileSync(dir + "/pending.json", JSON.stringify(pending, null, 2));
console.log("Approved device:", req.deviceId.substring(0, 16) + "...");
'

# 4. Refresh the Control UI — it should connect
```

## Option C: Onboard Inside the Pod

Run the interactive onboard wizard inside the pod (sets up gateway config
and auto-pairs the CLI as a local device).

```bash
kubectl exec -it -n apps deployment/openclaw -- \
  node /app/dist/index.js onboard
```

## Proxy Setup

The gateway must trust Traefik as a reverse proxy. Without this, all proxied
connections are rejected as untrusted.

```bash
# 1. Find the current Traefik pod IP
kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik \
  -o jsonpath='{.items[0].status.podIP}'

# 2. Write the gateway config (replace IP as needed)
kubectl exec -n apps deployment/openclaw -- sh -c '
cat > /home/node/.openclaw/openclaw.json << EOF
{
  "gateway": {
    "trustedProxies": ["10.42.4.37"]
  }
}
EOF'

# 3. Restart the gateway to pick up config (or it hot-reloads on next connection)
kubectl rollout restart deployment/openclaw -n apps
```

**Note:** `trustedProxies` uses exact IP matching (no CIDR support). If the
Traefik pod IP changes (e.g., after node reschedule), update the config.

## Telegram DM Access Control

Telegram DM access is managed separately from device pairing. The gateway
supports two policies configured via `channels.telegram.dmPolicy` in
`openclaw.json`:

### Allowlist Mode (Current Setup)

DM access is controlled by a static list of Telegram user IDs. Only listed
users receive responses; all others are silently ignored.

```bash
# Add a user: edit openclaw.json on the NFS volume
kubectl exec -n apps deployment/openclaw -- node -e '
const fs = require("fs");
const p = "/home/node/.openclaw/openclaw.json";
const c = JSON.parse(fs.readFileSync(p, "utf8"));
c.channels.telegram.allowFrom.push("NEW_USER_ID");
fs.writeFileSync(p, JSON.stringify(c, null, 2));
console.log("Updated allowFrom:", c.channels.telegram.allowFrom);
'

# Restart to apply (or wait for hot-reload)
kubectl rollout restart deployment/openclaw -n apps
```

### Pairing Mode (Alternative)

Set `dmPolicy: "pairing"` to require a one-time pairing code. Unknown users
receive an 8-character code (expires after 1 hour) that the operator approves.

```bash
# List pending Telegram pairing requests
kubectl exec -n apps deployment/openclaw -- \
  node dist/index.js pairing list telegram

# Approve a pairing request
kubectl exec -n apps deployment/openclaw -- \
  node dist/index.js pairing approve telegram <CODE>
```

Approved senders are stored in `~/.openclaw/credentials/` and persist across
pod restarts via NFS.

## When Re-Pairing Is Needed

- Browser data cleared (device key is stored in localStorage)
- Different browser or device
- `paired.json` deleted from NFS
- NFS volume recreated

Pairing is **not** needed after:
- Pod restarts (NFS persists state)
- Gateway config changes
- Deployment updates
