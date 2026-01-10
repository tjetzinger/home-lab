# Story 11.5: Configure NetworkPolicy for Container Isolation

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **platform engineer**,
I want **dev containers isolated via NetworkPolicy**,
so that **containers cannot communicate directly and are only accessible via Nginx proxy**.

## Acceptance Criteria

1. **Given** dev containers are running
   **When** I create NetworkPolicy for `dev` namespace
   **Then** the policy defines ingress rules:
   - Allow SSH (port 22) from nginx-proxy pods only
   - Deny all other ingress from dev-container pods
   **And** validates FR70 (Dev containers isolated via NetworkPolicy)

2. **Given** NetworkPolicy ingress is configured
   **When** I define egress rules
   **Then** the policy allows:
   - DNS resolution (kube-system namespace, port 53 UDP/TCP)
   - PostgreSQL access (data namespace, port 5432)
   - Ollama access (ml namespace, port 11434)
   - n8n access (apps namespace, port 5678)
   **And** blocks all other egress by default

3. **Given** NetworkPolicy is applied
   **When** I test connectivity from Belego container
   **Then** the container can:
   - Resolve DNS names (kube-dns)
   - Connect to PostgreSQL at `postgresql.data.svc.cluster.local:5432`
   - Connect to Ollama at `ollama.ml.svc.cluster.local:11434`
   **And** this validates NFR33 (NetworkPolicy isolation)

4. **Given** NetworkPolicy is enforced
   **When** I test blocked connectivity
   **Then** the container cannot:
   - Connect to other dev containers directly (SSH blocked between containers)
   - Reach arbitrary external endpoints without explicit egress rule

5. **Given** isolation is verified
   **When** I confirm access via Nginx proxy
   **Then** SSH connections work via LoadBalancer IP 192.168.2.101:
   - Port 2222 → Belego dev container
   - Port 2223 → Pilates dev container
   **And** validates continued functionality after NetworkPolicy applied

## Tasks / Subtasks

⚠️ **DRAFT TASKS** - Generated from requirements analysis. Will be validated and refined against actual codebase when dev-story runs.

- [x] **Task 1:** Create namespace labels for selector targeting (AC: 1, 2)
  - [x] Label `data` namespace: `name: data`
  - [x] Label `ml` namespace: `name: ml`
  - [x] Label `apps` namespace: `name: apps`
  - [x] Label `kube-system` namespace: `name: kube-system`
  - [x] Verify labels applied: `kubectl get ns --show-labels`

- [x] **Task 2:** Create NetworkPolicy manifest for dev containers (AC: 1, 2)
  - [x] Create `applications/dev-containers/networkpolicy.yaml`
  - [x] Define podSelector for dev-container pods
  - [x] Configure ingress: Allow SSH (22) from nginx-proxy pods only
  - [x] Configure egress: Allow DNS (53), PostgreSQL (5432), Ollama (11434), n8n (5678)
  - [x] Set policyTypes: [Ingress, Egress]

- [x] **Task 3:** Apply NetworkPolicy and verify (AC: 1, 2)
  - [x] Apply manifest: `kubectl apply -f networkpolicy.yaml`
  - [x] Verify policy created: `kubectl get networkpolicy -n dev`
  - [x] Describe policy to confirm rules: `kubectl describe networkpolicy -n dev`

- [x] **Task 4:** Test allowed connectivity (AC: 3)
  - [x] Test DNS resolution from dev container (kubernetes.default resolves)
  - [x] Test PostgreSQL connectivity: `postgres-postgresql.data.svc.cluster.local:5432` - SUCCESS
  - [x] Test Ollama connectivity: `ollama.ml.svc.cluster.local:11434` - SUCCESS
  - [x] Document successful connections (Python socket tests)

- [x] **Task 5:** Test blocked connectivity (AC: 4)
  - [x] Test inter-container SSH blocked: Belego → Pilates (10.42.0.36:22) - BLOCKED (Connection refused)
  - [x] Verify blocked external connections: google.com:80 - BLOCKED (Connection refused)
  - [x] Document blocked connections (Python socket tests)

