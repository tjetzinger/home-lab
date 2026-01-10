# Nginx Reverse Proxy

**Namespace:** `dev`
**Story:** 7.1 - Deploy Nginx Reverse Proxy
**Epic:** 7 - Development Proxy

## Overview

Nginx reverse proxy for accessing local development servers (e.g., frontend dev servers running on workstations) through the cluster ingress. This deployment uses ConfigMap-based configuration to enable hot-reload capability in future stories.

**Purpose:**
- Reverse proxy to local development servers
- Route traffic from cluster ingress to dev workstations
- ConfigMap-based configuration for flexibility

**Architecture:**
```
Internet → NextDNS (dev.home.jetzinger.com → 192.168.2.100)
       → MetalLB (192.168.2.100:443)
       → Traefik (HTTPS entrypoint)
       → IngressRoute (dev-proxy-ingress)
       → nginx-proxy Service (ClusterIP)
       → nginx-proxy Pod
       → Backend Dev Servers (192.168.2.x:port)
                ↓
          ConfigMap (nginx.conf)
```

## Components

| Component | Name | Type | Purpose |
|-----------|------|------|---------|
| ConfigMap | `nginx-proxy-config` | ConfigMap | nginx.conf with upstream definitions |
| Deployment | `nginx-proxy` | Deployment | Nginx reverse proxy (1 replica) |
| Service | `nginx-proxy` | ClusterIP | Internal cluster access (port 80) |
| Certificate | `dev-proxy-tls` | Certificate | TLS certificate for dev.home.jetzinger.com |
| IngressRoute | `dev-proxy-ingress` | IngressRoute | HTTPS ingress route |
| IngressRoute | `dev-proxy-ingress-redirect` | IngressRoute | HTTP to HTTPS redirect |

**Image:** `nginx:1.27-alpine`
**Resources:**
- Requests: 50m CPU, 64Mi memory
- Limits: 100m CPU, 128Mi memory

## Deployment

### Prerequisites

- K3s cluster with control plane and worker nodes (Stories 1.1-1.4)
- Dev namespace exists (created in Story 3.5)
- Traefik ingress controller (Story 3.2)
- cert-manager for TLS (Story 3.3)

### Deploy Nginx Proxy

1. **Apply ConfigMap:**
   ```bash
   kubectl apply -f applications/nginx/configmap.yaml
   ```

2. **Apply Deployment:**
   ```bash
   kubectl apply -f applications/nginx/deployment.yaml
   ```

3. **Apply Service:**
   ```bash
   kubectl apply -f applications/nginx/service.yaml
   ```

4. **Verify deployment:**
   ```bash
   kubectl get pods -n dev -l app.kubernetes.io/instance=nginx-proxy
   kubectl get svc -n dev nginx-proxy
   kubectl get configmap -n dev nginx-proxy-config
   ```

## Verification

### Pod Status

```bash
kubectl get pods -n dev -l app.kubernetes.io/instance=nginx-proxy
```

**Expected output:**
```
NAME                           READY   STATUS    RESTARTS   AGE
nginx-proxy-7775b75c68-wwklt   1/1     Running   0          5m
```

### Configuration Validation

```bash
# Verify nginx.conf is loaded from ConfigMap
POD=$(kubectl get pod -n dev -l app.kubernetes.io/instance=nginx-proxy -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n dev $POD -- cat /etc/nginx/nginx.conf | head -20

# Check nginx syntax
kubectl exec -n dev $POD -- nginx -t
```

