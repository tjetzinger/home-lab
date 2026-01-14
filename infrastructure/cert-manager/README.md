# cert-manager - Automated TLS Certificate Management

**Story:** 3.3 - Deploy cert-manager with Let's Encrypt
**Epic:** 3 - Ingress, TLS & Service Exposure
**Namespace:** `infra`

## What It Does

cert-manager automates the management and issuance of TLS certificates from various certificate authorities (CAs). It ensures Kubernetes Ingress resources and services have valid TLS certificates with automatic renewal before expiration.

## Why It Was Chosen

**Decision Rationale (ADR-003):**
- **Automatic certificate lifecycle:** Eliminates manual certificate renewal and reduces operational overhead
- **Let's Encrypt integration:** Free, automated CA with broad browser trust
- **Native Kubernetes integration:** Uses CRDs (Certificate, ClusterIssuer) for declarative certificate management
- **DNS-01 challenge support:** Enables wildcard certificates for `*.home.jetzinger.com`

**Alternatives Considered:**
- Manual certificate management → Rejected (operational burden, expiration risks)
- Traefik's built-in ACME → Rejected (less flexible, limited to HTTP-01 challenges)
- External certificate proxy → Rejected (additional infrastructure complexity)

## Key Configuration Decisions

### ClusterIssuer Configuration

cert-manager uses a `ClusterIssuer` resource to define the Let's Encrypt CA configuration:

**Production Issuer** (`letsencrypt-prod`):
- Endpoint: `https://acme-v02.api.letsencrypt.org/directory`
- Rate limits: 50 certificates per domain per week
- Use for: All production ingress routes

**Staging Issuer** (`letsencrypt-staging`):
- Endpoint: `https://acme-staging-v02.api.letsencrypt.org/directory`
- Higher rate limits for testing
- Use for: Development and testing only (untrusted certificates)

### Challenge Method

**DNS-01 Challenge:**
- Validates domain ownership via DNS TXT records
- Enables wildcard certificates (`*.home.jetzinger.com`)
- Requires DNS provider API integration (NextDNS in this deployment)

**HTTP-01 Challenge:**
- Alternative: Validates via HTTP endpoint
- Limitation: Cannot issue wildcard certificates
- Not used in this deployment

### Certificate Lifecycle

- **Renewal threshold:** Certificates renewed 30 days before expiration (Let's Encrypt default: 90-day validity)
- **Auto-renewal:** cert-manager monitors Certificate resources and renews automatically
- **Secret storage:** Certificates stored as Kubernetes Secrets, referenced by Ingress resources

## How to Access/Use

### Automatic Certificate Issuance for Ingress

Add annotations to Ingress or IngressRoute resources:

```yaml
metadata:
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  tls:
    - secretName: example-tls  # cert-manager creates this Secret
      hosts:
        - example.home.jetzinger.com
```

### Check Certificate Status

View certificate status:
```bash
kubectl get certificates -A
kubectl describe certificate <cert-name> -n <namespace>
```

View certificate details from Secret:
```bash
kubectl get secret <cert-secret-name> -n <namespace> -o yaml
```

### Verify ClusterIssuer Health

```bash
kubectl get clusterissuer
kubectl describe clusterissuer letsencrypt-prod
```

### Troubleshooting

Check cert-manager logs:
```bash
kubectl logs -n infra deployment/cert-manager -f
```

Check certificate challenges:
```bash
kubectl get challenges -A
kubectl describe challenge <challenge-name> -n <namespace>
```

Force certificate renewal (for testing):
```bash
kubectl delete secret <cert-secret-name> -n <namespace>
# cert-manager will automatically recreate and renew
```

## Deployment Details

**Helm Chart:** `jetstack/cert-manager`
**Version:** As specified in deployment values
**Installation:** Story 3.3 implementation

**Components:**
- `cert-manager` controller - Main certificate management logic
- `cert-manager-webhook` - Validates Certificate and Issuer resources
- `cert-manager-cainjector` - Injects CA bundles into webhooks and API services

**CRDs Installed:**
- `Certificate` - Represents a TLS certificate request
- `ClusterIssuer` / `Issuer` - Defines certificate authority configuration
- `CertificateRequest` - Internal resource for certificate issuance workflow
- `Challenge` - Represents ACME challenge for domain validation

## Integration Points

**Traefik Ingress:**
- Traefik IngressRoute resources reference cert-manager-issued certificates
- Automatic TLS termination for all `*.home.jetzinger.com` services

**Grafana:** `https://grafana.home.jetzinger.com` (uses cert-manager certificate)

## Monitoring

**Certificate Expiration Metrics:**
cert-manager exposes Prometheus metrics at `:9402/metrics`:
- `certmanager_certificate_expiration_timestamp_seconds` - Certificate expiry time
- `certmanager_certificate_ready_status` - Certificate readiness (0 or 1)

**Alerting:**
Prometheus alert rules should monitor certificate expiration (configured in kube-prometheus-stack).

## Security Considerations

**Let's Encrypt Account Key:**
- Stored in Kubernetes Secret in `infra` namespace
- Automatically generated on first ClusterIssuer creation
- Should be backed up for account recovery

**DNS Provider Credentials:**
- NextDNS API token stored as Kubernetes Secret
- Used for DNS-01 challenge automation
- Scoped to minimal required permissions (DNS TXT record creation/deletion)

## References

- [cert-manager Documentation](https://cert-manager.io/docs/)
- [Let's Encrypt Rate Limits](https://letsencrypt.org/docs/rate-limits/)
- [Story 3.3 Implementation](../../docs/implementation-artifacts/3-3-deploy-cert-manager-with-lets-encrypt.md)
- [ADR-003: Traefik Ingress Selection](../../docs/adrs/ADR-003-traefik-ingress.md)
