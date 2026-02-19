# Story 27.2: Configure Alertmanager Webhook to Internal ntfy Service

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **cluster operator**,
I want **to configure Alertmanager to deliver P1 alerts via webhook to the internal ntfy cluster service**,
so that **alert delivery is fully internal with no external network dependency on the critical notification path**.

## Acceptance Criteria

1. **Given** ntfy is running in the `monitoring` namespace (Story 27.1 complete)
   **When** I publish a test message to `http://ntfy.monitoring.svc.cluster.local/homelab-alerts` with admin credentials
   **Then** the topic accepts the message and it appears in ntfy server logs (FR225)

2. **Given** the ntfy topic exists
   **When** I update `monitoring/prometheus/values-homelab.yaml` to mount the `ntfy-credentials` K8s Secret and set the webhook receiver URL with credential file reference
   **And** I run `helm upgrade` for `kube-prometheus-stack`
   **Then** the upgrade completes without errors
   **And** the Alertmanager pod restarts cleanly and reaches `Running` state

3. **Given** the Alertmanager pod is running
   **When** I inspect the active Alertmanager config
   **Then** the `mobile-notifications` webhook receiver is present with URL `http://ntfy.monitoring.svc.cluster.local/homelab-alerts`
   **And** the route for `severity = "critical"` correctly maps to the `mobile-notifications` receiver
   **And** credentials are not exposed in the config (loaded from `password_file`, not inline)

4. **Given** the webhook is configured
   **When** I fire a test alert via `amtool alert add` with `severity=critical`
   **Then** Alertmanager sends the webhook POST to `http://ntfy.monitoring.svc.cluster.local/homelab-alerts` (FR225)
   **And** the delivery appears in ntfy server logs (`kubectl logs -n monitoring deployment/ntfy`)
   **And** no external network call is made on the alert delivery path

## Tasks / Subtasks

⚠️ **DRAFT TASKS** - Generated from requirements analysis. Will be validated and refined against actual codebase when dev-story runs.

