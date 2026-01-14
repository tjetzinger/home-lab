# Story 14.4: Configure Prometheus Metrics and Monitoring

Status: done

## Story

As a **platform operator**,
I want **LiteLLM to expose Prometheus metrics for inference routing and fallback events**,
So that **I can monitor the health of my inference infrastructure and track when failovers occur**.

## Acceptance Criteria

1. **Given** LiteLLM is deployed with three-tier fallback
   **When** I enable Prometheus metrics in LiteLLM configuration
   **Then** metrics are exposed on port 4000 at `/metrics` endpoint (FR118)
   **And** metrics include request counts, latencies, and fallback events

2. **Given** Prometheus metrics are enabled in LiteLLM
   **When** I create a ServiceMonitor for LiteLLM
   **Then** Prometheus automatically discovers and scrapes LiteLLM metrics
   **And** metrics appear in Prometheus UI under `litellm_*` prefix

3. **Given** LiteLLM metrics are being scraped
   **When** I query the Prometheus UI
   **Then** I can see request counts per model (`litellm_requests_metric`)
   **And** I can see latency histograms (`litellm_request_total_latency_metric`)
   **And** I can see fallback events when they occur

4. **Given** metrics are available in Prometheus
   **When** I add a LiteLLM panel to the existing ML dashboard
   **Then** operators can visualize inference routing and fallback patterns
   **And** the dashboard shows model usage distribution

5. **Given** LiteLLM has health endpoints configured
   **When** Kubernetes performs readiness probes
   **Then** the health endpoint responds within 1 second (NFR69)

## Tasks / Subtasks

⚠️ **DRAFT TASKS** - Generated from requirements analysis. Will be validated and refined against actual codebase when dev-story runs.

