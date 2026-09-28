# Folder Documentation - Master Index

Where everything in this repo lives, and where to start for a given task.
Last checked against the tree and the live cluster on **2026-09-28**.

Entries marked **historic** describe something retired. They are kept for the portfolio record;
do not follow them as current procedure.

## Start here

| I want to... | Go to |
|---|---|
| Understand the project | [`README.md`](../README.md), [`CLAUDE.md`](../CLAUDE.md) |
| Know *why* something is the way it is | [`docs/adrs/README.md`](adrs/README.md) - the ADR index |
| Upgrade k3s | [`runbooks/k3s-upgrade.md`](runbooks/k3s-upgrade.md) |
| Recover from a broken master | [ADR-019](adrs/ADR-019-tailscale-lan-policy-rule.md), `ssh root@192.168.2.20` |
| Handle the eGPU / GPU worker | [`runbooks/egpu-hotplug.md`](runbooks/egpu-hotplug.md), [`infrastructure/gpu-operator/`](../infrastructure/gpu-operator/README.md) |
| Back up or restore the database | [`runbooks/postgres-backup.md`](runbooks/postgres-backup.md), [`runbooks/postgres-restore.md`](runbooks/postgres-restore.md) |
| Rotate a leaked credential | [`runbooks/secret-rotation.md`](runbooks/secret-rotation.md) |
| Add or change an alert | [`monitoring/prometheus/custom-rules.yaml`](../monitoring/prometheus/custom-rules.yaml), routing in [`values-homelab.yaml`](../monitoring/prometheus/values-homelab.yaml) |
| Change which cloud model an alias uses | [`applications/litellm/configmap.yaml`](../applications/litellm/configmap.yaml), [ADR-013](adrs/ADR-013-cloud-model-tier-refresh.md) |

## Repository root

| Path | What it is |
|---|---|
| `README.md` | Public project overview |
| `CLAUDE.md` | Working instructions for Claude Code: cluster map, conventions, commands |
| `.ideas` | Loose idea notes |
| `_bmad/` | BMAD multi-agent workflow framework (config, agents, workflows). Tooling, not infrastructure |
| `secrets/` | Secret YAML templates with **empty placeholders**. Gitignored values are applied by hand. Never `kubectl apply` one over a live secret - patch single keys instead |

## `infrastructure/` - core cluster

| Folder | Contents |
|---|---|
| [`k3s/`](../infrastructure/k3s/README.md) | Install scripts for master and workers, the LXC config for the master, kubeconfig setup, Tailscale subnet routers. Also the master's host-only files: `tailscale-lan-rule.service`, `wait-tailscale-ip.sh` and `k3s-wait-tailscale.conf` (ADR-019) |
| [`metallb/`](../infrastructure/metallb/README.md) | MetalLB L2 load balancer; VIP `192.168.2.100` |
| [`traefik/`](../infrastructure/traefik/README.md) | Traefik ingress config and the dashboard route |
| [`cert-manager/`](../infrastructure/cert-manager/README.md) | Let's Encrypt certificates. Its pods need `dnsPolicy: None` (see the DNS notes in the README) |
| [`nfs/`](../infrastructure/nfs/README.md) | NFS subdir provisioner against the Synology DS920+ |
| [`gpu-operator/`](../infrastructure/gpu-operator/README.md) | NVIDIA GPU Operator values; the host driver is installed separately (ADR-020) |
| [`kubernetes-dashboard/`](../infrastructure/kubernetes-dashboard/README.md) | Kubernetes Dashboard and its ingress |
| [`agent-vms/`](../infrastructure/agent-vms/README.md) | Proxmox desktop VMs for Claude Cowork and Codex - outside k3s (ADR-018) |

## `applications/` - workloads