**Expected output:**
```
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

### Service Accessibility

```bash
# Test health endpoint from another pod
kubectl exec -n dev deployment/hello-nginx -- curl -s http://nginx-proxy.dev.svc.cluster.local/health
```

**Expected output:**
```
healthy
```

### Service Details

```bash
kubectl get svc -n dev nginx-proxy -o wide
```

**Expected output:**
```
NAME          TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)   AGE     SELECTOR
nginx-proxy   ClusterIP   10.43.16.27   <none>        80/TCP    10m     app.kubernetes.io/instance=nginx-proxy,app.kubernetes.io/name=nginx
```

## Configuration

The nginx configuration is stored in ConfigMap `nginx-proxy-config` and mounted at `/etc/nginx/nginx.conf`.

**Current Configuration:**
- **Upstreams:**
  - `app1` → 192.168.2.50:3000
  - `app2` → 192.168.2.51:8080
- **Server:** Listens on port 80
- **Location Blocks:**
  - `/` - Default nginx welcome page
  - `/app1` - Proxies to app1 upstream
  - `/app2` - Proxies to app2 upstream
  - `/health` - Health check endpoint
- **Proxy Headers:** Host, X-Real-IP, X-Forwarded-For, X-Forwarded-Proto

**Configuration Management:**
- Configuration is declarative via ConfigMap
- Hot-reload enabled - config changes automatically detected and applied (Story 7.3)
- No pod restart required for configuration updates
- ConfigMap changes propagate and reload within 30 seconds

## Hot-Reload Configuration

**Story:** 7.3 - Enable Hot-Reload Configuration
**Feature:** FR43 - Add/remove proxy targets without cluster restart

### How It Works

The nginx deployment uses automatic configuration hot-reload with zero downtime:

1. **ConfigMap Update**: Edit and apply `configmap.yaml`
2. **Kubernetes Propagation**: ConfigMap changes sync to pod (10-60 seconds)
3. **Change Detection**: Config watcher detects file timestamp change (10-second polling)
4. **Validation**: Watcher validates syntax with `nginx -t`
5. **Graceful Reload**: Nginx receives SIGHUP signal:
   - Master process spawns new workers with updated config
   - Old workers finish current requests gracefully
   - New workers handle new requests
   - Zero dropped connections

**Timeline:** ~30 seconds total from `kubectl apply` to reload complete

### Architecture Details

**ConfigMap Mount:**
- ConfigMap mounted at `/etc/nginx/custom/` (without `subPath` for auto-propagation)
- Nginx started with `-c /etc/nginx/custom/nginx.conf`
- Kubernetes uses symlink chain: `nginx.conf` → `..data` → `..TIMESTAMP/nginx.conf`

**Config Watcher:**
- Background process (`config-watcher.sh`) monitors config file
- Polling interval: 10 seconds (well within 30-second AC requirement)
- Uses `stat -L` to follow Kubernetes symlink chain
- Automatic syntax validation before reload
- Detailed logging of all reload events

### Verification Commands

**Check watcher status:**
```bash
POD=$(kubectl get pod -n dev -l app.kubernetes.io/instance=nginx-proxy -o jsonpath='{.items[0].metadata.name}')
kubectl logs -n dev $POD | grep config-watcher
```

**Verify automatic reload happened:**
```bash
# Check for reload events
kubectl logs -n dev $POD | grep "Reload signal sent"

# Expected output:
# [config-watcher] ✓ Reload signal sent successfully at 2026-01-06 21:49:22
```

**Confirm worker process reload:**
```bash
# View worker process changes
kubectl logs -n dev $POD | grep "start worker process"

# You'll see old PIDs replaced with new PIDs during reload
```

**Validate pod NOT restarted:**
```bash
kubectl get pod -n dev $POD -o jsonpath='{.status.containerStatuses[0].restartCount}'

# Expected output: 0
```

### Manual Reload Script

For immediate reload without waiting for automatic detection, use the provided script:

```bash
./applications/nginx/reload-proxy.sh
```

**Script Features:**
- Pre-flight configuration validation
- ConfigMap apply with propagation wait (30s timeout)
- Syntax validation before reload
- Graceful nginx reload
- Health endpoint verification
- Detailed progress logging

**Example Output:**
```
=========================================
Nginx Proxy Configuration Reload
=========================================

Step 1: Getting nginx pod...
  Pod: nginx-proxy-6f7c98bbf6-gkk8j

Step 2: Pre-flight validation...
Validating nginx configuration syntax... OK

Step 3: Capturing current configuration timestamp...
  Current timestamp: 1767736154

Step 4: Applying ConfigMap update...
  ConfigMap applied successfully

Step 5: Waiting for ConfigMap propagation...
  ConfigMap propagated after 15 seconds

Step 6: Validating new configuration...
Validating nginx configuration syntax... OK

