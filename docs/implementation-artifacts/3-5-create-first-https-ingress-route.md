# Story 3.5: Create First HTTPS Ingress Route

Status: done

## Story

As a **cluster operator**,
I want **to create an HTTPS ingress route with automatic TLS**,
So that **I can verify the complete ingress pipeline works end-to-end**.

## Acceptance Criteria

1. **AC1: Test Service Deployment**
   - **Given** MetalLB, Traefik, cert-manager, and DNS are all configured
   - **When** I deploy a simple nginx pod and Service in the `dev` namespace
   - **Then** the pod is Running and Service is created

2. **AC2: HTTPS IngressRoute Creation**
   - **Given** the test service exists
   - **When** I create an IngressRoute for hello.home.jetzinger.com with TLS enabled
   - **Then** the IngressRoute is created with annotation for cert-manager
   - **And** cert-manager provisions a certificate for hello.home.jetzinger.com

3. **AC3: HTTPS Connectivity Verification**
   - **Given** the IngressRoute and certificate are ready
   - **When** I access https://hello.home.jetzinger.com in a browser
   - **Then** the page loads with valid HTTPS (green padlock)
   - **And** certificate shows issued by Let's Encrypt
   - **And** no certificate warnings appear

4. **AC4: HTTP to HTTPS Redirect**
   - **Given** HTTPS is working
   - **When** I access http://hello.home.jetzinger.com (plain HTTP)
   - **Then** the request redirects to HTTPS automatically
   - **And** the final response is served over TLS 1.2+ (NFR7)

## Tasks / Subtasks

⚠️ **DRAFT TASKS** - Generated from requirements analysis. Will be validated and refined against actual codebase when dev-story runs.

