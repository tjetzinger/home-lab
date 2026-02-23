# Story 28.1: Prepare Infrastructure (Namespace, RAM, Secrets)

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **cluster operator**,
I want **to create the `backend` namespace, upgrade worker-01 RAM to 24Gi, and prepare Supabase secrets**,
So that **the cluster has adequate resources and secure credential management ready for the Supabase deployment**.

## Acceptance Criteria

1. **AC1 — Worker-01 RAM upgrade:** Given the cluster is running and Proxmox host has ~39Gi available memory, when I increase the k3s-worker-01 VM memory from 16Gi to 24Gi in Proxmox (hot-plug or VM restart), then `kubectl top node k3s-worker-01` reports ~24Gi total allocatable memory (FR228) and all existing pods on worker-01 continue running without disruption.

2. **AC2 — Backend namespace creation:** Given worker-01 has 24Gi RAM, when I create the `backend` namespace with `kubectl create namespace backend`, then the namespace exists and is ready for workload scheduling (FR227).

3. **AC3 — Secret placeholder file:** Given the `backend` namespace exists, when I create `secrets/supabase-secrets.yaml` with empty placeholder values for `POSTGRES_PASSWORD`, `JWT_SECRET`, `ANON_KEY`, `SERVICE_ROLE_KEY`, `GOTRUE_SMTP_PASS`, and `DASHBOARD_PASSWORD`, then the file is committed to git with empty placeholders only (FR246) and no real secret values are present in the committed file.

4. **AC4 — Real secrets applied:** Given the placeholder secret file exists in git, when I generate real values (JWT secret, derived ANON_KEY and SERVICE_ROLE_KEY, PostgreSQL password, Resend API key, dashboard password) and apply them via `kubectl patch secret supabase-secrets -n backend --type='merge' -p '{"stringData":{...}}'`, then the secret is created in the `backend` namespace with all required keys populated (FR247) and `kubectl get secret supabase-secrets -n backend` confirms the secret exists with 6 data keys (NFR136).

5. **AC5 — Node affinity label:** Given secrets are applied, when I verify node affinity labels on worker-01, then `kubernetes.io/hostname: k3s-worker-01` label is present and can be used for pod scheduling (FR229).

## Tasks / Subtasks

⚠️ **DRAFT TASKS** - Generated from requirements analysis. Will be validated and refined against actual codebase when dev-story runs.