- [x] **Task 6:** Verify SSH access via Nginx proxy still works (AC: 5)
  - [x] Test SSH to Belego: `ssh -p 2222 dev@192.168.2.101` - SUCCESS
  - [x] Test SSH to Pilates: `ssh -p 2223 dev@192.168.2.101` - SUCCESS
  - [x] SSH via Nginx proxy verified working with NetworkPolicy in place

- [x] **Task 7:** Documentation and sprint status update
  - [x] Update dev-containers README with NetworkPolicy section
  - [x] Update story file with completion notes
  - [x] Update sprint-status.yaml to mark story done

## Gap Analysis

**Scan Date:** 2026-01-10

### What Exists:
| Item | Location | Status |
|------|----------|--------|
| Dev container deployments | `applications/dev-containers/dev-container-*.yaml` | Operational with correct labels |
| Pod labels | `app.kubernetes.io/name: dev-container` | Ready for NetworkPolicy podSelector |
| Nginx proxy labels | `app.kubernetes.io/name: nginx` | Ready for ingress allowlist |
| Namespaces | `data`, `ml`, `apps`, `kube-system` | All exist |
| Namespace base labels | `kubernetes.io/metadata.name=<ns>` | Auto-applied by K8s |
| No existing NetworkPolicy | `dev` namespace | Clean slate |

### What's Missing:
| Item | Required Action |
|------|-----------------|
| `name: data` label on namespace | Need to add for namespaceSelector |
| `name: ml` label on namespace | Need to add for namespaceSelector |
| `name: apps` label on namespace | Need to add for namespaceSelector |
| `name: kube-system` label on namespace | Need to add for namespaceSelector |
| `networkpolicy.yaml` | Need to create |

### Task Changes Applied:
- NO CHANGES - Draft tasks accurately reflect current codebase state

---

## Dev Notes

### Architecture Requirements

