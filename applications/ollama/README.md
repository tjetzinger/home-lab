# Ollama LLM Inference Service

**Purpose:** CPU-based slim model inference for experimental/lightweight workloads

**Story:** 12.10 - Configure vLLM GPU Integration for Paperless-AI
**Epic:** 12 - GPU/ML Inference Platform
**Namespace:** `ml`

---

## Overview

Ollama is deployed as a Deployment using the official Ollama Helm chart, providing CPU-based inference for lightweight experimental workloads.

**Note:** Document classification has been moved to vLLM (GPU-accelerated) as of Story 12.10.

**Key Features:**
- CPU-only inference with slim models (llama3.2:1b, qwen2.5:3b)
- NFS-backed model storage for persistence
- HTTPS ingress with Let's Encrypt TLS
- Internal cluster access via ClusterIP service
- External access via ollama.home.jetzinger.com
- Reduced resource footprint (4GB RAM limit)

---

## Deployment

### Prerequisites

- `ml` namespace exists
- NFS storage provisioner available (nfs-client StorageClass)
- Traefik ingress controller deployed
- cert-manager for TLS certificate provisioning

### Deploy Ollama

```bash
# Add Ollama Helm repository
helm repo add ollama-helm https://otwld.github.io/ollama-helm/
helm repo update

# Deploy Ollama
helm upgrade --install ollama ollama-helm/ollama \
  -f values-homelab.yaml \
  -n ml

# Apply ingress configuration
kubectl apply -f ingress.yaml

# Verify deployment
kubectl get pods -n ml
kubectl get pvc -n ml
kubectl get svc -n ml
kubectl get certificate -n ml
```

---

## Access

### External HTTPS Access

**URL:** https://ollama.home.jetzinger.com
**Access:** Tailscale VPN only (no public internet exposure)

### Internal Cluster Access

**Service DNS:** `ollama.ml.svc.cluster.local`
**Port:** 11434

### Test API Endpoint

```bash
# List available models
curl https://ollama.home.jetzinger.com/api/tags

# Internal cluster access
kubectl run -it --rm curl-test --image=curlimages/curl --restart=Never -- \
  curl http://ollama.ml.svc.cluster.local:11434/api/tags
```

---

## Configuration

### Current Setup

| Setting | Value |
|---------|-------|
| Chart | ollama-helm/ollama (v1.36.0) |
| App Version | 0.13.3 |
| Namespace | ml |
| Service Type | ClusterIP (internal only) |
| Port | 11434 |
| Ingress | https://ollama.home.jetzinger.com |
| TLS | Let's Encrypt (letsencrypt-prod) |
| Persistence | NFS-backed PVC |
| PVC Name | ollama |
| Storage Class | nfs-client |
| Storage Size | 50Gi |
| Access Mode | ReadWriteOnce (RWO) |
| Mount Path | /root/.ollama |
| NFS Server | 192.168.2.2 (Synology DS920+) |
| GPU Support | Disabled (CPU-only for MVP) |

### Resource Allocation

| Component | CPU Request | CPU Limit | Memory Request | Memory Limit |
|-----------|-------------|-----------|----------------|--------------|
| Ollama | 500m | 2000m | 2Gi | 4Gi |

**Note:** Reduced allocation for slim models only. Document classification uses vLLM (GPU) as of Story 12.10.

---

## Model Management

### Download Models

```bash
# Get pod name
POD=$(kubectl get pods -n ml -l app.kubernetes.io/name=ollama -o jsonpath='{.items[0].metadata.name}')

# Pull a model
kubectl exec -n ml $POD -- ollama pull llama3.2:1b

# List downloaded models
kubectl exec -n ml $POD -- ollama list
```

### Currently Loaded Models

- **llama3.2:1b** (1.3 GB) - Small model for testing/lightweight inference
- **qwen2.5:3b** (1.9 GB) - Slim Qwen model for experimental workloads

**Note:** Large models (qwen2.5:14b) removed as of Story 12.10. Document classification now uses vLLM with GPU acceleration.

### Model Storage Details

