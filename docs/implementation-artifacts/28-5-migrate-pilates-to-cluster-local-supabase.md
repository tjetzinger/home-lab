# Story 28.5: Migrate pilates Dev Container to Cluster-Local Supabase

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **developer using the pilates dev container**,
I want **to switch pilates from supabase.com to the cluster-local Supabase instance**,
So that **pilates operates on a self-hosted backend with no external dependency on supabase.com**.

## Acceptance Criteria

1. **AC1 — Schema Seeded:** Given Supabase is running and accessible via ingress (Stories 28.2 + 28.3 complete), when I connect to the cluster-local Supabase Studio at `https://studio.supabase.home.jetzinger.com`, then I can create the pilates database schema and seed data required by the application (FR250).

2. **AC2 — Env Vars Updated:** Given the pilates schema is seeded on the new Supabase instance, when I update the pilates dev container configuration with `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` pointing to the cluster-local Supabase, then the env vars are updated in the pilates deployment manifest (FR249) and no application code changes are required (NFR140).

3. **AC3 — Application Functional:** Given the env vars are updated and NetworkPolicy already allows backend access (Story 28.4 completed this), when the pilates pod restarts with the new configuration, then pilates connects to the cluster-local Supabase instance and auth operations (login, signup) work against the local GoTrue, and database CRUD operations work against the local PostgREST.

4. **AC4 — Supabase.com Decommissioned:** Given both calsync and pilates are migrated, when I verify that no dev container pods reference supabase.com in their environment variables, then the supabase.com dependency is fully decommissioned for the `dev` namespace.

5. **AC5 — Manifests Committed:** Given the migration is validated, when I commit the updated pilates deployment manifest to git, then the manifest reflects the cluster-local Supabase configuration.

## Tasks / Subtasks

**DRAFT TASKS** - Generated from requirements analysis. Will be validated and refined against actual codebase when dev-story runs.

