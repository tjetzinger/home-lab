# Dev Containers Platform

Standardized development containers with SSH access for remote development using VS Code Remote-SSH or similar tools.

## Components

| Component | Description |
|-----------|-------------|
| `base-image/Dockerfile` | Ubuntu 22.04 base image with development tools |
| `ssh-configmap.yaml` | Template for SSH authorized_keys |
| `dev-container-template.yaml` | Kubernetes deployment template |

## Base Image Contents

The dev container base image includes:

- **OS**: Ubuntu 22.04 LTS
- **Node.js**: 20.x with npm
- **Python**: 3.11 with pip
- **kubectl**: Latest stable
- **Helm**: 3.x
- **Claude Code CLI**: `@anthropic-ai/claude-code`
- **Utilities**: git, sudo, vim, curl, wget
- **SSH Server**: OpenSSH with key-based authentication only

## Building the Image

```bash
cd applications/dev-containers/base-image
docker build -t dev-container-base:latest .
```

## Deploying a Dev Container

### 1. Create SSH ConfigMap

```bash
# Create ConfigMap with your SSH public key
kubectl create configmap dev-container-belego-ssh \
  --from-file=authorized_keys=~/.ssh/id_ed25519.pub \
  -n dev
```

### 2. Deploy the Container

```bash
# Copy and customize the template
cp dev-container-template.yaml dev-container-belego.yaml

# Replace INSTANCE with container name
sed -i 's/INSTANCE/belego/g' dev-container-belego.yaml

# Apply the manifest
kubectl apply -f dev-container-belego.yaml
```

### 3. SSH Access

SSH access is provided through the nginx proxy LoadBalancer (Story 11.4).

| Container | Port | IP |
|-----------|------|----|
| Belego | 2222 | 192.168.2.101 |
| Pilates | 2223 | 192.168.2.101 |

**Connect via SSH:**
```bash
# Belego
ssh -p 2222 dev@192.168.2.101

# Pilates
ssh -p 2223 dev@192.168.2.101
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
```

**Port-forward (for testing):**
```bash
kubectl port-forward svc/dev-container-belego-svc 2222:22 -n dev
ssh -p 2222 dev@localhost
```

## Resource Limits

Each container is configured with:
- **CPU**: 500m request, 2000m limit (2 cores)
- **Memory**: 1Gi request, 4Gi limit
- **Storage**: emptyDir (ephemeral, ~66 MB/s write speed)

## Storage Model

Dev containers use **emptyDir** for fast local storage:

| Aspect | Details |
|--------|---------|
| Type | emptyDir (node-local SSD) |
| Performance | ~66 MB/s (vs 11.6 MB/s NFS) |
| Persistence | **Ephemeral** - data lost on pod restart |
| Best Practice | Use `git push` to persist code changes |

**Why emptyDir?** NFS storage was too slow for development workloads (npm install, git operations, file indexing). Local storage provides 5.7x better write performance.

## Verification Commands

After building, verify the image:

```bash
docker run --rm dev-container-base:latest node --version    # v20.x
docker run --rm dev-container-base:latest python3 --version # Python 3.11.x
docker run --rm dev-container-base:latest kubectl version --client
docker run --rm dev-container-base:latest helm version
docker run --rm dev-container-base:latest claude --version
docker run --rm dev-container-base:latest git --version
docker run --rm dev-container-base:latest ssh -V
```

## Directory Structure

```
applications/dev-containers/
├── base-image/
│   └── Dockerfile                    # Dev container base image
├── dev-container-template.yaml       # Template for new containers
├── ssh-configmap.yaml                # SSH authorized_keys template
├── dev-container-belego.yaml         # Belego container deployment
├── dev-container-belego-ssh.yaml     # Belego SSH ConfigMap
├── dev-container-pilates.yaml        # Pilates container deployment
├── dev-container-pilates-ssh.yaml    # Pilates SSH ConfigMap
├── networkpolicy.yaml                # Container isolation policy
└── README.md                         # This file
```

## Deployed Containers

| Container | Namespace | SSH Service | Storage |
|-----------|-----------|-------------|---------|
| dev-container-belego | dev | dev-container-belego-svc:22 | emptyDir |
| dev-container-pilates | dev | dev-container-pilates-svc:22 | emptyDir |

## Architecture Notes

- **Namespace**: `dev` (shared with nginx proxy)
- **Storage**: emptyDir for all mounts (fast, ephemeral)
- **Security**: SSH key-based auth only, no password authentication
- **Network**: NetworkPolicy isolation (Story 11.5)

## NetworkPolicy Isolation

Dev containers are isolated via Kubernetes NetworkPolicy (`dev-container-isolation`):

**Ingress (Allowed):**
- SSH (port 22) from nginx-proxy pods only

**Egress (Allowed):**
- DNS resolution (kube-system, port 53)
- PostgreSQL (data namespace, port 5432)
- Ollama (ml namespace, port 11434)
- n8n (apps namespace, port 5678)

**Allowed (External):**
- Internet access (HTTP/HTTPS/SSH) for npm, pip, git, etc.

**Blocked:**
- Inter-container communication (Belego ↔ Pilates)
- All other cluster services not explicitly allowed

**Verification:**
```bash
# Check NetworkPolicy
kubectl get networkpolicy -n dev
kubectl describe networkpolicy dev-container-isolation -n dev

# Test from dev container
kubectl exec deployment/dev-container-belego -n dev -- python3 -c "
import socket
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.settimeout(5)
s.connect(('postgres-postgresql.data.svc.cluster.local', 5432))
print('PostgreSQL: SUCCESS')
"
```

## Related Stories

- Story 11.1: Create Dev Container Base Image (this)
- Story 11.2: Deploy Dev Containers for Belego and Pilates
- Story 11.3: Configure Persistent Storage for Workspaces
- Story 11.4: Configure Nginx SSH Proxy with Custom Domains
- Story 11.5: Configure NetworkPolicy for Container Isolation
- Story 11.6: Validate VS Code Remote-SSH Configuration
