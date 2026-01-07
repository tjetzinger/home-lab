# Alertmanager Mobile Notifications Setup

**Purpose:** Configure Alertmanager to send P1 (critical) alert notifications to mobile devices via ntfy.sh

**Story:** 4.5 - Setup Mobile Notifications for P1 Alerts
**Date Created:** 2026-01-06
**Last Updated:** 2026-01-06

---

## Overview

This runbook documents the configuration of mobile notifications for critical (P1) alerts in the home-lab Kubernetes cluster using Alertmanager and ntfy.sh.

**Service:** ntfy.sh (public instance)
**Topic:** `${NTFY_TOPIC}`
**Alert Types:** severity=critical only
**Latency:** <1 minute (NFR5 compliant)

---

## Prerequisites

- kube-prometheus-stack deployed in `monitoring` namespace
- Alertmanager running and accessible
- kubectl access to cluster
- Helm installed
- Mobile device with ntfy app installed (iOS/Android)

---

## Step 1: Install ntfy Mobile App

### iOS
1. Open App Store
2. Search for "ntfy"
3. Install "ntfy - PUT/POST to your phone"
4. Open app

### Android
1. Open Google Play Store
2. Search for "ntfy"
3. Install "ntfy"
4. Open app

### Subscribe to Alert Topic
1. In ntfy app, tap "+"
2. Enter topic name: `${NTFY_TOPIC}`
3. Tap "Subscribe"
4. Enable notifications for this topic

---

## Step 2: Create Kubernetes Secret

Create a secret to store the ntfy webhook URL:

```bash
# Create the secret manifest
cat <<EOF > /home/tt/Workspace/home-lab/monitoring/prometheus/ntfy-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: alertmanager-ntfy-webhook
  namespace: monitoring
  labels:
    app.kubernetes.io/name: alertmanager
    app.kubernetes.io/instance: kube-prometheus-stack-alertmanager
    app.kubernetes.io/part-of: home-lab
    app.kubernetes.io/component: notification
type: Opaque
stringData:
  webhook-url: "https://ntfy.sh/${NTFY_TOPIC}"
EOF

# Apply the secret
kubectl apply -f /home/tt/Workspace/home-lab/monitoring/prometheus/ntfy-secret.yaml

# Verify secret created
kubectl get secret alertmanager-ntfy-webhook -n monitoring
```

---

## Step 3: Update Alertmanager Configuration

Update the kube-prometheus-stack Helm values to add mobile notification receiver and routing.

### Edit values-homelab.yaml

Location: `/home/tt/Workspace/home-lab/monitoring/prometheus/values-homelab.yaml`

Update the `alertmanager.config` section:

```yaml
alertmanager:
  enabled: true

  alertmanagerSpec:
    # ... existing resource limits ...

  config:
    global:
      resolve_timeout: 5m

    # Routing configuration
    route:
      group_by: ['alertname', 'cluster', 'service']
      group_wait: 10s          # NFR5: Quick grouping for P1 alerts
      group_interval: 5m
      repeat_interval: 4h
      receiver: 'null'

      routes:
        # P1/Critical alerts to mobile
        - matchers:
            - severity = "critical"
          receiver: 'mobile-notifications'
          continue: false

        # Watchdog to null
        - matchers:
            - alertname = "Watchdog"
          receiver: 'null'

    receivers:
      - name: 'null'

      - name: 'mobile-notifications'
        webhook_configs:
          - url: 'https://ntfy.sh/${NTFY_TOPIC}'
            send_resolved: true
            http_config:
              follow_redirects: true
            max_alerts: 0
```

### Apply Configuration via Helm

```bash
# Upgrade the Helm release
helm upgrade kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -f /home/tt/Workspace/home-lab/monitoring/prometheus/values-homelab.yaml \
  -n monitoring

# Verify Alertmanager pod reloads
kubectl get pods -n monitoring -l app.kubernetes.io/name=alertmanager

# Check for configuration errors
kubectl logs -n monitoring alertmanager-kube-prometheus-stack-alertmanager-0 -c alertmanager --tail=50
```

---

## Step 4: Verify Configuration

### Check Alertmanager Configuration Secret

```bash
# View applied configuration
kubectl get secret alertmanager-kube-prometheus-stack-alertmanager -n monitoring \
  -o jsonpath='{.data.alertmanager\.yaml}' | base64 -d

# Verify mobile-notifications receiver exists
kubectl get secret alertmanager-kube-prometheus-stack-alertmanager -n monitoring \
  -o jsonpath='{.data.alertmanager\.yaml}' | base64 -d | grep -A 5 "mobile-notifications"
```

### Check Routing Rules

```bash
# Verify P1 routing
kubectl get secret alertmanager-kube-prometheus-stack-alertmanager -n monitoring \
  -o jsonpath='{.data.alertmanager\.yaml}' | base64 -d | grep -A 10 "routes:"
```

### Access Alertmanager UI

1. Open browser: https://alertmanager.home.jetzinger.com
2. Navigate to **Status > Config**
3. Verify `mobile-notifications` receiver is configured
4. Navigate to **Status > Routing Tree**
5. Verify P1 alerts route to `mobile-notifications`

---

## Step 5: Test End-to-End

### Trigger Test Alert

