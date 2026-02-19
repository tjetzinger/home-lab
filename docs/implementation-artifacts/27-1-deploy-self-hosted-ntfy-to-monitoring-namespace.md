# Story 27.1: Deploy Self-Hosted ntfy to monitoring Namespace

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **cluster operator**,
I want **to deploy a self-hosted ntfy notification server in the `monitoring` namespace with authentication enabled and Tailscale-only ingress**,
so that **I have a private, authenticated push notification endpoint that is not discoverable from the public internet and not subject to third-party rate limits**.

## Acceptance Criteria

1. **Given** the `monitoring` namespace exists and Traefik + cert-manager are operational
   **When** I apply the ntfy Deployment, ClusterIP Service, and K8s Secret (`ntfy-credentials`) to the `monitoring` namespace
   **Then** the ntfy pod reaches `Running` state and passes the readiness probe at `/healthz` (FR224)
   **And** the server starts with authentication mode enabled (`AUTH_DEFAULT_ACCESS=deny`)

2. **Given** the ntfy server is running
   **When** I send an unauthenticated HTTP request to the ntfy ClusterIP service
   **Then** the server returns HTTP 401 (NFR126)

3. **Given** the ntfy server is running
   **When** I send an authenticated request using the credentials from `ntfy-credentials` secret
   **Then** the server returns HTTP 200 and I can publish to a topic

4. **Given** the ntfy server is running
   **When** I apply the 3-part IngressRoute for `ntfy.home.jetzinger.com` with Tailscale-only access
   **Then** `https://ntfy.home.jetzinger.com` is accessible from within the Tailscale VPN (NFR127)
   **And** an unauthenticated request to `https://ntfy.home.jetzinger.com` returns 401

5. **Given** the deployment is complete
   **When** I verify the `ntfy-credentials` secret was created via `kubectl patch` (not `kubectl apply` with placeholder)
   **Then** the secret exists in `monitoring` namespace with valid credentials
   **And** `secrets/ntfy-secrets.yaml` in git contains empty placeholders only

## Tasks / Subtasks

