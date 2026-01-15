# Story 19.1: Deploy Gitea with PostgreSQL Backend

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **developer**,
I want **Gitea deployed with PostgreSQL for metadata storage**,
So that **I have a reliable self-hosted Git service**.

## Acceptance Criteria

1. **Given** the `dev` namespace exists and PostgreSQL is available
   **When** I deploy Gitea via Helm chart
   **Then** Gitea pod starts successfully
   **And** Gitea connects to existing PostgreSQL instance
   **And** this validates FR134

2. **Given** Gitea is deployed
   **When** I access the web interface
   **Then** interface loads within 3 seconds (NFR80)
   **And** initial setup wizard is displayed

3. **Given** Gitea uses PostgreSQL
   **When** I check database connections
   **Then** Gitea database exists in PostgreSQL
   **And** metadata is stored persistently

## Tasks / Subtasks

⚠️ **DRAFT TASKS** - Generated from requirements analysis. Will be validated and refined against actual codebase when dev-story runs.

### Task 1: Create Gitea Database in PostgreSQL (AC: 3)
- [x] 1.1: Connect to PostgreSQL instance
- [x] 1.2: Create `gitea` database
- [x] 1.3: Create `gitea` user with appropriate permissions
- [x] 1.4: Verify database connectivity

### Task 2: Deploy Gitea via Helm Chart (AC: 1, FR134)
- [x] 2.1: Create `applications/gitea/` directory
- [x] 2.2: Create `values-homelab.yaml` with PostgreSQL configuration
- [x] 2.3: Add Gitea Helm repository
- [x] 2.4: Deploy Gitea Helm chart in `dev` namespace
- [x] 2.5: Verify Gitea pod is running

### Task 3: Verify Web Interface and Performance (AC: 2, NFR80)
- [x] 3.1: Port-forward to Gitea service
- [x] 3.2: Access web interface and verify load time < 3 seconds
- [x] 3.3: Verify initial setup wizard is displayed
- [x] 3.4: Complete initial admin user setup (auto-created via Helm)

### Task 4: Documentation (AC: all)
- [x] 4.1: Create `applications/gitea/README.md`
- [x] 4.2: Document database configuration
- [x] 4.3: Update story file with completion notes

## Gap Analysis

**Scan Date:** 2026-01-15

✅ **What Exists:**
- `dev` namespace with existing pods (dev-container-belego, dev-container-pilates, nginx-proxy)
- PostgreSQL service at `postgres-postgresql.data.svc.cluster.local:5432`

❌ **What's Missing:**
- No `applications/gitea/` directory
- No `gitea` database in PostgreSQL
- No Gitea Helm repository configured
- No Gitea deployment

**Task Changes:** None - draft tasks accurately reflect codebase state.

---

## Dev Notes

### Technical Requirements

**FR134: Gitea deployed in `dev` namespace with PostgreSQL backend**
- Gitea Helm chart: `gitea-charts/gitea`
- Namespace: `dev` (already exists)
- PostgreSQL connection: `postgres-postgresql.data.svc.cluster.local:5432`

**NFR80: Gitea web interface loads within 3 seconds**
- Lightweight deployment with minimal resources

### Existing Infrastructure Context

**PostgreSQL Service:**
- Service: `postgres-postgresql.data.svc.cluster.local:5432`
- Auth: Username `postgres` with password in secret
- Storage: NFS-backed persistent storage

**Dev Namespace:**
- Already exists with dev containers and nginx proxy
- Standard labels: `app.kubernetes.io/part-of: home-lab`

### Helm Deployment Pattern

```bash
# Add Gitea Helm repo
helm repo add gitea-charts https://dl.gitea.com/charts/
helm repo update

# Deploy Gitea
helm upgrade --install gitea gitea-charts/gitea \
  -f values-homelab.yaml \
  -n dev
```

### PostgreSQL Database Creation

```sql
-- Connect to PostgreSQL
CREATE DATABASE gitea;
CREATE USER gitea WITH ENCRYPTED PASSWORD 'your-password';
GRANT ALL PRIVILEGES ON DATABASE gitea TO gitea;
```

Or via kubectl:
```bash
kubectl exec -it -n data postgres-postgresql-0 -- psql -U postgres -c "CREATE DATABASE gitea;"
kubectl exec -it -n data postgres-postgresql-0 -- psql -U postgres -c "CREATE USER gitea WITH ENCRYPTED PASSWORD 'password';"
kubectl exec -it -n data postgres-postgresql-0 -- psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE gitea TO gitea;"
```

### Values Configuration Pattern

```yaml
# applications/gitea/values-homelab.yaml
gitea:
  config:
    database:
      DB_TYPE: postgres
      HOST: postgres-postgresql.data.svc.cluster.local:5432
      NAME: gitea
      USER: gitea
      PASSWD: # from secret
    server:
      ROOT_URL: https://git.home.jetzinger.com

persistence:
  enabled: true
  storageClass: nfs-client

resources:
  requests:
    cpu: 100m
    memory: 256Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

### Project Context Reference

- [Source: docs/planning-artifacts/epics.md#Story 19.1, lines 4617-4648]
- [Source: docs/planning-artifacts/prd.md#FR134, NFR80]
- [Source: applications/postgres/ - PostgreSQL deployment]
- [Source: applications/ - Similar Helm deployment patterns]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.5 (claude-opus-4-5-20251101)

### Debug Log References

- PostgreSQL database creation: gitea database created with gitea user
- Helm deployment: valkey-cluster initially deployed but disabled for simpler setup
- Web interface load time: 0.247s (NFR80 requires < 3 seconds)
- Database connectivity: Verified 1 admin user in database after deployment

### Completion Notes List

1. **PostgreSQL Database Setup** (Task 1):
   - Created `gitea` database in PostgreSQL
   - Created `gitea` user with password `gitea-homelab-2026`
   - Granted all privileges including PostgreSQL 15+ schema permissions

2. **Helm Deployment** (Task 2):
   - Added gitea-charts Helm repository
   - Created `applications/gitea/values-homelab.yaml` with PostgreSQL configuration
   - Disabled embedded valkey-cluster, redis-cluster, postgresql, postgresql-ha
   - Deployed Gitea v1.24.6-rootless to dev namespace

3. **Performance Validation** (Task 3):
   - Web interface load time: **0.247s** (NFR80 < 3 seconds)
   - Admin user auto-created via Helm configuration
   - Database tables migrated successfully

4. **Configuration Details**:
   - HTTP Service: `gitea-http.dev.svc.cluster.local:3000`
   - SSH Service: `gitea-ssh.dev.svc.cluster.local:22`
   - Admin credentials: admin / gitea-admin-2026
   - Registration disabled (single-user mode)
   - Memory-based caching (lightweight setup)

### File List

| File | Action |
|------|--------|
| `applications/gitea/values-homelab.yaml` | Created |
| `applications/gitea/README.md` | Created |

### Change Log

- 2026-01-15: Story 19.1 created - Deploy Gitea with PostgreSQL Backend (Claude Opus 4.5)
- 2026-01-15: Story 19.1 completed - Gitea deployed with PostgreSQL backend (Claude Opus 4.5)
