# K3s Service Load Balancer (svclb) Recovery Runbook

**Related Alerts:**
- `K3sSvclbTraefikDown` (P0)
- `K3sSvclbPodsDown` (P1)
- `K3sSvclbDaemonSetMissing` (P1)

**Related ADRs:**
- ADR-008: Fix K3s Prometheus Alerts
- ADR-009: K3s Service Load Balancer Monitoring

## Overview

K3s uses a built-in service load balancer called **svclb** (Service Load Balancer, implemented via klipper-lb) instead of kube-proxy. The svclb creates DaemonSet pods on each node for LoadBalancer-type services to route external traffic.

**Critical Service:** `svclb-traefik` - Routes all HTTPS ingress traffic

## Quick Diagnosis

### Check svclb Pod Status

```bash
# List all svclb pods
kubectl get pods -n kube-system | grep svclb

# Expected output (healthy):
svclb-traefik-5b1f5b3f-qnr7n    2/2     Running     0    40h
svclb-traefik-5b1f5b3f-qz92t    2/2     Running     0    41h
svclb-traefik-5b1f5b3f-vn5jv    2/2     Running     0    39h
```

### Check DaemonSet Status

```bash
# Check svclb DaemonSets
kubectl get daemonset -n kube-system | grep svclb

# Expected output:
NAME                       DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE
svclb-traefik-5b1f5b3f     3         3         3       3            3
```

### Check LoadBalancer Services

```bash
# List LoadBalancer services
kubectl get svc --all-namespaces | grep LoadBalancer

# Expected output:
infra    traefik   LoadBalancer   10.43.142.59   192.168.2.100   80:30652/TCP,443:31754/TCP   41h
```

## Alert 1: K3sSvclbTraefikDown (P0 - Critical)

**Symptom:** Traefik svclb pods not running on all nodes

**Impact:** All HTTPS ingress broken - Grafana, n8n, dev proxy unreachable

### Diagnosis Steps

```bash
# 1. Check Traefik svclb pod status
kubectl get pods -n kube-system -l svccontroller.k3s.cattle.io/svcname=traefik

# 2. Check pod events
kubectl get events -n kube-system --sort-by='.lastTimestamp' | grep svclb-traefik | tail -20

# 3. Check pod logs (if pods exist)
POD=$(kubectl get pod -n kube-system -l svccontroller.k3s.cattle.io/svcname=traefik -o jsonpath='{.items[0].metadata.name}')
kubectl logs -n kube-system $POD

# 4. Check DaemonSet status
kubectl describe daemonset -n kube-system -l svccontroller.k3s.cattle.io/svcname=traefik

# 5. Check Traefik LoadBalancer service
kubectl get svc -n infra traefik
```

### Common Causes & Fixes

#### Cause 1: Node Not Ready

**Symptoms:**
- DaemonSet shows fewer ready pods than nodes
- Specific node missing svclb pod

**Fix:**
```bash
# Check node status
kubectl get nodes

# If node NotReady, check node:
ssh <node-ip>
sudo systemctl status k3s-agent  # On worker nodes
sudo systemctl status k3s         # On control plane

# Restart K3s if needed
sudo systemctl restart k3s-agent
```

#### Cause 2: Image Pull Failure

**Symptoms:**
- Pods in ImagePullBackOff or ErrImagePull state

**Fix:**
```bash
# Check pod status
kubectl describe pod -n kube-system <svclb-pod-name>

# K3s uses rancher/klipper-lb image
# Pull manually on node if needed:
ssh <node-ip>
sudo ctr -n k8s.io images pull rancher/klipper-lb:v0.4.4
```

#### Cause 3: Resource Constraints

**Symptoms:**
- Pods in Pending state
- Events show insufficient CPU/memory

**Fix:**
```bash
# Check node resources
kubectl top nodes

# Check pod resource requests
kubectl get pod -n kube-system <svclb-pod-name> -o yaml | grep -A 5 resources

# Scale down non-critical workloads if needed
```

#### Cause 4: DaemonSet Deleted

**Symptoms:**
- No svclb DaemonSet exists
- No svclb pods running

**Fix:**
```bash
# K3s auto-creates svclb DaemonSets for LoadBalancer services
# Delete and recreate the service to trigger recreation:

# 1. Get service configuration
kubectl get svc -n infra traefik -o yaml > /tmp/traefik-svc-backup.yaml

# 2. Delete service (will delete svclb DaemonSet)
kubectl delete svc -n infra traefik

# 3. Wait 5 seconds
sleep 5

# 4. Recreate service (K3s will auto-create svclb)
kubectl apply -f /tmp/traefik-svc-backup.yaml

# 5. Verify svclb DaemonSet created
kubectl get daemonset -n kube-system | grep svclb-traefik
```

### Recovery Verification