Step 7: Triggering nginx graceful reload...
  Reload signal sent successfully
  Timestamp: 2026-01-06 21:54:27

Step 8: Validating nginx health...
  Health check passed

Step 9: Verifying worker processes...
  Active worker processes: 4
  Workers active and serving requests

=========================================
✓ Reload completed successfully
=========================================
```

### Limitations and Edge Cases

**ConfigMap Propagation Timing:**
- Kubernetes ConfigMap propagation is eventually consistent
- Typical propagation time: 10-60 seconds
- Controlled by kubelet sync period (default: 1 minute)
- Automatic watcher handles timing variations

**Syntax Errors:**
- Invalid config prevents reload (pod keeps running with old config)
- Watcher logs syntax errors and skips reload
- Fix syntax and reapply - watcher will retry on next change

**Pod Restart:**
- Deployment changes (image, resources, etc.) still require pod restart
- Only ConfigMap changes use hot-reload
- Pod restart count remains 0 for config-only updates

**Multiple Rapid Changes:**
- Watcher includes 5-second stabilization wait
- Prevents reload during mid-write
- Safe for rapid successive ConfigMap updates

## Access

**Internal Cluster Access:**
- DNS: `nginx-proxy.dev.svc.cluster.local`
- ClusterIP: `10.43.16.27` (assigned by Kubernetes)
- Port: 80 (HTTP)

**External Access:**
- **URL:** https://dev.home.jetzinger.com
- **Domain:** `dev.home.jetzinger.com` (via NextDNS rewrite)
- **TLS Certificate:** Let's Encrypt Production (auto-provisioned by cert-manager)
- **Certificate Expiry:** 90 days (auto-renewal 30 days before expiry)
- **Access Methods:**
  - Home Network: Direct access via MetalLB IP (192.168.2.100)
  - Remote: Via Tailscale VPN
- **HTTP Redirect:** All HTTP requests automatically redirect to HTTPS

## Operations

### View Logs

```bash
POD=$(kubectl get pod -n dev -l app.kubernetes.io/instance=nginx-proxy -o jsonpath='{.items[0].metadata.name}')
kubectl logs -n dev $POD -f
```

### Update Configuration

#### Option 1: Automatic Hot-Reload (Recommended)

1. Edit and apply ConfigMap:
   ```bash
   # Edit configmap.yaml file
   kubectl apply -f applications/nginx/configmap.yaml
   ```

2. Configuration automatically reloads within 30 seconds:
   - ConfigMap propagates to pod (~10-60 seconds)
   - Config watcher detects change (~10 seconds)
   - Nginx gracefully reloads (zero downtime)
   - No pod restart required

3. Monitor reload:
   ```bash
   POD=$(kubectl get pod -n dev -l app.kubernetes.io/instance=nginx-proxy -o jsonpath='{.items[0].metadata.name}')
   kubectl logs -n dev $POD -f | grep "config-watcher"
   ```

#### Option 2: Manual Reload Script

For immediate reload without waiting for automatic detection:

```bash
# Run the reload script
./applications/nginx/reload-proxy.sh
```

The script performs:
- ConfigMap validation
- Apply and propagation wait
- Syntax validation
- Graceful nginx reload
- Health verification

### Scale Deployment

```bash
kubectl scale deployment/nginx-proxy -n dev --replicas=2
```

**Note:** Current configuration uses 1 replica (no HA required for dev proxy).

### Health Check

```bash
# Quick health check
kubectl exec -n dev deployment/nginx-proxy -- curl -s http://localhost/health

# Detailed status
kubectl describe pod -n dev -l app.kubernetes.io/instance=nginx-proxy
```

## Troubleshooting

### Pod Not Starting

```bash
# Check pod events
kubectl describe pod -n dev -l app.kubernetes.io/instance=nginx-proxy

# Check logs
kubectl logs -n dev -l app.kubernetes.io/instance=nginx-proxy
```

**Common issues:**
- ConfigMap not found: Verify `nginx-proxy-config` exists in `dev` namespace
- Syntax error in nginx.conf: Check ConfigMap content, test with `nginx -t`

### Service Not Accessible

```bash
# Verify service endpoints
kubectl get endpoints -n dev nginx-proxy