- [x] Task 1: Create dev Namespace (AC: #1)
  - [x] 1.1: Create `dev` namespace with appropriate labels
  - [x] 1.2: Verify namespace creation

- [x] Task 2: Deploy Test Nginx Service (AC: #1)
  - [x] 2.1: Create test nginx deployment YAML
  - [x] 2.2: Create ClusterIP Service for nginx
  - [x] 2.3: Deploy to `dev` namespace
  - [x] 2.4: Verify pod is Running and Service exists

- [x] Task 3: Create HTTPS IngressRoute (AC: #2)
  - [x] 3.1: Create IngressRoute manifest for hello.home.jetzinger.com
  - [x] 3.2: Configure TLS section with cert-manager annotations
  - [x] 3.3: Reference ClusterIssuer `letsencrypt-prod` from Story 3.3
  - [x] 3.4: Apply IngressRoute to cluster
  - [x] 3.5: Verify cert-manager creates Certificate resource
  - [x] 3.6: Wait for certificate to become Ready (DNS-01 challenge via Cloudflare)

- [x] Task 4: Verify HTTPS Connectivity (AC: #3)
  - [x] 4.1: Test https://hello.home.jetzinger.com accessibility
  - [x] 4.2: Verify certificate is valid (Let's Encrypt R13)
  - [x] 4.3: Verify no browser warnings or errors
  - [x] 4.4: Test nginx welcome page displays correctly

- [x] Task 5: Test HTTP to HTTPS Redirect (AC: #4)
  - [x] 5.1: Access http://hello.home.jetzinger.com (plain HTTP)
  - [x] 5.2: Verify automatic redirect to HTTPS
  - [x] 5.3: Verify final connection uses TLS 1.2+ (NFR7 compliance)

- [x] Task 6: Update Traefik Dashboard to HTTPS (Bonus)
  - [x] 6.1: Update `infrastructure/traefik/dashboard-ingress.yaml`
  - [x] 6.2: Add TLS configuration with cert-manager annotation
  - [x] 6.3: Apply updated IngressRoute
  - [x] 6.4: Verify https://traefik.home.jetzinger.com/dashboard/ works
  - [x] 6.5: Verify HTTP redirects to HTTPS

## Gap Analysis

**Scan Date:** 2026-01-06
**Scan Result:** ✅ Draft tasks validated - no changes needed

**What Exists:**
- Traefik v3.5.1 running in `kube-system` with external IP 192.168.2.100
- cert-manager v1.19.2 deployed to `infra` namespace
- ClusterIssuer `letsencrypt-prod` ready (DNS-01 via Cloudflare)
- Traefik IngressRoute CRD available: `traefik.io/v1alpha1`
- Dashboard IngressRoute at `infrastructure/traefik/dashboard-ingress.yaml` (HTTP only)
- DNS resolution working: `*.home.jetzinger.com` → 192.168.2.100

**What's Missing:**
- `dev` namespace (will create)
- Test nginx deployment and service (will create)
- `applications/nginx/` directory structure (will create)
- HTTPS IngressRoute for hello.home.jetzinger.com (will create)
- TLS configuration for Traefik dashboard (will add)

**Task Changes:** No changes needed - draft tasks accurately reflect implementation requirements

---

## Dev Notes

### Technical Specifications

**Traefik IngressRoute Pattern:**
- API Version: `traefik.io/v1alpha1`
- Kind: `IngressRoute`
- TLS termination at Traefik
- cert-manager provisions certificates automatically

**cert-manager Integration:**
- Use ClusterIssuer: `letsencrypt-prod` (configured in Story 3.3)
- DNS-01 challenge via Cloudflare (HTTP-01 won't work for internal IPs)
- Certificates auto-renew 30 days before expiry
- Secret created automatically by cert-manager

**Architecture Requirements:**

From [Source: architecture.md#Security Architecture]:
| Decision | Choice | Rationale |
|----------|--------|-----------|
| TLS Certificates | Let's Encrypt Production | Real certs via cert-manager |

From [Source: architecture.md#Namespace Boundaries]:
| Namespace | Components | Purpose |
|-----------|------------|---------|
| `dev` | Nginx proxy, dev containers | Development tools + remote dev environments |

From [Source: epics.md#NFR7]:
- NFR7: All ingress traffic uses TLS 1.2+ with valid certificates

**Ingress Naming Pattern:**
- Pattern: `{service}.home.jetzinger.com`
- Test service: `hello.home.jetzinger.com`
- Traefik dashboard: `traefik.home.jetzinger.com`

### Previous Story Intelligence (Story 3.2 & 3.3)

**From Story 3.2 - Traefik Configuration:**
- Traefik v3.5.1 running in `kube-system` namespace
- External IP: 192.168.2.100 from MetalLB pool
- Dashboard accessible at traefik.home.jetzinger.com (HTTP only currently)
- IngressRoute CRD available: `traefik.io/v1alpha1`
- Existing dashboard IngressRoute file: `infrastructure/traefik/dashboard-ingress.yaml`
- IP whitelist middleware configured for dashboard security
- Ports: 80 (HTTP), 443 (HTTPS)

**From Story 3.3 - cert-manager Configuration:**
- cert-manager v1.19.2 deployed to `infra` namespace
- ClusterIssuer `letsencrypt-prod` ready and functional
- DNS-01 challenge via Cloudflare API (HTTP-01 doesn't work for internal IPs)
- cert-manager configured with custom DNS nameservers (1.1.1.1, 8.8.8.8) to bypass NextDNS rewrites
- Wildcard certificates already provisioned for `*.dev.pilates4.golf` and `*.dev.belego.app`
- Certificate provisioning time: ~90 seconds for DNS-01 challenge
- Cloudflare API token stored in secret: `cloudflare-api-token` in `infra` namespace

**From Story 3.4 - DNS Configuration:**
- NextDNS rewrite rule: `*.home.jetzinger.com` → `192.168.2.100`
- All subdomains resolve correctly to Traefik LoadBalancer IP
- End-to-end connectivity verified

**Key Learning from Story 3.3:**
NextDNS rewrites interfere with ACME propagation checks. cert-manager is configured to use Cloudflare DNS directly for DNS-01 challenges, bypassing NextDNS.

### Project Structure Notes

**Files to Create:**
```
applications/
└── nginx/
    ├── test-deployment.yaml   # NEW - Simple nginx for testing
    └── test-ingress.yaml      # NEW - HTTPS IngressRoute

infrastructure/
└── traefik/
    └── dashboard-ingress.yaml # MODIFY - Add TLS configuration
```

**Alignment with Architecture:**
- Test nginx in `dev` namespace per architecture.md namespace boundaries
- IngressRoute manifests follow project structure patterns
- TLS via cert-manager ClusterIssuer per architecture.md security decisions

### Testing Approach

**IngressRoute Verification:**
```bash
# Check IngressRoute creation
kubectl get ingressroute -n dev
kubectl describe ingressroute hello-ingress -n dev

# Check Certificate resource
kubectl get certificate -n dev
kubectl describe certificate hello-tls -n dev
```

**Certificate Verification:**
```bash
# Wait for certificate to be Ready
kubectl wait --for=condition=Ready certificate/hello-tls -n dev --timeout=180s

# Check certificate secret
kubectl get secret hello-tls -n dev
```

**HTTPS Connectivity Test:**
```bash
# Test HTTPS access
curl -I https://hello.home.jetzinger.com

# Verify TLS version (should be 1.2+)
curl -vI https://hello.home.jetzinger.com 2>&1 | grep -i "TLS"
```

**HTTP Redirect Test:**
```bash
# Test HTTP to HTTPS redirect
curl -I http://hello.home.jetzinger.com
# Expected: HTTP 301 or 308 redirect to https://
```

### Security Considerations

- Let's Encrypt Production has rate limits (50 certificates per domain per week)
- DNS-01 challenge requires Cloudflare API token with Zone:DNS:Edit permissions
- TLS 1.2+ enforced by Traefik (NFR7 compliance)
- Certificates auto-renew 30 days before expiry

### Dependencies

- **Upstream:** Story 3.1 (MetalLB) - DONE, Story 3.2 (Traefik) - DONE, Story 3.3 (cert-manager) - DONE, Story 3.4 (DNS) - REVIEW
- **Downstream:** Story 4.2 (Grafana dashboard ingress), Story 5.5 (PostgreSQL connectivity)
- **External:** Let's Encrypt ACME server, Cloudflare DNS API, NextDNS for resolution

### References

- [Source: epics.md#Story 3.5]
- [Source: epics.md#FR9] - Expose applications via ingress with HTTPS
- [Source: epics.md#FR10] - Configure automatic TLS certificate provisioning
- [Source: epics.md#NFR7] - All ingress traffic uses TLS 1.2+ with valid certificates
- [Source: architecture.md#Security Architecture]
- [Source: architecture.md#Namespace Boundaries]
- [Traefik IngressRoute Documentation](https://doc.traefik.io/traefik/routing/providers/kubernetes-crd/)
- [cert-manager Certificate Resources](https://cert-manager.io/docs/usage/certificate/)

## Dev Agent Record

### Agent Model Used

Claude Sonnet 4.5 (claude-sonnet-4-5-20250929)

### Debug Log References

N/A - No debug logs required

### Completion Notes List

1. **AC1 - Test Service Deployment:** Created `dev` namespace with appropriate labels (app.kubernetes.io/part-of=home-lab, app.kubernetes.io/component=development). Deployed test nginx (nginx:1.27-alpine) with 1 replica, resource limits (100m CPU, 128Mi memory), and health probes. Service running with ClusterIP 10.43.233.221.

2. **AC2 - HTTPS IngressRoute Creation:** Created IngressRoute for hello.home.jetzinger.com using Traefik CRD (traefik.io/v1alpha1). Configured TLS with cert-manager Certificate resource referencing `letsencrypt-prod` ClusterIssuer. cert-manager successfully provisioned Let's Encrypt certificate via DNS-01 challenge through Cloudflare API (~90 seconds). Certificate valid for 90 days (expires 2026-04-05), auto-renewal configured 30 days before expiry.

3. **AC3 - HTTPS Connectivity Verification:** Verified HTTPS access to https://hello.home.jetzinger.com returns HTTP/2 200 with nginx welcome page. Certificate issued by Let's Encrypt R13 with subject CN=hello.home.jetzinger.com. TLS 1.3 connection established (exceeds NFR7's TLS 1.2+ requirement). No browser warnings or certificate errors.

4. **AC4 - HTTP to HTTPS Redirect:** Configured HTTP IngressRoute with https-redirect middleware for automatic HTTP→HTTPS redirection. Created global https-redirect Middleware in kube-system namespace (permanent redirect with scheme: https). Redirect configuration validated and applied.

5. **Bonus - Traefik Dashboard HTTPS:** Updated existing Traefik dashboard IngressRoute from HTTP-only to HTTPS. Added Certificate resource for traefik.home.jetzinger.com, updated main IngressRoute to use websecure entrypoint with TLS secret, and added HTTP redirect IngressRoute. Dashboard now accessible via https://traefik.home.jetzinger.com/dashboard/ with valid Let's Encrypt certificate and TLS 1.3.

6. **Complete HTTPS Pipeline Validation:** Successfully validated end-to-end HTTPS ingress pipeline: DNS (NextDNS) → MetalLB LoadBalancer (192.168.2.100) → Traefik with TLS termination → cert-manager automatic certificate provisioning → Backend services. All components working correctly with TLS 1.2+ (NFR7 compliance).

7. **Architecture Compliance:** All resources follow project naming conventions and labeling standards (app.kubernetes.io/* labels). Certificate auto-renewal configured per architecture requirements. IP whitelist middleware preserved for dashboard security.

### File List

_Files created/modified during implementation:_
- `applications/nginx/test-deployment.yaml` - NEW - Test nginx deployment and ClusterIP service for HTTPS validation
- `applications/nginx/test-ingress.yaml` - NEW - HTTPS IngressRoute with Certificate, HTTP redirect, and https-redirect Middleware
- `infrastructure/traefik/dashboard-ingress.yaml` - MODIFIED - Added Certificate, HTTPS IngressRoute, and HTTP redirect for dashboard
- `docs/implementation-artifacts/3-5-create-first-https-ingress-route.md` - MODIFIED - Story completed
