---
stepsCompleted: [1, 2, 3, 4]
workflow_completed: true
completedAt: '2026-01-29'
lastModified: '2026-02-19'
inputDocuments:
  - 'docs/planning-artifacts/prd.md'
  - 'docs/planning-artifacts/architecture.md'
workflowType: 'epics-and-stories'
date: '2025-12-27'
author: 'Tom'
project_name: 'home-lab'
updateReason: 'Ollama Pro Cloud Model Integration (2026-02-19): Added Epic 26 — FR215-FR223, NFR121-NFR125. Three Ollama Pro cloud models (cloud-kimi/kimi-k2.5, cloud-minimax/minimax-m2.5, cloud-qwen3-coder/qwen3-coder:480b-cloud) added to LiteLLM as primary tier. OpenClaw migrated off Anthropic (legal constraint) to cloud-kimi primary. paperless-gpt → cloud-minimax. open-webui default → cloud-minimax. openai-gpt4o demoted to explicit-only. Scoped workflow run: requirements extraction and Epic 26 story creation.'
currentStep: 'Workflow Complete - Epic 26 stories validated, ready for implementation'
---

# home-lab - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for home-lab, decomposing the requirements from the PRD and Architecture into implementable stories.

## Requirements Inventory

### Functional Requirements

**Cluster Operations (6 FRs)**
- FR1: Operator can deploy a K3s control plane on a dedicated VM
- FR2: Operator can add worker nodes to the cluster
- FR3: Operator can remove worker nodes from the cluster without data loss
- FR4: Operator can view cluster node status and health
- FR5: Operator can access the cluster remotely via Tailscale
- FR6: Operator can run kubectl commands from any Tailscale-connected device

**Workload Management (7 FRs)**
- FR7: Operator can deploy containerized applications to the cluster
- FR8: Operator can deploy applications using Helm charts
- FR9: Operator can expose applications via ingress with HTTPS
- FR10: Operator can configure automatic TLS certificate provisioning
- FR11: Operator can assign workloads to specific namespaces
- FR12: Operator can scale deployments up or down
- FR13: Operator can view pod logs and events

**Storage Management (5 FRs)**
- FR14: Operator can provision persistent volumes from NFS storage
- FR15: Operator can create PersistentVolumeClaims for applications
- FR16: System provisions storage dynamically via StorageClass
- FR17: Operator can verify storage mount health
- FR18: Operator can backup persistent data to Synology snapshots

**Networking & Ingress (5 FRs)**
- FR19: Operator can expose services via LoadBalancer using MetalLB
- FR20: Operator can configure ingress routes via Traefik
- FR21: Operator can access services via *.home.jetzinger.com domain
- FR22: System resolves internal DNS via NextDNS rewrites
- FR23: Operator can view Traefik dashboard for ingress status

**Observability (7 FRs)**
- FR24: Operator can view cluster metrics in Grafana dashboards
- FR25: Operator can query Prometheus for historical metrics
- FR26: System collects metrics from all nodes via Node Exporter
- FR27: System collects Kubernetes object metrics via kube-state-metrics
- FR28: System sends alerts via Alertmanager when thresholds exceeded
- FR29: Operator can receive mobile notifications for P1 alerts
- FR30: Operator can view alert history and status

**Data Services (5 FRs)**
- FR31: Operator can deploy PostgreSQL as a StatefulSet
- FR32: PostgreSQL persists data to NFS storage
- FR33: Operator can backup PostgreSQL to NFS
- FR34: Operator can restore PostgreSQL from backup
- FR35: Applications can connect to PostgreSQL within cluster

**AI/ML Workloads (18 FRs)**
- FR36: Operator can deploy Ollama for LLM inference
- FR37: Applications can query Ollama API for completions
- FR38: Operator can deploy Ollama with Qwen 2.5 14B for unified GPU inference
- FR39: GPU workloads can request GPU resources via NVIDIA Operator
- FR40: Operator can deploy n8n for workflow automation
- FR71: GPU worker (Intel NUC + RTX 3060 eGPU) joins cluster via Tailscale mesh (Solution A: all nodes run Tailscale)
- FR72: Ollama serves Qwen 2.5 14B as unified model for all inference tasks (code, classification, general)
- FR73: GPU Ollama gracefully degrades to CPU Ollama when GPU worker unavailable
- FR74: Operator can hot-plug GPU worker (add/remove on demand without cluster disruption)
- FR94: Ollama gracefully degrades to CPU when GPU is unavailable due to host workloads (Steam gaming)
- FR100: All K3s nodes (master, workers, GPU worker) run Tailscale for full mesh connectivity
- FR101: K3s configured with `--flannel-iface tailscale0` to route pod network over Tailscale mesh
- FR102: K3s nodes advertise Tailscale IPs via `--node-external-ip` for cross-subnet communication
- FR103: NO_PROXY environment includes Tailscale CGNAT range (100.64.0.0/10) on all nodes
- FR109: vLLM deployed with qwen2.5:14b model on GPU worker (k3s-gpu-worker) for primary inference (Story 12.10)
- FR110: Paperless-AI configured with `AI_PROVIDER=custom` pointing to vLLM OpenAI-compatible endpoint (Story 12.10)
- FR111: Ollama serves slim models (llama3.2:1b, qwen2.5:3b) for experimentation only, qwen2.5:14b removed (Story 12.10)
- FR112: k3s-worker-02 resources reduced from 32GB to 8GB RAM after vLLM migration (Story 12.10)

**Gaming Platform (6 FRs)**
- FR95: Intel NUC runs Steam on host Ubuntu OS (not containerized)
- FR96: Steam uses Proton for Windows game compatibility
- FR97: Operator can switch between Gaming Mode and ML Mode via script
- FR98: Gaming Mode scales Ollama pods to 0 and enables CPU fallback
- FR99: ML Mode restores GPU Ollama pods when Steam/gaming exits
- FR119: k3s-gpu-worker boots into ML Mode by default via systemd service (vLLM scaled to 1 at startup)

**LiteLLM Inference Proxy (6 FRs)**
- FR113: LiteLLM proxy deployed in `ml` namespace providing unified OpenAI-compatible endpoint
- FR114: LiteLLM configured with three-tier fallback: vLLM (GPU) → Ollama (CPU) → OpenAI (cloud)
- FR115: Paperless-AI configured to use LiteLLM endpoint instead of direct vLLM connection
- FR116: LiteLLM automatically routes to next fallback tier when primary backend health check fails
- FR117: OpenAI API key stored securely via Kubernetes secret for cloud fallback tier
- FR118: LiteLLM exposes Prometheus metrics for inference routing and fallback events

**Tailscale Subnet Router (3 FRs)**
- FR120: k3s-master configured as Tailscale subnet router advertising 192.168.2.0/24 to Tailscale network
- FR121: k3s-gpu-worker configured as Tailscale subnet router advertising 192.168.0.0/24 to Tailscale network
- FR122: Tailscale ACLs configured to allow subnet route access for authorized users

**Synology NAS K3s Worker (3 FRs)**
- FR123: K3s worker VM deployed on Synology DS920+ using Virtual Machine Manager
- FR124: NAS worker node labeled for lightweight/storage-adjacent workloads only
- FR125: NAS worker node tainted to prevent general workload scheduling

**Open-WebUI Application (4 FRs)**
- FR126: Open-WebUI deployed in `apps` namespace with persistent storage for chat history
- FR127: Open-WebUI configured to use LiteLLM as backend for unified model access
- FR128: Open-WebUI accessible via ingress at `chat.home.jetzinger.com` with HTTPS
- FR129: Open-WebUI supports switching between local models (vLLM, Ollama) and external providers (Groq, Google, Mistral)

**Kubernetes Dashboard (4 FRs)**
- FR130: Kubernetes Dashboard deployed in `infra` namespace
- FR131: Dashboard accessible via ingress at `dashboard.home.jetzinger.com` with HTTPS
- FR132: Dashboard authentication via bearer token or Tailscale identity
- FR133: Dashboard provides read-only view of all namespaces, pods, and resources

**Gitea Self-Hosted Git (4 FRs)**
- FR134: Gitea deployed in `dev` namespace with PostgreSQL backend
- FR135: Gitea accessible via ingress at `git.home.jetzinger.com` with HTTPS
- FR136: Gitea persists repositories and data to NFS storage
- FR137: Gitea configured for single-user operation with SSH key authentication

**DeepSeek-R1 14B Reasoning Mode (4 FRs)**
- FR138: DeepSeek-R1 14B model deployed via vLLM on GPU worker for reasoning tasks
- FR139: R1-Mode added as third GPU mode alongside ML-Mode and Gaming-Mode
- FR140: Mode switching script updated to support R1-Mode (scales vLLM to DeepSeek-R1 model)
- FR141: LiteLLM configured with DeepSeek-R1 as reasoning-tier model

**LiteLLM External Providers (4 FRs)**
- FR142: LiteLLM configured with Groq free tier as fast inference fallback
- FR143: LiteLLM configured with Google AI Studio (Gemini) free tier
- FR144: LiteLLM configured with Mistral API free tier
- FR145: API keys for external providers stored securely via Kubernetes secrets

**Blog Article Completion (3 FRs)**
- FR146: Technical blog post published covering Phase 1 MVP and new feature additions
- FR147: Blog post includes architecture diagrams, ADR references, and Grafana screenshots
- FR148: Blog post documents AI-assisted engineering workflow used throughout project

**OpenClaw Personal AI Assistant (40 FRs)**
- FR149: Operator can deploy OpenClaw Gateway as a Docker container on K3s in the `apps` namespace
- FR150: Operator can access the OpenClaw gateway control UI via `openclaw.home.jetzinger.com`
- FR151: Operator can configure OpenClaw via `openclaw.json` persisted on NFS storage
- FR152: System preserves all OpenClaw configuration and workspace data across pod restarts
- FR153: Operator can view gateway status and health via the control UI
- FR154: Operator can restart the gateway via the control UI
- FR155: System routes all conversations to Claude Opus 4.5 via Anthropic OAuth as the primary LLM
- FR156: System automatically falls back to LiteLLM proxy when Anthropic is unavailable
- FR157: User can identify which LLM provider is handling a given conversation
- FR158: Operator can manage Anthropic OAuth credentials through the gateway control UI
- FR159: User can send and receive messages with OpenClaw via Telegram DM
- FR160: User can send and receive messages with OpenClaw via WhatsApp DM
- FR161: User can send and receive messages with OpenClaw via Discord DM
- FR162: System enforces allowlist-only DM pairing across all messaging channels
- FR163: Operator can approve or reject pairing requests via the gateway CLI
- FR164: User can continue a conversation context across different messaging channels
- FR165: User can request web research and receive sourced answers via Exa MCP tools
- FR166: Operator can install and configure additional MCP research servers via mcporter
- FR167: User can invoke any configured MCP tool through natural language conversation
- FR168: System returns structured, sourced responses when using research tools
- FR169: User can interact with OpenClaw via voice input and receive spoken responses through ElevenLabs
- FR170: User can switch between text and voice modes within a conversation
- FR171: Operator can configure specialized sub-agents with distinct capabilities
- FR172: User can invoke specific sub-agents through the main conversation
- FR173: System routes tasks to appropriate sub-agents based on context
- FR174: User can trigger browser automation tasks through conversation
- FR175: System can navigate web pages, fill forms, and extract information via the browser tool
- FR176: System can present rich content via Canvas/A2UI
- FR177: Operator can install skills from ClawdHub marketplace
- FR178: Operator can update and sync installed skills via ClawdHub
- FR179: User can invoke installed skills through slash commands or natural conversation
- FR180: Operator can enable, disable, and configure individual skills via `openclaw.json`
- FR181: System collects gateway logs into Loki for analysis
- FR182: Operator can view OpenClaw operational dashboard in Grafana with log-derived metrics
- FR183: Grafana dashboard displays message volume per channel, LLM provider usage, MCP tool invocations, and error rates
- FR184: Prometheus Blackbox Exporter probes the gateway control UI for uptime monitoring
- FR185: Alertmanager sends alerts when the gateway is unreachable, error rate is sustained, or OAuth tokens are expiring
- FR186: Operator can view OpenClaw health snapshot via `openclaw health --json`
- FR187: Repository includes an ADR documenting OpenClaw architectural decisions
- FR188: Repository README includes a OpenClaw section with architecture overview

**Long-Term Memory (3 FRs)**
- FR189: Operator can configure OpenClaw to use the `memory-lancedb` plugin with OpenAI embeddings (`text-embedding-3-small`) for automatic memory capture and recall
- FR190: System automatically captures conversation context into a LanceDB vector store and recalls relevant memories on subsequent conversations
- FR191: Operator can manage the memory index via `openclaw ltm` CLI commands (stats, list, search)

**Document Processing Pipeline Upgrade (17 FRs)**
- FR192: Paperless-GPT deployed in `docs` namespace replacing Paperless-AI
- FR193: Paperless-GPT configured with Docling as OCR provider
- FR194: Paperless-GPT connected to LiteLLM proxy for LLM inference
- FR195: Documents auto-classified with title, tags, correspondent, document type, and custom fields
- FR196: Prompt templates customizable via Paperless-GPT web UI without pod restart
- FR197: Paperless-GPT supports manual review and automatic processing tag workflows
- FR198: Paperless-GPT accessible via ingress at `paperless-gpt.home.jetzinger.com` with HTTPS
- FR199: Docling server deployed with Granite-Docling 258M VLM pipeline
- FR200: Docling provides layout-aware PDF parsing preserving table structure, code blocks, equations
- FR201: Docling outputs structured markdown/JSON consumed by Paperless-GPT
- FR202: Docling runs on CPU with minimal resource footprint
- FR203: vLLM image upgraded from v0.5.5 to v0.10.2+ for Qwen3 support
- FR204: vLLM ML-mode model upgraded to Qwen/Qwen3-8B-AWQ
- FR205: LiteLLM configmap updated with Qwen3-8B-AWQ model path for vllm-qwen alias
- FR206: Ollama model upgraded from qwen2.5:3b to phi4-mini
- FR207: LiteLLM configmap updated with phi4-mini model for ollama-qwen alias
- FR208: Paperless-AI deployment, configmap, service, and ingress removed

**Ollama Pro Cloud Model Integration (9 FRs)**
- FR215: OLLAMA_API_KEY added to `litellm-secrets` via `kubectl patch` for Ollama Pro cloud model authentication; never applied via `kubectl apply` with placeholder
- FR216: LiteLLM `model_list` updated with three cloud model entries — `cloud-minimax` (minimax-m2.5), `cloud-kimi` (kimi-k2.5), `cloud-qwen3-coder` (qwen3-coder:480b-cloud) — all routing to `api_base: https://ollama.com/api` via `ollama_chat` provider
- FR217: LiteLLM `fallbacks` updated so each cloud model cascades to `["vllm-qwen", "ollama-qwen"]` when cloud API is unavailable, preserving full local inference as backup
- FR218: `openai-gpt4o` removed from the automatic fallback chain; retained as an explicit parallel-only selection
- FR219: `paperless-gpt` configmap updated with `LLM_MODEL: "cloud-minimax"` (replacing `"vllm-qwen"`) for improved multilingual German document processing via minimax-m2.5
- FR220: `open-webui` values-homelab.yaml updated with `DEFAULT_MODELS: "cloud-minimax"`; all three cloud models auto-exposed in the model picker via LiteLLM `/v1/models` with no per-model wiring required
- FR221: n8n configured with an OpenAI-compatible LiteLLM credential via the n8n UI (base URL: `http://litellm.ml.svc.cluster.local:4000/v1`); no Helm changes required; per-workflow model selection supports `cloud-minimax`, `cloud-kimi`, `cloud-qwen3-coder`
- FR222: `openclaw.json` inspected live before migration (`kubectl exec`) to identify the LLM provider and primary model configuration key names; primary model migrated to `cloud-kimi` via LiteLLM endpoint; Anthropic OAuth fully removed (legal constraint)
- FR223: openclaw coder sub-agent model migrated to `cloud-qwen3-coder` via LiteLLM endpoint after live config inspection confirms sub-agent model key names

**Development Proxy (3 FRs)**
- FR41: Operator can configure Nginx to proxy to local dev servers
- FR42: Developer can access local dev servers via cluster ingress
- FR43: Operator can add/remove proxy targets without cluster restart

**Cluster Maintenance (5 FRs)**
- FR44: Operator can upgrade K3s version on nodes
- FR45: Operator can backup cluster state via Velero
- FR46: Operator can restore cluster from Velero backup
- FR47: System applies security updates to node OS automatically
- FR48: Operator can view upgrade history and rollback if needed

**Portfolio & Documentation (6 FRs)**
- FR49: Audience can view public GitHub repository
- FR50: Audience can read architecture decision records (ADRs)
- FR51: Audience can view Grafana dashboard screenshots
- FR52: Audience can read technical blog posts about the build
- FR53: Operator can document decisions as ADRs in repository
- FR54: Operator can publish blog posts to dev.to or similar platform

**Document Management - Paperless-ngx (7 FRs)**
- FR55: Operator can deploy Paperless-ngx with Redis backend
- FR56: Paperless-ngx persists documents to NFS storage
- FR57: User can access Paperless-ngx via ingress with HTTPS
- FR58: User can upload, tag, and search scanned documents
- FR64: Paperless-ngx performs OCR on uploaded documents with German and English language support
- FR65: System handles thousands of documents with ongoing scanning and manual upload workflow
- FR66: Paperless-ngx uses PostgreSQL backend for metadata storage (deferred to future epic)

**Dev Containers (9 FRs)**
- FR59: Nginx proxy routes to dev containers in `dev` namespace
- FR60: Operator can provision dev containers with git worktree support
- FR61: Developer can connect VS Code to dev container via Nginx proxy
- FR62: Developer can run Claude Code inside dev containers
- FR63: Dev containers use local storage for workspace data
- FR67: Dev containers use single base image with Node.js, Python, Claude Code CLI, git, kubectl, helm
- FR68: Each dev container allocated 2 CPU cores and 4GB RAM
- FR69: Dev containers mount persistent 10GB volumes for workspace data
- FR70: Dev containers isolated via NetworkPolicy (accessible only via nginx proxy)

### NonFunctional Requirements

**Reliability (6 NFRs)**
- NFR1: Cluster achieves 95%+ uptime measured monthly
- NFR2: Control plane recovers from VM restart within 5 minutes
- NFR3: Worker node failure does not cause service outage (pods reschedule)
- NFR4: NFS storage remains accessible during Synology firmware updates
- NFR5: Alertmanager sends P1 alerts within 1 minute of threshold breach
- NFR6: Cluster state can be restored from Velero backup within 30 minutes

**Security (6 NFRs)**
- NFR7: All ingress traffic uses TLS 1.2+ with valid certificates
- NFR8: Cluster API access requires Tailscale VPN connection
- NFR9: No services exposed to public internet without ingress authentication
- NFR10: Kubernetes secrets encrypted at rest (K3s default)
- NFR11: Node OS security updates applied within 7 days of release
- NFR12: kubectl access requires valid kubeconfig (no anonymous access)

**Performance (5 NFRs)**
- NFR13: Ollama API responds within 30 seconds for typical prompts
- NFR14: Grafana dashboards load within 5 seconds
- NFR15: Pod scheduling completes within 30 seconds of deployment
- NFR16: NFS-backed PVCs mount within 10 seconds
- NFR17: Traefik routes requests with <100ms added latency

**Operability (6 NFRs)**
- NFR18: All cluster components emit Prometheus metrics
- NFR19: Pod logs retained for 7 days minimum
- NFR20: K3s upgrades complete with zero data loss
- NFR21: New services deployable without cluster restart
- NFR22: Runbooks exist for all P1 alert scenarios
- NFR23: Single operator can manage entire cluster (no team required)

**Documentation Quality (4 NFRs)**
- NFR24: All architecture decisions documented as ADRs
- NFR25: README provides working cluster setup in <2 hours
- NFR26: All deployed services have documented purpose and configuration
- NFR27: Repository navigable by external reviewer (hiring manager)

**Document Management - Paperless-ngx (3 NFRs)**
- NFR28: Paperless-ngx OCR processes German and English text with 95%+ accuracy
- NFR29: Document library scales to 5,000+ documents without performance degradation
- NFR30: Document search returns results within 3 seconds for full-text queries

**Dev Containers (3 NFRs)**
- NFR31: Dev container provisioning completes within 90 seconds (image pull + volume mount)
- NFR32: Persistent volumes retain workspace data across container restarts
- NFR33: Dev containers isolated via NetworkPolicy (no cross-container communication)

**GPU/ML Infrastructure (9 NFRs)**
- NFR34: Ollama achieves 35-40 tokens/second for Qwen 2.5 14B on RTX 3060
- NFR35: Ollama handles 2-3 concurrent inference requests without significant performance degradation
- NFR36: GPU worker joins cluster and becomes Ready within 2 minutes of boot via Tailscale
- NFR37: NVIDIA GPU Operator installs and configures GPU drivers automatically (no manual setup)
- NFR38: Ollama serves Qwen 2.5 14B as unified model for all tasks (code, classification, general)
- NFR50: Ollama detects GPU unavailability (host workload) within 10 seconds
- NFR55: Tailscale mesh establishes full connectivity within 60 seconds of node boot
- NFR56: Pod-to-pod communication works across different physical subnets (192.168.0.x <-> 192.168.2.x) via Tailscale
- NFR57: MTU configured at 1280 bytes to prevent VXLAN packet fragmentation over Tailscale

**Gaming Platform (5 NFRs)**
- NFR51: Gaming Mode activation completes within 30 seconds (pod scale-down + VRAM release)
- NFR52: ML Mode restoration completes within 2 minutes (pod scale-up + model load)
- NFR53: Steam games achieve 60+ FPS at 1080p with exclusive GPU access
- NFR54: Graceful degradation to Ollama CPU maintains <5 second inference latency
- NFR70: ML Mode auto-activates within 5 minutes of k3s-gpu-worker boot (after k3s agent ready)

**AI Classification Performance - Paperless-AI (7 NFRs)**
- NFR58: Qwen 2.5 14B produces valid JSON output for 95%+ of document classification requests (Story 12.8)
- NFR59: RAG document search returns relevant context within 5 seconds (Story 12.9)
- NFR60: Web UI configuration changes take effect without pod restart (Story 12.9)
- NFR61: CPU Ollama with Qwen 2.5 14B achieves acceptable inference speed (Story 12.8)
- NFR62: Document classification latency <60 seconds with CPU Ollama (Story 12.8)
- NFR63: vLLM achieves <5 second document classification latency with GPU-accelerated qwen2.5:14b (Story 12.10)
- NFR64: vLLM serves qwen2.5:14b with 35-40 tokens/second throughput on RTX 3060 (Story 12.10)

**LiteLLM Inference Proxy (5 NFRs)**
- NFR65: LiteLLM failover detection completes within 5 seconds of backend unavailability
- NFR66: LiteLLM adds <100ms latency to inference requests during normal operation
- NFR67: Paperless-AI document processing continues (degraded) during Gaming Mode via fallback chain
- NFR68: OpenAI fallback tier only activated when both vLLM and Ollama are unavailable
- NFR69: LiteLLM health endpoint responds within 1 second for readiness probes

**Tailscale Subnet Router (2 NFRs)**
- NFR71: Subnet routes advertised within 60 seconds of node boot
- NFR72: Subnet router failover: if one router goes down, network segment remains accessible via direct Tailscale connection

**Synology NAS K3s Worker (2 NFRs)**
- NFR73: NAS worker VM allocated maximum 2 vCPU, 4GB RAM to preserve NAS primary functions
- NFR74: NAS worker node joins cluster within 3 minutes of VM boot

**Open-WebUI Application (2 NFRs)**
- NFR75: Open-WebUI web interface loads within 3 seconds
- NFR76: Chat history persisted to NFS storage surviving pod restarts

**Kubernetes Dashboard (2 NFRs)**
- NFR77: Dashboard loads cluster overview within 5 seconds
- NFR78: Dashboard access restricted to Tailscale network only

**Gitea Self-Hosted Git (2 NFRs)**
- NFR79: Gitea repository operations (clone, push, pull) complete within 10 seconds for typical repos
- NFR80: Gitea web interface loads within 3 seconds

**DeepSeek-R1 14B Reasoning Mode (2 NFRs)**
- NFR81: R1-Mode model loading completes within 90 seconds
- NFR82: DeepSeek-R1 achieves 30+ tokens/second on RTX 3060 for reasoning tasks

**LiteLLM External Providers (2 NFRs)**
- NFR83: External provider failover activates within 5 seconds when local models unavailable
- NFR84: Rate limiting configured to stay within free tier quotas per provider

**Blog Article Completion (1 NFR)**
- NFR85: Blog post published to dev.to or equivalent platform within 2 weeks of Epic completion

**OpenClaw Performance (5 NFRs)**
- NFR86: OpenClaw gateway responds to incoming Telegram/WhatsApp/Discord messages within 10 seconds (excluding LLM inference time)
- NFR87: Gateway control UI loads within 3 seconds via Traefik ingress
- NFR88: LiteLLM fallback activates within 5 seconds of detecting Anthropic unavailability
- NFR89: mcporter MCP tool invocations (Exa research) return results within 30 seconds
- NFR90: Voice responses via ElevenLabs begin streaming within 5 seconds of request

**OpenClaw Security (5 NFRs)**
- NFR91: All API credentials (Anthropic OAuth, Telegram, WhatsApp, Discord, ElevenLabs, Exa) stored as Kubernetes Secrets, never in plaintext ConfigMaps
- NFR92: DM pairing enforces allowlist-only policy -- unapproved senders receive no response
- NFR93: Gateway control UI accessible only via Tailscale mesh (no public exposure)
- NFR94: OAuth tokens rotated and refreshed automatically; manual refresh available via control UI
- NFR95: No API keys or secrets exposed in Loki logs or Grafana dashboards

**OpenClaw Integration (4 NFRs)**
- NFR96: Anthropic OAuth maintains persistent connection; automatic reconnection on transient failures within 30 seconds
- NFR97: Telegram, WhatsApp, and Discord channels automatically reconnect after network interruptions within 60 seconds
- NFR98: mcporter MCP server connections recover gracefully from timeouts without crashing the gateway
- NFR99: LiteLLM internal cluster service (`litellm.ml.svc`) reachable from `apps` namespace via standard K8s DNS resolution

**OpenClaw Reliability (5 NFRs)**
- NFR100: OpenClaw pod restarts cleanly after node reboot with all configuration and workspace intact from NFS
- NFR101: Gateway survives individual channel disconnections without affecting other channels
- NFR102: Pod crash loop triggers Alertmanager notification within 2 minutes
- NFR103: Loki retains OpenClaw gateway logs for a minimum of 7 days
- NFR104: Blackbox Exporter probe interval of 30 seconds with alerting after 3 consecutive failures

**OpenClaw Memory (2 NFRs)**
- NFR105: Memory embedding latency does not exceed 500ms per message using OpenAI API (`text-embedding-3-small`); local Xenova not supported by memory-lancedb plugin
- NFR106: LanceDB memory data persists across pod restarts via local PVC (`openclaw-data`) on k3s-worker-01

**Document Processing Pipeline Upgrade (10 NFRs)**
- NFR107: Document metadata generation completes within 5 seconds via GPU vLLM (Qwen3-8B-AWQ)
- NFR108: Auto-tagging accuracy achieves 90%+ for common document types via GPU inference
- NFR109: Auto-tagging accuracy achieves 70%+ via CPU fallback (phi4-mini on Ollama)
- NFR110: Qwen3 models produce valid structured output for 95%+ of classification requests
- NFR111: CPU Ollama (phi4-mini) completes document classification within 60 seconds
- NFR112: Paperless-GPT prompt template changes take effect without pod restart
- NFR113: Docling server extracts structured text from PDFs within 30 seconds
- NFR114: Docling Granite-Docling VLM pipeline runs on CPU with <1GB memory footprint
- NFR115: vLLM v0.10.2+ maintains compatibility with existing CLI arguments
- NFR116: vLLM upgrade does not disrupt DeepSeek-R1 deployment

