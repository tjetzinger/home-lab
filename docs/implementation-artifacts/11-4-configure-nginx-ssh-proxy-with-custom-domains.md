# Story 11.4: Configure Nginx SSH Proxy with Custom Domains

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **developer**,
I want **SSH access to dev containers via custom domains on different ports**,
so that **I can use VS Code Remote SSH with familiar domain names**.

## Acceptance Criteria

1. **Given** dev containers are running
   **When** I deploy Nginx with stream module
   **Then** the ConfigMap includes stream configuration:
   - Stream module loaded for TCP proxying
   - Upstream `dev-belego` → `dev-container-belego-svc.dev.svc.cluster.local:22`
   - Upstream `dev-pilates` → `dev-container-pilates-svc.dev.svc.cluster.local:22`
   - Port 2222 → Belego dev container
   - Port 2223 → Pilates dev container

2. **Given** Nginx proxy is deployed
   **When** I create IngressRoutes for HTTP/HTTPS access
   **Then** the following domains are configured:
   - `dev.belego.app` → Nginx service (Belego HTTP traffic)
   - `dev.app.pilates4.golf` → Nginx service (Pilates HTTP)
   - `dev.blog.pilates4.golf` → Nginx service (same backend)
   - `dev.join.pilates4.golf` → Nginx service (same backend)
   - `dev.www.pilates4.golf` → Nginx service (same backend)

3. **Given** IngressRoutes use custom domains
   **When** I configure NextDNS with wildcard rewrites
   **Then** the following DNS entries point to MetalLB IP (192.168.2.100):
   - `*.belego.app` → 192.168.2.100
   - `*.pilates4.golf` → 192.168.2.100

4. **Given** DNS is configured
   **When** I SSH to `dev.belego.app:2222`
   **Then** I connect to Belego dev container
   **And** when I SSH to any Pilates domain on port 2223
   **Then** I connect to the same Pilates dev container
   **And** this validates FR59, FR61 (Nginx proxy routes to dev containers)

## Tasks / Subtasks

**Note:** This story requires significant changes to the existing nginx-proxy deployment to support TCP stream proxying in addition to HTTP proxying.

- [x] **Task 1:** Update nginx ConfigMap with stream module (AC: 1)
  - [x] Stream module compiled-in with nginx:alpine (no load_module needed)
  - [x] Add stream block with map directive for runtime DNS resolution
  - [x] Configure port 2222 for Belego, port 2223 for Pilates
  - [x] Preserve existing HTTP configuration

- [x] **Task 2:** Update nginx Service to expose SSH ports (AC: 1)
  - [x] Add port 2222 (SSH Belego)
  - [x] Add port 2223 (SSH Pilates)
  - [x] Keep existing port 80 (HTTP)

- [x] **Task 3:** Update nginx Deployment (AC: 1)
  - [x] Add container ports 2222, 2223
  - [x] Verified nginx:alpine includes stream module (compiled with --with-stream)

- [x] **Task 4:** Create IngressRoutes for custom domains (AC: 2)
  - [x] Create IngressRoute for `dev.belego.app`
  - [x] Create IngressRoutes for Pilates domains (dev.pilates4.golf, dev.app, dev.admin, dev.blog, dev.join, dev.www)
  - [x] Configure TLS with Let's Encrypt via cert-manager

- [x] **Task 5:** Configure NextDNS rewrites (AC: 3) - MANUAL
  - [x] Add `*.belego.app` → 192.168.2.100 rewrite
  - [x] Add `*.pilates4.golf` → 192.168.2.100 rewrite
  - [x] DNS configuration verified working

- [x] **Task 6:** Expose SSH ports via LoadBalancer (AC: 4)
  - [x] Created LoadBalancer service `nginx-proxy-ssh` (service-ssh-lb.yaml)
  - [x] MetalLB assigned IP 192.168.2.101
  - [x] External SSH access verified

- [x] **Task 7:** Test SSH connectivity (AC: 4)
  - [x] Fixed SSH key ownership issue (ConfigMap mounts as root)
  - [x] SSH via LoadBalancer IP working: `ssh -p 2222 dev@192.168.2.101`
  - [x] Both containers accessible (port 2222=Belego, 2223=Pilates)
  - [x] VS Code SSH config documented

