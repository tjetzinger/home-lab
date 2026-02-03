# ADR-011: OpenClaw Personal AI Assistant

**Status:** Accepted
**Date:** 2026-02-03
**Decision Makers:** Tom, Claude (AI Assistant)

## Context

The home-lab platform needed a personal AI assistant capability that goes beyond the existing Open-WebUI chat interface. The requirements were:

- Accessible via messaging platforms (Telegram, Discord) for mobile and desktop convenience
- Frontier-quality reasoning using Claude Opus 4.5 as the primary LLM
- High availability with graceful degradation to local inference when cloud APIs are unavailable
- Integration with the existing LiteLLM/vLLM/Ollama infrastructure
- Long-term memory that persists across conversations
- Secure access without public API exposure

The existing infrastructure provided:
- LiteLLM proxy with three-tier fallback (vLLM GPU → Ollama CPU → OpenAI cloud)
- Tailscale VPN for secure remote access
- Loki/Prometheus/Grafana observability stack
- NFS and local-path storage options

## Decision Drivers

- **Reasoning quality** - Need frontier model capabilities for complex tasks
- **Availability** - Should work even when cloud APIs are rate-limited or unavailable
- **Security** - No public API exposure, single-user lockdown
- **Operational simplicity** - Reuse existing observability and infrastructure patterns
- **Mobile accessibility** - Chat via phone without VPN connection to web UI

## Considered Options

### Option 1: Web-Only Chat Interface (Open-WebUI)

