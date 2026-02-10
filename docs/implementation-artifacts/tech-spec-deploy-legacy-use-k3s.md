---
title: 'Deploy legacy-use on Home-Lab K3s'
slug: 'deploy-legacy-use-k3s'
created: '2026-02-10'
status: 'implementation-complete'
stepsCompleted: [1, 2, 3, 4]
tech_stack:
  - K3s (containerd runtime)
  - Traefik IngressRoute CRD + cert-manager (letsencrypt-prod ClusterIssuer)
  - PostgreSQL 16 (existing, data namespace, postgres-postgresql.data:5432)
  - Docker-in-Docker sidecar (docker:27-dind, privileged)
  - FastAPI backend (Python, port 8088)
  - Vite/React frontend (port 5173)
  - CoreDNS (kube-dns, ClusterIP 10.43.0.10)
files_to_modify:
  - applications/legacy-use/namespace.yaml
  - applications/legacy-use/backend-deployment.yaml
  - applications/legacy-use/frontend-deployment.yaml
  - applications/legacy-use/service.yaml
  - applications/legacy-use/ingressroute.yaml
  - applications/legacy-use/middleware.yaml
  - secrets/legacy-use-secrets.yaml
code_patterns:
  - 'Raw kubectl manifests (app.kubernetes.io/managed-by: kubectl)'
  - 'Traefik 3-part IngressRoute: Certificate + HTTPS route + HTTP redirect'
  - 'Namespace-scoped https-redirect Middleware (must create in legacy-use ns)'
  - 'ClusterIP services only — external access via Traefik'
  - 'Cross-namespace PostgreSQL via short-form DNS (postgres-postgresql.data)'
  - 'Standard labels: name, instance, component, part-of: home-lab, managed-by'
  - 'Multi-container sidecar pods (openclaw pattern: init + main + sidecars)'
  - 'Secrets via secretKeyRef or envFrom + secretRef'
  - 'CoreDNS at 10.43.0.10 for DinD --dns flag'
test_patterns:
  - 'kubectl get pods -n legacy-use (all containers Running)'
  - 'kubectl exec connectivity checks (DB, DinD docker info, RDP ports)'
  - 'curl -sk https://legacy-use.home.jetzinger.com (ingress verification)'
  - 'DinD DNS: docker run --dns 10.43.0.10 alpine nslookup brain.home.jetzinger.com'
---

# Tech-Spec: Deploy legacy-use on Home-Lab K3s

**Created:** 2026-02-10

## Overview

### Problem Statement

legacy-use is an AI-powered tool for transforming legacy applications into modern REST APIs. It needs to run on the home-lab K3s cluster for demos and development. The key challenge is that legacy-use spawns Docker containers for job execution, but K3s uses containerd — there is no `/var/run/docker.sock` on any node.

### Solution

Deploy `tjetzinger/legacy-use-backend:1.2.0` and `tjetzinger/legacy-use-frontend:1.2.0` (pre-built Docker Hub images) in a new `legacy-use` namespace. Use a Docker-in-Docker (DinD) sidecar to provide a real Docker socket to the backend with zero code changes. Use the existing PostgreSQL in the `data` namespace. Expose via Traefik IngressRoute at `legacy-use.home.jetzinger.com`. Configure DinD-spawned containers with `--dns 10.43.0.10` (CoreDNS) so they can resolve both internal K8s services and external domains.

### Scope

**In Scope:**
- New `legacy-use` namespace
- Database creation on existing PostgreSQL (`postgres-postgresql.data:5432`)
- Backend deployment with DinD sidecar (`privileged: true`)
- Frontend deployment (Vite/React)
- ClusterIP services for backend and frontend
- Traefik IngressRoute + TLS cert for `legacy-use.home.jetzinger.com`
- Namespace-scoped `https-redirect` Middleware
- Secrets management (Anthropic API key, DB password)
- DinD DNS configuration (`--dns 10.43.0.10`)

