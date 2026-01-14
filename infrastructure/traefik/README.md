# Traefik - Cloud-Native Ingress Controller

**Story:** 3.2 - Configure Traefik Ingress Controller
**Epic:** 3 - Ingress, TLS & Service Exposure
**Namespace:** `kube-system` (bundled with K3s)

## What It Does

Traefik is a modern HTTP reverse proxy and load balancer that routes external traffic to Kubernetes services. It automatically discovers services, handles TLS termination, and provides dynamic configuration through Kubernetes resources.

## Why It Was Chosen

**Decision Rationale (ADR-003):**
- **Bundled with K3s:** Pre-installed, reducing operational complexity
- **IngressRoute CRDs:** More powerful than standard Ingress resources (middleware, TCP/UDP routes)
- **Automatic Let's Encrypt:** Seamless integration with cert-manager
- **Dynamic configuration:** No config reloads required when services change
- **Lightweight:** Efficient resource usage suitable for home lab constraints

**Alternatives Considered:**
- **Nginx Ingress** → Rejected (more complex configuration, not K3s default)
- **HAProxy Ingress** → Rejected (steeper learning curve, less Kubernetes-native)
- **Istio/Linkerd service mesh** → Rejected (overkill for home lab, high resource overhead)
- **Kong Gateway** → Rejected (enterprise features not needed, heavier resource footprint)

## Key Configuration Decisions

### K3s Integration

Traefik is deployed by K3s as a HelmChart resource:
- **Chart location:** `/var/lib/rancher/k3s/server/manifests/traefik.yaml`
- **Automatic updates:** K3s manages Traefik version updates
- **Customization:** Override values via `/var/lib/rancher/k3s/server/manifests/traefik-config.yaml`

**Key K3s Traefik Settings:**
```yaml
# K3s default Traefik configuration
servicetype: LoadBalancer  # Gets IP from MetalLB
metrics:
  prometheus: true  # Exposes metrics for Prometheus scraping
ports:
  web: 80
  websecure: 443
  metrics: 9100
```

### IngressRoute vs Ingress

Traefik supports both standard Ingress and its own IngressRoute CRD:

**IngressRoute (Preferred):**
```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: grafana
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`grafana.home.jetzinger.com`)
      kind: Rule
      services:
        - name: grafana
          port: 80
  tls:
    secretName: grafana-tls  # cert-manager managed
```

**Advantages:**
- Middleware support (authentication, rate limiting, headers)
- TCP/UDP routing capabilities
- More expressive routing rules
- Better error handling configuration

**Standard Ingress (Also Supported):**
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  rules:
    - host: example.home.jetzinger.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: example
                port:
                  number: 80
  tls:
    - secretName: example-tls
      hosts:
        - example.home.jetzinger.com
```

### TLS Configuration

**Automatic HTTPS Redirect:**
Traefik configured to redirect HTTP → HTTPS automatically for all routes.

**Certificate Management:**
- Certificates managed by cert-manager (Let's Encrypt)
- Traefik reads certificates from Kubernetes Secrets
- Automatic certificate rotation (cert-manager handles renewal)

**TLS Versions:**
- Minimum TLS version: TLS 1.2
- Supports TLS 1.3 for modern clients

### Entry Points

Traefik defines entry points for different traffic types:

| Entry Point | Port | Protocol | Purpose |
|-------------|------|----------|---------|
| `web` | 80 | HTTP | Redirects to HTTPS |
| `websecure` | 443 | HTTPS | Primary encrypted traffic |
| `metrics` | 9100 | HTTP | Prometheus metrics endpoint |

## How to Access/Use

### Creating an IngressRoute

**Step 1: Deploy your application service**
```bash
kubectl apply -f my-app-deployment.yaml
kubectl apply -f my-app-service.yaml
```

**Step 2: Create IngressRoute**
```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: my-app
  namespace: apps
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`my-app.home.jetzinger.com`)
      kind: Rule
      services:
        - name: my-app
          port: 8080
  tls:
    secretName: my-app-tls
```

**Step 3: DNS configuration**
- Add DNS rewrite in NextDNS: `my-app.home.jetzinger.com` → `192.168.2.100` (Traefik LoadBalancer IP)

**Step 4: Access your application**
```
https://my-app.home.jetzinger.com
```

### Using Middleware

Traefik middleware adds functionality like authentication, rate limiting, and header manipulation:

**Example: Basic Auth Middleware**
```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: basic-auth
  namespace: apps
spec:
  basicAuth:
    secret: auth-secret  # Contains username/password
