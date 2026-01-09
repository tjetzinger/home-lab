# Story 10.8: Implement Security Hardening

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **platform engineer**,
I want **CSRF and CORS protection enabled for Paperless-ngx**,
so that **the web interface is protected against cross-site attacks**.

## Acceptance Criteria

1. **Given** Paperless-ngx is deployed with ingress
   **When** I configure security hardening settings
   **Then** Helm values include:
   ```yaml
   env:
     PAPERLESS_CSRF_TRUSTED_ORIGINS: "https://paperless.home.jetzinger.com"
     PAPERLESS_CORS_ALLOWED_HOSTS: "https://paperless.home.jetzinger.com"
     PAPERLESS_COOKIE_PREFIX: "paperless_ngx"
     PAPERLESS_ENABLE_HTTP_REMOTE_USER: "false"
   ```
   **And** this validates FR79 (CSRF protection enabled)
   **And** this validates FR80 (CORS restricted to authorized origins)

2. **Given** security settings are applied
   **When** I attempt cross-origin request from unauthorized domain
   **Then** request is rejected with CORS error
   **And** CSRF token validation is enforced on form submissions

## Tasks / Subtasks

⚠️ **DRAFT TASKS** - Generated from requirements analysis. Will be validated and refined against actual codebase when dev-story runs.

- [x] **Task 1:** Verify existing security configuration matches requirements (AC: 1)
  - [x] Read `applications/paperless/values-homelab.yaml` and verify all security settings exist
  - [x] Confirm `PAPERLESS_CSRF_TRUSTED_ORIGINS: "https://paperless.home.jetzinger.com"` present (FR79) - Line 64
  - [x] Confirm `PAPERLESS_CORS_ALLOWED_HOSTS: "https://paperless.home.jetzinger.com"` present (FR80) - Line 65
  - [x] Confirm `PAPERLESS_COOKIE_PREFIX: "paperless_ngx"` present - Line 63
  - [x] Confirm `PAPERLESS_ENABLE_HTTP_REMOTE_USER: "false"` present - Line 67
  - [x] Update values file header comment to reference Story 10.8 and FR79-80

- [x] **Task 2:** Test CORS protection (AC: 2)
  - [x] Use curl to send cross-origin OPTIONS request from unauthorized origin - No CORS headers returned
  - [x] Verify CORS preflight is rejected for unauthorized domains - evil.com blocked ✅
  - [x] Verify CORS headers are present for authorized origin - Headers present for paperless.home.jetzinger.com
  - [x] Document CORS behavior observations - FR80 validated

- [x] **Task 3:** Test CSRF protection (AC: 2)
  - [x] Access Paperless web interface and verify CSRF token is in forms - Hidden input present
  - [x] Verify login form includes CSRF token - `csrfmiddlewaretoken` field present
  - [x] Attempt form submission without CSRF token (should fail) - Returns 403 Forbidden
  - [x] Document CSRF validation behavior - FR79 validated

- [x] **Task 4:** Document security validation results
  - [x] Update values-homelab.yaml header with FR79-80 references - Added lines 13-14
  - [x] Document CORS and CSRF test results (below)
  - [x] Note any configuration adjustments made: None required - all settings already configured
  - [x] Capture security validation metrics (below)

### Security Test Results Summary

**Test Date:** 2026-01-09

| Test | Result | FR |
|------|--------|-----|
| CSRF token in forms | ✅ Present (`csrfmiddlewaretoken`) | FR79 |
| CSRF cookie prefix | ✅ `paperless_ngxcsrftoken` | FR79 |
| POST without CSRF | ✅ Returns 403 Forbidden | FR79 |
| CORS unauthorized origin | ✅ No headers returned (blocked) | FR80 |
| CORS authorized origin | ✅ Headers present | FR80 |

**CORS Response Headers (Authorized Origin):**
```
access-control-allow-origin: https://paperless.home.jetzinger.com
access-control-allow-methods: DELETE, GET, OPTIONS, PATCH, POST, PUT
access-control-allow-headers: accept, authorization, content-type, user-agent, x-csrftoken, x-requested-with
```

**Security Configuration (Verified):**
- `PAPERLESS_CSRF_TRUSTED_ORIGINS`: https://paperless.home.jetzinger.com
- `PAPERLESS_CORS_ALLOWED_HOSTS`: https://paperless.home.jetzinger.com
- `PAPERLESS_COOKIE_PREFIX`: paperless_ngx
- `PAPERLESS_ENABLE_HTTP_REMOTE_USER`: false

## Gap Analysis

**Scan Date:** 2026-01-09

### ✅ What Exists:
| Item | Location | Status |
|------|----------|--------|
| `PAPERLESS_COOKIE_PREFIX: "paperless_ngx"` | values-homelab.yaml:63 | ✅ Present |
| `PAPERLESS_CSRF_TRUSTED_ORIGINS` | values-homelab.yaml:64 | ✅ Present (FR79) |
| `PAPERLESS_CORS_ALLOWED_HOSTS` | values-homelab.yaml:65 | ✅ Present (FR80) |
| `PAPERLESS_ENABLE_HTTP_REMOTE_USER: "false"` | values-homelab.yaml:67 | ✅ Present |
| Paperless pod running | docs namespace | ✅ Running |

### ❌ What's Missing:
- CORS/CSRF behavior validation (needs testing)

