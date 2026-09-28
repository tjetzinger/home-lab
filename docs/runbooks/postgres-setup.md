# PostgreSQL Setup and Operations (CloudNativePG)

**Purpose:** Run, inspect and rebuild the cluster's PostgreSQL
**Decisions:** [ADR-014](../adrs/ADR-014-postgres-off-bitnami.md) (CloudNativePG), two instances since 2026-09-28
**Rewritten:** 2026-09-28 for CloudNativePG. The Bitnami version of this runbook (Story 5.1) is in
git history; its `postgres-postgresql` service and StatefulSet no longer exist.

---

## At a glance

| | |
|---|---|
| Operator | CloudNativePG 1.30.0 - Helm release `cnpg`, chart `cnpg/cloudnative-pg` 0.29.0, namespace `cnpg-system` |
| Cluster | `postgres-cnpg`, namespace `data`, **2 instances** (primary + streaming replica) |
| PostgreSQL | 18.6, image `ghcr.io/cloudnative-pg/postgresql:18.6` (pinned) |
| Storage | 8Gi per instance on `nfs-client` |
| Placement | one instance each on `k3s-worker-01` and `k3s-worker-02` (anti-affinity `required`) |
| Manifests | `applications/postgres-cnpg/` - `cluster.yaml`, `values-homelab.yaml` (operator), `backup-cronjob.yaml` |

### Services

| Service | Points at | Use |
|---|---|---|
| `postgres-cnpg-rw.data.svc.cluster.local:5432` | the primary | **everything** - all consumers use this |
| `postgres-cnpg-ro.data.svc.cluster.local:5432` | the replica | read-only queries (nothing uses it today) |
| `postgres-cnpg-r.data.svc.cluster.local:5432` | any instance | rarely useful |

`-rw` follows the primary through a switchover, so consumers never need to know which pod is primary.

### Databases and roles (checked 2026-09-28)

| Database | Owner | Used by (login role) |
|---|---|---|
| `litellm` | `postgres` | LiteLLM (`postgres` - superuser) |
| `paperless` | `postgres` | Paperless-ngx (`paperless_user`) |
| `gitea` | `postgres` | Gitea (`gitea`) |
| `n8n` | `postgres` | n8n (`n8n`) |
| `legacy_use` | `legacy_use` | Legacy-Use (`legacy_use`) |

Role `app_user` is a leftover from the Epic 5 connectivity test. It owns nothing listed above.

---

## Connect

**Always find the primary by label.** The primary moves on every switchover and node drain, so
never hard-code `postgres-cnpg-1`.

```bash
PRIMARY=$(kubectl --context default -n data get pod \
  -l cnpg.io/cluster=postgres-cnpg,cnpg.io/instanceRole=primary -o name)

# psql as the superuser over the local socket (peer auth - no password needed)
kubectl --context default -n data exec -it $PRIMARY -c postgres -- psql -U postgres

# one-off query
kubectl --context default -n data exec $PRIMARY -c postgres -- psql -U postgres -c '\l+'
```

From your workstation, port-forward the **service**, not a pod, so you always land on the primary:

```bash
kubectl --context default -n data port-forward svc/postgres-cnpg-rw 5432:5432
# password: secret postgres-cnpg-superuser, key "password"
psql -h localhost -U postgres
```

The `kubectl cnpg` plugin is **not** installed on the workstation. Everything here uses plain
`kubectl`.

---

## Health check

```bash
kubectl --context default -n data get cluster postgres-cnpg
# expect: STATUS "Cluster in healthy state", READY 2

kubectl --context default -n data get pods -l cnpg.io/cluster=postgres-cnpg \
  -L cnpg.io/instanceRole -o wide
# expect: one primary, one replica, on different workers

# replication lag, from the primary
kubectl --context default -n data exec $PRIMARY -c postgres -- psql -U postgres -c \
  "select application_name, state, sync_state, replay_lag from pg_stat_replication;"
# expect: one row, state "streaming"
```

**One PodDisruptionBudget exists, `postgres-cnpg-primary`, and it shows `ALLOWED DISRUPTIONS 0`.
That is by design** - it forces CNPG to switch over before the primary's node drains. With a single
replica, CNPG creates no replica PDB.