```bash
# 1. Verify all svclb pods running
kubectl get pods -n kube-system -l svccontroller.k3s.cattle.io/svcname=traefik

# 2. Verify DaemonSet healthy
kubectl get daemonset -n kube-system | grep svclb-traefik

# 3. Test ingress access
curl -k https://grafana.home.jetzinger.com
curl -k https://n8n.home.jetzinger.com
curl -k https://dev.home.jetzinger.com/health

# 4. Check MetalLB assigned IP
kubectl get svc -n infra traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
# Expected: 192.168.2.100
```

## Alert 2: K3sSvclbPodsDown (P1 - Critical)

**Symptom:** svclb pods for any LoadBalancer service not running on all nodes

**Impact:** Specific LoadBalancer services unavailable

### Diagnosis Steps

```bash
# 1. List all svclb DaemonSets
kubectl get daemonset -n kube-system | grep svclb

# 2. Check which DaemonSet has issues
kubectl get daemonset -n kube-system -o wide | grep svclb

# 3. Check pods for problematic DaemonSet
DAEMONSET=<daemonset-name>
kubectl get pods -n kube-system -l app.kubernetes.io/name=$DAEMONSET

# 4. Check events
kubectl get events -n kube-system --sort-by='.lastTimestamp' | grep $DAEMONSET
```

### Recovery

Follow same steps as K3sSvclbTraefikDown, but for the specific service:

```bash
# Identify the LoadBalancer service
SERVICE_NAME=$(echo $DAEMONSET | sed 's/svclb-//' | sed 's/-[^-]*$//')

# Check the service
kubectl get svc --all-namespaces | grep $SERVICE_NAME
```

## Alert 3: K3sSvclbDaemonSetMissing (P1 - Critical)

**Symptom:** LoadBalancer service exists but no svclb DaemonSet

**Impact:** LoadBalancer service not functioning

### Diagnosis Steps

```bash
# 1. List LoadBalancer services
kubectl get svc --all-namespaces -o wide | grep LoadBalancer

# 2. List svclb DaemonSets
kubectl get daemonset -n kube-system | grep svclb

# 3. Check K3s servicelb status
ssh <control-plane-node>
sudo systemctl status k3s | grep servicelb
```

### Common Causes & Fixes

#### Cause 1: K3s ServiceLB Disabled

**Fix:**
```bash
# Check K3s config
ssh <control-plane-node>
cat /etc/systemd/system/k3s.service

# If servicelb disabled (--disable servicelb), re-enable:
sudo systemctl edit k3s.service
# Remove --disable servicelb flag

sudo systemctl daemon-reload
sudo systemctl restart k3s
```

#### Cause 2: DaemonSet Manually Deleted

**Fix:**
```bash
# Delete and recreate LoadBalancer service to trigger svclb creation
NAMESPACE=<namespace>
SERVICE=<service-name>

# Backup
kubectl get svc -n $NAMESPACE $SERVICE -o yaml > /tmp/$SERVICE-backup.yaml

# Delete and recreate
kubectl delete svc -n $NAMESPACE $SERVICE
sleep 5
kubectl apply -f /tmp/$SERVICE-backup.yaml

# Verify svclb created
kubectl get daemonset -n kube-system | grep svclb-$SERVICE
```

## Prevention

### Monitoring

- ✅ Prometheus alerts configured (ADR-009)
- ✅ P0 alert for Traefik svclb (most critical)
- ✅ P1 alert for general svclb failures

### Best Practices

1. **Never manually delete svclb DaemonSets**
   - Managed by K3s servicelb controller
   - Auto-recreated when LoadBalancer service exists

2. **Test ingress after node operations**
   - After node restart, verify svclb pods running
   - After K3s upgrade, check svclb DaemonSets

3. **Monitor LoadBalancer IP assignments**
   - MetalLB assigns IPs to LoadBalancer services
   - svclb routes traffic to assigned IPs

4. **Preserve LoadBalancer service configuration**
   - Backup before modifications
   - Avoid changing service type from LoadBalancer

## Related Documentation

- [K3s Service Load Balancer Documentation](https://docs.k3s.io/networking#service-load-balancer)
- [K3s klipper-lb GitHub](https://github.com/k3s-io/klipper-lb)
- ADR-008: Fix K3s Prometheus Alerts
- ADR-009: K3s Service Load Balancer Monitoring

## Escalation

If issue persists after following this runbook:

1. Check K3s logs on all nodes:
   ```bash
   ssh <node>
   sudo journalctl -u k3s -f
   ```

2. Check for K3s known issues:
   - [K3s GitHub Issues](https://github.com/k3s-io/k3s/issues)
   - Search for "servicelb" or "klipper-lb"

3. Consider K3s restart on affected node (last resort):
   ```bash
   ssh <node>
   sudo systemctl restart k3s-agent  # or k3s for control plane
   ```

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2026-01-07 | Initial runbook created | Claude Code |
| 2026-01-07 | Added K3s svclb alerts | ADR-009 |
