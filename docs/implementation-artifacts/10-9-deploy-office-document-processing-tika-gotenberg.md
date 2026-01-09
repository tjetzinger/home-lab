# Story 10.9: Deploy Office Document Processing (Tika + Gotenberg)

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **user**,
I want **Paperless-ngx to process Office documents (Word, Excel, PowerPoint)**,
so that **I can import business documents directly without manual PDF conversion**.

## Acceptance Criteria

1. **Given** cluster has `docs` namespace
   **When** I deploy Apache Tika and Gotenberg
   **Then** the following resources are created:
   - Deployment: `tika` (1 replica, image: `apache/tika:latest`)
   - Service: `tika` (port 9998)
   - Deployment: `gotenberg` (1 replica, image: `gotenberg/gotenberg:8`)
   - Service: `gotenberg` (port 3000)

2. **Given** Tika and Gotenberg are running
   **When** I configure Paperless-ngx integration
   **Then** Helm values include:
   ```yaml
   env:
     PAPERLESS_TIKA_ENABLED: "true"
     PAPERLESS_TIKA_ENDPOINT: "http://tika:9998"
     PAPERLESS_TIKA_GOTENBERG_ENDPOINT: "http://gotenberg:3000"
   ```
   **And** this validates FR81 (Apache Tika for text extraction)
   **And** this validates FR82 (Gotenberg for PDF conversion)

3. **Given** Office processing is configured
   **When** I upload a .docx, .xlsx, or .pptx file
   **Then** Paperless-ngx converts the file to PDF via Gotenberg
   **And** text is extracted via Tika for full-text search
   **And** document appears in library with searchable content
   **And** this validates FR83 (direct Office format import)

4. **Given** OCR workers are configured
   **When** I check processing performance
   **Then** PAPERLESS_TASK_WORKERS is set to 2
   **And** this validates NFR41 (2 parallel OCR workers)

## Tasks / Subtasks

⚠️ **DRAFT TASKS** - Generated from requirements analysis. Will be validated and refined against actual codebase when dev-story runs.

- [x] **Task 1:** Create Apache Tika deployment and service (AC: 1)
  - [x] Create directory `applications/tika/`
  - [x] Create `applications/tika/deployment.yaml` with image `apache/tika:latest`
  - [x] Create `applications/tika/service.yaml` exposing port 9998
  - [x] Apply manifests to `docs` namespace
  - [x] Verify Tika pod is running and healthy - tika-546cc5fb9c-2vz2z Running

- [x] **Task 2:** Create Gotenberg deployment and service (AC: 1)
  - [x] Create directory `applications/gotenberg/`
  - [x] Create `applications/gotenberg/deployment.yaml` with image `gotenberg/gotenberg:8`
  - [x] Configure Gotenberg with `--chromium-disable-javascript=true` for security
  - [x] Create `applications/gotenberg/service.yaml` exposing port 3000
  - [x] Apply manifests to `docs` namespace
  - [x] Verify Gotenberg pod is running and healthy - gotenberg-5cbb47d6c5-cb4w9 Running

- [x] **Task 3:** Configure Paperless-ngx Tika integration (AC: 2)
  - [x] Add `PAPERLESS_TIKA_ENABLED: "true"` to values-homelab.yaml
  - [x] Add `PAPERLESS_TIKA_ENDPOINT: "http://tika:9998"` to values-homelab.yaml
  - [x] Add `PAPERLESS_TIKA_GOTENBERG_ENDPOINT: "http://gotenberg:3000"` to values-homelab.yaml
  - [x] Verify `PAPERLESS_TASK_WORKERS: "2"` is already set (NFR41) ✓
  - [x] Upgrade Paperless Helm release with new values - Revision 21
  - [x] Verify Paperless pod restarts with new configuration ✓

- [x] **Task 4:** Test Office document processing (AC: 3)
  - [x] Create or obtain a test .docx file
  - [x] Upload .docx file via Paperless consume folder
  - [x] Verify document is converted to PDF by Gotenberg - test-document ✓
  - [x] Verify text is extracted and searchable - "HOMELAB_TIKA_TEST_2026" found ✓
  - [x] Test with .xlsx file (Excel) - test-spreadsheet ✓
  - [x] Test with .pptx file (PowerPoint) - test-presentation ✓
  - [x] Verify all Office formats appear in library with searchable content ✓

- [x] **Task 5:** Document configuration and update headers
  - [x] Update values-homelab.yaml header with FR81-83, NFR41 references
  - [x] Document Tika/Gotenberg deployment details
  - [x] Capture test results for Office document processing

## Gap Analysis

**Scan Date:** 2026-01-09

### ✅ What Exists:
| Item | Location | Status |
|------|----------|--------|
| Paperless-ngx deployment | docs namespace | ✅ Running (1/1) |
| Redis deployment | docs namespace | ✅ Running (1/1) |

### ❌ What's Missing:
| Item | Required Action |
|------|-----------------|
| `applications/tika/` directory | CREATE - New deployment needed |
| `applications/gotenberg/` directory | CREATE - New deployment needed |
| Tika deployment in cluster | DEPLOY - Create and apply |
| Gotenberg deployment in cluster | DEPLOY - Create and apply |
| `PAPERLESS_TIKA_*` settings | ADD - Configure in values-homelab.yaml |

### Task Changes:
- **NO CHANGES** - Draft tasks accurate for implementation story

---

## Dev Notes

### Architecture Requirements

**Tika Configuration:** [Source: docs/planning-artifacts/architecture.md]
- Apache Tika for text and metadata extraction from Office documents
- Image: `apache/tika:latest`
- Port: 9998
- Internal service only (no ingress required)

