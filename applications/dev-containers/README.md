# Dev Containers Platform

Standardized development containers with SSH access for remote development using VS Code Remote-SSH or similar tools.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        ai-dev (TEMPLATE)                         │
│  PVC: dev-home-ai-dev mounted at /home/dev                       │
│  Contains: .claude.json (MCP config), .bashrc, tools config      │
└─────────────────────────────────────────────────────────────────┘
                              │
                    (init container copies)
                              │
        ┌─────────────────────┼─────────────────────┐
        ▼                     ▼                     ▼
┌───────────────┐   ┌───────────────┐   ┌───────────────┐
│    belego     │   │    pilates    │   │  (new devs)   │
│ Own PVC copy  │   │ Own PVC copy  │   │ Own PVC copy  │
└───────────────┘   └───────────────┘   └───────────────┘
```

**Key Points:**
- **ai-dev** is the template - configure it once, all new containers inherit
- Each container gets **own PVC** copied from ai-dev on first boot
- Config changes to ai-dev propagate to new containers only
- PVC mounted at `/home/dev` (entire home directory persisted)

## Images

| Image | Description |
|-------|-------------|
| `dev-container-base:latest` | Ubuntu 22.04 base with Node.js, Python, kubectl, helm, Claude CLI |
| `dev-container-ai:latest` | Extends base with Bun, OpenCode, exa-mcp-server (system-wide) |

### AI Image Contents

The `dev-container-ai:latest` image includes everything in base plus:

- **Bun**: Fast JavaScript runtime (`/opt/bun/`)
- **OpenCode**: AI coding assistant (`/opt/opencode/`)
- **exa-mcp-server**: Web search MCP (global npm)
- **agent-browser**: Browser automation MCP (global npm)

## Building Images

```bash
cd applications/dev-containers/base-image

# Build base image
docker build -t dev-container-base:latest .

# Build AI image
docker build -f Dockerfile.ai -t dev-container-ai:latest .

# Push to k3s nodes
docker save dev-container-ai:latest | ssh k3s-worker-01 "sudo ctr -n k8s.io images import -"
```

## SSH Access

SSH access is provided through the nginx proxy LoadBalancer.

| Container | Port | IP |
|-----------|------|----|
| Belego | 2222 | 192.168.2.101 |
| Pilates | 2223 | 192.168.2.101 |
| AI-Dev | 2224 | 192.168.2.101 |

**Connect via SSH:**
```bash
ssh -p 2222 dev@192.168.2.101  # Belego
ssh -p 2223 dev@192.168.2.101  # Pilates
ssh -p 2224 dev@192.168.2.101  # AI-Dev (template)
```

**VS Code SSH Config (~/.ssh/config):**
```
Host dev-belego
    HostName 192.168.2.101
    Port 2222
    User dev

Host dev-pilates
    HostName 192.168.2.101
    Port 2223
    User dev

Host dev-ai-dev
    HostName 192.168.2.101
    Port 2224
    User dev
```

## Template System

### How It Works

1. **ai-dev** is the template container with PVC at `/home/dev`
2. Configure ai-dev once (MCP servers, API keys, tools, etc.)
3. New containers use init container to copy from ai-dev PVC
4. Each container gets independent copy - changes don't sync after creation

### Updating the Template

```bash
# SSH into ai-dev
ssh -p 2224 dev@192.168.2.101

# Make configuration changes (e.g., add MCP server)
claude mcp add myserver -- npx -y my-mcp-server

# Changes are now in ai-dev PVC
# New containers will inherit these changes
```

### Creating New Dev Container

1. Copy the template deployment:
```bash
cp dev-container-belego.yaml dev-container-newname.yaml
sed -i 's/belego/newname/g' dev-container-newname.yaml
```

2. Create SSH ConfigMap:
```bash
kubectl create configmap dev-container-newname-ssh \
  --from-file=authorized_keys=path/to/keys \
  -n dev
```

3. Add nginx port mapping (in `applications/nginx/`):
- `configmap.yaml`: Add port mapping
- `service-ssh-lb.yaml`: Expose port

4. Apply:
```bash
kubectl apply -f dev-container-newname.yaml
```

## Storage Model

| Aspect | Details |
|--------|---------|
| Mount Point | `/home/dev` (entire home directory) |
| Type | local-path PVC |
| Size | 20Gi per container |
| Persistence | Survives pod restarts |
| Location | `/var/lib/rancher/k3s/storage/` on node |

**What's Persisted:**
- `~/.claude.json` - MCP server config with API keys
- `~/.bashrc` - Shell configuration
- `~/workspace/` - Git repos and projects
- Tool configs (bun, npm, etc.)

**What's NOT Persisted (in image):**
- System tools (`/opt/bun`, `/opt/opencode`)
- Global npm packages

## Deployed Containers

| Container | Role | Node | PVC | SSH Port |
|-----------|------|------|-----|----------|
| dev-container-ai-dev | Template | k3s-worker-01 | dev-home-ai-dev (20Gi) | 2224 |
| dev-container-belego | Dev | k3s-worker-01 | dev-home-belego (20Gi) | 2222 |
| dev-container-pilates | Dev | k3s-worker-01 | dev-home-pilates (20Gi) | 2223 |

## Directory Structure

```
applications/dev-containers/
├── base-image/
│   ├── Dockerfile                    # Base dev container image
│   └── Dockerfile.ai                 # AI-enabled image (extends base)
├── dev-container-ai-dev.yaml         # Template container (CONFIGURE HERE)
├── dev-container-ai-dev-ssh.yaml     # AI-Dev SSH ConfigMap
├── dev-container-belego.yaml         # Belego deployment (copies from ai-dev)
├── dev-container-belego-ssh.yaml     # Belego SSH ConfigMap
├── dev-container-pilates.yaml        # Pilates deployment (copies from ai-dev)
├── dev-container-pilates-ssh.yaml    # Pilates SSH ConfigMap
├── networkpolicy.yaml                # Container isolation policy
└── README.md                         # This file
```

## MCP Server Configuration

MCP servers are configured via `~/.claude.json` on the PVC. Configure once on ai-dev, inherited by new containers.

**Current MCP Servers (ai-dev template):**
- `exa` - Web search, code context, research (local npx)
- `dialog-mcp` - Reddit research (remote HTTP)

**Add new MCP server:**
```bash
ssh -p 2224 dev@192.168.2.101
claude mcp add servername -e API_KEY=xxx -- npx -y package-name
```

## Resource Limits

| Resource | Request | Limit |
|----------|---------|-------|
| CPU | 500m | 2000m |
| Memory | 1Gi | 4Gi |
| Storage | 20Gi | - |

## NetworkPolicy Isolation

Dev containers are isolated via Kubernetes NetworkPolicy:

**Allowed Ingress:** SSH (port 22) from nginx-proxy only
**Allowed Egress:** DNS, PostgreSQL, Ollama, n8n, Internet (HTTP/HTTPS/SSH)
**Blocked:** Inter-container communication

## Troubleshooting

**Init container failed to copy template:**
```bash
kubectl logs deployment/dev-container-belego -n dev -c init-home
```

**Check PVC contents:**
```bash
kubectl exec deployment/dev-container-ai-dev -n dev -- ls -la /home/dev/
```

**Rebuild template from scratch:**
1. Delete PVC: `kubectl delete pvc dev-home-ai-dev -n dev`
2. Re-apply deployment (will create empty PVC)
3. SSH in and configure manually