### Task Changes:
- **NO CHANGES** - Draft tasks accurate for validation story

---

## Dev Notes

### Architecture Requirements

**Security Configuration:** [Source: docs/planning-artifacts/architecture.md]
- CSRF protection required for web interface
- CORS restricted to authorized origins only
- Cookie prefix to prevent conflicts with other services
- HTTP remote user disabled (using built-in authentication)

**Security Settings Reference:** [Source: https://docs.paperless-ngx.com/configuration/]
- `PAPERLESS_CSRF_TRUSTED_ORIGINS`: Comma-separated list of trusted origins for CSRF
- `PAPERLESS_CORS_ALLOWED_HOSTS`: Comma-separated list of allowed CORS origins
- `PAPERLESS_COOKIE_PREFIX`: Prefix for all cookies (prevents conflicts)
- `PAPERLESS_ENABLE_HTTP_REMOTE_USER`: Enable/disable reverse proxy authentication

### Technical Constraints

**Ingress Configuration:** [Source: applications/paperless/]
- Public URL: `https://paperless.home.jetzinger.com`
- TLS via cert-manager with Let's Encrypt
- Traefik IngressRoute for routing

**Access Pattern:** [Source: docs/planning-artifacts/architecture.md]
- All access via Tailscale VPN (no public internet exposure)
- CORS protection still required for defense-in-depth

### Previous Story Intelligence

**From Story 10.7 - Single-User Mode with NFS Polling:**
- Paperless-ngx fully operational with HTTPS access
- All consumer polling settings verified working
- Values file header updated with FR references
- Similar validation/testing approach successful

**Existing Configuration Status:**
The following security settings are ALREADY configured in `values-homelab.yaml`:
- Line 63: `PAPERLESS_COOKIE_PREFIX: "paperless_ngx"` ✅
- Line 64: `PAPERLESS_CSRF_TRUSTED_ORIGINS: "https://paperless.home.jetzinger.com"` ✅
- Line 65: `PAPERLESS_CORS_ALLOWED_HOSTS: "https://paperless.home.jetzinger.com"` ✅
- Line 67: `PAPERLESS_ENABLE_HTTP_REMOTE_USER: "false"` ✅

**Key Insight:** This story is primarily VALIDATION - configuration already exists. Focus on:
1. Verifying configuration matches requirements
2. Testing CORS protection actually works
3. Testing CSRF validation is enforced

### Project Structure Notes

**Relevant Files:**
- `applications/paperless/values-homelab.yaml` - Helm values with security config
- Paperless web interface at `https://paperless.home.jetzinger.com`

**Testing Approach:**
- This is a validation/testing story similar to Stories 10.6 and 10.7
- Configuration already in place, needs verification
- Use curl for CORS testing, browser for CSRF inspection

### Testing Requirements

**Validation Checklist:**
1. [ ] All PAPERLESS_CSRF_* and PAPERLESS_CORS_* settings present
2. [ ] CORS preflight rejected for unauthorized origins
3. [ ] CORS headers present for authorized origin
4. [ ] CSRF token present in HTML forms
5. [ ] Form submission without token rejected

**Security Test Commands:**
```bash
# Test CORS preflight for unauthorized origin
curl -X OPTIONS https://paperless.home.jetzinger.com/api/ \
  -H "Origin: https://evil.com" \
  -H "Access-Control-Request-Method: POST" -v

# Test CORS for authorized origin
curl -X OPTIONS https://paperless.home.jetzinger.com/api/ \
  -H "Origin: https://paperless.home.jetzinger.com" \
  -H "Access-Control-Request-Method: POST" -v
```

### References

- [Epic 10: Document Management System: docs/planning-artifacts/epics.md#Epic 10]
- [Story 10.8 Requirements: docs/planning-artifacts/epics.md#Story 10.8]
- [FR79: CSRF protection enabled: docs/planning-artifacts/prd.md]
- [FR80: CORS restricted to authorized origins: docs/planning-artifacts/prd.md]
- [Previous Story: 10-7-configure-single-user-mode-with-nfs-polling.md]
- [Paperless Security Configuration: https://docs.paperless-ngx.com/configuration/]
- [Current values: applications/paperless/values-homelab.yaml]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.5 (claude-opus-4-5-20251101)

### Debug Log References

- CORS test: `curl -X OPTIONS https://paperless.home.jetzinger.com/api/`
- CSRF token check: `curl -s https://paperless.home.jetzinger.com/accounts/login/ | grep csrf`
- CSRF cookie check: `curl -s -I https://paperless.home.jetzinger.com/accounts/login/ | grep set-cookie`

### Completion Notes List

- ✅ All 4 security settings verified present in values-homelab.yaml (lines 63-67)
- ✅ CORS protection validated: unauthorized origins blocked, authorized origin returns headers
- ✅ CSRF protection validated: tokens in forms, cookie prefix correct, 403 on missing token
- ✅ Header updated with FR79-80 references
- ✅ No configuration changes required - all settings already in place

### Change Log

- 2026-01-09: Story 10.8 implementation completed
  - Verified all security hardening settings (FR79, FR80)
  - Tested CORS protection with curl (unauthorized/authorized origins)
  - Tested CSRF protection (token presence, POST rejection)
  - Updated values-homelab.yaml header with FR79-80 references

### File List

- `applications/paperless/values-homelab.yaml` - Updated header with FR79-80 references

