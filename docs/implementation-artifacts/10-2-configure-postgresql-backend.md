# Story 10.2: Configure PostgreSQL Backend

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **platform engineer**,
I want **Paperless-ngx to use the existing cluster PostgreSQL database instead of SQLite**,
so that **the system can scale to 5,000+ documents with efficient metadata queries**.

## Acceptance Criteria

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

## Tasks / Subtasks

⚠️ **DRAFT TASKS** - Generated from requirements analysis. Will be validated and refined against actual codebase when dev-story runs.

- [x] **Task 1:** Create PostgreSQL database and user (AC: 2)
  - [x] Connect to PostgreSQL pod: `kubectl exec -it -n data postgresql-0 -- psql -U postgres`
  - [x] Create database: `CREATE DATABASE paperless;`
  - [x] Create user: `CREATE USER paperless_user WITH PASSWORD '<secure-password>';`
  - [x] Grant privileges: `GRANT ALL PRIVILEGES ON DATABASE paperless TO paperless_user;`
  - [x] Grant schema privileges: `GRANT ALL ON SCHEMA public TO paperless_user;`
  - [x] Verify: `\l` (list databases), `\du` (list users)

- [x] **Task 2:** Update secrets file with PostgreSQL credentials (AC: 2)
  - [x] Edit `secrets/paperless-secrets.yaml`
  - [x] Add `PAPERLESS_DBPASS: "<secure-password>"` to env section
  - [x] Keep PAPERLESS_SECRET_KEY from Story 10.1
  - [x] Verify secrets file is gitignored

- [x] **Task 3:** Update Helm values with PostgreSQL configuration (AC: 1)
  - [x] Edit `applications/paperless/values-homelab.yaml`
  - [x] Add PostgreSQL environment variables to env section
  - [x] Disable bundled PostgreSQL subchart (already disabled from Story 10.1)
  - [x] Document PostgreSQL configuration in comments
  - [x] Fix PostgreSQL hostname: postgres-postgresql.data.svc.cluster.local

- [x] **Task 4:** Upgrade Paperless-ngx deployment with PostgreSQL (AC: 3)
  - [x] Run Helm upgrade with secrets file:
    ```bash
    helm upgrade --install paperless gabe565/paperless-ngx \
      -f applications/paperless/values-homelab.yaml \
      -f secrets/paperless-secrets.yaml \
      -n docs
    ```
  - [x] Monitor pod restart and database migration
  - [x] Check pod logs for PostgreSQL connection success
  - [x] Verify no errors in Celery worker logs

- [x] **Task 5:** Validate PostgreSQL backend and data migration (AC: 3)
  - [x] Verify Paperless-ngx web interface loads successfully (HTTP 302 redirect)
  - [x] Check PostgreSQL for created tables: `\c paperless; \dt;` (17+ tables created)
  - [x] Verify database schema migration completed (215 migrations applied)
  - [x] Confirm no SQLite database files created in pod

## Gap Analysis

**Scan Date:** 2026-01-08

### Codebase Reality Check

✅ **What Exists:**
- `applications/paperless/values-homelab.yaml` - Helm values file from Story 10.1
  - Current env vars: TZ, PAPERLESS_URL, PAPERLESS_SECRET_KEY, PAPERLESS_REDIS
  - PostgreSQL subchart already disabled: `postgresql.enabled: false`
- `secrets/paperless-secrets.yaml` - Contains PAPERLESS_SECRET_KEY (missing PAPERLESS_DBPASS)
- Pods running: paperless-paperless-ngx-78c7d6f694-tvhlw, redis-65b6f6cb77-9v2kq
- PostgreSQL cluster operational: postgres-postgresql-0 in `data` namespace

❌ **What's Missing:**
- PostgreSQL database `paperless` (needs creation in Task 1)
- PostgreSQL user `paperless_user` (needs creation in Task 1)
- PostgreSQL env vars in values-homelab.yaml (PAPERLESS_DBENGINE, PAPERLESS_DBHOST, PAPERLESS_DBNAME, PAPERLESS_DBUSER, PAPERLESS_DBPORT)
- PAPERLESS_DBPASS in secrets file

### Task Validation

**NO CHANGES NEEDED** - Draft tasks accurately reflect current codebase state:
- ✅ Task 1: Create PostgreSQL database and user (both missing, creation required)
- ✅ Task 2: Update secrets file with PAPERLESS_DBPASS (missing credential)
- ✅ Task 3: Update Helm values with PostgreSQL env vars (missing configuration)
- ✅ Task 4: Upgrade deployment (standard procedure)
- ✅ Task 5: Validate PostgreSQL backend (verification step)

**Conclusion:** All draft tasks are implementation-ready. No refinement required.

---

## Dev Notes

### Architecture Requirements

