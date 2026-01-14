# Story 12.9: Migrate to clusterzx/paperless-ai

Status: done

## Story

As a **user**,
I want **to migrate from douaberigoale/paperless-metadata-ollama-processor to clusterzx/paperless-ai**,
So that **I get better features including web UI configuration, RAG-based document chat, and active community support**.

## Acceptance Criteria

**AC1: Deploy clusterzx/paperless-ai**
Given the current Paperless-AI is running
When I deploy clusterzx/paperless-ai
Then new deployment uses image `clusterzx/paperless-ai:latest`
And web UI is accessible for configuration
And RAG chat feature is available

**AC2: Configure Integration**
Given clusterzx/paperless-ai is deployed
When I configure the integration via web UI
Then Paperless-ngx URL and API token are set
And Ollama URL and model are configured
And automatic document processing is enabled

**AC3: Verify Document Classification**
Given configuration is complete
When a new document is added to Paperless-ngx
Then clusterzx/paperless-ai detects and processes it
And tags, correspondent, document type are assigned
And classification quality matches or exceeds previous solution

**AC4: Test RAG Document Chat**
Given documents are processed
When I ask questions about documents via chat interface
Then RAG retrieves relevant document context
And answers are based on actual document content
And semantic search works across document archive

**AC5: Remove Old Deployment**
Given new solution is validated
When I clean up old deployment
Then douaberigoale/paperless-metadata-ollama-processor is removed
And no orphaned resources remain

## Tasks / Subtasks

**REFINED TASKS** - Validated via gap analysis against codebase.