- [x] Task 1: Enable and verify LiteLLM metrics endpoint (AC: #1)
  - [x] Add `callbacks: ["prometheus"]` to `litellm_settings` in `applications/litellm/configmap.yaml`
  - [x] Apply updated configmap and restart LiteLLM deployment
  - [x] Verify metrics endpoint responds with Prometheus format at `/metrics/` (note: requires trailing slash)

- [x] Task 2: Create ServiceMonitor for LiteLLM (AC: #2)
  - [x] Create `monitoring/prometheus/litellm-servicemonitor.yaml` following gpu-servicemonitor pattern
  - [x] Configure ServiceMonitor to target `litellm` service in `ml` namespace
  - [x] Set scrape interval to 30s (matching existing ServiceMonitors)
  - [x] Apply ServiceMonitor and verify Prometheus target discovery

- [x] Task 3: Verify Prometheus metrics scraping (AC: #3)
  - [x] Prometheus API shows LiteLLM target as "UP" (health: up)
  - [x] Query `litellm_proxy_total_requests_metric_total` verified (showing request counts)
  - [x] Query `litellm_request_total_latency_metric_bucket` verified (histogram available)
  - [x] Test request sent to generate metrics data

- [x] Task 4: Add LiteLLM panel to Grafana dashboard (AC: #4)
  - [x] Created new `monitoring/grafana/dashboards/litellm-dashboard.yaml` (dedicated dashboard)
  - [x] Included panels for: request rate, latency percentiles (p50/p95/p99), token throughput, proxy overhead
  - [x] Applied dashboard ConfigMap with auto-discovery labels (grafana_dashboard: "1")

- [x] Task 5: Validate health endpoint response time (AC: #5)
  - [x] Verified `/health/readiness` endpoint responds in ~2-3ms (well under 1s NFR69 requirement)
  - [x] Readiness probe already configured in deployment.yaml with 5s timeout
  - [x] 5-run test averaged 2.4ms response time

## Gap Analysis

**Scan Date:** 2026-01-14 (refined by dev-story gap analysis)

✅ **What Exists:**
- `applications/litellm/deployment.yaml` - LiteLLM deployed with health probes (lines 80-95)
- `applications/litellm/configmap.yaml` - LiteLLM configuration with model fallbacks
- `applications/litellm/service.yaml` (embedded in deployment.yaml) - ClusterIP service on port 4000
- `monitoring/prometheus/gpu-servicemonitor.yaml` - Example ServiceMonitor pattern
- `monitoring/grafana/dashboards/nvidia-dcgm-dashboard.yaml` - Example Grafana dashboard ConfigMap
- Health endpoints already configured: `/health/liveliness`, `/health/readiness`
- kube-prometheus-stack deployed in `monitoring` namespace

**LiteLLM Current Configuration:**
```yaml
# From deployment.yaml - ports and health checks
ports:
  - name: http
    containerPort: 4000
readinessProbe:
  httpGet:
    path: /health/readiness
    port: http
  timeoutSeconds: 5  # NFR69 requires <1s response, probe allows 5s
```

❌ **What's Missing:**
- **Prometheus callback NOT enabled** - LiteLLM `/metrics` returns 404 (need `callbacks: ["prometheus"]`)
- ServiceMonitor for LiteLLM (`monitoring/prometheus/litellm-servicemonitor.yaml`)
- Grafana dashboard for LiteLLM metrics

**LiteLLM Metrics (expected based on LiteLLM documentation):**
- `litellm_requests_metric` - Total requests per model
- `litellm_request_total_latency_metric` - Request latency histogram
- `litellm_deployment_state` - Model deployment health
- `litellm_deployment_success_responses` / `litellm_deployment_failure_responses` - Per-deployment success/failure

**Task Validation:** Draft tasks cover all acceptance criteria. No changes needed.

---

## Dev Notes

### Previous Story Intelligence (14.3)

**Key learnings from Story 14.3:**
- LiteLLM service is accessible at `http://litellm.ml.svc.cluster.local:4000`
- Three-tier fallback is working: vLLM → Ollama → OpenAI
- Ollama cold cache requires 120s timeout (already configured)
- LiteLLM master key is set via secret for authentication

### ServiceMonitor Pattern (from gpu-servicemonitor.yaml)

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: litellm
  namespace: monitoring
  labels:
    release: kube-prometheus-stack  # Required for Prometheus discovery
spec:
  namespaceSelector:
    matchNames:
      - ml
  selector:
    matchLabels:
      app: litellm
  endpoints:
    - port: http
      interval: 30s
      path: /metrics
```

### Grafana Dashboard ConfigMap Pattern

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: litellm-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"  # Required for dashboard auto-discovery
    release: kube-prometheus-stack
data:
  litellm-dashboard.json: |
    { ... dashboard JSON ... }
```

### Architecture Constraints

- **FR118:** LiteLLM exposes Prometheus metrics for inference routing and fallback events
- **NFR69:** LiteLLM health endpoint responds within 1 second for readiness probes
- **Namespace:** ServiceMonitor must be in `monitoring` namespace with `release: kube-prometheus-stack` label

### Files to Create/Modify

- `monitoring/prometheus/litellm-servicemonitor.yaml` - NEW: ServiceMonitor for metrics scraping
- `monitoring/grafana/dashboards/litellm-dashboard.yaml` - NEW: Grafana dashboard ConfigMap

### Testing Requirements

- Verify `/metrics` endpoint returns Prometheus format data
- Verify ServiceMonitor target appears in Prometheus Targets page
- Verify metrics can be queried in Prometheus UI
- Verify dashboard appears in Grafana

### LiteLLM Metrics Reference

LiteLLM exposes the following metrics (from documentation):
- `litellm_requests_metric{model="vllm-qwen"}` - Request count by model
- `litellm_request_total_latency_metric` - Latency histogram
- `litellm_deployment_state{model_id="vllm-qwen"}` - 1 if healthy, 0 if failed
- `litellm_deployment_latency_per_output_token` - Per-token latency

### References

- [Source: docs/planning-artifacts/epics.md#Story 14.4]
- [Source: docs/planning-artifacts/prd.md#FR118, NFR69]
- [Source: monitoring/prometheus/gpu-servicemonitor.yaml - ServiceMonitor pattern]
- [Source: monitoring/grafana/dashboards/nvidia-dcgm-dashboard.yaml - Dashboard ConfigMap pattern]
- [LiteLLM Prometheus Metrics Docs: https://docs.litellm.ai/docs/proxy/prometheus]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.5 (claude-opus-4-5-20251101)

### Debug Log References

- LiteLLM `/metrics` endpoint returns 404 by default - requires `callbacks: ["prometheus"]` in litellm_settings
- LiteLLM `/metrics` redirects to `/metrics/` (trailing slash required) - ServiceMonitor configured with correct path
- Prometheus discovered target immediately after ServiceMonitor creation (~15s for first scrape)
- Health endpoint response time: 2-3ms average across 5 test runs (NFR69 satisfied)

### Completion Notes List

- Prometheus metrics now exposed at `http://litellm.ml.svc.cluster.local:4000/metrics/`
- ServiceMonitor created in `monitoring` namespace with `release: kube-prometheus-stack` label for auto-discovery
- Prometheus scraping LiteLLM every 30s with health status "up"
- Grafana dashboard created with 9 panels: request rate, failed requests, total tokens, spend, request rate by model, latency percentiles, token throughput, LLM API latency, proxy overhead
- Available metrics include: `litellm_proxy_total_requests_metric_total`, `litellm_request_total_latency_metric`, `litellm_llm_api_latency_metric`, `litellm_overhead_latency_metric`, token metrics, and more

### File List

**Created:**
- `monitoring/prometheus/litellm-servicemonitor.yaml` - ServiceMonitor for Prometheus scraping
- `monitoring/grafana/dashboards/litellm-dashboard.yaml` - Grafana dashboard ConfigMap

**Modified:**
- `applications/litellm/configmap.yaml` - Added `callbacks: ["prometheus"]` to litellm_settings

### Change Log

- 2026-01-14: Story 14.4 implemented - Prometheus metrics and monitoring for LiteLLM