**Gotenberg Configuration:** [Source: docs/planning-artifacts/architecture.md]
- Gotenberg for PDF conversion with Chromium engine
- Image: `gotenberg/gotenberg:8`
- Port: 3000
- Security: `--chromium-disable-javascript=true`
- Internal service only (no ingress required)

**Paperless Integration:** [Source: https://docs.paperless-ngx.com/configuration/]
- `PAPERLESS_TIKA_ENABLED`: Enable Tika integration for Office docs
- `PAPERLESS_TIKA_ENDPOINT`: URL to Tika server
- `PAPERLESS_TIKA_GOTENBERG_ENDPOINT`: URL to Gotenberg server

### Technical Constraints

**Namespace:** docs (same as Paperless-ngx)
**Storage:** No persistent storage required (stateless services)
**Resources:** Gotenberg requires more memory due to Chromium (~512Mi recommended)

### Previous Story Intelligence

**From Story 10.8 - Security Hardening:**
- Paperless-ngx fully operational with security settings
- CSRF and CORS protection validated
- Configuration update pattern established

**From Stories 10.6, 10.7:**
- Document upload and processing workflow validated
- NFS consume folder operational
- OCR processing working

**Existing Configuration Status:**
The following settings need to be ADDED to `values-homelab.yaml`:
- `PAPERLESS_TIKA_ENABLED: "true"` (NEW)
- `PAPERLESS_TIKA_ENDPOINT: "http://tika:9998"` (NEW)
- `PAPERLESS_TIKA_GOTENBERG_ENDPOINT: "http://gotenberg:3000"` (NEW)

**Key Insight:** This is an IMPLEMENTATION story - new deployments required, not just validation.

### Project Structure Notes

**New Files to Create:**
- `applications/tika/deployment.yaml`
- `applications/tika/service.yaml`
- `applications/gotenberg/deployment.yaml`
- `applications/gotenberg/service.yaml`

**Files to Modify:**
- `applications/paperless/values-homelab.yaml` - Add Tika settings

### Testing Requirements

**Validation Checklist:**
1. [x] Tika pod running in docs namespace - tika-546cc5fb9c-2vz2z Running
2. [x] Gotenberg pod running in docs namespace - gotenberg-5cbb47d6c5-cb4w9 Running
3. [x] Tika service accessible at tika:9998 - Apache Tika 3.2.3
4. [x] Gotenberg service accessible at gotenberg:3000 - {"status":"up"}
5. [x] Paperless configured with Tika integration - env vars verified
6. [x] .docx file successfully processed - test-document
7. [x] .xlsx file successfully processed - test-spreadsheet
8. [x] .pptx file successfully processed - test-presentation
9. [x] Extracted text is searchable in Paperless - All unique markers found

**Test Commands:**
```bash
# Verify Tika is running
kubectl get pods -n docs -l app=tika
kubectl exec -n docs deployment/paperless-paperless-ngx -- curl -s http://tika:9998/tika

# Verify Gotenberg is running
kubectl get pods -n docs -l app=gotenberg
kubectl exec -n docs deployment/paperless-paperless-ngx -- curl -s http://gotenberg:3000/health
```

### References

- [Epic 10: Document Management System: docs/planning-artifacts/epics.md#Epic 10]
- [Story 10.9 Requirements: docs/planning-artifacts/epics.md#Story 10.9]
- [FR81: Apache Tika for text extraction: docs/planning-artifacts/prd.md]
- [FR82: Gotenberg for PDF conversion: docs/planning-artifacts/prd.md]
- [FR83: Direct Office format import: docs/planning-artifacts/prd.md]
- [NFR41: 2 parallel OCR workers: docs/planning-artifacts/prd.md]
- [Previous Story: 10-8-implement-security-hardening.md]
- [Paperless Tika Configuration: https://docs.paperless-ngx.com/configuration/]
- [Apache Tika: https://tika.apache.org/]
- [Gotenberg: https://gotenberg.dev/]
- [Current values: applications/paperless/values-homelab.yaml]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.5 (claude-opus-4-5-20251101)

### Debug Log References

- Tika logs: `kubectl logs -n docs deployment/tika`
- Gotenberg logs: `kubectl logs -n docs deployment/gotenberg`
- Paperless Tika processing: `kubectl logs -n docs deployment/paperless-paperless-ngx | grep -i tika`

### Completion Notes List

1. **Apache Tika deployed** - image: apache/tika:latest, port 9998, stateless
2. **Gotenberg deployed** - image: gotenberg/gotenberg:8, port 3000, Chromium JS disabled for security
3. **Paperless integration configured** - TIKA_ENABLED, TIKA_ENDPOINT, TIKA_GOTENBERG_ENDPOINT
4. **Office document processing validated**:
   - .docx: Processed via Tika → text extraction successful
   - .xlsx: Processed via Tika → spreadsheet data extracted
   - .pptx: Processed via Tika → presentation text extracted
5. **All documents converted to PDF** via Gotenberg with Chromium engine
6. **Full-text search working** - unique test markers searchable in Paperless

### File List

**Created:**
- `applications/tika/deployment.yaml` - Apache Tika deployment
- `applications/tika/service.yaml` - Tika ClusterIP service
- `applications/gotenberg/deployment.yaml` - Gotenberg deployment with security args
- `applications/gotenberg/service.yaml` - Gotenberg ClusterIP service

**Modified:**
- `applications/paperless/values-homelab.yaml` - Added FR81-83, NFR41 header references and TIKA settings

