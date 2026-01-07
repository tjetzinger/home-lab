# Story 3.4: Configure DNS with NextDNS Rewrites

Status: done

## Story

As a **cluster operator**,
I want **to configure NextDNS to resolve *.home.jetzinger.com to my cluster ingress**,
So that **I can access services by name from any device on my network**.

## Acceptance Criteria

1. **AC1: NextDNS Dashboard Access**
   - **Given** Traefik has external IP 192.168.2.100 from MetalLB pool
   - **When** I log into NextDNS dashboard
   - **Then** I can access the Rewrites configuration section

2. **AC2: DNS Rewrite Rule Configuration**
   - **Given** NextDNS Rewrites section is accessible
   - **When** I add a rewrite rule: `*.home.jetzinger.com` -> `192.168.2.100`
   - **Then** the rule is saved successfully
   - **And** the rule appears in the active rewrites list

3. **AC3: DNS Resolution Verification**
   - **Given** DNS rewrite is configured
   - **When** I query `nslookup grafana.home.jetzinger.com` from a network device
   - **Then** the query resolves to 192.168.2.100
   - **And** any subdomain of home.jetzinger.com resolves to the same IP

4. **AC4: End-to-End Connectivity**
   - **Given** DNS is working
   - **When** I access http://traefik.home.jetzinger.com from a browser
   - **Then** the request reaches Traefik
   - **And** the Traefik dashboard loads (or appropriate response)

## Tasks / Subtasks

**DRAFT TASKS** - Generated from requirements analysis. Will be validated and refined against actual codebase when dev-story runs.