**Out of Scope:**
- VPN gateway pods for customer access (future — when customers exist, use isolated gateway pods per customer to handle overlapping subnets)
- Custom image builds (using pre-built Docker Hub images)
- Monitoring/alerting integration
- Backup CronJobs

## Context for Development

### Codebase Patterns

- **Manifest style:** Raw kubectl manifests with `app.kubernetes.io/managed-by: kubectl` (not Helm)
- **IngressRoute:** 3-part structure — Certificate (cert-manager) + HTTPS IngressRoute (websecure) + HTTP redirect IngressRoute (web). Uses `letsencrypt-prod` ClusterIssuer.
- **Middleware:** `https-redirect` is namespace-scoped, NOT cluster-wide. Must create one in the `legacy-use` namespace since we're not deploying to `apps`.
- **Services:** Always `ClusterIP`. External access exclusively through Traefik IngressRoutes.
- **Cross-namespace DB:** Short-form DNS `postgres-postgresql.data` (or FQDN `postgres-postgresql.data.svc.cluster.local`). Both work.
- **Labels:** Required on ALL resources: `app.kubernetes.io/name`, `app.kubernetes.io/instance`, `app.kubernetes.io/component`, `app.kubernetes.io/part-of: home-lab`, `app.kubernetes.io/managed-by: kubectl`
- **Multi-container pods:** openclaw pattern — initContainer for permissions, main container, sidecars with independent ports/probes/resources. Shared volumes via PVC or emptyDir.
- **Secrets:** Stored in `secrets/` (gitignored). Applied via `kubectl apply`. Referenced in deployments via `secretKeyRef` or `envFrom: secretRef`.
- **CoreDNS:** ClusterIP `10.43.0.10` (kube-dns in kube-system). DinD-spawned containers need `--dns 10.43.0.10` to resolve K8s service names and external domains.

### Files to Reference

| File | Purpose |
| ---- | ------- |
| `applications/open-webui/ingressroute.yaml` | 3-part IngressRoute + TLS pattern |
| `applications/litellm/deployment.yaml` | Raw manifest deployment (non-Helm) with labels |
| `applications/litellm/ingressroute.yaml` | IngressRoute with cert-manager Certificate |
| `applications/openclaw/deployment.yaml` | Multi-container pod: initContainer + main + sidecars |
| `applications/n8n/values-homelab.yaml` | PostgreSQL cross-namespace connection pattern |
| `monitoring/grafana/https-redirect-middleware.yaml` | Middleware definition pattern |

### Technical Decisions

- **DinD over host Docker:** K3s has no Docker. DinD sidecar (`docker:27-dind`) runs a full Docker daemon in the pod. Backend connects via `DOCKER_HOST=tcp://localhost:2375`. Zero code changes to legacy-use. Requires `privileged: true`.
- **Pre-built images:** `tjetzinger/legacy-use-backend:1.2.0` and `tjetzinger/legacy-use-frontend:1.2.0` from Docker Hub. No custom builds or registry needed.
- **CoreDNS for DinD containers:** DinD-spawned containers default to Docker's DNS, not K8s CoreDNS. Passing `--dns 10.43.0.10` ensures they resolve both internal services and external domains like `brain.home.jetzinger.com`.
- **Existing PostgreSQL:** New database + user on the shared PostgreSQL instance in `data` namespace. Connection via `postgres-postgresql.data:5432`.
- **Own namespace middleware:** Since `legacy-use` is its own namespace (not `apps`), we create a dedicated `https-redirect` Middleware there.
- **DinD storage:** `emptyDir: {}` — ephemeral, wiped on pod restart. Fine for temporary job containers.
- **Future VPN pattern (documented, not implemented):** When customers are onboarded, deploy per-customer gateway pods (OpenVPN + socat relay) as K8s services. Isolated network namespaces handle overlapping subnets. Architecture documented in `.claude/plans/flickering-drifting-wigderson.md`.

## Implementation Plan

### Tasks

- [x] Task 1: Create namespace
  - File: `applications/legacy-use/namespace.yaml`
  - Action: Create `legacy-use` namespace with standard `app.kubernetes.io/part-of: home-lab` label
  - Notes: Apply first — all other resources depend on this namespace existing