**Dev Containers Architecture:** [Source: docs/planning-artifacts/architecture.md#Dev Containers Architecture]
- NetworkPolicy: Moderate isolation (access cluster services, no cross-container communication)
- FR70: Dev containers isolated via NetworkPolicy (accessible only via nginx proxy)
- NFR33: Dev containers isolated via NetworkPolicy (no cross-container communication)

### Technical Constraints

**NetworkPolicy Requirements:**
- K3s uses Flannel CNI by default, which supports NetworkPolicy
- NetworkPolicy is namespace-scoped
- Both Ingress and Egress policies must be defined
- Namespace selectors require labels on target namespaces

**Current Dev Container Labels (from Story 11.2):**
```yaml
labels:
  app.kubernetes.io/name: dev-container
  app.kubernetes.io/instance: dev-container-belego  # or dev-container-pilates
  app.kubernetes.io/part-of: home-lab
```

**Nginx Proxy Labels (from Story 7.1):**
```yaml
labels:
  app.kubernetes.io/name: nginx
  app.kubernetes.io/instance: nginx-proxy
```

### Previous Story Intelligence

**From Story 11.4:**
- SSH access verified working via LoadBalancer IP 192.168.2.101
- Ports: 2222 (Belego), 2223 (Pilates)
- nginx-proxy routes SSH traffic via stream module
- Key learning: nginx stream uses runtime DNS resolution via map directive

**From Story 11.2:**
- Dev containers deployed as Deployments in `dev` namespace
- Services: `dev-container-belego-svc`, `dev-container-pilates-svc`
- Containers running on worker nodes

### NetworkPolicy Template

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: dev-container-isolation
  namespace: dev
  labels:
    app.kubernetes.io/part-of: home-lab
    app.kubernetes.io/managed-by: kubectl
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: dev-container
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app.kubernetes.io/name: nginx
    ports:
    - protocol: TCP
      port: 22
  egress:
  # DNS
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
  # PostgreSQL
  - to:
    - namespaceSelector:
        matchLabels:
          name: data
    ports:
    - protocol: TCP
      port: 5432
  # Ollama
  - to:
    - namespaceSelector:
        matchLabels:
          name: ml
    ports:
    - protocol: TCP
      port: 11434
  # n8n (optional)
  - to:
    - namespaceSelector:
        matchLabels:
          name: apps
    ports:
    - protocol: TCP
      port: 5678
```

### Testing Commands

```bash
# Verify namespace labels
kubectl get ns --show-labels

# Apply NetworkPolicy
kubectl apply -f applications/dev-containers/networkpolicy.yaml

# Verify policy
kubectl get networkpolicy -n dev
kubectl describe networkpolicy dev-container-isolation -n dev

# Test from inside dev container
kubectl exec -it deployment/dev-container-belego -n dev -- /bin/bash

# Inside container:
# Test DNS
nslookup postgresql.data.svc.cluster.local

# Test PostgreSQL
nc -zv postgresql.data.svc.cluster.local 5432

# Test Ollama
nc -zv ollama.ml.svc.cluster.local 11434

# Test blocked: Try to ping other dev container
ping <pilates-pod-ip>  # Should fail/timeout
```

### Project Structure Notes

**Directory:** `applications/dev-containers/`
- `dev-container-belego.yaml` - Belego deployment
- `dev-container-pilates.yaml` - Pilates deployment
- `dev-container-template.yaml` - Template for new containers
- `networkpolicy.yaml` - **TO BE CREATED** - Container isolation policy

### References

- [Epic 11: Dev Containers Platform](../planning-artifacts/epics.md#epic-11)
- [Story 11.4: Configure Nginx SSH Proxy](./11-4-configure-nginx-ssh-proxy-with-custom-domains.md)
- [FR70: Dev containers isolated via NetworkPolicy](../planning-artifacts/prd.md)
- [NFR33: NetworkPolicy isolation](../planning-artifacts/prd.md)
- [Architecture: Dev Containers](../planning-artifacts/architecture.md#dev-containers-architecture)

---

## Dev Agent Record

### Completion Date
2026-01-10

### Files Created/Modified

| File | Action | Description |
|------|--------|-------------|
| `applications/dev-containers/networkpolicy.yaml` | Created | NetworkPolicy for container isolation |
| `applications/dev-containers/README.md` | Modified | Added NetworkPolicy isolation section |

### Namespace Labels Applied

```bash
kubectl label namespace data name=data
kubectl label namespace ml name=ml
kubectl label namespace apps name=apps
kubectl label namespace kube-system name=kube-system
```

### Test Results

**Allowed Connectivity (AC: 3):**
- DNS resolution: ✅ kubernetes.default resolves
- PostgreSQL (`postgres-postgresql.data.svc.cluster.local:5432`): ✅ SUCCESS
- Ollama (`ollama.ml.svc.cluster.local:11434`): ✅ SUCCESS

**Blocked Connectivity (AC: 4):**
- Inter-container SSH (Belego → Pilates 10.42.0.36:22): ✅ BLOCKED (Connection refused)
- External internet (google.com:80): ✅ BLOCKED (Connection refused)

**SSH via Nginx Proxy (AC: 5):**
- `ssh -p 2222 dev@192.168.2.101`: ✅ SUCCESS
- `ssh -p 2223 dev@192.168.2.101`: ✅ SUCCESS

### Key Learnings

1. **Namespace labels for selectors**: NetworkPolicy `namespaceSelector` requires explicit labels. While Kubernetes auto-applies `kubernetes.io/metadata.name`, using explicit `name:` labels is cleaner.

2. **Testing without netcat**: Dev containers may not have `nc` or `nslookup` installed. Python's `socket` module works as a reliable alternative for connectivity tests.

3. **External internet blocked by default**: Once egress rules are defined, all non-matching traffic is blocked - including apt-get updates and external APIs.

### Verification Commands

```bash
# Check NetworkPolicy
kubectl get networkpolicy -n dev
kubectl describe networkpolicy dev-container-isolation -n dev

# Test connectivity from dev container
kubectl exec deployment/dev-container-belego -n dev -- python3 -c "
import socket
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.settimeout(5)
s.connect(('postgres-postgresql.data.svc.cluster.local', 5432))
print('PostgreSQL: SUCCESS')
"
```