# Test from another pod
kubectl exec -n dev deployment/hello-nginx -- curl -v http://nginx-proxy.dev.svc.cluster.local/health
```

**Common issues:**
- No endpoints: Pod selector mismatch, verify labels
- Connection refused: Check pod readiness probe, verify nginx is listening on port 80

### Configuration Not Loaded

```bash
# Verify ConfigMap mount
kubectl exec -n dev $POD -- ls -la /etc/nginx/

# Check mounted config
kubectl exec -n dev $POD -- cat /etc/nginx/nginx.conf
```

**Common issues:**
- Empty file: Check ConfigMap `data.nginx.conf` key exists
- Old config: Verify ConfigMap was applied and propagated (see hot-reload troubleshooting below)

### Hot-Reload Not Working

**Symptom:** ConfigMap updated but nginx still using old configuration

**Diagnosis:**
```bash
POD=$(kubectl get pod -n dev -l app.kubernetes.io/instance=nginx-proxy -o jsonpath='{.items[0].metadata.name}')

# 1. Check watcher process is running
kubectl exec -n dev $POD -- ps aux | grep config-watcher

# 2. Check watcher logs for errors
kubectl logs -n dev $POD | grep config-watcher | tail -20

# 3. Check ConfigMap timestamp in pod
kubectl exec -n dev $POD -- stat -L -c '%Y - %y' /etc/nginx/custom/nginx.conf

# 4. Compare to ConfigMap in Kubernetes
kubectl get configmap nginx-proxy-config -n dev -o yaml | head -30
```

**Common issues:**

1. **ConfigMap not propagated yet:**
   - Kubernetes takes 10-60 seconds to sync ConfigMap changes
   - Check timestamp with `stat -L` command above
   - Wait up to 60 seconds, then check watcher logs

2. **Watcher process not running:**
   - Check deployment logs for watcher startup errors
   - Verify `nginx-config-watcher` ConfigMap exists
   - Restart pod if watcher failed to start

3. **Syntax error in new config:**
   ```bash
   # Watcher logs will show syntax validation failure
   kubectl logs -n dev $POD | grep "syntax invalid"

   # Check syntax manually
   kubectl exec -n dev $POD -- nginx -t
   ```
   - Fix syntax error in ConfigMap
   - Reapply ConfigMap - watcher will retry

4. **ConfigMap mount issue:**
   ```bash
   # Verify mount structure
   kubectl exec -n dev $POD -- ls -la /etc/nginx/custom/

   # Should show symlink chain:
   # nginx.conf -> ..data/nginx.conf
   # ..data -> ..TIMESTAMP/
   ```

**Resolution:**
- For immediate fix: Use manual reload script (`reload-proxy.sh`)
- For persistent issues: Check deployment configuration and watcher logs

## Adding New Proxy Targets

To add a new dev server to the proxy with automatic hot-reload:

1. **Edit ConfigMap** (`applications/nginx/configmap.yaml`):
   ```nginx
   # Add upstream definition
   upstream app3 {
       server 192.168.2.52:9000;
   }

   # Add location block
   location /app3 {
       proxy_pass http://app3;
       proxy_set_header Host $host;
       proxy_set_header X-Real-IP $remote_addr;
       proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
       proxy_set_header X-Forwarded-Proto $scheme;
   }
   ```

2. **Apply changes** (automatic reload, no pod restart):
   ```bash
   kubectl apply -f applications/nginx/configmap.yaml
   ```

3. **Wait for automatic reload** (~30 seconds):
   ```bash
   # Watch reload logs
   POD=$(kubectl get pod -n dev -l app.kubernetes.io/instance=nginx-proxy -o jsonpath='{.items[0].metadata.name}')
   kubectl logs -n dev $POD -f | grep "Reload signal sent"
   ```

4. **Test new route:**
   ```bash
   curl https://dev.home.jetzinger.com/app3
   ```

**Alternative - Manual Immediate Reload:**
```bash
# For immediate reload without waiting
./applications/nginx/reload-proxy.sh
```

## Implementation Status

### Completed Stories
- ✅ **Story 7.1:** Deploy Nginx Reverse Proxy - Initial deployment with ConfigMap-based config
- ✅ **Story 7.2:** Configure Ingress for Dev Proxy Access - HTTPS ingress with TLS
- ✅ **Story 7.3:** Enable Hot-Reload Configuration - Automatic config reload without pod restart
- ✅ **Story 11.4:** Configure Nginx SSH Proxy with Custom Domains - TCP stream proxy for SSH access

### Technical Achievements
- Zero-downtime configuration updates
- FR43 compliance: Add/remove proxy targets without cluster restart
- NFR1 compliance: No pod restart for config-only changes (maintains 95% uptime)
- Automatic detection and reload within 30 seconds
- Manual reload script for immediate updates

## SSH Proxy for Dev Containers

**Story:** 11.4 - Configure Nginx SSH Proxy with Custom Domains
**Feature:** FR59 - Nginx proxy routes to dev containers, FR61 - Connect VS Code via Nginx proxy

### Overview

Nginx provides TCP stream proxying for SSH access to dev containers. This enables VS Code Remote SSH to connect to dev containers running in the cluster.

### SSH Access

| Container | Port | LoadBalancer IP |
|-----------|------|-----------------|
| Belego    | 2222 | 192.168.2.101   |
| Pilates   | 2223 | 192.168.2.101   |

### Connection Commands

```bash
# SSH to Belego dev container
ssh -p 2222 dev@192.168.2.101