- [x] Task 2: Create database and user on existing PostgreSQL
  - Action: `kubectl exec` into `postgres-postgresql` in `data` namespace
  - Commands:
    - `CREATE DATABASE legacy_use;`
    - `CREATE USER legacy_use WITH PASSWORD '<password>';`
    - `GRANT ALL PRIVILEGES ON DATABASE legacy_use TO legacy_use;`
    - `ALTER DATABASE legacy_use OWNER TO legacy_use;`
  - Notes: Password must match what's stored in the secret (Task 3). Include `OWNER TO` so the user can create tables.

- [x] Task 3: Create secrets
  - File: `secrets/legacy-use-secrets.yaml` (gitignored)
  - Action: Create K8s Secret with:
    - `anthropic-api-key`: Anthropic API key for the backend
    - `database-url`: Full PostgreSQL connection string `postgresql://legacy_use:<pw>@postgres-postgresql.data:5432/legacy_use`
  - Notes: Use `stringData` for readability. Apply with `kubectl apply -f secrets/legacy-use-secrets.yaml -n legacy-use`. Never commit this file.

- [x] Task 4: Create backend deployment with DinD sidecar
  - File: `applications/legacy-use/backend-deployment.yaml`
  - Action: Create Deployment with two containers:
    - **backend** container: `tjetzinger/legacy-use-backend:1.2.0`, port 8088, env vars for `DATABASE_URL` (from secret), `ANTHROPIC_API_KEY` (from secret), `DOCKER_HOST=tcp://localhost:2375`. Resources: 250m/512Mi requests, 1000m/1Gi limits.
    - **dind** sidecar: `docker:27-dind`, `privileged: true`, `DOCKER_TLS_CERTDIR=""`, emptyDir volume at `/var/lib/docker`. Resources: 100m/256Mi requests, 500m/1Gi limits.
  - Labels: `app.kubernetes.io/name: legacy-use`, `component: backend`, `part-of: home-lab`, `managed-by: kubectl`
  - Notes: Backend readiness probe on `GET /health :8088` (or TCP 8088 if no health endpoint). DinD has no probe — it's a daemon.

- [x] Task 5: Create frontend deployment
  - File: `applications/legacy-use/frontend-deployment.yaml`
  - Action: Create Deployment with:
    - **frontend** container: `tjetzinger/legacy-use-frontend:1.2.0`, port 5173, env `VITE_API_URL=http://legacy-use-backend:8088`. Resources: 100m/128Mi requests, 250m/256Mi limits.
  - Labels: `app.kubernetes.io/name: legacy-use`, `component: frontend`, `part-of: home-lab`, `managed-by: kubectl`
  - Notes: Readiness probe on HTTP GET `/` port 5173.

- [x] Task 6: Create services
  - File: `applications/legacy-use/service.yaml`
  - Action: Create two ClusterIP services:
    - `legacy-use-backend`: port 8088 → targetPort 8088, selector `component: backend`
    - `legacy-use-frontend`: port 80 → targetPort 5173, selector `component: frontend`
  - Notes: Both use standard labels. Frontend service maps port 80 externally for clean ingress.

- [x] Task 7: Create https-redirect middleware
  - File: `applications/legacy-use/middleware.yaml`
  - Action: Create Traefik Middleware in `legacy-use` namespace:
    ```yaml
    apiVersion: traefik.io/v1alpha1
    kind: Middleware
    metadata:
      name: https-redirect
      namespace: legacy-use
    spec:
      redirectScheme:
        permanent: true
        scheme: https
    ```
  - Notes: Required because middleware is namespace-scoped. Cannot reference the one in `apps` namespace.

