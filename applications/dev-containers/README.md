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

### 3. Configure SSH Access

SSH access is provided through the nginx proxy in the dev namespace (Story 11.4).

For direct testing, use port-forward:
```bash
kubectl port-forward svc/dev-container-belego-svc 2222:22 -n dev

# Connect via SSH
ssh -p 2222 dev@localhost
```

## Resource Limits

Each container is configured with:
- **CPU**: 500m request, 2000m limit (2 cores)
- **Memory**: 1Gi request, 4Gi limit
- **Storage**: 10GB NFS PVC for workspace

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
└── README.md                         # This file
```

## Deployed Containers

| Container | Namespace | SSH Service | Storage |
|-----------|-----------|-------------|---------|
| dev-container-belego | dev | dev-container-belego-svc:22 | 10GB NFS PVC |
| dev-container-pilates | dev | dev-container-pilates-svc:22 | 10GB NFS PVC |

## Architecture Notes

- **Namespace**: `dev` (shared with nginx proxy)
- **Storage**: Hybrid model - NFS PVC for workspace, emptyDir for builds
- **Security**: SSH key-based auth only, no password authentication
- **Network**: NetworkPolicy isolation configured in Story 11.5

## Related Stories

- Story 11.1: Create Dev Container Base Image (this)
- Story 11.2: Deploy Dev Containers for Belego and Pilates
- Story 11.3: Configure Persistent Storage for Workspaces
- Story 11.4: Configure Nginx SSH Proxy with Custom Domains
- Story 11.5: Configure NetworkPolicy for Container Isolation
- Story 11.6: Validate VS Code Remote-SSH Configuration