| Folder | Namespace | Contents |
|---|---|---|
| `postgres-cnpg/` | `data` | **The** PostgreSQL: CloudNativePG cluster, two instances (ADR-014) |
| `postgres/` | - | **Historic.** Bitnami PostgreSQL, replaced by CNPG; the release no longer exists |
| `litellm/` | `ml` | LiteLLM proxy: cloud aliases and the fallback chain to vLLM and Ollama |
| `vllm/` | `ml` | vLLM on the GPU worker; modes switched by `scripts/gpu-worker/gpu-mode` |
| `ollama/` | `ml` | Ollama on CPU, last hop of the fallback chain |
| `open-webui/` | `apps` | Chat front end on LiteLLM |
| `n8n/` | `apps` | Workflow automation. Service renamed `n8n-app` to avoid the `N8N_PORT` env collision |
| `paperless/` | `docs` | Paperless-ngx, Paperless-GPT, Docling |
| `tika/`, `gotenberg/`, `stirling-pdf/` | `docs` | Office-document parsing, conversion and PDF tools for Paperless |
| `gitea/` | `dev` | Self-hosted Git |
| `legacy-use/` | `legacy-use` | Browser automation platform (backend, DinD, frontend) |

## `monitoring/` - observability

| Folder | Contents |
|---|---|
| `prometheus/` | kube-prometheus-stack values (chart 91.4.1), custom alert rules, ServiceMonitors, the hand-written kube-proxy EndpointSlice, blackbox exporter, ingresses |
| `grafana/` | Dashboards (LiteLLM, NVIDIA DCGM) and ingress |
| `loki/` | Loki and promtail |
| `ntfy/` | Self-hosted ntfy: where `critical` alerts reach the phone |

Only `severity: critical` alerts page the phone. Everything else goes to the `null` receiver.

## `scripts/`

| Path | What it does |
|---|---|
| `gpu-worker/gpu-mode` | Switch the GPU between `ml`, `r1` and `gaming` modes; runs on the GPU worker |
| `gpu-worker/gpu-mode-default.service` | Sets the GPU mode at boot |
| `gpu-worker/steam-setup.md` | Steam/Proton setup for gaming mode |
| `deploy-prometheus.sh`, `deploy-n8n.sh` | Deploy helpers that merge gitignored secrets files into Helm values |
| `deploy-postgres.sh` | **Historic** - deploys the Bitnami chart; CNPG is applied from `applications/postgres-cnpg/` |
| `health-check.sh` | Storage health: NFS connectivity, PV/PVC status, mounts |
| `ollama-health.sh` | Ollama API, model availability and a test inference |
| `open-webui/apply-model-curation.sh` | Curate which models Open-WebUI shows |

## `docs/`

| Path | What it is |
|---|---|
| [`adrs/`](adrs/README.md) | Architecture Decision Records, ADR-001 to ADR-020, with an index |
| `runbooks/` | Operational procedures - see the next table |
| `planning-artifacts/` | PRD, architecture, epics, product brief, readiness reports, career research |
| `implementation-artifacts/` | One file per story (epics 1-28), `sprint-status.yaml`, tech specs |
| `analysis/` | Brainstorming session notes |
| `diagrams/` | Architecture overview and Grafana screenshots |
| `blog-posts/` | Published technical blog posts |
| `PORTFOLIO.md`, `VISUAL_TOUR.md` | Portfolio companion and screenshot tour |
| `project-context.md`, `SEMANTIC_INDEX.yaml`, `bmm-workflow-status.yaml` | BMAD context and a tag index of the docs |

### Runbooks

| Runbook | Status |
|---|---|
| `k3s-upgrade.md`, `k3s-rollback.md` | Current. After an upgrade, check the master's boot guard (section 4c) |
| `cluster-backup.md`, `cluster-restore.md` | Current |
| `node-removal.md` | Current |
| `os-security-updates.md` | Current |
| `egpu-hotplug.md` | Current - driver 570 (updated 2026-09-28) |
| `secret-rotation.md` | Current |
| `postgres-backup.md`, `postgres-restore.md` | Current - CloudNativePG |
| `postgres-setup.md`, `postgres-connectivity.md` | Current - CloudNativePG operations, and connecting a new app (rewritten 2026-09-28) |
| `nfs-restore.md` | Current |
| `alertmanager-setup.md`, `loki-setup.md` | Setup records for the monitoring stack |
| `agent-desktop-vms.md` | Current - Cowork/Codex VMs |
| `k3s-svclb-recovery.md` | **Historic** - ServiceLB disabled (ADR-017) |
| `openclaw-device-pairing.md` | **Historic** - OpenClaw retired (ADR-015) |

## Keeping this file true

Update it in the same commit when you add, move or retire a folder, runbook or ADR.
