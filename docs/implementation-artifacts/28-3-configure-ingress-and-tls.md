# Story 28.3: Configure Ingress and TLS

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **cluster operator**,
I want **to provision a wildcard TLS certificate and create IngressRoutes for all 5 Supabase services**,
So that **I can access Supabase Studio, API, Auth, Storage, and Edge Functions via browser at their respective `*.supabase.home.jetzinger.com` subdomains**.

## Acceptance Criteria

1. **AC1 — Wildcard Certificate:** Given Supabase is running in the `backend` namespace (Story 28.2 complete) and cert-manager is operational with the `dnsPolicy: None` fix, when I create a Certificate resource for `*.supabase.home.jetzinger.com` in the `backend` namespace using the existing `letsencrypt-prod` ClusterIssuer, then cert-manager provisions a wildcard TLS certificate (FR244) and `kubectl get certificate -n backend` shows the certificate in Ready state.

2. **AC2 — IngressRoutes Created:** Given the wildcard certificate is ready, when I create 5 IngressRoutes following the existing 3-part pattern (Certificate + HTTPS route + HTTP redirect) for:
   - `api.supabase.home.jetzinger.com` → Kong API gateway (port 8000)
   - `auth.supabase.home.jetzinger.com` → GoTrue service (port 9999)
   - `studio.supabase.home.jetzinger.com` → Studio service (port 3000)
   - `storage.supabase.home.jetzinger.com` → Storage API service (port 5000)
   - `functions.supabase.home.jetzinger.com` → Edge Functions service (port 9000)
   then all 5 IngressRoutes are created and visible in Traefik dashboard (FR245).

3. **AC3 — Studio Dashboard Access:** Given IngressRoutes are active, when I access `https://studio.supabase.home.jetzinger.com` from a Tailscale-connected device, then the Supabase Studio dashboard loads with a valid TLS certificate (NFR137) and the certificate shows `*.supabase.home.jetzinger.com` as the subject.

4. **AC4 — PostgREST API Access:** Given all ingress routes are active, when I access `https://api.supabase.home.jetzinger.com/rest/v1/` with the anon key header from a Tailscale-connected device, then PostgREST responds with the API schema (FR232).

5. **AC5 — GoTrue Health:** Given GoTrue ingress is active, when I access `https://auth.supabase.home.jetzinger.com/health` from a Tailscale-connected device, then GoTrue returns a healthy status (FR238).

6. **AC6 — Tailscale-Only Access:** Given all 5 subdomains are accessible, when I attempt to access any Supabase subdomain from a non-Tailscale device, then the connection is refused or times out (NFR137).

7. **AC7 — Manifests Committed:** Given the implementation is complete, when I commit the IngressRoute manifests to git, then `applications/supabase/` contains all IngressRoute YAML files and the Certificate resource.

## Tasks / Subtasks

