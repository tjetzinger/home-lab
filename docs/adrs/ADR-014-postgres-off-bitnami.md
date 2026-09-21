# ADR-014: PostgreSQL off Bitnami to CloudNativePG

**Status:** Accepted
**Date:** 2026-09-20
**Supersedes:** the Bitnami `postgresql` chart deployment from Epic 5 (Story 5.1)

## Context

An image audit of every pod in the cluster found the data tier running
`registry-1.docker.io/bitnami/postgresql:latest` with `imagePullPolicy: IfNotPresent`.

Bitnami's August 2025 catalogue change removed **all versioned tags** from `docker.io/bitnami`.
Verified directly against the Docker Hub registry API on 2026-09-20: the `postgresql` repository
carries only `latest` plus sha-tags. Every versioned tag was archived to `docker.io/bitnamilegacy`,
which receives no updates and which Bitnami describes as a temporary migration aid with no
long-term commitment. Their own published advice is to copy images you depend on into a registry
you control.

That left the data tier unpinnable:

| | |
|---|---|
| Running image | PostgreSQL **18.1**, pulled 2026-01-06 |
| `bitnami/postgresql:latest` on 2026-09-20 | PostgreSQL **18.6.0**, re-pushed that day |
| `PG_VERSION` on disk | **18** |

The majors matched, so nothing was broken yet. The hazard is what happens when PostgreSQL 19
lands in `latest`: any event that re-pulls — node rebuild, image garbage collection, eviction —
starts a v19 binary against a v18 data directory, and PostgreSQL refuses to boot. There is no
warning and no version to pin to.

This was not hypothetical. The `postgres-backup` CronJob used the same tag and had already pulled
a fresh image that day while the database pod still ran January's.

## Decision

Migrate to **CloudNativePG**, operator v1.30.0 (chart `cnpg/cloudnative-pg` 0.29.0), running
PostgreSQL 18.6 from `ghcr.io/cloudnative-pg/postgresql`, pinned by tag.

CNPG publishes its own maintained, versioned images, so the root problem does not recur. It also
manages minor-version upgrades as rolling restarts and offers declarative backup with PITR if an
object store is ever added.

## Alternatives considered

| Alternative | Why rejected |
|---|---|
| Pin to `bitnamilegacy/postgresql:<version>` | One-line change, but the archive is frozen, accumulates unpatched CVEs, and Bitnami has not committed to keeping it |
| Mirror the image into the Gitea registry and pin by digest | Solid and cheap — Gitea's registry is live at `git.home.jetzinger.com`. Rejected only because it leaves the home lab owning patch cadence for its own database forever |
| Official `postgres:18-alpine` + hand-written StatefulSet | Means re-implementing the ServiceMonitor, metrics exporter and backup that the chart provided. More work than CNPG for a worse result |
| Do nothing | The failure is silent until a pod reschedules, at which point the database will not start |

## Consequences

### Migration

Bootstrapped with CNPG's declarative `monolith` import: the operator ran `pg_dumpall -r` for roles
(with their password hashes) plus a `pg_dump` per named database against the live Bitnami instance.
Nothing was copied by hand. The three empty Epic-5 test databases (`app_test_db`, `backup_test`,
`test_persistence`) were left off the import list and did not carry over.

Five consumers, each scaled to 0 before comparison so no live writer could race the check, then
verified table-by-table with exact `count(*)`:

| Consumer | Tables | Result |
|---|---|---|
| Paperless-ngx | 72 | identical after re-syncing one Celery log row |
| Gitea | 112 | identical |
| n8n | 56 | identical |
| LiteLLM | 45 | identical after re-syncing two spend-log tables |
| Legacy-Use | 10 | identical |

LiteLLM connects as the `postgres` superuser, so `enableSuperuserAccess: true` is required. Giving
it its own role is a worthwhile follow-up; it was kept out of the migration so that only the host
changed.

### What this changed elsewhere

- **Backup.** `applications/postgres/backup-cronjob.yaml` was replaced by
  `applications/postgres-cnpg/backup-cronjob.yaml`. Not a CNPG `ScheduledBackup`: those need an
  S3-compatible store or CSI volume snapshots, and this cluster has neither —
  nfs-subdir-external-provisioner has no snapshot support and `kubectl get volumesnapshotclass`
  returns no such resource type. The new job keeps `pg_dumpall` to the same PVC, adds a `gzip -t`
  integrity check the old one lacked, and uses a pinned image.
- **Alerting.** `PostgreSQLUnhealthy` watched
  `kube_statefulset_status_replicas_ready{statefulset="postgres-postgresql"}`, which CNPG never
  produces — it manages Pods from a Cluster CR, not a StatefulSet. Its `absent()` clause fired the
  moment the Bitnami release was uninstalled. Rewritten against `cnpg_collector_up`.
- **Connection strings.** Gitea, n8n and Paperless via `values-homelab.yaml`; LiteLLM and
  Legacy-Use hold theirs in secrets and were `kubectl patch`ed.

### Lessons worth keeping

- **Do not compare `reltuples` to verify a migration.** It is a planner estimate and reads `-1` for
  never-analyzed tables. The first comparison reported `gitea old=-50` — a negative row count — and
  marked all five databases as mismatched when four were byte-identical. Use `count(*)`.
- **Do not compare password hashes to check whether credentials survived.** SCRAM-SHA-256 hashes
  are salted, so the same password produces a different hash every time. Comparing them suggested
  the import had lost every role password; testing actual authentication showed all were intact.
- **A `helm upgrade -f values.yaml` silently drops anything the previous deploy passed with
  `--set`.** Paperless lost both its database password and its Django `SECRET_KEY` this way. The
  password crash-looped the pod and was obvious; the `SECRET_KEY` did not, and Paperless ran
  signing sessions with a placeholder committed to a public repo until it was caught. Both now live
  in a Kubernetes secret referenced by `valueFrom`. See `applications/paperless/secret.yaml`.

### Rollback

The Bitnami PVC `data-postgres-postgresql-0` and a pre-migration `pg_dumpall`
(`postgres-premigration-20260920-213116.sql.gz`, gzip-verified, on the `postgres-backup` PVC, named
so the 7-day rotation will not delete it) were both retained after the release was uninstalled.

## References

- `applications/postgres-cnpg/` — operator values, Cluster manifest, backup CronJob, README
- [bitnami/containers#83267](https://github.com/bitnami/containers/issues/83267) — the catalogue change
- [ADR-013](ADR-013-cloud-model-tier-refresh.md) — the LiteLLM tier that depends on this database
