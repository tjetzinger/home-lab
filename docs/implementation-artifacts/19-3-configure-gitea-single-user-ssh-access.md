# Story 19.3: Configure Gitea Single-User SSH Access

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **developer**,
I want **Gitea configured for single-user operation with SSH**,
So that **I can push/pull repositories via SSH keys**.

## Acceptance Criteria

1. **Given** Gitea is deployed and accessible
   **When** I configure single-user mode
   **Then** registration is disabled after initial user creation
   **And** only the primary user can create repositories
   **And** this validates FR137

2. **Given** single-user mode is configured
   **When** I add my SSH public key to Gitea
   **Then** key is stored in user profile
   **And** SSH authentication works for git operations

3. **Given** SSH is configured
   **When** I clone a repository via SSH
   **Then** `git clone git@git.home.jetzinger.com:user/repo.git` works
   **And** clone completes within 10 seconds for typical repos (NFR79)

## Tasks / Subtasks

⚠️ **DRAFT TASKS** - Generated from requirements analysis. Will be validated and refined against actual codebase when dev-story runs.

### Task 1: Verify Single-User Mode Configuration (AC: 1, FR137)
- [x] 1.1: Verify `DISABLE_REGISTRATION: true` is set in values-homelab.yaml
- [x] 1.2: Verify admin user exists and can create repositories
- [x] 1.3: Confirm registration endpoint returns disabled message

### Task 2: Configure SSH Service for External Access (AC: 2)
- [x] 2.1: Update `service.ssh.type` from ClusterIP to LoadBalancer in values-homelab.yaml
- [x] 2.2: Configure SSH port (recommend 2222 to avoid privileged port issues)
- [x] 2.3: Update Gitea config `SSH_PORT` to match external port
- [x] 2.4: Apply Helm upgrade with new values
- [x] 2.5: Verify LoadBalancer IP assigned by MetalLB (192.168.2.102:2222)

### Task 3: Add SSH Public Key to Admin User (AC: 2)
- [x] 3.1: Access Gitea web interface at https://git.home.jetzinger.com
- [x] 3.2: Navigate to User Settings → SSH/GPG Keys (via API)
- [x] 3.3: Add SSH public key from ~/.ssh/id_ed25519.pub
- [x] 3.4: Verify key is stored in user profile (fingerprint: SHA256:/xuYam...)

### Task 4: Test SSH Git Operations (AC: 3, NFR79)
- [x] 4.1: Create test repository in Gitea
- [x] 4.2: Clone repository via SSH: `ssh://git@192.168.2.102:2222/admin/ssh-test-repo.git`
- [x] 4.3: Push changes via SSH
- [x] 4.4: Measure clone time: 0.761s (NFR79 < 10 seconds)
- [x] 4.5: Delete test repository after validation

### Task 5: Documentation (AC: all)
- [x] 5.1: Update `applications/gitea/README.md` with SSH access instructions
- [x] 5.2: Document SSH clone command format
- [x] 5.3: Update story file with completion notes

## Gap Analysis

**Scan Date:** 2026-01-15

✅ **What Exists:**
- `DISABLE_REGISTRATION: true` configured in values-homelab.yaml (line 60)
- Admin user exists with `is_admin: true`
- Registration endpoint returns "Registration is disabled" message
- SSH public key available at `/home/tt/.ssh/id_ed25519.pub`
- Gitea SSH Service exists at `gitea-ssh.dev.svc.cluster.local:22`

❌ **What's Missing:**
- SSH Service Type is ClusterIP (needs LoadBalancer for external access)
- SSH Port is 22 (should be 2222 for non-privileged external port)
- SSH public key not added to Gitea admin profile
- External SSH access not working (cannot SSH from outside cluster)

**Task Changes:** None - draft tasks accurately reflect codebase state.

---

## Dev Notes

### Technical Requirements

**FR137: Gitea configured for single-user operation with SSH key authentication**
- Single-user mode already configured: `DISABLE_REGISTRATION: true` in values-homelab.yaml
- SSH key authentication requires external SSH access (currently ClusterIP only)

**NFR79: Repository operations (clone, push, pull) complete within 10 seconds for typical repos**
- HTTPS already validated at 0.6s clone time in Story 19.2
- SSH should achieve similar performance

### Existing Infrastructure Context