- [x] Task 8: Create IngressRoute with TLS
  - File: `applications/legacy-use/ingressroute.yaml`
  - Action: Create 3 resources:
    1. **Certificate**: `legacy-use-tls`, issuer `letsencrypt-prod` (ClusterIssuer), dnsNames `legacy-use.home.jetzinger.com`
    2. **IngressRoute (HTTPS)**: entryPoint `websecure`, match `Host(\`legacy-use.home.jetzinger.com\`)`, service `legacy-use-frontend:80`, tls secretName `legacy-use-tls`
    3. **IngressRoute (redirect)**: entryPoint `web`, same host match, middleware `https-redirect` (namespace `legacy-use`), service `legacy-use-frontend:80`
  - Notes: Follow exact pattern from `applications/open-webui/ingressroute.yaml`. Routes point to frontend service — the frontend talks to backend internally.

- [x] Task 9: Verify privileged mode support
  - Action: Check for PSP/admission controllers:
    - `kubectl get podsecuritypolicies`
    - `kubectl get validatingwebhookconfigurations`
    - `kubectl get constrainttemplates`
  - Notes: If any block `privileged: true`, address before deploying backend. K3s default is permissive.

- [x] Task 10: Apply all manifests and verify
  - Action: Apply in dependency order:
    1. `kubectl apply -f applications/legacy-use/namespace.yaml`
    2. `kubectl apply -f secrets/legacy-use-secrets.yaml -n legacy-use`
    3. `kubectl apply -f applications/legacy-use/middleware.yaml`
    4. `kubectl apply -f applications/legacy-use/backend-deployment.yaml`
    5. `kubectl apply -f applications/legacy-use/frontend-deployment.yaml`
    6. `kubectl apply -f applications/legacy-use/service.yaml`
    7. `kubectl apply -f applications/legacy-use/ingressroute.yaml`
  - Notes: Wait for backend pod to show `2/2 Running` before verifying. DinD takes ~10s to initialize.

- [x] Task 11: Configure DNS record
  - Action: Add `legacy-use.home.jetzinger.com` DNS record pointing to cluster ingress IP (same as other `*.home.jetzinger.com` records)
  - Notes: If using wildcard DNS (`*.home.jetzinger.com`), this may already resolve. Verify with `dig legacy-use.home.jetzinger.com`.

### Acceptance Criteria

- [x] AC 1: Given the `legacy-use` namespace exists, when `kubectl get ns legacy-use` is run, then the namespace is shown with status `Active`

- [x] AC 2: Given the PostgreSQL database is created, when `kubectl exec -n data statefulset/postgres-postgresql -- psql -U legacy_use -d legacy_use -c "SELECT 1"` is run, then it returns `1` successfully

- [x] AC 3: Given the backend deployment is applied, when `kubectl get pods -n legacy-use -l app.kubernetes.io/component=backend` is run, then a pod shows `2/2 Running` (backend + dind containers)

- [x] AC 4: Given the DinD sidecar is running, when `kubectl exec -n legacy-use deployment/legacy-use-backend -c dind -- docker info` is run, then Docker daemon info is returned (Server Version, Storage Driver, etc.)

- [x] AC 5: Given the DinD DNS is configured, when `kubectl exec -n legacy-use deployment/legacy-use-backend -c dind -- docker run --rm --dns 10.43.0.10 alpine nslookup legacy-use-backend.legacy-use.svc.cluster.local` is run, then the service IP is resolved successfully

- [x] AC 6: Given the DinD DNS is configured for external domains, when `kubectl exec -n legacy-use deployment/legacy-use-backend -c dind -- docker run --rm --dns 10.43.0.10 alpine nslookup brain.home.jetzinger.com` is run, then the domain resolves successfully

- [x] AC 7: Given the frontend deployment is applied, when `kubectl get pods -n legacy-use -l app.kubernetes.io/component=frontend` is run, then a pod shows `1/1 Running`

- [x] AC 8: Given the backend can reach PostgreSQL, when `kubectl exec -n legacy-use deployment/legacy-use-backend -c backend -- python -c "import urllib.request; urllib.request.urlopen('http://localhost:8088/health')"` is run (or equivalent health check), then the backend responds healthy

- [x] AC 9: Given the IngressRoute is applied and TLS cert is issued, when `kubectl get certificate -n legacy-use legacy-use-tls` is run, then the certificate shows `Ready: True`

