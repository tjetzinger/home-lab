# OpenClaw Device Pairing Repair

## Symptom

After an OpenClaw pod restart, the CLI fails with:

```
gateway connect failed: Error: pairing required
Error: gateway closed (1008): pairing required
```

All CLI commands (including `openclaw devices list`) fail because they require gateway connectivity.

## Root Cause

The pod restart causes the gateway to regenerate its in-memory session state. The CLI's stored device credentials become stale, triggering a re-pairing flow. The CLI sends a repair request but cannot approve it because it needs the gateway to do so — a chicken-and-egg problem.

## Diagnosis

1. Confirm WebSocket connectivity is working (not a Traefik/HTTP issue):

```bash
timeout 5 wscat -c "wss://openclaw.home.jetzinger.com" -w 5
# Should return: {"type":"event","event":"connect.challenge",...}
```

2. Check pending pairing requests on the server:

```bash
kubectl exec -n apps deployment/openclaw -c openclaw -- \
  cat /home/node/.openclaw/devices/pending.json
```

If you see an entry with `"isRepair": true`, the CLI is waiting for approval.

## Fix: Approve Pairing via PVC

Since the CLI cannot connect to approve itself, approve directly by editing the server-side JSON:

```bash
kubectl exec -n apps deployment/openclaw -c openclaw -- node -e "
const fs = require('fs');
const pending = JSON.parse(fs.readFileSync('/home/node/.openclaw/devices/pending.json', 'utf8'));
const paired = JSON.parse(fs.readFileSync('/home/node/.openclaw/devices/paired.json', 'utf8'));

const reqId = Object.keys(pending)[0];
const req = pending[reqId];
if (!req) { console.log('No pending request'); process.exit(1); }

const device = paired[req.deviceId];
if (device) {
  device.roles = req.roles;
  device.scopes = req.scopes;
  device.approvedAtMs = Date.now();
  console.log('Updated paired device:', req.deviceId.substring(0,16) + '...');
}

delete pending[reqId];

fs.writeFileSync('/home/node/.openclaw/devices/paired.json', JSON.stringify(paired, null, 2));
fs.writeFileSync('/home/node/.openclaw/devices/pending.json', JSON.stringify(pending, null, 2));
console.log('Pairing approved, pending cleared.');
"
```

## Verify

```bash
openclaw gateway health
```

Expected output: `Gateway Health OK` with channel statuses.

## Notes

- The pending request ID changes on each CLI retry, so always read the current `pending.json` dynamically (use `Object.keys(pending)[0]`)
- Device data is persisted on the `openclaw-data` PVC at `/home/node/.openclaw/devices/`
- The gateway may cache state in memory — if the file edit doesn't take effect, restart the pod: `kubectl rollout restart deployment/openclaw -n apps`
- The dashboard UI (`https://openclaw.home.jetzinger.com/#token=...`) connects as `webchat` and does not have device approval controls
