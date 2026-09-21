# ADR-015: Retire OpenClaw and Self-Hosted Supabase

**Status:** Accepted
**Date:** 2026-09-21
**Supersedes:** [ADR-011](ADR-011-openclaw-personal-ai-assistant.md) (OpenClaw), Epic 28 (Supabase)

## Context

Phase 2 of the cluster update campaign set out to fix Kong **2.8.1** — released April 2022, long
EOL, and fronting `api.supabase.home.jetzinger.com`. Investigating how to upgrade it turned into a
better question: is any of this used?

### Kong could not be fixed in isolation

`kong:2.8.1` is the **chart default** in `supabase-community/supabase` 0.5.0, not an override.
Overriding just the image would pair Kong 3 with a Kong-2-era declarative config. The proper route
is chart 0.5.0 → 0.8.0, which ships `kong/kong:3.9.1` with a matching config — but it also bumps
`supabase/postgres` **15.8.1.085 → 17.6.1.136**.

That is a major PostgreSQL jump against an existing PG 15 data directory: the server would refuse
to start. Precisely the failure class [ADR-014](ADR-014-postgres-off-bitnami.md) was written to
eliminate, one day earlier.

So the options were a PG 15→17 migration, or pinning the db image and hoping 0.8.0 tolerates PG 15.
Both are real work to keep a stack nothing uses.

### Neither stack was in use

**Supabase.** Epic 28's goal was replacing supabase.com for the calsync and pilates dev container
backends. The config migration happened; nothing else did.

| Check | Result |
|---|---|
| Tables in the `public` schema | **0** |
| `auth.users` | 1, created 2026-02-23 (validation) |
| `storage.objects` | 1 — `hello.txt` |
| Kong gateway traffic | 36 requests, **all** on 23–24 Feb 2026 |
| DB connections | only Supabase's own components |
| calsync / pilates dev containers | pointed at it, ran **only sshd for 208 days** |

**OpenClaw.** Last reported `Available` on **2026-01-31**; the deployment sat at `0/0` for eight
months. Yet `openclaw-env-backup` still ran nightly — it tarred **3.8 GB over 20 minutes** at 02:00
on the day of removal, retaining seven such archives. `OpenClawGatewayDown` had been firing since
14 September. Four IngressRoutes still routed to a scaled-to-zero deployment.

The `activeDeadlineSeconds: 600 → 3600` change committed that same morning in `b5667fe` was tuning
that CronJob — for an application already dead eight months. Nobody noticed, because a backup job
that succeeds looks identical whether or not its subject matters.

## Decision

Remove both stacks entirely, including OpenClaw's backups.

## Consequences

**Reclaimed:** ~53 GB of storage (OpenClaw 10Gi data + 20Gi backups, Supabase 4 PVCs totalling
9Gi), 9 pods, ~1.3 GB RAM on k3s-worker-01, 14 IngressRoutes, 2 certificates.

**Removed problems:** an EOL gateway on an ingress path, a PG 15→17 migration, and two firing
alerts — deleted at the rule, not silenced.

**Lost permanently:** OpenClaw's workspace. A final `pg_dumpall` of Supabase was taken to the
`postgres-backup` PVC as `supabase-final-*.sql.gz` (32 KB, gzip-verified) — small because there was
nothing in it.

**Unaffected:** pilates4golf production runs on the supabase.com project `rgdsgudrnmwjmesfvrsz`,
entirely separate from the retired self-hosted instance.

### Verified before deleting

cert-manager had been upgraded to 1.21.2 that morning, and its verification was incomplete: 24/24
certificates `Ready` only means the **stored** certs are valid, and the logged "verified existing
registration with ACME server" proves outbound DNS and HTTPS but not a full challenge cycle. The
solver is `dns01/cloudflare`, so issuance also needs the Cloudflare API and a TXT record.

Nothing had been issued since the upgrade — the newest `CertificateRequest` was 11 days old and the
earliest natural renewal was 2026-10-05. A broken issuer would have stayed invisible for two weeks
and then surfaced as an expired certificate.

A throwaway Certificate against `letsencrypt-staging` was therefore issued first: **valid in 82
seconds**, `Order` reached `valid`, real staging cert (`CN=issuance-probe.home.jetzinger.com`,
issuer `(STAGING) Dastardly Durum YR1`). Deleted afterwards. Doing this before removing two
certificates means any future issuance problem cannot be blamed on this work.

### Things found along the way

- **A second alert rule was missed in planning.** The plan named `OpenClawGatewayDown`; the rules
  file also carried `OpenclawCrashLooping` from Story 21.4. Found by parsing the file after the
  first edit and listing what remained, not by grepping for what was expected.
- **Deleting a Prometheus rule does not resolve its alert.** Prometheus simply stops sending it and
  never emits a resolved notification, so Alertmanager holds the alert until `resolve_timeout`.
  Expect a lag; it is not a failed removal.
- **Cross-namespace secret references do not resolve.** The final Supabase dump needed the password
  from `backend` and the backup PVC in `data`. The password had to be copied into a temporary
  secret in `data` first. The same trap was found in `applications/postgres/test-client.yaml`
  during ADR-014.

## References

- `docs/adrs/ADR-014-postgres-off-bitnami.md` — the PG major-version trap this avoided repeating
- `docs/adrs/ADR-011-openclaw-personal-ai-assistant.md` — superseded by this
- Epic 28 in `docs/planning-artifacts/epics.md` — superseded by this