- [x] AC 10: Given all services and ingress are configured, when `curl -sk https://legacy-use.home.jetzinger.com` is run from within the Tailscale network, then the frontend HTML is returned (200 OK)

- [x] AC 11: Given the backend service is reachable from frontend, when a job is triggered from the legacy-use UI, then the backend spawns a Docker container inside DinD and the job executes successfully

## Additional Context

### Dependencies

- **PostgreSQL:** `postgres-postgresql` service running in `data` namespace (port 5432). Must be accessible cross-namespace.
- **Traefik:** Running in `kube-system` with entryPoints `web` (80) and `websecure` (443) configured.
- **cert-manager:** `letsencrypt-prod` ClusterIssuer must exist in `infra` namespace and be functional.
- **CoreDNS:** `kube-dns` service at `10.43.0.10` in `kube-system`. Required for DinD `--dns` flag.
- **DNS:** `legacy-use.home.jetzinger.com` must resolve to the cluster's ingress IP (MetalLB or node IP).
- **Docker Hub access:** Worker nodes must be able to pull from Docker Hub (`tjetzinger/legacy-use-backend:1.2.0`, `tjetzinger/legacy-use-frontend:1.2.0`, `docker:27-dind`).

### Testing Strategy

**Automated verification (post-deploy script):**
```bash
#!/bin/bash
set -e
echo "=== legacy-use deployment verification ==="

echo "1. Namespace..."
kubectl get ns legacy-use

echo "2. Pods (expecting backend 2/2, frontend 1/1)..."
kubectl get pods -n legacy-use

echo "3. DinD Docker daemon..."
kubectl exec -n legacy-use deployment/legacy-use-backend -c dind -- docker info | head -5

echo "4. DinD DNS (internal)..."
kubectl exec -n legacy-use deployment/legacy-use-backend -c dind -- \
  docker run --rm --dns 10.43.0.10 alpine nslookup legacy-use-backend.legacy-use.svc.cluster.local

echo "5. DinD DNS (external)..."
kubectl exec -n legacy-use deployment/legacy-use-backend -c dind -- \
  docker run --rm --dns 10.43.0.10 alpine nslookup brain.home.jetzinger.com

echo "6. TLS certificate..."
kubectl get certificate -n legacy-use legacy-use-tls

echo "7. Ingress (via curl)..."
curl -sk https://legacy-use.home.jetzinger.com | head -5

echo "=== All checks passed ==="
```

**Manual verification:**
- Open `https://legacy-use.home.jetzinger.com` in browser via Tailscale
- Trigger a job from the UI and confirm it executes
- Check DinD for spawned containers: `kubectl exec -n legacy-use deployment/legacy-use-backend -c dind -- docker ps`

### Notes

- **Risk: Privileged mode blocked.** If K3s has admission controllers blocking `privileged: true`, the DinD sidecar won't start. Mitigation: check PSP/webhooks in Task 9 before deploying.
- **Risk: Docker Hub rate limits.** If the cluster pulls images frequently, Docker Hub anonymous rate limits (100 pulls/6h) may throttle. Mitigation: use `imagePullPolicy: IfNotPresent` so images are pulled once and cached.
- **Known limitation:** DinD storage is ephemeral (`emptyDir`). Job container images are re-pulled on every pod restart. If this becomes a performance issue, consider a PVC for `/var/lib/docker`.
- **Future: VPN gateway pods.** When customers are onboarded, deploy per-customer OpenVPN + socat gateway pods as K8s services. Each pod has its own network namespace, handling overlapping subnets (e.g., both on `192.168.0.0/24`). Architecture documented in `.claude/plans/flickering-drifting-wigderson.md`.
- **Future: DinD Docker daemon configuration.** If legacy-use needs to pass `--dns 10.43.0.10` to every spawned container, this may need to be configured in the DinD daemon config (`/etc/docker/daemon.json` with `"dns": ["10.43.0.10"]`) rather than per-container. Evaluate during Task 10 verification.