- [ ] Task 1: Seed pilates database schema on cluster-local Supabase (AC: #1)
  - [ ] 1.1 Access Studio at `https://studio.supabase.home.jetzinger.com`
  - [ ] 1.2 SSH into pilates dev container and identify schema/migration requirements
  - [ ] 1.3 Run pilates's migration or seed scripts against the local Supabase instance
  - [ ] 1.4 Verify schema exists in Studio SQL editor
  - **Status:** Manual task — deferred to user. Schema seeding is app-specific.

- [x] Task 2: Update pilates deployment with Supabase env vars (AC: #2)
  - [x] 2.1 Add env vars to pilates deployment in `applications/dev-containers/dev-container-pilates.yaml`
  - [x] 2.2 Apply updated deployment
  - [x] 2.3 Set actual key values via `kubectl set env`
  - [x] 2.4 Pod rollout complete (force-deleted old pod for RWO PVC release)

- [x] Task 3: Validate pilates connectivity (AC: #3)
  - [x] 3.1 Env vars verified: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` all set
  - [x] 3.2 PostgREST → HTTP 200
  - [x] 3.3 GoTrue → v2.186.0 healthy
  - [ ] 3.4 Start pilates application and verify it connects successfully (manual SSH — app-specific)
  - [ ] 3.5 Test auth operations against local GoTrue (manual SSH — app-specific)
  - [ ] 3.6 Test database CRUD operations against local PostgREST (manual SSH — app-specific)

- [x] Task 4: Verify supabase.com decommissioned (AC: #4)
  - [x] 4.1 Checked all 3 dev-container pods (ai-dev, calsync, pilates)
  - [x] 4.2 Confirmed: no env var contains `supabase.com` or `supabase.co` — all point to cluster-local

- [ ] Task 5: Commit manifests to git (AC: #5)
  - [ ] 5.1 Git add updated files
  - [ ] 5.2 Commit with conventional commit message

## Gap Analysis

**Scan Date:** 2026-02-23

**What Exists:**
- `applications/dev-containers/networkpolicy.yaml` — Already has egress rule to backend namespace on port 8000 (Story 28.4)
- `backend` namespace has `name=backend` label (Story 28.4)
- Supabase running in `backend` namespace (8 pods healthy, Kong on k3s-worker-01)
- `applications/dev-containers/dev-container-pilates.yaml` — Deployment with NO env section (same starting state as calsync before 28.4)
- `applications/dev-containers/dev-container-calsync.yaml` — Reference implementation with env vars added

**What's Missing:**
- No Supabase env vars in pilates deployment → **Task 2**
- Schema seeding not done → **Task 1 (manual)**

**Task Changes Applied:** None — draft tasks accurately match codebase reality.

---

## Dev Notes

### Architecture & Constraints

- **Pilates deployment is identical pattern to calsync:** Same image (`dev-container-ai:latest`), same labels (`app.kubernetes.io/name: dev-container`), same node (`k3s-worker-01`), same RWO PVC pattern. The only difference is the instance name and SSH config.
- **NetworkPolicy already updated:** Story 28.4 added the egress rule to `backend` namespace on port 8000. The pilates pod shares the same `app.kubernetes.io/name: dev-container` label, so the same NetworkPolicy applies. **However:** the pilates pod hasn't been restarted since the NetworkPolicy update — it may need a restart for kube-router to apply fresh iptables rules.
- **`backend` namespace already labeled:** `name=backend` label was added in Story 28.4. No additional namespace labeling needed.
- **NFR140:** No application code changes required — only env var updates.

### Proven Migration Pattern (from Story 28.4)

Follow exactly the same pattern established for calsync:
1. Add `env` section to container spec in deployment YAML
2. `SUPABASE_URL` hardcoded as cluster-internal Kong URL (not a secret)
3. `SUPABASE_ANON_KEY` and `SUPABASE_SERVICE_ROLE_KEY` as empty placeholders per CLAUDE.md secrets convention
4. Apply manifest, then `kubectl set env` to set actual key values
5. Force-delete old pod if new pod is Pending due to RWO PVC (use `--grace-period=10`)

### Key Differences from Story 28.4

- **No NetworkPolicy changes needed** — already done in Story 28.4
- **No namespace labeling needed** — already done in Story 28.4
- **Pilates has no HTTP port exposed** — only SSH port 22 (unlike calsync which has port 3000)
- **Additional AC: supabase.com decommissioning** — verify ALL dev containers are migrated

### Service Names and Ports

| Service | K8s Name | Port | Purpose |
|---------|----------|------|---------|
| Kong (API Gateway) | `supabase-supabase-kong.backend.svc.cluster.local` | 8000 | Unified Supabase API endpoint |

### Previous Story Intelligence (28.4)

Critical learnings from Story 28.4:
1. **Missing `name=backend` namespace label** was root cause of "Connection refused" — already fixed
2. **iptables debugging** revealed kube-router REJECT rules for pods without matching NetworkPolicy ACCEPT marks
3. **Env var split**: SUPABASE_URL in YAML, keys via `kubectl set env` at runtime
4. **ReadWriteOnce PVC** requires force-deleting old pod for rollout to proceed
5. **Connectivity validated**: PostgREST HTTP 200, GoTrue v2.186.0 healthy from calsync pod
6. **Fresh test pods appeared to work** because they completed before kube-router applied rules — don't be fooled by transient success

### Existing File Locations

- Pilates deployment: `applications/dev-containers/dev-container-pilates.yaml`
- Pilates SSH config: `applications/dev-containers/dev-container-pilates-ssh.yaml`
- NetworkPolicy: `applications/dev-containers/networkpolicy.yaml` (already has backend egress rule)
- Supabase secrets: `secrets/supabase-secrets.yaml` (placeholders only)
- Calsync deployment (reference): `applications/dev-containers/dev-container-calsync.yaml`

### References

- [Source: docs/planning-artifacts/epics.md — Epic 28, Story 28.5, lines 6623-6659]
- [Source: docs/planning-artifacts/architecture.md — Dev Container Migration section, line 1989]
- [Source: docs/planning-artifacts/prd.md — FR249, FR250, NFR140]
- [Source: applications/dev-containers/dev-container-pilates.yaml — Current deployment]
- [Source: applications/dev-containers/dev-container-calsync.yaml — Reference implementation (Story 28.4)]
- [Source: docs/implementation-artifacts/28-4-migrate-calsync-to-cluster-local-supabase.md — Previous story]
- FRs covered: FR249, FR250
- NFRs covered: NFR140

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

### Completion Notes List

- Task 2: Pilates deployment updated with Supabase env vars following proven calsync pattern. `SUPABASE_URL` hardcoded in YAML, keys set via `kubectl set env`. Force-deleted old pod for RWO PVC release.
- Task 3: Connectivity validated from pilates pod — PostgREST HTTP 200, GoTrue v2.186.0 healthy. App-level validation (Tasks 3.4-3.6) deferred to user (manual SSH).
- Task 4: All 3 dev-container pods verified — zero references to `supabase.com` or `supabase.co`. Supabase.com dependency fully decommissioned for dev namespace.

### File List

- `applications/dev-containers/dev-container-pilates.yaml` — Added Supabase env vars (SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY)