- **Storage Location:** NFS-backed PVC mounted at `/root/.ollama`
- **NFS Path:** `192.168.2.2:/volume1/k8s-data/ml-ollama-pvc-{uid}/`
- **Persistence:** ✅ Models survive pod restarts (validated)
- **Reclaim Policy:** Delete (PV deleted when PVC is deleted)

---

## API Usage

### List Models

```bash
curl https://ollama.home.jetzinger.com/api/tags
```

### Generate Text

```bash
curl https://ollama.home.jetzinger.com/api/generate -d '{
  "model": "llama3.2:1b",
  "prompt": "Why is the sky blue?",
  "stream": false
}'
```

### Chat Completion

```bash
curl https://ollama.home.jetzinger.com/api/chat -d '{
  "model": "llama3.2:1b",
  "messages": [
    {"role": "user", "content": "Hello! What can you help me with?"}
  ],
  "stream": false
}'
```

For full API documentation, see: https://github.com/ollama/ollama/blob/main/docs/api.md

---

## API Testing Results

**Story:** 6.2 - Test Ollama API and Model Inference
**Validated:** 2026-01-06

### API Endpoints Validated

| Endpoint | Method | Status | Response Time | Notes |
|----------|--------|--------|---------------|-------|
| `/api/tags` | GET | ✅ 200 | < 1s | Lists available models |
| `/api/generate` | POST | ✅ 200 | 2-116s | Text completion (varies by prompt complexity) |
| `/api/generate` (streaming) | POST | ✅ 200 | Streaming | Newline-delimited JSON chunks |

### Performance Benchmarks

**Test Environment:**
- Infrastructure: CPU-only inference (4 cores, 8Gi memory)
- Model: llama3.2:1b (1.3GB, Q8_0 quantization)
- Test Date: 2026-01-06

**Results:**

| Test Type | Prompt | Response Time | Status vs NFR13 |
|-----------|--------|---------------|-----------------|
| Simple prompt | "Hello" | 2s | ✅ < 30s |
| Medium prompt | "Hello, how are you?" | 116s | ❌ > 30s |

**NFR13 Status:** ⚠️ **Partially Met**
- Simple prompts meet the <30s target
- Complex prompts exceed target on CPU-only inference
- **Mitigation:** GPU support in Phase 2 will significantly improve performance
- **Current State:** Acceptable for MVP testing, production workloads should use shorter prompts or accept longer response times

### API Response Examples

**List Models Response:**
```json
{
  "models": [
    {
      "name": "llama3.2:1b",
      "model": "llama3.2:1b",
      "modified_at": "2026-01-06T18:26:21.023875318Z",
      "size": 1321098329,
      "digest": "baf6a787fdffd633537aa2eb51cfd54cb93ff08e28040095462bb63daf552878",
      "details": {
        "parent_model": "",
        "format": "gguf",
        "family": "llama",
        "families": ["llama"],
        "parameter_size": "1.2B",
        "quantization_level": "Q8_0"
      }
    }
  ]
}
```

**Generate Text Response (Non-Streaming):**
```json
{
  "model": "llama3.2:1b",
  "created_at": "2026-01-06T19:45:23.123456Z",
  "response": "I'm doing well, thanks for asking. Is there something I can help you with or would you like to talk about yourself?",
  "done": true,
  "total_duration": 116082000000,
  "load_duration": 1234567,
  "prompt_eval_count": 14,
  "eval_count": 89,
  "eval_duration": 115000000000
}
```

**Generate Text Response (Streaming):**
```json
{"response":"\"","done":false}
{"response":"Hello","done":false}
{"response":",","done":false}
{"response":" I","done":false}
{"response":"'m","done":false}
...
{"response":"","done":true,"total_duration":5123456789}
```

### External Access Validation

**Access Method:** Tailscale VPN required

**Validated:**
- ✅ DNS resolution: `ollama.home.jetzinger.com` → `192.168.2.100`
- ✅ TLS certificate: Valid Let's Encrypt (expires Apr 6, 2026)
- ✅ HTTPS access: Working with HTTP→HTTPS redirect (308)
- ✅ API responses: Identical to internal cluster access

**External Access Pattern for Applications:**