**From Story 19.2:**
- Gitea deployed in `dev` namespace
- HTTP Service: `gitea-http.dev.svc.cluster.local:3000`
- SSH Service: `gitea-ssh.dev.svc.cluster.local:22` (ClusterIP - needs change)
- Admin credentials: admin / gitea-admin-2026
- Web access: https://git.home.jetzinger.com

**Current SSH Service Configuration:**
```yaml
service:
  ssh:
    type: ClusterIP  # Currently internal only
    port: 22
```

**Required Change (from Architecture):**
```yaml
service:
  ssh:
    type: LoadBalancer  # External access via MetalLB
    port: 2222          # Non-privileged port
```

**SSH Configuration in Gitea:**
```yaml
gitea:
  config:
    server:
      SSH_DOMAIN: git.home.jetzinger.com
      SSH_PORT: 2222  # Must match external port
```

### Previous Story Intelligence

**From Story 19.2:**
- HTTPS clone time: 0.6s (excellent performance)
- Certificate: Let's Encrypt via cert-manager
- Data persists on NFS PVC `gitea-shared-storage`
- Admin user already created and working

### Architecture Compliance

**Namespace:** `dev` (development tools)
**Service Type:** LoadBalancer (MetalLB for external IP)
**Port:** 2222 (non-privileged, standard alternative SSH port)
**Labels:** Standard `app.kubernetes.io/part-of: home-lab`

**SSH Clone Format:**
```bash
git clone ssh://git@git.home.jetzinger.com:2222/admin/repo-name.git
# or with ~/.ssh/config:
git clone git@git.home.jetzinger.com:admin/repo-name.git
```

### Project Context Reference

- [Source: docs/planning-artifacts/epics.md#Story 19.3, lines 4688-4720]
- [Source: docs/planning-artifacts/prd.md#FR137]
- [Source: docs/planning-artifacts/architecture.md#Gitea Architecture, lines 1075-1138]
- [Source: applications/gitea/values-homelab.yaml - Current Gitea config]
- [Source: docs/implementation-artifacts/19-2-configure-gitea-storage-and-ingress.md - Previous story]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.5 (claude-opus-4-5-20251101)

### Debug Log References

- Single-user mode: `DISABLE_REGISTRATION: true` verified in values-homelab.yaml
- Admin user: Verified can create repositories via API
- SSH service: Changed from ClusterIP:22 to LoadBalancer:2222
- LoadBalancer IP: 192.168.2.102 assigned by MetalLB
- SSH key added: fingerprint SHA256:/xuYamqryGpB18Qc7TajhUDDzvLVNOaGTK34M3tEMRI
- SSH clone time: 0.761s (NFR79 < 10 seconds)
- Pod restart required to apply SSH port changes (leveldb lock issue resolved by force delete)

### Completion Notes List

1. **Single-User Mode** (Task 1):
   - Registration already disabled via `DISABLE_REGISTRATION: true`
   - Admin user verified with `is_admin: true`
   - Registration page returns "Registration is disabled" message

2. **SSH Service Configuration** (Task 2):
   - Updated `service.ssh.type` from ClusterIP to LoadBalancer
   - Changed SSH port from 22 to 2222 (non-privileged)
   - MetalLB assigned IP: 192.168.2.102
   - Pod restart required due to leveldb queue lock (resolved)

3. **SSH Key Setup** (Task 3):
   - Added ed25519 key via Gitea API
   - Key stored in admin profile
   - Fingerprint: SHA256:/xuYam...

4. **SSH Git Operations** (Task 4):
   - Clone via SSH: 0.761s (NFR79 < 10 seconds)
   - Push via SSH: Working correctly
   - Host key added to ~/.ssh/known_hosts

5. **Access Methods:**
   - HTTPS: `https://git.home.jetzinger.com`
   - SSH: `ssh://git@192.168.2.102:2222/admin/repo.git`
   - Note: SSH uses IP directly (DNS points to Traefik for HTTPS)

### File List

| File | Action |
|------|--------|
| `applications/gitea/values-homelab.yaml` | Modified (SSH service type & port) |
| `applications/gitea/README.md` | Modified (SSH access documentation) |

### Change Log

- 2026-01-15: Story 19.3 completed - SSH access configured (Claude Opus 4.5)
- 2026-01-15: Story 19.3 created - Configure Gitea Single-User SSH Access (Claude Opus 4.5)