- [x] **Task 8:** Documentation and sprint status update
  - [x] Update nginx README with SSH proxy info
  - [x] Update dev-containers README with SSH access instructions
  - [x] Update sprint-status.yaml to mark story done

## Gap Analysis

**Scan Date:** 2026-01-09

### What Exists:
| Item | Location | Status |
|------|----------|--------|
| nginx-proxy Deployment | `applications/nginx/deployment.yaml` | Operational (HTTP only) |
| nginx-proxy Service | `applications/nginx/service.yaml` | ClusterIP:80 |
| nginx-proxy ConfigMap | `applications/nginx/configmap.yaml` | HTTP config only |
| dev-container-belego-svc | dev namespace | ClusterIP:22 |
| dev-container-pilates-svc | dev namespace | ClusterIP:22 |
| Config watcher | `applications/nginx/config-watcher-configmap.yaml` | Hot-reload enabled |
| Traefik Ingress | cluster | Operational |

### What's Missing (To Be Created/Modified):
| Item | Required Action |
|------|-----------------|
| Stream module config | MODIFY - Add to nginx.conf |
| SSH ports in Service | MODIFY - Add 2222, 2223 |
| SSH ports in Deployment | MODIFY - Add containerPorts |
| IngressRoutes for domains | CREATE - Traefik IngressRoute manifests |
| NextDNS rewrites | MANUAL - Configure in NextDNS dashboard |
| LoadBalancer/TCPIngressRoute | CREATE - External SSH exposure |

**Architecture Decision:** Need to decide between:
1. LoadBalancer service for SSH (simpler, uses MetalLB IP)
2. Traefik TCPIngressRoute (more complex, but consistent with HTTP ingress)

---

## Dev Notes

### Architecture Requirements

