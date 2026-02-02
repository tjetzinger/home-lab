# OpenClaw Gateway

AI-powered Telegram bot gateway with LanceDB long-term memory and Playwright browser automation.

## Architecture

```
Pod: openclaw (apps namespace, k3s-worker-01)
+-- initContainer: fix-permissions (busybox:1.37)
|   chown PVC dirs, create LanceDB dir
+-- container: openclaw (openclaw:2026.2.1)
|   ports: 18789 (gateway), 18790 (bridge)
|   volumes: PVC -> /home/node/.openclaw, /home/node/clawd
|   connects to browser via localhost:9222
+-- container: sandbox-browser (openclaw-sandbox-browser:bookworm-slim)
    ports: 9222 (CDP), 5900 (VNC), 6080 (noVNC)
    volume: /dev/shm (emptyDir, 256Mi)
```

- **Namespace**: `apps`
- **LLM**: Anthropic Claude Opus 4.5 (via LiteLLM)
- **Memory**: LanceDB with text-embedding-3-small
- **Browser**: Chromium via CDP sidecar (Playwright-compatible)
- **Telegram**: `@moltbot_homelab_bot`
- **Storage**: 10Gi PVC on NFS

## Build

Both images are built from official OpenClaw source (no custom Dockerfiles):

```bash
cd applications/openclaw
./build.sh
```

This clones the OpenClaw repo at `v2026.2.1`, builds:
- `openclaw:2026.2.1` from the official `Dockerfile`
- `openclaw-sandbox-browser:bookworm-slim` from `Dockerfile.sandbox-browser`

Both images are transferred to `k3s-worker-01` via `ctr`.

## Deploy

```bash
./deploy.sh
```

## Post-Deploy: Browser Configuration

Add browser config to the existing `openclaw.json` on the PVC:

```bash
kubectl exec -n apps deployment/openclaw -c openclaw -- \
  node -e "
    const fs = require('fs');
    const cfg = JSON.parse(fs.readFileSync('/home/node/.openclaw/openclaw.json'));
    cfg.browser = {
      enabled: true,
      defaultProfile: 'sandbox',
      profiles: {
        sandbox: { cdpUrl: 'http://localhost:9222' }
      }
    };
    fs.writeFileSync('/home/node/.openclaw/openclaw.json', JSON.stringify(cfg, null, 2));
    console.log('Browser config added');
  "
```

Then restart the pod:

```bash
kubectl rollout restart deployment/openclaw -n apps
```

## Verify

```bash
# Both containers running (expect 2/2)
kubectl get pods -n apps -l app.kubernetes.io/name=openclaw

# Main container logs
kubectl logs -n apps deployment/openclaw -c openclaw --tail=20

# Browser sidecar logs
kubectl logs -n apps deployment/openclaw -c sandbox-browser --tail=20

# CDP endpoint accessible from main container
kubectl exec -n apps deployment/openclaw -c openclaw -- \
  curl -s http://localhost:9222/json/version

# Browser config
kubectl exec -n apps deployment/openclaw -c openclaw -- \
  node -e "const c=require('/home/node/.openclaw/openclaw.json'); console.log(JSON.stringify(c.browser, null, 2))"
```

## Browser Debugging (VNC)

Port-forward the noVNC web interface for visual browser debugging:

```bash
kubectl port-forward -n apps deployment/openclaw 6080:6080
# Open http://localhost:6080
```

## Configuration

### Environment (openclaw-secrets)

```yaml
ANTHROPIC_API_KEY: <key>
OPENAI_API_KEY: <key>
TELEGRAM_BOT_TOKEN: <token>
```

### Memory Storage

- **Path**: `/home/node/.openclaw/memory/lancedb`
- **Model**: text-embedding-3-small
- **Provider**: OpenAI

## Resource Limits

| Container | CPU | Memory |
|-----------|-----|--------|
| openclaw | 250m-1000m | 512Mi-2Gi |
| sandbox-browser | 250m-1000m | 256Mi-1Gi |

## Node Assignment

Pinned to `k3s-worker-01` via nodeAffinity.

## Rollback

```bash
kubectl rollout undo deployment/openclaw -n apps
```