---
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: protected-app
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`protected.home.jetzinger.com`)
      kind: Rule
      middlewares:
        - name: basic-auth  # Apply authentication
      services:
        - name: protected-app
          port: 80
  tls:
    secretName: protected-tls
```

### Check Traefik Status

View Traefik service and LoadBalancer IP:
```bash
kubectl get svc traefik -n kube-system
```

View Traefik pods:
```bash
kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik
```

Check Traefik logs:
```bash
kubectl logs -n kube-system deployment/traefik -f
```

### Traefik Dashboard (Optional)

Enable dashboard for debugging (not exposed externally by default):
```bash
kubectl port-forward -n kube-system deployment/traefik 9000:9000
```

Access: `http://localhost:9000/dashboard/`

## Deployment Details

**Installed By:** K3s (automatic HelmChart deployment)
**Chart:** `traefik/traefik` (managed by K3s)
**Namespace:** `kube-system`

**Components:**
- `traefik` deployment - Main ingress controller
- `traefik` service (LoadBalancer) - Receives external traffic via MetalLB

**CRDs:**
- `IngressRoute` - HTTP/HTTPS routing rules
- `IngressRouteTCP` - TCP routing rules
- `IngressRouteUDP` - UDP routing rules
- `Middleware` - Request/response transformations
- `TLSOption` - TLS configuration
- `TraefikService` - Advanced service definitions

## Integration Points

**MetalLB:**
- Traefik Service (type: LoadBalancer) assigned IP `192.168.2.100` by MetalLB
- All external HTTPS traffic enters cluster through this IP

**cert-manager:**
- Traefik reads TLS certificates from Secrets created by cert-manager
- Automatic certificate renewal and rotation

**Services Using Traefik Ingress:**
- **Grafana:** `https://grafana.home.jetzinger.com`
- **n8n:** `https://n8n.home.jetzinger.com`
- **Ollama:** `https://ollama.home.jetzinger.com`
- **Nginx Dev Proxy:** `https://proxy.home.jetzinger.com`

## Monitoring

**Prometheus Metrics:**
Traefik exposes metrics at `:9100/metrics`:
- `traefik_entrypoint_requests_total` - Total requests per entry point
- `traefik_entrypoint_request_duration_seconds` - Request latency
- `traefik_service_requests_total` - Requests per backend service
- `traefik_service_request_duration_seconds` - Backend service latency

**Grafana Dashboards:**
kube-prometheus-stack includes Traefik dashboards showing:
- Request rates and error rates
- Response times (p50, p95, p99)
- Backend service health
- Certificate expiration status

## Troubleshooting

**Service Not Accessible:**
```bash
# Check IngressRoute exists
kubectl get ingressroute -n <namespace>

# Describe IngressRoute for errors
kubectl describe ingressroute <name> -n <namespace>

# Check Traefik logs
kubectl logs -n kube-system deployment/traefik | grep <hostname>
```

**Certificate Issues:**
```bash
# Verify cert-manager issued certificate
kubectl get certificate -n <namespace>

# Check Secret exists
kubectl get secret <tls-secret-name> -n <namespace>

# Traefik logs will show TLS errors
kubectl logs -n kube-system deployment/traefik | grep -i tls
```

**503 Service Unavailable:**
- Backend service not running: `kubectl get pods -n <namespace>`
- Service selector mismatch: `kubectl describe svc <service-name>`
- Pod not ready: `kubectl describe pod <pod-name>`

## Security Considerations

**TLS Enforcement:**
- All HTTP traffic automatically redirected to HTTPS
- Modern TLS configuration (TLS 1.2+ only)
- Strong cipher suites configured

**Network Exposure:**
- Traefik only accessible via Tailscale VPN (no public internet exposure)
- LoadBalancer IP (192.168.2.100) only routable on private subnet

**Middleware for Security:**
- Consider rate limiting middleware to prevent abuse
- Use authentication middleware for sensitive services
- Add security headers middleware (HSTS, X-Frame-Options)

## Performance Tuning

**Resource Limits:**
```yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

**Connection Pooling:**
Traefik maintains connection pools to backend services for efficiency.

**HTTP/2 Support:**
Enabled by default for clients supporting HTTP/2.

## References

- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [K3s Traefik Configuration](https://docs.k3s.io/networking#traefik-ingress-controller)
- [IngressRoute Reference](https://doc.traefik.io/traefik/routing/providers/kubernetes-crd/)
- [Story 3.2 Implementation](../../docs/implementation-artifacts/3-2-configure-traefik-ingress-controller.md)
- [ADR-003: Traefik Ingress Selection](../../docs/adrs/ADR-003-traefik-ingress.md)