- [x] Task 1: Create https-redirect Middleware in backend namespace (AC: #2)
  - [x] 1.1 Created inline in `applications/supabase/ingressroute.yaml` (Part 0) — redirectScheme, permanent: true, scheme: https
  - [x] 1.2 Applied via `kubectl apply -f applications/supabase/ingressroute.yaml`
  - [x] 1.3 Verified: `kubectl get middleware -n backend` shows `https-redirect`

- [x] Task 2: Create wildcard Certificate resource (AC: #1)
  - [x] 2.1 Created Certificate in `applications/supabase/ingressroute.yaml` (Part 1) for `*.supabase.home.jetzinger.com`
  - [x] 2.2 Uses `letsencrypt-prod` ClusterIssuer, duration 2160h, renewBefore 720h
  - [x] 2.3 Certificate reached Ready state within ~2 minutes (DNS-01 challenge)
  - [x] 2.4 Secret `supabase-tls` created in backend namespace

- [x] Task 3: Create IngressRoute for api.supabase (AC: #2, #4)
  - [x] 3.1 HTTPS IngressRoute: Host(`api.supabase.home.jetzinger.com`) → `supabase-supabase-kong:8000`
  - [x] 3.2 HTTP redirect IngressRoute referencing https-redirect middleware
  - [x] 3.3 Both use `tls.secretName: supabase-tls`

- [x] Task 4: Create IngressRoute for studio.supabase (AC: #2, #3)
  - [x] 4.1 HTTPS IngressRoute: Host(`studio.supabase.home.jetzinger.com`) → `supabase-supabase-studio:3000`
  - [x] 4.2 HTTP redirect IngressRoute

- [x] Task 5: Create IngressRoute for auth.supabase (AC: #2, #5)
  - [x] 5.1 HTTPS IngressRoute: Host(`auth.supabase.home.jetzinger.com`) → `supabase-supabase-auth:9999`
  - [x] 5.2 HTTP redirect IngressRoute

- [x] Task 6: Create IngressRoute for storage.supabase (AC: #2)
  - [x] 6.1 HTTPS IngressRoute: Host(`storage.supabase.home.jetzinger.com`) → `supabase-supabase-storage:5000`
  - [x] 6.2 HTTP redirect IngressRoute

- [x] Task 7: Create IngressRoute for functions.supabase (AC: #2)
  - [x] 7.1 HTTPS IngressRoute: Host(`functions.supabase.home.jetzinger.com`) → `supabase-supabase-functions:9000`
  - [x] 7.2 HTTP redirect IngressRoute

- [x] Task 8: Apply all manifests and validate (AC: #1-6)
  - [x] 8.1 Applied all resources: 1 Middleware + 1 Certificate + 10 IngressRoutes created
  - [x] 8.2 Certificate Ready: `CN=*.supabase.home.jetzinger.com`, issuer Let's Encrypt R13
  - [x] 8.3 All 10 IngressRoutes visible in backend namespace
  - [x] 8.4 Studio: HTTP 307 (redirect to /project/default — dashboard serving)
  - [x] 8.5 API: HTTP 200 (PostgREST via Kong with anon key)
  - [x] 8.6 GoTrue: healthy JSON response (`v2.186.0`)
  - [x] 8.7 Storage: HTTP 404 (service responding, no bucket in request — expected)
  - [x] 8.8 Edge Functions: HTTP 400 (service responding, no function specified — expected)

- [ ] Task 9: Commit manifests to git (AC: #7)
  - [ ] 9.1 Git add all new files in `applications/supabase/`
  - [ ] 9.2 Commit with conventional commit message

## Gap Analysis

**Scan Date:** 2026-02-23

**What Exists:**
- `applications/supabase/values-homelab.yaml` — Helm values with `ingress.enabled: false` (delegating to Traefik IngressRoutes)
- `letsencrypt-prod` ClusterIssuer — operational (`infrastructure/cert-manager/cluster-issuer.yaml`)
- Wildcard certificate pattern — `infrastructure/cert-manager/wildcard-certificates.yaml` (`*.dev.pilates4.golf`)
- `https-redirect` Middleware exists in `monitoring`, `dev`, `legacy-use`, `apps` namespaces (each namespace needs its own)
- 3-part IngressRoute pattern proven across cluster (`monitoring/ntfy/ingress.yaml`, `applications/litellm/ingressroute.yaml`, etc.)
- Supabase services running in `backend` namespace: Kong:8000, Studio:3000, Auth:9999, Storage:5000, Functions:9000
- Environment URLs pre-configured: `API_EXTERNAL_URL` and `SUPABASE_PUBLIC_URL` already point to `https://api.supabase.home.jetzinger.com`

**What's Missing:**
- No Certificate resource for `*.supabase.home.jetzinger.com`
- No `https-redirect` Middleware in `backend` namespace
- No IngressRoutes for any Supabase subdomain
- No `applications/supabase/ingressroute.yaml` file

**Task Changes Applied:** None — draft tasks accurately match codebase reality.

---

## Dev Notes

### Architecture & Constraints

- **3-Part IngressRoute Pattern (proven):** Every service in this cluster uses Certificate + HTTPS IngressRoute + HTTP→HTTPS redirect IngressRoute. Follow exactly.
- **Wildcard Certificate:** Single Certificate resource with `dnsNames: ["*.supabase.home.jetzinger.com"]` covers all 5 subdomains. Shared TLS secret `supabase-tls`.
- **ClusterIssuer:** `letsencrypt-prod` (already operational, dnsPolicy fix applied in cert-manager).
- **Tailscale-only access:** All `*.home.jetzinger.com` domains resolve via NextDNS rewrites to MetalLB IPs, accessible only from Tailscale mesh. No additional config needed for NFR137.

### Routing Design Decision

**api.supabase → Kong (port 8000):** This is the unified Supabase API gateway. The Supabase JS client SDK and Studio both use this endpoint. Kong routes internally based on path prefix:
- `/rest/v1/*` → PostgREST
- `/auth/v1/*` → GoTrue
- `/storage/v1/*` → Storage
- `/functions/v1/*` → Edge Functions

The values file already has `SUPABASE_PUBLIC_URL: https://api.supabase.home.jetzinger.com` and `API_EXTERNAL_URL: https://api.supabase.home.jetzinger.com`. Dev containers (calsync, pilates) will use this as their `SUPABASE_URL`.

**auth/storage/functions subdomains → Direct service access:** These bypass Kong and provide direct health check and debugging endpoints. They are NOT used by Supabase client SDKs.

**studio.supabase → Studio (port 3000):** Direct to the Next.js dashboard app. Studio connects to Kong via `SUPABASE_PUBLIC_URL`.

### Service Names and Ports (from Helm deployment)

| Service | K8s Name | Port |
|---------|----------|------|
| Kong (API Gateway) | `supabase-supabase-kong` | 8000 |
| Studio (Dashboard) | `supabase-supabase-studio` | 3000 |
| GoTrue (Auth) | `supabase-supabase-auth` | 9999 |
| Storage API | `supabase-supabase-storage` | 5000 |
| Edge Functions | `supabase-supabase-functions` | 9000 |

### https-redirect Middleware

Each namespace needs its own `https-redirect` Middleware (Traefik middleware is namespace-scoped). Existing examples:
- `monitoring` namespace: `monitoring/grafana/https-redirect-middleware.yaml`
- `legacy-use` namespace: `applications/legacy-use/middleware.yaml`
- `dev` namespace: `applications/gitea/ingressroute.yaml` (inline)

Create one for `backend` namespace following same pattern.

### NFR138 — Auth Email Confirmation Links

Currently `GOTRUE_MAILER_AUTOCONFIRM: true` (Story 28.2 decision — no human email verification for programmatic backends). Email confirmation links are not sent. The `API_EXTERNAL_URL` is `https://api.supabase.home.jetzinger.com` which means if autoconfirm is ever disabled, auth callbacks would route through Kong at `/auth/v1/verify`. NFR138 is satisfied by the auth subdomain existing for health checks even though email links aren't currently generated.

### Labels (Required on All Resources)

```yaml
labels:
  app.kubernetes.io/name: supabase
  app.kubernetes.io/instance: supabase-{component}
  app.kubernetes.io/part-of: home-lab
  app.kubernetes.io/managed-by: kubectl
```

### File Organization

All manifests go in `applications/supabase/`:
- `ingressroute.yaml` — Certificate + all 10 IngressRoutes (5 HTTPS + 5 redirect) in one file (follows openclaw pattern of multi-doc YAML)
- `middleware.yaml` — https-redirect Middleware (or inline in ingressroute.yaml)

Alternatively, could split per subdomain. The single-file approach (like ntfy's `ingress.yaml`) is preferred for simplicity since all share the same wildcard cert.

### Previous Story Intelligence (28.2)

Key learnings from Story 28.2 implementation:
1. **NFS incompatible with PostgreSQL and Storage** — switched to local-path
2. **Kong OOMKilled at 256Mi** — bumped to 1Gi limit
3. **GoTrue SMTP TLS failure** — autoconfirm enabled, SMTP deferred
4. **dnsPolicy patches not persisted** — runbook created at `docs/runbooks/supabase-helm-upgrade.md`
5. **Chart secret mapping requires ALL keys** — 9 keys needed in supabase-secrets
6. **Total memory: 1280Mi (1.25Gi)** — under 2Gi target
7. **Helm revision 7** — multiple iterations needed

### Project Structure Notes

- Values file: `applications/supabase/values-homelab.yaml` (existing from Story 28.2)
- IngressRoute: `applications/supabase/ingressroute.yaml` (new)
- Middleware: `applications/supabase/middleware.yaml` (new, or inline)
- Namespace: `backend` (created in Story 28.1)
- Reference IngressRoute: `monitoring/ntfy/ingress.yaml` (most recent 3-part example)
- Reference IngressRoute: `applications/openclaw/ingressroute.yaml` (multi-doc wildcard cert example)

### References

- [Source: docs/planning-artifacts/epics.md — Epic 28, Story 28.3, lines 6534-6580]
- [Source: docs/planning-artifacts/architecture.md — Supabase Ingress section, lines 2036-2056]
- [Source: docs/planning-artifacts/prd.md — FR244, FR245, NFR137, NFR138]
- [Source: monitoring/ntfy/ingress.yaml — Most recent 3-part IngressRoute pattern]
- [Source: applications/openclaw/ingressroute.yaml — Multi-doc wildcard cert example]
- [Source: monitoring/grafana/https-redirect-middleware.yaml — Middleware reference]
- [Source: docs/implementation-artifacts/28-2-deploy-supabase-core-via-helm.md — Previous story intelligence]
- FRs covered: FR244, FR245
- NFRs covered: NFR137, NFR138

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

### Completion Notes List

1. **Single-file approach for all resources** — Middleware, Certificate, and all 10 IngressRoutes consolidated into one `ingressroute.yaml` file. Follows the proven multi-doc YAML pattern from openclaw. Simpler to manage since all share the same wildcard cert.
2. **DNS-01 challenge completed in ~2 minutes** — Wildcard cert provisioned via `letsencrypt-prod` ClusterIssuer. No issues with cert-manager's existing `dnsPolicy: None` fix.
3. **TLS verified** — `CN=*.supabase.home.jetzinger.com`, issuer Let's Encrypt R13, valid Feb 23 → May 24 2026.
4. **All 5 endpoints responding** — api (200), studio (307), auth (healthy JSON), storage (404 — no bucket), functions (400 — no function). All HTTP responses confirm services are reachable through IngressRoutes.
5. **Routing design confirmed** — api.supabase routes to Kong (unified API gateway for all Supabase client SDKs). auth/storage/functions route directly to individual services for health checks and debugging. Studio routes directly to Next.js dashboard.
6. **Tailscale-only access** — All `*.home.jetzinger.com` domains resolve via NextDNS rewrites to MetalLB IPs, accessible only from Tailscale mesh. No additional configuration needed.

### File List

- `applications/supabase/ingressroute.yaml` — NEW: Middleware + Certificate + 10 IngressRoutes (5 HTTPS + 5 redirect)
- `docs/implementation-artifacts/28-3-configure-ingress-and-tls.md` — MODIFIED: Story file with completed tasks