- [x] Task 1: Upgrade k3s-worker-01 VM RAM from 16Gi to 24Gi in Proxmox (AC: #1)
  - [x] 1.1 Log into Proxmox VE and increase k3s-worker-01 VM memory to 24Gi (hot-plug preferred, VM restart if needed)
  - [x] 1.2 Verify `kubectl top node k3s-worker-01` shows ~24Gi allocatable memory
  - [x] 1.3 Verify all existing pods on worker-01 remain Running without disruption

- [x] Task 2: Create `backend` namespace (AC: #2)
  - [x] 2.1 Run `kubectl create namespace backend`
  - [x] 2.2 Verify namespace exists with `kubectl get namespace backend`

- [x] Task 3: Create secret placeholder file (AC: #3)
  - [x] 3.1 Create `secrets/supabase-secrets.yaml` following the ntfy-secrets pattern (K8s Secret with `stringData`, empty values, comment header with Story/Epic/FR traceability, standard labels)
  - [x] 3.2 Include 6 keys: `POSTGRES_PASSWORD`, `JWT_SECRET`, `ANON_KEY`, `SERVICE_ROLE_KEY`, `GOTRUE_SMTP_PASS`, `DASHBOARD_PASSWORD`
  - [x] 3.3 Apply the empty placeholder to create the Secret object: `kubectl apply -f secrets/supabase-secrets.yaml`

- [x] Task 4: Generate and apply real secret values (AC: #4)
  - [x] 4.1 Generate `POSTGRES_PASSWORD` (random secure password via openssl)
  - [x] 4.2 Generate `JWT_SECRET` (48-byte random string via openssl)
  - [x] 4.3 Generate `ANON_KEY` — JWT signed with `JWT_SECRET` containing `role: anon` claim (HS256, 10yr expiry)
  - [x] 4.4 Generate `SERVICE_ROLE_KEY` — JWT signed with `JWT_SECRET` containing `role: service_role` claim (HS256, 10yr expiry)
  - [x] 4.5 Set `GOTRUE_SMTP_PASS` to protonmail-bridge password (cluster-local SMTP via protonmail-bridge.docs.svc:25, replacing Resend)
  - [x] 4.6 Generate `DASHBOARD_PASSWORD` (random secure password via openssl)
  - [x] 4.7 Apply all real values via `kubectl patch secret supabase-secrets -n backend --type='merge'`
  - [x] 4.8 Verify secret with `kubectl get secret supabase-secrets -n backend` — confirmed 6 data keys

- [x] Task 5: Verify node affinity label (AC: #5)
  - [x] 5.1 Confirm `kubernetes.io/hostname=k3s-worker-01` label is present (pre-verified during gap analysis — label exists by default on K8s nodes)

## Gap Analysis

**Scan Date:** 2026-02-23

**What Exists:**
- `kubernetes.io/hostname=k3s-worker-01` label already present on node (default K8s label)
- Worker-01 currently at 16Gi allocatable, 60% usage (9899Mi)

**What's Missing:**
- `backend` namespace does not exist
- `secrets/supabase-secrets.yaml` file does not exist
- `supabase-secrets` K8s Secret does not exist
- Worker-01 RAM still at 16Gi (Proxmox upgrade required)

**Task Changes Applied:**
- Task 5: Simplified — removed redundant label check subtask (label exists by default on all K8s nodes)

---

## Dev Notes

### Architecture & Constraints

- **New `backend` namespace** — dedicated for Supabase and future backend services consumed by dev containers (FR227)
- **Worker-01 RAM upgrade** — 16Gi → 24Gi in Proxmox; host has ~39Gi available; required to accommodate Supabase alongside existing workloads (FR228)
- **Supabase-bundled PostgreSQL** — isolated from existing `data` namespace PostgreSQL; own extensions and lifecycle
- **DNS gotcha** — `*.jetzinger.com` wildcard DNS interception affects pods needing external access; `dnsPolicy: None` fix will be applied in Story 28.2 Helm values (NFR135)

### Secret Management Pattern

- Follow existing pattern: raw K8s `Secret` with `stringData` (not base64 `data`)
- Naming convention: `supabase-secrets` (matches `{app}-secrets` pattern)
- File location: `secrets/supabase-secrets.yaml` (gitignored directory)
- Apply pattern: `kubectl apply -f` for initial creation, `kubectl patch` for real values
- **NEVER** commit real secret values to git
- **NEVER** `kubectl apply` a file with empty placeholders over live secrets (use `kubectl patch` only)

### Supabase JWT Key Generation

- `JWT_SECRET`: Used by GoTrue and all Supabase components to sign/verify tokens
- `ANON_KEY`: Pre-generated JWT with `{"role": "anon", "iss": "supabase"}` claims, signed with `JWT_SECRET`
- `SERVICE_ROLE_KEY`: Pre-generated JWT with `{"role": "service_role", "iss": "supabase"}` claims, signed with `JWT_SECRET`
- Key generation tool: `supabase` CLI or manual JWT generation (e.g., using `jwt.io` or `pyjwt`)
- JWT payload format: `{"role": "<role>", "iss": "supabase", "iat": <timestamp>, "exp": <far-future-timestamp>}`

### Labels (Required on All Resources)

```yaml
labels:
  app.kubernetes.io/name: supabase
  app.kubernetes.io/instance: supabase-secrets
  app.kubernetes.io/part-of: home-lab
  app.kubernetes.io/managed-by: kubectl
```

### Project Structure Notes

- Secret file: `secrets/supabase-secrets.yaml` (follows existing `secrets/{app}-secrets.yaml` pattern)
- Application directory: `applications/supabase/` (will be created in Story 28.2)
- Namespace: `backend` (new — not yet in project-context.md namespace table)

### References

- [Source: docs/planning-artifacts/epics.md — Epic 28, Story 28.1]
- [Source: docs/planning-artifacts/architecture.md — Supabase Backend section, lines 1989-2087]
- [Source: docs/analysis/brainstorming-session-2026-02-23.md — Constraint Mapping, Secrets Management]
- [Source: docs/project-context.md — Secret Management section]
- [Source: secrets/ntfy-secrets.yaml — Reference pattern for K8s Secret placeholder]
- FRs covered: FR227, FR228, FR229, FR246, FR247
- NFRs covered: NFR136, NFR139

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

- Proxmox LXC hot-plug: memory resize applied live, k3s-agent restart required for kubelet to report new capacity
- JWT generation: Used Python hmac/hashlib (no pyjwt available on Arch), HS256, 10-year expiry
- SMTP change: Switched from Resend SMTP relay to cluster-local protonmail-bridge (protonmail-bridge.docs.svc.cluster.local:25)

### Completion Notes List

- AC1: Worker-01 RAM upgraded 16Gi → 24Gi via Proxmox LXC hot-plug. k3s-agent restarted to report new capacity. All pods remained Running. Usage dropped from 60% to 40%.
- AC2: `backend` namespace created and Active.
- AC3: `secrets/supabase-secrets.yaml` created with 6 empty placeholder keys following ntfy-secrets pattern (comment header, labels, stringData).
- AC4: All 6 real secret values generated and applied via `kubectl patch`. POSTGRES_PASSWORD, JWT_SECRET, DASHBOARD_PASSWORD via openssl. ANON_KEY and SERVICE_ROLE_KEY as HS256 JWTs signed with JWT_SECRET. GOTRUE_SMTP_PASS set to protonmail-bridge password (cluster-local SMTP, not Resend).
- AC5: `kubernetes.io/hostname=k3s-worker-01` label confirmed present (default K8s label).
- SMTP design change: GoTrue will use cluster-local protonmail-bridge (docs namespace) instead of Resend. This eliminates external SMTP dependency and removes the need for `dnsPolicy: None` on GoTrue for SMTP access. Story 28.2 Helm values should configure: SMTP host=protonmail-bridge.docs.svc.cluster.local, port=25, user=thomas@jetzinger.com, password from secret.

### Change Log

- 2026-02-23: Tasks refined based on codebase gap analysis
- 2026-02-23: SMTP provider changed from Resend to cluster-local protonmail-bridge
- 2026-02-23: All tasks completed, story marked for review

### File List

- secrets/supabase-secrets.yaml (created — placeholder secret file)
- docs/implementation-artifacts/28-1-prepare-infrastructure-namespace-ram-secrets.md (modified — story file)
- docs/implementation-artifacts/sprint-status.yaml (modified — epic/story status updates)