- [x] Task 1: Update Alertmanager Helm values to mount ntfy-credentials and configure webhook (AC: #2)
  - [x] Subtask 1.1: In `monitoring/prometheus/values-homelab.yaml`, add `alertmanager.alertmanagerSpec.secrets: [ntfy-credentials]` to mount the K8s Secret from Story 27.1 into the Alertmanager pod at `/etc/alertmanager/secrets/ntfy-credentials/`
  - [x] Subtask 1.2: In the same file, update the `mobile-notifications` receiver `webhook_configs` entry: set `url: http://ntfy.monitoring.svc.cluster.local/homelab-alerts`, add `http_config.basic_auth.username: admin` and `http_config.basic_auth.password_file: /etc/alertmanager/secrets/ntfy-credentials/NTFY_ADMIN_PASS`
  - [x] Subtask 1.3: Run `helm upgrade kube-prometheus-stack prometheus-community/kube-prometheus-stack -n monitoring -f monitoring/prometheus/values-homelab.yaml` and verify Alertmanager pod restarts and reaches `Running` state

- [x] Task 2: Verify Alertmanager config and confirm topic accepts messages (AC: #1, #3)
  - [x] Subtask 2.1: Inspect active Alertmanager config: `kubectl exec -n monitoring alertmanager-kube-prometheus-stack-alertmanager-0 -- cat /etc/alertmanager/config_out/alertmanager.env.yaml` — confirm webhook URL and `mobile-notifications` receiver present
  - [x] Subtask 2.2: Verify `ntfy-credentials` secret is mounted: `kubectl exec -n monitoring alertmanager-kube-prometheus-stack-alertmanager-0 -- ls /etc/alertmanager/secrets/ntfy-credentials/`
  - [x] Subtask 2.3: Test ntfy topic by publishing a message directly from within the cluster via wget with Basic auth — message published successfully (id: IitRTPfI6QP3), confirmed in ntfy stats logs (messages_published=1)

- [x] Task 3: Test end-to-end alert delivery via Alertmanager webhook (AC: #4)
  - [x] Subtask 3.1: Fire test alert via amtool: `alertname=TestNtfyWebhook severity=critical` — alert accepted by Alertmanager API (group_wait=10s)
  - [x] Subtask 3.2: Verify ntfy server logs show the incoming POST from Alertmanager: messages_published counter incremented from 2→3 in the 23:18:57 stat cycle (alert fired at 23:18:12, webhook delivered ~23:18:22)
  - [x] Subtask 3.3: Confirm delivery was cluster-internal only — ntfy ClusterIP service, no external egress required on alert path

## Gap Analysis

**Scan Date:** 2026-02-20

**✅ What Exists:**
- `monitoring/prometheus/values-homelab.yaml` — file present
- `alertmanager.config.receivers[mobile-notifications]` — receiver already defined
- Route `severity = "critical"` → `mobile-notifications` — correctly wired, no change needed
- `send_resolved: true`, `http_config.follow_redirects: true`, `max_alerts: 0` — already in `webhook_configs`

**❌ What's Missing:**
- `alertmanager.alertmanagerSpec.secrets: [ntfy-credentials]` — not present, must be added (Task 1.1)
- `url: http://ntfy.monitoring.svc.cluster.local/homelab-alerts` — missing from `webhook_configs` (Task 1.2)
- `http_config.basic_auth` block — missing from `webhook_configs` (Task 1.2)

**Task Changes Applied:** None — draft tasks accurately reflect codebase state.

---

## Dev Notes

### Architecture Decisions (MUST follow)

**Alertmanager Webhook Pattern (internal cluster DNS — FR225):**
- Webhook URL: `http://ntfy.monitoring.svc.cluster.local/homelab-alerts`
- No external network call on the critical alert path (Alertmanager and ntfy are co-located in `monitoring` namespace)
- Authentication: `basic_auth` with `username: admin` and `password_file` pointing to mounted K8s secret

**Credentials — NEVER in git:**
Mount the existing `ntfy-credentials` K8s Secret (created in Story 27.1) via `alertmanagerSpec.secrets`. Alertmanager Operator mounts K8s secrets at `/etc/alertmanager/secrets/<secret-name>/<key>`. This means credentials stay in-cluster, not in git-committed values.

### Critical: Existing Alertmanager Config State

The `mobile-notifications` receiver in `monitoring/prometheus/values-homelab.yaml` already exists with:
- Route: `severity = "critical"` → `mobile-notifications` ✅ (no change needed)
- `send_resolved: true` ✅ (no change needed)
- `follow_redirects: true` ✅ (no change needed)
- **MISSING: `url` field** — the old ntfy.sh URL was removed when `secrets/ntfy-secrets.yaml` was replaced in Story 27.1

Story 27.2 adds ONLY:
1. `alertmanagerSpec.secrets: [ntfy-credentials]`
2. `url`, `http_config.basic_auth.username`, `http_config.basic_auth.password_file` to the existing `webhook_configs` entry

**Do NOT:**
- Create a new receiver (already exists)
- Change routing rules (critical alerts already route correctly)
- Modify `monitoring/prometheus/custom-rules.yaml` (already has `severity: critical` labels)
- Store credentials inline in `values-homelab.yaml`

### Complete Target Config (what values-homelab.yaml should look like after Task 1)

```yaml
alertmanager:
  alertmanagerSpec:
    secrets:
      - ntfy-credentials   # <-- ADD THIS: mounts at /etc/alertmanager/secrets/ntfy-credentials/

  config:
    ...
    receivers:
      - name: 'null'
      - name: 'mobile-notifications'
        webhook_configs:
          - url: http://ntfy.monitoring.svc.cluster.local/homelab-alerts   # <-- ADD
            send_resolved: true
            http_config:
              follow_redirects: true
              basic_auth:                                                   # <-- ADD
                username: admin                                             # <-- ADD
                password_file: /etc/alertmanager/secrets/ntfy-credentials/NTFY_ADMIN_PASS  # <-- ADD
            max_alerts: 0
```

### ntfy Topic

- Topic name: `homelab-alerts` (descriptive, internal, aligns with Epic 27 intent)
- Topics in ntfy are created automatically on first publish — no `ntfy topic add` command needed
- Admin user (`admin` role) has publish access to all topics by default

### ntfy Message Format

When Alertmanager fires a webhook, it POSTs the standard Alertmanager webhook JSON payload to the ntfy topic URL. ntfy v2.11.0 receives this and publishes the raw JSON as the message body to the `homelab-alerts` topic. The mobile app (Story 27.3) will receive the notification with JSON content.

> **Note:** Message formatting (X-Title, X-Priority headers, templates) can be improved in a follow-up if desired. The current approach satisfies FR225 (internal delivery) and Story 27.3 validates end-to-end mobile delivery.

### Alertmanager Pod Name

The Alertmanager pod follows the pattern: `alertmanager-kube-prometheus-stack-alertmanager-0`. Confirm the exact name with:
```bash
kubectl get pods -n monitoring | grep alertmanager
```

### Helm Upgrade Command

```bash
helm upgrade kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f monitoring/prometheus/values-homelab.yaml
```

No additional `-f` secrets file needed — credentials are loaded from the mounted K8s Secret at runtime.

### Verification Commands

```bash
# Confirm Alertmanager pod name
kubectl get pods -n monitoring | grep alertmanager

# Inspect active rendered config
kubectl exec -n monitoring alertmanager-kube-prometheus-stack-alertmanager-0 \
  -- cat /etc/alertmanager/config_out/alertmanager.env.yaml

# Confirm secret is mounted
kubectl exec -n monitoring alertmanager-kube-prometheus-stack-alertmanager-0 \
  -- ls /etc/alertmanager/secrets/ntfy-credentials/
# Should show: NTFY_ADMIN_PASS  NTFY_ADMIN_USER

# Check ntfy logs for incoming webhook
kubectl logs -n monitoring deployment/ntfy --tail=30 -f

# Fire test alert (run in a separate terminal while watching ntfy logs)
kubectl exec -n monitoring alertmanager-kube-prometheus-stack-alertmanager-0 \
  -- amtool alert add alertname=TestNtfyWebhook severity=critical \
     --alertmanager.url=http://localhost:9093
```

### Previous Story Learnings (Story 27.1)

- **ntfy image:** `binwiederhier/ntfy:v2.11.0` (pinned)
- **ntfy service:** `ntfy.monitoring.svc.cluster.local:80` (ClusterIP)
- **Admin user:** `admin` — created via `NTFY_PASSWORD=... ntfy user add --role=admin admin`
- **Credentials secret:** `ntfy-credentials` in `monitoring` namespace with keys `NTFY_ADMIN_USER` and `NTFY_ADMIN_PASS`
- **Auth behavior:** ntfy returns `403 Forbidden` for unauthenticated requests (not 401) — `AUTH_DEFAULT_ACCESS=deny`
- **cert-manager fix:** `dnsPolicy: None` applied to cert-manager pods (no impact on this story)
- **Commit pattern:** `feat: <description> (Story 27.2)` prefix

### Project Structure Notes

- Alertmanager Helm values (only file to modify): `monitoring/prometheus/values-homelab.yaml`
- ntfy K8s Secret (from Story 27.1): `ntfy-credentials` in `monitoring` namespace — DO NOT recreate
- Custom alert rules (no changes): `monitoring/prometheus/custom-rules.yaml` — severity=critical labels already correct
- No new files needed — this story is a config-only change to one existing Helm values file

### References

- FR225: Alertmanager webhook → `http://ntfy.monitoring.svc.cluster.local` [Source: docs/planning-artifacts/prd.md#FR225]
- NFR5: P1 alerts within 1 minute via self-hosted ntfy [Source: docs/planning-artifacts/prd.md#NFR5]
- Architecture decision: [Source: docs/planning-artifacts/architecture.md#Self-Hosted Notification Architecture (ntfy)]
- Current Alertmanager config: [Source: monitoring/prometheus/values-homelab.yaml#receivers]
- ntfy-credentials K8s Secret: created in Story 27.1 [Source: docs/implementation-artifacts/27-1-deploy-self-hosted-ntfy-to-monitoring-namespace.md]
- kube-prometheus-stack secret mounting: `alertmanager.alertmanagerSpec.secrets` — Prometheus Operator docs

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

- Alertmanager pod restarted cleanly after helm upgrade (REVISION: 6, pod Running 2/2 after 17s)
- Active config verified via `cat /etc/alertmanager/config_out/alertmanager.env.yaml` — webhook URL and basic_auth present, credentials as password_file
- ntfy-credentials secret mounted at `/etc/alertmanager/secrets/ntfy-credentials/` with keys: NTFY_ADMIN_PASS, NTFY_ADMIN_USER
- Direct publish test via wget succeeded (id: IitRTPfI6QP3, topic: homelab-alerts)
- amtool test alert fired at 23:18:12; ntfy messages_published counter incremented 2→3 at 23:18:57 stat cycle (confirms webhook delivery)

### Completion Notes List

- Implemented in a single config-only change to `monitoring/prometheus/values-homelab.yaml`
- Added `alertmanagerSpec.secrets: [ntfy-credentials]` — mounts K8s secret at `/etc/alertmanager/secrets/ntfy-credentials/`
- Updated `mobile-notifications` webhook_configs: added `url`, `http_config.basic_auth.username`, and `http_config.basic_auth.password_file`
- Credentials are NOT stored in git — loaded from mounted K8s Secret at runtime (password_file pattern)
- All 4 acceptance criteria validated against live cluster
- No external network dependency on critical alert path: Alertmanager → ntfy (ClusterIP) fully cluster-internal

### File List

- `monitoring/prometheus/values-homelab.yaml` (modified — added alertmanagerSpec.secrets, webhook url, basic_auth)

## Change Log

| Date | Change |
|------|--------|
| 2026-02-20 | Tasks refined based on codebase gap analysis — no changes needed, draft tasks accurate |
| 2026-02-20 | Development started — status → in-progress |
| 2026-02-20 | Implementation complete — all tasks done, all ACs verified against live cluster, status → review |
