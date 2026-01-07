# Story 3.3: Deploy cert-manager with Let's Encrypt

Status: done

## Story

As a **cluster operator**,
I want **to deploy cert-manager that automatically provisions TLS certificates**,
so that **all my services can use valid HTTPS without manual certificate management**.

## Acceptance Criteria

1. **AC1: cert-manager Deployment**
   - **Given** cluster is running with ingress working
   - **When** I deploy cert-manager via Helm to the `infra` namespace
   - **Then** cert-manager controller, webhook, and cainjector pods are Running
   - **And** CRDs for Certificate, Issuer, ClusterIssuer are installed

2. **AC2: ClusterIssuer Configuration**
   - **Given** cert-manager is running
   - **When** I create a ClusterIssuer for Let's Encrypt Production with DNS-01 challenge (via Cloudflare)
   - **Then** the ClusterIssuer shows Ready status
   - **And** `kubectl describe clusterissuer letsencrypt-prod` shows no errors

3. **AC3: Certificate Provisioning**
   - **Given** ClusterIssuer is ready
   - **When** I create a test Certificate resource for test.home.jetzinger.com
   - **Then** cert-manager requests a certificate from Let's Encrypt
   - **And** the Certificate status shows Ready within 2 minutes
   - **And** a Secret containing tls.crt and tls.key is created

4. **AC4: TLS Compliance**
   - **Given** certificates are provisioned automatically
   - **When** I inspect the certificate
   - **Then** it uses TLS 1.2 or higher (NFR7)
   - **And** certificate is valid and not self-signed

## Tasks / Subtasks

