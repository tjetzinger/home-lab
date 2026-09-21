# ADR-016: Cluster-Wide Update Campaign

**Status:** Accepted
**Date:** 2026-09-21
**Related:** [ADR-014](ADR-014-postgres-off-bitnami.md) (Phase 1), [ADR-015](ADR-015-retire-openclaw-and-supabase.md) (Phase 2)

## Context

An audit of every workload found the cluster had drifted in a specific way: almost nothing was
broken, and almost everything was unpinned, stale, or both. LiteLLM ran `main-latest` twenty minor
versions behind. n8n was thirty-six versions behind. The data tier ran Bitnami's `:latest` because
Bitnami had deleted every versioned tag from Docker Hub.

None of it was failing, which is precisely why it had accumulated. The work was organised into six
phases, ordered so that each one removed a class of risk rather than a list of versions.

## Decision

Work the phases in dependency order — data tier first, because everything else depends on it;
security second; pinning third, so later upgrades start from a known state; applications fourth;
observability fifth. Defer the GPU node.

At every step, prefer **removing a problem over solving it**, and **pin explicitly** rather than
trusting a chart's `appVersion`.

## The phases

### Phase 1 — PostgreSQL off Bitnami → CloudNativePG

Bitnami's August 2025 catalogue change left `docker.io/bitnami/postgresql` carrying only `latest`.
Five databases (`litellm`, `paperless`, `gitea`, `n8n`, `legacy_use`) migrated to CloudNativePG
18.6, verified table-by-table with exact `count(*)` before cutover. See ADR-014.

### Phase 2 — Security

Began as "upgrade Kong 2.8.1, EOL since April 2022". Kong turned out to be a Supabase chart
*default*, and fixing it properly meant a PostgreSQL 15→17 migration — the exact failure mode
ADR-014 exists to prevent. Investigating whether that was worth it showed Supabase had zero
application tables and no traffic since February, and OpenClaw had been dead eight months while
still tarring 3.8 GB nightly. Both removed: **~53 GB reclaimed**, an EOL gateway off the ingress
path, and the migration avoided entirely. See ADR-015.

Also: cert-manager 1.19.2 → 1.21.2, and MetalLB 0.15.3 → 0.16.1.

### Phase 3 — Floating tags pinned

Five images pinned to the version already running, so upgrading became a deliberate act rather than
a side effect of a pod being rescheduled.

The Protonmail bridge was the sharp one: its upstream image had been **deleted**, surviving only as
a containerd cache on a single node. Any reschedule would have lost it permanently. Mirrored into
the Gitea registry and proven pullable from a node that never had it.

### Phase 4 — Application versions

| Application | From | To |
|---|---|---|
| n8n | 2.3.5 | 2.39.8 |
| LiteLLM | v1.81.9 | v1.101.0 |
| Stirling-PDF | 2.1.5 | 2.14.3 |
| Gitea | 1.24.6 | 1.27.3 |
| paperless-gpt | v0.24.0 | v0.28.0 |

n8n applied 129 schema migrations, LiteLLM 165. Both are irreversible by changing a tag back, so a
verified dump preceded each.

### Phase 5 — Observability

kube-prometheus-stack 80.14.4 → 91.4.1 (operator v0.87.1 → v0.94.0, Grafana 12.3.1 → 13.2.2,
Prometheus 3.14.0). Loki 3.6.3 → 3.7.8.

### Phase 6 — GPU node

Deferred by decision. `k3s-gpu-worker` is controlled manually and was deliberately stopped. See
[egpu-hotplug.md](../runbooks/egpu-hotplug.md) for the two cluster-wide side effects that causes.

### Follow-on — k3s v1.34.3 → v1.34.11

Traefik turned out not to be independently upgradable: it is a k3s-bundled chart managed by the
helm-controller, so its version is bound to the k3s release. A patch upgrade inside the existing
1.34 line carried Traefik **37.1.1 → 40.1.4** without a Kubernetes minor bump.

## Consequences

### The recurring pattern

**Three chart sources changed ownership**, each looking like a routine version bump until checked:

