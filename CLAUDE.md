# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**home-lab** is a production-grade K3s Kubernetes learning platform running on Proxmox VE. It serves as both functional home infrastructure and a career portfolio project demonstrating AI-assisted platform engineering.

**Status:** All 25 epics complete. Cluster operational with full ML inference and document processing stack.

## Key Documentation

| Document | Path |
|----------|------|
| Architecture Decisions | `docs/planning-artifacts/architecture.md` |
| PRD | `docs/planning-artifacts/prd.md` |
| Epics & Stories | `docs/planning-artifacts/epics.md` |
| Sprint Status | `docs/implementation-artifacts/sprint-status.yaml` |
| Master Index | `docs/FOLDER_DOCUMENTATION.md` |

## Cluster Architecture

**Nodes:**
- `k3s-master` (192.168.2.20) - Control plane
- `k3s-worker-01` (192.168.2.21) - CPU worker
- `k3s-worker-02` (192.168.2.22) - CPU worker
- `k3s-gpu-worker` - Intel NUC + RTX 3060 eGPU (12GB VRAM), GPU inference
- `k3s-nas-worker` - Synology DS920+ VM

**Namespaces:**
- `kube-system` - K3s core, Traefik
- `infra` - MetalLB, cert-manager
- `monitoring` - Prometheus, Grafana, Loki, Alertmanager
- `data` - PostgreSQL
- `ml` - vLLM, Ollama, LiteLLM (inference stack)
- `apps` - n8n, Open-WebUI, OpenClaw (personal AI assistant)
- `docs` - Paperless-ngx, Paperless-GPT, Docling, Gotenberg, Tika, Stirling-PDF
- `dev` - Nginx proxy, dev containers
- `legacy-use` - Legacy-Use browser automation platform
- `kubernetes-dashboard` - Cluster dashboard

**Storage:** NFS via Synology DS920+ for shared workloads; `local-path` (Rancher) for node-local PVCs (e.g., openclaw)
**Access:** Tailscale VPN only (no public API exposure)
**Ingress:** `{service}.home.jetzinger.com` via Traefik + Let's Encrypt

## ML Inference Stack

Three-tier architecture with automatic failover via LiteLLM:

```
LiteLLM Proxy (litellm.ml.svc) → vLLM (GPU) → Ollama (CPU) → OpenAI (Cloud)
```

**GPU Modes** (on k3s-gpu-worker):
- `ml` - Qwen3-8B-AWQ (general inference)
- `r1` - DeepSeek-R1-Distill-Qwen-7B-AWQ (reasoning tasks)
- `gaming` - vLLM scaled to 0, GPU released

```bash
# Check/switch GPU mode
ssh k3s-gpu-worker "gpu-mode status"
ssh k3s-gpu-worker "gpu-mode ml"    # Switch to Qwen
ssh k3s-gpu-worker "gpu-mode r1"    # Switch to DeepSeek-R1
ssh k3s-gpu-worker "gpu-mode gaming"
```

## Infrastructure Commands

```bash
# Cluster validation
kubectl get nodes
kubectl get pods -A

# Helm deployments (pattern for all apps)
helm upgrade --install {name} {chart} -f values-homelab.yaml -n {namespace}

# Check ML inference
kubectl get pods -n ml
kubectl logs -n ml deployment/litellm --tail=50

# Check Paperless/docs stack
kubectl get pods -n docs

# Check OpenClaw (personal AI assistant)
kubectl get pods -n apps -l app.kubernetes.io/name=openclaw
kubectl logs -n apps deployment/openclaw --tail=50
```

## Runbooks

Operational runbooks are in `docs/runbooks/`:
- `postgres-backup.md` / `postgres-restore.md` — DB backup/restore procedures
- `k3s-upgrade.md` — Cluster upgrade procedure
- `egpu-hotplug.md` — eGPU hot-plug on k3s-gpu-worker
- `cluster-backup.md` / `cluster-restore.md` — Full cluster state backup/restore
- `k3s-svclb-recovery.md` — Recover from svclb issues after node changes

## Repository Structure

```
infrastructure/     # Core cluster (k3s/, nfs/, metallb/, cert-manager/, traefik/)
applications/       # Workloads (vllm/, litellm/, ollama/, paperless/, open-webui/, gitea/, n8n/, postgres/, openclaw/, legacy-use/)
monitoring/         # Observability (prometheus/, loki/)
docs/              # ADRs (docs/adrs/), runbooks (docs/runbooks/), planning/implementation artifacts
scripts/           # Automation (gpu-worker/gpu-mode, deploy scripts, health checks)
secrets/           # Secret YAML templates (empty placeholders; real values applied manually, never committed)
```

## BMAD Framework

This project uses the BMAD multi-agent AI workflow framework in `_bmad/`. Key workflows:

```bash
/bmad:bmm:workflows:workflow-status    # Check current status
/bmad:bmm:workflows:create-story       # Create next story from backlog
/bmad:bmm:workflows:dev-story          # Implement a story
/bmad:bmm:workflows:code-review        # Code review after implementation
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
- Paperless-GPT (replaced Paperless-AI in Epic 25) stores LLM provider config in its configmap
