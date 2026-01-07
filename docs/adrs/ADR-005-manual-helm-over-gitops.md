# ADR-005: Manual Helm Deployment over GitOps (Phase 1)

**Status:** Accepted
**Date:** 2026-01-07
**Decision Makers:** Tom, Claude (AI Assistant)

## Context

The home-lab K3s cluster requires a deployment methodology for infrastructure components (cert-manager, MetalLB, NFS provisioner) and applications (PostgreSQL, Ollama, n8n, Grafana). The deployment approach must balance learning goals, operational complexity, and portfolio demonstration value.

Project constraints:
- **Single operator** (Tom) managing the cluster
- **Weekend-based phased implementation** (limited time windows)
- **Learning-first goals** - Operational experience valued over automation
- **Phase 1 scope** - Foundation setup, 8 epics, ~40 stories
- **Portfolio context** - Demonstrating understanding before adding abstraction layers

The decision impacts:
- How infrastructure components are deployed and upgraded
- Configuration management (values files, secrets)
- Rollback procedures and disaster recovery
- Migration path to automation (Phase 2+)

## Decision Drivers

- **Learning value** - Manual operations build deeper understanding before automation
- **Operational experience** - Hands-on kubectl/helm troubleshooting is career-relevant
- **Timeline constraints** - Weekend implementation favors simpler workflows
- **Debugging complexity** - Direct deployments easier to troubleshoot than GitOps reconciliation
- **Phase 1 focus** - Get cluster operational, defer optimization to Phase 2
- **Portfolio narrative** - "I learned foundational operations, then added GitOps" is stronger than "I started with GitOps"

## Considered Options

### Option 1: Manual Helm Deployment (Phase 1) - Selected

**Approach:**
- Store Helm values files in Git (`values-homelab.yaml` per chart)
- Deploy via `helm upgrade --install` from local machine
- Store raw manifests (ConfigMaps, Ingress) in Git
- Apply via `kubectl apply -f` from local machine
- Document deployment commands in component READMEs

**Pros:**
- **Maximum learning** - Direct exposure to Helm charts, kubectl commands, K8s API
- **Simple troubleshooting** - No reconciliation loops, direct cause/effect
- **Fast iteration** - Change values file → `helm upgrade` → immediate feedback
- **No additional infrastructure** - No ArgoCD/Flux installation required
- **Clear debugging** - `helm status`, `kubectl describe` show exact state
- **Flexible rollbacks** - `helm rollback` to any previous release

**Cons:**
- **Manual drift risk** - Imperative changes (via kubectl edit) not captured in Git
- **No automatic sync** - Git changes don't auto-deploy to cluster
- **Operator dependency** - Requires human to run deployment commands
- **Harder auditing** - Must check `helm list` + `kubectl get` to verify deployed state
- **Inconsistent state possible** - Git repo may diverge from cluster reality

### Option 2: GitOps from Start (ArgoCD or Flux)

**Approach:**
- Install ArgoCD or Flux as first component
- Define all infrastructure/apps as Application manifests
- Git push → GitOps controller auto-syncs to cluster
- Continuous reconciliation (every 3 minutes)
- Self-healing (auto-corrects drift)

**Pros:**
- **Automatic sync** - Git push → cluster automatically updated
- **Drift prevention** - Manual kubectl changes auto-reverted
- **Audit trail** - Git history = deployment history
- **Declarative state** - Cluster state always matches Git
- **Production pattern** - Used in enterprise K8s environments

**Cons:**
- **Abstraction layer** - Hides Helm/kubectl operations behind controller
- **Debugging complexity** - Must understand reconciliation loops, sync waves, health checks
- **Initial setup overhead** - ArgoCD requires installation, RBAC, Ingress, SSO configuration
- **Learning curve** - CRDs (Application, ApplicationSet), sync policies, hooks
- **Harder troubleshooting** - "Why isn't my change deploying?" requires ArgoCD debugging

### Option 3: Pure kubectl apply (No Helm)

**Approach:**
- Write raw YAML manifests for all components
- Store in Git, apply via `kubectl apply -k` (Kustomize)
- No Helm charts, no templating

**Pros:**
- Simple, direct Kubernetes manifests
- No Helm abstraction layer
- Easy to understand exact resources deployed

**Cons:**
- **No package management** - Manually maintain PostgreSQL, Prometheus, cert-manager manifests
- **Version tracking nightmare** - Must manually update 100+ YAML lines for version bumps
- **No community charts** - Can't leverage prometheus-community, bitnami, etc.
- **Reinventing the wheel** - Writing manifests that Helm charts already provide

### Option 4: Terraform/Pulumi (Infrastructure as Code)

**Approach:**
- Define Kubernetes resources in Terraform HCL or Pulumi code
- Apply via `terraform apply` or `pulumi up`
- State stored in backend (S3, local file)

**Pros:**
- State management built-in
- Plan/preview before apply
- Good for multi-cloud infrastructure