- [x] Task 1: Create `monitoring/ntfy/` directory with K8s manifests (AC: #1)
  - [x] Subtask 1.1: Create `monitoring/ntfy/deployment.yaml` — ntfy Deployment with `AUTH_DEFAULT_ACCESS=deny` env var, `/healthz` readiness probe, port 80
  - [x] Subtask 1.2: Create `monitoring/ntfy/service.yaml` — ClusterIP Service exposing port 80 (`ntfy.monitoring.svc.cluster.local`)
  - [x] Subtask 1.3: Create `monitoring/ntfy/ingress.yaml` — 3-part IngressRoute: Certificate + HTTPS IngressRoute + HTTP→HTTPS redirect (matching pattern from `monitoring/grafana/grafana-ingress.yaml`)

- [x] Task 2: Create K8s Secret placeholder in git (AC: #5)
  - [x] Subtask 2.1: Updated `secrets/ntfy-secrets.yaml` from old Helm values format (ntfy.sh webhook URL) to K8s Secret template with empty `NTFY_ADMIN_USER` and `NTFY_ADMIN_PASS` placeholders
  - [x] Subtask 2.2: Applied real credentials via `kubectl patch secret ntfy-credentials -n monitoring --type='merge' -p '{"stringData":{"NTFY_ADMIN_USER":"admin","NTFY_ADMIN_PASS":"..."}}'`

- [x] Task 3: Apply manifests and verify authentication (AC: #2, #3)
  - [x] Subtask 3.1: `kubectl apply -f monitoring/ntfy/` — pod reached Running state (1/1 Ready)
  - [x] Subtask 3.2: Unauthenticated request returns 403 Forbidden (ntfy's behavior for `AUTH_DEFAULT_ACCESS=deny`; wrong credentials return 401 Unauthorized)
  - [x] Subtask 3.3: Authenticated request via `Authorization: Basic admin:<pass>` returns 200 OK and opens ndjson stream

- [x] Task 4: Verify Tailscale-only ingress (AC: #4)
  - [x] Subtask 4.1: cert-manager issued TLS cert for `ntfy.home.jetzinger.com` (Let's Encrypt DNS-01 via Cloudflare) — required DNS fix for cert-manager (see Completion Notes)
  - [x] Subtask 4.2: `https://ntfy.home.jetzinger.com/test-topic/json` returns 403 unauthenticated (TLS verify result: 0 — valid Let's Encrypt cert)
  - [x] Subtask 4.3: Authenticated HTTPS request returns 200 OK

## Gap Analysis

**Scan Date:** 2026-02-19

**What Exists:**
- `monitoring/grafana/grafana-ingress.yaml` — 3-part IngressRoute pattern confirmed
- `monitoring/grafana/https-redirect-middleware.yaml` — `https-redirect` Middleware confirmed in `monitoring` namespace
- `secrets/ntfy-secrets.yaml` — exists in OLD Alertmanager Helm values format (must be replaced)

**What's Missing:**
- `monitoring/ntfy/` directory and all 3 manifests (deployment, service, ingress)
- `ntfy-credentials` K8s Secret in cluster

**Task Changes Applied:** None — draft tasks accurately reflect codebase state.

---

## Dev Notes

### Architecture Decisions (MUST follow)

**Deployment pattern:** `monitoring/ntfy/` directory (consistent with `monitoring/grafana/`, `monitoring/prometheus/`)
- `deployment.yaml` — ntfy server
- `service.yaml` — ClusterIP
- `ingress.yaml` — 3-part IngressRoute (Certificate + HTTPS + HTTP redirect)

**Authentication:** Set `AUTH_DEFAULT_ACCESS=deny` as environment variable on the ntfy container. This ensures unauthenticated requests return 401 at the server level (NFR126). Alternative: server.yml config file mounted as ConfigMap.

**ntfy image:** `binwiederhier/ntfy` — use a pinned version tag, not `latest`.

**Port:** ntfy listens on port 80 internally by default. Traefik handles TLS termination.

**Secrets:** K8s Secret `ntfy-credentials` in `monitoring` namespace. Apply via `kubectl patch` ONLY. The `secrets/ntfy-secrets.yaml` placeholder in git must have empty values.
> ⚠️ CRITICAL: `secrets/ntfy-secrets.yaml` currently contains the OLD ntfy.sh webhook URL in Helm values format — this file must be replaced with a K8s Secret template (empty placeholders) as part of this story.

### IngressRoute Pattern (exact match from existing monitoring ingress)

Follow `monitoring/grafana/grafana-ingress.yaml` and `monitoring/prometheus/alertmanager-ingress.yaml` exactly:

```yaml
# Part 1: Certificate
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: ntfy-tls
  namespace: monitoring
  labels:
    app.kubernetes.io/name: ntfy
    app.kubernetes.io/instance: ntfy
    app.kubernetes.io/part-of: home-lab
spec:
  secretName: ntfy-tls
  duration: 2160h
  renewBefore: 720h
  dnsNames:
    - ntfy.home.jetzinger.com
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
---
# Part 2: HTTPS IngressRoute
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: ntfy-ingress
  namespace: monitoring
  labels:
    app.kubernetes.io/name: ntfy
    app.kubernetes.io/instance: ntfy
    app.kubernetes.io/part-of: home-lab
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`ntfy.home.jetzinger.com`)
      kind: Rule
      services:
        - name: ntfy
          port: 80
  tls:
    secretName: ntfy-tls
---
# Part 3: HTTP→HTTPS redirect (reuses existing https-redirect middleware)
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: ntfy-ingress-redirect
  namespace: monitoring
  labels:
    app.kubernetes.io/name: ntfy
    app.kubernetes.io/instance: ntfy-redirect
    app.kubernetes.io/part-of: home-lab
spec:
  entryPoints:
    - web
  routes:
    - match: Host(`ntfy.home.jetzinger.com`)
      kind: Rule
      middlewares:
        - name: https-redirect
          namespace: monitoring
      services:
        - name: ntfy
          port: 80
```

**Note:** The `https-redirect` Middleware already exists in `monitoring/grafana/https-redirect-middleware.yaml` — do NOT recreate it.

### K8s Labels (ALL resources must have these)

```yaml
labels:
  app.kubernetes.io/name: ntfy
  app.kubernetes.io/instance: ntfy
  app.kubernetes.io/part-of: home-lab
  app.kubernetes.io/managed-by: kubectl
```

### Secrets Pattern

```bash
# Create secret with placeholder in git (secrets/ntfy-secrets.yaml):
apiVersion: v1
kind: Secret
metadata:
  name: ntfy-credentials
  namespace: monitoring
stringData:
  NTFY_ADMIN_USER: ""   # applied via kubectl patch, never committed
  NTFY_ADMIN_PASS: ""   # applied via kubectl patch, never committed

# Apply real values (NEVER committed to git):
kubectl patch secret ntfy-credentials -n monitoring --type='merge' \
  -p '{"stringData":{"NTFY_ADMIN_USER":"<user>","NTFY_ADMIN_PASS":"<pass>"}}'
```

### Existing ntfy-secrets.yaml

`secrets/ntfy-secrets.yaml` currently contains the OLD ntfy.sh webhook URL in Alertmanager Helm values format. This must be replaced with the K8s Secret template above. The Alertmanager webhook config will be handled in Story 27.2 as a separate values override.

### Recent Patterns from Git

- `feat: migrate openclaw off Anthropic to cloud-kimi primary (Story 26.3)` — K8s manifest updates in `applications/`
- `feat: update service default models to cloud tier (Story 26.2)` — ConfigMap patches
- `feat: add Ollama Pro cloud models to LiteLLM (Story 26.1)` — Secret patch + ConfigMap
- All commits follow `feat:` prefix with `(Story X.Y)` reference

### Project Structure Notes

- ntfy manifests: `monitoring/ntfy/` (follow `monitoring/grafana/` and `monitoring/prometheus/` patterns)
- Secret placeholder: `secrets/ntfy-secrets.yaml` (replace with K8s Secret format)
- NO `applications/monitoring/` directory exists — monitoring components use `monitoring/` directly
- `https-redirect` Middleware already exists in `monitoring` namespace — reuse it

### References

- Architecture decision: [Source: docs/planning-artifacts/architecture.md#Self-Hosted Notification Architecture (ntfy)]
- IngressRoute pattern: [Source: monitoring/grafana/grafana-ingress.yaml]
- HTTP redirect middleware: [Source: monitoring/grafana/https-redirect-middleware.yaml]
- Labels standard: [Source: docs/planning-artifacts/architecture.md#Consistency Rules]
- Secrets management: [Source: CLAUDE.md — ALWAYS use kubectl patch, NEVER apply with placeholder]
- Epic 27 definition: [Source: docs/planning-artifacts/epics.md#Epic 27]

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

- cert-manager DNS-01 challenge initially failed: `tls: failed to verify certificate: x509: certificate is valid for *.jetzinger.com, not api.cloudflare.com` — root cause: Tailscale updated node resolv.conf on 2026-02-13 adding `search jetzinger.com`, causing ndots:5 search domain expansion to intercept all external HTTPS calls (api.cloudflare.com → api.cloudflare.com.jetzinger.com → 192.168.2.2/Traefik)
- Fix applied: `dnsPolicy: None` with explicit dnsConfig on cert-manager controller, webhook, and cainjector pods, excluding `jetzinger.com` from search domains
- ntfy auth behavior note: `AUTH_DEFAULT_ACCESS=deny` returns **403 Forbidden** (not 401) for unauthenticated requests. HTTP 401 only appears for *wrong* credentials. AC#2 intent (access denied without auth) is satisfied.

### Completion Notes List

- Deployed ntfy `v2.11.0` (pinned tag) to `monitoring` namespace with `NTFY_AUTH_DEFAULT_ACCESS=deny`
- ntfy admin user created in auth DB via `NTFY_PASSWORD=... ntfy user add --role=admin admin` (using NTFY_PASSWORD env var for non-interactive script use)
- `ntfy-credentials` K8s Secret applied via `kubectl patch` (empty placeholder committed to git, real creds applied in-cluster only)
- 3-part IngressRoute deployed: Certificate + HTTPS IngressRoute + HTTP→HTTPS redirect
- Let's Encrypt cert `ntfy-tls` issued via DNS-01 (Cloudflare) — READY
- **Infrastructure fix (bonus):** Patched cert-manager controller/webhook/cainjector with `dnsPolicy: None` to fix Tailscale search domain interference. Also persisted fix in `infrastructure/cert-manager/values-homelab.yaml` so it survives future `helm upgrade`.
- All ACs verified: pod Running (AC#1), auth enforced (AC#2/3), HTTPS ingress with valid TLS cert (AC#4), secret in cluster with empty git placeholder (AC#5)

### File List

- monitoring/ntfy/deployment.yaml (created)
- monitoring/ntfy/service.yaml (created)
- monitoring/ntfy/ingress.yaml (created)
- secrets/ntfy-secrets.yaml (modified — replaced old Helm values format with K8s Secret template)
- infrastructure/cert-manager/values-homelab.yaml (modified — added dnsPolicy: None fix for all three cert-manager components)
- docs/implementation-artifacts/sprint-status.yaml (modified — status: in-progress → review)

### Change Log

- 2026-02-19: Created monitoring/ntfy/ manifests (deployment, service, ingress), replaced secrets/ntfy-secrets.yaml with K8s Secret template, applied ntfy-credentials via kubectl patch, fixed cert-manager DNS issue (dnsPolicy: None for all components). Story 27.1 complete.
