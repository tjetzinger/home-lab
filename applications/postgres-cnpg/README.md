# PostgreSQL (CloudNativePG)

Replaces the Bitnami `postgresql` chart in namespace `data`. See
[ADR-014](../../docs/adrs/ADR-014-postgres-off-bitnami.md).

**Operator:** CloudNativePG 1.30.0, chart `cnpg/cloudnative-pg` 0.29.0, namespace `cnpg-system`
**Cluster:** `postgres-cnpg` in namespace `data`, 1 instance, PostgreSQL 18.6, 8Gi on `nfs-client`

## Why this replaced Bitnami

Bitnami's August 2025 catalogue change removed every versioned tag from `docker.io/bitnami`.
Verified against the registry API on 2026-09-20: the `postgresql` repo carries **only `latest`**
plus sha-tags. Versioned tags moved to `docker.io/bitnamilegacy`, which receives no updates and
which Bitnami describes as temporary.

That left the data tier unpinnable. The running pod held PostgreSQL 18.1 pulled on 2026-01-06 with
`imagePullPolicy: IfNotPresent`, while `bitnami/postgresql:latest` had moved to 18.6.0. Same major,
so harmless — until PostgreSQL 19 lands in `latest`, at which point any re-pull (node rebuild,
image GC, eviction) starts a v19 binary against a v18 data directory and Postgres refuses to boot.
The `postgres-backup` CronJob proved re-pulls happen: it pulled a fresh image while the database
pod still ran January's.

CNPG publishes its own maintained, versioned images, so the problem does not recur.

## Services

| Service | Use |
|---------|-----|
| `postgres-cnpg-rw.data.svc.cluster.local` | read-write (primary) — this is what consumers use |
| `postgres-cnpg-ro.data.svc.cluster.local` | read-only replicas (none configured) |
| `postgres-cnpg-r.data.svc.cluster.local` | any instance |

## Consumers

Five, all connecting to `postgres-cnpg-rw`:

| App | Database | Role | Where the connection string lives |
|-----|----------|------|-----------------------------------|
| LiteLLM | `litellm` | `postgres` | secret `litellm-secrets` key `DATABASE_URL` (`kubectl patch`) |
| Paperless-ngx | `paperless` | `paperless_user` | `applications/paperless/values-homelab.yaml` |
| Gitea | `gitea` | `gitea` | `applications/gitea/values-homelab.yaml` |
| n8n | `n8n` | `n8n` | `applications/n8n/values-homelab.yaml` |
| Legacy-Use | `legacy_use` | `legacy_use` | secret `legacy-use-secrets` key `database-url` (`kubectl patch`) |

LiteLLM connects as the `postgres` superuser, which is why `enableSuperuserAccess: true` is set.
Giving it its own role is a worthwhile follow-up, but was deliberately kept out of the migration
so that only the host changed.

Supabase in namespace `backend` runs its **own** PostgreSQL and is unaffected by any of this.

## Secrets

Both were created by copying the existing Bitnami superuser password, so no consumer password
changed during the migration — only the host in their connection strings.

| Secret | Purpose |
|--------|---------|
| `postgres-cnpg-superuser` | the `postgres` superuser (`kubernetes.io/basic-auth`) |
| `postgres-cnpg-import-source` | password for reading the old cluster during bootstrap import |

Apply values with `kubectl patch`, never `kubectl apply` on a placeholder file.

## Bootstrap import

`cluster.yaml` bootstraps with CNPG's declarative `monolith` import: the operator runs
`pg_dumpall -r` for roles (with their password hashes) plus a `pg_dump` per named database against
the live Bitnami instance. Nothing was copied by hand.

The three empty Epic-5 test databases (`app_test_db`, `backup_test`, `test_persistence`) were
simply left off the list and did not carry over.

**The import runs once, at bootstrap.** To redo it, delete the Cluster and its PVC.

### Migration verification (2026-09-20)

Exact `count(*)` across every user table in each database, old vs new:

| Database | Old | New | |
|----------|-----|-----|---|
| `litellm` | 22950 | 22950 | match |
| `gitea` | 77 | 77 | match |
| `n8n` | 792 | 792 | match |
| `legacy_use` | 33 | 33 | match |
| `paperless` | 16909 | 16908 | one row, `django_celery_results_taskresult` |

The Paperless difference is drift, not loss: the source was still live and Celery wrote a
task-result row after the snapshot. Every other table matched exactly.

**Do not compare `reltuples`.** It is a planner estimate and reads `-1` for never-analyzed tables —
the first attempt at this comparison reported `gitea old=-50`, a negative row count. Use
`count(*)`.

## Operations

```bash
kubectl --context default get cluster postgres-cnpg -n data
kubectl --context default cnpg status postgres-cnpg -n data   # needs the cnpg kubectl plugin
kubectl --context default exec -n data postgres-cnpg-1 -c postgres -- psql -U postgres -c '\l+'
```