```bash
# From any Tailscale-connected device:
curl https://ollama.home.jetzinger.com/api/generate \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama3.2:1b",
    "prompt": "Your prompt here",
    "stream": false
  }'
```

**Security:** All external access requires Tailscale VPN connection. No public internet exposure.

### Health Check Script

**Location:** `scripts/ollama-health.sh`

**Usage:**
```bash
# Test external HTTPS endpoint (default)
./scripts/ollama-health.sh

# Test internal cluster endpoint
./scripts/ollama-health.sh --internal
```

**Checks Performed:**
1. API endpoint accessibility
2. Model availability (llama3.2:1b)
3. Basic inference test with response time measurement

**Exit Codes:**
- `0` - All healthy
- `1` - API unreachable
- `2` - Model not available
- `3` - Inference failed
- `4` - Performance degraded (>30s response time)

**Example Output:**
```
======================================
  Ollama Health Check
======================================
  Endpoint: https://ollama.home.jetzinger.com
  Model: llama3.2:1b
======================================

[PASS] API endpoint accessible (https://ollama.home.jetzinger.com)
[PASS] Model llama3.2:1b available (size: 1.3G)
[PASS] Inference successful (2s)

======================================
  Summary
======================================

Checks passed: 3
Warnings:      0
Checks failed: 0

OLLAMA HEALTH: OK
```

### Functional Requirements Validation

✅ **FR37:** Applications can query Ollama API for completions
- Validated via successful `/api/generate` requests
- Both streaming and non-streaming modes operational
- External access via Tailscale VPN working
- Health check script provides monitoring capability

---

## Monitoring

### Check Pod Status

```bash
# Pod status
kubectl get pods -n ml -l app.kubernetes.io/name=ollama

# Pod logs
kubectl logs -n ml -l app.kubernetes.io/name=ollama --tail=50 -f

# Resource usage
kubectl top pod -n ml
```

### Verify Storage

```bash
# Check PVC status
kubectl get pvc -n ml

# Verify NFS mount inside pod
POD=$(kubectl get pods -n ml -l app.kubernetes.io/name=ollama -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n ml $POD -- df -h /root/.ollama
```

### Certificate Status

```bash
# Check TLS certificate
kubectl get certificate -n ml ollama-tls

# Describe certificate for details
kubectl describe certificate -n ml ollama-tls
```

---

## Operations

This section covers day-to-day operational procedures for managing the Ollama deployment.

### Scaling Procedures

**Prerequisites:**
- Deployment type: Deployment (supports horizontal scaling)
- Storage: NFS-backed PVC (supports multi-node access despite RWO access mode)
- Resource availability: Each pod requires 500m CPU / 2Gi RAM minimum

**Scale Up:**

```bash
# Scale to 2 replicas
kubectl scale deployment ollama -n ml --replicas=2

# Monitor pod creation
kubectl get pods -n ml -l app.kubernetes.io/name=ollama -w

# Verify both pods are Running
kubectl get pods -n ml -l app.kubernetes.io/name=ollama -o wide
```

Expected behavior:
- New pod(s) created with status: ContainerCreating → Running
- Kubernetes service automatically load balances across all healthy pods
- NFS storage allows pods to run on different nodes (no same-node constraint)

**Scale Down:**

```bash
# Scale to 1 replica
kubectl scale deployment ollama -n ml --replicas=1

# Monitor pod termination
kubectl get pods -n ml -l app.kubernetes.io/name=ollama -w

# Verify remaining pod continues running
kubectl get pods -n ml -l app.kubernetes.io/name=ollama
```

Expected behavior:
- Kubernetes gracefully terminates excess pod(s)
- Remaining pod(s) continue serving requests
- No service interruption (load balancer updates automatically)

**Verify Service Health After Scaling:**

```bash
# Run health check
./scripts/ollama-health.sh --external

# Or test API directly
curl https://ollama.home.jetzinger.com/api/tags
```