# SSH to Pilates dev container
ssh -p 2223 dev@192.168.2.101
```

### VS Code SSH Config

Add to `~/.ssh/config`:

```
Host dev-belego
    HostName 192.168.2.101
    Port 2222
    User dev

Host dev-pilates
    HostName 192.168.2.101
    Port 2223
    User dev
```

Then connect via VS Code Remote-SSH extension using `dev-belego` or `dev-pilates`.

### Components

| Component | Name | Purpose |
|-----------|------|---------|
| ConfigMap | `nginx-proxy-config` | Stream module config with TCP upstreams |
| Service | `nginx-proxy` | ClusterIP with ports 80, 2222, 2223 |
| Service | `nginx-proxy-ssh` | LoadBalancer for external SSH (192.168.2.101) |
| IngressRoute | `dev-belego-ingress` | HTTPS for dev.belego.app |
| IngressRoute | `dev-pilates-ingress` | HTTPS for Pilates domains |

### HTTP Access via Custom Domains

| Domain | Purpose |
|--------|---------|
| dev.belego.app | Belego HTTP development |
| dev.pilates4.golf | Pilates HTTP development |
| dev.app.pilates4.golf | Pilates app subdomain |
| dev.admin.pilates4.golf | Pilates admin subdomain |
| dev.blog.pilates4.golf | Pilates blog subdomain |
| dev.join.pilates4.golf | Pilates join subdomain |
| dev.www.pilates4.golf | Pilates www subdomain |

### DNS Configuration (NextDNS)

Custom domains are resolved via NextDNS rewrites:
- `*.belego.app` → 192.168.2.100 (Traefik for HTTP)
- `*.pilates4.golf` → 192.168.2.100 (Traefik for HTTP)

SSH uses separate LoadBalancer IP: 192.168.2.101

## References

- **Story 7.1:** Deploy Nginx Reverse Proxy
- **Story 7.2:** Configure Ingress for Dev Proxy Access
- **Story 7.3:** Enable Hot-Reload Configuration (completed)
- **Story 11.4:** Configure Nginx SSH Proxy with Custom Domains
- **Epic 7:** Development Proxy
- **Epic 11:** Dev Containers Platform
- **Story 3.5:** Create First HTTPS Ingress Route (test deployment pattern)
- **FR43:** Add/remove proxy targets without cluster restart
- **FR59:** Nginx proxy routes to dev containers
- **FR61:** Connect VS Code via Nginx proxy
- **NFR1:** 95% uptime requirement

## Test Deployment

The `applications/nginx/` directory also contains test files from Story 3.5:
- `test-deployment.yaml` - Test nginx deployment (`hello-nginx`)
- `test-ingress.yaml` - HTTPS ingress route for hello.home.jetzinger.com

These files are kept for reference and testing purposes.
