# ADR-017: Retire the Dev Containers and the nginx Proxy

**Status:** Accepted
**Date:** 2026-09-22
**Supersedes:** Epic 7 (nginx reverse proxy), Epic 11 (dev containers)
**Precedent:** [ADR-015](ADR-015-retire-openclaw-and-supabase.md)

## Context

Three dev containers — `calsync`, `pilates`, `ai-dev` — and the `nginx-proxy` in front of them were
deployed in January 2026 and stopped being used in February. This is the third time this pattern has
appeared in this cluster: deployed, validated, then left running.

### The evidence

| Check | Result |
|---|---|
| What the containers actually ran | **`sshd` only** — confirmed with `ps` in all three |
| Last HTTP request through `nginx-proxy` | **2026-02-25**, returning **502 Connection refused** |
| Container log volume, last 7 days | 8 lines total |
| External upstreams `/app1`, `/app2` | `192.168.2.50:3000`, `192.168.2.51:8080` — neither responded |

The 502 is the part that settles it. The last person to open `dev.www.pilates4.golf` got an error,
because nothing was listening on port 3000 even then. The HTTP dev environments had been broken for
seven months before anyone removed them.

### What the proxy was actually doing

`nginx-proxy` terminated three SSH ports (2222/2223/2224) for the dev containers, served
`dev.calsync.info` and six `dev.*.pilates4.golf` hostnames, and proxied `/app1` and `/app2` to two
LAN addresses that no longer answer. With the dev containers gone, every one of those is dead.

## Decision

Remove all of it: the three dev containers and their 20Gi volumes, `nginx-proxy`, the `hello-nginx`
test deployment beside it, and the four certificates and five IngressRoute pairs they needed.

Also disable **k3s ServiceLB**, which the same investigation showed to be structurally unable to
serve this cluster — see below. `disable: servicelb` is set in the master's `config.yaml` and
applied.

## Consequences

- **~60 GB of local-path storage reclaimed** across the three 20Gi home volumes
- **6 pods gone**, ~200m CPU and ~832Mi of memory requests released
- **`192.168.2.101` returned to the MetalLB pool**, leaving `traefik` as the only LoadBalancer
- **4 certificates stop renewing**: `dev-calsync-tls`, `dev-pilates-tls`, `dev-proxy-tls`,
  `hello-tls`

### Work discarded deliberately

Recorded because it is not recoverable. The user chose to discard rather than preserve it.

- **calsync** (5.0 GB) — branch **`n8n` existed only in this container**: 9 commits absent from
  `github.com/tjetzinger/calsync`, plus 48 uncommitted files. Its other five branches were all
  pushed and `ahead=0`.
- **pilates** (2.6 GB) — branch `main`, fully pushed, one uncommitted file (`CLAUDE.md`).
- **ai-dev** (517 MB) — no git repository at all.

### k3s ServiceLB removed

Three `svclb` pods had been permanently `Pending`. The cause was a hostPort collision:
`svclb-traefik` wanted port 2222 for `gitea-ssh` and `svclb-nginx-proxy-ssh` wanted the same port
for `ssh-calsync`. MetalLB serves those on two different IPs without difficulty; **ServiceLB cannot,
because a hostPort is per-node and has no notion of which address traffic arrived on.**

MetalLB is the implementation worth keeping, and not only because of that. `192.168.2.100` is a
MetalLB VIP that **42 IngressRoutes and the entire `*.home.jetzinger.com` wildcard** depend on.
Under ServiceLB a service's `EXTERNAL-IP` is the node IPs, so that address would cease to exist,
every DNS record would need repointing, and VIP failover would be lost — with MetalLB the address
moves to a healthy node and DNS never changes.

Removing `nginx-proxy-ssh` ended the collision on its own; disabling ServiceLB removes a component
that was contributing nothing.

### Things found along the way

- **`applications/nginx/test-ingress.yaml` also defined the `kube-system/https-redirect`
  Middleware**, which the Traefik dashboard depends on. Deleting that file's resources took the
  middleware with it and broke the dashboard's HTTP→HTTPS redirect. The definition has been moved
  into `infrastructure/traefik/dashboard-ingress.yaml`, where it belongs. A shared resource had
  been living inside a file named after a throwaway test app.
- **The `dev.*` DNS names were never public.** `dig` from inside the network returned
  `192.168.2.100`, but Cloudflare holds **no `dev.*` records in either zone** and `1.1.1.1` returns
  NXDOMAIN. They resolved through a local split-horizon resolver, so those dev environments were
  only ever reachable from the home network. No registrar cleanup was needed.

## References

- [ADR-015](ADR-015-retire-openclaw-and-supabase.md) — the same pattern, two stacks earlier
- [ADR-016](ADR-016-cluster-update-campaign.md) — the campaign that surfaced this
- [k3s-svclb-recovery.md](../runbooks/k3s-svclb-recovery.md) — assumes ServiceLB exists; now historical