---

## Monitoring

- Metrics come from each instance's built-in exporter, scraped by `PodMonitor/postgres-cnpg`
  (namespace `data`).
- `cnpg_collector_up` is the health signal. The critical alert `PostgreSQLUnhealthy`
  (`monitoring/prometheus/custom-rules.yaml`) fires when it reads 0 **or** disappears.
- Useful queries: `cnpg_backends_total` (connections), `cnpg_pg_database_size_bytes`,
  `cnpg_pg_replication_lag`.

---

## Maintenance

### Node drain

Draining the node that holds the primary triggers a **switchover** first: the replica is promoted,
and writes stop for a few seconds. Measured on 2026-09-28: **8 seconds** with no rows lost; n8n
reconnected in 7 seconds. The displaced instance stays `Pending` until its node returns - that is
the `required` anti-affinity working, not a fault.

### Configuration change

Edit `applications/postgres-cnpg/cluster.yaml`, then:

```bash
kubectl --context default apply -f applications/postgres-cnpg/cluster.yaml
```

`primaryUpdateMethod: switchover` makes CNPG update the replica first and then switch over, so the
primary is never restarted in place. Expect the same few seconds of write outage.

### Minor PostgreSQL upgrade

Change `imageName` in `cluster.yaml` to the new pinned tag (same major version only) and apply.
A **major** upgrade (19.x) is a different procedure - do not just change the tag.

---

## Rebuild from scratch

Only for a lost cluster. For data recovery, use [postgres-restore.md](postgres-restore.md).

```bash
# 1. Operator
helm repo add cnpg https://cloudnative-pg.github.io/charts
helm --kube-context default upgrade --install cnpg cnpg/cloudnative-pg --version 0.29.0 \
  -n cnpg-system --create-namespace -f applications/postgres-cnpg/values-homelab.yaml

# 2. Superuser secret - create ONCE, with the real password (never apply a placeholder over it)
kubectl --context default -n data create secret generic postgres-cnpg-superuser \
  --type=kubernetes.io/basic-auth --from-literal=username=postgres --from-literal=password='<password>'
```

3. `cluster.yaml` bootstraps by **importing from the retired Bitnami service**
   (`bootstrap.initdb.import`, source `postgres-postgresql.data`). That source no longer exists, so a
   fresh apply as-is will fail. For a rebuild, replace the `bootstrap` block with a plain
   `initdb`, apply, then load the latest nightly dump as described in
   [postgres-restore.md](postgres-restore.md).
4. Recreate the backup job: `kubectl --context default apply -f applications/postgres-cnpg/backup-cronjob.yaml`.

---

## Troubleshooting

| Symptom | Check |
|---|---|
| Consumers get "connection refused" | `kubectl -n data get endpointslices -l kubernetes.io/service-name=postgres-cnpg-rw` - an empty slice means no primary. Then check the cluster status and pod events |
| Cluster not "healthy" | `kubectl -n data describe cluster postgres-cnpg` (the Status and Events sections) and `kubectl -n cnpg-system logs deploy/cnpg-cloudnative-pg --tail=100` |
| Instance `Pending` | Expected while its node is drained or down (anti-affinity). Otherwise check PVC binding and NFS |
| `password authentication failed` | The role's password in PostgreSQL does not match the consumer's secret. Reset with `ALTER ROLE ... PASSWORD`, then patch the consumer's secret |
| Replica not streaming | `pg_stat_replication` on the primary, then the replica pod's logs |

Backup-specific issues: [postgres-backup.md](postgres-backup.md).

---

## Related

- [postgres-connectivity.md](postgres-connectivity.md) - connecting a new application
- [postgres-backup.md](postgres-backup.md) / [postgres-restore.md](postgres-restore.md)
- [`applications/postgres-cnpg/README.md`](../../applications/postgres-cnpg/README.md) - migration from Bitnami
- [ADR-014](../adrs/ADR-014-postgres-off-bitnami.md)

## Change log

- 2026-01-06: Created for the Bitnami deployment (Story 5.1)
- 2026-09-28: Rewritten for CloudNativePG with two instances