**Important Notes:**
- **RWO Storage Clarification:** While the PVC uses ReadWriteOnce (RWO) access mode, NFS-backed storage inherently supports multi-node concurrent access. This allows Ollama to scale across multiple nodes without same-node constraints that would apply to block storage.
- **Model Persistence:** Models stored in `/root/.ollama` are shared across all replicas via NFS
- **Performance:** CPU-only inference performance is consistent regardless of replica count
- **Capacity Planning:** Verify node resources before scaling (each pod: 500m-4 CPU, 2-8Gi RAM)

### Log Viewing

**View Recent Logs:**

```bash
# Get pod name
POD=$(kubectl get pods -n ml -l app.kubernetes.io/name=ollama -o jsonpath='{.items[0].metadata.name}')

# View last 50 lines
kubectl logs -n ml $POD --tail=50

# View logs from last 5 minutes
kubectl logs -n ml $POD --since=5m

# View logs with timestamps
kubectl logs -n ml $POD --timestamps --tail=100
```

**Stream Real-Time Logs:**

```bash
# Stream logs from a specific pod
kubectl logs -n ml $POD --follow

# Stream logs with timestamps
kubectl logs -n ml $POD --follow --timestamps

# Stream logs from all Ollama pods (when scaled)
kubectl logs -n ml -l app.kubernetes.io/name=ollama --follow --prefix
```

**Filter Logs:**

```bash
# Search for inference requests
kubectl logs -n ml $POD | grep "POST.*generate"

# Search for errors
kubectl logs -n ml $POD | grep -i error

# View startup messages
kubectl logs -n ml $POD | head -30
```

**Common Log Patterns:**

- **Startup:** `msg="Listening on [::]:11434 (version X.X.X)"`
- **Model Loading:** `msg="total blobs: 5"`
- **Health Checks:** `GET "/" | 200 | ~20µs`
- **Inference Requests:** `POST "/api/generate" | 200 | 1m54s`
- **API Queries:** `GET "/api/tags" | 200 | ~1ms`

### Event Inspection

**View All Namespace Events:**

```bash
# View all events in ml namespace, sorted by time
kubectl get events -n ml --sort-by=.lastTimestamp

# View events in human-readable format
kubectl get events -n ml --sort-by=.lastTimestamp -o wide
```

**Filter Events:**

```bash
# View only Ollama deployment events
kubectl get events -n ml \
  --field-selector involvedObject.kind=Deployment,involvedObject.name=ollama \
  --sort-by=.lastTimestamp

# View only Ollama pod events
kubectl get events -n ml \
  --field-selector involvedObject.kind=Pod \
  --sort-by=.lastTimestamp | grep ollama
```

**View Pod-Specific Events:**

```bash
# Get detailed events for a specific pod
POD=$(kubectl get pods -n ml -l app.kubernetes.io/name=ollama -o jsonpath='{.items[0].metadata.name}')
kubectl describe pod -n ml $POD | grep -A 20 "Events:"
```

**Common Event Types:**

- **Scheduled:** Pod assigned to a node
- **Pulling / Pulled:** Container image download
- **Created / Started:** Container lifecycle
- **ScalingReplicaSet:** Deployment replica count changed
- **Killing:** Graceful pod termination
- **FailedScheduling:** Pod cannot be scheduled (resource constraints, node affinity)
- **BackOff / CrashLoopBackOff:** Container failing to start

**Event Retention:**

⚠️ Kubernetes events are retained for approximately **1 hour**. For historical analysis beyond this window, use:
- **Grafana + Loki:** Query logs from the last 30 days (Epic 4 deployment)
- **Prometheus:** View pod restart counts and availability metrics

### Troubleshooting Common Issues

**Pods Not Scaling Up:**

```bash
# Check node resources
kubectl describe nodes | grep -A 5 "Allocated resources"

# Check deployment status
kubectl describe deployment ollama -n ml

# Check replica set status
kubectl get rs -n ml -l app.kubernetes.io/name=ollama
```

Common causes:
- Insufficient node resources (CPU/memory)
- Image pull failures (check events)
- Node taints/affinities preventing scheduling

**Slow or Failed Image Pull:**

```bash
# Check image pull status
kubectl describe pod -n ml $POD | grep -A 10 "Events:"

# View image size and pull time
kubectl get events -n ml --sort-by=.lastTimestamp | grep -i pulled
```

