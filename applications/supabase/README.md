# Supabase

Self-hosted Supabase backend — PostgreSQL, REST, Auth, Storage, Edge Functions and Studio.

**Epic:** 28 — Self-Hosted Supabase Backend
**Chart:** `supabase-community/supabase` v0.5.0 (pinned, NFR134)
**Namespace:** `backend`

## Overview

| Component | Deployment | Purpose |
|-----------|-----------|---------|
| `supabase-supabase-db` | StatefulSet | PostgreSQL on NFS |
| `supabase-supabase-kong` | Deployment | API gateway, fronts everything else |
| `supabase-supabase-rest` | Deployment | PostgREST — auto REST API over the schema |
| `supabase-supabase-auth` | Deployment | GoTrue — sign-up, sign-in, OAuth |
| `supabase-supabase-storage` | Deployment | Storage API, files on NFS |
| `supabase-supabase-functions` | Deployment | Deno edge functions |
| `supabase-supabase-meta` | Deployment | postgres-meta — schema introspection for Studio |
| `supabase-supabase-studio` | Deployment | Web console |

**Disabled to keep the footprint under 2Gi (NFR139):** Analytics (Logflare), Realtime, Vector, imgproxy.

## Access

All ingress is Tailscale-only, TLS via cert-manager:

| Host | Serves |
|------|--------|
| `studio.supabase.home.jetzinger.com` | Studio console |
| `api.supabase.home.jetzinger.com` | Kong gateway / PostgREST |
| `auth.supabase.home.jetzinger.com` | GoTrue |
| `storage.supabase.home.jetzinger.com` | Storage API |
| `functions.supabase.home.jetzinger.com` | Edge Functions |

## Deployment

```bash
helm upgrade --install supabase supabase-community/supabase \
  -f applications/supabase/values-homelab.yaml -n backend

kubectl --context default apply -f applications/supabase/ingressroute.yaml
```

**Follow [`docs/runbooks/supabase-helm-upgrade.md`](../../docs/runbooks/supabase-helm-upgrade.md)
for any upgrade.** The chart has no `dnsPolicy` support, so the `dnsPolicy: None` patches that Auth,
Kong and Functions need are applied after deploy — and **Helm drops them on every upgrade**. Without
them, the `*.jetzinger.com` wildcard swallows external hostnames like `accounts.google.com` and OAuth
breaks.

## Secrets

Every credential comes from the `supabase-secrets` Secret via the chart's `secretRef` /
`secretRefKey` mechanism. `values-homelab.yaml` holds only the *mapping*, never a value.

| Chart block | Secret key |
|-------------|-----------|
| `secret.jwt` | `ANON_KEY`, `SERVICE_ROLE_KEY`, `JWT_SECRET` |
| `secret.db` | `POSTGRES_PASSWORD`, `DB_DATABASE` |
| `secret.smtp` | `SMTP_USERNAME`, `GOTRUE_SMTP_PASS` |
| `secret.dashboard` | `DASHBOARD_USERNAME`, `DASHBOARD_PASSWORD`, `OPENAI_API_KEY` |
| `secret.meta` | `META_CRYPTO_KEY` |

Apply values with `kubectl patch`, never `kubectl apply` on a placeholder file — see
[`docs/runbooks/secret-rotation.md`](../../docs/runbooks/secret-rotation.md).

### `META_CRYPTO_KEY`

Moved out of `values-homelab.yaml` and rotated on **2026-09-20**. It had been a hardcoded chart
placeholder committed to a public repo while `meta.enabled: true`.

postgres-meta uses this key only to decrypt the inbound `x-connection-encrypted` request header at
request time. Nothing is encrypted at rest, so rotating it is safe and needs no data migration —
restart `supabase-supabase-meta` and Studio afterwards.

`secret.realtime.secretKeyBase` is deliberately left as the literal string
`not-used-realtime-disabled`. Realtime is disabled; the value is a self-documenting placeholder,
not an exposure.

## Storage

- PostgreSQL data and the Storage API's file bucket both sit on NFS (Synology DS920+).
- All components are pinned to `k3s-worker-01` by `nodeSelector`.

## SMTP

GoTrue is pointed at the cluster-local Protonmail Bridge
(`protonmail-bridge.docs.svc.cluster.local:25`, FR236/FR237).

**In practice almost no mail is sent.** `GOTRUE_MAILER_AUTOCONFIRM: "true"` confirms new accounts
without an email round-trip, because the consumers are programmatic backends with no human
verification flow. The SMTP config exists so that invite and recovery paths work if they are ever
switched on.

If you do enable a mail flow and nothing arrives, check the bridge first — it crashes silently and
`socat` masks the failure. See
[`applications/paperless/protonmail-bridge/README.md`](../paperless/protonmail-bridge/README.md).

## Related

- [`docs/runbooks/supabase-helm-upgrade.md`](../../docs/runbooks/supabase-helm-upgrade.md) — upgrade procedure and dnsPolicy re-patching
- [`docs/runbooks/secret-rotation.md`](../../docs/runbooks/secret-rotation.md) — credential rotation
- `values-homelab.yaml` — the FR/NFR map is in the file header