```bash
# Record start time
date '+%Y-%m-%d %H:%M:%S'

# Scale down a deployment to trigger alert
kubectl scale deployment kube-prometheus-stack-kube-state-metrics \
  -n monitoring --replicas=0

# Wait 60 seconds for alert evaluation
sleep 60

# Check mobile device for notification
# Expected: Notification received with alert details
```

### Verify Notification Content

Notification should include:
- ✅ Alert name (e.g., "KubeStateMetricsDown")
- ✅ Severity (critical)
- ✅ Cluster context (namespace, deployment)
- ✅ Description and impact
- ✅ Runbook URL (if configured)

### Test Alert Resolution

```bash
# Restore service
kubectl scale deployment kube-prometheus-stack-kube-state-metrics \
  -n monitoring --replicas=1

# Wait 90 seconds for resolution
sleep 90

# Check mobile device for resolution notification
# Expected: "resolved" notification received
```

### Verify via ntfy API

```bash
# Check ntfy topic for messages (last 10)
curl -s "https://ntfy.sh/${NTFY_TOPIC}/json?poll=1"

# Check for specific alert
curl -s "https://ntfy.sh/${NTFY_TOPIC}/json?poll=1" | grep "KubeStateMetricsDown"
```

---

## Step 6: Measure Latency (NFR5 Compliance)

**Requirement:** P1 alerts must be delivered within 1 minute

### Latency Breakdown

1. **Alert Evaluation**: ~30 seconds (Prometheus evaluationInterval)
2. **Alertmanager Grouping**: 10 seconds (group_wait)
3. **Webhook Delivery**: <5 seconds (ntfy.sh)
4. **Total**: ~45 seconds ✓ (within 1-minute requirement)

### Measurement Procedure

```bash
# T1: Trigger alert
date '+%Y-%m-%d %H:%M:%S' && kubectl scale deployment <target> -n <namespace> --replicas=0

# T2: Wait and check phone
sleep 60

# T3: Calculate latency
# Latency = (Time notification received on phone) - T1
# Expected: <60 seconds
```

---

## Troubleshooting

### No Notifications Received

1. **Check Alertmanager logs:**
   ```bash
   kubectl logs -n monitoring alertmanager-kube-prometheus-stack-alertmanager-0 -c alertmanager | grep -i "webhook\|error"
   ```

2. **Verify receiver configuration:**
   ```bash
   kubectl get secret alertmanager-kube-prometheus-stack-alertmanager -n monitoring \
     -o jsonpath='{.data.alertmanager\.yaml}' | base64 -d | grep -A 10 "mobile-notifications"
   ```

3. **Check routing:**
   ```bash
   # Verify severity=critical routes to mobile-notifications
   kubectl get secret alertmanager-kube-prometheus-stack-alertmanager -n monitoring \
     -o jsonpath='{.data.alertmanager\.yaml}' | base64 -d | grep -B 5 -A 5 "severity = \"critical\""
   ```

4. **Test webhook manually:**
   ```bash
   curl -d "Test message from home-lab" https://ntfy.sh/${NTFY_TOPIC}
   # Check phone for test message
   ```

### Alerts Not Firing

1. **Check Prometheus targets:**
   - Open: https://prometheus.home.jetzinger.com/targets
   - Verify all targets are UP

2. **Check PrometheusRules:**
   ```bash
   kubectl get prometheusrules -n monitoring
   ```

3. **Check alert state in Prometheus:**
   - Open: https://prometheus.home.jetzinger.com/alerts
   - Verify alert exists and is in correct state

### Configuration Not Reloading

1. **Force Alertmanager restart:**
   ```bash
   kubectl delete pod alertmanager-kube-prometheus-stack-alertmanager-0 -n monitoring
   kubectl get pods -n monitoring -w
   ```

2. **Check configuration syntax:**
   ```bash
   kubectl logs -n monitoring alertmanager-kube-prometheus-stack-alertmanager-0 -c alertmanager | grep -i "error\|failed"
   ```

---

## Configuration Reference

### Current Setup

| Component | Value |
|-----------|-------|
| Service | ntfy.sh (public) |
| Topic | ${NTFY_TOPIC} |
| Webhook URL | https://ntfy.sh/${NTFY_TOPIC} |
| Receiver Name | mobile-notifications |
| Routing Matcher | severity = "critical" |
| Group Wait | 10s |
| Group Interval | 5m |
| Repeat Interval | 4h |
| Send Resolved | true |

### Alert Severity Mapping

| Priority | Severity Label | Destination |
|----------|---------------|-------------|
| P1 | critical | mobile-notifications |
| P2 | warning | null (no notification) |
| P3 | info | null (no notification) |
| Watchdog | N/A | null (always firing test) |

---

## Related Documentation

- [Story 4.4 - Configure Alertmanager with Alert Rules](../implementation-artifacts/4-4-configure-alertmanager-with-alert-rules.md)
- [Story 4.5 - Setup Mobile Notifications](../implementation-artifacts/4-5-setup-mobile-notifications-for-p1-alerts.md)
- [Prometheus Alertmanager Documentation](https://prometheus.io/docs/alerting/latest/configuration/)
- [ntfy Documentation](https://docs.ntfy.sh/)
- [kube-prometheus-stack Chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)

---

## Change Log

- 2026-01-06: Initial runbook creation - ntfy.sh mobile notifications configured