Expected pull time for Ollama image: ~4-5 minutes (2.1GB) on typical home connection.

**Service Not Load Balancing:**

```bash
# Verify service endpoints include all pods
kubectl get endpoints -n ml ollama

# Expected: Multiple IP addresses listed (one per Running pod)
```

If endpoints missing:
- Check pod readiness: `kubectl get pods -n ml -o wide`
- Check readiness probe: `kubectl describe pod -n ml $POD | grep -A 5 Readiness`

---

## Troubleshooting

### Pod Not Starting

```bash
# Check pod events
POD=$(kubectl get pods -n ml -l app.kubernetes.io/name=ollama -o jsonpath='{.items[0].metadata.name}')
kubectl describe pod -n ml $POD

# Check logs
kubectl logs -n ml $POD

# Check deployment status
kubectl get deployment -n ml ollama
```

### PVC Not Binding

```bash
# Check PVC status
kubectl get pvc -n ml
kubectl describe pvc -n ml ollama

# Verify NFS provisioner is running
kubectl get pods -n infra -l app=nfs-subdir-external-provisioner

# Check StorageClass exists
kubectl get storageclass nfs-client
```

### Model Download Fails

```bash
# Check internet connectivity from pod
POD=$(kubectl get pods -n ml -l app.kubernetes.io/name=ollama -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n ml $POD -- curl -I https://ollama.com

# Check available disk space
kubectl exec -n ml $POD -- df -h /root/.ollama

# View download logs
kubectl logs -n ml $POD --tail=100
```

### HTTPS Access Not Working

```bash
# Check ingress route
kubectl get ingressroute -n ml

# Check certificate status
kubectl get certificate -n ml ollama-tls

# Check cert-manager logs
kubectl logs -n infra -l app=cert-manager --tail=50

# Test HTTP (should redirect to HTTPS)
curl -v http://ollama.home.jetzinger.com/api/tags
```

### Slow Inference Performance

**Note:** This is expected for CPU-only inference. GPU support will be added in Phase 2.

Current performance:
- CPU-only inference on 4 cores
- Expected response time: < 30 seconds for small models (NFR13)
- For faster inference, consider using smaller models (1B-3B parameters)

---

## Future Enhancements

- **Phase 2:** GPU support (Intel NUC with eGPU)
- **Phase 2:** vLLM deployment for OpenAI-compatible API
- **Phase 2:** Model quantization for improved CPU performance
- **Phase 2:** Auto-scaling based on inference load

---

## Related Documentation

- [Ollama Official Documentation](https://github.com/ollama/ollama)
- [Ollama API Reference](https://github.com/ollama/ollama/blob/main/docs/api.md)
- [Ollama Helm Chart](https://github.com/otwld/ollama-helm)

---

## Change Log

- 2026-01-06: Initial deployment (Story 6.1) - CPU-only inference with NFS-backed model storage
- 2026-01-06: Deployed llama3.2:1b model (1.3 GB) for testing
- 2026-01-06: Validated model persistence across pod restarts
- 2026-01-06: Configured HTTPS ingress with Let's Encrypt TLS
- 2026-01-06: API testing completed (Story 6.2) - Validated all endpoints, streaming mode, external access
- 2026-01-06: Performance benchmarking completed - NFR13 partially met (2s simple prompts, 116s complex prompts)
- 2026-01-06: Created ollama-health.sh script for health monitoring
- 2026-01-06: Validated FR37 - Applications can query Ollama API for completions
- 2026-01-06: Operations section added (Story 6.4) - Scaling procedures, log viewing, event inspection, troubleshooting
- 2026-01-06: Validated FR12 (scaling) and FR13 (logs/events) - Demonstrated Kubernetes operational skills
- 2026-01-06: Discovered NFS storage allows multi-node scaling despite RWO access mode
- 2026-01-13: Story 12.10 - Downgraded to slim models (llama3.2:1b, qwen2.5:3b), removed qwen2.5:14b
- 2026-01-13: Reduced memory limit from 16Gi to 4Gi, CPU limit from 4000m to 2000m
- 2026-01-13: Document classification moved to vLLM (GPU) on k3s-gpu-worker