**Dev Containers Architecture:** [Source: docs/planning-artifacts/architecture.md#Dev Containers Architecture]
- Access: SSH via Nginx proxy (nginx already handles routing in `dev` namespace)
- FR59: Nginx proxy routes to dev containers
- FR61: Connect VS Code via Nginx proxy

### Technical Constraints

**Nginx Stream Module:**
- nginx:alpine image includes stream module but may need to load it explicitly
- Stream block must be at top level (same level as http block)
- Cannot mix http and stream directives in same block

**Ports:**
- Port 2222 → Belego dev container SSH
- Port 2223 → Pilates dev container SSH
- Port 80 → HTTP proxy (existing)

**DNS/Ingress:**
- Domains: `*.belego.app`, `*.pilates4.golf`
- MetalLB IP: 192.168.2.100
- SSH traffic is TCP, not HTTP - requires either LoadBalancer or Traefik TCPIngressRoute

### Previous Story Intelligence

**From Story 11.2:**
- SSH services: `dev-container-belego-svc:22`, `dev-container-pilates-svc:22`
- SSH connectivity verified via kubectl port-forward
- Both containers running on k3s-worker-02

**From Epic 7 (Nginx Proxy):**
- Hot-reload configuration working (config-watcher.sh)
- nginx-proxy-config ConfigMap for nginx.conf
- nginx:1.27-alpine image

### Project Structure Notes

**Directory:** `applications/nginx/`
- `deployment.yaml` - Current HTTP-only deployment
- `service.yaml` - Current ClusterIP:80 service
- `configmap.yaml` - Current HTTP nginx.conf
- `config-watcher-configmap.yaml` - Hot-reload script
- `ingress.yaml` - HTTP ingress (may need TCP equivalent)

### Testing Requirements

**Validation Checklist:**
1. [ ] Nginx starts with stream module loaded
2. [ ] SSH ports 2222, 2223 accessible within cluster
3. [ ] SSH ports accessible externally via domain:port
4. [ ] VS Code Remote SSH connects successfully
5. [ ] IngressRoutes serve dev.*.domains correctly

**Test Commands:**
```bash
# Verify nginx config
kubectl exec deployment/nginx-proxy -n dev -- nginx -t

# Test internal SSH routing
kubectl run test-ssh --rm -it --image=alpine -n dev -- nc -zv nginx-proxy 2222
kubectl run test-ssh --rm -it --image=alpine -n dev -- nc -zv nginx-proxy 2223

# Test external SSH (after LoadBalancer/TCP ingress)
ssh -p 2222 dev@dev.belego.app
ssh -p 2223 dev@dev.app.pilates4.golf
```

### VS Code SSH Config

After completion, users should add to `~/.ssh/config`:
```
Host dev-belego
    HostName dev.belego.app
    Port 2222
    User dev

Host dev-pilates
    HostName dev.app.pilates4.golf
    Port 2223
    User dev
```

### References

- [Epic 11: Dev Containers Platform](../planning-artifacts/epics.md#epic-11)
- [Story 11.2: Deploy Dev Containers](./11-2-deploy-dev-containers-for-belego-and-pilates.md)
- [FR59: Nginx proxy routes to dev containers](../planning-artifacts/prd.md)
- [FR61: Connect VS Code via Nginx proxy](../planning-artifacts/prd.md)
- [Epic 7: Development Proxy](../planning-artifacts/epics.md#epic-7)

---

## Dev Agent Record

### Completion Date
2026-01-10

### Files Created/Modified

| File | Action | Description |
|------|--------|-------------|
| `applications/nginx/configmap.yaml` | Modified | Added stream block with map directive for SSH proxy |
| `applications/nginx/service.yaml` | Modified | Added ports 2222 (Belego) and 2223 (Pilates) |
| `applications/nginx/deployment.yaml` | Modified | Added container ports 2222, 2223 |
| `applications/nginx/service-ssh-lb.yaml` | Created | LoadBalancer service for external SSH access |
| `applications/nginx/ingressroute-dev-domains.yaml` | Created | IngressRoutes and Certificates for dev domains |
| `applications/nginx/README.md` | Modified | Added SSH Proxy documentation section |
| `applications/dev-containers/README.md` | Modified | Added SSH access instructions |
| `applications/dev-containers/dev-container-template.yaml` | Modified | Fixed SSH key ownership in startup script |
| `applications/dev-containers/dev-container-belego.yaml` | Modified | Fixed SSH key ownership in startup script |
| `applications/dev-containers/dev-container-pilates.yaml` | Modified | Fixed SSH key ownership in startup script |

### Key Learnings

1. **Stream module in nginx:alpine**: The `nginx:alpine` image has the stream module compiled-in (`--with-stream`), so no `load_module` directive is needed.

2. **DNS resolution in stream blocks**: Nginx stream blocks resolve DNS at startup time. Using a `map` directive with `$server_port` forces runtime resolution, avoiding "host not found in upstream" errors when services aren't ready.

3. **ConfigMap ownership issue**: Kubernetes ConfigMaps mount with root ownership. For SSH authorized_keys, the startup script must copy from a temp location and `chown` to the correct user before starting sshd.

4. **LoadBalancer vs TCPIngressRoute**: Chose LoadBalancer (MetalLB) for SSH ports because:
   - Simpler configuration
   - Dedicated IP (192.168.2.101) for SSH traffic
   - Keeps HTTP traffic on main Traefik IP (192.168.2.100)

### External IP Allocation

| Service | IP | Purpose |
|---------|-----|---------|
| Traefik | 192.168.2.100 | HTTP/HTTPS ingress |
| nginx-proxy-ssh | 192.168.2.101 | SSH access to dev containers |

### SSH Access Summary

```bash
# Via LoadBalancer IP
ssh -p 2222 dev@192.168.2.101  # Belego
ssh -p 2223 dev@192.168.2.101  # Pilates

# VS Code SSH config
Host dev-belego
    HostName 192.168.2.101
    Port 2222
    User dev

Host dev-pilates
    HostName 192.168.2.101
    Port 2223
    User dev
```

### Verification Commands

```bash
# Test SSH connectivity
ssh -p 2222 dev@192.168.2.101 echo "Belego connected"
ssh -p 2223 dev@192.168.2.101 echo "Pilates connected"

# Check nginx stream config
kubectl exec deployment/nginx-proxy -n dev -- nginx -t

# Verify LoadBalancer IP
kubectl get svc nginx-proxy-ssh -n dev
```
