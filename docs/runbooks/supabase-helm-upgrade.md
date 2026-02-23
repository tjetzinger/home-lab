# Supabase Helm Upgrade Procedure

**Purpose:** Safe upgrade procedure for Supabase Helm chart with dnsPolicy re-patching

**Story:** 28.2 - Deploy Supabase Core via Helm
**Date Created:** 2026-02-23
**Last Updated:** 2026-02-23

---

## Overview

The Supabase community Helm chart (v0.5.0) does **not** support `dnsPolicy` or `dnsConfig` natively in its deployment templates. The `dnsPolicy: None` configuration required by our `*.jetzinger.com` wildcard DNS interception is applied via post-deploy `kubectl patch`. **These patches are lost on every Helm upgrade** because Helm recreates the deployment specs from the chart templates.

**Affected Deployments:**
- `supabase-supabase-auth` (GoTrue) — OAuth provider callbacks need external DNS
- `supabase-supabase-kong` (API Gateway) — external health checks
- `supabase-supabase-functions` (Edge Functions) — external API calls from Deno runtime

**Why This Matters:**
Without `dnsPolicy: None`, these pods inherit the node's DNS search domains which include `jetzinger.com`. External hostnames like `accounts.google.com` get resolved as `accounts.google.com.jetzinger.com` (wildcard match) instead of the real address, breaking OAuth flows and external API calls.

---

## Pre-Upgrade Checklist

- [ ] Verify current Helm revision: `helm history supabase -n backend`
- [ ] Run `helm diff` to preview changes (install plugin: `helm plugin install https://github.com/databus23/helm-diff`)
- [ ] Verify all pods are healthy: `kubectl get pods -n backend`
- [ ] Note current chart version: `helm list -n backend`

---

## Upgrade Procedure

### Step 1: Diff the Upgrade

```bash
helm diff upgrade supabase supabase-community/supabase \
  --version <NEW_VERSION> \
  -f applications/supabase/values-homelab.yaml \
  -n backend
```

Review changes carefully. Pay attention to any new secret keys or template changes.

### Step 2: Run the Helm Upgrade

```bash
helm upgrade supabase supabase-community/supabase \
  --version <NEW_VERSION> \
  -f applications/supabase/values-homelab.yaml \
  -n backend
```

### Step 3: Wait for Pods to Stabilize

```bash
kubectl rollout status deployment/supabase-supabase-auth -n backend --timeout=120s
kubectl rollout status deployment/supabase-supabase-kong -n backend --timeout=120s
kubectl rollout status deployment/supabase-supabase-functions -n backend --timeout=120s
```

### Step 4: Re-Apply dnsPolicy Patches

```bash
# Auth (GoTrue)
kubectl patch deployment supabase-supabase-auth -n backend --type='json' \
  -p='[{"op":"add","path":"/spec/template/spec/dnsPolicy","value":"None"},{"op":"add","path":"/spec/template/spec/dnsConfig","value":{"nameservers":["10.43.0.10"],"searches":["backend.svc.cluster.local","svc.cluster.local","cluster.local"],"options":[{"name":"ndots","value":"5"}]}}]'

# Kong (API Gateway)
kubectl patch deployment supabase-supabase-kong -n backend --type='json' \
  -p='[{"op":"add","path":"/spec/template/spec/dnsPolicy","value":"None"},{"op":"add","path":"/spec/template/spec/dnsConfig","value":{"nameservers":["10.43.0.10"],"searches":["backend.svc.cluster.local","svc.cluster.local","cluster.local"],"options":[{"name":"ndots","value":"5"}]}}]'

# Edge Functions (Deno)
kubectl patch deployment supabase-supabase-functions -n backend --type='json' \
  -p='[{"op":"add","path":"/spec/template/spec/dnsPolicy","value":"None"},{"op":"add","path":"/spec/template/spec/dnsConfig","value":{"nameservers":["10.43.0.10"],"searches":["backend.svc.cluster.local","svc.cluster.local","cluster.local"],"options":[{"name":"ndots","value":"5"}]}}]'
```

### Step 5: Verify Patches Applied

```bash
for dep in auth kong functions; do
  echo "=== $dep ==="
  kubectl get pod -n backend -l app.kubernetes.io/name=supabase-$dep \
    -o jsonpath='{.items[0].spec.dnsPolicy}'
  echo
done
```

Expected output: `None` for all three.

### Step 6: Verify All Pods Running

```bash
kubectl get pods -n backend -o wide
```

All 8 pods should be `Running` and `1/1` on `k3s-worker-01`.

---

## Post-Upgrade Validation

### Quick Health Checks

```bash
# PostgREST API (via Kong)
ANON_KEY=$(kubectl get secret supabase-secrets -n backend -o jsonpath='{.data.ANON_KEY}' | base64 -d)
kubectl run curl-check --image=curlimages/curl --rm -it --restart=Never -n backend -- \
  curl -s -o /dev/null -w "%{http_code}" \
  "http://supabase-supabase-kong.backend.svc.cluster.local:8000/rest/v1/" \
  -H "apikey: $ANON_KEY"
# Expected: 200

# Studio Dashboard
kubectl run curl-studio --image=curlimages/curl --rm -it --restart=Never -n backend -- \
  curl -s -o /dev/null -w "%{http_code}" \
  "http://supabase-supabase-studio.backend.svc.cluster.local:3000/"
# Expected: 307 (redirect to login)
```

### PostgreSQL Extensions

```bash
kubectl exec supabase-supabase-db-0 -n backend -- \
  psql -U postgres -c "SELECT extname FROM pg_extension WHERE extname IN ('pgsodium','pg_graphql','pg_net','pgcrypto','pgjwt') ORDER BY extname;"
```

---

## Rollback Procedure

```bash
# View history
helm history supabase -n backend

# Rollback to previous revision
helm rollback supabase <REVISION_NUMBER> -n backend

# Re-apply dnsPolicy patches (Step 4 above)
```

**Note:** Rollback also requires re-applying dnsPolicy patches.

---

## DNS Config Reference

The DNS config used in patches follows the proven pattern from cert-manager (`infrastructure/cert-manager/values-homelab.yaml`):

| Field | Value | Purpose |
|-------|-------|---------|
| `nameservers` | `10.43.0.10` | CoreDNS ClusterIP |
| `searches` | `backend.svc.cluster.local`, `svc.cluster.local`, `cluster.local` | Cluster DNS resolution |
| `ndots` | `5` | Match K8s default |

**Critical:** Do NOT include `jetzinger.com` in search domains. This is the root cause of the wildcard DNS interception issue.

---

## Known Limitations

- **dnsPolicy patches are not persisted in Helm values** — The chart would need upstream changes to support `dnsPolicy`/`dnsConfig` in deployment templates.
- **StatefulSet PVCs are not managed by Helm** — If the PostgreSQL PVC storage class or size needs changing, manually delete the StatefulSet and PVC before upgrading.
- **Kong requires 256Mi+ memory at startup** — Do not set Kong memory limits below 1Gi.

---

## References

- [Supabase Community Helm Chart](https://github.com/supabase-community/supabase-kubernetes)
- Story 28.2: Deploy Supabase Core via Helm
- `infrastructure/cert-manager/values-homelab.yaml` — dnsPolicy reference implementation
- `applications/supabase/values-homelab.yaml` — Helm values file