**Pros:**
- Already deployed and working (https://chat.home.jetzinger.com)
- Supports multiple LLM backends via LiteLLM
- Full conversation history and model switching

**Cons:**
- Requires Tailscale VPN connection for access
- No mobile notifications or proactive messaging
- No long-term memory across sessions
- Limited to web browser interaction

### Option 2: OpenClaw with Local-Only LLM

**Pros:**
- No cloud API costs or dependencies
- Complete data sovereignty
- Works offline

**Cons:**
- Limited reasoning quality compared to frontier models
- Qwen 2.5 7B/14B significantly less capable than Opus 4.5
- No benefit from existing Claude Code subscription

### Option 3: OpenClaw with Cloud-Primary + Local Fallback (Selected)

**Pros:**
- Frontier reasoning quality with Opus 4.5 as primary
- Graceful degradation to local models when cloud unavailable
- Messaging channel access without VPN (outbound-only connections)
- Long-term memory via LanceDB
- Leverages existing Claude Code subscription (Anthropic OAuth)

**Cons:**
- Cloud API dependency for best experience
- Additional complexity managing multiple LLM backends
- Requires API credentials management

## Decision

Deploy OpenClaw gateway on K3s with the following architecture:

### Deployment Architecture

**Kubernetes Deployment:**
- Single-pod Deployment in `apps` namespace
- Node affinity to `k3s-worker-01` (highest resource CPU worker)
- Official `openclaw/openclaw` Docker image (Node.js >= 22)
- Resource limits: Reasonable CPU/memory for gateway operations

**Manifests:**
```
applications/openclaw/
├── deployment.yaml      # Pod spec with node affinity
├── service.yaml         # ClusterIP service on port 18789
├── ingressroute.yaml    # Traefik IngressRoute for HTTPS
├── pvc.yaml             # Local PVC for persistence
└── secret.yaml          # K8s Secret for credentials
```

### Inverse Fallback LLM Pattern

Unlike typical setups where local models are primary and cloud is fallback, OpenClaw uses an "inverse fallback" pattern:

```
┌─────────────────────────────────────────────────────────────────┐
│                     OpenClaw Gateway                             │
│                                                                  │
│   ┌─────────────────┐                                           │
│   │  Agent Engine   │                                           │
│   └────────┬────────┘                                           │
│            │                                                     │
│            ▼                                                     │
│   ┌─────────────────┐    ┌─────────────────────────────────┐   │
│   │  Claude Opus    │    │         LiteLLM Fallback        │   │
│   │    4.5          │───▶│  (litellm.ml.svc:4000)          │   │
│   │  (PRIMARY)      │    │                                  │   │
│   │                 │    │  ┌─────┐  ┌──────┐  ┌────────┐  │   │
│   │  Anthropic OAuth│    │  │vLLM │─▶│Ollama│─▶│ OpenAI │  │   │
│   └─────────────────┘    │  │(GPU)│  │(CPU) │  │(Cloud) │  │   │
│                          │  └─────┘  └──────┘  └────────┘  │   │
│                          └─────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

**Rationale:** Best reasoning quality (Opus 4.5) for primary use, with the existing three-tier local stack as fallback. This ensures the best possible responses while maintaining availability.

### Outbound-Only Channel Networking

All messaging channels use outbound connections initiated from inside the cluster:

| Channel | Protocol | Connection Type |
|---------|----------|-----------------|
| Telegram | HTTPS | Long-polling (getUpdates API) |
| Discord | WebSocket | Outbound gateway connection |
| Web UI | HTTPS | Traefik IngressRoute |

**Security Benefits:**
- No inbound firewall rules required
- No webhook URLs to expose or manage
- No DNS requirements for callback URLs
- Tailscale VPN-only access preserved for web UI
- Messaging works without VPN (channels connect outbound)

### Log-Based Observability Pattern

OpenClaw does not expose a native Prometheus `/metrics` endpoint. Instead, we use a hybrid observability approach:

**Log Collection (Story 24.1):**
- Promtail collects stdout/stderr from OpenClaw pod
- Logs shipped to Loki with labels: `namespace=apps`, `app_kubernetes_io_name=openclaw`
- Log format: `TIMESTAMP [component] message`
- Components: `[gateway]`, `[telegram]`, `[discord]`, `[ws]`, `[openclaw]`, `[canvas]`, `[heartbeat]`

**Grafana Dashboard:**
- LogQL queries for message volume, error rates, channel activity
- Panels: Messages by channel, LLM provider usage, error rates, session activity

**Uptime Monitoring (Story 24.2):**
- Blackbox Exporter HTTP probe on internal service URL
- 30-second probe interval
- Metrics: `probe_success`, `probe_duration_seconds`, `probe_http_status_code`

**Alerting:**
- `OpenClawGatewayDown` (P1): Fires after 90s of consecutive probe failures
- Log-based P2 alerts configured via Grafana Alerting (Loki ruler not available in SingleBinary mode)

### Local PVC Persistence Strategy

**Storage Class:** `local-path` (K3s built-in provisioner)
**Capacity:** 10Gi
**Node Affinity:** Bound to `k3s-worker-01`

**Persisted Data:**
```
~/.openclaw/           # Gateway configuration
├── openclaw.json     # Main config file
└── ...

~/clawd/              # Agent workspace
├── mcporter/         # MCP tool configurations
├── sessions/         # Conversation session data
└── ...

~/.lancedb/           # Long-term memory index
└── memory/           # Vector embeddings (OpenAI text-embedding-3-small)
```

**Backup Strategy:**
- Velero cluster backups include OpenClaw PVC
- Local-path storage on k3s-worker-01 filesystem
- Configuration reproducible from K8s manifests + secrets

### Security Model

**Credential Management:**
- All secrets stored in K8s Secret `openclaw-secrets`
- 9 secret keys: Anthropic OAuth, Telegram bot token, Discord bot token, ElevenLabs API key, Exa API key, OpenAI API key (embeddings), LiteLLM fallback URL, gateway auth token, WhatsApp (placeholder)

**Access Control:**
- DM allowlist-only pairing for Telegram and Discord
- Single-user lockdown across all channels
- Web UI requires Tailscale VPN access
- No public API endpoints

**Network Security:**
- All external connections are outbound-only
- Cluster-internal service for health probes
- Traefik IngressRoute with TLS termination

## Consequences

### Positive

- **Best reasoning quality** - Opus 4.5 provides frontier-level capabilities
- **High availability** - Automatic fallback to local models ensures uptime
- **Mobile accessibility** - Telegram/Discord access without VPN
- **Long-term memory** - LanceDB preserves context across conversations
- **Operational consistency** - Reuses existing Loki/Grafana observability patterns
- **Security maintained** - No public API exposure, VPN-only web access

### Negative

- **Cloud dependency** - Best experience requires Anthropic API availability
- **Complexity** - Multiple LLM backends to configure and maintain
- **Local storage risk** - PVC on single node (mitigated by Velero backups)
- **No native metrics** - Requires log-based observability workarounds

### Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Anthropic API outage | Automatic fallback to LiteLLM three-tier stack |
| k3s-worker-01 failure | Velero backups, config reproducible from Git |
| Credential exposure | K8s Secrets, no credentials in Git, secret rotation capability |
| DM spam/abuse | Allowlist-only pairing, single-user lockdown |
| Memory index corruption | LanceDB supports rebuild from conversation history |

## Implementation Notes

**Deployment:**
```bash
# Apply OpenClaw manifests
kubectl apply -f applications/openclaw/

# Verify pod running
kubectl get pods -n apps -l app.kubernetes.io/name=openclaw

# Check logs
kubectl logs -n apps -l app.kubernetes.io/name=openclaw -f
```

**Health Check:**
```bash
# JSON health snapshot
kubectl exec -n apps deploy/openclaw -c openclaw -- \
  node dist/entry.js health --json
```

**Configuration via Control UI:**
- Access: https://openclaw.home.jetzinger.com (Tailscale required)
- Configure channels, LLM providers, MCP tools via web interface
- Changes persist to local PVC

## References

- [OpenClaw Documentation](https://openclaw.dev/)
- [Story 21.1: Deploy OpenClaw Gateway](../implementation-artifacts/21-1-deploy-openclaw-gateway-with-local-persistence.md)
- [Story 24.1: Loki Log Collection & Grafana Dashboard](../implementation-artifacts/24-1-configure-loki-log-collection-and-grafana-dashboard.md)
- [Story 24.2: Blackbox Exporter & Alertmanager Rules](../implementation-artifacts/24-2-configure-blackbox-exporter-and-alertmanager-rules.md)
- [Architecture Decision Document - OpenClaw Section](../planning-artifacts/architecture.md#openclaw-personal-ai-assistant-architecture)