**Cons:**
- **Different toolchain** - Not K8s-native (learning Terraform vs Kubernetes)
- **Helm provider complexity** - Terraform wrapping Helm adds indirection
- **State management overhead** - Requires backend configuration, locking
- **Not aligned with learning goals** - Terraform valuable but distinct from K8s operations

## Decision

**Phase 1: Manual Helm + kubectl (Learning-First Approach)**

Implementation pattern:
1. **Helm for packaged applications:**
   - Store `values-homelab.yaml` in Git for each chart
   - Deploy: `helm upgrade --install {name} {chart} -f values-homelab.yaml -n {namespace}`
   - Version control values files only (not full Helm releases)

2. **kubectl apply for custom manifests:**
   - Store raw YAML (Ingress, ConfigMap, custom deployments) in Git
   - Deploy: `kubectl apply -f {manifest}.yaml`

3. **Documentation:**
   - Each component directory contains README.md with deployment commands
   - Runbooks document upgrade procedures

4. **Drift mitigation:**
   - Commit any manual changes back to Git after troubleshooting
   - Weekly audit: `helm list -A` + `kubectl get all -A` vs Git state

5. **Future migration path:**
   - Phase 2: Add ArgoCD, convert to GitOps incrementally
   - Existing values files and manifests become ArgoCD Application sources

## Consequences

### Positive

- **Deep learning** - Forced exposure to Helm internals, kubectl operations
- **Fast feedback loops** - Immediate deployment results, no reconciliation wait
- **Simple troubleshooting** - Direct correlation: command → result
- **Flexible experimentation** - Easy to test changes without GitOps abstractions
- **Operational confidence** - Understanding manual process before automating
- **Portfolio narrative** - Demonstrates foundational skills before advanced patterns
- **Phase 2 readiness** - Manual experience makes GitOps adoption intentional, not cargo-cult

### Negative

- **Manual drift risk** - Ad-hoc kubectl changes may not make it back to Git
- **No automatic rollback** - Must manually `helm rollback` on issues
- **Deployment dependency** - Requires operator to run commands (no auto-sync)
- **State verification burden** - Must manually check Git vs cluster consistency
- **Harder multi-environment** - No easy way to sync dev/staging/prod (single cluster mitigates this)

### Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Git diverges from cluster (drift) | Weekly audit: compare `helm list` output to Git values files; document drift resolution in runbooks |
| Accidental kubectl changes lost | Rule: Always commit manual changes to Git immediately after troubleshooting |
| Difficult rollbacks | Helm automatic revision history (`helm rollback`); Git history provides values file rollback |
| Secrets in Git (security risk) | Use Kubernetes native secrets (K3s encrypts at rest); plan Sealed Secrets for Phase 2 GitOps |
| Deployment process not documented | Each component README.md contains exact deployment commands; scripts/ directory provides automation helpers |

## Implementation Notes

**Repository Structure:**
```
home-lab/
├── infrastructure/
│   ├── nfs/
│   │   ├── values-homelab.yaml
│   │   └── README.md  # Deployment: helm upgrade --install nfs-provisioner...
│   ├── cert-manager/
│   │   ├── values-homelab.yaml
│   │   ├── cluster-issuer.yaml
│   │   └── README.md
├── applications/
│   ├── postgres/
│   │   ├── values-homelab.yaml
│   │   └── README.md
└── scripts/
    ├── deploy-all.sh  # Full stack deployment script (idempotent)
    └── verify-state.sh  # Compare Git vs cluster state
```

**Example Deployment Workflow:**
```bash
# 1. Update values file
vim infrastructure/cert-manager/values-homelab.yaml

# 2. Deploy/upgrade
helm upgrade --install cert-manager jetstack/cert-manager \
  -f infrastructure/cert-manager/values-homelab.yaml \
  -n infra --create-namespace

# 3. Verify
kubectl get pods -n infra
kubectl get certificates -A

# 4. Commit to Git
git add infrastructure/cert-manager/values-homelab.yaml
git commit -m "Configure cert-manager with Let's Encrypt"
git push
```

**Drift Detection (Weekly Audit):**
```bash
# Check Helm releases
helm list -A > /tmp/helm-state.txt
git diff /tmp/helm-state.txt docs/helm-state-expected.txt

# Check for untracked resources
kubectl get all -A --show-labels | grep -v "app.kubernetes.io/managed-by=helm"
```

**Phase 2 GitOps Migration Path:**
1. Install ArgoCD in `gitops` namespace
2. Create Application manifest for one component (e.g., cert-manager)
3. Let ArgoCD sync from existing Git values files
4. Validate ArgoCD manages component correctly
5. Migrate remaining components incrementally
6. Decommission manual deployment scripts

## References

- [Architecture Decision: Infrastructure Management Approach](../planning-artifacts/architecture.md#infrastructure-management-approach)
- [Project Structure: Repository Organization](../planning-artifacts/architecture.md#repository-organization)
- [Helm Best Practices](https://helm.sh/docs/chart_best_practices/)
- [ArgoCD Documentation (Phase 2 Reference)](https://argo-cd.readthedocs.io/)
- [Story 8.2: Setup Cluster State Backup](../implementation-artifacts/sprint-status.yaml)
