# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**home-lab** is a production-grade K3s Kubernetes learning platform running on Proxmox VE. It serves as both functional home infrastructure and a career portfolio project demonstrating AI-assisted platform engineering.

**Current Phase:** Implementation (Phase 4) - Story 1.1 in progress (K3s control plane setup)

## Key Documentation

| Document | Path |
|----------|------|
| Architecture Decisions | `docs/planning-artifacts/architecture.md` |
| PRD | `docs/planning-artifacts/prd.md` |
| Epics & Stories | `docs/planning-artifacts/epics.md` |
| Sprint Status | `docs/implementation-artifacts/sprint-status.yaml` |
| Master Index | `docs/FOLDER_DOCUMENTATION.md` |

## Infrastructure Commands

```bash
# K3s master installation (run on VM after SSH)
chmod +x infrastructure/k3s/install-master.sh
sudo ./infrastructure/k3s/install-master.sh

# Cluster validation
kubectl get nodes
kubectl get pods -n kube-system
kubectl get componentstatuses

# Helm deployments (pattern for all apps)
helm upgrade --install {name} {chart} -f values-homelab.yaml -n {namespace}
```

## Architecture

**Cluster Layout:**
- Control plane: `k3s-master` (192.168.2.20)
- Workers: `k3s-worker-01/02` (192.168.2.21/22)
- Storage: External NFS via Synology DS920+
- Access: Tailscale VPN only (no public API exposure)

**Namespaces:**
- `kube-system` - K3s core, Traefik
- `infra` - MetalLB, cert-manager
- `monitoring` - Prometheus, Grafana, Loki
- `data` - PostgreSQL
- `ml` - Ollama, vLLM
- `apps` - n8n
- `docs` - Paperless-ngx
- `dev` - Nginx proxy, dev containers

**Repository Structure:**
```
infrastructure/     # Core cluster (k3s/, nfs/, metallb/, cert-manager/)
applications/       # Workloads (postgres/, ollama/, nginx/, n8n/, paperless/)
monitoring/         # Observability (prometheus/, loki/)
docs/              # Documentation, ADRs, planning artifacts
scripts/           # Automation scripts
```

## BMAD Framework

This project uses the BMAD multi-agent AI workflow framework located in `_bmad/`. Key workflows:

```bash
# Check current workflow status
/bmad:bmm:workflows:workflow-status

# Create next story from backlog
/bmad:bmm:workflows:create-story

# Implement a story
/bmad:bmm:workflows:dev-story

# Code review after implementation
/bmad:bmm:workflows:code-review
```

## Consistency Rules

**Naming:**
- K8s resources: `{app}-{component}` (e.g., `postgres-primary`)
- Ingress: `{service}.home.jetzinger.com`
- Helm values: `values-homelab.yaml` in each chart directory

**Labels (all resources):**
```yaml
labels:
  app.kubernetes.io/name: {app}
  app.kubernetes.io/instance: {app}-{component}
  app.kubernetes.io/part-of: home-lab
  app.kubernetes.io/managed-by: helm
```

**ADRs:** `docs/adrs/ADR-{NNN}-{short-title}.md`

## Development Guidelines

- When altering database structure, always work with migration files
- Build incrementally: ONE feature at a time
- All decisions captured as ADRs for portfolio documentation
- Git is single source of truth - all manifests and Helm values version controlled
- No inline `--set` flags in production Helm deployments