**Ollama Pro Cloud Model Integration (5 NFRs)**
- NFR121: Cloud model API requests to `ollama.com` complete within 60 seconds (remote execution on Ollama's servers; LiteLLM `timeout: 60` per cloud model entry)
- NFR122: `OLLAMA_API_KEY` stored securely as a Kubernetes secret; applied only via `kubectl patch` — never via `kubectl apply` with a placeholder value
- NFR123: LiteLLM failover from cloud models to local tier (`vllm-qwen` → `ollama-qwen`) activates within 5 seconds of cloud API unavailability, consistent with NFR65
- NFR124: All three cloud models automatically visible in Open-WebUI model picker via LiteLLM `/v1/models` without per-model wiring in the Helm values
- NFR125: openclaw local LiteLLM fallback (vLLM GPU → Ollama CPU) remains fully functional after cloud model primary migration; fallback behavior unchanged from pre-migration state

### Additional Requirements

**From Architecture Document:**

- **Implementation Approach**: Manual + Helm (Learning-First) - VMs provisioned manually via Proxmox UI, K3s via curl installer
- **NFS Provisioner**: nfs-subdir-external-provisioner via Helm with dynamic StorageClass
- **Observability Stack**: kube-prometheus-stack (includes Prometheus, Grafana, Alertmanager, Node Exporter, kube-state-metrics)
- **Log Aggregation**: Loki with Promtail for log collection
- **PostgreSQL**: Bitnami Helm chart with NFS-backed PVC
- **Ollama**: Official Helm chart, CPU for MVP (GPU deferred to Phase 2)
- **Backup Strategy**: etcd snapshots (K3s built-in) + pg_dump to NFS + Git repository for manifests
- **TLS**: cert-manager with Let's Encrypt Production issuer
- **Naming Patterns**: {app}-{component} for resources, Kubernetes recommended labels (app.kubernetes.io/*)
- **Repository Structure**: Layer-based (infrastructure/, applications/, monitoring/, docs/, scripts/)
- **Helm Values Pattern**: values-homelab.yaml for each chart
- **Implementation Sequence**: K3s → NFS → cert-manager → MetalLB → kube-prometheus-stack → Loki → PostgreSQL → Ollama → Nginx

**Namespace Strategy:**
| Namespace | Purpose |
|-----------|---------|
| kube-system | K3s core, Traefik |
| infra | MetalLB, cert-manager, NFS provisioner |
| monitoring | Prometheus, Grafana, Loki, Alertmanager |
| data | PostgreSQL |
| apps | n8n |
| ml | Ollama, vLLM (GPU workloads) |
| docs | Paperless-ngx, Redis |
| dev | Nginx proxy, dev containers |

**Phase 2 Architecture Additions:**

**Document Management (Paperless-ngx):**
- Backend: PostgreSQL (shared with existing cluster database, not Redis)
- OCR: Tesseract with German (deu) + English (eng) language packs
- Storage: NFS PVC for documents (snapshot-protected)
- Scaling: PostgreSQL backend supports 5,000+ documents
- Deployment: Community Helm chart with custom values

**Dev Containers:**
- Base image: Single Dockerfile with Node.js, Python, Claude Code CLI, git, kubectl, helm
- Access: SSH via Nginx proxy (nginx already handles routing in `dev` namespace)
- Storage: Hybrid model (Git repos on NFS PVC 10GB, build artifacts on emptyDir)
- Resources: 2 CPU cores, 4GB RAM per container
- Capacity: Cluster supports 2-3 dev containers simultaneously
- NetworkPolicy: Moderate isolation (access cluster services, no cross-container communication)
- Lifecycle: Kubernetes Deployment per container, SSH server enabled

**GPU/ML Infrastructure (vLLM + RTX 3060):**
- GPU Worker: Intel NUC + RTX 3060 12GB eGPU
- GPU Networking: Solution A - Manual Tailscale on all K3s nodes for full mesh connectivity
- K3s Configuration: `--flannel-iface tailscale0` + `--node-external-ip <tailscale-ip>`
- MTU: 1280 bytes (prevents VXLAN fragmentation over Tailscale)
- NO_PROXY: Must include `100.64.0.0/10` for kubectl logs/exec to work
- Models: DeepSeek-Coder 6.7B, Mistral 7B, Llama 3.1 8B (4-bit quantized)
- Model Serving: Single vLLM instance, 3 models loaded in memory
- Context Window: 8K-16K tokens per request
- VRAM Allocation: ~16GB total (10-11GB models, 1-2GB KV cache, remaining headroom)
- Hot-plug Capability: GPU worker can join/leave cluster without disruption
- Graceful Degradation: vLLM workloads fall back to Ollama CPU when GPU offline
- GPU Scheduling: NVIDIA GPU Operator for automatic driver installation

**Node Topology:**
| Node | Role | Physical IP | Tailscale IP |
|------|------|-------------|--------------|
| k3s-master | Control plane | 192.168.2.20 | 100.x.x.a |
| k3s-worker-01 | General compute | 192.168.2.21 | 100.x.x.b |
| k3s-worker-02 | General compute | 192.168.2.22 | 100.x.x.c |
| k3s-gpu-worker | GPU (Intel NUC) | 192.168.0.25 | 100.x.x.d |

**MetalLB IP Pool:** 192.168.2.100-120

**Ollama Pro Cloud Model Integration Architecture (Epic 26):**
- LiteLLM is the explicit cloud gatekeeper — Ollama pod is untouched; clean cloud/local separation
- Cloud API base: `https://ollama.com/api` (CRITICAL: `/api` suffix required — `https://api.ollama.com` returns 404)
- Provider type: `ollama_chat` (not `ollama`) for Ollama Pro cloud API
- Model name format: `{model}:XXb-cloud` suffix mandatory — omitting it returns "model not found"
- Exact cloud model tags must be confirmed at implementation via Ollama Pro dashboard (`ollama ls --cloud`)
- Anthropic fully removed from openclaw (legal constraint) — `anthropic:subscription` OAuth, `ANTHROPIC_OAUTH_TOKEN`, and all `anthropic/` model references removed; zero Anthropic fallback by design
- openclaw primary: `cloud-kimi` (kimi-k2.5) — chosen over cloud-minimax for image input capability needed for browser automation
- openclaw fallback chain: `cloud-minimax` → `vllm-qwen` → `ollama-qwen` (full local inference preserved)
- openclaw coder sub-agents: `cloud-qwen3-coder` (qwen3-coder:480b-cloud, purpose-built for agentic coding)
- Updated routing: `cloud-kimi` → `cloud-minimax` → `vllm-qwen` → `ollama-qwen`; `cloud-minimax` → `vllm-qwen` → `ollama-qwen`; `cloud-qwen3-coder` → `vllm-qwen` → `ollama-qwen`
- Secrets: `LITELLM_MASTER_KEY` added to openclaw secrets; `ANTHROPIC_OAUTH_TOKEN` removed via `kubectl patch ... --type='json' -p '[{"op":"remove"...}]'`
- Operational mode: Cloud unaffected by Gaming Mode (GPU scaled to 0 → cloud still routes correctly)
- Full outage (cloud + GPU + CPU all down): Error — no Anthropic fallback by design

**OpenClaw Architecture (from Architecture Document):**
- Deployed as Kubernetes Deployment in `apps` namespace (official openclaw/openclaw Docker image, Node.js >= 22)
- Storage: NFS PVC (10Gi) for `~/.clawdbot` config + `~/clawd/` workspace
- Ingress: `openclaw.home.jetzinger.com` via Traefik IngressRoute
- LLM routing: Inverse fallback pattern -- cloud primary (Opus 4.5 via Anthropic OAuth) -> local fallback (LiteLLM proxy at `litellm.ml.svc:4000`)
- Messaging channels: Telegram (long-polling), WhatsApp (Baileys), Discord (discord.js) -- all outbound, no inbound exposure
- MCP tools: mcporter with Exa + additional research servers, installed to workspace NFS
- Voice: ElevenLabs TTS/STT via API
- Multi-agent: Native sub-agent routing
- Browser automation: Built-in browser tool
- Skills: ClawdHub marketplace integration
- Observability: Log-based pattern (Loki + Blackbox Exporter) since no native /metrics endpoint
  - Grafana dashboard with LogQL queries (message volume, LLM routing, MCP invocations, errors)
  - Blackbox HTTP probe on gateway UI (30s interval, alert after 3 failures)
  - Alertmanager rules: gateway down (P1), high error rate (P2), OAuth expiry (P2)
- Secrets: 7 credential types in K8s Secrets (Anthropic OAuth, Telegram, WhatsApp, Discord, ElevenLabs, Exa, additional MCP)
- DM security: Allowlist-only pairing across all channels
- WhatsApp persistence: Baileys auth state on NFS PVC to survive pod restarts

### FR Coverage Map

| FR | Epic | Description |
|----|------|-------------|
| FR1 | Epic 1 | Deploy K3s control plane on VM |
| FR2 | Epic 1 | Add worker nodes to cluster |
| FR3 | Epic 1 | Remove worker nodes without data loss |
| FR4 | Epic 1 | View cluster node status and health |
| FR5 | Epic 1 | Access cluster remotely via Tailscale |
| FR6 | Epic 1 | Run kubectl from Tailscale-connected device |
| FR7 | Epic 4 | Deploy containerized applications (validated with Prometheus) |
| FR8 | Epic 5 | Deploy applications using Helm charts (validated with PostgreSQL) |
| FR9 | Epic 3 | Expose applications via ingress with HTTPS |
| FR10 | Epic 3 | Configure automatic TLS certificate provisioning |
| FR11 | Epic 4 | Assign workloads to specific namespaces |
| FR12 | Epic 6 | Scale deployments up or down |
| FR13 | Epic 6 | View pod logs and events |
| FR14 | Epic 2 | Provision persistent volumes from NFS |
| FR15 | Epic 2 | Create PersistentVolumeClaims for applications |
| FR16 | Epic 2 | System provisions storage dynamically via StorageClass |
| FR17 | Epic 2 | Verify storage mount health |
| FR18 | Epic 2 | Backup persistent data to Synology snapshots |
| FR19 | Epic 3 | Expose services via LoadBalancer using MetalLB |
| FR20 | Epic 3 | Configure ingress routes via Traefik |
| FR21 | Epic 3 | Access services via *.home.jetzinger.com domain |
| FR22 | Epic 3 | System resolves internal DNS via NextDNS |
| FR23 | Epic 3 | View Traefik dashboard for ingress status |
| FR24 | Epic 4 | View cluster metrics in Grafana dashboards |
| FR25 | Epic 4 | Query Prometheus for historical metrics |
| FR26 | Epic 4 | System collects metrics from all nodes via Node Exporter |
| FR27 | Epic 4 | System collects K8s object metrics via kube-state-metrics |
| FR28 | Epic 4 | System sends alerts via Alertmanager |
| FR29 | Epic 4 | Receive mobile notifications for P1 alerts |
| FR30 | Epic 4 | View alert history and status |
| FR31 | Epic 5 | Deploy PostgreSQL as StatefulSet |
| FR32 | Epic 5 | PostgreSQL persists data to NFS storage |
| FR33 | Epic 5 | Backup PostgreSQL to NFS |
| FR34 | Epic 5 | Restore PostgreSQL from backup |
| FR35 | Epic 5 | Applications can connect to PostgreSQL |
| FR36 | Epic 6 | Deploy Ollama for LLM inference |
| FR37 | Epic 6 | Applications can query Ollama API |
| FR38 | Epic 12 | Deploy vLLM for production inference |
| FR39 | Epic 12 | GPU workloads request GPU resources via NVIDIA Operator |
| FR40 | Epic 6 | Deploy n8n for workflow automation |
| FR41 | Epic 7 | Configure Nginx to proxy to local dev servers |
| FR42 | Epic 7 | Access local dev servers via cluster ingress |
| FR43 | Epic 7 | Add/remove proxy targets without cluster restart |
| FR44 | Epic 8 | Upgrade K3s version on nodes |
| FR45 | Epic 8 | Backup cluster state via Velero |
| FR46 | Epic 8 | Restore cluster from Velero backup |
| FR47 | Epic 8 | System applies security updates to node OS |
| FR48 | Epic 8 | View upgrade history and rollback if needed |
| FR49 | Epic 9 | Audience can view public GitHub repository |
| FR50 | Epic 9 | Audience can read ADRs |
| FR51 | Epic 9 | Audience can view Grafana dashboard screenshots |
| FR52 | Epic 9 | Audience can read technical blog posts |
| FR53 | Epic 9 | Document decisions as ADRs in repository |
| FR54 | Epic 9 | Publish blog posts to dev.to or similar |
| FR55 | Epic 10 | Deploy Paperless-ngx with Redis backend |
| FR56 | Epic 10 | Paperless-ngx persists documents to NFS |
| FR57 | Epic 10 | Access Paperless-ngx via ingress with HTTPS |
| FR58 | Epic 10 | Upload, tag, and search scanned documents |
| FR59 | Epic 11 | Nginx proxy routes to dev containers |
| FR60 | Epic 11 | Provision dev containers with git worktree support |
| FR61 | Epic 11 | Connect VS Code to dev container via Nginx |
| FR62 | Epic 11 | Run Claude Code inside dev containers |
| FR63 | Epic 11 | Dev containers use local storage for workspace |
| FR64 | Epic 10 | Paperless-ngx performs OCR with German and English support |
| FR65 | Epic 10 | System handles thousands of documents |
| FR66 | Epic 10 | Paperless-ngx uses PostgreSQL backend for metadata (deferred to future) |
| FR67 | Epic 11 | Dev containers use single base image with standard tools |
| FR68 | Epic 11 | Each dev container allocated 2 CPU cores and 4GB RAM |
| FR69 | Epic 11 | Dev containers mount persistent 10GB volumes |
| FR70 | Epic 11 | Dev containers isolated via NetworkPolicy |
| FR71 | Epic 12 | GPU worker joins cluster via Tailscale overlay network |
| FR72 | Epic 12 | Ollama serves Qwen 2.5 14B as unified model for all inference tasks |
| FR73 | Epic 12 | GPU Ollama gracefully degrades to CPU Ollama when GPU offline |
| FR74 | Epic 12 | Operator can hot-plug GPU worker without cluster disruption |
| FR94 | Epic 12 | Ollama gracefully degrades when GPU unavailable due to host workloads |
| FR95 | Epic 13 | Intel NUC runs Steam on host Ubuntu OS |
| FR96 | Epic 13 | Steam uses Proton for Windows game compatibility |
| FR97 | Epic 13 | Operator can switch between Gaming Mode and ML Mode via script |
| FR98 | Epic 13 | Gaming Mode scales Ollama pods to 0 and enables CPU fallback |
| FR99 | Epic 13 | ML Mode restores GPU Ollama pods when gaming exits |
| FR100 | Epic 12 | All K3s nodes run Tailscale for full mesh connectivity |
| FR101 | Epic 12 | K3s configured with --flannel-iface tailscale0 |
| FR102 | Epic 12 | K3s nodes advertise Tailscale IPs via --node-external-ip |
| FR103 | Epic 12 | NO_PROXY includes Tailscale CGNAT range (100.64.0.0/10) |
| FR113 | Epic 14 | LiteLLM proxy deployed in `ml` namespace |
| FR114 | Epic 14 | LiteLLM configured with multi-tier fallback |
| FR115 | Epic 14 | Paperless-AI configured to use LiteLLM endpoint |
| FR116 | Epic 14 | LiteLLM auto-routes to fallback tier on health check failure |
| FR117 | Epic 14 | OpenAI API key stored securely via K8s secret |
| FR118 | Epic 14 | LiteLLM exposes Prometheus metrics |
| FR119 | Epic 13 | k3s-gpu-worker boots into ML Mode by default |
| FR120 | Epic 15 | k3s-master as Tailscale subnet router (192.168.2.0/24) |
| FR121 | Epic 15 | k3s-gpu-worker as Tailscale subnet router (192.168.0.0/24) |
| FR122 | Epic 15 | Tailscale ACLs configured for subnet route access |
| FR123 | Epic 16 | K3s worker VM deployed on Synology DS920+ |
| FR124 | Epic 16 | NAS worker node labeled for lightweight workloads |
| FR125 | Epic 16 | NAS worker node tainted to prevent general scheduling |
| FR126 | Epic 17 | Open-WebUI deployed with persistent chat history |
| FR127 | Epic 17 | Open-WebUI configured to use LiteLLM backend |
| FR128 | Epic 17 | Open-WebUI accessible at chat.home.jetzinger.com |
| FR129 | Epic 17 | Open-WebUI supports model switching |
| FR130 | Epic 18 | Kubernetes Dashboard deployed in `infra` namespace |
| FR131 | Epic 18 | Dashboard accessible at dashboard.home.jetzinger.com |
| FR132 | Epic 18 | Dashboard authentication via bearer token |
| FR133 | Epic 18 | Dashboard provides read-only view of all resources |
| FR134 | Epic 19 | Gitea deployed with PostgreSQL backend |
| FR135 | Epic 19 | Gitea accessible at git.home.jetzinger.com |
| FR136 | Epic 19 | Gitea persists repositories to NFS |
| FR137 | Epic 19 | Gitea configured for single-user SSH auth |
| FR138 | Epic 20 | DeepSeek-R1 14B deployed via vLLM |
| FR139 | Epic 20 | R1-Mode added as third GPU mode |
| FR140 | Epic 20 | Mode switching script supports R1-Mode |
| FR141 | Epic 20 | LiteLLM configured with DeepSeek-R1 as reasoning tier |
| FR142 | Epic 14 | LiteLLM configured with Groq free tier (parallel model) |
| FR143 | Epic 14 | LiteLLM configured with Google AI Studio (parallel model) |
| FR144 | Epic 14 | LiteLLM configured with Mistral API (parallel model) |
| FR145 | Epic 14 | External provider API keys stored via K8s secrets |
| FR146 | Epic 9 | Technical blog post covering Phase 1 MVP + new features |
| FR147 | Epic 9 | Blog includes architecture diagrams and Grafana screenshots |
| FR148 | Epic 9 | Blog documents AI-assisted engineering workflow |
| FR149 | Epic 21 | Deploy OpenClaw Gateway on K3s in apps namespace |
| FR150 | Epic 21 | Gateway control UI via openclaw.home.jetzinger.com |
| FR151 | Epic 21 | Configure OpenClaw via openclaw.json on NFS |
| FR152 | Epic 21 | Preserve config and workspace across pod restarts |
| FR153 | Epic 21 | View gateway status and health via control UI |
| FR154 | Epic 21 | Restart gateway via control UI |
| FR155 | Epic 21 | Route conversations to Opus 4.5 via Anthropic OAuth |
| FR156 | Epic 21 | Fall back to LiteLLM when Anthropic unavailable |
| FR157 | Epic 21 | Identify which LLM provider is handling conversation |
| FR158 | Epic 21 | Manage Anthropic OAuth via gateway control UI |
| FR159 | Epic 21 | Telegram DM messaging channel |
| FR160 | Epic 22 | WhatsApp DM messaging channel |
| FR161 | Epic 22 | Discord DM messaging channel |
| FR162 | Epic 21 | Enforce allowlist-only DM pairing |
| FR163 | Epic 21 | Approve/reject pairing requests via gateway CLI |
| FR164 | Epic 22 | Cross-channel conversation context continuity |
| FR165 | Epic 22 | Web research via Exa MCP tools |
| FR166 | Epic 22 | Install additional MCP research servers via mcporter |
| FR167 | Epic 22 | Invoke MCP tools through natural language |
| FR168 | Epic 22 | Structured, sourced responses from research tools |
| FR169 | Epic 23 | Voice input/output via ElevenLabs |
| FR170 | Epic 23 | Switch between text and voice modes |
| FR171 | Epic 23 | Configure specialized sub-agents |
| FR172 | Epic 23 | Invoke sub-agents from main conversation |
| FR173 | Epic 23 | Route tasks to sub-agents based on context |
| FR174 | Epic 23 | Trigger browser automation via conversation |
| FR175 | Epic 23 | Navigate web, fill forms, extract information |
| FR176 | Epic 23 | Present rich content via Canvas/A2UI |
| FR177 | Epic 23 | Install skills from ClawdHub marketplace |
| FR178 | Epic 23 | Update and sync installed skills |
| FR179 | Epic 23 | Invoke skills via slash commands or conversation |
| FR180 | Epic 23 | Enable/disable/configure individual skills |
| FR181 | Epic 24 | Collect gateway logs into Loki |
| FR182 | Epic 24 | Grafana dashboard with log-derived metrics |
| FR183 | Epic 24 | Dashboard: message volume, LLM usage, MCP tools, errors |
| FR184 | Epic 24 | Blackbox Exporter probes gateway UI |
| FR185 | Epic 24 | Alertmanager rules for gateway/errors/OAuth |
| FR186 | Epic 24 | Health snapshot via openclaw health --json |
| FR187 | Epic 24 | ADR documenting OpenClaw architectural decisions |
| FR188 | Epic 24 | README OpenClaw section with architecture overview |
| FR189 | Epic 21 | Configure memory-lancedb plugin with local Xenova embeddings |
| FR190 | Epic 21 | Auto-capture/recall conversation context via LanceDB |
| FR191 | Epic 21 | Manage memory index via openclaw memory CLI commands |

| FR215 | Epic 26 | OLLAMA_API_KEY secret management via kubectl patch |
| FR216 | Epic 26 | LiteLLM model_list updated with three cloud model entries |
| FR217 | Epic 26 | LiteLLM fallbacks updated — cloud cascades to local tier |
| FR218 | Epic 26 | openai-gpt4o removed from auto-fallback chain |
| FR219 | Epic 26 | paperless-gpt updated to cloud-minimax default model |
| FR220 | Epic 26 | open-webui updated to cloud-minimax default; cloud models in picker |
| FR221 | Epic 26 | n8n configured with LiteLLM credential via UI |
| FR222 | Epic 26 | openclaw primary migrated to cloud-kimi; Anthropic removed |
| FR223 | Epic 26 | openclaw coder sub-agents migrated to cloud-qwen3-coder |

**Coverage Summary:** 223 FRs total, 125 NFRs total
- **Phase 1 (Epic 1-9):** 54 FRs completed + 3 new (FR146-148 for Blog Article)
  - Epic 9 (Portfolio): FR49-54, FR146-148
- **Phase 2 (Epic 10-12):** 49 FRs
  - Epic 10 (Paperless-ngx): FR55-58, FR64-66, FR75-93
  - Epic 11 (Dev Containers): FR59-63, FR67-70
  - Epic 12 (GPU/ML - vLLM + Qwen 2.5 14B): FR38-39, FR71-74, FR87-89, FR94, FR100-112
- **Phase 3 (Epic 13-14):** 12 FRs + 4 new (FR142-145 for External Providers)
  - Epic 13 (Steam Gaming): FR95-99, FR119
  - Epic 14 (LiteLLM Inference Proxy): FR113-118, FR142-145
- **Phase 4 (Epic 15-20):** 22 FRs
  - Epic 15 (Tailscale Subnet Router): FR120-122
  - Epic 16 (NAS K3s Worker): FR123-125
  - Epic 17 (Open-WebUI): FR126-129
  - Epic 18 (K8s Dashboard): FR130-133
  - Epic 19 (Gitea): FR134-137
  - Epic 20 (DeepSeek-R1): FR138-141
- **Phase 5 (Epic 21-24 - NEW):** 43 FRs (FR149-191), 21 NFRs (NFR86-106)
  - Epic 21 (OpenClaw Core Gateway & Telegram): FR149-159, FR162-163, FR189-191
  - Epic 22 (OpenClaw Research & Multi-Channel): FR160-161, FR164-168
  - Epic 23 (OpenClaw Advanced Capabilities): FR169-180
  - Epic 24 (OpenClaw Observability & Documentation): FR181-188

## Epic List

### Epic 1: Foundation - K3s Cluster with Remote Access
Tom has a working multi-node K3s cluster he can access from anywhere via Tailscale.
**FRs covered:** FR1, FR2, FR3, FR4, FR5, FR6

### Epic 2: Storage & Persistence
Tom can provision persistent NFS storage for any application needing data persistence.
**FRs covered:** FR14, FR15, FR16, FR17, FR18

### Epic 3: Ingress, TLS & Service Exposure
Tom can expose any service with HTTPS via *.home.jetzinger.com domains.
**FRs covered:** FR9, FR10, FR19, FR20, FR21, FR22, FR23

### Epic 4: Observability Stack
Tom can monitor the cluster, view dashboards, and receive P1 alerts on his phone.
**FRs covered:** FR7, FR11, FR24, FR25, FR26, FR27, FR28, FR29, FR30

### Epic 5: PostgreSQL Database Service
Tom has a production-grade PostgreSQL database with backup and restore capability.
**FRs covered:** FR8, FR31, FR32, FR33, FR34, FR35

### Epic 6: AI Inference Platform
Tom can run LLM inference (Ollama) and workflow automation (n8n) on the cluster.
**FRs covered:** FR12, FR13, FR36, FR37, FR40

### Epic 7: Development Proxy
Tom can access local development servers through cluster ingress.
**FRs covered:** FR41, FR42, FR43

### Epic 8: Cluster Operations & Maintenance
Tom can upgrade K3s, backup/restore the cluster, and maintain long-term operations.
**FRs covered:** FR44, FR45, FR46, FR47, FR48

### Epic 9: Portfolio & Public Showcase
Tom has a polished public portfolio that demonstrates capability to hiring managers and recruiters, including comprehensive technical blog coverage.
**FRs covered:** FR49-54, FR146-148
**NFRs covered:** NFR85

### Epic 10: Document Management System (Paperless-ngx Ecosystem) [Phase 2]

**User Outcome:** Tom can digitize, organize, and search thousands of scanned documents with OCR support for German and English, AI-powered auto-tagging, Office document processing, PDF editing, and automatic email attachment import—replacing physical paper filing with a comprehensive digital archive.

**FRs covered:** FR55-58, FR64-66, FR75-93
- FR55: Deploy Paperless-ngx with Redis backend
- FR56: Documents persist to NFS storage
- FR57: Access via HTTPS ingress
- FR58: Upload, tag, and search documents
- FR64: OCR with German and English language support
- FR65: Handle thousands of documents (ongoing workflow)
- FR66: PostgreSQL backend for metadata
- FR75: Single-user operation with folder-based organization
- FR76: Duplicate document detection on import
- FR77: NFS mount for consume folders from workstation
- FR78: Auto-import from consume folders within 30 seconds
- FR79: CSRF protection for web interface
- FR80: CORS restricted to authorized origins
- FR81: Apache Tika for Office document text extraction
- FR82: Gotenberg for Office-to-PDF conversion
- FR83: Direct import of Word, Excel, PowerPoint, LibreOffice formats
- FR84: Stirling-PDF for PDF manipulation
- FR85: Split, merge, rotate, compress PDFs via web UI
- FR86: Stirling-PDF ingress with HTTPS
- FR87: Paperless-AI connects to GPU Ollama (Intel NUC + RTX 3060)
- FR88: LLM-based auto-tagging via GPU-accelerated inference
- FR89: Auto-populate correspondents and document types
- FR104: Ollama configured with Qwen 2.5 14B for reliable JSON-structured document metadata extraction (Story 12.8)
- FR105: Paperless-AI model configurable via ConfigMap without code changes (Story 12.8)
- FR106: clusterzx/paperless-ai deployed with web-based configuration UI (Story 12.9)
- FR107: RAG-based document chat enables natural language queries across document archive (Story 12.9)
- FR108: Document classification rules configurable via web interface (Story 12.9)
- FR90: Monitor private email inbox via IMAP
- FR91: Monitor Gmail inbox via IMAP
- FR92: Auto-import email attachments (PDF, Office docs)
- FR93: Email bridge container for IMAP access

**NFRs covered:** NFR28-30, NFR39-49
- NFR28: 95%+ OCR accuracy (German/English)
- NFR29: Scale to 5,000+ documents
- NFR30: 3-second full-text search
- NFR39: NFS polling mode (inotify incompatible)
- NFR40: 10-second polling interval
- NFR41: 2 parallel OCR workers
- NFR42: GPU inference throughput 50+ tokens/sec
- NFR43: AI classification within 10 seconds per document

**Implementation Notes:**
- PostgreSQL backend (shared cluster database)
- Tesseract OCR with German (deu) + English (eng) language packs
- NFS storage with Synology snapshot protection
- gabe565 Helm chart for Paperless-ngx
- Apache Tika + Gotenberg for Office document processing
- Stirling-PDF via official Helm chart
- Paperless-AI connector to GPU Ollama on Intel NUC
- Email bridge for private email + Gmail direct IMAP

---

### Epic 11: Dev Containers Platform [Phase 2]

**User Outcome:** Tom can develop remotely using isolated dev containers with VS Code and Claude Code, accessing full development tooling via SSH through the cluster's Nginx proxy with persistent workspace storage.

**FRs covered:** FR59, FR60, FR61, FR62, FR63, FR67, FR68, FR69, FR70
- FR59: Nginx proxy routes to dev containers
- FR60: Provision dev containers with git worktree support
- FR61: Connect VS Code via Nginx proxy
- FR62: Run Claude Code inside dev containers
- FR63: Use local storage for workspace data
- FR67: Single base image (Node.js, Python, Claude Code CLI, git, kubectl, helm)
- FR68: 2 CPU cores, 4GB RAM per container
- FR69: Persistent 10GB volumes for workspace data
- FR70: NetworkPolicy isolation (accessible only via nginx proxy)

**NFRs covered:** NFR31, NFR32, NFR33
- NFR31: 90-second provisioning time
- NFR32: Persistent workspace data across restarts
- NFR33: NetworkPolicy isolation (no cross-container communication)

**Implementation Notes:**
- Single base Docker image with standard dev tools
- Hybrid storage: NFS PVC (10GB) for git repos, emptyDir for build artifacts
- SSH access via Nginx stream proxy
- Cluster capacity: 2-3 concurrent dev containers
- NetworkPolicy: Access cluster services, blocked cross-container

---

### Epic 12: GPU/ML Inference Platform (Ollama + Qwen 2.5 14B) [Phase 2]

**User Outcome:** Tom can run GPU-accelerated LLM inference with Ollama serving the unified Qwen 2.5 14B model on a hot-pluggable GPU worker, with automatic graceful degradation to Ollama CPU when the GPU worker is offline or host is using the GPU for gaming, enabling high-quality AI inference for n8n workflows, Paperless-AI document classification (with RAG chat), and development tasks.

**FRs covered:** FR38, FR39, FR71-74, FR87-89, FR94, FR100-112
- FR38: Deploy Ollama with Qwen 2.5 14B for unified GPU inference
- FR39: GPU workloads request GPU resources via NVIDIA Operator
- FR71: GPU worker (Intel NUC + RTX 3060) joins cluster via Tailscale mesh (Solution A)
- FR72: Ollama serves Qwen 2.5 14B as unified model for all inference tasks
- FR73: GPU Ollama gracefully degrades to CPU Ollama when GPU offline
- FR74: Hot-plug GPU worker (add/remove without cluster disruption)
- FR87: Paperless-AI connects to GPU Ollama (Intel NUC + RTX 3060)
- FR88: LLM-based auto-tagging via GPU-accelerated inference
- FR89: Auto-populate correspondents and document types from content
- FR94: Ollama gracefully degrades to CPU when GPU unavailable (Steam gaming)
- FR100: All K3s nodes run Tailscale for full mesh connectivity
- FR101: K3s configured with `--flannel-iface tailscale0` for pod networking
- FR102: K3s nodes advertise Tailscale IPs via `--node-external-ip`
- FR103: NO_PROXY includes Tailscale CGNAT range (100.64.0.0/10)
- FR104: Ollama configured with Qwen 2.5 14B for reliable JSON-structured metadata extraction
- FR105: Paperless-AI model configurable via ConfigMap without code changes
- FR106: clusterzx/paperless-ai deployed with web-based configuration UI
- FR107: RAG-based document chat enables natural language queries
- FR108: Document classification rules configurable via web interface

**NFRs covered:** NFR34-38, NFR50, NFR55-62
- NFR34: Ollama achieves acceptable inference speed for Qwen 2.5 14B on CPU
- NFR35: Handle concurrent inference requests
- NFR36: GPU worker joins cluster in 2 minutes via Tailscale
- NFR37: NVIDIA GPU Operator installs drivers automatically
- NFR38: Ollama serves Qwen 2.5 14B as unified model for all tasks
- NFR50: Ollama available as fallback when GPU unavailable
- NFR55: Tailscale mesh establishes connectivity within 60 seconds
- NFR56: Pod-to-pod communication across subnets (192.168.0.x ↔ 192.168.2.x)
- NFR57: MTU 1280 bytes for VXLAN over Tailscale
- NFR58: Qwen 2.5 14B produces valid JSON 95%+ of requests
- NFR59: RAG document search returns context within 5 seconds
- NFR60: Web UI config changes without pod restart
- NFR61: CPU Ollama achieves acceptable inference speed (Story 12.8)
- NFR62: Document classification latency <60 seconds with CPU (Story 12.8)
- NFR63: vLLM achieves <5 second document classification latency (Story 12.10)
- NFR64: vLLM serves qwen2.5:14b with 35-40 tokens/second (Story 12.10)

**Implementation Notes:**
- Intel NUC + RTX 3060 eGPU (12GB VRAM) on 192.168.0.25
- **Solution A Networking:** Tailscale mesh on ALL K3s nodes (master, workers, GPU worker)
- K3s config: `--flannel-iface tailscale0 --node-external-ip <tailscale-ip>`
- Cross-subnet: 192.168.0.x (Intel NUC) ↔ 192.168.2.x (K3s cluster) via Tailscale
- 3 models (4-bit quantized): DeepSeek-Coder 6.7B, Mistral 7B, Llama 3.1 8B
- VRAM allocation: ~10-11GB models, ~1-2GB KV cache
- Context window: 8K-16K tokens per request
- NVIDIA GPU Operator for automatic driver management
- Fallback routing: vLLM (GPU) → Ollama (CPU) when GPU worker unavailable
- Paperless-AI connector for document auto-classification via Ollama
- Dual-use GPU: Shared between K8s ML workloads and host Steam gaming

---

### Epic 13: Steam Gaming Platform (Dual-Use GPU) [Phase 3]

**User Outcome:** Tom can use the Intel NUC + RTX 3060 for both Steam gaming (Windows games via Proton) AND ML inference (Ollama with Qwen 2.5 14B), switching between modes with a simple script that gracefully scales down K8s workloads when gaming and restores them afterward.

**FRs covered:** FR95-99, FR119
- FR95: Intel NUC runs Steam on host Ubuntu OS (not containerized)
- FR96: Steam uses Proton for Windows game compatibility
- FR97: Operator can switch between Gaming Mode and ML Mode via script
- FR98: Gaming Mode scales Ollama pods to 0 and enables CPU fallback
- FR99: ML Mode restores GPU Ollama pods when Steam/gaming exits
- FR119: k3s-gpu-worker boots into ML Mode by default via systemd service

**NFRs covered:** NFR51-54, NFR70
- NFR51: Gaming Mode activation completes within 30 seconds (pod scale-down + VRAM release)
- NFR52: ML Mode restoration completes within 2 minutes (pod scale-up + model load)
- NFR70: ML Mode auto-activates within 5 minutes of k3s-gpu-worker boot
- NFR53: Steam games achieve 60+ FPS at 1080p with exclusive GPU access
- NFR54: Graceful degradation to Ollama CPU maintains <5 second inference latency

**Implementation Notes:**
- Steam runs on host Ubuntu OS (graphics workloads don't containerize well)
- Mode switching via `/usr/local/bin/gpu-mode gaming|ml` script
- RTX 3060 12GB VRAM cannot run gaming (6-8GB) + Ollama Qwen 2.5 14B (~8-9GB) simultaneously
- n8n workflows detect GPU unavailability and route to Ollama CPU fallback
- Gaming Mode: `kubectl scale deployment/ollama --replicas=0 -n ml`
- ML Mode: `kubectl scale deployment/ollama --replicas=1 -n ml`
- NVIDIA driver configured with `nvidia-drm.modeset=1` for PRIME support

---

### Epic 14: LiteLLM Inference Proxy [Phase 3]

**User Outcome:** Tom has a unified AI inference endpoint with automatic failover (vLLM GPU → Ollama CPU → OpenAI Paid) plus parallel access to free external providers (Groq, Gemini, Mistral) as independent model choices for any application.

**FRs covered:** FR113-118, FR142-145
- FR113: LiteLLM proxy deployed in `ml` namespace providing unified OpenAI-compatible endpoint
- FR114: LiteLLM configured with three-tier fallback: vLLM (GPU) → Ollama (CPU) → OpenAI (cloud)
- FR115: Paperless-AI configured to use LiteLLM endpoint instead of direct vLLM connection
- FR116: LiteLLM automatically routes to next fallback tier when primary backend health check fails
- FR117: OpenAI API key stored securely via Kubernetes secret for cloud fallback tier
- FR118: LiteLLM exposes Prometheus metrics for inference routing and fallback events
- FR142: LiteLLM configured with Groq free tier as parallel model option (not fallback)
- FR143: LiteLLM configured with Google AI Studio (Gemini) free tier as parallel model option
- FR144: LiteLLM configured with Mistral API free tier as parallel model option
- FR145: API keys for external providers stored securely via Kubernetes secrets

**NFRs covered:** NFR65-69, NFR83-84
- NFR65: LiteLLM failover detection completes within 5 seconds of backend unavailability
- NFR66: LiteLLM adds <100ms latency to inference requests during normal operation
- NFR67: Paperless-AI document processing continues (degraded) during Gaming Mode via fallback chain
- NFR68: OpenAI fallback tier only activated when both vLLM and Ollama are unavailable
- NFR69: LiteLLM health endpoint responds within 1 second for readiness probes
- NFR83: External provider requests route within 5 seconds
- NFR84: Rate limiting configured to stay within free tier quotas per provider

**Implementation Notes:**
- LiteLLM provides OpenAI-compatible API that routes to multiple backends
- Fallback chain (unchanged): vLLM (GPU) → Ollama (CPU) → OpenAI (paid)
- Parallel models (new): Groq, Gemini, Mistral available as independent model choices
- Applications can explicitly request external models (e.g., `groq/llama-3.1-70b`, `gemini/gemini-pro`)
- Health checks on fallback chain backends determine automatic routing
- Prometheus metrics track model usage across all providers

---

### Epic 15: Network Access Enhancement (Tailscale Subnet Router) [Phase 4]

**User Outcome:** Tom can access the full home network (192.168.0.0/24 and 192.168.2.0/24) from anywhere via Tailscale subnet routing, without needing Tailscale installed on every device.

**FRs covered:** FR120-122
- FR120: k3s-master configured as Tailscale subnet router advertising 192.168.2.0/24 to Tailscale network
- FR121: k3s-gpu-worker configured as Tailscale subnet router advertising 192.168.0.0/24 to Tailscale network
- FR122: Tailscale ACLs configured to allow subnet route access for authorized users

**NFRs covered:** NFR71-72
- NFR71: Subnet routes advertised within 60 seconds of node boot
- NFR72: Subnet router failover: if one router goes down, network segment remains accessible via direct Tailscale connection

**Implementation Notes:**
- Both k3s-master and k3s-gpu-worker already run Tailscale for cluster networking
- Enable `--advertise-routes` flag on existing Tailscale installations
- Configure Tailscale ACLs via admin console to approve subnet routes
- Provides access to NAS, printers, and other LAN devices from anywhere

---

### Epic 16: NAS Worker Node (Synology DS920+) [Phase 4]

**User Outcome:** Tom has a lightweight K3s worker node running on the Synology NAS for storage-adjacent workloads, maximizing NAS utilization without impacting primary storage functions.

**FRs covered:** FR123-125
- FR123: K3s worker VM deployed on Synology DS920+ using Virtual Machine Manager
- FR124: NAS worker node labeled for lightweight/storage-adjacent workloads only
- FR125: NAS worker node tainted to prevent general workload scheduling

**NFRs covered:** NFR73-74
- NFR73: NAS worker VM allocated maximum 2 vCPU, 4GB RAM to preserve NAS primary functions
- NFR74: NAS worker node joins cluster within 3 minutes of VM boot

**Implementation Notes:**
- Synology DS920+ has 4 cores and 19GB RAM available
- VM uses conservative resources (2 vCPU, 4GB RAM) to avoid impacting NAS performance
- Node taint prevents general workloads; only tolerating pods scheduled here
- Ideal for backup jobs, storage monitoring, or NFS-adjacent processing

---

### Epic 17: ChatGPT-like Interface (Open-WebUI) [Phase 4]

**User Outcome:** Tom has a polished ChatGPT-like web interface for interacting with all LLM models (local vLLM, Ollama, and external providers) through a unified chat experience with persistent history.

**FRs covered:** FR126-129
- FR126: Open-WebUI deployed in `apps` namespace with persistent storage for chat history
- FR127: Open-WebUI configured to use LiteLLM as backend for unified model access
- FR128: Open-WebUI accessible via ingress at `chat.home.jetzinger.com` with HTTPS
- FR129: Open-WebUI supports switching between local models (vLLM, Ollama) and external providers (Groq, Google, Mistral)

**NFRs covered:** NFR75-76
- NFR75: Open-WebUI web interface loads within 3 seconds
- NFR76: Chat history persisted to NFS storage surviving pod restarts

**Implementation Notes:**
- Open-WebUI provides ChatGPT-like experience for self-hosted models
- Connects to LiteLLM unified endpoint (Epic 14) for model routing
- Supports multiple conversations, model switching, and chat export
- Persistent storage ensures chat history survives restarts

---

### Epic 18: Cluster Visualization Dashboard [Phase 4]

**User Outcome:** Tom can visualize cluster resources, pod status, and Kubernetes objects through a web-based dashboard, complementing Grafana metrics with real-time cluster state.

**FRs covered:** FR130-133
- FR130: Kubernetes Dashboard deployed in `infra` namespace
- FR131: Dashboard accessible via ingress at `dashboard.home.jetzinger.com` with HTTPS
- FR132: Dashboard authentication via bearer token or Tailscale identity
- FR133: Dashboard provides read-only view of all namespaces, pods, and resources

**NFRs covered:** NFR77-78
- NFR77: Dashboard loads cluster overview within 5 seconds
- NFR78: Dashboard access restricted to Tailscale network only

**Implementation Notes:**
- Official Kubernetes Dashboard provides cluster visualization
- Read-only access sufficient for monitoring and troubleshooting
- Bearer token auth or skip login for Tailscale-only access
- Complements Grafana (metrics) with live resource state

---

### Epic 19: Self-Hosted Git Service (Gitea) [Phase 4]

**User Outcome:** Tom can host private Git repositories locally with a lightweight, self-hosted Git service that provides GitHub-like features without external dependencies.

**FRs covered:** FR134-137
- FR134: Gitea deployed in `dev` namespace with PostgreSQL backend
- FR135: Gitea accessible via ingress at `git.home.jetzinger.com` with HTTPS
- FR136: Gitea persists repositories and data to NFS storage
- FR137: Gitea configured for single-user operation with SSH key authentication

**NFRs covered:** NFR79-80
- NFR79: Gitea repository operations (clone, push, pull) complete within 10 seconds for typical repos
- NFR80: Gitea web interface loads within 3 seconds

**Implementation Notes:**
- Gitea is lightweight alternative to GitLab (lower resource requirements)
- Uses existing PostgreSQL (Epic 5) for metadata storage
- SSH access via NodePort or Tailscale for git+ssh operations
- Single-user mode simplifies configuration

---

### Epic 20: Reasoning Model Support (DeepSeek-R1 14B) [Phase 4]

**User Outcome:** Tom can use reasoning-focused AI models for complex tasks via a third GPU mode (R1-Mode), enabling chain-of-thought reasoning alongside standard ML inference and gaming.

**FRs covered:** FR138-141
- FR138: DeepSeek-R1 14B model deployed via vLLM on GPU worker for reasoning tasks
- FR139: R1-Mode added as third GPU mode alongside ML-Mode and Gaming-Mode
- FR140: Mode switching script updated to support R1-Mode (scales vLLM to DeepSeek-R1 model)
- FR141: LiteLLM configured with DeepSeek-R1 as reasoning-tier model

**NFRs covered:** NFR81-82
- NFR81: R1-Mode model loading completes within 90 seconds
- NFR82: DeepSeek-R1 achieves 30+ tokens/second on RTX 3060 for reasoning tasks

**Implementation Notes:**
- DeepSeek-R1 14B fits in 12GB VRAM (RTX 3060)
- Extended gpu-mode script: ML-Mode (Qwen 2.5) → R1-Mode (DeepSeek-R1) → Gaming-Mode
- LiteLLM can route reasoning requests to DeepSeek-R1 when in R1-Mode
- Model swap requires vLLM restart (different model weights)

### Epic 21: OpenClaw Core Gateway & Telegram Channel [Phase 5]

> **⚠️ REIMPLEMENTATION NOTE (2026-01-30):** This epic was previously marked as DONE but experienced persistent configuration corruption and crash loops. All Kubernetes resources, NFS data, and application manifests have been completely cleaned up. This epic has been reset to BACKLOG status for complete reimplementation from scratch with lessons learned from the first implementation.

**User Outcome:** Tom has a personal AI assistant running on his K3s cluster, accessible via Telegram, powered by Claude Opus 4.5 with automatic LiteLLM fallback, secured with allowlist-only DM pairing.

**FRs covered:** FR149-159, FR162-163
- FR149: Deploy OpenClaw Gateway as Docker container on K3s in `apps` namespace
- FR150: Gateway control UI accessible via `openclaw.home.jetzinger.com`
- FR151: Configure OpenClaw via `openclaw.json` persisted on local persistent storage
- FR152: Preserve all config and workspace data across pod restarts via local persistent volume
- FR152a: System schedules OpenClaw pod to k3s-worker-01 (highest resource CPU worker) using node affinity
- FR152b: Velero cluster backups include OpenClaw local PVC for disaster recovery
- FR153: View gateway status and health via control UI
- FR154: Restart gateway via control UI
- FR155: Route conversations to Claude Opus 4.5 via Anthropic OAuth
- FR156: Automatic fallback to LiteLLM proxy when Anthropic unavailable
- FR157: Identify which LLM provider is handling a conversation
- FR158: Manage Anthropic OAuth credentials via gateway control UI
- FR159: Send and receive messages via Telegram DM
- FR162: Enforce allowlist-only DM pairing across all channels
- FR163: Approve/reject pairing requests via gateway CLI

**NFRs covered:** NFR86-88, NFR91-96, NFR99-102
- NFR86: Gateway message processing <10s (excluding LLM inference)
- NFR87: Gateway control UI loads <3s
- NFR88: LiteLLM fallback activates <5s
- NFR91: All credentials stored as K8s Secrets
- NFR92: Allowlist-only DM pairing
- NFR93: Control UI accessible only via Tailscale
- NFR94: OAuth tokens auto-refreshed
- NFR95: No secrets in Loki logs
- NFR96: Anthropic OAuth auto-reconnect <30s
- NFR99: LiteLLM reachable via K8s DNS from apps namespace
- NFR100: Pod restarts cleanly with config from local storage on k3s-worker-01
- NFR101: Individual channel disconnections don't affect others
- NFR102: Crash loop alerts within 2 minutes

**Implementation Notes:**
- Official openclaw/openclaw Docker image (Node.js >= 22)
- Local PVC (10Gi, local-path storage class) on k3s-worker-01: `~/.clawdbot` (config) + `~/clawd/` (workspace)
- Node affinity pins pod to k3s-worker-01 (highest resource CPU worker)
- Backed up via Velero cluster backups
- Traefik IngressRoute for HTTPS
- Inverse fallback: cloud primary (Opus 4.5) -> local fallback (LiteLLM)
- Telegram uses outbound long-polling (no inbound exposure needed)
- Depends on Epic 14 (LiteLLM) for fallback routing

### Epic 22: OpenClaw Research Tools & Multi-Channel [Phase 5]

> **⚠️ STATUS UPDATE (2026-01-30):** This epic depends on Epic 21. Due to Epic 21 complete cleanup and reimplementation, this epic has been moved back to BACKLOG status. Implementation will resume after Epic 21 is stable and complete.

**User Outcome:** Tom can research topics through his AI assistant using web research tools, and interact from WhatsApp, Discord, or Telegram with conversation continuity across channels.

**FRs covered:** FR160-161, FR164-168
- FR160: Send and receive messages via WhatsApp DM (Baileys)
- FR161: Send and receive messages via Discord DM (discord.js)
- FR164: Continue conversation context across different messaging channels
- FR165: Web research via Exa MCP tools with sourced answers
- FR166: Install and configure additional MCP research servers via mcporter
- FR167: Invoke any configured MCP tool through natural language conversation
- FR168: Structured, sourced responses from research tools

**NFRs covered:** NFR89, NFR97-98
- NFR89: mcporter MCP tool invocations return results <30s
- NFR97: Channel auto-reconnect <60s (Telegram/WhatsApp/Discord)
- NFR98: mcporter graceful timeout recovery (no gateway crash)

**Implementation Notes:**
- WhatsApp via Baileys (WebSocket, long-polling — no inbound exposure)
- Discord via discord.js (WebSocket — no inbound exposure)
- WhatsApp Baileys auth state persisted on local PVC to survive pod restarts
- mcporter + Exa installed to local workspace for persistence
- Depends on Epic 21 (gateway must exist)

### Epic 23: OpenClaw Advanced Capabilities [Phase 5]

**User Outcome:** Tom's AI assistant can speak via voice, delegate to specialized sub-agents, automate browser tasks, present rich content, and install skills from a marketplace — making it a fully capable personal tool.

**FRs covered:** FR169-180
- FR169: Voice input/output via ElevenLabs TTS/STT
- FR170: Switch between text and voice modes within a conversation
- FR171: Configure specialized sub-agents with distinct capabilities
- FR172: Invoke specific sub-agents from main conversation
- FR173: Route tasks to appropriate sub-agents based on context
- FR174: Trigger browser automation tasks through conversation
- FR175: Navigate web pages, fill forms, extract information via browser tool
- FR176: Present rich content via Canvas/A2UI
- FR177: Install skills from ClawdHub marketplace
- FR178: Update and sync installed skills via ClawdHub
- FR179: Invoke installed skills via slash commands or natural conversation
- FR180: Enable, disable, and configure individual skills via openclaw.json

**NFRs covered:** NFR90
- NFR90: ElevenLabs voice streaming begins <5s

**Implementation Notes:**
- ElevenLabs TTS/STT via API (streaming responses)
- Native OpenClaw sub-agent routing
- Built-in browser automation tool
- ClawdHub skills installed to local workspace
- Depends on Epic 21 (gateway must exist)
- Independent of Epic 22 (can be implemented in parallel)

### Epic 24: OpenClaw Observability & Portfolio Documentation [Phase 5]

**User Outcome:** Tom can monitor OpenClaw health via Grafana dashboards, receive alerts when the assistant is unhealthy, and showcase the architecture in his portfolio for interviews.

**FRs covered:** FR181-188
- FR181: Collect gateway logs into Loki for analysis
- FR182: Grafana dashboard with log-derived metrics (LogQL)
- FR183: Dashboard shows message volume, LLM provider usage, MCP tool invocations, error rates
- FR184: Prometheus Blackbox Exporter probes gateway control UI
- FR185: Alertmanager rules: gateway down (P1), high error rate (P2), OAuth expiry (P2)
- FR186: Health snapshot via `openclaw health --json`
- FR187: ADR documenting OpenClaw architectural decisions
- FR188: README OpenClaw section with architecture overview

**NFRs covered:** NFR103-104
- NFR103: Loki retains OpenClaw logs 7 days
- NFR104: Blackbox probe 30s interval, alert after 3 failures

**Implementation Notes:**
- Log-based observability pattern (new for cluster — Loki + Blackbox instead of Prometheus scrape)
- Promtail collects gateway stdout/stderr -> Loki
- Grafana dashboard with LogQL queries
- Blackbox Exporter HTTP probe on openclaw.home.jetzinger.com
- Depends on Epic 21 (gateway must exist)
- Independent of Epics 22-23

---

### Epic 26: Ollama Pro Cloud Model Integration [Phase 6]

**User Outcome:** Tom has frontier cloud AI models (kimi-k2.5 256K context, minimax-m2.5 205K multilingual, qwen3-coder:480b-cloud) available through LiteLLM as a primary inference tier with automatic local fallback, with openclaw fully migrated off Anthropic to cloud-kimi as primary, and all relevant services updated to use cloud-minimax as default for document/chat workloads.

**FRs covered:** FR215-FR223
- FR215: OLLAMA_API_KEY added to `litellm-secrets` via `kubectl patch`
- FR216: LiteLLM model_list updated with `cloud-kimi`, `cloud-minimax`, `cloud-qwen3-coder` entries via `ollama_chat` provider → `https://ollama.com/api`
- FR217: LiteLLM fallbacks updated — each cloud model cascades to `vllm-qwen` → `ollama-qwen`
- FR218: `openai-gpt4o` removed from auto-fallback chain (explicit-only parallel selection)
- FR219: `paperless-gpt` updated to `LLM_MODEL: cloud-minimax`
- FR220: `open-webui` updated to `DEFAULT_MODELS: cloud-minimax`; all cloud models auto-exposed in picker
- FR221: n8n configured with LiteLLM OpenAI-compatible credential via UI
- FR222: openclaw primary migrated to `cloud-kimi`; Anthropic OAuth fully removed (legal constraint)
- FR223: openclaw coder sub-agents migrated to `cloud-qwen3-coder`

**NFRs covered:** NFR121-NFR125
- NFR121: Cloud API requests complete within 60 seconds
- NFR122: OLLAMA_API_KEY stored as K8s secret, applied only via `kubectl patch`
- NFR123: Cloud → local failover within 5 seconds
- NFR124: All cloud models auto-visible in Open-WebUI model picker
- NFR125: openclaw local LiteLLM fallback remains functional post-migration

**Implementation Notes:**
- Cloud API base: `https://ollama.com/api` (CRITICAL: `/api` suffix required)
- Provider: `ollama_chat` (not `ollama`)
- Model tags: `{model}:XXb-cloud` suffix mandatory — exact tags confirmed via Ollama Pro dashboard at implementation time
- Anthropic fully removed from openclaw (legal constraint) — zero Anthropic fallback by design
- openclaw primary: `cloud-kimi` (image input for browser automation; cloud-minimax has no image input)
- Depends on Epic 14 (LiteLLM), Epic 21 (openclaw), Epic 17 (Open-WebUI), Epic 25 (Paperless-GPT)

---

### Story 14.1: Deploy LiteLLM Proxy with vLLM Backend

As a **cluster operator**,
I want **to deploy LiteLLM proxy with vLLM as the primary backend**,
So that **I have a unified OpenAI-compatible endpoint for all AI inference requests**.

**Story Points:** 3

**Acceptance Criteria:**

**Given** the `ml` namespace exists with vLLM deployment running
**When** I deploy LiteLLM via Helm chart or Kubernetes manifests
**Then** LiteLLM pod starts successfully in the `ml` namespace
**And** LiteLLM exposes an OpenAI-compatible API endpoint

**Given** LiteLLM is deployed
**When** I configure it to use vLLM as the primary model backend
**Then** LiteLLM correctly proxies requests to vLLM
**And** responses are returned in OpenAI API format

**Given** LiteLLM is routing to vLLM
**When** I send a chat completion request to the LiteLLM endpoint
**Then** the response matches the model output from vLLM
**And** latency overhead is <100ms (NFR66)

**Tasks:**
- [ ] Research LiteLLM deployment options (Docker image, Helm chart)
- [ ] Create Kubernetes deployment manifest for LiteLLM
- [ ] Configure LiteLLM with vLLM backend URL (http://vllm.ml.svc.cluster.local:8000)
- [ ] Create Service and IngressRoute for LiteLLM
- [ ] Test basic inference request through LiteLLM

---

### Story 14.2: Configure Three-Tier Fallback Chain

As a **cluster operator**,
I want **LiteLLM to automatically fall back to Ollama CPU, then OpenAI cloud when vLLM is unavailable**,
So that **AI inference continues even during Gaming Mode or GPU worker outages**.

**Story Points:** 5

**Acceptance Criteria:**

**Given** LiteLLM is deployed with vLLM backend
**When** I add Ollama as a secondary backend in LiteLLM configuration
**Then** LiteLLM routes to Ollama when vLLM health check fails
**And** failover completes within 5 seconds (NFR65)

**Given** LiteLLM has vLLM and Ollama backends configured
**When** I add OpenAI as a tertiary backend
**Then** OpenAI API key is stored as Kubernetes secret (FR117)
**And** OpenAI is only used when both vLLM and Ollama are unavailable (NFR68)

**Given** three-tier fallback is configured
**When** I scale vLLM to 0 replicas (Gaming Mode)
**Then** LiteLLM automatically routes requests to Ollama CPU
**And** document processing continues (degraded) via fallback chain (NFR67)

**Given** vLLM and Ollama are both unavailable
**When** I send an inference request
**Then** LiteLLM routes to OpenAI cloud as last resort
**And** response is returned with higher latency but correct format

**Tasks:**
- [ ] Configure LiteLLM model routing with fallback chain
- [ ] Add Ollama backend configuration (http://ollama.ml.svc.cluster.local:11434)
- [ ] Create Kubernetes secret for OpenAI API key
- [ ] Configure OpenAI as tertiary fallback backend
- [ ] Test failover by scaling vLLM to 0
- [ ] Test complete fallback chain (both vLLM and Ollama down)
- [ ] Verify failover detection time (<5 seconds)

---

### Story 14.3: Integrate Paperless-AI with LiteLLM

As a **document management user**,
I want **Paperless-AI to use the LiteLLM unified endpoint**,
So that **document classification continues working regardless of which backend is available**.

**Story Points:** 3

**Acceptance Criteria:**

**Given** LiteLLM is deployed with three-tier fallback
**When** I update Paperless-AI configuration to use LiteLLM endpoint
**Then** `AI_PROVIDER=custom` points to LiteLLM service URL (FR115)
**And** document classification requests route through LiteLLM

**Given** Paperless-AI is configured with LiteLLM
**When** I upload a document for processing
**Then** the document is classified using the available backend tier
**And** classification results are stored correctly

**Given** vLLM is unavailable (Gaming Mode)
**When** Paperless-AI processes a document
**Then** the request falls back to Ollama CPU via LiteLLM
**And** processing completes (potentially slower)

**Tasks:**
- [ ] Update Paperless-AI deployment with LiteLLM endpoint URL
- [ ] Configure AI_PROVIDER and API endpoint settings
- [ ] Test document classification through LiteLLM → vLLM path
- [ ] Test document classification during Gaming Mode (LiteLLM → Ollama)
- [ ] Verify classification accuracy is maintained across backends

---

### Story 14.4: Configure Prometheus Metrics and Monitoring

As a **cluster operator**,
I want **LiteLLM to expose Prometheus metrics for inference routing**,
So that **I can monitor which backend tier is serving requests and track fallback events**.

**Story Points:** 2

**Acceptance Criteria:**

**Given** LiteLLM is deployed
**When** I enable Prometheus metrics export
**Then** LiteLLM exposes metrics endpoint on /metrics (FR118)
**And** ServiceMonitor scrapes LiteLLM metrics

**Given** LiteLLM metrics are being scraped
**When** I view Grafana dashboards
**Then** I can see which backend tier is serving requests
**And** fallback events are visible in metrics

**Given** LiteLLM health endpoint is configured
**When** Kubernetes performs readiness probe
**Then** health check responds within 1 second (NFR69)
**And** pod is marked ready when backends are available

**Tasks:**
- [ ] Enable Prometheus metrics in LiteLLM configuration
- [ ] Create ServiceMonitor for LiteLLM
- [ ] Configure readiness/liveness probes
- [ ] Add LiteLLM panel to existing Grafana ML dashboard
- [ ] Test metrics export and dashboard visibility

---

### Story 14.5: Validate Failover and Performance

As a **cluster operator**,
I want **to validate the complete LiteLLM failover chain meets NFR requirements**,
So that **I have confidence the system handles backend failures gracefully**.

**Story Points:** 3

**Acceptance Criteria:**

**Given** LiteLLM is fully configured with three-tier fallback
**When** I run performance tests during normal operation
**Then** LiteLLM adds <100ms latency overhead (NFR66)
**And** vLLM serves requests with GPU-accelerated speed

**Given** I switch to Gaming Mode (`gpu-mode gaming`)
**When** vLLM pods scale to 0
**Then** LiteLLM detects unavailability within 5 seconds (NFR65)
**And** requests automatically route to Ollama CPU

**Given** Ollama CPU is serving requests
**When** I process documents via Paperless-AI
**Then** processing completes (degraded performance expected)
**And** classification accuracy is maintained (NFR67)

**Given** both vLLM and Ollama are unavailable
**When** I send inference request
**Then** LiteLLM routes to OpenAI cloud (NFR68)
**And** request completes with cloud latency

**Tasks:**
- [ ] Measure baseline latency with vLLM (GPU)
- [ ] Measure LiteLLM proxy overhead (<100ms)
- [ ] Test failover timing (vLLM → Ollama) <5 seconds
- [ ] Test complete fallback chain to OpenAI
- [ ] Document performance characteristics per tier
- [ ] Update steam-setup.md with LiteLLM fallback behavior

---

### Story 14.6: Configure External Provider Parallel Models

As a **cluster operator**,
I want **to configure Groq, Google AI Studio, and Mistral as parallel model options in LiteLLM**,
So that **any application can explicitly select these free-tier models without affecting the existing fallback chain**.

**Story Points:** 3

**Acceptance Criteria:**

**Given** LiteLLM is deployed with the existing fallback chain
**When** I add Groq model definitions to the LiteLLM config
**Then** `groq/llama-3.3-70b-versatile` is available as a model choice
**And** `groq/mixtral-8x7b-32768` is available as a model choice
**And** these models do NOT participate in the fallback chain

**Given** Groq models are configured
**When** I add Google AI Studio model definitions
**Then** `gemini/gemini-1.5-flash` is available as a model choice
**And** `gemini/gemini-1.5-pro` is available as a model choice

**Given** Google AI models are configured
**When** I add Mistral model definitions
**Then** `mistral/mistral-small-latest` is available as a model choice

**Given** all external provider models are configured
**When** I create a Kubernetes secret with API keys (FR145)
**Then** secret contains GROQ_API_KEY, GOOGLE_AI_API_KEY, MISTRAL_API_KEY
**And** LiteLLM deployment references the secret via environment variables

**Given** external providers are fully configured
**When** I request `groq/llama-3.3-70b-versatile` via LiteLLM API
**Then** request routes directly to Groq (NFR83: within 5 seconds)
**And** response returns successfully

**Given** rate limiting is configured
**When** requests approach free tier limits
**Then** LiteLLM enforces rate limits per provider (NFR84)
**And** requests are throttled rather than failing

**Tasks:**
- [ ] Add Groq model definitions to LiteLLM config (FR142)
- [ ] Add Google AI Studio model definitions to LiteLLM config (FR143)
- [ ] Add Mistral model definitions to LiteLLM config (FR144)
- [ ] Create litellm-api-keys secret with all provider keys (FR145)
- [ ] Update LiteLLM deployment to mount secret as env vars
- [ ] Configure rate limiting per provider (NFR84)
- [ ] Test each external model via curl/API call
- [ ] Verify fallback chain still works independently
- [ ] Document available models in README

---

## Epic 1: Foundation - K3s Cluster with Remote Access

Tom has a working multi-node K3s cluster he can access from anywhere via Tailscale.

---

### Story 1.1: Create K3s Control Plane

As a **cluster operator**,
I want **to deploy a K3s control plane on a dedicated VM**,
So that **I have a working Kubernetes cluster foundation**.

**Acceptance Criteria:**

**Given** Proxmox host is running with available resources
**When** I create a VM with 2 vCPU, 4GB RAM, 32GB disk at 192.168.2.20
**Then** the VM boots successfully with Ubuntu Server
**And** SSH access is available

**Given** the control plane VM is running
**When** I run the K3s installation script with `--write-kubeconfig-mode 644`
**Then** K3s server starts successfully
**And** `kubectl get nodes` shows the master node as Ready
**And** the node token is available at `/var/lib/rancher/k3s/server/node-token`

**Given** the K3s control plane is running
**When** I check cluster health with `kubectl get componentstatuses`
**Then** all components report Healthy status

---

### Story 1.2: Add First Worker Node

As a **cluster operator**,
I want **to add a worker node to the cluster**,
So that **workloads can be scheduled on dedicated compute resources**.

**Acceptance Criteria:**

**Given** K3s control plane is running and accessible
**When** I create a VM with 4 vCPU, 8GB RAM, 50GB disk at 192.168.2.21
**Then** the VM boots successfully with Ubuntu Server
**And** SSH access is available

**Given** the worker VM is running and can reach the control plane
**When** I run the K3s agent installation with the server URL and node token
**Then** the agent joins the cluster successfully
**And** `kubectl get nodes` shows k3s-worker-01 as Ready

**Given** both nodes are Ready
**When** I deploy a test pod without node selector
**Then** the pod schedules to the worker node (not master)
**And** the pod reaches Running state

---

### Story 1.3: Add Second Worker Node

As a **cluster operator**,
I want **to add a second worker node to the cluster**,
So that **I have redundancy and can test multi-node scheduling**.

**Acceptance Criteria:**

**Given** K3s cluster has master and one worker running
**When** I create a VM with 4 vCPU, 8GB RAM, 50GB disk at 192.168.2.22
**Then** the VM boots successfully with Ubuntu Server
**And** SSH access is available

**Given** the second worker VM is running
**When** I run the K3s agent installation with the server URL and node token
**Then** the agent joins the cluster successfully
**And** `kubectl get nodes` shows 3 nodes all in Ready state

**Given** three nodes are Ready
**When** I deploy a Deployment with 3 replicas
**Then** pods are distributed across worker nodes
**And** no pods schedule to the master node (unless toleration set)

---

### Story 1.4: Configure Remote kubectl Access

As a **cluster operator**,
I want **to run kubectl commands from any Tailscale-connected device**,
So that **I can manage the cluster remotely without SSH**.

**Acceptance Criteria:**

**Given** K3s cluster is running with all nodes Ready
**When** I copy `/etc/rancher/k3s/k3s.yaml` to my local `~/.kube/config`
**Then** the kubeconfig file contains valid cluster credentials

**Given** the kubeconfig references `127.0.0.1:6443`
**When** I update the server URL to `https://192.168.2.20:6443`
**Then** kubectl can connect to the cluster from the local network

**Given** Tailscale is configured with subnet routing to 192.168.2.0/24
**When** I run `kubectl get nodes` from a Tailscale-connected laptop outside the home network
**Then** the command succeeds and shows all 3 nodes
**And** response time is under 2 seconds

**Given** remote kubectl access is working
**When** I attempt kubectl without valid kubeconfig
**Then** access is denied (NFR12: no anonymous access)

---

### Story 1.5: Document Node Removal Procedure

As a **cluster operator**,
I want **to safely remove a worker node without data loss**,
So that **I can perform maintenance or replace failed nodes**.

**Acceptance Criteria:**

**Given** cluster has 3 nodes with pods running on all workers
**When** I run `kubectl drain k3s-worker-02 --ignore-daemonsets --delete-emptydir-data`
**Then** all non-DaemonSet pods are evicted from the node
**And** pods reschedule to k3s-worker-01

**Given** node is drained
**When** I run `kubectl delete node k3s-worker-02`
**Then** the node is removed from cluster
**And** `kubectl get nodes` shows only 2 nodes

**Given** node removal is complete
**When** I check application health
**Then** all applications remain accessible
**And** no data loss has occurred (NFR3)

**Given** the procedure is validated
**When** I document it in `docs/runbooks/node-removal.md`
**Then** the runbook includes drain, delete, and rejoin steps
**And** recovery procedure is documented

---

## Epic 2: Storage & Persistence

Tom can provision persistent NFS storage for any application needing data persistence.

---

### Story 2.1: Deploy NFS Storage Provisioner

As a **cluster operator**,
I want **to deploy an NFS provisioner that creates PersistentVolumes automatically**,
So that **applications can request storage without manual PV creation**.

**Acceptance Criteria:**

**Given** Synology NFS share is configured at 192.168.2.2:/volume1/k8s-data
**When** I verify NFS connectivity from a worker node with `showmount -e 192.168.2.2`
**Then** the k8s-data export is visible
**And** worker nodes are in the allowed hosts list

**Given** NFS is accessible from all cluster nodes
**When** I deploy nfs-subdir-external-provisioner via Helm with `values-homelab.yaml`
**Then** the provisioner pod starts in the `infra` namespace
**And** pod status shows Running

**Given** the provisioner is running
**When** I check for StorageClass with `kubectl get storageclass`
**Then** `nfs-client` StorageClass exists
**And** it is marked as the default StorageClass

**Given** the StorageClass is configured
**When** I inspect StorageClass details
**Then** reclaim policy is set to Delete
**And** provisioner is set to `cluster.local/nfs-subdir-external-provisioner`

---

### Story 2.2: Create and Test PersistentVolumeClaim

As a **cluster operator**,
I want **to create PersistentVolumeClaims that automatically provision storage**,
So that **applications can persist data without manual intervention**.

**Acceptance Criteria:**

**Given** NFS provisioner is running with default StorageClass
**When** I create a PVC requesting 1Gi of storage
**Then** the PVC status transitions to Bound within 30 seconds
**And** a corresponding PV is automatically created

**Given** the PVC is Bound
**When** I create a test pod that mounts the PVC
**Then** the pod starts successfully
**And** the volume mounts within 10 seconds (NFR16)

**Given** the test pod is running with mounted volume
**When** I write a file to the mounted path
**Then** the file persists on the Synology NFS share
**And** the file path follows pattern `{namespace}-{pvc-name}-{pv-id}/`

**Given** data is written to the volume
**When** I delete and recreate the pod (same PVC)
**Then** the previously written data is still accessible
**And** no data loss occurs

---

### Story 2.3: Verify Storage Mount Health

As a **cluster operator**,
I want **to verify NFS mount health across the cluster**,
So that **I can detect storage issues before they affect applications**.

**Acceptance Criteria:**

**Given** NFS provisioner and test PVC are deployed
**When** I run `kubectl get pv` and `kubectl get pvc --all-namespaces`
**Then** all PVs show Available or Bound status
**And** all PVCs show Bound status

**Given** pods are using NFS-backed volumes
**When** I exec into a pod and run `df -h` on the mount point
**Then** the NFS mount is visible with correct capacity
**And** used/available space is reported accurately

**Given** NFS storage is operational
**When** Synology performs a firmware update (simulated by brief NFS restart)
**Then** existing mounts recover automatically
**And** pods do not crash (NFR4)

**Given** I need ongoing health visibility
**When** I create a storage health check script at `scripts/health-check.sh`
**Then** the script validates NFS connectivity, PV/PVC status, and mount health
**And** returns exit code 0 for healthy, non-zero for issues

---

### Story 2.4: Configure Synology Snapshots for Backup

As a **cluster operator**,
I want **to configure Synology snapshots for the k8s-data volume**,
So that **I can recover from accidental data deletion or corruption**.

**Acceptance Criteria:**

**Given** Synology DS920+ is accessible via web UI
**When** I configure Snapshot Replication for /volume1/k8s-data
**Then** hourly snapshots are scheduled
**And** retention policy keeps 24 hourly + 7 daily snapshots

**Given** snapshots are configured
**When** an hourly snapshot runs
**Then** the snapshot completes successfully
**And** snapshot is visible in Synology Snapshot Replication

**Given** data exists in a PVC
**When** I accidentally delete files from the NFS mount
**Then** I can restore from a Synology snapshot via the web UI
**And** the data is recovered without affecting running pods

**Given** backup strategy is validated
**When** I document the procedure in `docs/runbooks/nfs-restore.md`
**Then** the runbook includes snapshot location, restore steps, and verification
**And** recovery time objective is documented

---

## Epic 3: Ingress, TLS & Service Exposure

Tom can expose any service with HTTPS via *.home.jetzinger.com domains.

---

### Story 3.1: Deploy MetalLB for LoadBalancer Services

As a **cluster operator**,
I want **to deploy MetalLB so Services of type LoadBalancer get external IPs**,
So that **I can expose services outside the cluster on my home network**.

**Acceptance Criteria:**

**Given** K3s cluster is running with all nodes Ready
**When** I deploy MetalLB via Helm with `values-homelab.yaml` to the `infra` namespace
**Then** the MetalLB controller and speaker pods start successfully
**And** all pods show Running status

**Given** MetalLB is running
**When** I apply an IPAddressPool for range 192.168.2.100-192.168.2.120
**Then** the pool is created successfully
**And** `kubectl get ipaddresspools -n infra` shows the pool

**Given** MetalLB and IP pool are configured
**When** I apply an L2Advertisement for the pool
**Then** MetalLB can announce IPs via ARP on the home network

**Given** MetalLB is fully configured
**When** I create a test Service of type LoadBalancer
**Then** the Service receives an external IP from the pool (e.g., 192.168.2.100)
**And** the IP is reachable from other devices on the home network

---

### Story 3.2: Configure Traefik Ingress Controller

As a **cluster operator**,
I want **to configure Traefik as my ingress controller with a dashboard**,
So that **I can route HTTP traffic to services and monitor ingress status**.

**Acceptance Criteria:**

**Given** K3s is installed (Traefik is included by default)
**When** I check for Traefik in kube-system namespace
**Then** Traefik pods are running
**And** Traefik Service exists with LoadBalancer type

**Given** MetalLB is configured
**When** I verify Traefik Service external IP
**Then** Traefik has an IP from the MetalLB pool (e.g., 192.168.2.100)
**And** port 80 and 443 are accessible from the home network

**Given** Traefik is running with external IP
**When** I enable the Traefik dashboard via IngressRoute
**Then** the dashboard is accessible at traefik.home.jetzinger.com
**And** I can view routers, services, and middlewares

**Given** Traefik dashboard is accessible
**When** I review ingress routing latency
**Then** Traefik adds less than 100ms latency to requests (NFR17)

---

### Story 3.3: Deploy cert-manager with Let's Encrypt

As a **cluster operator**,
I want **to deploy cert-manager that automatically provisions TLS certificates**,
So that **all my services can use valid HTTPS without manual certificate management**.

**Acceptance Criteria:**

**Given** cluster is running with ingress working
**When** I deploy cert-manager via Helm to the `infra` namespace
**Then** cert-manager controller, webhook, and cainjector pods are Running
**And** CRDs for Certificate, Issuer, ClusterIssuer are installed

**Given** cert-manager is running
**When** I create a ClusterIssuer for Let's Encrypt Production with HTTP-01 challenge
**Then** the ClusterIssuer shows Ready status
**And** `kubectl describe clusterissuer letsencrypt-prod` shows no errors

**Given** ClusterIssuer is ready
**When** I create a test Certificate resource for test.home.jetzinger.com
**Then** cert-manager requests a certificate from Let's Encrypt
**And** the Certificate status shows Ready within 2 minutes
**And** a Secret containing tls.crt and tls.key is created

**Given** certificates are provisioned automatically
**When** I inspect the certificate
**Then** it uses TLS 1.2 or higher (NFR7)
**And** certificate is valid and not self-signed

---

### Story 3.4: Configure DNS with NextDNS Rewrites

As a **cluster operator**,
I want **to configure NextDNS to resolve *.home.jetzinger.com to my cluster ingress**,
So that **I can access services by name from any device on my network**.

**Acceptance Criteria:**

**Given** Traefik has external IP 192.168.2.100 (or similar from MetalLB pool)
**When** I log into NextDNS dashboard
**Then** I can access the Rewrites configuration section

**Given** NextDNS Rewrites section is accessible
**When** I add a rewrite rule: `*.home.jetzinger.com` -> `192.168.2.100`
**Then** the rule is saved successfully
**And** the rule appears in the active rewrites list

**Given** DNS rewrite is configured
**When** I query `nslookup grafana.home.jetzinger.com` from a network device
**Then** the query resolves to 192.168.2.100
**And** any subdomain of home.jetzinger.com resolves to the same IP

**Given** DNS is working
**When** I access http://traefik.home.jetzinger.com from a browser
**Then** the request reaches Traefik
**And** the Traefik dashboard loads (or appropriate response)

---

### Story 3.5: Create First HTTPS Ingress Route

As a **cluster operator**,
I want **to create an HTTPS ingress route with automatic TLS**,
So that **I can verify the complete ingress pipeline works end-to-end**.

**Acceptance Criteria:**

**Given** MetalLB, Traefik, cert-manager, and DNS are all configured
**When** I deploy a simple nginx pod and Service in the `dev` namespace
**Then** the pod is Running and Service is created

**Given** the test service exists
**When** I create an IngressRoute for hello.home.jetzinger.com with TLS enabled
**Then** the IngressRoute is created with annotation for cert-manager
**And** cert-manager provisions a certificate for hello.home.jetzinger.com

**Given** the IngressRoute and certificate are ready
**When** I access https://hello.home.jetzinger.com in a browser
**Then** the page loads with valid HTTPS (green padlock)
**And** certificate shows issued by Let's Encrypt
**And** no certificate warnings appear

**Given** HTTPS is working
**When** I access http://hello.home.jetzinger.com (plain HTTP)
**Then** the request redirects to HTTPS automatically
**And** the final response is served over TLS 1.2+ (NFR7)

---

## Epic 4: Observability Stack

Tom can monitor the cluster, view dashboards, and receive P1 alerts on his phone.

---

### Story 4.1: Deploy kube-prometheus-stack

As a **cluster operator**,
I want **to deploy the complete Prometheus monitoring stack**,
So that **I have metrics collection, storage, and visualization ready**.

**Acceptance Criteria:**

**Given** cluster has NFS storage and ingress configured
**When** I create the `monitoring` namespace
**Then** the namespace is created with appropriate labels
**And** this validates FR11 (assign workloads to specific namespaces)

**Given** the monitoring namespace exists
**When** I deploy kube-prometheus-stack via Helm with `values-homelab.yaml`
**Then** the following pods start in the monitoring namespace:
- prometheus-server
- grafana
- alertmanager
- node-exporter (DaemonSet on all nodes)
- kube-state-metrics
**And** all pods reach Running status within 5 minutes

**Given** the stack is deployed
**When** I check node-exporter pods
**Then** one pod runs on each node (master, worker-01, worker-02)
**And** this validates FR26 (metrics from all nodes)

**Given** kube-state-metrics is running
**When** I query Prometheus for `kube_pod_info`
**Then** metrics for all cluster pods are available
**And** this validates FR27 (K8s object metrics)

**Given** all components are running
**When** I verify this is a containerized application deployment
**Then** this validates FR7 (deploy containerized applications)

---

### Story 4.2: Configure Grafana Dashboards and Ingress

As a **cluster operator**,
I want **to access Grafana dashboards via HTTPS**,
So that **I can visualize cluster metrics from any device**.

**Acceptance Criteria:**

**Given** kube-prometheus-stack is deployed with Grafana
**When** I create an IngressRoute for grafana.home.jetzinger.com with TLS
**Then** cert-manager provisions a certificate
**And** Grafana is accessible via HTTPS

**Given** Grafana is accessible
**When** I log in with the default admin credentials
**Then** the Grafana home page loads within 5 seconds (NFR14)
**And** I can change the admin password

**Given** I'm logged into Grafana
**When** I navigate to the Dashboards section
**Then** pre-built Kubernetes dashboards are available:
- Kubernetes / Compute Resources / Cluster
- Kubernetes / Compute Resources / Namespace
- Node Exporter / Nodes
**And** dashboards show real cluster data

**Given** dashboards are working
**When** I add Prometheus as a data source (if not auto-configured)
**Then** Prometheus data source shows "Data source is working"
**And** I can query metrics via Explore view
**And** this validates FR24 (view cluster metrics in Grafana)

---

### Story 4.3: Verify Prometheus Metrics and Queries

As a **cluster operator**,
I want **to query Prometheus for historical metrics**,
So that **I can analyze trends and troubleshoot issues**.

**Acceptance Criteria:**

**Given** Prometheus is running and scraping targets
**When** I create an IngressRoute for prometheus.home.jetzinger.com with TLS
**Then** Prometheus UI is accessible via HTTPS

**Given** Prometheus UI is accessible
**When** I navigate to Status -> Targets
**Then** all scrape targets show "UP" status:
- kubernetes-nodes
- kubernetes-pods
- node-exporter
- kube-state-metrics
**And** this validates NFR18 (all components emit Prometheus metrics)

**Given** targets are healthy
**When** I query `node_memory_MemAvailable_bytes` in the query interface
**Then** results show memory data for all 3 nodes
**And** data points span the retention period

**Given** historical data is available
**When** I query `rate(container_cpu_usage_seconds_total[5m])`
**Then** CPU usage rate data is returned
**And** I can view data from the past hour
**And** this validates FR25 (query Prometheus for historical metrics)

---

### Story 4.4: Configure Alertmanager with Alert Rules

As a **cluster operator**,
I want **to configure alert rules for critical cluster conditions**,
So that **I'm notified when issues require attention**.

**Acceptance Criteria:**

**Given** kube-prometheus-stack is deployed with Alertmanager
**When** I create an IngressRoute for alertmanager.home.jetzinger.com with TLS
**Then** Alertmanager UI is accessible via HTTPS

**Given** Alertmanager UI is accessible
**When** I view the Alerts page
**Then** I can see configured alert rules and their status

**Given** kube-prometheus-stack includes default rules
**When** I review PrometheusRule resources
**Then** rules exist for:
- P1: NodeDown, TargetDown
- P2: PodCrashLoopBackOff, HighMemoryPressure
- P3: CertificateExpirySoon, DiskSpaceWarning

**Given** alert rules are configured
**When** I add custom rules in `monitoring/prometheus/custom-rules.yaml` for:
- PostgreSQL unhealthy (P1)
- NFS unreachable (P1)
**Then** the custom PrometheusRule is applied
**And** rules appear in Prometheus UI under Alerts

**Given** alert rules are active
**When** I simulate an alert condition (e.g., scale down a deployment to cause missing target)
**Then** alert fires within 1 minute (NFR5)
**And** alert appears in Alertmanager UI
**And** this validates FR28 (system sends alerts when thresholds exceeded)

**Given** alerts are firing
**When** I view Alertmanager UI
**Then** I can see alert history, active alerts, and silenced alerts
**And** this validates FR30 (view alert history and status)

---

### Story 4.5: Setup Mobile Notifications for P1 Alerts

As a **cluster operator**,
I want **to receive mobile notifications for P1 alerts**,
So that **I'm immediately aware of critical issues even when away from my desk**.

**Acceptance Criteria:**

**Given** Alertmanager is running with alert rules
**When** I configure Alertmanager with a notification receiver (Pushover, Slack, or ntfy)
**Then** the receiver configuration is valid
**And** Alertmanager shows no configuration errors

**Given** notification receiver is configured
**When** I create a route that sends P1 (critical) alerts to the mobile receiver
**Then** the route is applied via Alertmanager ConfigMap or Secret
**And** the routing tree shows P1 alerts going to mobile

**Given** routing is configured
**When** I trigger a test P1 alert (e.g., manually fire NodeDown)
**Then** I receive a notification on my mobile device within 2 minutes
**And** the notification includes alert name, severity, and cluster context

**Given** mobile notifications are working
**When** the test alert resolves
**Then** I receive a resolution notification
**And** this validates FR29 (receive mobile notifications for P1 alerts)

**Given** notification flow is validated
**When** I document the setup in `docs/runbooks/alertmanager-setup.md`
**Then** the runbook includes receiver configuration and testing steps

---

### Story 4.6: Deploy Loki for Log Aggregation

As a **cluster operator**,
I want **to aggregate and query logs from all pods**,
So that **I can troubleshoot issues using centralized logging**.

**Acceptance Criteria:**

**Given** kube-prometheus-stack is deployed
**When** I deploy Loki via Helm with `values-homelab.yaml` to the monitoring namespace
**Then** Loki and Promtail pods start successfully
**And** Promtail runs as DaemonSet on all nodes

**Given** Loki is running
**When** I configure Loki as a data source in Grafana
**Then** the data source shows "Data source is working"
**And** LogQL queries return results

**Given** Loki is receiving logs
**When** I query `{namespace="monitoring"}` in Grafana Explore
**Then** logs from monitoring namespace pods are returned
**And** logs include timestamps, labels, and log content

**Given** log aggregation is working
**When** I configure Loki retention for 7 days
**Then** logs older than 7 days are automatically pruned
**And** this satisfies NFR19 (7-day log retention)

**Given** logging is operational
**When** I use Loki to troubleshoot a pod issue
**Then** I can filter logs by namespace, pod, container
**And** I can search for specific error messages

---

## Epic 5: PostgreSQL Database Service

Tom has a production-grade PostgreSQL database with backup and restore capability.

---

### Story 5.1: Deploy PostgreSQL via Bitnami Helm Chart

As a **cluster operator**,
I want **to deploy PostgreSQL using the Bitnami Helm chart**,
So that **I have a production-ready database with sensible defaults**.

**Acceptance Criteria:**

**Given** cluster has NFS storage provisioner and monitoring configured
**When** I create the `data` namespace
**Then** the namespace is created with appropriate labels

**Given** the data namespace exists
**When** I deploy Bitnami PostgreSQL via Helm with `values-homelab.yaml`
**Then** the PostgreSQL StatefulSet is created
**And** the postgres-0 pod starts successfully
**And** this validates FR8 (deploy applications using Helm charts)

**Given** PostgreSQL pod is running
**When** I check the pod details with `kubectl describe pod postgres-0 -n data`
**Then** the pod shows as a StatefulSet member
**And** this validates FR31 (deploy PostgreSQL as StatefulSet)

**Given** PostgreSQL is deployed
**When** I check the Service created
**Then** a ClusterIP service `postgres` exists in the data namespace
**And** port 5432 is exposed

**Given** PostgreSQL is running
**When** I connect with `kubectl exec -it postgres-0 -n data -- psql -U postgres`
**Then** the psql prompt appears
**And** I can run `\l` to list databases

---

### Story 5.2: Configure NFS Persistence for PostgreSQL

As a **cluster operator**,
I want **PostgreSQL data to persist on NFS storage**,
So that **data survives pod restarts and node failures**.

**Acceptance Criteria:**

**Given** PostgreSQL Helm chart is configured
**When** I set `primary.persistence.storageClass: nfs-client` in values-homelab.yaml
**Then** the chart requests storage from the NFS provisioner

**Given** PostgreSQL is deployed with NFS persistence
**When** I check PVCs with `kubectl get pvc -n data`
**Then** a PVC for PostgreSQL data exists and shows Bound status
**And** the PVC uses the nfs-client StorageClass

**Given** PVC is bound
**When** I check the Synology NFS share
**Then** a directory exists for the PostgreSQL PVC
**And** PostgreSQL data files are visible
**And** this validates FR32 (PostgreSQL persists data to NFS)

**Given** data is on NFS
**When** I delete the PostgreSQL pod with `kubectl delete pod postgres-0 -n data`
**Then** the StatefulSet recreates the pod
**And** the new pod mounts the same PVC
**And** all previously created databases and data are intact

**Given** persistence is validated
**When** I simulate a worker node failure (drain the node running postgres)
**Then** PostgreSQL pod reschedules to another node
**And** data remains accessible via NFS

---

### Story 5.3: Setup PostgreSQL Backup with pg_dump

As a **cluster operator**,
I want **to backup PostgreSQL databases to NFS automatically**,
So that **I can recover from data corruption or accidental deletion**.

**Acceptance Criteria:**

**Given** PostgreSQL is running with data
**When** I create a test database and table with sample data
**Then** the data is queryable via psql

**Given** test data exists
**When** I create a CronJob that runs pg_dump daily to an NFS-backed PVC
**Then** the CronJob is created in the data namespace
**And** the CronJob manifest is saved at `applications/postgres/backup-cronjob.yaml`

**Given** the backup CronJob exists
**When** I trigger a manual run with `kubectl create job --from=cronjob/postgres-backup manual-backup -n data`
**Then** the backup job runs successfully
**And** a .sql.gz file is created in the backup PVC

**Given** backup file exists
**When** I verify the backup file on Synology NFS share
**Then** the file contains valid SQL dump
**And** file size is reasonable for the data volume
**And** this validates FR33 (backup PostgreSQL to NFS)

**Given** backups are working
**When** I check backup retention
**Then** the script retains the last 7 daily backups
**And** older backups are automatically deleted

---

### Story 5.4: Validate PostgreSQL Restore Procedure

As a **cluster operator**,
I want **to restore PostgreSQL from a backup**,
So that **I can recover from disasters with documented procedures**.

**Acceptance Criteria:**

**Given** a valid pg_dump backup exists on NFS
**When** I document the restore procedure in `docs/runbooks/postgres-restore.md`
**Then** the runbook includes step-by-step restore instructions

**Given** runbook is documented
**When** I intentionally drop the test database
**Then** the database is deleted and data is lost

**Given** data loss has occurred
**When** I follow the restore runbook to restore from backup
**Then** I can copy the backup file into the postgres pod
**And** I can run `psql -U postgres < backup.sql` to restore

**Given** restore command completes
**When** I verify the restored data
**Then** the test database exists again
**And** all rows in the test table are restored
**And** this validates FR34 (restore PostgreSQL from backup)

**Given** restore is validated
**When** I measure restore time for the test database
**Then** restore time is documented in the runbook
**And** the procedure works within acceptable time bounds

---

### Story 5.5: Test Application Connectivity to PostgreSQL

As a **cluster operator**,
I want **applications to connect to PostgreSQL within the cluster**,
So that **workloads can use the database as their data store**.

**Acceptance Criteria:**

**Given** PostgreSQL is running in the data namespace
**When** I deploy a test pod in the apps namespace with psql client
**Then** the pod starts successfully

**Given** the test pod is running
**When** I exec into the pod and connect to `postgres.data.svc.cluster.local:5432`
**Then** the connection succeeds
**And** I can authenticate with PostgreSQL credentials

**Given** connectivity works
**When** I create a database and user for an application
**Then** the application-specific credentials work
**And** the application can perform CRUD operations

**Given** application connectivity is validated
**When** I document connection strings in `docs/runbooks/postgres-connectivity.md`
**Then** the runbook includes:
- Internal DNS: `postgres.data.svc.cluster.local`
- Port: 5432
- How to retrieve credentials from Secret
**And** this validates FR35 (applications can connect to PostgreSQL)

**Given** documentation is complete
**When** future applications need PostgreSQL
**Then** they can follow the documented pattern

---

## Epic 6: AI Inference Platform

Tom can run LLM inference (Ollama) and workflow automation (n8n) on the cluster.

---

### Story 6.1: Deploy Ollama for LLM Inference

As a **cluster operator**,
I want **to deploy Ollama for running LLM inference**,
So that **I can serve AI models from my home cluster**.

**Acceptance Criteria:**

**Given** cluster has NFS storage and ingress configured
**When** I create the `ml` namespace
**Then** the namespace is created with appropriate labels

**Given** the ml namespace exists
**When** I deploy Ollama via Helm with `values-homelab.yaml`
**Then** the Ollama deployment is created in the ml namespace
**And** the Ollama pod starts successfully

**Given** Ollama pod is running
**When** I configure an NFS-backed PVC for model storage
**Then** the PVC is bound to Ollama at `/root/.ollama`
**And** downloaded models persist across pod restarts

**Given** Ollama is deployed with persistent storage
**When** I create an IngressRoute for ollama.home.jetzinger.com with TLS
**Then** Ollama API is accessible via HTTPS
**And** this validates FR36 (deploy Ollama for LLM inference)

**Given** Ollama is accessible
**When** I exec into the pod and run `ollama pull llama3.2:1b`
**Then** the model downloads and is stored on NFS
**And** subsequent pod restarts don't require re-downloading

---

### Story 6.2: Test Ollama API and Model Inference

As a **cluster operator**,
I want **to query the Ollama API for completions**,
So that **applications can leverage LLM capabilities**.

**Acceptance Criteria:**

**Given** Ollama is running with a model loaded
**When** I send a POST request to `https://ollama.home.jetzinger.com/api/generate`
**Then** the API responds with a 200 status

**Given** the API is responding
**When** I send a prompt like `{"model": "llama3.2:1b", "prompt": "Hello, how are you?"}`
**Then** Ollama returns a generated response
**And** response time is under 30 seconds for typical prompts (NFR13)

**Given** API inference works
**When** I query the `/api/tags` endpoint
**Then** it returns the list of available models
**And** the model I pulled is in the list

**Given** external access works
**When** I test the API from a Tailscale-connected device outside the home network
**Then** the API is accessible and returns valid responses
**And** this validates FR37 (applications can query Ollama API)

**Given** inference is validated
**When** I create a simple test script that queries Ollama
**Then** the script can be used for health checks
**And** the script is saved at `scripts/ollama-health.sh`

---

### Story 6.3: Deploy n8n for Workflow Automation

As a **cluster operator**,
I want **to deploy n8n for workflow automation**,
So that **I can create automated workflows that leverage cluster services**.

**Acceptance Criteria:**

**Given** cluster has storage, ingress, and database configured
**When** I deploy n8n via Helm with `values-homelab.yaml` to the `apps` namespace
**Then** the n8n deployment is created
**And** the n8n pod starts successfully

**Given** n8n requires persistent storage
**When** I configure an NFS-backed PVC for n8n data
**Then** the PVC is bound and mounted
**And** workflow data persists across restarts

**Given** n8n is running
**When** I create an IngressRoute for n8n.home.jetzinger.com with TLS
**Then** n8n UI is accessible via HTTPS
**And** I can log in to the n8n interface

**Given** n8n UI is accessible
**When** I create a simple test workflow that calls the Ollama API
**Then** the workflow executes successfully
**And** Ollama response is captured in workflow output
**And** this validates FR40 (deploy n8n for workflow automation)

**Given** n8n is operational
**When** I document the setup in `docs/runbooks/n8n-setup.md`
**Then** the runbook includes deployment details and initial configuration

---

### Story 6.4: Validate Scaling and Log Access

As a **cluster operator**,
I want **to scale deployments and view pod logs**,
So that **I can manage workload capacity and troubleshoot issues**.

**Acceptance Criteria:**

**Given** Ollama is deployed as a Deployment (not StatefulSet)
**When** I run `kubectl scale deployment ollama -n ml --replicas=2`
**Then** a second Ollama pod starts
**And** both pods reach Running state
**And** this validates FR12 (scale deployments up or down)

**Given** multiple Ollama pods are running
**When** I scale back down with `kubectl scale deployment ollama -n ml --replicas=1`
**Then** one pod terminates gracefully
**And** the remaining pod continues serving requests

**Given** pods are running
**When** I run `kubectl logs ollama-xxx -n ml`
**Then** pod logs are displayed showing Ollama activity
**And** I can see model loading and inference requests

**Given** logs are accessible
**When** I run `kubectl logs ollama-xxx -n ml --follow`
**Then** logs stream in real-time
**And** new inference requests appear as they happen

**Given** events are tracked
**When** I run `kubectl get events -n ml --sort-by=.lastTimestamp`
**Then** I can see recent events for the namespace
**And** pod scheduling, scaling, and health events are visible
**And** this validates FR13 (view pod logs and events)

---

## Epic 7: Development Proxy

Tom can access local development servers through cluster ingress.

---

### Story 7.1: Deploy Nginx Reverse Proxy

As a **cluster operator**,
I want **to deploy Nginx as a reverse proxy to local development servers**,
So that **I can access my dev machines through the cluster**.

**Acceptance Criteria:**

**Given** cluster has ingress and TLS configured
**When** I create the `dev` namespace
**Then** the namespace is created with appropriate labels

**Given** the dev namespace exists
**When** I create a ConfigMap with initial proxy configuration
**Then** the ConfigMap contains nginx.conf with upstream definitions
**And** the ConfigMap is saved at `applications/nginx/configmap.yaml`

**Given** the ConfigMap exists
**When** I deploy Nginx with the ConfigMap mounted
**Then** the Nginx deployment is created in the dev namespace
**And** the Nginx pod starts successfully
**And** the deployment manifest is saved at `applications/nginx/deployment.yaml`

**Given** Nginx pod is running
**When** I check the nginx configuration inside the pod
**Then** the proxy configuration from ConfigMap is loaded
**And** this validates FR41 (configure Nginx to proxy to local dev servers)

**Given** Nginx is deployed
**When** I create a Service of type ClusterIP for Nginx
**Then** the Service exposes port 80
**And** the Service is accessible within the cluster

---

### Story 7.2: Configure Ingress for Dev Proxy Access

As a **developer**,
I want **to access my local dev servers via cluster ingress URLs**,
So that **I can test services with real HTTPS and domain names**.

**Acceptance Criteria:**

**Given** Nginx proxy is running in the dev namespace
**When** I create an IngressRoute for dev.home.jetzinger.com with TLS
**Then** cert-manager provisions a certificate
**And** the ingress is saved at `applications/nginx/ingress.yaml`

**Given** ingress is configured
**When** I configure Nginx to proxy `/app1` to a local dev server (e.g., 192.168.2.50:3000)
**Then** the upstream is defined in the ConfigMap
**And** location block routes `/app1` to the upstream

**Given** proxy route is configured
**When** I access https://dev.home.jetzinger.com/app1 from any device
**Then** the request is proxied to the local dev server
**And** the response is returned through the cluster
**And** this validates FR42 (access local dev servers via cluster ingress)

**Given** basic proxying works
**When** I add additional proxy targets (e.g., `/app2` -> 192.168.2.51:8080)
**Then** multiple dev servers are accessible through the same ingress
**And** each path routes to the correct backend

**Given** proxy is working
**When** I test from a Tailscale-connected device outside home network
**Then** dev servers are accessible remotely via the cluster proxy
**And** HTTPS is enforced on all requests

---

### Story 7.3: Enable Hot-Reload Configuration

As a **cluster operator**,
I want **to add or remove proxy targets without restarting the cluster or pods**,
So that **I can quickly update dev proxy routing**.

**Acceptance Criteria:**

**Given** Nginx is deployed with ConfigMap-based configuration
**When** I update the ConfigMap with a new proxy target
**Then** the ConfigMap is updated in the cluster

**Given** ConfigMap is updated
**When** I send a reload signal to Nginx (via nginx -s reload or pod exec)
**Then** Nginx reloads its configuration without restart
**And** existing connections are not interrupted

**Given** manual reload works
**When** I configure Nginx to watch for config changes (inotify or sidecar)
**Then** configuration changes are detected automatically
**And** Nginx reloads within 30 seconds of ConfigMap update
**And** this validates FR43 (add/remove proxy targets without cluster restart)

**Given** hot-reload is working
**When** I remove a proxy target from the ConfigMap
**Then** the route stops working after reload
**And** 404 is returned for the removed path

**Given** configuration is dynamic
**When** I document the process in `docs/runbooks/dev-proxy.md`
**Then** the runbook includes:
- How to add a new proxy target
- How to trigger reload
- How to verify routing
**And** examples are provided for common scenarios

---

## Epic 8: Cluster Operations & Maintenance

Tom can upgrade K3s, backup/restore the cluster, and maintain long-term operations.

---

### Story 8.1: Configure K3s Upgrade Procedure

As a **cluster operator**,
I want **to upgrade K3s version on nodes safely**,
So that **I can apply security patches and new features without downtime**.

**Acceptance Criteria:**

**Given** K3s cluster is running a specific version
**When** I check the current version with `kubectl version`
**Then** the server and client versions are displayed
**And** I can identify if an upgrade is available

**Given** an upgrade is planned
**When** I document the upgrade procedure in `docs/runbooks/k3s-upgrade.md`
**Then** the runbook includes:
- Pre-upgrade checklist (backup, health check)
- Master node upgrade steps
- Worker node upgrade steps (one at a time)
- Rollback procedure

**Given** the runbook is documented
**When** I upgrade the master node first using the K3s install script with `INSTALL_K3S_VERSION`
**Then** the master node restarts with the new version
**And** `kubectl get nodes` shows the master with updated version
**And** control plane recovers within 5 minutes (NFR2)

**Given** master is upgraded
**When** I upgrade worker nodes one at a time (drain -> upgrade -> uncordon)
**Then** pods reschedule during drain
**And** each worker rejoins with the new version
**And** no data loss occurs (NFR20)
**And** this validates FR44 (upgrade K3s version on nodes)

**Given** all nodes are upgraded
**When** I verify cluster health
**Then** all nodes show Ready with matching versions
**And** all pods are Running

---

### Story 8.2: Setup Cluster State Backup

As a **cluster operator**,
I want **to backup cluster state regularly**,
So that **I can recover from control plane failures**.

**Acceptance Criteria:**

**Given** K3s is running with etcd as the datastore
**When** I verify K3s snapshot configuration
**Then** automatic snapshots are enabled (K3s default)
**And** snapshots are stored at `/var/lib/rancher/k3s/server/db/snapshots`

**Given** automatic snapshots are running
**When** I check snapshot files on the master node
**Then** multiple timestamped snapshot files exist
**And** snapshots are taken every 12 hours by default

**Given** default snapshots work
**When** I configure K3s to snapshot to NFS for off-node storage
**Then** the `--etcd-snapshot-dir` points to NFS mount
**And** snapshots are accessible even if master fails

**Given** NFS backup is configured
**When** I create a manual snapshot with `k3s etcd-snapshot save`
**Then** a new snapshot file is created
**And** the snapshot is verified as valid
**And** this validates FR45 (backup cluster state)

**Given** backup is working
**When** I document the backup configuration in `docs/runbooks/cluster-backup.md`
**Then** the runbook includes snapshot location, manual snapshot command, and verification steps

---

### Story 8.3: Validate Cluster Restore Procedure

As a **cluster operator**,
I want **to restore the cluster from a backup**,
So that **I can recover from catastrophic control plane failures**.

**Acceptance Criteria:**

**Given** etcd snapshots exist on NFS
**When** I document the restore procedure in `docs/runbooks/cluster-restore.md`
**Then** the runbook includes:
- When to use restore (vs rebuild)
- Snapshot selection criteria
- Step-by-step restore commands
- Post-restore verification

**Given** restore procedure is documented
**When** I simulate control plane failure (stop K3s, delete etcd data)
**Then** the cluster becomes unavailable
**And** kubectl commands fail

**Given** cluster is down
**When** I restore from snapshot using `k3s server --cluster-reset --cluster-reset-restore-path=<snapshot>`
**Then** K3s restarts with the restored state
**And** the restore completes within 30 minutes (NFR6)

**Given** restore completes
**When** I verify cluster state
**Then** `kubectl get nodes` shows all nodes
**And** `kubectl get pods --all-namespaces` shows workloads
**And** application data is intact
**And** this validates FR46 (restore cluster from backup)

**Given** restore is validated
**When** I rejoin worker nodes if needed
**Then** workers reconnect to the restored master
**And** full cluster operation resumes

---

### Story 8.4: Configure Automatic OS Security Updates

As a **cluster operator**,
I want **node operating systems to apply security updates automatically**,
So that **vulnerabilities are patched without manual intervention**.

**Acceptance Criteria:**

**Given** Ubuntu Server is running on all nodes
**When** I install and configure unattended-upgrades package
**Then** the package is installed on master and all workers
**And** security updates are enabled in configuration

**Given** unattended-upgrades is installed
**When** I configure `/etc/apt/apt.conf.d/50unattended-upgrades`
**Then** only security updates are applied (not all updates)
**And** automatic reboot is disabled (manual control)
**And** email notifications are configured (optional)

**Given** configuration is applied
**When** I verify with `unattended-upgrade --dry-run`
**Then** pending security updates are listed
**And** no non-security updates are included

**Given** unattended-upgrades is working
**When** a security update is released
**Then** it is applied within 7 days (NFR11)
**And** this validates FR47 (system applies security updates automatically)

**Given** updates are automatic
**When** I need to track what was updated
**Then** logs are available at `/var/log/unattended-upgrades/`
**And** I can view upgrade history
**And** this partially validates FR48 (view upgrade history)

---

### Story 8.5: Document Rollback and History Procedures

As a **cluster operator**,
I want **to view upgrade history and rollback if needed**,
So that **I can recover from problematic upgrades**.

**Acceptance Criteria:**

**Given** K3s has been upgraded
**When** I check K3s version history
**Then** I can see current version with `k3s --version`
**And** previous versions are noted in upgrade runbook

**Given** upgrade history is tracked
**When** I document rollback procedures in `docs/runbooks/k3s-rollback.md`
**Then** the runbook includes:
- When to rollback vs restore
- Rollback using previous K3s binary
- Rollback using etcd snapshot
- Post-rollback verification

**Given** a problematic upgrade occurs
**When** I follow the rollback procedure
**Then** I can reinstall the previous K3s version
**And** cluster returns to previous state
**And** this validates FR48 (view upgrade history and rollback if needed)

**Given** OS updates need rollback
**When** I document package rollback in runbook
**Then** apt history commands are documented
**And** package downgrade procedure is included

**Given** all runbooks are complete
**When** I review the docs/runbooks/ directory
**Then** runbooks exist for all P1 alert scenarios
**And** this validates NFR22 (runbooks for P1 scenarios)

---

## Epic 9: Portfolio & Public Showcase

Tom has a polished public portfolio that demonstrates capability to hiring managers and recruiters.

---

### Story 9.1: Structure Public GitHub Repository

As a **portfolio audience member**,
I want **to view a well-organized public GitHub repository**,
So that **I can understand the project structure and navigate easily**.

**Acceptance Criteria:**

**Given** the home-lab project exists locally
**When** I structure the repository following the architecture
**Then** the following directories exist:
- `infrastructure/` (k3s, nfs, metallb, cert-manager)
- `applications/` (postgres, ollama, nginx, n8n)
- `monitoring/` (prometheus, loki)
- `docs/` (adrs, runbooks, diagrams)
- `scripts/`

**Given** the structure is created
**When** I create a comprehensive README.md
**Then** the README includes:
- Project overview and purpose
- Architecture diagram or link
- Quick start guide
- Directory structure explanation
- Link to blog posts
**And** setup can be understood in <2 hours (NFR25)

**Given** README is complete
**When** I add a .gitignore file
**Then** sensitive files are excluded (kubeconfig, secrets, .env)
**And** generated files are excluded

**Given** repository is structured
**When** I push to GitHub and make the repository public
**Then** the repository is accessible at github.com/{username}/home-lab
**And** this validates FR49 (audience can view public GitHub repository)

**Given** repository is public
**When** a hiring manager visits the repository
**Then** they can navigate the structure intuitively (NFR27)
**And** the professional README makes a strong first impression

---

### Story 9.2: Create Architecture Decision Records

As a **portfolio audience member**,
I want **to read architecture decision records**,
So that **I can understand the reasoning behind technical choices**.

**Acceptance Criteria:**

**Given** docs/adrs/ directory exists
**When** I create ADRs for key decisions made during the project
**Then** ADRs are created following pattern `ADR-{NNN}-{short-title}.md`
**And** this validates FR53 (document decisions as ADRs)

**Given** ADR template is established
**When** I write ADR-001-k3s-over-k8s.md
**Then** the ADR includes:
- Title and date
- Status (accepted)
- Context (why this decision was needed)
- Decision (what was chosen)
- Consequences (trade-offs and implications)

**Given** first ADR is complete
**When** I create additional ADRs for:
- ADR-002-nfs-over-longhorn.md
- ADR-003-traefik-ingress.md
- ADR-004-kube-prometheus-stack.md
- ADR-005-manual-helm-over-gitops.md
**Then** all major architectural decisions are documented
**And** this validates NFR24 (all decisions documented as ADRs)

**Given** ADRs are written
**When** a technical interviewer reads them
**Then** they can see "I chose X over Y because..." reasoning
**And** trade-off analysis demonstrates engineering judgment
**And** this validates FR50 (audience can read ADRs)

**Given** ADRs are complete
**When** I add an index to docs/adrs/README.md
**Then** all ADRs are listed with brief descriptions
**And** the index links to each ADR

---

### Story 9.3: Capture and Document Grafana Screenshots

As a **portfolio audience member**,
I want **to view Grafana dashboard screenshots**,
So that **I can see the running infrastructure without access to the cluster**.

**Acceptance Criteria:**

**Given** Grafana is running with dashboards populated
**When** I capture screenshots of key dashboards:
- Kubernetes Cluster Overview
- Node Resource Usage
- Pod Status Dashboard
- Custom home-lab dashboard
**Then** screenshots are saved as PNG files

**Given** screenshots are captured
**When** I save them to `docs/diagrams/screenshots/`
**Then** files are named descriptively (e.g., `grafana-cluster-overview.png`)
**And** file sizes are optimized for web viewing

**Given** screenshots are saved
**When** I add them to the README or a dedicated docs page
**Then** images are embedded or linked
**And** each screenshot has a caption explaining what it shows
**And** this validates FR51 (audience can view Grafana dashboard screenshots)

**Given** screenshots show real data
**When** a hiring manager views them
**Then** they see proof of running infrastructure
**And** they can see metrics from actual workloads

**Given** visual documentation is complete
**When** I create an architecture diagram using Excalidraw or similar
**Then** the diagram shows cluster topology, network flow, and components
**And** the diagram is saved to `docs/diagrams/architecture-overview.png`

---

### Story 9.4: Write and Publish First Technical Blog Post

As a **portfolio audience member**,
I want **to read technical blog posts about the build**,
So that **I can understand the journey and learn from the experience**.

**Acceptance Criteria:**

**Given** the cluster is operational with workloads running
**When** I outline a blog post about the project
**Then** the outline covers:
- Introduction (career context, why this project)
- Technical approach (K3s, home lab setup)
- Key learnings (what worked, what didn't)
- Connection to automotive experience
- Call to action (links to repo, next steps)

**Given** outline is complete
**When** I write the full blog post (1500-2500 words)
**Then** the post is technically accurate
**And** the narrative connects automotive to Kubernetes
**And** AI-assisted methodology is mentioned as differentiator

**Given** blog post is written
**When** I publish to dev.to (or similar platform)
**Then** the post is publicly accessible
**And** the post includes link to GitHub repository
**And** this validates FR54 (publish blog posts to dev.to or similar)

**Given** post is published
**When** I share on LinkedIn
**Then** the post reaches professional network
**And** this validates FR52 (audience can read technical blog posts)

**Given** first post is complete
**When** I link the post from the GitHub README
**Then** visitors can find the blog content
**And** the portfolio has complete narrative arc

---

### Story 9.5: Document All Deployed Services

As a **portfolio audience member**,
I want **to understand the purpose and configuration of each service**,
So that **I can evaluate the depth of implementation**.

**Acceptance Criteria:**

**Given** all services are deployed
**When** I create documentation for each major component
**Then** each component has a README or doc section explaining:
- What it does
- Why it was chosen
- Key configuration decisions
- How to access/use it

**Given** component documentation exists
**When** I organize it under appropriate directories
**Then** `infrastructure/*/README.md` documents infra components
**And** `applications/*/README.md` documents applications
**And** `monitoring/*/README.md` documents observability stack
**And** this validates NFR26 (all services documented)

**Given** documentation is complete
**When** I create a portfolio summary page at `docs/PORTFOLIO.md`
**Then** the page provides:
- High-level project summary
- Skills demonstrated
- Technologies used
- Links to key sections
**And** this serves as a "resume companion" document

**Given** all documentation is in place
**When** a hiring manager spends 10 minutes reviewing
**Then** they can understand scope, depth, and quality
**And** they have enough context to prepare interview questions
**And** this validates NFR27 (navigable by external reviewer)

---

### Story 9.6: Write Comprehensive Technical Blog Post

As a **portfolio audience member**,
I want **to read a detailed technical blog post about the home-lab project**,
So that **I can understand the implementation journey, technical decisions, and AI-assisted engineering workflow**.

**Story Points:** 5

**Acceptance Criteria:**

**Given** the home-lab project has reached Phase 4 completion
**When** I write a comprehensive technical blog post (FR146)
**Then** the post covers:
- Project motivation and goals
- Phase 1 MVP architecture and implementation
- New feature additions (Tailscale subnet routing, NAS worker, Open-WebUI, etc.)
- Key technical challenges and solutions
- Lessons learned

**Given** the blog post draft is complete
**When** I add visual content (FR147)
**Then** the post includes:
- Architecture diagrams (from docs/planning-artifacts/)
- ADR references with links to key decisions
- Grafana dashboard screenshots showing real metrics
- Code snippets for key configurations

**Given** the blog post covers technical content
**When** I document the AI-assisted workflow (FR148)
**Then** the post explains:
- How BMAD framework was used for planning
- How Claude Code assisted with implementation
- Specific examples of AI-human collaboration
- Productivity gains and workflow improvements

**Given** the blog post is complete
**When** I publish to dev.to or equivalent platform (NFR85)
**Then** the post is publicly accessible
**And** it includes appropriate tags (kubernetes, homelab, ai, devops)
**And** publication occurs within 2 weeks of Epic completion

**Tasks:**
- [ ] Create blog post outline with all major sections
- [ ] Write project overview and motivation section
- [ ] Document Phase 1 MVP implementation journey
- [ ] Cover new Phase 4 features and their value
- [ ] Create/export architecture diagrams for the post
- [ ] Capture Grafana screenshots showing real cluster metrics
- [ ] Write AI-assisted engineering workflow section
- [ ] Add code snippets for key configurations
- [ ] Review and edit for technical accuracy
- [ ] Publish to dev.to with appropriate tags
- [ ] Share on LinkedIn/social media

---

## Phase 2 Epic Details

### Epic 10: Document Management System (Paperless-ngx Ecosystem)

**User Outcome:** Tom has a comprehensive self-hosted document management system with scanning, tagging, searching, AI-powered classification, Office document processing, PDF editing, and automatic email import.

**FRs Covered:** FR55-58, FR64-66, FR75-93
**NFRs Covered:** NFR28-30, NFR39-49

---

#### Story 10.1: Deploy Paperless-ngx with Redis Backend

**As a** platform engineer
**I want** Paperless-ngx deployed with Redis for task queuing
**So that** the document management system can process uploads and OCR tasks asynchronously

**Acceptance Criteria:**

**Given** cluster has `docs` namespace
**When** I deploy Paperless-ngx via gabe565 Helm chart
**Then** the following resources are created:
- Deployment: `paperless-ngx` (1 replica)
- Deployment: `redis` (1 replica for task queue)
- Service: `paperless-ngx` (port 8000)
- Service: `redis` (port 6379)

**Given** Paperless-ngx is deployed
**When** I check Helm values configuration
**Then** the chart uses:
- Image: `ghcr.io/paperless-ngx/paperless-ngx:latest`
- Redis connection: `redis://redis:6379`
- Environment variables set for PAPERLESS_URL, PAPERLESS_SECRET_KEY

**Given** pods are running
**When** I execute `kubectl get pods -n docs`
**Then** both `paperless-ngx-*` and `redis-*` pods show status Running
**And** this validates FR55 (deploy Paperless-ngx with Redis)

**Story Points:** 5

---

#### Story 10.2: Configure PostgreSQL Backend

**As a** platform engineer
**I want** Paperless-ngx to use the existing cluster PostgreSQL database instead of SQLite
**So that** the system can scale to 5,000+ documents with efficient metadata queries

**Acceptance Criteria:**

**Given** cluster PostgreSQL is running in `data` namespace
**When** I configure Paperless-ngx database connection
**Then** Helm values include:
```yaml
env:
  PAPERLESS_DBENGINE: postgresql
  PAPERLESS_DBHOST: postgresql.data.svc.cluster.local
  PAPERLESS_DBNAME: paperless
  PAPERLESS_DBUSER: paperless_user
  PAPERLESS_DBPORT: "5432"
```

**Given** PostgreSQL credentials are configured
**When** I create database and user in PostgreSQL
**Then** database `paperless` exists with user `paperless_user`
**And** credentials are stored in `secrets/paperless-secrets.yaml` (gitignored)
**And** this validates FR66 (PostgreSQL backend for metadata)

**Given** Paperless-ngx is upgraded with PostgreSQL config
**When** I check pod logs
**Then** logs show successful PostgreSQL connection
**And** logs show database migration completion
**And** no SQLite-related errors appear
**And** this validates NFR29 (scales to 5,000+ documents)

**Story Points:** 3

---

#### Story 10.3: Configure OCR with German and English Support

**As a** user
**I want** Paperless-ngx to perform OCR on scanned documents in German and English
**So that** I can search document contents in both languages

**Acceptance Criteria:**

**Given** Paperless-ngx is running
**When** I configure OCR language support
**Then** Helm values include:
```yaml
env:
  PAPERLESS_OCR_LANGUAGE: deu+eng
  PAPERLESS_OCR_MODE: skip
```

**Given** OCR is configured
**When** I upload a test PDF with German text
**Then** Paperless-ngx processes the document
**And** OCR extracts German text searchable in the interface
**And** this validates NFR28 (95%+ OCR accuracy for German and English)

**Given** OCR processing is complete
**When** I search for a German keyword from the document
**Then** search returns results within 3 seconds
**And** this validates NFR30 (search performance target)

**Story Points:** 5

---

#### Story 10.4: Configure NFS Persistent Storage

**As a** platform engineer
**I want** Paperless-ngx to store documents on NFS
**So that** documents persist across pod restarts and benefit from Synology snapshots

**Acceptance Criteria:**

**Given** NFS StorageClass exists (`nfs-client`)
**When** I configure Paperless-ngx PVC via Helm values
**Then** the following PVCs are created:
- `paperless-data` (50GB) - for uploaded documents
- `paperless-media` (20GB) - for thumbnails and exports

**Given** PVCs are bound
**When** I check volume mounts
**Then** Paperless-ngx pod mounts:
- `/usr/src/paperless/data` → `paperless-data` PVC
- `/usr/src/paperless/media` → `paperless-media` PVC

**Given** storage is mounted
**When** I upload a test document
**Then** the document file appears in Synology NFS share under `/volume1/k8s-data/docs-paperless-data-*/`
**And** this validates FR56 (Paperless persists to NFS)

**Given** Synology snapshots are configured
**When** I verify snapshot schedule
**Then** hourly snapshots include Paperless document directories
**And** documents are protected from accidental deletion

**Story Points:** 3

---

#### Story 10.5: Configure Ingress with HTTPS

**As a** user
**I want** to access Paperless-ngx via HTTPS at `paperless.home.jetzinger.com`
**So that** I can securely browse and upload documents from any Tailscale-connected device

**Acceptance Criteria:**

**Given** Traefik and cert-manager are operational
**When** I create IngressRoute for Paperless-ngx
**Then** the manifest defines:
```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: paperless-https
  namespace: docs
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`paperless.home.jetzinger.com`)
      kind: Rule
      services:
        - name: paperless-ngx
          port: 8000
  tls:
    certResolver: letsencrypt
```

**Given** IngressRoute is applied
**When** I access `https://paperless.home.jetzinger.com` from Tailscale device
**Then** the Paperless-ngx login page loads with valid TLS certificate
**And** this validates FR57 (HTTPS access via ingress)

**Given** I log in to Paperless-ngx
**When** I browse the document library
**Then** the interface loads without TLS warnings
**And** I can upload, tag, and search documents
**And** this validates FR58 (upload, tag, search functionality)

**Story Points:** 3

---

#### Story 10.6: Validate Document Management Workflow

**As a** user
**I want** to verify the complete document lifecycle
**So that** I can confidently migrate from manual file storage to Paperless-ngx

**Acceptance Criteria:**

**Given** Paperless-ngx is fully operational
**When** I upload 10 test documents (mix of scanned PDFs and manual uploads)
**Then** all documents appear in the library within 30 seconds
**And** OCR processing completes for scanned documents

**Given** documents are processed
**When** I create tags: "Invoices", "Contracts", "Medical", "Taxes"
**Then** I can assign multiple tags to each document
**And** tags appear in the sidebar for filtering

**Given** documents are tagged
**When** I perform full-text search for specific keywords
**Then** search returns relevant documents within 3 seconds
**And** search highlights matching text in document previews

**Given** the system handles 10 documents
**When** I scale to 100 documents (simulate realistic usage)
**Then** interface remains responsive (<5s page load)
**And** this validates NFR29 (scales to 5,000+ documents)

**Given** I verify backup coverage
**When** I check Synology snapshots
**Then** all uploaded documents are included in hourly snapshots
**And** I can access previous versions via Synology UI

**Story Points:** 5

---

#### Story 10.7: Configure Single-User Mode with NFS Polling

**As a** platform engineer
**I want** Paperless-ngx configured for single-user operation with NFS-compatible polling
**So that** documents dropped into consume folders via NFS mount are automatically imported

**Acceptance Criteria:**

**Given** Paperless-ngx is deployed with NFS storage
**When** I configure single-user and polling settings
**Then** Helm values include:
```yaml
env:
  PAPERLESS_CONSUMER_SUBDIRS_AS_TAGS: "true"
  PAPERLESS_CONSUMER_RECURSIVE: "true"
  PAPERLESS_CONSUMER_DELETE_DUPLICATES: "true"
  PAPERLESS_CONSUMER_POLLING: "10"
  PAPERLESS_CONSUMER_POLLING_DELAY: "5"
  PAPERLESS_CONSUMER_POLLING_RETRY_COUNT: "5"
```
**And** this validates FR75 (single-user folder-based organization)
**And** this validates FR76 (duplicate document detection)
**And** this validates NFR39 (NFS polling mode required)
**And** this validates NFR40 (10-second polling interval)

**Given** consume folder is NFS-mounted on workstation
**When** I verify NFS mount path from `/etc/fstab`
**Then** the consume PVC is accessible at `/mnt/paperless`
**And** scanner/desktop can drop files into this directory
**And** this validates FR77 (NFS mount from workstation)

**Given** NFS polling is configured
**When** I drop a test PDF into the consume folder
**Then** Paperless-ngx detects the file within 10 seconds
**And** document appears in library within 30 seconds of detection
**And** this validates FR78 (auto-import within 30 seconds)

**Implementation Notes:**
- NFS does not support inotify, polling is required
- Polling interval: 10 seconds (PAPERLESS_CONSUMER_POLLING)
- Polling delay: 5 seconds wait after file change before consuming
- Retry count: 5 attempts if file is locked during upload

**Story Points:** 3

---

#### Story 10.8: Implement Security Hardening

**As a** platform engineer
**I want** CSRF and CORS protection enabled for Paperless-ngx
**So that** the web interface is protected against cross-site attacks

**Acceptance Criteria:**

**Given** Paperless-ngx is deployed with ingress
**When** I configure security hardening settings
**Then** Helm values include:
```yaml
env:
  PAPERLESS_CSRF_TRUSTED_ORIGINS: "https://paperless.home.jetzinger.com"
  PAPERLESS_CORS_ALLOWED_HOSTS: "https://paperless.home.jetzinger.com"
  PAPERLESS_COOKIE_PREFIX: "paperless_ngx"
  PAPERLESS_ENABLE_HTTP_REMOTE_USER: "false"
```
**And** this validates FR79 (CSRF protection enabled)
**And** this validates FR80 (CORS restricted to authorized origins)

**Given** security settings are applied
**When** I attempt cross-origin request from unauthorized domain
**Then** request is rejected with CORS error
**And** CSRF token validation is enforced on form submissions

**Story Points:** 2

---

#### Story 10.9: Deploy Office Document Processing (Tika + Gotenberg)

**As a** user
**I want** Paperless-ngx to process Office documents (Word, Excel, PowerPoint)
**So that** I can import business documents directly without manual PDF conversion

**Acceptance Criteria:**

**Given** cluster has `docs` namespace
**When** I deploy Apache Tika and Gotenberg
**Then** the following resources are created:
- Deployment: `tika` (1 replica, image: `apache/tika:latest`)
- Service: `tika` (port 9998)
- Deployment: `gotenberg` (1 replica, image: `gotenberg/gotenberg:8`)
- Service: `gotenberg` (port 3000)

**Given** Tika and Gotenberg are running
**When** I configure Paperless-ngx integration
**Then** Helm values include:
```yaml
env:
  PAPERLESS_TIKA_ENABLED: "true"
  PAPERLESS_TIKA_ENDPOINT: "http://tika:9998"
  PAPERLESS_TIKA_GOTENBERG_ENDPOINT: "http://gotenberg:3000"
```
**And** this validates FR81 (Apache Tika for text extraction)
**And** this validates FR82 (Gotenberg for PDF conversion)

**Given** Office processing is configured
**When** I upload a .docx, .xlsx, or .pptx file
**Then** Paperless-ngx converts the file to PDF via Gotenberg
**And** text is extracted via Tika for full-text search
**And** document appears in library with searchable content
**And** this validates FR83 (direct Office format import)

**Given** OCR workers are configured
**When** I check processing performance
**Then** PAPERLESS_TASK_WORKERS is set to 2
**And** this validates NFR41 (2 parallel OCR workers)

**Implementation Notes:**
- Tika: Text and metadata extraction from Office docs
- Gotenberg: PDF conversion with Chromium engine (Office-to-PDF)
- Gotenberg flags: `--chromium-disable-javascript=true` for security
- Both services are internal, no ingress required

**Story Points:** 5

---

#### Story 10.10: Deploy Stirling-PDF

**As a** user
**I want** Stirling-PDF deployed for PDF manipulation
**So that** I can split, merge, rotate, and compress PDFs via web interface

**Acceptance Criteria:**

**Given** cluster has `docs` namespace
**When** I deploy Stirling-PDF via Helm
**Then** I run:
```bash
helm repo add stirling-pdf https://stirling-tools.github.io/Stirling-PDF-chart
helm install stirling-pdf stirling-pdf/stirling-pdf-chart \
  --namespace docs \
  -f applications/stirling-pdf/values-homelab.yaml
```
**And** Deployment `stirling-pdf` is created with 1 replica
**And** Service `stirling-pdf` is created on port 8080

**Given** Stirling-PDF is deployed
**When** I create Helm values file
**Then** configuration includes:
```yaml
env:
  SECURITY_ENABLELOGIN: "false"
  SYSTEM_DEFAULTLOCALE: "de-DE"
persistence:
  enabled: false  # Stateless operation
```

**Given** Stirling-PDF is running
**When** I create IngressRoute for HTTPS access
**Then** `stirling.home.jetzinger.com` routes to Stirling-PDF service
**And** TLS certificate is provisioned via cert-manager
**And** this validates FR84 (Stirling-PDF deployed)
**And** this validates FR86 (ingress with HTTPS)

**Given** Stirling-PDF is accessible
**When** I use the web interface
**Then** I can split, merge, rotate, and compress PDFs
**And** this validates FR85 (PDF manipulation capabilities)

**Implementation Notes:**
- Official Helm chart: `stirling-pdf/stirling-pdf-chart`
- Stateless operation (no persistent storage needed)
- German locale (de-DE) matches user preference
- No authentication (internal Tailscale network only)

**Story Points:** 3

---

#### Story 10.11: Configure Email Integration

**As a** user
**I want** Paperless-ngx to monitor my email inboxes for document attachments
**So that** invoices and documents sent via email are automatically imported

**Acceptance Criteria:**

**Given** cluster has `docs` namespace
**When** I deploy email bridge container for private email provider
**Then** the following resources are created:
- StatefulSet: `email-bridge` (1 replica)
- Service: `email-bridge` (ports: 143 IMAP, 25 SMTP)
- PVC: for credential storage (1Gi)

**Given** email bridge is running
**When** I configure bridge credentials
**Then** I exec into pod and run bridge CLI
**And** I login with email account
**And** bridge generates IMAP credentials

**Given** email accounts are configured
**When** I set up Paperless-ngx mail fetcher via UI
**Then** Mail Accounts include:
- Private Email: IMAP server via bridge, bridge credentials
- Gmail: IMAP server `imap.gmail.com:993`, App Password authentication
**And** this validates FR90 (monitor private email inbox)
**And** this validates FR91 (monitor Gmail inbox)
**And** this validates FR93 (email bridge container)

**Given** mail rules are configured
**When** I create mail rules for document consumption
**Then** rules filter by subject/sender for invoices, statements, contracts
**And** PDF and Office attachments are extracted and imported
**And** this validates FR92 (auto-import email attachments)

**Given** email integration is active
**When** I receive an email with PDF attachment
**Then** attachment appears in Paperless-ngx within mail check interval
**And** document is tagged based on mail rule configuration

**Implementation Notes:**
- Email Bridge: Required for private email IMAP access
- Gmail: Direct IMAP with App Password (OAuth not supported)
- Mail fetcher runs on configurable schedule (hourly default)
- Credentials stored in Kubernetes secrets (gitignored)

**Story Points:** 5

---

### Epic 11: Dev Containers Platform

**User Outcome:** Tom can provision isolated development containers accessible via custom domains, supporting remote VS Code and Claude Code workflows.

**FRs Covered:** FR59, FR60, FR61, FR62, FR63, FR67, FR68, FR69, FR70
**NFRs Covered:** NFR31, NFR32, NFR33

---

#### Story 11.1: Create Dev Container Base Image

**As a** platform engineer
**I want** a standardized dev container base image with all required tools
**So that** new dev containers can be provisioned consistently

**Acceptance Criteria:**

**Given** I need a base image for dev containers
**When** I create a Dockerfile
**Then** it includes the following components:
```dockerfile
FROM ubuntu:22.04
RUN apt-get update && apt-get install -y \
    openssh-server curl git sudo vim
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs
RUN apt-get install -y python3.11 python3-pip
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && chmod +x kubectl && mv kubectl /usr/local/bin/
RUN curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
RUN npm install -g @anthropic-ai/claude-code
RUN useradd -m -s /bin/bash dev && echo "dev ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
EXPOSE 22
CMD ["/usr/sbin/sshd", "-D"]
```

**Given** Dockerfile is created
**When** I build the image
**Then** the build completes without errors
**And** image is tagged as `dev-container-base:latest`

**Given** image is built
**When** I verify installed tools
**Then** the image includes:
- Node.js 20.x with npm
- Python 3.11 with pip
- kubectl (latest stable)
- helm 3
- Claude Code CLI (`claude-code --version` works)
- git, sudo, vim, SSH server

**Given** image is verified
**When** I push to local registry or rebuild for each deployment
**Then** the image is available for dev container deployments
**And** this validates FR67 (single base image with all tools)

**Story Points:** 5

---

#### Story 11.2: Deploy Dev Containers for Belego and Pilates

**As a** developer
**I want** two dev containers deployed (one for Belego, one for Pilates projects)
**So that** I can develop both projects in isolated environments

**Acceptance Criteria:**

**Given** base image exists
**When** I deploy dev container for Belego
**Then** the following resources are created in `dev` namespace:
- Deployment: `dev-container-belego` (1 replica)
- Service: `dev-container-belego-svc` (port 22 for SSH)
- Resources: 2 CPU cores, 4GB RAM (FR68)

**Given** Belego container is deployed
**When** I deploy dev container for Pilates
**Then** the following resources are created:
- Deployment: `dev-container-pilates` (1 replica)
- Service: `dev-container-pilates-svc` (port 22 for SSH)
- Resources: 2 CPU cores, 4GB RAM

**Given** both containers are running
**When** I execute `kubectl get pods -n dev`
**Then** both `dev-container-belego-*` and `dev-container-pilates-*` show status Running
**And** each pod has SSH server listening on port 22

**Given** I verify resource allocation
**When** I check pod resource requests
**Then** cluster allocates 4 CPU cores and 8GB RAM total
**And** resources are within cluster capacity (k3s-worker nodes have sufficient resources)

**Story Points:** 5

---

#### Story 11.3: Configure Persistent Storage for Workspaces

**As a** developer
**I want** persistent 10GB volumes for each dev container
**So that** my git repos and workspace data survive container restarts

**Acceptance Criteria:**

**Given** NFS StorageClass exists
**When** I configure PVCs for dev containers
**Then** the following PVCs are created:
- `dev-belego-workspace` (10GB, nfs-client StorageClass)
- `dev-pilates-workspace` (10GB, nfs-client StorageClass)

**Given** PVCs are bound
**When** I check volume mounts in deployments
**Then** each dev container mounts:
- `/home/dev/workspace` → respective PVC

**Given** volumes are mounted
**When** I SSH into Belego container and create test files
**Then** files persist in `/home/dev/workspace`
**And** files appear in Synology NFS share under `/volume1/k8s-data/dev-*-workspace-*/`

**Given** container is restarted
**When** I delete the pod and wait for recreation
**Then** new pod mounts the same PVC
**And** test files are still present in `/home/dev/workspace`
**And** this validates NFR32 (workspace data persists across restarts)

**Story Points:** 3

---

#### Story 11.4: Configure Nginx SSH Proxy with Custom Domains

**As a** developer
**I want** SSH access to dev containers via custom domains on different ports
**So that** I can use VS Code Remote SSH with familiar domain names

**Acceptance Criteria:**

**Given** dev containers are running
**When** I deploy Nginx with stream module
**Then** the ConfigMap includes:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
  namespace: dev
data:
  nginx.conf: |
    load_module /usr/lib/nginx/modules/ngx_stream_module.so;
    events {}
    stream {
      upstream dev-belego {
        server dev-container-belego-svc.dev.svc.cluster.local:22;
      }
      upstream dev-pilates {
        server dev-container-pilates-svc.dev.svc.cluster.local:22;
      }
      server {
        listen 2222;
        proxy_pass dev-belego;
      }
      server {
        listen 2223;
        proxy_pass dev-pilates;
      }
    }
```

**Given** Nginx proxy is deployed
**When** I create IngressRoutes for HTTP/HTTPS access
**Then** the following domains are configured:
- `dev.belego.app` → Nginx service (Belego HTTP traffic)
- `dev.app.pilates4.golf` → Nginx service (Pilates HTTP - all 4 subdomains)
- `dev.blog.pilates4.golf` → Nginx service (same backend)
- `dev.join.pilates4.golf` → Nginx service (same backend)
- `dev.www.pilates4.golf` → Nginx service (same backend)

**Given** IngressRoutes use custom domains
**When** I configure NextDNS with wildcard rewrites
**Then** the following DNS entries point to MetalLB IP (192.168.2.100):
- `*.belego.app` → 192.168.2.100
- `*.pilates4.golf` → 192.168.2.100

**Given** DNS is configured
**When** I SSH to `dev.belego.app:2222`
**Then** I connect to Belego dev container
**And** when I SSH to any Pilates domain on port 2223
**Then** I connect to the same Pilates dev container
**And** this validates FR59, FR61 (Nginx proxy routes to dev containers)

**Story Points:** 8

---

#### Story 11.5: Configure NetworkPolicy for Container Isolation

**As a** platform engineer
**I want** dev containers isolated via NetworkPolicy
**So that** containers cannot communicate directly and are only accessible via Nginx proxy

**Acceptance Criteria:**

**Given** dev containers are running
**When** I create NetworkPolicy for `dev` namespace
**Then** the policy defines:
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: dev-container-isolation
  namespace: dev
spec:
  podSelector:
    matchLabels:
      app: dev-container
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: nginx
    ports:
    - protocol: TCP
      port: 22
  egress:
  - to:
    - namespaceSelector: {}
      podSelector:
        matchLabels:
          k8s-app: kube-dns
    ports:
    - protocol: UDP
      port: 53
  - to:
    - namespaceSelector:
        matchLabels:
          name: data
    ports:
    - protocol: TCP
      port: 5432
  - to:
    - namespaceSelector:
        matchLabels:
          name: ml
    ports:
    - protocol: TCP
      port: 11434
```

**Given** NetworkPolicy is applied
**When** I test connectivity from Belego container
**Then** the container can:
- Reach DNS (kube-dns)
- Connect to PostgreSQL in `data` namespace (port 5432)
- Connect to Ollama in `ml` namespace (port 11434)

**Given** NetworkPolicy is enforced
**When** I test blocked connectivity
**Then** the container cannot:
- Connect to other dev containers directly (SSH blocked)
- Reach external internet without explicit egress rule

**Given** isolation is verified
**When** I confirm access via Nginx proxy
**Then** SSH connections work via Nginx stream module on ports 2222/2223
**And** this validates NFR33 (NetworkPolicy isolation)

**Story Points:** 5

---

#### Story 11.6: Validate VS Code Remote SSH Configuration

**As a** developer
**I want** VS Code Remote SSH working with both dev containers
**So that** I can develop remotely with full IDE features

**Acceptance Criteria:**

**Given** dev containers are accessible via SSH
**When** I configure VS Code SSH config
**Then** `~/.ssh/config` includes:
```ssh-config
Host belego-dev
  HostName dev.belego.app
  Port 2222
  User dev
  IdentityFile ~/.ssh/id_rsa

Host pilates-dev
  HostName dev.app.pilates4.golf
  Port 2223
  User dev
  IdentityFile ~/.ssh/id_rsa
```

**Given** SSH config is created
**When** I connect to `belego-dev` via VS Code Remote SSH
**Then** VS Code connects successfully
**And** I can browse `/home/dev/workspace`
**And** this validates FR61 (VS Code connection)

**Given** VS Code is connected
**When** I open a terminal in VS Code
**Then** I can run `claude-code --version`
**And** Claude Code CLI responds with version information
**And** this validates FR62 (Claude Code inside dev containers)

**Given** I clone a git repo in workspace
**When** I restart the container
**Then** the cloned repo persists in `/home/dev/workspace`
**And** this validates FR60, FR63 (git worktree support and local storage)

**Given** both containers are validated
**When** I measure provisioning time
**Then** new dev container ready within 90 seconds (image pull + volume mount)
**And** this validates NFR31 (provisioning performance)

**Story Points:** 5

---

### Epic 12: GPU/ML Inference Platform (vLLM + Qwen 2.5 14B)

**User Outcome:** AI/ML workflows can access GPU-accelerated inference via vLLM with Qwen 2.5 14B model, with Paperless-AI document classification (including RAG chat) using vLLM's OpenAI-compatible API. Ollama downgraded to slim models for experimentation. OpenAI gpt-4o-mini fallback when GPU unavailable (Epic 13).

**FRs Covered:** FR38, FR39, FR71-74, FR87-89, FR94, FR100-112
**NFRs Covered:** NFR34-38, NFR50, NFR55-64

---

#### Story 12.1: Install Ubuntu 22.04 on Intel NUC and Configure eGPU

**As a** platform engineer
**I want** Ubuntu 22.04 installed on the Intel NUC with RTX 3060 eGPU configured
**So that** the hardware is ready to join the K3s cluster with GPU capabilities

**Acceptance Criteria:**

**Given** I have Intel NUC hardware and RTX 3060 eGPU
**When** I install Ubuntu 22.04 LTS
**Then** the OS is installed with:
- Static IP: 192.168.0.25 (Intel NUC local network)
- Hostname: `k3s-gpu-worker`
- SSH access configured with key-based authentication
- System updates applied: `sudo apt update && sudo apt upgrade -y`

**Given** OS is installed
**When** I connect the eGPU via Thunderbolt
**Then** `boltctl list` shows the eGPU enclosure
**And** I authorize the device: `boltctl authorize <device-uuid>`
**And** `lspci | grep NVIDIA` shows RTX 3060

**Given** eGPU is detected
**When** I install NVIDIA drivers
**Then** I run:
```bash
sudo apt install nvidia-driver-535
sudo reboot
```
**And** after reboot, `nvidia-smi` shows RTX 3060 with 12GB VRAM
**And** driver version is 535+ (CUDA 12.2+ compatible)
**And** nvidia-persistenced daemon is enabled: `sudo systemctl enable --now nvidia-persistenced`

**Given** drivers are installed
**When** I configure system hardening
**Then** UFW firewall allows SSH and K3s ports
**And** unattended upgrades are enabled
**And** eGPU auto-connects on boot

**Story Points:** 5

---

#### Story 12.2: Configure Tailscale Mesh on All K3s Nodes (Solution A)

**As a** platform engineer
**I want** Tailscale installed on all K3s nodes with flannel configured over the mesh
**So that** the Intel NUC GPU worker can join the cluster from a different subnet (192.168.0.x → 192.168.2.x)

**Acceptance Criteria:**

**AC1: Install Tailscale on Existing K3s Nodes**
**Given** K3s cluster is running (master, worker-01, worker-02)
**When** I install Tailscale on each node
**Then** I run on each node:
```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```
**And** each node gets a Tailscale IP (100.x.x.a, 100.x.x.b, 100.x.x.c)
**And** all nodes appear in Tailscale admin console
**And** this validates FR100 (all K3s nodes run Tailscale)

**AC2: Configure K3s Master with Tailscale**
**Given** Tailscale is running on k3s-master
**When** I update K3s server config
**Then** I add to `/etc/rancher/k3s/config.yaml`:
```yaml
flannel-iface: tailscale0
node-external-ip: <tailscale-100.x.x.a>
tls-san:
  - <tailscale-100.x.x.a>
  - 192.168.2.20
```
**And** I add to `/etc/environment`:
```bash
NO_PROXY=127.0.0.0/8,10.0.0.0/8,100.64.0.0/10,172.16.0.0/12,192.168.0.0/16,.local,localhost
```
**And** I restart K3s: `sudo systemctl restart k3s`
**And** this validates FR101, FR102, FR103

**AC3: Configure K3s Workers with Tailscale**
**Given** Tailscale is running on k3s-worker-01 and k3s-worker-02
**When** I update K3s agent config on each worker
**Then** I add to `/etc/rancher/k3s/config.yaml`:
```yaml
flannel-iface: tailscale0
node-external-ip: <tailscale-100.x.x.b>  # Each worker's Tailscale IP
```
**And** I add NO_PROXY to `/etc/environment` (same as master)
**And** I restart K3s agent: `sudo systemctl restart k3s-agent`
**And** rolling restart: one node at a time, verify Ready before next

**AC4: Verify Cluster Connectivity**
**Given** all nodes restarted with Tailscale config
**When** I verify cluster status
**Then** `kubectl get nodes -o wide` shows all nodes with Tailscale IPs (100.x.x.*)
**And** pods can communicate across nodes (test with busybox ping)
**And** this validates NFR55, NFR56

**AC5: Join Intel NUC GPU Worker**
**Given** Intel NUC has Tailscale running (from Story 12.1)
**When** I install K3s agent on Intel NUC
**Then** I run:
```bash
TAILSCALE_IP=$(tailscale ip -4)
curl -sfL https://get.k3s.io | K3S_URL=https://<master-tailscale-ip>:6443 \
  K3S_TOKEN=<cluster-token> sh -s - agent \
  --flannel-iface tailscale0 \
  --node-external-ip=$TAILSCALE_IP
```
**And** node joins: `kubectl get nodes` shows `k3s-gpu-worker` as Ready
**And** this validates FR71 (GPU worker joins via Tailscale mesh)

**AC6: Apply GPU Labels and Taints**
**Given** k3s-gpu-worker has joined
**When** I apply labels and taints
**Then** I run:
```bash
kubectl label nodes k3s-gpu-worker gpu=nvidia
kubectl taint nodes k3s-gpu-worker nvidia.com/gpu=present:NoSchedule
```
**And** `kubectl describe node k3s-gpu-worker` shows labels and taints applied

**Story Points:** 8

---

#### Story 12.3: Install NVIDIA Container Toolkit and GPU Operator

**As a** platform engineer
**I want** NVIDIA Container Toolkit and GPU Operator deployed
**So that** Kubernetes can schedule GPU workloads with proper runtime support

**Acceptance Criteria:**

**Given** NUC is joined to cluster
**When** I install NVIDIA Container Toolkit on NUC
**Then** I run:
```bash
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | \
  sudo tee /etc/apt/sources.list.d/nvidia-docker.list
sudo apt update && sudo apt install -y nvidia-container-toolkit
sudo systemctl restart k3s-agent
```

**Given** container toolkit is installed
**When** I deploy NVIDIA GPU Operator via Helm
**Then** I run:
```bash
helm repo add nvidia https://helm.ngc.nvidia.com/nvidia && helm repo update
helm upgrade --install gpu-operator nvidia/gpu-operator \
  -n gpu-operator --create-namespace \
  --set driver.enabled=false \
  --set toolkit.enabled=true
```
**And** operator pods are running: `kubectl get pods -n gpu-operator`

**Given** GPU Operator is deployed
**When** I create RuntimeClass for GPU workloads
**Then** I apply:
```yaml
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: nvidia
handler: nvidia
```

**Given** RuntimeClass is created
**When** I verify GPU visibility
**Then** `kubectl describe node k3s-gpu-worker | grep nvidia.com/gpu` shows: `nvidia.com/gpu: 1`
**And** this validates FR39, NFR37 (GPU resources available, automatic driver setup)

**Story Points:** 8

---

#### Story 12.4: Deploy vLLM with 3-Model Configuration

**As a** ML engineer
**I want** vLLM deployed serving DeepSeek-Coder 6.7B, Mistral 7B, and Llama 3.1 8B
**So that** AI workflows can access GPU-accelerated inference via API

**Acceptance Criteria:**

**Given** GPU Operator is operational
**When** I deploy vLLM in `ml` namespace
**Then** the Deployment manifest includes:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vllm-server
  namespace: ml
spec:
  replicas: 1
  template:
    spec:
      runtimeClassName: nvidia
      nodeSelector:
        gpu: nvidia
      tolerations:
      - key: nvidia.com/gpu
        operator: Exists
        effect: NoSchedule
      containers:
      - name: vllm
        image: vllm/vllm-openai:latest
        args:
        - --model
        - deepseek-ai/deepseek-coder-6.7b-instruct
        - --gpu-memory-utilization
        - "0.9"
        resources:
          limits:
            nvidia.com/gpu: 1
```

**Given** vLLM is deployed
**When** I create Service and IngressRoute
**Then** Service exposes port 8000
**And** IngressRoute configured:
```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: vllm-https
  namespace: ml
spec:
  entryPoints:
  - websecure
  routes:
  - match: Host(`vllm.home.jetzinger.com`)
    kind: Rule
    services:
    - name: vllm-api
      port: 8000
  tls:
    certResolver: letsencrypt
```

**Given** vLLM is accessible
**When** I test inference
**Then** `curl https://vllm.home.jetzinger.com/v1/models` returns model list
**And** inference response time <500ms for typical prompts
**And** this validates FR38, FR72, NFR38 (vLLM deployment, multi-model support)

**Story Points:** 13

---

#### Story 12.5: Configure Hot-Plug and Graceful Degradation

**As a** platform engineer
**I want** eGPU hot-plug support with automatic Ollama CPU fallback
**So that** AI workflows continue during GPU maintenance without manual intervention

**Acceptance Criteria:**

**Given** vLLM is deployed
**When** I create PodDisruptionBudget
**Then** the PDB allows graceful pod termination:
```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: vllm-pdb
  namespace: ml
spec:
  maxUnavailable: 1
  selector:
    matchLabels:
      app: vllm
```

**Given** Ollama is already deployed (Epic 6)
**When** I configure load balancing between vLLM and Ollama
**Then** Service selector matches both backends
**And** traffic routes to available inference backend

**Given** GPU node monitoring is configured
**When** I create PrometheusRule for GPU node down
**Then** alert triggers when GPU worker is unavailable for 2 minutes
**And** alert routes to ntfy.sh for mobile notification

**Given** I create eGPU disconnect procedure
**When** I document runbook in `docs/runbooks/egpu-hotplug.md`
**Then** runbook includes:
- Disconnect: `kubectl drain k3s-gpu-worker --ignore-daemonsets`, unplug eGPU
- Reconnect: Plug eGPU, verify `nvidia-smi`, `kubectl uncordon k3s-gpu-worker`

**Given** procedure is tested
**When** I disconnect eGPU
**Then** vLLM traffic fails over to Ollama CPU
**And** when I reconnect eGPU
**Then** vLLM resumes GPU inference
**And** this validates FR73, FR74 (graceful degradation, hot-plug capability)

**Story Points:** 8

---

#### Story 12.6: GPU Metrics and Performance Validation

**As a** platform engineer
**I want** GPU metrics exported to Prometheus with Grafana dashboards
**So that** GPU utilization and inference performance can be monitored

**Acceptance Criteria:**

**Given** GPU Operator is deployed
**When** I enable DCGM Exporter
**Then** I run:
```bash
helm upgrade gpu-operator nvidia/gpu-operator \
  -n gpu-operator \
  --set dcgmExporter.enabled=true
```
**And** `kubectl get pods -n gpu-operator | grep dcgm` shows exporter running

**Given** DCGM Exporter is running
**When** I create ServiceMonitor for Prometheus
**Then** the ServiceMonitor scrapes DCGM metrics every 30s
**And** Prometheus targets show `dcgm-exporter` as UP

**Given** metrics are scraped
**When** I import NVIDIA DCGM Exporter Dashboard (Grafana ID: 12239)
**Then** dashboard shows:
- GPU utilization (%)
- GPU memory usage (MB/12288MB)
- GPU temperature (°C)
- Power consumption (W)
- SM clock speed (MHz)

**Given** dashboard is configured
**When** I perform performance validation
**Then** I verify:
- **NFR34**: GPU utilization >80% during concurrent inference requests
- **NFR35**: 50+ tokens/second for Mistral 7B and Llama 3.1 8B
- **NFR36**: GPU worker joins cluster within 2 minutes of boot
- Inference latency <500ms for typical requests (128 token output)

**Given** validation is complete
**When** I capture screenshots
**Then** GPU metrics screenshots saved to `docs/screenshots/gpu-metrics.png`
**And** dashboard is accessible at `grafana.home.jetzinger.com`

**Story Points:** 8

---

#### Story 12.7: Deploy Paperless-AI with GPU Ollama Integration

**As a** user
**I want** Paperless-ngx documents auto-classified using GPU-accelerated LLM inference
**So that** tags, correspondents, and document types are automatically populated from content

**Acceptance Criteria:**

**Given** GPU worker (Intel NUC + RTX 3060) is running Ollama
**When** I verify Ollama GPU availability
**Then** `kubectl get pods -n ml -l app=ollama` shows running pod on GPU worker
**And** `ollama list` shows llama3.2:1b or larger model loaded
**And** GPU is utilized for inference (NVIDIA SMI shows memory usage)

**Given** Ollama is GPU-accelerated
**When** I deploy Paperless-AI connector
**Then** the following resources are created:
- Deployment: `paperless-ai` (1 replica, image: `douaberigoale/paperless-metadata-ollama-processor`)
- ConfigMap: `paperless-ai-config` (connection settings)
- Secret: `paperless-ai-secrets` (Paperless API token)

**Given** Paperless-AI is deployed
**When** I configure environment variables
**Then** configuration includes:
```yaml
env:
  PAPERLESS_URL: "http://paperless-ngx.docs.svc.cluster.local:8000"
  PAPERLESS_API_TOKEN: "<api-token>"
  OLLAMA_URL: "http://ollama.ml.svc.cluster.local:11434"
  OLLAMA_MODEL: "llama3.2:1b"
  PROCESS_PREDEFINED_DOCUMENTS: "true"
  ADD_AI_PROCESSED_TAG: "true"
```
**And** this validates FR87 (Paperless-AI connects to GPU Ollama)

**Given** Paperless-AI is connected
**When** I upload a new document to Paperless-ngx
**Then** document content is sent to Ollama for classification
**And** inference uses GPU acceleration (NFR42: 50+ tokens/sec)
**And** classification completes within 10 seconds (NFR43)
**And** this validates FR88 (LLM-based auto-tagging)

**Given** AI classification is working
**When** I check document metadata after processing
**Then** tags are auto-populated based on document content
**And** correspondent is identified from letterhead/sender
**And** document type is classified (invoice, contract, statement, etc.)
**And** `ai-processed` tag is added to document
**And** this validates FR89 (auto-populate correspondents and types)

**Given** processing pipeline is validated
**When** I monitor GPU metrics during document processing
**Then** Grafana dashboard shows GPU utilization spikes during inference
**And** processing throughput meets NFR42 (50+ tokens/second)
**And** per-document latency meets NFR43 (<10 seconds)

**Implementation Notes:**
- Paperless-AI: `douaberigoale/paperless-metadata-ollama-processor` Docker image
- Ollama must be running on GPU worker for acceptable performance
- Model: llama3.2:1b for balance of speed and accuracy
- API token generated in Paperless-ngx admin UI
- Processor polls for new documents or uses webhook

**Story Points:** 5

---

#### Story 12.8: Upgrade Ollama Model to llama3.1:8b

**As a** user
**I want** Paperless-AI to use llama3.1:8b instead of llama3.2:1b
**So that** document classification is more reliable with consistent JSON output

**Acceptance Criteria:**

**Given** Ollama is running
**When** I pull the llama3.1:8b model
**Then** `ollama list` shows llama3.1:8b available
**And** model size is approximately 4.7GB

**Given** llama3.1:8b is available
**When** I update Paperless-AI ConfigMap
**Then** `OLLAMA_MODEL_NAME` is set to `llama3.1:8b`
**And** Paperless-AI pod is restarted with new configuration

**Given** Paperless-AI uses llama3.1:8b
**When** I process a test document
**Then** classification returns valid JSON response
**And** no "Extracted content is not valid JSON" errors occur
**And** title, tags, correspondent are correctly extracted

**Implementation Notes:**
- llama3.2:1b (1.3GB) struggles with JSON formatting
- llama3.1:8b (4.7GB) has much better instruction following
- May need to increase Ollama memory limits for 8b model
- CPU inference will be slower but more reliable

**Story Points:** 2

---

#### Story 12.9: Migrate to clusterzx/paperless-ai

**As a** user
**I want** to migrate from douaberigoale/paperless-metadata-ollama-processor to clusterzx/paperless-ai
**So that** I get better features including web UI configuration, RAG-based document chat, and active community support

**Acceptance Criteria:**

**Given** the current Paperless-AI is running
**When** I deploy clusterzx/paperless-ai
**Then** new deployment uses image `clusterzx/paperless-ai:latest`
**And** web UI is accessible for configuration
**And** RAG chat feature is available

**Given** clusterzx/paperless-ai is deployed
**When** I configure the integration via web UI
**Then** Paperless-ngx URL and API token are set
**And** Ollama URL and model are configured
**And** automatic document processing is enabled

**Given** documents are processed
**When** I ask questions about documents via chat interface
**Then** RAG retrieves relevant document context
**And** answers are based on actual document content

**Implementation Notes:**
- clusterzx/paperless-ai has 4,900+ GitHub stars vs 10 for current solution
- Features: Web UI, RAG chat, multi-model support, smart tagging rules
- Docker image: `clusterzx/paperless-ai:latest`
- Requires persistence for config and RAG index

**Story Points:** 5

---

#### Story 12.10: Configure vLLM GPU Integration for Paperless-AI

**As a** user
**I want** Paperless-AI to use vLLM on GPU instead of Ollama on CPU
**So that** document classification is fast (<5 seconds) with GPU-accelerated inference

**Acceptance Criteria:**

**AC1: Configure vLLM with qwen2.5:14b**
**Given** vLLM is deployed on k3s-gpu-worker
**When** I configure vLLM to serve qwen2.5:14b
**Then** model is pulled and loaded (~8-9GB VRAM)
**And** vLLM serves OpenAI-compatible API at `/v1/chat/completions`
**And** `curl http://vllm.ml.svc:8000/v1/models` returns qwen2.5:14b
**And** this validates FR109

**AC2: Reconfigure Paperless-AI to use vLLM**
**Given** vLLM is serving qwen2.5:14b
**When** I update Paperless-AI ConfigMap
**Then** `AI_PROVIDER` is set to `custom`
**And** `CUSTOM_BASE_URL` is set to `http://vllm.ml.svc.cluster.local:8000/v1`
**And** `LLM_MODEL` is set to `qwen2.5:14b`
**And** Paperless-AI pod is restarted with new configuration
**And** this validates FR110

**AC3: Validate GPU-accelerated Classification**
**Given** Paperless-AI uses vLLM
**When** I upload a test document tagged with "pre-process"
**Then** document is classified within 5 seconds (NFR63)
**And** title, tags, correspondent, document type are assigned correctly
**And** vLLM throughput is 35-40 tokens/second (NFR64)

**AC4: Downgrade Ollama to Slim Models**
**Given** Paperless-AI no longer uses Ollama
**When** I reconfigure Ollama on k3s-worker-02
**Then** qwen2.5:14b model is deleted: `ollama rm qwen2.5:14b`
**And** slim models are available: llama3.2:1b, qwen2.5:3b
**And** Ollama memory limit reduced to 4Gi
**And** this validates FR111

**AC5: Reduce k3s-worker-02 Resources**
**Given** Ollama uses slim models only
**When** I reduce k3s-worker-02 VM resources
**Then** RAM is reduced from 32GB to 8GB via Proxmox
**And** node restarts and rejoins cluster
**And** `kubectl describe node k3s-worker-02` shows ~8GB allocatable memory
**And** this validates FR112

**Implementation Notes:**
- vLLM uses OpenAI-compatible API format (not Ollama's `/api/generate`)
- clusterzx/paperless-ai supports `AI_PROVIDER=custom` for OpenAI-compatible endpoints
- OpenAI fallback (gpt-4o-mini) via n8n routing comes in Epic 13
- Ollama kept for experimentation with lightweight models

**Story Points:** 5

---

### Epic 13: Steam Gaming Platform (Dual-Use GPU)

**User Outcome:** Tom can use the Intel NUC + RTX 3060 for both Steam gaming (Windows games via Proton) AND ML inference (Ollama with Qwen 2.5 14B), switching between modes with a simple script that gracefully scales down K8s workloads when gaming and restores them afterward. The system boots into ML Mode by default.

**FRs Covered:** FR95-99, FR119
**NFRs Covered:** NFR51-54, NFR70

---

#### Story 13.1: Install Steam and Proton on Intel NUC

**As a** gamer
**I want** Steam installed on the Intel NUC host with Proton enabled
**So that** I can play Windows games using the RTX 3060 eGPU

**Acceptance Criteria:**

**Given** Intel NUC is running Ubuntu 22.04 with RTX 3060 eGPU configured
**When** I install Steam from the official repository
**Then** `sudo apt install steam` completes successfully
**And** Steam client launches and authenticates
**And** this validates FR95 (Steam on host Ubuntu OS)

**Given** Steam is installed
**When** I enable Steam Play for all titles
**Then** Settings → Steam Play → "Enable Steam Play for all other titles" is checked
**And** Proton version is set (Proton Experimental or Proton 9.0+)
**And** this validates FR96 (Proton for Windows game compatibility)

**Given** Proton is enabled
**When** I download and launch a Windows game
**Then** game launches using Proton compatibility layer
**And** game renders on RTX 3060 eGPU
**And** `nvidia-smi` shows game process using GPU memory

**Given** Steam gaming is working
**When** I configure `nvidia-drm.modeset=1` for PRIME support
**Then** `/etc/modprobe.d/nvidia-drm.conf` contains `options nvidia-drm modeset=1`
**And** after reboot, GPU is available for both Steam and K8s workloads

**Implementation Notes:**
- Steam runs on host OS (not containerized) - graphics workloads need direct GPU access
- Proton uses WINE + DXVK for DirectX translation
- `nvidia-drm.modeset=1` required for proper eGPU support
- Test with a known Proton-compatible game (e.g., Hades, Stardew Valley)

**Story Points:** 3

---

#### Story 13.2: Configure Mode Switching Script

**As a** platform operator
**I want** a script to switch between Gaming Mode and ML Mode
**So that** I can easily transition the GPU between gaming and K8s ML workloads

**Acceptance Criteria:**

**Given** Intel NUC has both Steam and K3s agent installed
**When** I create `/usr/local/bin/gpu-mode` script
**Then** script accepts `gaming` or `ml` argument
**And** script is executable: `chmod +x /usr/local/bin/gpu-mode`
**And** this validates FR97 (mode switching script)

**Given** script is created
**When** I run `gpu-mode gaming`
**Then** script executes: `kubectl scale deployment/vllm --replicas=0 -n ml`
**And** vLLM pods terminate and release GPU memory
**And** script outputs: "Gaming Mode: vLLM scaled to 0, GPU available for Steam"
**And** completion time is <30 seconds (NFR51)
**And** this validates FR98 (Gaming Mode)

**Given** Gaming Mode is active
**When** I run `gpu-mode ml`
**Then** script executes: `kubectl scale deployment/vllm --replicas=1 -n ml`
**And** vLLM pod starts and loads models
**And** script outputs: "ML Mode: vLLM restored, GPU dedicated to inference"
**And** completion time is <2 minutes (NFR52)
**And** this validates FR99 (ML Mode restoration)

**Given** mode switching works
**When** I verify GPU availability after switching
**Then** `nvidia-smi` shows expected GPU usage:
- Gaming Mode: GPU available (0% VRAM from K8s)
- ML Mode: vLLM using ~10-11GB VRAM

**Implementation Notes:**
```bash
#!/bin/bash
# /usr/local/bin/gpu-mode
case "$1" in
  gaming)
    kubectl scale deployment/vllm --replicas=0 -n ml
    echo "Gaming Mode: vLLM scaled to 0, GPU available for Steam"
    ;;
  ml)
    kubectl scale deployment/vllm --replicas=1 -n ml
    echo "ML Mode: vLLM restored, GPU dedicated to inference"
    ;;
  *)
    echo "Usage: gpu-mode [gaming|ml]"
    exit 1
    ;;
esac
```

**Story Points:** 5

---

#### Story 13.3: Integrate n8n Fallback Routing

**As a** platform operator
**I want** n8n workflows to automatically route to Ollama CPU when GPU is unavailable
**So that** AI inference continues working (with degraded performance) during gaming

**Acceptance Criteria:**

**Given** n8n workflows use vLLM for inference
**When** I configure fallback detection
**Then** workflows check vLLM availability before sending requests
**And** timeout is set to 10 seconds (NFR50)

**Given** fallback detection is configured
**When** vLLM is unavailable (Gaming Mode)
**Then** workflows automatically route to Ollama CPU endpoint
**And** inference latency is <5 seconds (NFR54)
**And** user receives results (with potentially lower quality)

**Given** fallback routing works
**When** I monitor n8n during mode transitions
**Then** no workflow failures occur during Gaming Mode
**And** Grafana alerts show "GPU unavailable - using CPU fallback"

**Implementation Notes:**
- n8n workflow nodes: HTTP Request with error handling
- Primary: `http://vllm.ml.svc.cluster.local:8000/v1/completions`
- Fallback: `http://ollama.ml.svc.cluster.local:11434/api/generate`
- Health check endpoint for vLLM availability

**Story Points:** 3

---

#### Story 13.4: Validate Gaming Performance

**As a** gamer
**I want** Steam games to achieve 60+ FPS at 1080p
**So that** the gaming experience is smooth with exclusive GPU access

**Acceptance Criteria:**

**Given** Gaming Mode is active (vLLM scaled to 0)
**When** I launch a graphics-intensive game
**Then** game renders at 60+ FPS at 1080p (NFR53)
**And** `nvidia-smi` shows full GPU availability
**And** no VRAM conflicts with K8s workloads

**Given** gaming is in progress
**When** I monitor system resources
**Then** GPU temperature stays within safe limits (<85°C)
**And** game runs smoothly without stuttering
**And** no K8s pods are competing for GPU resources

**Given** gaming session ends
**When** I switch back to ML Mode
**Then** `gpu-mode ml` restores vLLM within 2 minutes (NFR52)
**And** vLLM health check passes
**And** n8n workflows resume using GPU inference

**Given** performance is validated
**When** I document tested games
**Then** README includes list of validated games with settings:
- Game name, Proton version, resolution, FPS achieved
- Any required tweaks or compatibility notes

**Implementation Notes:**
- Test with a mix of game types (indie, AAA)
- Benchmark games: Hades, Civilization VI, or similar
- Document any Proton GE requirements for specific titles
- GPU: RTX 3060 12GB should handle most 1080p gaming comfortably

**Story Points:** 2

---

## Phase 4 Epic Details

### Epic 15: Network Access Enhancement (Tailscale Subnet Router)

**User Outcome:** Tom can access the full home network (192.168.0.0/24 and 192.168.2.0/24) from anywhere via Tailscale subnet routing.

**FRs Covered:** FR120-122
**NFRs Covered:** NFR71-72

---

#### Story 15.1: Configure k3s-master as Subnet Router

**As a** remote user,
**I want** k3s-master to advertise the 192.168.2.0/24 subnet to Tailscale,
**So that** I can access devices on that network segment from anywhere.

**Acceptance Criteria:**

**Given** k3s-master is running Tailscale for cluster networking
**When** I configure Tailscale to advertise routes
**Then** `tailscale up --advertise-routes=192.168.2.0/24` is added to startup
**And** subnet route appears in Tailscale admin console as pending

**Given** subnet route is advertised
**When** I approve the route in Tailscale admin console
**Then** route status changes to "approved"
**And** Tailscale clients can route to 192.168.2.0/24 via k3s-master
**And** this validates FR120

**Given** subnet routing is enabled
**When** k3s-master boots
**Then** subnet routes advertised within 60 seconds (NFR71)
**And** `tailscale status` shows route as active

**Tasks:**
- [ ] Update Tailscale startup flags on k3s-master
- [ ] Add `--advertise-routes=192.168.2.0/24` to tailscale up command
- [ ] Approve route in Tailscale admin console
- [ ] Test connectivity from remote Tailscale client to 192.168.2.x devices
- [ ] Document route approval process

**Story Points:** 2

---

#### Story 15.2: Configure k3s-gpu-worker as Subnet Router

**As a** remote user,
**I want** k3s-gpu-worker to advertise the 192.168.0.0/24 subnet to Tailscale,
**So that** I can access devices on the Intel NUC network segment from anywhere.

**Acceptance Criteria:**

**Given** k3s-gpu-worker is running Tailscale for cluster networking
**When** I configure Tailscale to advertise routes
**Then** `tailscale up --advertise-routes=192.168.0.0/24` is added to startup
**And** subnet route appears in Tailscale admin console as pending

**Given** subnet route is advertised
**When** I approve the route in Tailscale admin console
**Then** route status changes to "approved"
**And** Tailscale clients can route to 192.168.0.0/24 via k3s-gpu-worker
**And** this validates FR121

**Given** both subnet routers are configured
**When** one router goes down
**Then** direct Tailscale connections still work (NFR72)
**And** only the specific subnet loses routing (not entire network)

**Tasks:**
- [ ] Update Tailscale startup flags on k3s-gpu-worker
- [ ] Add `--advertise-routes=192.168.0.0/24` to tailscale up command
- [ ] Approve route in Tailscale admin console
- [ ] Test connectivity from remote client to 192.168.0.x devices
- [ ] Test failover behavior when one router is down

**Story Points:** 2

---

#### Story 15.3: Configure Tailscale ACLs for Subnet Access

**As a** security-conscious operator,
**I want** Tailscale ACLs configured to control subnet route access,
**So that** only authorized users can access the full home network.

**Acceptance Criteria:**

**Given** subnet routes are approved and working
**When** I configure Tailscale ACLs
**Then** ACL policy defines which users/groups can access subnet routes
**And** this validates FR122

**Given** ACLs are configured
**When** an authorized user connects via Tailscale
**Then** they can access both 192.168.0.0/24 and 192.168.2.0/24 subnets
**And** traffic routes through appropriate subnet router

**Given** ACLs restrict access
**When** an unauthorized Tailscale user attempts subnet access
**Then** connection is blocked by ACL policy
**And** only direct Tailscale device connections work

**Tasks:**
- [ ] Design ACL policy for subnet access (FR122)
- [ ] Update Tailscale ACL configuration via admin console
- [ ] Test authorized user access to both subnets
- [ ] Test unauthorized user is blocked from subnets
- [ ] Document ACL policy in repository

**Story Points:** 2

---

### Epic 16: NAS Worker Node (Synology DS920+)

**User Outcome:** Tom has a lightweight K3s worker node running on the Synology NAS for storage-adjacent workloads.

**FRs Covered:** FR123-125
**NFRs Covered:** NFR73-74

---

#### Story 16.1: Deploy K3s Worker VM on Synology NAS

**As a** cluster operator,
**I want** a K3s worker VM running on the Synology DS920+ NAS,
**So that** I can run storage-adjacent workloads close to the data.

**Acceptance Criteria:**

**Given** Synology DS920+ has Virtual Machine Manager installed
**When** I create a new VM for K3s worker
**Then** VM is allocated 2 vCPU and 4GB RAM (NFR73)
**And** VM uses Debian or Ubuntu minimal image
**And** this validates FR123

**Given** VM is created
**When** I install K3s agent on the VM
**Then** agent connects to k3s-master control plane
**And** node appears in `kubectl get nodes`
**And** node joins within 3 minutes of VM boot (NFR74)

**Given** K3s agent is running
**When** I configure Tailscale on the NAS worker
**Then** node is accessible via Tailscale mesh
**And** cluster networking works across subnets

**Tasks:**
- [ ] Create VM in Synology VMM with 2 vCPU, 4GB RAM (NFR73)
- [ ] Install minimal Debian/Ubuntu on VM
- [ ] Install Tailscale on VM and join tailnet
- [ ] Install K3s agent connecting to k3s-master
- [ ] Verify node joins cluster within 3 minutes (NFR74)
- [ ] Document VM configuration and setup steps

**Story Points:** 3

---

#### Story 16.2: Label and Taint NAS Worker Node

**As a** cluster operator,
**I want** the NAS worker node labeled and tainted for specific workloads,
**So that** general workloads don't accidentally schedule there and impact NAS performance.

**Acceptance Criteria:**

**Given** NAS worker node has joined the cluster
**When** I apply labels for workload targeting
**Then** node has label `node-type=nas-worker`
**And** node has label `workload-class=lightweight`
**And** this validates FR124

**Given** node is labeled
**When** I apply taint to prevent general scheduling
**Then** node has taint `workload-class=nas-only:NoSchedule`
**And** general pods without toleration won't schedule here
**And** this validates FR125

**Given** taint is applied
**When** I deploy a pod without toleration
**Then** pod does NOT schedule on NAS worker
**And** pod schedules on other available workers

**Given** taint is applied
**When** I deploy a pod WITH toleration for `nas-only`
**Then** pod CAN schedule on NAS worker
**And** node selector `node-type=nas-worker` targets it specifically

**Tasks:**
- [ ] Apply labels: `node-type=nas-worker`, `workload-class=lightweight` (FR124)
- [ ] Apply taint: `workload-class=nas-only:NoSchedule` (FR125)
- [ ] Test that general pods don't schedule on NAS worker
- [ ] Create example pod spec with toleration for NAS worker
- [ ] Document node labels and taints in repository

**Story Points:** 2

---

### Epic 17: ChatGPT-like Interface (Open-WebUI)

**User Outcome:** Tom has a polished ChatGPT-like web interface for all LLM models through LiteLLM.

**FRs Covered:** FR126-129
**NFRs Covered:** NFR75-76

---

#### Story 17.1: Deploy Open-WebUI with Persistent Storage

**As a** home-lab user,
**I want** Open-WebUI deployed with persistent chat history,
**So that** I have a ChatGPT-like interface for my self-hosted models.

**Acceptance Criteria:**

**Given** the `apps` namespace exists
**When** I deploy Open-WebUI via Helm or manifests
**Then** Open-WebUI pod starts successfully
**And** PVC is created for chat history on NFS storage
**And** this validates FR126

**Given** Open-WebUI is deployed
**When** I access the web interface
**Then** interface loads within 3 seconds (NFR75)
**And** login/registration page is displayed

**Given** chat history is stored
**When** pod restarts
**Then** chat history is preserved (NFR76)
**And** previous conversations are accessible

**Tasks:**
- [ ] Create PVC for Open-WebUI data on NFS storage
- [ ] Deploy Open-WebUI in `apps` namespace (FR126)
- [ ] Configure persistent volume mount for `/app/backend/data`
- [ ] Test pod restart preserves chat history (NFR76)
- [ ] Measure page load time (<3 seconds, NFR75)

**Story Points:** 3

---

#### Story 17.2: Configure Open-WebUI with LiteLLM Backend

**As a** home-lab user,
**I want** Open-WebUI connected to LiteLLM for unified model access,
**So that** I can use all configured models (local and external) through one interface.

**Acceptance Criteria:**

**Given** Open-WebUI is deployed
**When** I configure the OpenAI API endpoint
**Then** endpoint points to LiteLLM service (`http://litellm.ml.svc.cluster.local:4000/v1`)
**And** this validates FR127

**Given** LiteLLM backend is configured
**When** I open the model selector in Open-WebUI
**Then** all LiteLLM models are available:
- `default` (fallback chain)
- `groq/llama-3.3-70b-versatile`
- `gemini/gemini-1.5-flash`
- `mistral/mistral-small-latest`
**And** this validates FR129

**Given** models are available
**When** I switch between models in a conversation
**Then** responses come from the selected model
**And** model switching works seamlessly

**Tasks:**
- [ ] Configure OPENAI_API_BASE to point to LiteLLM (FR127)
- [ ] Configure OPENAI_API_KEY (can be dummy for LiteLLM)
- [ ] Verify all LiteLLM models appear in Open-WebUI (FR129)
- [ ] Test chat with each model type
- [ ] Document model switching functionality

**Story Points:** 2

---

#### Story 17.3: Configure Open-WebUI Ingress

**As a** home-lab user,
**I want** Open-WebUI accessible via HTTPS ingress,
**So that** I can access it from any device on my network.

**Acceptance Criteria:**

**Given** Open-WebUI is deployed and working
**When** I create ingress resource
**Then** ingress routes `chat.home.jetzinger.com` to Open-WebUI service
**And** TLS certificate is provisioned via cert-manager
**And** this validates FR128

**Given** ingress is configured
**When** I access `https://chat.home.jetzinger.com`
**Then** Open-WebUI interface loads with valid HTTPS
**And** interface is accessible from any Tailscale-connected device

**Tasks:**
- [ ] Create ingress for `chat.home.jetzinger.com` (FR128)
- [ ] Configure TLS with cert-manager annotation
- [ ] Verify HTTPS access works
- [ ] Test from multiple devices (phone, laptop)
- [ ] Add DNS entry if not using wildcard

**Story Points:** 2

---

### Epic 18: Cluster Visualization Dashboard

**User Outcome:** Tom can visualize cluster resources via Kubernetes Dashboard.

**FRs Covered:** FR130-133
**NFRs Covered:** NFR77-78

---

#### Story 18.1: Deploy Kubernetes Dashboard

**As a** cluster operator,
**I want** Kubernetes Dashboard deployed for cluster visualization,
**So that** I can view cluster resources through a web interface.

**Acceptance Criteria:**

**Given** the `infra` namespace exists
**When** I deploy Kubernetes Dashboard via Helm
**Then** dashboard pods start successfully
**And** dashboard service is created
**And** this validates FR130

**Given** dashboard is deployed
**When** I access the dashboard
**Then** cluster overview loads within 5 seconds (NFR77)
**And** all namespaces, pods, and resources are visible (FR133)

**Tasks:**
- [ ] Deploy Kubernetes Dashboard Helm chart in `infra` namespace (FR130)
- [ ] Configure dashboard for read-only access (FR133)
- [ ] Verify dashboard loads within 5 seconds (NFR77)
- [ ] Test visibility of all cluster resources

**Story Points:** 2

---

#### Story 18.2: Configure Dashboard Ingress and Authentication

**As a** cluster operator,
**I want** Dashboard accessible via HTTPS with authentication,
**So that** I can securely access it from any Tailscale device.

**Acceptance Criteria:**

**Given** Kubernetes Dashboard is deployed
**When** I create ingress resource
**Then** ingress routes `dashboard.home.jetzinger.com` to dashboard service
**And** TLS certificate is provisioned via cert-manager
**And** this validates FR131

**Given** ingress is configured
**When** I configure authentication
**Then** dashboard requires bearer token or Tailscale identity (FR132)
**And** access is restricted to Tailscale network only (NFR78)

**Given** authentication is configured
**When** I access from outside Tailscale network
**Then** access is denied
**And** only Tailscale-connected devices can reach dashboard

**Tasks:**
- [ ] Create ingress for `dashboard.home.jetzinger.com` (FR131)
- [ ] Configure TLS with cert-manager
- [ ] Set up bearer token authentication (FR132)
- [ ] Restrict ingress to Tailscale IP ranges (NFR78)
- [ ] Create ServiceAccount and token for dashboard access
- [ ] Document authentication process

**Story Points:** 3

---

### Epic 19: Self-Hosted Git Service (Gitea)

**User Outcome:** Tom can host private Git repositories locally with Gitea.

**FRs Covered:** FR134-137
**NFRs Covered:** NFR79-80

---

#### Story 19.1: Deploy Gitea with PostgreSQL Backend

**As a** developer,
**I want** Gitea deployed with PostgreSQL for metadata storage,
**So that** I have a reliable self-hosted Git service.

**Acceptance Criteria:**

**Given** the `dev` namespace exists and PostgreSQL is available
**When** I deploy Gitea via Helm chart
**Then** Gitea pod starts successfully
**And** Gitea connects to existing PostgreSQL instance
**And** this validates FR134

**Given** Gitea is deployed
**When** I access the web interface
**Then** interface loads within 3 seconds (NFR80)
**And** initial setup wizard is displayed

**Given** Gitea uses PostgreSQL
**When** I check database connections
**Then** Gitea database exists in PostgreSQL
**And** metadata is stored persistently

**Tasks:**
- [ ] Create Gitea database in existing PostgreSQL
- [ ] Deploy Gitea Helm chart in `dev` namespace (FR134)
- [ ] Configure PostgreSQL connection in Gitea values
- [ ] Verify web interface loads within 3 seconds (NFR80)
- [ ] Complete initial setup wizard

**Story Points:** 3

---

#### Story 19.2: Configure Gitea Storage and Ingress

**As a** developer,
**I want** Gitea repositories persisted to NFS and accessible via HTTPS,
**So that** my code is safely stored and accessible from anywhere.

**Acceptance Criteria:**

**Given** Gitea is deployed
**When** I configure persistent storage
**Then** repositories are stored on NFS volume
**And** data survives pod restarts
**And** this validates FR136

**Given** storage is configured
**When** I create ingress resource
**Then** ingress routes `git.home.jetzinger.com` to Gitea service
**And** TLS certificate is provisioned via cert-manager
**And** this validates FR135

**Given** ingress is configured
**When** I access `https://git.home.jetzinger.com`
**Then** Gitea interface loads with valid HTTPS
**And** repository operations work via HTTPS

**Tasks:**
- [ ] Create PVC for Gitea data on NFS storage (FR136)
- [ ] Configure volume mounts for `/data`
- [ ] Create ingress for `git.home.jetzinger.com` (FR135)
- [ ] Configure TLS with cert-manager
- [ ] Test repository creation and cloning via HTTPS

**Story Points:** 2

---

#### Story 19.3: Configure Gitea Single-User SSH Access

**As a** developer,
**I want** Gitea configured for single-user operation with SSH,
**So that** I can push/pull repositories via SSH keys.

**Acceptance Criteria:**

**Given** Gitea is deployed and accessible
**When** I configure single-user mode
**Then** registration is disabled after initial user creation
**And** only the primary user can create repositories
**And** this validates FR137

**Given** single-user mode is configured
**When** I add my SSH public key to Gitea
**Then** key is stored in user profile
**And** SSH authentication works for git operations

**Given** SSH is configured
**When** I clone a repository via SSH
**Then** `git clone git@git.home.jetzinger.com:user/repo.git` works
**And** clone completes within 10 seconds for typical repos (NFR79)

**Tasks:**
- [ ] Configure Gitea for single-user operation (FR137)
- [ ] Disable public registration after admin user creation
- [ ] Add SSH public key to admin user profile
- [ ] Configure SSH service (NodePort or Tailscale)
- [ ] Test git clone/push/pull via SSH (NFR79)
- [ ] Document SSH setup process

**Story Points:** 2

---

### Epic 20: Reasoning Model Support (DeepSeek-R1 14B)

**User Outcome:** Tom can use reasoning-focused AI models via R1-Mode on the GPU worker.

**FRs Covered:** FR138-141
**NFRs Covered:** NFR81-82

---

#### Story 20.1: Deploy DeepSeek-R1 14B via vLLM

**As a** ML platform operator,
**I want** DeepSeek-R1 14B deployed via vLLM,
**So that** I can use reasoning-focused models for complex tasks.

**Acceptance Criteria:**

**Given** vLLM is deployed on k3s-gpu-worker
**When** I configure vLLM with DeepSeek-R1 14B model
**Then** model loads successfully on RTX 3060 (12GB VRAM)
**And** model loading completes within 90 seconds (NFR81)
**And** this validates FR138

**Given** DeepSeek-R1 is loaded
**When** I send a reasoning request
**Then** model generates chain-of-thought response
**And** throughput achieves 30+ tokens/second (NFR82)

**Given** model is serving
**When** I check VRAM usage
**Then** model fits within 12GB VRAM budget
**And** no OOM errors occur during inference

**Tasks:**
- [ ] Download DeepSeek-R1 14B model (AWQ quantized)
- [ ] Configure vLLM deployment for DeepSeek-R1 (FR138)
- [ ] Test model loading time (<90 seconds, NFR81)
- [ ] Benchmark inference speed (>30 tok/s, NFR82)
- [ ] Document model configuration

**Story Points:** 3

---

#### Story 20.2: Implement R1-Mode in GPU Mode Script

**As a** platform operator,
**I want** R1-Mode added to the gpu-mode script,
**So that** I can switch between Qwen 2.5, DeepSeek-R1, and Gaming modes.

**Acceptance Criteria:**

**Given** gpu-mode script supports ML-Mode and Gaming-Mode
**When** I add R1-Mode support
**Then** `gpu-mode r1` switches vLLM to DeepSeek-R1 model
**And** `gpu-mode ml` switches back to Qwen 2.5 14B
**And** this validates FR139 and FR140

**Given** R1-Mode is implemented
**When** I run `gpu-mode r1`
**Then** vLLM deployment is updated with DeepSeek-R1 model
**And** pod restarts with new model
**And** model is ready within 90 seconds (NFR81)

**Given** mode switching works
**When** I check available modes
**Then** `gpu-mode status` shows current mode
**And** three modes are available: ml, r1, gaming

**Tasks:**
- [ ] Update gpu-mode script to support `r1` argument (FR139, FR140)
- [ ] Implement model switching via ConfigMap or deployment patch
- [ ] Add `gpu-mode status` command to show current mode
- [ ] Test ml → r1 → gaming → ml transitions
- [ ] Document R1-Mode usage

**Story Points:** 3

---

#### Story 20.3: Configure LiteLLM with DeepSeek-R1

**As a** application developer,
**I want** DeepSeek-R1 accessible via LiteLLM,
**So that** applications can request reasoning-focused inference.

**Acceptance Criteria:**

**Given** DeepSeek-R1 is deployed via vLLM
**When** I add it to LiteLLM configuration
**Then** `deepseek-r1` model is available in LiteLLM
**And** this validates FR141

**Given** LiteLLM is configured
**When** I request `deepseek-r1` model via API
**Then** request routes to vLLM with DeepSeek-R1 (when in R1-Mode)
**And** response includes reasoning chain

**Given** mode is not R1-Mode
**When** I request `deepseek-r1` model
**Then** request fails gracefully with clear error
**And** application can fallback to `default` model

**Tasks:**
- [ ] Add DeepSeek-R1 model definition to LiteLLM config (FR141)
- [ ] Configure model to route to vLLM endpoint
- [ ] Test inference via LiteLLM API
- [ ] Handle mode mismatch errors gracefully
- [ ] Document model availability and mode requirements

**Story Points:** 2

---

## Phase 1 Epic Details (Completed)

### Epic 1: Foundation - K3s Cluster with Remote Access

Tom has a working multi-node K3s cluster he can access from anywhere via Tailscale.

---

## Summary

| Epic | Title | Stories | FRs Covered | NFRs Covered |
|------|-------|---------|-------------|--------------|
| 1 | Foundation - K3s Cluster | 5 | FR1-6 | - |
| 2 | Storage & Persistence | 4 | FR14-18 | NFR4, NFR16 |
| 3 | Ingress, TLS & Service Exposure | 5 | FR9-10, FR19-23 | NFR7, NFR17 |
| 4 | Observability Stack | 6 | FR7, FR11, FR24-30 | NFR5, NFR14, NFR18 |
| 5 | PostgreSQL Database Service | 5 | FR8, FR31-35 | NFR20 |
| 6 | AI Inference Platform | 4 | FR12-13, FR36-37, FR40 | NFR13 |
| 7 | Development Proxy | 3 | FR41-43 | - |
| 8 | Cluster Operations & Maintenance | 5 | FR44-48 | NFR2, NFR11, NFR20, NFR22 |
| 9 | Portfolio & Public Showcase | 6 | FR49-54, FR146-148 | NFR24-27, NFR85 |
| **Phase 1 Total** | | **43 stories** | **57 FRs** | **20 NFRs** |
| | | | | |
| 10 | Document Management System (Paperless-ngx Ecosystem) | 11 | FR55-58, FR64-66, FR75-86, FR90-93 | NFR28-30, NFR39-41 |
| 11 | Dev Containers Platform | 6 | FR59-63, FR67-70 | NFR31-33 |
| 12 | GPU/ML Inference Platform (vLLM + Qwen 2.5 14B) | 10 | FR38-39, FR71-74, FR87-89, FR94, FR100-112 | NFR34-38, NFR50, NFR55-64 |
| **Phase 2 Total** | | **27 stories** | **49 FRs** | **27 NFRs** |
| | | | | |
| 13 | Steam Gaming Platform (Dual-Use GPU) | 4 | FR95-99, FR119 | NFR51-54, NFR70 |
| 14 | LiteLLM Inference Proxy | 6 | FR113-118, FR142-145 | NFR65-69, NFR83-84 |
| **Phase 3 Total** | | **10 stories** | **16 FRs** | **12 NFRs** |
| | | | | |
| 15 | Network Access Enhancement (Tailscale Subnet Router) | 3 | FR120-122 | NFR71-72 |
| 16 | NAS Worker Node (Synology DS920+) | 2 | FR123-125 | NFR73-74 |
| 17 | ChatGPT-like Interface (Open-WebUI) | 3 | FR126-129 | NFR75-76 |
| 18 | Cluster Visualization Dashboard | 2 | FR130-133 | NFR77-78 |
| 19 | Self-Hosted Git Service (Gitea) | 3 | FR134-137 | NFR79-80 |
| 20 | Reasoning Model Support (DeepSeek-R1 14B) | 3 | FR138-141 | NFR81-82 |
| **Phase 4 Total** | | **16 stories** | **22 FRs** | **12 NFRs** |
| | | | | |
| **Phase 5** | **OpenClaw Personal AI Assistant** | | | |
| 21 | OpenClaw Core Gateway & Telegram Channel | 5 | FR149-159, FR162-163, FR189-191 | NFR86-88, NFR91-96, NFR99-102, NFR105-106 |
| 22 | OpenClaw Research Tools & Multi-Channel | 4 | FR160-161, FR164-168 | NFR89, NFR97-98 |
| 23 | OpenClaw Advanced Capabilities | 5 | FR169-180 | NFR90 |
| 24 | OpenClaw Observability & Documentation | 3 | FR181-188 | NFR103-104 |
| **Phase 5 Total** | | **17 stories** | **43 FRs** | **21 NFRs** |
| | | | | |
| **Grand Total** | | **113 stories** | **191 FRs** | **106 NFRs** |

**Phase 1 Status:** ✅ Completed (Epics 1-9)
**Phase 2 Status:** ✅ Completed (Epics 10-12)
**Phase 3 Status:** ✅ Ready for Implementation (Epic 13-14 - Steam Gaming with mode switching + LiteLLM Inference Proxy)
**Phase 4 Status:** 📋 Stories Created (Epics 15-20 - Network, NAS Worker, Open-WebUI, Dashboard, Gitea, DeepSeek-R1)
**Phase 5 Status:** 📋 Stories Created (Epics 21-24 - OpenClaw Personal AI Assistant)

---

### Epic 21: OpenClaw Core Gateway & Telegram Channel

**User Outcome:** Tom has a personal AI assistant running on his K3s cluster, accessible via Telegram, powered by Claude Opus 4.5 with automatic LiteLLM fallback, secured with allowlist-only DM pairing, with long-term memory that learns across conversations.

**FRs Covered:** FR149-159, FR162-163, FR189-191
**NFRs Covered:** NFR86-88, NFR91-96, NFR99-102, NFR105-106

---

#### Story 21.1: Deploy OpenClaw Gateway with Local Persistent Storage

As a **cluster operator**,
I want **to deploy the OpenClaw gateway container on K3s with local persistent storage on k3s-worker-01 for configuration and workspace data**,
So that **my AI assistant infrastructure is running and survives pod restarts without losing state**.

**Acceptance Criteria:**

**Given** the `apps` namespace exists and local-path storage provisioner is available
**When** I apply the OpenClaw Deployment (with node affinity to k3s-worker-01), Service, PVC, and Secret manifests
**Then** the OpenClaw pod starts successfully on k3s-worker-01 with the official `openclaw/openclaw` image (FR152a)
**And** a 10Gi local PVC (local-path storage class) is bound and mounted at `~/.clawdbot` (config) and `~/clawd/` (workspace) via subPath
**And** the K8s Secret `openclaw-secrets` is created with placeholder values for all 8 credential types (Anthropic OAuth, Telegram, WhatsApp, Discord, ElevenLabs, Exa, LiteLLM fallback URL, gateway auth token)
**And** the `openclaw.json` configuration file persists on local storage at `~/.clawdbot/openclaw.json`
**And** Velero cluster backups include the OpenClaw PVC for disaster recovery (FR152b)

**Given** the OpenClaw pod is running on k3s-worker-01
**When** the pod is deleted or k3s-worker-01 reboots
**Then** the replacement pod starts on k3s-worker-01 with all configuration and workspace data intact from local storage (NFR100)
**And** no manual re-configuration is required

**FRs covered:** FR149, FR151, FR152, FR152a, FR152b
**NFRs covered:** NFR91, NFR100

---

#### Story 21.2: Configure Traefik Ingress & Control UI

As a **cluster operator**,
I want **to access the OpenClaw gateway control UI via `openclaw.home.jetzinger.com` over HTTPS**,
So that **I can view gateway health, manage configuration, and restart the gateway from my browser**.

**Acceptance Criteria:**

**Given** the OpenClaw gateway pod and ClusterIP service are running (Story 21.1)
**When** I apply the Traefik IngressRoute for `openclaw.home.jetzinger.com`
**Then** the gateway control UI is accessible at `https://openclaw.home.jetzinger.com` with valid TLS certificate
**And** the UI loads within 3 seconds (NFR87)
**And** the UI is only accessible via Tailscale mesh (NFR93)

**Given** the control UI is loaded
**When** I view the gateway status page
**Then** I can see gateway health, uptime, and connection status (FR153)

**Given** the control UI is loaded
**When** I trigger a gateway restart via the UI
**Then** the gateway process restarts cleanly and reconnects all services (FR154)
**And** persistent state is preserved on local storage

**FRs covered:** FR150, FR153, FR154
**NFRs covered:** NFR87, NFR93

---

#### Story 21.3: Configure Long-Term Memory with LanceDB

As a **cluster operator**,
I want **to configure OpenClaw to use the `memory-lancedb` plugin with local Xenova embeddings for automatic memory capture and recall**,
So that **my AI assistant learns from past conversations and provides contextually relevant responses without manual memory management**.

**Acceptance Criteria:**

**Given** the OpenClaw gateway is running with local persistent storage (Story 21.1)
**When** I configure `plugins.slots.memory = "memory-lancedb"` and `plugins.entries.memory-lancedb.config.embedding` with `apiKey: "${OPENAI_API_KEY}"` and `model: "text-embedding-3-small"` in `openclaw.json`
**Then** the gateway starts with the `memory-lancedb` plugin active, replacing the default `memory-core` plugin (FR189)
**And** the OPENAI_API_KEY is resolved from the K8s Secret environment variable

**Given** the `memory-lancedb` plugin is active
**When** a conversation message is processed
**Then** the system automatically captures conversation context (user message + assistant key facts) into the LanceDB vector store (FR190)
**And** embedding latency does not exceed 500ms per message via OpenAI API (NFR105)

**Given** the `memory-lancedb` plugin is active and has stored memories
**When** a new conversation message arrives
**Then** the system automatically embeds the incoming message and performs vector similarity search against stored memories (FR190)
**And** relevant memories are injected as context before LLM inference, transparent to the user

**Given** the OpenClaw pod restarts
**When** the replacement pod starts
**Then** the LanceDB vector store and memory files are intact on the local PVC (`openclaw-data`) (NFR106)
**And** no memory data is lost and auto-recall continues functioning immediately

**Given** the operator execs into the OpenClaw pod
**When** they run `openclaw ltm stats`, `openclaw ltm list`, or `openclaw ltm search`
**Then** the CLI commands return memory count, list stored memories, or perform semantic search respectively (FR191)

**FRs covered:** FR189, FR190, FR191
**NFRs covered:** NFR105, NFR106

---

#### Story 21.4: Configure Opus 4.5 LLM with LiteLLM Fallback

As a **cluster operator**,
I want **to configure OpenClaw to use Claude Opus 4.5 as the primary LLM with automatic fallback to the existing LiteLLM proxy**,
So that **my AI assistant always has an LLM backend available, using frontier reasoning by default and local inference as backup**.

**Acceptance Criteria:**

**Given** the OpenClaw gateway is running with secrets configured (Story 21.1)
**When** I set the `ANTHROPIC_OAUTH_TOKEN` in the K8s Secret and configure `LITELLM_FALLBACK_URL` to `http://litellm.ml.svc.cluster.local:4000/v1`
**Then** OpenClaw routes all conversations to Claude Opus 4.5 via Anthropic OAuth as the primary LLM (FR155)
**And** the LiteLLM fallback URL resolves via standard K8s DNS from the `apps` namespace (NFR99)

**Given** Anthropic API is available
**When** a conversation message is processed
**Then** the response is generated by Opus 4.5
**And** the user can identify that Opus 4.5 is handling the conversation (FR157)

**Given** the Anthropic API becomes unavailable
**When** a conversation message is processed
**Then** OpenClaw automatically falls back to LiteLLM proxy within 5 seconds (FR156, NFR88)
**And** the three-tier LiteLLM fallback chain activates (vLLM GPU -> Ollama CPU -> OpenAI cloud)
**And** the user can identify the fallback provider is handling the conversation (FR157)

**Given** Anthropic API recovers after a transient failure
**When** the OAuth connection is re-established
**Then** auto-reconnection completes within 30 seconds (NFR96)

**Given** the gateway control UI is accessible (Story 21.2)
**When** I navigate to OAuth credential management
**Then** I can view token status and trigger manual refresh if needed (FR158, NFR94)
**And** no API keys or secrets are exposed in Loki logs (NFR95)

**FRs covered:** FR155, FR156, FR157, FR158
**NFRs covered:** NFR88, NFR94, NFR95, NFR96, NFR99

---

#### Story 21.5: Enable Telegram Channel with DM Security

As a **user**,
I want **to send and receive messages with my AI assistant via Telegram DM with allowlist-only security**,
So that **I can interact with my personal AI from Telegram while ensuring no unauthorized users can access it**.

**Acceptance Criteria:**

**Given** the OpenClaw gateway is running with LLM configured (Story 21.4)
**When** I set the `TELEGRAM_BOT_TOKEN` in the K8s Secret (from BotFather)
**Then** the Telegram channel connector starts and begins long-polling the Telegram Bot API
**And** no inbound network exposure is required (outbound HTTPS only)

**Given** the Telegram channel is connected
**When** an authorized user (on the allowlist in `openclaw.json`) sends a DM
**Then** the message is processed by the LLM and a response is returned within 10 seconds excluding LLM inference time (FR159, NFR86)

**Given** the Telegram channel is connected
**When** an unauthorized user (not on the allowlist) sends a DM
**Then** the message is rejected and the user receives no response (FR162, NFR92)

**Given** an unknown user attempts to interact
**When** the operator reviews pairing requests via the gateway CLI
**Then** the operator can approve or reject the pairing request (FR163)

**Given** the Telegram channel experiences a network interruption
**When** connectivity is restored
**Then** the channel automatically reconnects within 60 seconds (NFR97)
**And** the disconnection does not affect other gateway functionality (NFR101)

**Given** the OpenClaw pod enters a CrashLoopBackOff state
**When** the crash loop persists
**Then** Alertmanager sends a notification within 2 minutes (NFR102)

**FRs covered:** FR159, FR162, FR163
**NFRs covered:** NFR86, NFR92, NFR97, NFR101, NFR102

---

### Epic 22: OpenClaw Research Tools & Multi-Channel

**User Outcome:** Tom can research topics through his AI assistant using web research tools, and interact from WhatsApp, Discord, or Telegram with conversation continuity across channels.

**FRs Covered:** FR160-161, FR164-168
**NFRs Covered:** NFR89, NFR97-98

---

#### Story 22.1: Enable WhatsApp Channel via Baileys

As a **user**,
I want **to send and receive messages with my AI assistant via WhatsApp DM**,
So that **I can interact with my personal AI from my primary messaging app**.

**Acceptance Criteria:**

**Given** the OpenClaw gateway is running with LLM and Telegram configured (Epic 21)
**When** I configure WhatsApp Baileys credentials and complete the initial pairing process
**Then** the WhatsApp channel connector starts and establishes a WebSocket connection to WhatsApp servers
**And** no inbound network exposure is required (outbound WebSocket only)

**Given** the WhatsApp channel is connected
**When** an authorized user sends a DM
**Then** the message is processed by the LLM and a response is returned (FR160)
**And** the allowlist-only DM security policy applies (FR162, configured in Epic 21)

**Given** the OpenClaw pod restarts
**When** the replacement pod starts
**Then** the Baileys auth state is restored from NFS PVC at `~/clawd/` and no re-pairing is required
**And** WhatsApp reconnects automatically

**Given** the WhatsApp channel experiences a network interruption
**When** connectivity is restored
**Then** the channel automatically reconnects within 60 seconds (NFR97)
**And** the disconnection does not affect Telegram or other channels (NFR101)

**FRs covered:** FR160
**NFRs covered:** NFR97, NFR100, NFR101

---

#### Story 22.2: Enable Discord Channel

As a **user**,
I want **to send and receive messages with my AI assistant via Discord DM**,
So that **I can interact with my personal AI from Discord alongside my other communities**.

**Acceptance Criteria:**

**Given** the OpenClaw gateway is running (Epic 21)
**When** I set the `DISCORD_BOT_TOKEN` in the K8s Secret (from Discord Developer Portal)
**Then** the Discord channel connector starts and establishes a WebSocket connection to the Discord gateway via discord.js
**And** no inbound network exposure is required (outbound WebSocket only)

**Given** the Discord channel is connected
**When** an authorized user sends a DM
**Then** the message is processed by the LLM and a response is returned (FR161)
**And** the allowlist-only DM security policy applies (FR162)

**Given** the Discord channel experiences a network interruption
**When** connectivity is restored
**Then** the channel automatically reconnects within 60 seconds (NFR97)
**And** the disconnection does not affect Telegram or WhatsApp channels (NFR101)

**FRs covered:** FR161
**NFRs covered:** NFR97, NFR101

---

#### Story 22.3: Configure MCP Research Tools via mcporter

As a **user**,
I want **to ask my AI assistant to research topics on the web and receive sourced answers**,
So that **I can get up-to-date, referenced information without leaving the conversation**.

**Acceptance Criteria:**

**Given** the OpenClaw gateway is running with at least one messaging channel active (Epic 21)
**When** I configure the `EXA_API_KEY` in the K8s Secret and install the Exa MCP server via mcporter
**Then** the Exa research tool is available to the OpenClaw agent
**And** mcporter config and installed servers persist on NFS at `~/clawd/` for pod restart survival

**Given** the Exa MCP tool is configured
**When** a user asks a research question (e.g., "What are the latest K3s releases?")
**Then** the assistant invokes the Exa MCP tool through natural language conversation (FR167)
**And** returns a structured, sourced response with URLs and references (FR165, FR168)
**And** the MCP tool invocation returns results within 30 seconds (NFR89)

**Given** an MCP server connection times out
**When** the timeout is detected
**Then** the mcporter recovers gracefully without crashing the gateway (NFR98)
**And** the user receives an error message indicating the research tool is temporarily unavailable

**Given** the operator wants to add additional research MCP servers
**When** they install a new server via mcporter
**Then** the new server is available to the agent for tool invocation (FR166)
**And** the installation persists on NFS

**FRs covered:** FR165, FR166, FR167, FR168
**NFRs covered:** NFR89, NFR98

---

#### Story 22.4: Cross-Channel Conversation Context

As a **user**,
I want **to continue a conversation with my AI assistant across different messaging channels**,
So that **I can start a discussion on Telegram and pick it up on WhatsApp or Discord without losing context**.

**Acceptance Criteria:**

**Given** the user has active sessions on multiple messaging channels (Telegram, WhatsApp, Discord)
**When** the user sends a message on one channel referencing a previous conversation from another channel
**Then** the assistant maintains conversation context across channels (FR164)
**And** the user can seamlessly continue the discussion

**Given** a conversation has history on Telegram
**When** the same authorized user sends a follow-up message on WhatsApp
**Then** the assistant has access to the prior conversation context
**And** responds coherently with awareness of the earlier discussion

**Given** one messaging channel is disconnected
**When** the user switches to another active channel
**Then** the conversation context is preserved and accessible on the new channel

**FRs covered:** FR164

---

### Epic 23: OpenClaw Advanced Capabilities

**User Outcome:** Tom's AI assistant can speak via voice, delegate to specialized sub-agents, automate browser tasks, present rich content, and install skills from a marketplace — making it a fully capable personal tool.

**FRs Covered:** FR169-180
**NFRs Covered:** NFR90

---

#### Story 23.1: Enable Voice Interaction via ElevenLabs

As a **user**,
I want **to interact with my AI assistant using voice input and receive spoken responses**,
So that **I can have hands-free conversations with my personal AI**.

**Acceptance Criteria:**

**Given** the OpenClaw gateway is running with at least one messaging channel active (Epic 21)
**When** I set the `ELEVENLABS_API_KEY` in the K8s Secret
**Then** the ElevenLabs TTS/STT integration is available to the OpenClaw agent

**Given** voice mode is enabled
**When** the user sends a voice message through a supported channel
**Then** the assistant processes the voice input via ElevenLabs STT, generates a response via the LLM, and returns a spoken response via ElevenLabs TTS (FR169)
**And** voice response streaming begins within 5 seconds of the request (NFR90)

**Given** the user is in a voice conversation
**When** the user sends a text message instead of voice
**Then** the assistant seamlessly switches to text mode and responds in text (FR170)
**And** switching back to voice is equally seamless

**Given** the ElevenLabs API is temporarily unavailable
**When** the user sends a voice message
**Then** the assistant falls back to text-only response and informs the user that voice is temporarily unavailable

**FRs covered:** FR169, FR170
**NFRs covered:** NFR90

---

#### Story 23.2: Configure Multi-Agent Sub-Agent Routing

As an **operator**,
I want **to configure specialized sub-agents that the AI assistant can delegate tasks to**,
So that **different types of requests are handled by purpose-built agents with distinct capabilities**.

**Acceptance Criteria:**

**Given** the OpenClaw gateway is running (Epic 21)
**When** the operator configures specialized sub-agents in `openclaw.json` with distinct capabilities (e.g., coding assistant, research specialist, writing editor)
**Then** the sub-agents are registered and available to the main agent (FR171)

**Given** sub-agents are configured
**When** a user explicitly invokes a specific sub-agent (e.g., "ask the coding agent to review this")
**Then** the request is routed to the specified sub-agent and the response is returned to the user (FR172)

**Given** sub-agents are configured
**When** a user sends a message that matches a sub-agent's domain (e.g., a code review request when a coding sub-agent exists)
**Then** the system routes the task to the appropriate sub-agent based on context (FR173)
**And** the user receives the sub-agent's specialized response

**Given** no sub-agent matches the request
**When** a general conversation message is sent
**Then** the main agent handles the request directly without sub-agent routing

**FRs covered:** FR171, FR172, FR173

---

#### Story 23.3: Enable Browser Automation Tool

As a **user**,
I want **to ask my AI assistant to perform browser-based tasks like navigating websites, filling forms, and extracting information**,
So that **I can automate web interactions through conversation without doing them manually**.

**Acceptance Criteria:**

**Given** the OpenClaw gateway is running (Epic 21)
**When** a user requests a browser automation task through conversation (e.g., "check the current price of X on this website")
**Then** the assistant triggers the built-in browser automation tool (FR174)

**Given** the browser tool is invoked
**When** the task involves navigating a web page
**Then** the tool can navigate to URLs, interact with page elements, fill forms, and extract information (FR175)
**And** the extracted information is returned to the user in the conversation

**Given** a browser automation task fails (e.g., page not loading, element not found)
**When** the failure is detected
**Then** the assistant informs the user of the failure with a clear error description
**And** the gateway remains stable (no crash)

**FRs covered:** FR174, FR175

---

#### Story 23.4: Enable Rich Content via Canvas/A2UI

As a **user**,
I want **my AI assistant to present rich, structured content beyond plain text**,
So that **I can receive visually organized information like tables, diagrams, or interactive elements when appropriate**.

**Acceptance Criteria:**

**Given** the OpenClaw gateway is running (Epic 21)
**When** a response benefits from rich content presentation (e.g., comparison tables, structured data, visual layouts)
**Then** the assistant uses Canvas/A2UI to present the content in a rich format (FR176)

**Given** the messaging channel does not support rich content rendering
**When** rich content is generated
**Then** the assistant falls back to a well-formatted text representation

**FRs covered:** FR176

---

#### Story 23.5: Integrate ClawdHub Skills Marketplace

As an **operator**,
I want **to install, update, and manage skills from the ClawdHub marketplace for my AI assistant**,
So that **I can extend the assistant's capabilities with community-built skills without custom development**.

**Acceptance Criteria:**

**Given** the OpenClaw gateway is running with workspace NFS persistence (Epic 21)
**When** the operator installs a skill from the ClawdHub marketplace
**Then** the skill is downloaded and installed to the workspace NFS at `~/clawd/` (FR177)
**And** the skill persists across pod restarts

**Given** skills are installed
**When** the operator runs an update/sync operation via ClawdHub
**Then** installed skills are updated to their latest versions (FR178)

**Given** a skill is installed and enabled
**When** a user invokes the skill via a slash command (e.g., `/translate`) or natural language conversation
**Then** the skill executes and returns its output to the user (FR179)

**Given** the operator wants to manage individual skills
**When** they edit `openclaw.json` to enable, disable, or configure a specific skill
**Then** the changes take effect and the skill's availability is updated accordingly (FR180)
**And** disabled skills are not invocable by users

**FRs covered:** FR177, FR178, FR179, FR180

---

### Epic 24: OpenClaw Observability & Portfolio Documentation

**User Outcome:** Tom can monitor OpenClaw health via Grafana dashboards, receive alerts when the assistant is unhealthy, and showcase the architecture in his portfolio for interviews.

**FRs Covered:** FR181-188
**NFRs Covered:** NFR103-104

---

#### Story 24.1: Configure Loki Log Collection & Grafana Dashboard

As a **cluster operator**,
I want **to collect OpenClaw gateway logs into Loki and view operational metrics in a Grafana dashboard**,
So that **I can monitor message volume, LLM routing, MCP tool usage, and error rates without native Prometheus metrics**.

**Acceptance Criteria:**

**Given** the OpenClaw gateway is running (Epic 21) and Promtail is collecting logs cluster-wide
**When** the OpenClaw pod emits stdout/stderr logs
**Then** Promtail collects and ships the logs to Loki with appropriate labels (`namespace=apps`, `app=openclaw`) (FR181)
**And** logs are retained for a minimum of 7 days (NFR103)

**Given** OpenClaw logs are available in Loki
**When** I create a Grafana dashboard with LogQL queries
**Then** the dashboard displays the following panels (FR182, FR183):
- Message volume per channel (Telegram, WhatsApp, Discord)
- LLM provider usage ratio (Opus 4.5 vs LiteLLM fallback)
- MCP tool invocation counts (Exa research queries)
- Error rates and types (auth failures, channel disconnects, MCP timeouts)
- Session activity and agent routing

**Given** the Grafana dashboard is configured
**When** I open it in Grafana
**Then** the panels load with data from Loki and reflect recent gateway activity

**FRs covered:** FR181, FR182, FR183
**NFRs covered:** NFR103

---

#### Story 24.2: Configure Blackbox Exporter & Alertmanager Rules

As a **cluster operator**,
I want **Prometheus Blackbox Exporter to probe the OpenClaw gateway and Alertmanager to notify me when something is wrong**,
So that **I know within minutes if my AI assistant is down or experiencing sustained errors**.

**Acceptance Criteria:**

**Given** the OpenClaw gateway is accessible at `openclaw.home.jetzinger.com` (Story 21.2)
**When** I configure a Blackbox Exporter HTTP probe target for the gateway URL
**Then** the probe runs every 30 seconds and reports uptime, response latency, and TLS validity to Prometheus (FR184, NFR104)

**Given** the Blackbox Exporter probe is active
**When** the gateway becomes unreachable for 3 consecutive probes (90 seconds)
**Then** Alertmanager fires a `OpenClawGatewayDown` P1 alert (FR185)

**Given** OpenClaw logs are available in Loki (Story 24.1)
**When** the error rate exceeds 10% over a sustained period (detected via LogQL recording rules or manual review)
**Then** Alertmanager fires a `OpenClawHighErrorRate` P2 alert (FR185)

**Given** OpenClaw logs contain OAuth token warning patterns
**When** the warnings indicate imminent token expiry
**Then** Alertmanager fires a `OpenClawAuthExpiry` P2 alert (FR185)

**Given** the OpenClaw gateway is running
**When** I run `openclaw health --json` via kubectl exec
**Then** a JSON health snapshot is returned showing gateway status, channel connectivity, LLM provider status, and MCP tool availability (FR186)

**FRs covered:** FR184, FR185, FR186
**NFRs covered:** NFR104

---

#### Story 24.3: Document OpenClaw Architecture (ADR & README)

As a **portfolio audience member (hiring manager, recruiter)**,
I want **to read about the OpenClaw AI assistant architecture in the repository documentation**,
So that **I can understand the technical decisions, integration patterns, and AI-assisted engineering approach**.

**Acceptance Criteria:**

**Given** the OpenClaw system is deployed and operational
**When** I create an ADR documenting OpenClaw architectural decisions
**Then** the ADR is saved at `docs/adrs/ADR-{NNN}-openclaw-personal-ai-assistant.md` following the existing ADR format (FR187)
**And** the ADR covers: deployment architecture, inverse fallback LLM pattern, outbound-only channel networking, log-based observability pattern, NFS persistence strategy, and security model

**Given** the ADR is written
**When** I update the repository README
**Then** the README includes a OpenClaw section with architecture overview (FR188)
**And** the section describes: what OpenClaw is, how it connects to the cluster, LLM routing, messaging channels, and observability approach
**And** the documentation is navigable by an external reviewer (NFR27)

**FRs covered:** FR187, FR188

---

---

## Epic 25: Document Processing Pipeline Upgrade

**Goal:** Replace Paperless-AI with Paperless-GPT, add Docling for layout-aware document parsing, and upgrade the ML inference stack to Qwen3 models. Establishes a two-stage document processing pipeline where Docling extracts document structure and Qwen3 generates metadata.

**Brainstorming Session:** `docs/analysis/brainstorming-session-2026-02-12.md`

**Dependencies:** Existing Paperless-ngx (Epic 10), LiteLLM (Epic 14), vLLM (Epic 12)

**Architecture Decision:** Option C (revised) — Qwen3-8B-AWQ on GPU (primary), phi4-mini (Microsoft Phi-4-mini 3.8B) on Ollama CPU (fallback). Pivoted from qwen3:4b due to unfixable thinking mode overhead on CPU. No worker-02 Proxmox upgrade needed.

**FRs:** FR192-FR208
**NFRs:** NFR107-NFR116

### Story 25.1: Upgrade vLLM to Support Qwen3

As a **cluster operator**,
I want **to upgrade vLLM from v0.5.5 to v0.10.2+ and deploy Qwen3-8B-AWQ**,
So that **the GPU inference tier delivers significantly improved document classification accuracy and multilingual support**.

**Acceptance Criteria:**

**Given** vLLM is currently running v0.5.5 with Qwen2.5-7B-Instruct-AWQ
**When** I update the vLLM deployment image to `vllm/vllm-openai:v0.10.2` (or newer stable)
**Then** the vLLM pod starts successfully on k3s-gpu-worker (FR203)
**And** existing CLI arguments (`--enforce-eager`, `--quantization awq_marlin`, `--gpu-memory-utilization 0.90`, `--max-model-len 8192`) remain compatible (NFR115)

**Given** vLLM v0.10.2+ is running
**When** I update the model argument to `Qwen/Qwen3-8B-AWQ`
**Then** the model downloads and loads within 120 seconds (FR204)
**And** vLLM health endpoint responds at `/health`
**And** the model serves inference requests via OpenAI-compatible API

**Given** Qwen3-8B-AWQ is serving on vLLM
**When** I send a document classification prompt
**Then** the response includes valid structured metadata (title, tags, correspondent) (NFR110)
**And** inference throughput achieves 30-50 tokens/second on RTX 3060

**Given** the vLLM upgrade is complete
**When** I verify the DeepSeek-R1 deployment manifest (`deployment-r1.yaml`)
**Then** R1 mode continues to function with the upgraded vLLM image (NFR116)
**And** `gpu-mode r1` successfully switches to DeepSeek-R1

**FRs covered:** FR203, FR204
**NFRs covered:** NFR107, NFR110, NFR115, NFR116

---

### Story 25.2: Upgrade Ollama to Phi4-mini and Update LiteLLM

As a **cluster operator**,
I want **to upgrade Ollama from qwen2.5:3b to phi4-mini (Microsoft Phi-4-mini 3.8B) and update LiteLLM model routing**,
So that **the CPU fallback tier delivers improved metadata quality when the GPU is unavailable, without the Qwen3 thinking mode latency penalty**.

**Acceptance Criteria:**

**Given** Ollama is running on k3s-worker-02 with qwen2.5:3b (1.9GB)
**When** I pull the phi4-mini model via `ollama pull phi4-mini`
**Then** the model downloads successfully (~2.5GB Q4) and fits within worker-02's 8GB RAM (FR206)
**And** `ollama list` shows phi4-mini available

**Given** phi4-mini is available on Ollama
**When** I remove the old qwen2.5:3b model and any qwen3:4b model
**Then** disk space is reclaimed
**And** phi4-mini responds to inference requests without thinking mode overhead

**Given** Ollama and vLLM models are updated
**When** I update the LiteLLM configmap with new model paths:
- `vllm-qwen` → `openai/Qwen/Qwen3-8B-AWQ`
- `ollama-qwen` → `ollama/phi4-mini`
**Then** LiteLLM reloads configuration (FR205, FR207)
**And** the fallback chain `vllm-qwen → ollama-qwen → openai-gpt4o` routes correctly

**Given** LiteLLM is updated
**When** vLLM is unavailable (GPU off / gaming mode)
**Then** requests to `vllm-qwen` automatically fall back to `ollama-qwen` (phi4-mini)
**And** document classification completes within 60 seconds on CPU (NFR111)
**And** classification accuracy achieves 70%+ for common document types (NFR109)

**Given** LiteLLM is updated
**When** I access Open-WebUI and request model `vllm-qwen`
**Then** Open-WebUI transparently receives Qwen3 responses without configuration changes

**FRs covered:** FR205, FR206, FR207
**NFRs covered:** NFR108, NFR109, NFR111

---

### Story 25.3: Deploy Docling Server

As a **cluster operator**,
I want **to deploy a Docling server with the Granite-Docling VLM pipeline in the docs namespace**,
So that **incoming documents are parsed with layout-aware structure extraction before LLM processing**.

**Acceptance Criteria:**

**Given** the `docs` namespace has Paperless-ngx, Tika, and Gotenberg running
**When** I deploy a Docling server pod with `DOCLING_OCR_PIPELINE=vlm`
**Then** the Docling server starts and responds at its health endpoint (FR199)
**And** the pod uses <1GB memory (NFR114)
**And** the pod runs on CPU without GPU requirements (FR202)

**Given** Docling server is running
**When** I submit a PDF with complex tables and mixed German/English text
**Then** Docling returns structured markdown preserving table structure, reading order, and text content (FR200, FR201)
**And** extraction completes within 30 seconds for typical documents (NFR113)

**Given** Docling server is running
**When** I submit a scanned PDF (image-only)
**Then** Granite-Docling 258M VLM pipeline performs OCR and returns structured text
**And** German and English text are correctly extracted

**Given** Docling server is deployed
**When** Tika and Gotenberg are verified
**Then** Tika continues to handle email and Office format text extraction (unchanged)
**And** Gotenberg continues to convert Office documents to PDF (unchanged)

**FRs covered:** FR199, FR200, FR201, FR202
**NFRs covered:** NFR113, NFR114

---

### Story 25.4: Deploy Paperless-GPT and Remove Paperless-AI

As a **cluster operator**,
I want **to deploy Paperless-GPT with Docling OCR provider and remove Paperless-AI**,
So that **documents are processed through the two-stage pipeline (Docling → LLM) with improved metadata quality and customizable prompts**.

**Acceptance Criteria:**

**Given** Docling server and LiteLLM are operational
**When** I deploy Paperless-GPT with configuration:
- `OCR_PROVIDER=docling`
- `DOCLING_URL=http://docling:8000`
- `LLM_PROVIDER=openai`
- `LLM_MODEL=vllm-qwen`
- `OPENAI_API_BASE=http://litellm.ml.svc.cluster.local:4000/v1`
- `PAPERLESS_BASE_URL=http://paperless-paperless-ngx.docs.svc.cluster.local:8000`
**Then** Paperless-GPT starts and connects to all dependencies (FR192, FR193, FR194)

**Given** Paperless-GPT is running
**When** I tag a document with `paperless-gpt` in Paperless-ngx
**Then** Paperless-GPT processes the document through Docling → LLM pipeline
**And** title, tags, correspondent, and document type are generated (FR195)
**And** the web UI shows the document for manual review before applying metadata (FR197)

**Given** Paperless-GPT is running
**When** I tag a document with `paperless-gpt-auto` in Paperless-ngx
**Then** metadata is generated and applied automatically without manual review (FR197)

**Given** Paperless-GPT web UI is accessible
**When** I modify a prompt template via the web interface
**Then** the change takes effect without pod restart (FR196, NFR112)

**Given** Paperless-GPT is configured with ingress
**When** I access `paperless-gpt.home.jetzinger.com`
**Then** the web UI loads with HTTPS via Let's Encrypt certificate (FR198)

**Given** Paperless-GPT is fully operational and validated
**When** I remove Paperless-AI deployment, configmap, service, and ingress
**Then** all Paperless-AI resources are cleaned up from `docs` namespace (FR208)
**And** the `paperless-ai.home.jetzinger.com` ingress is removed
**And** Paperless-ngx continues to function normally

**Given** Paperless-GPT processes a document with GPU unavailable
**When** LiteLLM falls back to Ollama phi4-mini
**Then** metadata is still generated (degraded quality acceptable) (NFR109, NFR111)
**And** classification accuracy achieves 70%+ for common document types

**FRs covered:** FR192, FR193, FR194, FR195, FR196, FR197, FR198, FR208
**NFRs covered:** NFR107, NFR108, NFR109, NFR110, NFR111, NFR112

---

### Story 25.5: Enable VLM OCR Pipeline via Remote Services

As a **cluster operator**,
I want **to enable Docling's VLM pipeline for scanned/image-only PDFs by routing VLM inference through LiteLLM to Ollama serving Granite-Docling 258M**,
So that **scanned documents are processed with layout-aware OCR while maintaining the existing LiteLLM proxy pattern and graceful degradation**.

**✅ Validation Spike Completed (2026-02-14): GO**
- docling-serve v1.12.0 accepts `vlm_pipeline_model_api` — issue #318 (schema drop) is fixed
- Docling successfully calls remote Ollama and returns structured OCR output
- `response_format: "doctags"` is a required field in `vlm_pipeline_model_api`
- CPU inference latency: ~90s/page (NFR117 updated from 30s to 120s target)
- Ollama memory: +17Mi idle with granite-docling:258m loaded (521MB on disk)
- Test: image of data table → correctly extracted to markdown with full table structure
- [#463](https://github.com/docling-project/docling-serve/issues/463) (env var defaults) still OPEN but not a blocker — per-request config works

**Acceptance Criteria:**

#### Phase 1: Validation Spike (Go/No-Go)

**Given** Ollama is running on k3s-worker-02 with phi4-mini
**When** I pull `ibm/granite-docling:258m` on Ollama
**Then** the model is available alongside phi4-mini (FR210)
**And** Ollama memory footprint increases by <500MB (NFR118)
**And** I can verify the model responds to vision requests via `curl http://ollama:11434/v1/chat/completions`

**Given** Docling server is running with standard pipeline on k3s-worker-01
**When** I add `DOCLING_SERVE_ENABLE_REMOTE_SERVICES=true` to the Docling deployment
**And** I submit a scanned image/PDF with VLM pipeline configuration:
```json
{
  "options": {
    "pipeline": "vlm",
    "vlm_pipeline_model_api": {
      "url": "http://ollama.ml.svc.cluster.local:11434/v1/chat/completions",
      "params": { "model": "ibm/granite-docling:258m", "max_completion_tokens": 4096 },
      "response_format": "doctags",
      "timeout": 240
    }
  }
}
```
**Then** Docling sends VLM requests to Ollama and returns structured OCR output (FR209)
**And** VLM inference completes within 120 seconds per page on CPU (NFR117)

**✅ SPIKE COMPLETED — GO (2026-02-14):** Tested with table image → correct markdown extraction in 90s.

#### Phase 2: LiteLLM Integration (only if Phase 1 = GO)

**Given** VLM pipeline confirmed working with Ollama directly
**When** I add a `granite-docling` model alias to LiteLLM configmap pointing to Ollama `ibm/granite-docling:258m`
**Then** LiteLLM routes `granite-docling` requests to Ollama (FR211)
**And** the model is NOT added to the general text fallback chain (vllm-qwen → ollama-qwen → openai)

**Given** LiteLLM serves granite-docling
**When** I update the Docling VLM request to route through LiteLLM:
```json
{
  "options": {
    "pipeline": "vlm",
    "vlm_pipeline_model_api": {
      "url": "http://litellm.ml.svc.cluster.local:4000/v1/chat/completions",
      "params": { "model": "granite-docling" }
    }
  }
}
```
**Then** Docling calls LiteLLM which routes to Ollama for VLM inference (FR212)
**And** the scanned PDF is processed with OCR text extraction via Granite-Docling 258M (FR213)
**And** structured DocTags output is returned with extracted text content
**And** VLM inference completes within 120 seconds per page on CPU (NFR117)
**And** end-to-end processing completes within 10 minutes for a typical multi-page scanned document (NFR119)

#### Phase 3: Graceful Degradation & Paperless-GPT Integration

**Given** Ollama or LiteLLM is unavailable
**When** Docling attempts a VLM pipeline request
**Then** Docling degrades gracefully to standard pipeline (EasyOCR) (FR214, NFR120)
**And** no pod crash or request hang occurs

**Given** Paperless-GPT is configured with Docling as OCR provider
**When** a scanned document is tagged for processing
**Then** Paperless-GPT sends the document to Docling with VLM pipeline configuration
**And** the two-stage pipeline (Docling VLM OCR → LLM metadata) produces metadata for scanned documents

**FRs covered:** FR209, FR210, FR211, FR212, FR213, FR214
**NFRs covered:** NFR117, NFR118, NFR119, NFR120

---

**Workflow Status:** All epics and stories through Phase 6 have been created with detailed acceptance criteria, including:
- Phase 1-4: All 96 previous stories (Epics 1-20)
- Phase 5: 16 new OpenClaw stories (Epics 21-24):
  - OpenClaw Core Gateway & Telegram (Epic 21) with Opus 4.5 + LiteLLM inverse fallback
  - OpenClaw Research & Multi-Channel (Epic 22) with Exa MCP tools + WhatsApp/Discord
  - OpenClaw Advanced Capabilities (Epic 23) with voice, sub-agents, browser, skills
  - OpenClaw Observability & Documentation (Epic 24) with log-based monitoring + portfolio docs
- Phase 6 (continued): Document Processing Pipeline Upgrade (Epic 25):
  - vLLM Qwen3 upgrade (Story 25.1) with Qwen3-8B-AWQ on GPU
  - Ollama Qwen3 upgrade + LiteLLM update (Story 25.2) with phi4-mini CPU fallback
  - Docling server deployment (Story 25.3) with Granite-Docling 258M VLM pipeline
  - Paperless-GPT deployment + Paperless-AI removal (Story 25.4) with two-stage pipeline
  - VLM OCR pipeline via remote services (Story 25.5) with Granite-Docling 258M on Ollama through LiteLLM
- Phase 6 (continued): Ollama Pro Cloud Model Integration (Epic 26):
  - LiteLLM cloud provider config + secret management (Story 26.1)
  - Service default model updates: paperless-gpt, open-webui, n8n (Story 26.2)
  - OpenClaw cloud model migration + Anthropic removal (Story 26.3)

Ready to add to sprint-status.yaml and begin implementation.

---

## Epic 26: Ollama Pro Cloud Model Integration

**Goal:** Add three Ollama Pro cloud models (kimi-k2.5, minimax-m2.5, qwen3-coder:480b-cloud) to LiteLLM as primary inference tier with automatic local fallback. Update all services to use cloud models as defaults. Migrate openclaw off Anthropic (legal constraint) to cloud-kimi primary.

**Brainstorming Session:** `docs/analysis/brainstorming-session-2026-02-19.md`

**Dependencies:** Epic 14 (LiteLLM), Epic 21 (openclaw), Epic 17 (Open-WebUI), Epic 25 (Paperless-GPT)

**Architecture Decision:** LiteLLM as explicit cloud gatekeeper — Ollama pod untouched. Cloud API base: `https://ollama.com/api` (`/api` suffix required). Provider: `ollama_chat`. Model tag format: `{model}:XXb-cloud` (exact tags confirmed at implementation via Ollama Pro dashboard). openclaw: cloud-kimi primary (image input for browser automation), cloud-qwen3-coder for coder sub-agents, Anthropic removed per legal constraint.

**FRs:** FR215-FR223
**NFRs:** NFR121-NFR125

---

### Story 26.1: Configure LiteLLM with Ollama Pro Cloud Models

As a **cluster operator**,
I want **to add three Ollama Pro cloud models to LiteLLM with proper secret management and fallback chains**,
So that **all services have access to frontier cloud AI with automatic local fallback when the cloud is unavailable**.

**Acceptance Criteria:**

**Given** LiteLLM is running in the `ml` namespace with existing `litellm-secrets`
**When** I add `OLLAMA_API_KEY` to the secret via `kubectl patch secret litellm-secrets -n ml --type='merge' -p '{"stringData":{"OLLAMA_API_KEY":"<key>"}}'`
**Then** the key is stored securely as a Kubernetes secret (FR215)
**And** no `kubectl apply` with placeholder values is performed (NFR122)

**Given** `OLLAMA_API_KEY` is in the secret
**When** I update the LiteLLM configmap to add three cloud model entries:
- `cloud-kimi` → `ollama_chat/kimi-k2.5:<tag>-cloud` at `https://ollama.com/api`
- `cloud-minimax` → `ollama_chat/minimax-m2.5:<tag>-cloud` at `https://ollama.com/api`
- `cloud-qwen3-coder` → `ollama_chat/qwen3-coder:480b-cloud` at `https://ollama.com/api`
**Then** LiteLLM reloads and all three models appear in `/v1/models` response (FR216)
**And** each entry has `timeout: 60` and `api_key: os.environ/OLLAMA_API_KEY`

**Given** the cloud models are registered in LiteLLM
**When** I update the `fallbacks` section in `litellm_settings`:
- `cloud-kimi` → `["cloud-minimax", "vllm-qwen", "ollama-qwen"]`
- `cloud-minimax` → `["vllm-qwen", "ollama-qwen"]`
- `cloud-qwen3-coder` → `["vllm-qwen", "ollama-qwen"]`
**Then** LiteLLM falls back to local tier when cloud API is unavailable (FR217)
**And** failover activates within 5 seconds (NFR123)

**Given** the fallback chains are configured
**When** I remove `openai-gpt4o` from any automatic fallback chain entries (retaining it as explicit-only)
**Then** `openai-gpt4o` is no longer part of any automatic routing (FR218)
**And** it remains available as a direct model selection

**Given** the full cloud configuration is applied
**When** I send a test inference request to `cloud-kimi` via the LiteLLM endpoint
**Then** the response returns within 60 seconds (NFR121)
**And** LiteLLM Prometheus metrics record the cloud model request

**Given** the exact Ollama Pro model tags are unknown at planning time
**When** I obtain the `OLLAMA_API_KEY` and access the Ollama Pro account
**Then** I verify exact model tags via `ollama ls --cloud` or the Ollama Pro dashboard
**And** update configmap entries with confirmed tags before applying

**FRs covered:** FR215, FR216, FR217, FR218
**NFRs covered:** NFR121, NFR122, NFR123

---

### Story 26.2: Update Service Default Models to Cloud Tier

As a **cluster operator**,
I want **to update paperless-gpt, open-webui, and n8n to use cloud models as defaults**,
So that **document processing and chat workloads benefit from frontier model quality without changing application code**.

**Acceptance Criteria:**

**Given** `cloud-minimax` is available in LiteLLM and LiteLLM is reachable from the `docs` namespace
**When** I update the `paperless-gpt` configmap with `LLM_MODEL: "cloud-minimax"` (replacing `"vllm-qwen"`)
**Then** Paperless-GPT uses cloud-minimax for document metadata generation (FR219)
**And** the change takes effect without pod restart (hot-reload from configmap update)
**And** document classification still produces valid title, tags, correspondent, document type

**Given** cloud-minimax produces improved multilingual output
**When** I process a German-language document through Paperless-GPT
**Then** metadata quality is equal or better to the previous vllm-qwen baseline
**And** fallback to `vllm-qwen` activates automatically if cloud is unavailable (FR217)

**Given** LiteLLM `/v1/models` now includes `cloud-kimi`, `cloud-minimax`, and `cloud-qwen3-coder`
**When** I update `open-webui` values-homelab.yaml with `DEFAULT_MODELS: "cloud-minimax"` and redeploy
**Then** Open-WebUI shows `cloud-minimax` as the default model selection (FR220)
**And** all three cloud models appear in the model picker without additional per-model configuration (NFR124)
**And** local models (`vllm-qwen`, `ollama-qwen`) remain selectable

**Given** Open-WebUI is updated
**When** I start a new chat session in Open-WebUI
**Then** the chat automatically uses cloud-minimax
**And** I can switch to cloud-kimi or cloud-qwen3-coder from the model picker
**And** the UI loads within 3 seconds (NFR75)

**Given** n8n is running in the `apps` namespace
**When** I create a new credential in n8n UI of type "OpenAI API" with:
- Base URL: `http://litellm.ml.svc.cluster.local:4000/v1`
- API Key: LiteLLM master key (from existing K8s secret)
**Then** n8n can use the LiteLLM credential for AI nodes (FR221)
**And** per-workflow model selection supports `cloud-minimax`, `cloud-kimi`, `cloud-qwen3-coder`
**And** no Helm chart changes are required for n8n

**FRs covered:** FR219, FR220, FR221
**NFRs covered:** NFR121, NFR124

---

### Story 26.3: Migrate OpenClaw Off Anthropic to Cloud-Kimi Primary

As a **cluster operator**,
I want **to migrate openclaw's primary LLM from Anthropic Claude to cloud-kimi via LiteLLM, and coder sub-agents to cloud-qwen3-coder**,
So that **openclaw operates without any Anthropic dependency while maintaining full local fallback capability**.

**Acceptance Criteria:**

**Given** openclaw is running on k3s-worker-01 with Anthropic OAuth as primary
**When** I exec into the openclaw pod (`kubectl exec -n apps deployment/openclaw -- cat ~/.clawdbot/openclaw.json`)
**Then** I can identify the exact JSON key paths for the primary model provider, primary model ID, and coder sub-agent model (FR222)
**And** I document the exact key names before making any changes

**Given** the config key names are confirmed
**When** I remove `ANTHROPIC_OAUTH_TOKEN` from `openclaw-secrets` via:
`kubectl patch secret openclaw-secrets -n apps --type='json' -p '[{"op":"remove","path":"/data/ANTHROPIC_OAUTH_TOKEN"}]'`
**Then** the Anthropic OAuth token is removed from the cluster (FR222)
**And** no fallback to Anthropic remains anywhere in the routing chain

**Given** Anthropic credentials are removed
**When** I add `LITELLM_MASTER_KEY` to `openclaw-secrets` via `kubectl patch`
**Then** the LiteLLM master key is available to the openclaw container as an env var

**Given** the secrets are updated
**When** I apply the openclaw model config patch (via `kubectl exec` edit of `openclaw.json` or Gateway `config.patch` RPC):
- Provider: `litellm` at `http://litellm.ml.svc.cluster.local:4000/v1`
- Models registered: `cloud-kimi`, `cloud-minimax`, `cloud-qwen3-coder`, `vllm-qwen`, `ollama-qwen`
- Main agent primary: `litellm/cloud-kimi`
- Main agent fallbacks: `["litellm/cloud-minimax", "litellm/vllm-qwen", "litellm/ollama-qwen"]`
- Coder sub-agents: `litellm/cloud-qwen3-coder`
**Then** openclaw routes all conversations to cloud-kimi as primary (FR222)
**And** coder sub-agent tasks are routed to cloud-qwen3-coder (FR223)

**Given** the config is applied and openclaw pod restarts cleanly
**When** I send a test Telegram message to openclaw
**Then** the response comes from cloud-kimi (kimi-k2.5) via LiteLLM
**And** the gateway responds within 10 seconds excluding LLM inference time (NFR86)
**And** I can verify cloud-kimi is handling the request from gateway logs in Loki

**Given** cloud-kimi is operational as primary
**When** I simulate cloud API unavailability (temporarily set wrong api_base in litellm configmap for cloud-kimi)
**Then** LiteLLM automatically falls back to `cloud-minimax`, then `vllm-qwen`, then `ollama-qwen` (FR217)
**And** failover activates within 5 seconds (NFR123)
**And** openclaw continues responding without error

**Given** the migration is complete
**When** I verify the operational behavior across all modes:
- Normal: cloud-kimi (primary) ✓
- Cloud unavailable: vllm-qwen (local GPU) ✓
- Gaming Mode (GPU scaled to 0): cloud-kimi (cloud unaffected by GPU mode) ✓
- Cloud + GPU down: ollama-qwen (CPU fallback) ✓
- Full outage: Error — no Anthropic fallback (by design) ✓
**Then** all modes behave as specified in the architecture (NFR125)

**Given** the local LiteLLM fallback chain is validated
**When** I update the `openclaw-secrets` YAML in git (not the live secret):
- Remove `ANTHROPIC_OAUTH_TOKEN: ""` placeholder
- Add `LITELLM_MASTER_KEY: ""` placeholder
**Then** the git file reflects current secret structure (empty placeholders only, values applied via kubectl patch)

**FRs covered:** FR222, FR223
**NFRs covered:** NFR123, NFR125