**Database Backend:** [Source: docs/planning-artifacts/architecture.md#Document Management Architecture]
- Database: PostgreSQL (existing cluster deployment from Epic 5)
- Connection: `postgresql.data.svc.cluster.local:5432`
- Rationale: NFR29 requires scaling to 5,000+ documents (PostgreSQL outperforms SQLite at scale)
- Database name: `paperless`
- User: `paperless_user` (dedicated user, not postgres superuser)

**Environment Variables:** [Source: Paperless-ngx official documentation]
- `PAPERLESS_DBENGINE=postgresql` (switches from default SQLite)
- `PAPERLESS_DBHOST=postgresql.data.svc.cluster.local` (cluster DNS)
- `PAPERLESS_DBNAME=paperless`
- `PAPERLESS_DBUSER=paperless_user`
- `PAPERLESS_DBPASS=<password>` (from secrets file)
- `PAPERLESS_DBPORT=5432` (PostgreSQL default port)

**Secrets Management:** [Source: Story 10.1 - Established Pattern]
- Real credentials: `secrets/paperless-secrets.yaml` (gitignored)
- Placeholders: `values-homelab.yaml` (committed to git)
- Helm merge: `-f values-homelab.yaml -f secrets/paperless-secrets.yaml`

### Technical Constraints

**NFR29 - Document Scaling:** [Source: docs/planning-artifacts/prd.md#NFR29]
- Target: System handles 5,000+ documents efficiently
- PostgreSQL requirement: Efficient metadata queries at scale (vs SQLite limitations)
- Validation: Database migration completes successfully, queries remain performant

**Database Migration:** [Source: Paperless-ngx documentation]
- First startup with PostgreSQL triggers Django migrations
- Paperless-ngx automatically creates schema (no manual SQL required beyond DB/user creation)
- Migration logs appear in pod startup: "Applying migrations..."
- Existing SQLite data NOT migrated automatically (Story 10.1 had no data, clean slate)

**PostgreSQL Cluster Availability:** [Source: Epic 5 - Story 5.1]
- PostgreSQL deployed via Bitnami Helm chart in `data` namespace
- Service: `postgresql.data.svc.cluster.local` (cluster DNS)
- Already operational and serving n8n (validated in Epic 6)
- NFS-backed persistence configured (Epic 5, Story 5.2)

### Project Structure Notes

**File Locations:** [Source: docs/planning-artifacts/architecture.md#Project Structure]
```
applications/
├── paperless/
│   ├── values-homelab.yaml        # Update with PostgreSQL env vars (Task 3)
│   ├── redis.yaml                 # Already deployed (Story 10.1)
│   ├── ingress.yaml               # Story 10.5 (HTTPS access)
│   └── pvc.yaml                   # Story 10.4 (NFS storage)
secrets/
└── paperless-secrets.yaml         # Update with PAPERLESS_DBPASS (Task 2)
```

**Helm Values Pattern:** [Source: Story 10.1 - Implementation Summary]
- All environment variables in `env:` section of values-homelab.yaml
- Secrets managed via separate `secrets/paperless-secrets.yaml` file
- No inline `--set` flags in production deployments

### Testing Requirements

**Validation Checklist:**
1. PostgreSQL database `paperless` exists with user `paperless_user`
2. Pod restarts successfully after Helm upgrade
3. Pod logs show PostgreSQL connection success
4. Pod logs show database migrations applied
5. No SQLite-related errors in logs
6. Paperless-ngx web interface loads (via port-forward)
7. PostgreSQL contains Paperless-ngx tables (`\dt` shows schema)

**Database Connection Verification:**
```bash
# From Paperless-ngx pod
kubectl exec -it -n docs paperless-paperless-ngx-<pod-id> -- env | grep PAPERLESS_DB

# Expected output:
# PAPERLESS_DBENGINE=postgresql
# PAPERLESS_DBHOST=postgresql.data.svc.cluster.local
# PAPERLESS_DBNAME=paperless
# PAPERLESS_DBUSER=paperless_user
# PAPERLESS_DBPORT=5432
```

**PostgreSQL Table Verification:**
```bash
# Connect to PostgreSQL and check tables
kubectl exec -it -n data postgresql-0 -- psql -U paperless_user -d paperless -c '\dt'

# Expected: Django tables (auth_user, documents_document, etc.)
```

### Previous Story Intelligence

**From Story 10.1 - Deployment Learnings:**
- gabe565 Helm chart deployment successful
- Standalone Redis (redis:7-alpine) works better than Bitnami subchart
- Secrets management pattern established and working
- Pod validation: `kubectl get pods -n docs` shows both pods Running
- Celery worker connected to Redis successfully

**From Story 10.1 - Current Pod State:**
```
NAME                                       READY   STATUS    RESTARTS   AGE
paperless-paperless-ngx-<pod-id>          1/1     Running   0          ~X min
redis-<pod-id>                            1/1     Running   0          ~X min
```

**From Story 10.1 - Key Decisions:**
1. Standalone Redis over Bitnami subchart (image pull issues resolved)
2. Redis auth disabled (private cluster, Tailscale VPN only)
3. Ephemeral Redis storage (task queue only, no critical data)
4. Secrets pattern: placeholders in values-homelab.yaml, real credentials in gitignored file

**From Story 10.1 - Current Configuration:**
- `values-homelab.yaml` contains placeholder for PAPERLESS_SECRET_KEY
- `secrets/paperless-secrets.yaml` contains real PAPERLESS_SECRET_KEY
- PostgreSQL subchart already disabled: `postgresql.enabled: false`
- Currently using default SQLite (will be replaced by PostgreSQL in this story)

**From Epic 5 - PostgreSQL Deployment:**
- PostgreSQL service: `postgresql.data.svc.cluster.local`
- Port: 5432
- Superuser: `postgres`
- Already serving n8n database successfully
- NFS-backed persistence configured and validated

### Git Intelligence

**Recent Work Patterns:**
- Commit `5d5ed47`: Implement Story 10.1 (Paperless-ngx with Redis)
- Commit `33761ad`: Implement Story 1.1 (K3s Control Plane Infrastructure)
- Pattern: Detailed commit messages with FR references

**Established Patterns:**
- All Helm deployments use `values-homelab.yaml` files
- Documentation includes validation evidence and completion notes
- Namespace organization: `docs` for document management (Story 10.1 established)
- Secrets stored in gitignored `secrets/` directory

### References

- [Epic 10 Overview: docs/planning-artifacts/epics.md#Epic 10]
- [Story 10.2 Requirements: docs/planning-artifacts/epics.md (PostgreSQL requirement)]
- [Architecture: Document Management: docs/planning-artifacts/architecture.md#Document Management Architecture]
- [Functional Requirements: FR66 (PostgreSQL backend): docs/planning-artifacts/prd.md]
- [Non-Functional Requirements: NFR29 (5,000+ docs scaling): docs/planning-artifacts/prd.md]
- [Previous Story: 10-1-deploy-paperless-ngx-with-redis-backend.md]
- [PostgreSQL Deployment: docs/implementation-artifacts/5-1-deploy-postgresql-via-bitnami-helm-chart.md]
- [Paperless-ngx Official Docs: https://docs.paperless-ngx.com/configuration/]

## Dev Agent Record

### Agent Model Used

Claude Sonnet 4.5 (model ID: claude-sonnet-4-5-20250929)

### Debug Log References

_Will be populated by dev-story agent_

### Completion Notes List

**Implementation Summary:**
- Created PostgreSQL database `paperless` and user `paperless_user` with secure password
- Updated secrets file with PAPERLESS_DBPASS (gitignored)
- Updated Helm values with PostgreSQL configuration (all 6 environment variables)
- Upgraded Paperless-ngx deployment via Helm (revision 10)
- Successfully migrated from SQLite to PostgreSQL backend

**Key Decisions:**
1. **PostgreSQL service discovery**: Fixed initial connection issue - service name is `postgres-postgresql.data.svc.cluster.local`, not `postgresql.data.svc.cluster.local`
2. **Schema privileges**: Required additional PostgreSQL grants beyond database-level privileges:
   - `GRANT ALL ON SCHEMA public TO paperless_user;`
   - `GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO paperless_user;`
   - `GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO paperless_user;`
   - `ALTER DEFAULT PRIVILEGES` for future table/sequence creation
3. **Password generation**: Used `openssl rand -base64 50` for cryptographically secure password

**Validation Results:**
- ✅ Pod: paperless-paperless-ngx-5db64c4cd7-ccrzq (1/1 Running)
- ✅ PostgreSQL connection successful: postgres-postgresql.data.svc.cluster.local:5432
- ✅ Database migrations: 215 migrations applied successfully
- ✅ Database tables: 17+ Django/Paperless tables created, owned by paperless_user
- ✅ No SQLite database files in pod
- ✅ Web interface accessible (HTTP 302 redirect to login)
- ✅ All PostgreSQL environment variables correctly configured
- ✅ No errors in pod logs

**Follow-up Tasks:**
- Story 10.3: Configure OCR with German and English support
- Story 10.4: Configure NFS persistent storage for documents
- Story 10.5: Configure HTTPS ingress (paperless.home.jetzinger.com)

### File List

**Modified Files:**
- `applications/paperless/values-homelab.yaml` - Added PostgreSQL environment variables (PAPERLESS_DBENGINE, PAPERLESS_DBHOST, PAPERLESS_DBNAME, PAPERLESS_DBUSER, PAPERLESS_DBPORT)
- `secrets/paperless-secrets.yaml` - Added PAPERLESS_DBPASS with secure password (gitignored, not committed)
- `docs/implementation-artifacts/10-2-configure-postgresql-backend.md` - Gap analysis, completion notes, file list
- `docs/implementation-artifacts/sprint-status.yaml` - Story status: ready-for-dev → in-progress → review

**Database Changes:**
- PostgreSQL `data` namespace: Created database `paperless`, user `paperless_user`, granted schema privileges
