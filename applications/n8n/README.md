# n8n Workflow Automation

**Story**: 6.3 - Deploy n8n for Workflow Automation
**Epic**: 6 - AI Inference Platform
**Status**: Deployed ✅

## Overview

n8n is a workflow automation platform deployed to enable automated workflows that leverage cluster services, particularly Ollama for LLM inference.

**Functional Requirements Validated:**
- ✅ FR8: Deploy applications using Helm charts
- ✅ FR40: Deploy n8n for workflow automation

**Non-Functional Requirements:**
- ✅ NFR7: All ingress traffic uses TLS 1.2+ with valid certificates (Let's Encrypt)
- ✅ NFR8: Workflow data persists across pod restarts (NFS-backed PVC)

## Deployment Details

### Chart Information

- **Helm Repository**: `community-charts` (https://community-charts.github.io/helm-charts)
- **Chart**: `community-charts/n8n`
- **Chart Version**: v1.16.16
- **Application Version**: v2.2.3
- **Namespace**: `apps`
- **Release Name**: `n8n`

### Infrastructure Components

**Deployment**:
- Type: Deployment (1 replica, Recreate strategy)
- Pod: `n8n-859554bc7d-hvt25` running on `k3s-worker-02`
- Image: `n8nio/n8n:2.2.3`

**Service**:
- Name: `n8n`
- Type: ClusterIP
- Port: 5678 (HTTP)
- Internal DNS: `n8n.apps.svc.cluster.local:5678`

**Storage**:
- PVC: `n8n-main-persistence` (10Gi, ReadWriteOnce)
- StorageClass: `nfs-client` (NFS provisioner)
- Mount Path: `/home/node/.n8n`
- Backend: Synology NFS storage
- Status: Bound ✅

**Database**:
- Type: PostgreSQL (external)
- Host: `postgres-postgresql.data` (internal cluster DNS)
- Port: 5432
- Database: `n8n`
- User: `n8n`
- Schema: `public`
- Connection Status: ✅ Migrations completed successfully

**Ingress**:
- URL: https://n8n.home.jetzinger.com
- Type: Traefik IngressRoute
- TLS: Let's Encrypt (cert-manager)
- Certificate: `n8n-tls` (Ready ✅, 90-day duration)
- HTTP→HTTPS Redirect: Enabled
- Access: Tailscale VPN only

**Resource Allocation**:
```yaml
requests:
  cpu: 250m
  memory: 512Mi
limits:
  cpu: 2000m
  memory: 2Gi
```

**Security Context**:
- runAsUser: 1000
- runAsGroup: 1000
- fsGroup: 1000
- allowPrivilegeEscalation: false
- Capabilities: ALL dropped
- readOnlyRootFilesystem: false (required for workflow execution)

## Access Information

### Web Interface

**URL**: https://n8n.home.jetzinger.com

**Initial Setup** (⚠️ User Action Required):
1. Navigate to https://n8n.home.jetzinger.com
2. Complete the setup wizard:
   - Create admin account (email/password)
   - Configure workspace name
   - Optional: Set up telemetry preferences
3. Log in to the n8n dashboard

### API Access

**Base URL**: `https://n8n.home.jetzinger.com/api/v1`

API access requires authentication token (obtained from UI after initial setup).

## Configuration

### Environment Variables

**Protocol & Host**:
- `N8N_PROTOCOL=https`
- `N8N_HOST=n8n.home.jetzinger.com`
- `N8N_PORT=5678`
- `WEBHOOK_URL=https://n8n.home.jetzinger.com/`

**Database**:
- `DB_TYPE=postgresdb`
- `DB_POSTGRESDB_HOST=postgres-postgresql.data`
- `DB_POSTGRESDB_PORT=5432`
- `DB_POSTGRESDB_DATABASE=n8n`
- `DB_POSTGRESDB_USER=n8n`
- `DB_POSTGRESDB_SCHEMA=public`

**Execution**:
- `EXECUTIONS_PROCESS=main` (deprecated, can be removed)
- `EXECUTIONS_MODE=regular`
- `EXECUTIONS_DATA_PRUNE=true`
- `EXECUTIONS_DATA_MAX_AGE=336` (14 days)

**General**:
- `GENERIC_TIMEZONE=America/New_York`
- `N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}`

## Helm Deployment Commands

### Initial Deployment

```bash
# Add Helm repository
helm repo add community-charts https://community-charts.github.io/helm-charts
helm repo update

# Deploy n8n
helm upgrade --install n8n community-charts/n8n \
  -f applications/n8n/values-homelab.yaml \
  -n apps

# Apply ingress configuration
kubectl apply -f applications/n8n/ingress.yaml
```

### Upgrade Deployment

```bash
# Update Helm values and upgrade
helm upgrade n8n community-charts/n8n \
  -f applications/n8n/values-homelab.yaml \
  -n apps
```

### Uninstall

```bash
# Remove Helm release
helm uninstall n8n -n apps

# Remove ingress resources
kubectl delete -f applications/n8n/ingress.yaml

# Optional: Delete PVC (data will be lost)
kubectl delete pvc n8n-main-persistence -n apps
```

## Validation Steps

### Deployment Validation

```bash
# Check pod status
kubectl get pods -n apps -l app.kubernetes.io/name=n8n

# Expected: 1/1 Running, 0 restarts
# NAME                   READY   STATUS    RESTARTS   AGE
# n8n-859554bc7d-hvt25   1/1     Running   0          5m

# Check PVC status
kubectl get pvc -n apps n8n-main-persistence

# Expected: Bound
# NAME                   STATUS   VOLUME                                     CAPACITY
# n8n-main-persistence   Bound    pvc-xxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx     10Gi

# Check certificate status
kubectl get certificate -n apps n8n-tls

# Expected: READY = True
# NAME      READY   SECRET    AGE
# n8n-tls   True    n8n-tls   5m
```

### HTTPS Access Validation

```bash
# Test HTTPS endpoint
curl -I https://n8n.home.jetzinger.com

# Expected: HTTP/2 200 OK
```

### Database Connection Validation

```bash
# Check n8n logs for successful migration
kubectl logs -n apps -l app.kubernetes.io/name=n8n --tail=50

# Expected: "Editor is now accessible via: https://n8n.home.jetzinger.com"
```

### DNS Resolution Validation

```bash
# Test DNS resolution from cluster
kubectl run -n apps dnsutils --image=gcr.io/kubernetes-e2e-test-images/dnsutils:1.3 \
  --restart=Never --rm -i -- nslookup postgres-postgresql.data

# Expected: Resolves to PostgreSQL service IP
```

## Integration with Ollama

### Internal Ollama Access (Recommended)

For workflows running within the cluster, use the internal Ollama service:

**Endpoint**: `http://ollama.ml.svc.cluster.local:11434`

**Example HTTP Request Node Configuration**:
```json
{
  "method": "POST",
  "url": "http://ollama.ml.svc.cluster.local:11434/api/generate",
  "body": {
    "model": "llama3.2:1b",
    "prompt": "Your prompt here",
    "stream": false
  }
}
```

### External Ollama Access (Webhooks)

For webhook URLs that need external access:

**Endpoint**: `https://ollama.home.jetzinger.com/api/generate`

Note: External access requires Tailscale VPN connection.

## Next Steps (User Actions Required)

### Task 6: Configure n8n Initial Setup

⚠️ **Manual Action Required**:

1. Open browser and navigate to: https://n8n.home.jetzinger.com
2. Complete setup wizard:
   - Create admin account
   - Configure workspace settings
3. Verify PostgreSQL connection in Settings → Database
4. Test workflow data persistence by restarting the pod:
   ```bash
   kubectl delete pod -n apps -l app.kubernetes.io/name=n8n
   # Wait for pod to restart, verify workflow still exists
   ```

### Task 7: Create Test Workflow with Ollama Integration

⚠️ **Manual Action Required**:

1. Log in to n8n UI
2. Create new workflow
3. Add HTTP Request node:
   - Method: POST
   - URL: `http://ollama.ml.svc.cluster.local:11434/api/generate`
   - Body (JSON):
     ```json
     {
       "model": "llama3.2:1b",
       "prompt": "Hello, how are you?",
       "stream": false
     }
     ```
4. Add Set node to parse and display Ollama response
5. Execute workflow
6. Verify Ollama response is captured successfully
7. Save workflow to confirm persistence

**Expected Result**: Workflow executes successfully, Ollama returns generated text, workflow persists after pod restart.

## Troubleshooting

### Pod Crashes on Startup

**Symptom**: Pod in CrashLoopBackOff state
**Common Cause**: DNS resolution failure for PostgreSQL

**Solution**:
```bash
# Check pod logs
kubectl logs -n apps -l app.kubernetes.io/name=n8n

# If you see "getaddrinfo ENOTFOUND postgres-postgresql.data.svc.cluster.local"
# Use shorter DNS name in values-homelab.yaml:
# externalPostgresql.host: postgres-postgresql.data  (not .svc.cluster.local)

# Upgrade deployment
helm upgrade n8n community-charts/n8n -f applications/n8n/values-homelab.yaml -n apps
```

### Certificate Not Provisioning

**Symptom**: Certificate stuck in "Issuing" state

**Solution**:
```bash
# Check certificate status
kubectl describe certificate -n apps n8n-tls

# Check ACME challenge status
kubectl get challenge,order -n apps

# Verify cert-manager is running
kubectl get pods -n infra -l app.kubernetes.io/name=cert-manager

# Check cert-manager logs
kubectl logs -n infra -l app.kubernetes.io/name=cert-manager --tail=50
```

### n8n UI Not Accessible

**Symptom**: Cannot access https://n8n.home.jetzinger.com

**Solution**:
```bash
# Verify ingress route
kubectl get ingressroute -n apps

# Check Traefik logs
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik --tail=50

# Verify service endpoints
kubectl get endpoints -n apps n8n

# Test internal service access
kubectl run -n apps curl --image=curlimages/curl --rm -i -- \
  curl http://n8n.apps.svc.cluster.local:5678
```

### Database Connection Issues

**Symptom**: n8n fails to connect to PostgreSQL

**Solution**:
```bash
# Verify PostgreSQL service exists
kubectl get svc -n data postgres-postgresql

# Test DNS resolution
kubectl run -n apps dnsutils --image=gcr.io/kubernetes-e2e-test-images/dnsutils:1.3 \
  --restart=Never --rm -i -- nslookup postgres-postgresql.data

# Verify database and user exist
kubectl exec -n data postgres-postgresql-0 -- env PGPASSWORD=${POSTGRES_PASSWORD} \
  psql -U postgres -c "\l" | grep n8n

kubectl exec -n data postgres-postgresql-0 -- env PGPASSWORD=${POSTGRES_PASSWORD} \
  psql -U postgres -c "\du" | grep n8n
```

### Ollama Integration Not Working

**Symptom**: HTTP Request node fails to reach Ollama

**Solution**:
```bash
# Verify Ollama is running
kubectl get pods -n ml -l app.kubernetes.io/name=ollama

# Test Ollama API from n8n pod
kubectl exec -n apps -l app.kubernetes.io/name=n8n -- \
  curl http://ollama.ml.svc.cluster.local:11434/api/tags

# Check if model is loaded
kubectl exec -n ml -l app.kubernetes.io/name=ollama -- \
  ollama list
```

## Deprecation Warnings

### EXECUTIONS_PROCESS Environment Variable

**Warning**: `EXECUTIONS_PROCESS` is deprecated and no longer needed.

**Action**: Remove from `extraEnvVars` in `values-homelab.yaml` in future updates.

**Impact**: None - warning only, functionality not affected.

### Python Task Runner

**Notice**: Python 3 is missing from the n8n container image.

**Impact**: Python-based task runners not available. JavaScript task runner is functional.

**Action**: Deploy external Python task runner if Python workflows are needed (see n8n docs).

## Performance Notes

**Database Migrations**: Initial startup includes running PostgreSQL database migrations (30+ migrations). This is normal and only occurs on first deployment or after n8n upgrades.

**Resource Usage**: Current allocation is conservative (250m/512Mi requests). Monitor actual usage in Grafana and adjust if needed.

**Response Time**: n8n UI response time depends on workflow complexity and external service calls (e.g., Ollama inference time).

## Related Documentation

- [Epic 6: AI Inference Platform](../../docs/planning-artifacts/epics.md#Epic-6)
- [Story 6.3: Deploy n8n](../../docs/implementation-artifacts/6-3-deploy-n8n-for-workflow-automation.md)
- [PostgreSQL Deployment](../postgres/README.md)
- [Ollama Deployment](../ollama/README.md)
- [Architecture Decision: External PostgreSQL](../../docs/planning-artifacts/architecture.md)

## Maintenance

### Backup

Workflow data is stored in:
1. **PostgreSQL database** (`n8n` database) - backed up via PostgreSQL backup procedures (see postgres/README.md)
2. **NFS persistent volume** (`/home/node/.n8n`) - backed up via Synology snapshot schedule

No additional n8n-specific backup required.

### Upgrades

To upgrade n8n to a newer version:

```bash
# Update Helm repository
helm repo update

# Check available versions
helm search repo community-charts/n8n --versions

# Upgrade to specific version
helm upgrade n8n community-charts/n8n \
  --version <new-version> \
  -f applications/n8n/values-homelab.yaml \
  -n apps

# Verify upgrade
kubectl rollout status deployment/n8n -n apps
kubectl logs -n apps -l app.kubernetes.io/name=n8n --tail=50
```

**Note**: Check n8n release notes for breaking changes before upgrading.

### Monitoring

n8n metrics are available in Grafana dashboards:
- Pod CPU/Memory usage
- Database connection metrics (via PostgreSQL monitoring)
- Ingress traffic metrics (via Traefik)

## Security Considerations

**Secrets Management**:
- Database password stored in Helm values (plaintext) - consider using Kubernetes Secrets or external secret management for production
- Encryption key stored in Helm values - rotate periodically
- TLS certificate auto-renewed by cert-manager

**Network Security**:
- External access restricted to Tailscale VPN
- Internal service uses ClusterIP (not exposed externally)
- HTTPS enforced via redirect middleware

**Authentication**:
- Admin account created during initial setup
- Support for SSO/OAuth (configure via n8n UI)
- API authentication via tokens

---

**Deployment Date**: 2026-01-06
**Last Updated**: 2026-01-06
**Status**: ✅ Deployed and operational (Tasks 6-7 require user action)