- [x] Task 1: Verify NextDNS Configuration (AC: #1, #2)
  - [x] 1.1: Confirm NextDNS rewrite rule exists for `*.home.jetzinger.com`
  - [x] 1.2: Document the rewrite rule configuration
  - [x] 1.3: Screenshot NextDNS dashboard showing the rule (optional)

- [x] Task 2: Test DNS Resolution (AC: #3)
  - [x] 2.1: Test resolution from workstation using nslookup
  - [x] 2.2: Test multiple subdomains (grafana, traefik, test)
  - [x] 2.3: Verify all resolve to 192.168.2.100

- [x] Task 3: Validate End-to-End Connectivity (AC: #4)
  - [x] 3.1: Access traefik.home.jetzinger.com via HTTP
  - [x] 3.2: Verify Traefik dashboard responds
  - [x] 3.3: Test from different network client if available

- [x] Task 4: Documentation (AC: all)
  - [x] 4.1: Document NextDNS configuration in story notes
  - [x] 4.2: Note any caveats (e.g., only works on NextDNS-configured networks)

## Gap Analysis

**Scan Date:** 2026-01-06
**Scan Result:** ✅ NextDNS already configured - verification only needed

**What Exists:**
- NextDNS rewrite rule for `*.home.jetzinger.com` -> `192.168.2.100` (ALREADY CONFIGURED)
- Traefik running with external IP 192.168.2.100 from MetalLB
- Traefik dashboard accessible at traefik.home.jetzinger.com (Story 3.2)
- DNS resolution verified working:
  - `grafana.home.jetzinger.com` → 192.168.2.100 ✓
  - `traefik.home.jetzinger.com` → 192.168.2.100 ✓
  - `test.home.jetzinger.com` → 192.168.2.100 ✓
- End-to-end connectivity verified: Traefik dashboard responds with HTTP 200 OK

**What's Missing:**
- Formal documentation of the NextDNS configuration in completion notes
- Test results documentation

**Task Changes:** No changes needed - draft tasks accurately reflect verification-only scope

---

## Dev Notes

### Technical Specifications

**NextDNS Configuration:**
- Service: NextDNS (https://my.nextdns.io)
- Feature: DNS Rewrites
- Rule: `*.home.jetzinger.com` -> `192.168.2.100`
- Effect: All subdomains resolve to Traefik's LoadBalancer IP

**Architecture Requirements:**

From [Source: epics.md#FR21]:
- FR21: Operator can access services via *.home.jetzinger.com domain

From [Source: epics.md#FR22]:
- FR22: System resolves internal DNS via NextDNS rewrites

### Previous Story Intelligence (Story 3.3)

**Key Learning - NextDNS Interference with cert-manager:**
During Story 3.3 implementation, we discovered that NextDNS rewrites affect ALL DNS queries from devices using NextDNS, including cert-manager's ACME DNS-01 propagation checks. This was resolved by configuring cert-manager to use Cloudflare DNS (1.1.1.1, 8.8.8.8) directly for TXT record verification.

**Current Cluster State:**
| Node | IP | Status |
|------|-----|--------|
| k3s-master | 192.168.2.20 | Ready |
| k3s-worker-01 | 192.168.2.21 | Ready |
| k3s-worker-02 | 192.168.2.22 | Ready |

**Traefik Configuration (from Story 3.2):**
- External IP: 192.168.2.100 (from MetalLB pool)
- Dashboard: traefik.home.jetzinger.com (HTTP, IP-whitelisted)
- Ports: 80 (HTTP), 443 (HTTPS)

### Project Structure Notes

**No files to create** - This story is configuration-only in NextDNS dashboard (external service).

**Documentation only:**
- This story file documents the existing configuration
- No Kubernetes manifests or Helm charts required

### Testing Approach

**DNS Resolution Test:**
```bash
# Test from any device using NextDNS
nslookup grafana.home.jetzinger.com
# Expected: Address: 192.168.2.100

nslookup traefik.home.jetzinger.com
# Expected: Address: 192.168.2.100

nslookup anything.home.jetzinger.com
# Expected: Address: 192.168.2.100
```

**Connectivity Test:**
```bash
# Test HTTP access to Traefik dashboard
curl -I http://traefik.home.jetzinger.com
# Expected: HTTP/1.1 200 OK (from home network)
```

### Security Considerations

- NextDNS rewrites only affect devices configured to use NextDNS
- Devices using other DNS servers will not resolve *.home.jetzinger.com
- This is a feature, not a bug - provides network segmentation
- External users cannot access internal services (no public DNS resolution)

### Limitations

1. **Network-dependent:** Only works on networks/devices using NextDNS
2. **No public access:** Services are internal-only by design
3. **Manual configuration:** NextDNS rewrites must be configured manually in dashboard

### Dependencies

- **Upstream:** Story 3.1 (MetalLB) - COMPLETED, Story 3.2 (Traefik) - COMPLETED
- **Downstream:** Story 3.5 (HTTPS ingress routes)
- **External:** NextDNS account and configuration

### References

- [Source: epics.md#Story 3.4]
- [Source: epics.md#FR21]
- [Source: epics.md#FR22]
- [NextDNS Rewrites Documentation](https://my.nextdns.io)

## Dev Agent Record

### Agent Model Used

Claude Sonnet 4.5 (claude-sonnet-4-5-20250929)

### Debug Log References

N/A - Configuration verification only

### Completion Notes List

1. **AC1 & AC2 - NextDNS Configuration Verification:** Confirmed NextDNS rewrite rule exists: `*.home.jetzinger.com` → `192.168.2.100`. This configuration was already in place prior to this story (pre-configured before project Sprint Planning). The rule is active and functioning correctly.

2. **AC3 - DNS Resolution Verification:** Tested DNS resolution from workstation for multiple subdomains:
   - `grafana.home.jetzinger.com` → 192.168.2.100 ✓
   - `traefik.home.jetzinger.com` → 192.168.2.100 ✓
   - `test.home.jetzinger.com` → 192.168.2.100 ✓

   All queries return the correct Traefik LoadBalancer IP address.

3. **AC4 - End-to-End Connectivity:** Verified HTTP connectivity to Traefik dashboard at `http://traefik.home.jetzinger.com/dashboard/` returns HTTP 200 OK. Complete ingress pipeline working: DNS → MetalLB LoadBalancer IP → Traefik → Dashboard.

4. **Configuration Details:**
   - **DNS Provider:** NextDNS (https://my.nextdns.io)
   - **Rewrite Type:** Wildcard subdomain rewrite
   - **Target IP:** 192.168.2.100 (Traefik LoadBalancer IP from MetalLB pool)
   - **Scope:** All devices using NextDNS on the network

5. **Important Caveats Documented:**
   - **Network-dependent:** DNS rewrites only apply to devices configured to use NextDNS
   - **No public access:** Services remain internal-only (not publicly resolvable)
   - **cert-manager consideration:** NextDNS rewrites interfere with ACME DNS-01 propagation checks. cert-manager is configured to use Cloudflare DNS (1.1.1.1, 8.8.8.8) directly to bypass this (configured in Story 3.3).

6. **Note:** This was a verification-only story. NextDNS was pre-configured before Sprint Planning began, so no infrastructure changes were required—only verification and documentation.

### File List

_Files created/modified during implementation:_
- `docs/implementation-artifacts/3-4-configure-dns-with-nextdns-rewrites.md` - MODIFIED - Story completed with verification results
