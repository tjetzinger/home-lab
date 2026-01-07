# ADR-003: Traefik Ingress Controller (K3s Bundled)

**Status:** Accepted
**Date:** 2026-01-07
**Decision Makers:** Tom, Claude (AI Assistant)

## Context

The home-lab K3s cluster requires an Ingress Controller to route external HTTPS traffic to internal services (Grafana, Ollama, n8n, Paperless-ngx). All services must be accessible via subdomains (e.g., `grafana.home.jetzinger.com`) with automatic TLS certificate provisioning.

Requirements:
- HTTPS ingress routes for 8+ services
- Integration with cert-manager for Let's Encrypt certificates
- DNS routing via NextDNS rewrites (192.168.2.0/24 → subdomains)
- Access restricted to Tailscale VPN (no public internet exposure)
- NFR: 5-second dashboard load time
- Single operator management (learning-first approach)

## Decision Drivers

- **K3s bundled component** - Traefik included by default (zero installation overhead)
- **cert-manager integration** - Well-documented TLS automation workflow
- **Simplicity at home lab scale** - Sufficient for 8+ services, straightforward configuration
- **Learning value** - Understanding Traefik concepts (IngressRoute, Middleware) applicable to production
- **Community momentum** - Traefik v2+ widely adopted in K3s/edge deployments
- **Time efficiency** - No separate installation/configuration required

## Considered Options

### Option 1: Traefik v2 (K3s Bundled) - Selected

**Pros:**
- **Zero installation** - Included with K3s out-of-the-box
- **Pre-configured** - Runs as DaemonSet in `kube-system` namespace
- **cert-manager support** - Standard annotations for TLS automation
- **Active development** - Traefik Labs maintains K3s integration
- **CRD-based config** - IngressRoute custom resources (more flexible than Ingress)
- **Metrics endpoint** - Prometheus integration built-in
- **Dynamic configuration** - Hot reload without pod restarts

**Cons:**
- Different API from standard Ingress (IngressRoute CRD)
- Less documentation than nginx-ingress for some use cases
- Migration path required if moving to standard K8s (non-K3s)
- Fewer third-party integrations than nginx ecosystem

### Option 2: nginx-ingress Controller

**Pros:**
- **Most widely used** - Largest community, extensive documentation
- **Standard Ingress API** - Uses native Kubernetes Ingress resources
- **Feature-rich** - Advanced routing, auth, rate limiting
- **Production proven** - Battle-tested at scale

**Cons:**
- **Separate installation required** - Additional Helm deployment step
- Higher resource overhead (nginx pods + controller)
- Configuration via annotations can become complex
- Requires replacing K3s default (Traefik)
- Less optimized for edge/lightweight deployments

### Option 3: HAProxy Ingress Controller

**Pros:**
- High performance for L4/L7 load balancing
- Advanced traffic shaping capabilities
- Enterprise support available

**Cons:**
- **Smaller community** compared to Traefik/nginx
- Separate installation required
- Steeper learning curve (HAProxy configuration syntax)
- Overkill for home lab scale (8 services)

### Option 4: Istio Service Mesh

**Pros:**
- Full service mesh (mTLS, observability, traffic management)
- Advanced features (canary deployments, circuit breaking)
- Industry-standard for microservices architectures

**Cons:**
- **Massive operational complexity** - Control plane, sidecar proxies, CRDs
- **High resource overhead** - Requires significant CPU/memory
- Steep learning curve (Envoy, VirtualService, Gateway concepts)
- **Overkill for home lab** - 99% of features unused
- Conflicts with K3s simplicity philosophy

## Decision

**Use Traefik v2 (K3s bundled) as the Ingress Controller**

Implementation approach:
- **Keep K3s default** - Traefik already running in `kube-system` namespace
- **IngressRoute CRDs** - Use Traefik-native resources for routing
- **cert-manager integration** - TLS annotations on IngressRoute resources
- **MetalLB LoadBalancer** - Traefik service gets external IP (192.168.2.50)
- **NextDNS rewrites** - `*.home.jetzinger.com` → 192.168.2.50
- **Tailscale only** - No firewall ports exposed to public internet

## Consequences

### Positive

- **Immediate availability** - No installation required, works out-of-the-box
- **Resource efficiency** - No additional ingress controller pods
- **Simplified troubleshooting** - Single ingress solution, no version conflicts
- **Learning value** - Traefik concepts (IngressRoute, Middleware) transferable to production edge deployments
- **Automatic updates** - Traefik version managed by K3s upgrades
- **Fast implementation** - Create IngressRoute → TLS cert auto-provisioned → service accessible

### Negative

- **API divergence** - IngressRoute CRD not portable to standard K8s (must convert to Ingress)
- **K3s lock-in** - Migration to vanilla K8s requires ingress controller replacement
- **Community fragmentation** - Some Helm charts provide only standard Ingress manifests (requires conversion)
- **Limited ecosystem** - Fewer third-party tools/plugins vs nginx

### Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| IngressRoute API changes | K3s maintains compatibility; version pinning available if needed |
| Traefik bugs/vulnerabilities | K3s security updates include Traefik patches; can disable and install alternative |
| Insufficient features for future needs | Can run nginx-ingress alongside Traefik if specific nginx features needed (separate service port) |
| Migration complexity to vanilla K8s | Document IngressRoute → Ingress conversion pattern; defer migration concern to Phase 2+ |
| cert-manager integration issues | Well-documented workflow; extensive community examples; fallback to manual cert provisioning |

## Implementation Notes

**Verify Traefik Running:**
```bash
kubectl get pods -n kube-system | grep traefik
kubectl get svc -n kube-system traefik
```

**Example IngressRoute:**
```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: grafana-ingress
  namespace: monitoring
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`grafana.home.jetzinger.com`)
      kind: Rule
      services:
        - name: prometheus-grafana
          port: 80
  tls:
    secretName: grafana-tls
```

**Traefik Dashboard (Optional Debugging):**
```bash
kubectl port-forward -n kube-system $(kubectl get pods -n kube-system | grep traefik | awk '{print $1}') 9000:9000
# Access: http://localhost:9000/dashboard/
```

**MetalLB Integration:**
Traefik service uses LoadBalancer type with IP from MetalLB pool (192.168.2.50-192.168.2.60).

**DNS Configuration:**
NextDNS rewrites:
- `*.home.jetzinger.com` → 192.168.2.50 (Traefik LoadBalancer IP)

**Future Migration Path (Phase 2+):**
If moving to vanilla K8s or requiring standard Ingress API:
1. Install nginx-ingress alongside Traefik (different service port)
2. Convert IngressRoute → Ingress resources (automated script possible)
3. Test services on nginx-ingress
4. Update DNS to point to nginx-ingress LoadBalancer
5. Decommission Traefik

## References

- [Architecture Decision: Networking & Ingress](../planning-artifacts/architecture.md#networking--ingress)
- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [K3s Networking](https://docs.k3s.io/networking)
- [cert-manager with Traefik](https://cert-manager.io/docs/usage/ingress/)
- [Story 3.2: Configure Traefik Ingress Controller](../implementation-artifacts/sprint-status.yaml)
- [Story 3.5: Create First HTTPS Ingress Route](../implementation-artifacts/sprint-status.yaml)