| Chart | What happened |
|---|---|
| `bitnami/postgresql` | versioned tags deleted from Docker Hub |
| `grafana/loki` | became Grafana Enterprise Logs only at 7.0.0; OSS moved to `grafana-community`, forked at 6.55.0 and renumbered from 18.x |
| Traefik | not independently upgradable — bound to the k3s release |

The lesson is that `helm repo update` followed by a version bump is not a safe default. **Check who
owns the chart before trusting its next version.**

### A pinned tag is not a current tag

Phase 3 fixed drift, not staleness. ntfy sat on v2.11.0 — seventeen minor versions behind — and the
audit missed it precisely because the tag was pinned and the pod was healthy. Pinning stops a
version changing underneath you; it says nothing about whether the pin is still a good one.

### State in `emptyDir` looks durable until something restarts

Two applications kept real state in an `emptyDir` and appeared fine because their pods had not
restarted in months:

- **Stirling-PDF** — `/configs` including its H2 database, rebuilt on every restart for 255 days
  unnoticed. The chart's own `persistence.enabled: true` does not fix this; it provisions a claim
  and still renders an empty `volumeMounts` block.
- **ntfy** — `user.db`, holding the `admin` account and every ACL. With
  `NTFY_AUTH_DEFAULT_ACCESS=deny`, losing it means Alertmanager gets 401s and **critical alerts stop
  reaching the phone silently**.

A sweep of all 39 `emptyDir` mounts found no others. The useful test is not "is this an emptyDir"
but **"if this vanished, would anything rebuild it?"** Grafana's `/var/lib/grafana` is an emptyDir
too and is safe, because all 28 dashboards come from ConfigMaps.

### Adding persistence introduces a second trap

An RWO claim plus a single-writer database means `RollingUpdate` starts a second pod on the same
files. Fixed with `strategy: Recreate` in Gitea, Stirling-PDF and ntfy. Gitea had been failing this
way on every upgrade for months, masked by the deployment happening to be scaled to zero first.

### Two credentials rotated

The Gitea admin password and the Gitea database password were both live in a public repository.
Neither was found by an incident — both came from the sweep procedure now in
[secret-rotation.md](../runbooks/secret-rotation.md).

### What it cost

A **4m45s database outage** during the k3s upgrade. A `nodeSelector` added in Phase 1 pinned
PostgreSQL to one node; its own comment justified excluding two nodes and then pinned to one,
ignoring that two others were valid. The PodDisruptionBudget refused the eviction, and once the pod
was deleted it could not reschedule anywhere. Gitea, n8n, LiteLLM and Paperless went down with it;
n8n needed a further 121 seconds and 9 retries to reconnect.

The pre-flight checks that would have caught it are now in
[k3s-upgrade.md](../runbooks/k3s-upgrade.md).

## Known gaps, deliberately left

- **PostgreSQL runs a single instance.** Draining either CPU worker is still an outage. The
  two-instance plan is written into `applications/postgres-cnpg/cluster.yaml`, unapplied.
- **No point-in-time recovery.** `pg_stat_archiver` reports success while storing nothing, and
  `archive_mode` cannot be disabled — it is a CNPG fixed parameter. See
  [postgres-backup.md](../runbooks/postgres-backup.md).
- **The database, its dumps and the etcd snapshots all live on the same Synology.** PITR would not
  fix this; offsite object storage would.
- **`k3s-gpu-worker` remains on v1.34.3** and upgrades when next started.

## References

- [ADR-014](ADR-014-postgres-off-bitnami.md) — Phase 1
- [ADR-015](ADR-015-retire-openclaw-and-supabase.md) — Phase 2
- [k3s-upgrade.md](../runbooks/k3s-upgrade.md) — pre-flight checks added after the outage
- [postgres-backup.md](../runbooks/postgres-backup.md) — what the nightly dump does not cover
- [egpu-hotplug.md](../runbooks/egpu-hotplug.md) — side effects of the GPU node being down
- [secret-rotation.md](../runbooks/secret-rotation.md) — the sweep that found both credentials
