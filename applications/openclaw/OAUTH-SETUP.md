# OpenClaw OAuth Setup: Claude Max Subscription

This guide covers obtaining an Anthropic OAuth token via Claude Max and configuring it for a headless OpenClaw gateway running in Kubernetes.

## Prerequisites

- Active Claude Pro or Max subscription
- Claude Code CLI installed locally (`npm install -g @anthropic-ai/claude-code`)
- `kubectl` access to the cluster with the OpenClaw deployment
- OpenClaw gateway already deployed (Story 21.1) with NFS persistence

## Step 1: Obtain the OAuth Token

On your **local machine** (not the K8s pod), run:

```bash
claude setup-token
```

This opens a browser window for the Anthropic OAuth flow. Complete the authorization and the CLI will display a token starting with `sk-ant-oat01-...`.

Copy the full token. Tokens obtained this way are valid for approximately 1 year.

### Token Format

| Prefix | Type | Header |
|--------|------|--------|
| `sk-ant-oat01-...` | OAuth token (subscription) | `Authorization: Bearer <token>` |
| `sk-ant-api...` | API key (pay-as-you-go) | `x-api-key: <key>` |

OpenClaw handles both formats, but OAuth is the recommended path for Claude Max subscribers.

## Step 2: Patch the Kubernetes Secret

The `openclaw-secrets` Secret already has an `ANTHROPIC_OAUTH_TOKEN` placeholder. Patch it with the real value:

```bash
TOKEN_B64=$(echo -n 'sk-ant-oat01-YOUR-TOKEN-HERE' | base64 -w0)

kubectl patch secret openclaw-secrets -n apps --type='json' \
  -p="[{\"op\": \"replace\", \"path\": \"/data/ANTHROPIC_OAUTH_TOKEN\", \"value\": \"${TOKEN_B64}\"}]"
```

This updates the live secret without modifying any git-tracked files.

## Step 3: Write the Auth Profile on the Pod

The gateway needs an auth-profiles.json file in the agent directory. After patching the secret, exec into the pod:

```bash
kubectl exec -n apps deployment/openclaw -- node -e '
const fs = require("fs");
const dir = "/home/node/.openclaw/agents/main/agent";
fs.mkdirSync(dir, { recursive: true });

const authProfiles = {
  "anthropic:subscription": {
    provider: "anthropic",
    mode: "oauth",
    access: process.env.ANTHROPIC_OAUTH_TOKEN,
    type: "oauth"
  }
};

fs.writeFileSync(dir + "/auth-profiles.json", JSON.stringify(authProfiles, null, 2) + "\n");
console.log("Auth profile written successfully");
'
```

This reads the token from the environment variable (injected by the Secret) and writes it to the NFS-persisted credential store.

## Step 4: Configure openclaw.json

The gateway config at `/home/node/.openclaw/openclaw.json` needs the auth profile and model settings. The minimal addition to an existing config:

```json
{
  "auth": {
    "profiles": {
      "anthropic:subscription": {
        "provider": "anthropic",
        "mode": "oauth"
      }
    },
    "order": {
      "anthropic": ["anthropic:subscription"]
    }
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "anthropic/claude-opus-4-5"
      }
    }
  }
}
```

To update via kubectl exec:

```bash
kubectl exec -n apps deployment/openclaw -- node -e '
const fs = require("fs");
const path = "/home/node/.openclaw/openclaw.json";
const cfg = JSON.parse(fs.readFileSync(path, "utf8"));

cfg.auth = {
  profiles: {
    "anthropic:subscription": { provider: "anthropic", mode: "oauth" }
  },
  order: { anthropic: ["anthropic:subscription"] }
};

cfg.agents = {
  defaults: {
    model: { primary: "anthropic/claude-opus-4-5" }
  }
};

fs.writeFileSync(path, JSON.stringify(cfg, null, 2) + "\n");
console.log("Config updated");
'
```

## Step 5: Restart and Verify

Restart the deployment to pick up the new secret:

```bash
kubectl rollout restart deployment/openclaw -n apps
kubectl rollout status deployment/openclaw -n apps --timeout=90s
```

Verify the gateway started correctly:

```bash
kubectl logs -n apps deployment/openclaw --tail=20
```

Expected output includes:

```
[gateway] agent model: anthropic/claude-opus-4-5
[gateway] listening on ws://0.0.0.0:18789 (PID 1)
```

## Step 6: Test via Control UI

Open `https://openclaw.home.jetzinger.com` and send a message via WebChat. The response should come from Opus 4.5.

## Adding a LiteLLM Fallback (Optional)

To add a local LiteLLM proxy as fallback when Anthropic is unavailable, extend `openclaw.json`:

```json
{
  "models": {
    "mode": "merge",
    "providers": {
      "litellm": {
        "baseUrl": "http://litellm.ml.svc.cluster.local:4000/v1",
        "api": "openai-completions",
        "apiKey": "${LITELLM_API_KEY}",
        "models": [
          { "id": "vllm-qwen", "name": "Qwen 2.5 (vLLM GPU)", "api": "openai-completions" },
          { "id": "ollama-qwen", "name": "Qwen 2.5 (Ollama CPU)", "api": "openai-completions" }
        ]
      }
    }
  },
  "env": {
    "LITELLM_API_KEY": "your-litellm-master-key"
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "anthropic/claude-opus-4-5",
        "fallbacks": ["litellm/vllm-qwen"]
      }
    }
  }
}
```

The `LITELLM_API_KEY` must match the `LITELLM_MASTER_KEY` from the LiteLLM deployment in the `ml` namespace:

```bash
kubectl get secret litellm-secrets -n ml -o jsonpath='{.data.LITELLM_MASTER_KEY}' | base64 -d
```

## Token Renewal

The OAuth token expires after approximately 1 year. To renew:

1. Run `claude setup-token` on your local machine
2. Repeat Step 2 (patch the K8s secret)
3. Repeat Step 3 (update auth-profiles.json on the pod)
4. Restart the deployment (Step 5)

## Troubleshooting

### Config validation errors on startup

If the pod crashes with "Config invalid", check the error message for unrecognized keys. Common mistakes:

- `providers` at root level -- must be under `models.providers`
- `token` or `apiKey` inside auth profiles -- credentials go in `auth-profiles.json`, not `openclaw.json`
- Missing `models` array in custom provider -- each provider under `models.providers` requires a `models: [...]` array

Fix via a temporary pod if the main pod is crash-looping:

```bash
kubectl run openclaw-fix --rm -i --restart=Never --image=node:22-slim -n apps \
  --overrides='{
    "spec": {
      "securityContext": {"runAsUser": 1000, "runAsGroup": 1000},
      "containers": [{"name": "fix", "image": "node:22-slim",
        "command": ["node", "-e", "...your fix script..."],
        "volumeMounts": [{"name": "d", "mountPath": "/mnt", "subPath": "openclaw"}]
      }],
      "volumes": [{"name": "d", "persistentVolumeClaim": {"claimName": "openclaw-data"}}]
    }
  }'
```

### 401 Invalid bearer token

- Verify the token starts with `sk-ant-oat01-`
- Check that `auth-profiles.json` has the full token in the `access` field
- Ensure the pod was restarted after patching the secret

### No secrets in logs

The gateway redacts secrets by default. Verify with:

```bash
kubectl exec -n apps deployment/openclaw -- \
  sh -c 'grep -ic "sk-ant\|sk-litellm\|oauth" /tmp/openclaw/openclaw-*.log'
```

Expected output: `0`