- [x] Task 1: Deploy cert-manager via Helm (AC: #1)
  - [x] 1.1: Create `infrastructure/cert-manager/` directory
  - [x] 1.2: Create `values-homelab.yaml` with cert-manager configuration
  - [x] 1.3: Add Helm repository for cert-manager (`jetstack/cert-manager`)
  - [x] 1.4: Deploy cert-manager to `infra` namespace via Helm
  - [x] 1.5: Verify controller, webhook, and cainjector pods are Running
  - [x] 1.6: Verify CRDs are installed (Certificate, Issuer, ClusterIssuer)

- [x] Task 2: Configure ClusterIssuer for Let's Encrypt (AC: #2)
  - [x] 2.1: Create `cluster-issuer.yaml` with Let's Encrypt issuers (staging + prod)
  - [x] 2.2: Configure DNS-01 challenge solver via Cloudflare API
  - [x] 2.3: Create Kubernetes secret for Cloudflare API token
  - [x] 2.4: Apply ClusterIssuer to cluster
  - [x] 2.5: Verify ClusterIssuer shows Ready status

- [x] Task 3: Test Certificate Provisioning (AC: #3)
  - [x] 3.1: Create test Certificate resource for test.home.jetzinger.com
  - [x] 3.2: Wait for Certificate to become Ready (staging first, then production)
  - [x] 3.3: Verify Secret containing tls.crt and tls.key is created
  - [x] 3.4: Clean up test certificate resources

- [x] Task 4: Validate TLS Compliance (AC: #4)
  - [x] 4.1: Inspect certificate details (issuer: Let's Encrypt R13, validity: 90 days)
  - [x] 4.2: Verify SHA256/RSA-2048 (TLS 1.2+ compatible per NFR7)
  - [x] 4.3: Verify certificate is from Let's Encrypt (not self-signed)
  - [x] 4.4: Document certificate configuration

## Gap Analysis

**Scan Date:** 2026-01-05
**Scan Result:** ✅ Draft tasks validated - no changes needed

**What Exists:**
- `infra` namespace available (currently has NFS provisioner)
- Traefik running with external IP 192.168.2.100
- MetalLB providing LoadBalancer services
- K3s cluster with 3 nodes Ready (k3s-master, k3s-worker-01, k3s-worker-02)

**What's Missing:**
- `infrastructure/cert-manager/` directory (will create)
- cert-manager Helm release (will deploy)
- cert-manager CRDs (will be installed with Helm chart)
- ClusterIssuer for Let's Encrypt Production (will create)

**Task Changes:** None - draft tasks accurate for fresh cert-manager installation

---

## Dev Notes

### Technical Specifications

**cert-manager Deployment:**
- Helm Chart: `jetstack/cert-manager`
- Namespace: `infra` (per architecture)
- Components:
  - Controller: Manages Certificate lifecycle
  - Webhook: Validates cert-manager resources
  - CAInjector: Injects CA bundles

**Let's Encrypt Configuration:**
- Server: `https://acme-v02.api.letsencrypt.org/directory` (Production)
- Challenge: DNS-01 via Cloudflare API (HTTP-01 won't work for internal domains)
- Email: tt@jetzinger.com (for certificate expiry notifications)
- DNS Nameservers: 1.1.1.1, 8.8.8.8 (bypasses NextDNS rewrites for ACME checks)

**Architecture Requirements:**

From [Source: architecture.md#Security Architecture]:
| Decision | Choice | Rationale |
|----------|--------|-----------|
| TLS Certificates | Let's Encrypt Production | Real certs via cert-manager |

From [Source: architecture.md#Namespace Boundaries]:
| Namespace | Components | Purpose |
|-----------|------------|---------|
| `infra` | MetalLB, cert-manager | Core infrastructure |

From [Source: architecture.md#Project Structure]:
```
infrastructure/
└── cert-manager/
    ├── values-homelab.yaml        # cert-manager config
    └── cluster-issuer.yaml        # Let's Encrypt issuer
```

From [Source: epics.md#NFR7]:
- NFR7: All ingress traffic uses TLS 1.2+ with valid certificates

### Previous Story Intelligence (Story 3.2)

**Traefik Configuration:**
- Traefik running in kube-system namespace
- External IP: 192.168.2.100 from MetalLB pool
- Dashboard accessible at traefik.home.jetzinger.com (HTTP)
- Ports 80/443 accessible from home network

**Current Cluster State:**
| Node | IP | Status |
|------|-----|--------|
| k3s-master | 192.168.2.20 | Ready |
| k3s-worker-01 | 192.168.2.21 | Ready |
| k3s-worker-02 | 192.168.2.22 | Ready |

**Learnings from 3.2:**
- Traefik v3.5.1 bundled with K3s
- IngressRoute CRDs available from traefik.io/v1alpha1
- IP whitelist middleware needed pod/node networks due to SNAT
- Traefik dashboard enabled via `--api.dashboard=true`

### Project Structure Notes

**Files to Create:**
```
infrastructure/
└── cert-manager/
    ├── values-homelab.yaml     # NEW - cert-manager Helm values
    └── cluster-issuer.yaml     # NEW - Let's Encrypt ClusterIssuer
```

**Alignment with Architecture:**
- cert-manager in `infra` namespace per architecture.md
- Values file follows `values-homelab.yaml` naming convention
- ClusterIssuer (cluster-scoped) vs Issuer (namespace-scoped)

### Testing Approach

**cert-manager Verification:**
```bash
# Check cert-manager pods
kubectl get pods -n infra | grep cert-manager

# Expected output:
# cert-manager-xxx           Running
# cert-manager-cainjector-xxx Running
# cert-manager-webhook-xxx   Running

# Check CRDs
kubectl get crds | grep cert-manager
```

**ClusterIssuer Verification:**
```bash
# Check ClusterIssuer status
kubectl get clusterissuer
kubectl describe clusterissuer letsencrypt-prod

# Expected: Ready = True
```

**Certificate Test:**
```bash
# Create test certificate
kubectl apply -f test-certificate.yaml

# Check certificate status
kubectl get certificate -n infra
kubectl describe certificate test-cert -n infra

# Check secret created
kubectl get secret test-cert-tls -n infra
```

### Security Considerations

- Let's Encrypt Production has rate limits (50 certificates per domain per week)
- Use Let's Encrypt Staging for testing to avoid rate limits
- HTTP-01 challenge requires port 80 accessible to Let's Encrypt servers
- cert-manager creates Secrets for certificates (tls.crt, tls.key)

### DNS Requirement

**Important:** For Let's Encrypt HTTP-01 challenge to work:
- DNS for *.home.jetzinger.com must resolve to Traefik's external IP (192.168.2.100)
- Story 3.4 configures NextDNS for this - may need to configure manually first
- Alternative: Use DNS-01 challenge if HTTP-01 fails from internal network

### Dependencies

- **Upstream:** Story 3.1 (MetalLB) - COMPLETED, Story 3.2 (Traefik) - COMPLETED
- **Downstream:** Story 3.5 (HTTPS ingress)
- **External:** Let's Encrypt ACME server, DNS resolution for HTTP-01 challenge

### References

- [Source: epics.md#Story 3.3]
- [Source: epics.md#FR10]
- [Source: epics.md#NFR7]
- [Source: architecture.md#Security Architecture]
- [Source: architecture.md#Namespace Boundaries]
- [cert-manager Installation](https://cert-manager.io/docs/installation/helm/)
- [Let's Encrypt HTTP-01 Challenge](https://cert-manager.io/docs/configuration/acme/http01/)
- [Traefik + cert-manager Integration](https://doc.traefik.io/traefik/https/acme/)

## Dev Agent Record

### Agent Model Used

Claude Opus 4.5 (claude-opus-4-5-20251101)

### Debug Log References

N/A - No debug logs required

### Completion Notes List

1. **AC1 - cert-manager Deployment:** Deployed cert-manager v1.19.2 via Helm to `infra` namespace. All three pods running: controller, webhook, cainjector. Six CRDs installed including Certificate, Issuer, ClusterIssuer.

2. **AC2 - ClusterIssuer Configuration:** Created two ClusterIssuers (letsencrypt-staging and letsencrypt-prod) using DNS-01 challenge via Cloudflare API. Both show Ready status. Note: HTTP-01 was initially attempted but failed because Let's Encrypt servers cannot reach internal IPs (192.168.2.100). DNS-01 solves this by creating TXT records in Cloudflare.

3. **AC3 - Certificate Provisioning:** Successfully tested certificate provisioning with both staging and production issuers. Production certificate issued by Let's Encrypt R13 for `test.home.jetzinger.com`. Certificate ready in ~90 seconds. Secret created with tls.crt and tls.key.

4. **AC4 - TLS Compliance:** Verified certificate uses RSA-2048 key with SHA256 signature (TLS 1.2+ compatible per NFR7). Certificate is valid Let's Encrypt production certificate (not self-signed), valid for 90 days.

5. **Key Learning - NextDNS Interference:** NextDNS rewrites `*.home.jetzinger.com` to 192.168.2.100, which prevented cert-manager's DNS propagation check from finding TXT records. Resolved by configuring cert-manager to use Cloudflare DNS (1.1.1.1, 8.8.8.8) directly via `--dns01-recursive-nameservers` and `--dns01-recursive-nameservers-only` flags.

6. **Cloudflare Integration:** API token stored in Kubernetes secret `cloudflare-api-token` in `infra` namespace. Token requires Zone:DNS:Edit and Zone:Zone:Read permissions.

7. **Additional Wildcard Certificates:** Created production wildcard certificates for dev environments:
   - `*.dev.pilates4.golf` → Secret: `pilates4-golf-wildcard-tls`
   - `*.dev.belego.app` → Secret: `belego-app-wildcard-tls`
   Both auto-renew 30 days before expiry.

### File List

_Files created/modified during implementation:_
- `infrastructure/cert-manager/values-homelab.yaml` - NEW - cert-manager Helm values with DNS nameserver config
- `infrastructure/cert-manager/cluster-issuer.yaml` - NEW - Let's Encrypt ClusterIssuers (staging + prod) with Cloudflare DNS-01
- `infrastructure/cert-manager/wildcard-certificates.yaml` - NEW - Wildcard certs for dev.pilates4.golf and dev.belego.app
- `docs/implementation-artifacts/3-3-deploy-cert-manager-with-lets-encrypt.md` - MODIFIED - Story completed