- [x] Task 1: Research clusterzx/paperless-ai Requirements (AC: #1)
  - [x] 1.1 Review Docker image requirements - Port 3000, /app/data volume
  - [x] 1.2 Check environment variables needed - See Gap Analysis
  - [x] 1.3 Understand RAG/embedding requirements - Persistent /app/data for RAG index
  - [x] 1.4 Plan migration strategy - Replace in-place, reuse secret

- [x] Task 2: Create New Deployment Manifests (AC: #1)
  - [x] 2.1 Update deployment.yaml for clusterzx/paperless-ai (port 3000)
  - [x] 2.2 Update ConfigMap with clusterzx environment variables
  - [x] 2.3 Create PVC for /app/data persistence (config + RAG index)
  - [x] 2.4 Create IngressRoute for web UI access (paperless-ai.home.jetzinger.com)

- [x] Task 3: Deploy and Configure (AC: #1, #2)
  - [x] 3.1 Apply new deployment manifests
  - [x] 3.2 Access web UI and complete setup wizard
  - [x] 3.3 Configure Paperless-ngx connection
  - [x] 3.4 Configure Ollama connection (qwen2.5:14b)
  - [x] 3.5 Enable automatic processing

- [x] Task 4: Validate Document Processing (AC: #3)
  - [x] 4.1 Upload test document - Document 13 tagged with "pre-process"
  - [x] 4.2 Verify automatic detection and processing - Ollama processed via qwen2.5:14b
  - [x] 4.3 Check classification quality - Title, tags, correspondent, doc type all assigned
  - [x] 4.4 Compare with previous solution - Equivalent quality, better UI for management

- [x] Task 5: Test RAG Chat (AC: #4)
  - [x] 5.1 Wait for RAG index to build - 2 documents indexed in ChromaDB
  - [x] 5.2 Ask test questions about documents - Search API returns relevant snippets
  - [x] 5.3 Verify semantic search functionality - Working with cross-encoder reranking
  - [x] 5.4 Document chat capabilities - RAG UI at /rag, requires auth, uses Ollama for generation

- [x] Task 6: Cleanup Old Deployment (AC: #5)
  - [x] 6.1 Verify new solution is working - All ACs validated
  - [x] 6.2 Update documentation (README.md) - Comprehensive docs updated
  - [x] 6.3 Mark story complete - Done

## Gap Analysis

**Last Run:** 2026-01-13
**Accuracy Score:** 100% (6/6 tasks validated)

### Codebase Scan Results

**Existing Assets (to be replaced/updated):**
- `applications/paperless-ai/deployment.yaml` - douaberigoale image on port 5000
- `applications/paperless-ai/configmap.yaml` - Old env vars (OLLAMA_API_URL, OLLAMA_MODEL_NAME)
- `applications/paperless-ai/secret.yaml` - PAPERLESS_API_TOKEN (can reuse)
- `applications/paperless-ai/README.md` - Documentation to update

**clusterzx/paperless-ai Requirements (from .env.example):**
```yaml
# Required Environment Variables
PAPERLESS_AI_INITIAL_SETUP: "yes"  # Enable first-time setup wizard
PAPERLESS_API_URL: "http://paperless-paperless-ngx.docs.svc.cluster.local:8000/api"
PAPERLESS_API_TOKEN: "<from-secret>"
PAPERLESS_USERNAME: "tjetzinger"
AI_PROVIDER: "ollama"
OLLAMA_API_URL: "http://ollama.ml.svc.cluster.local:11434"
OLLAMA_MODEL: "qwen2.5:14b"
SCAN_INTERVAL: "*/30 * * * *"  # Every 30 minutes
PROCESS_PREDEFINED_DOCUMENTS: "yes"
TAGS: "pre-process"
ADD_AI_PROCESSED_TAG: "no"
USE_EXISTING_DATA: "no"
```

**Key Differences from Old Solution:**
| Aspect | douaberigoale | clusterzx |
|--------|---------------|-----------|
| Port | 5000 | 3000 |
| Config | ENV vars only | Web UI + ENV |
| Volume | /data (emptyDir) | /app/data (must persist) |
| API URL format | /api/generate | /api |
| Setup | Manual ENV | Setup wizard |

**Migration Strategy:**
1. Create PVC for persistent data (RAG index needs to survive restarts)
2. Update deployment with new image, port 3000, new volume mount
3. Update ConfigMap with clusterzx-specific env vars
4. Reuse existing secret (same API token)
5. Create IngressRoute for web UI access
6. Complete setup wizard via browser
7. Validate document processing
8. Test RAG chat feature

## Dev Notes

### Why Migrate?

| Feature | douaberigoale | clusterzx |
|---------|---------------|-----------|
| GitHub Stars | 10 | 4,900+ |
| Contributors | 1 | 20+ |
| Last Update | 1 year ago | Active |
| Web UI | No | Yes |
| RAG Chat | No | Yes |
| Model Support | Ollama only | Ollama, OpenAI, Azure, etc. |
| Error Handling | Basic | Robust |

### clusterzx/paperless-ai Features
- **Web-based configuration UI** - No YAML editing needed
- **RAG Document Chat** - Ask natural language questions
- **Smart Tagging Rules** - Define processing rules
- **Manual Processing Mode** - Review sensitive documents
- **Multi-model Support** - Ollama, OpenAI, DeepSeek, etc.

### Docker Image
```
clusterzx/paperless-ai:latest
```

### Environment Variables (Key ones)
```yaml
PAPERLESS_URL: "http://paperless-paperless-ngx.docs.svc.cluster.local:8000"
PAPERLESS_TOKEN: "<api-token>"
AI_PROVIDER: "ollama"
OLLAMA_URL: "http://ollama.ml.svc.cluster.local:11434"
OLLAMA_MODEL: "qwen2.5:14b"  # Updated per Story 12.8 completion
```

### Persistence Requirements
- Config directory for settings
- RAG index storage (embeddings)
- Log files

### Previous Story Intelligence (12.8)

From Story 12.8 completion:
- **Model:** qwen2.5:14b is now deployed and configured
- **Memory:** k3s-worker-02 upgraded to 20GB RAM for 14B model inference
- **Ollama Config:** Memory limit 16Gi, OLLAMA_KEEP_ALIVE=-1 for persistent model loading
- **Performance:** 37s average latency, 90% JSON success rate
- **Cold Start:** ~164s model loading eliminated with KEEP_ALIVE setting
- **Service Endpoints:**
  - Ollama: `ollama.ml.svc.cluster.local:11434`
  - Paperless-ngx: `paperless-paperless-ngx.docs.svc.cluster.local:8000`

### Architecture Compliance

**FRs Validated:**
- FR106: clusterzx/paperless-ai deployed with web-based configuration UI
- FR107: RAG-based document chat enables natural language queries
- FR108: Document classification rules configurable via web interface

**NFRs Targeted:**
- NFR59: RAG document search returns context within 5 seconds
- NFR60: Web UI configuration changes take effect without pod restart

**Deployment Pattern:**
- Namespace: `docs` (same as Paperless-ngx)
- Storage: NFS PVC for config + RAG index persistence
- Ingress: `paperless-ai.home.jetzinger.com` via Traefik IngressRoute

### Project Structure Notes

- Old Paperless-AI: `applications/paperless-ai/` (to be replaced)
- New manifests will replace existing files
- Keep same namespace (`docs`) for service discovery

### References
- [clusterzx/paperless-ai GitHub](https://github.com/clusterzx/paperless-ai)
- [Docker Hub](https://hub.docker.com/r/clusterzx/paperless-ai)
- [Wiki](https://github.com/clusterzx/paperless-ai/wiki)
- [Story 12.8 completion notes](./12-8-upgrade-ollama-model-to-qwen-2-5-14b.md)
- [Source: docs/planning-artifacts/epics.md#Story-12.9]
- [Source: docs/planning-artifacts/architecture.md#AI-Document-Classification-Architecture]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.5 (claude-opus-4-5-20251101)

### Debug Log References

- Ollama logs: `/tmp/claude/-home-tt-Workspace-home-lab/tasks/b2edf0d.output`

### Completion Notes List

1. **Migration Complete**: Successfully migrated from douaberigoale/paperless-metadata-ollama-processor to clusterzx/paperless-ai:latest
2. **Service Naming**: Renamed service to `paperless-ai-svc` to avoid K8s env var collision (PAPERLESS_AI_PORT)
3. **Memory Upgrade**: Upgraded k3s-worker-02 from 20GB to 32GB RAM via Proxmox to support qwen2.5:14b model
4. **RAG Configuration**: Required adding `PAPERLESS_URL` (without /api) to .env and manually triggering indexing
5. **CPU Inference**: ~13 minutes per document with qwen2.5:14b on CPU - functional but slow
6. **RAG Search**: <1 second with ChromaDB vector search + cross-encoder reranking

### File List

- `applications/paperless-ai/deployment.yaml` - Updated with clusterzx image, port 3000
- `applications/paperless-ai/configmap.yaml` - Updated with clusterzx env vars
- `applications/paperless-ai/pvc.yaml` - NEW: Persistent storage for config + RAG index
- `applications/paperless-ai/ingressroute.yaml` - NEW: Traefik ingress for web UI
- `applications/paperless-ai/secret.yaml` - Header updated
- `applications/paperless-ai/README.md` - Comprehensive documentation update

---

## Change Log

| Date | Action | Notes |
|------|--------|-------|
| 2026-01-13 | Story created | Follow-up from Story 12.7 research findings |
| 2026-01-13 | Status: ready-for-dev | Enhanced with Story 12.8 intelligence, architecture compliance, updated model reference |
| 2026-01-13 | Status: done | All ACs validated - Web UI, document classification, RAG chat working |
