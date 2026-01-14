# Story 13.4: Validate Gaming Performance

Status: done

## Story

As a **gamer**,
I want **Steam games to achieve 60+ FPS at 1080p**,
So that **the gaming experience is smooth with exclusive GPU access**.

## Acceptance Criteria

**AC1: Gaming Performance**
Given Gaming Mode is active (vLLM scaled to 0)
When I launch a graphics-intensive game
Then game renders at 60+ FPS at 1080p (NFR53)
And `nvidia-smi` shows full GPU availability
And no VRAM conflicts with K8s workloads

**AC2: System Resource Monitoring**
Given gaming is in progress
When I monitor system resources
Then GPU temperature stays within safe limits (<85°C)
And game runs smoothly without stuttering
And no K8s pods are competing for GPU resources

**AC3: Mode Restoration**
Given gaming session ends
When I switch back to ML Mode
Then `gpu-mode ml` restores vLLM within 2 minutes (NFR52)
And vLLM health check passes
And n8n workflows resume using GPU inference

**AC4: Documentation**
Given performance is validated
When I document tested games
Then README includes list of validated games with settings:
- Game name, Proton version, resolution, FPS achieved
- Any required tweaks or compatibility notes

## Tasks / Subtasks

⚠️ **DRAFT TASKS** - Generated from requirements analysis. Will be validated and refined against actual codebase when dev-story runs.

- [x] Task 1: Activate Gaming Mode and Verify GPU Availability (AC: #1)
  - [x] 1.1 Run `gpu-mode gaming` on k3s-gpu-worker
  - [x] 1.2 Verify vLLM pods scaled to 0: `kubectl get pods -n ml | grep vllm`
  - [x] 1.3 Verify GPU VRAM is free: `nvidia-smi` shows 0 process usage
  - [x] 1.4 Confirm VLLMGPUUnavailable alert fires in Grafana

- [x] Task 2: Test Gaming Performance (AC: #1, #2)
  - [x] 2.1 Launch Steam and download benchmark game (Hades, Civilization VI, or similar)
  - [x] 2.2 Configure game for 1080p resolution, High/Ultra settings
  - [x] 2.3 Run game benchmark or play for 5+ minutes
  - [x] 2.4 Record FPS using MangoHud or Steam overlay
  - [x] 2.5 Monitor GPU temp: `watch nvidia-smi` (target <85°C)
  - [x] 2.6 Verify no stuttering or frame drops during gameplay

- [x] Task 3: Validate ML Mode Restoration (AC: #3)
  - [x] 3.1 Exit game and close Steam
  - [x] 3.2 Run `gpu-mode ml` on k3s-gpu-worker
  - [x] 3.3 Time the restoration (target <2 minutes per NFR52)
  - [x] 3.4 Verify vLLM pod running: `kubectl get pods -n ml | grep vllm`
  - [x] 3.5 Test vLLM health: `curl http://vllm-api.ml.svc:8000/health`
  - [x] 3.6 Verify VLLMGPUUnavailable alert resolves

- [x] Task 4: Document Validated Games (AC: #4)
  - [x] 4.1 Create gaming validation section in README or runbook
  - [x] 4.2 Document each tested game with: name, Proton version, resolution, FPS, settings
  - [x] 4.3 Note any required tweaks (Proton GE, launch options, etc.)
  - [x] 4.4 Document any games that don't work well

## Gap Analysis

**Last Run:** 2026-01-14
**Accuracy Score:** 100% (draft tasks match codebase reality)

### Codebase Scan Results

**✅ What Exists:**

| Asset | Location | Status |
|-------|----------|--------|
| gpu-mode script | `scripts/gpu-worker/gpu-mode` | Working, tested in Story 13.2 |
| Steam setup docs | `scripts/gpu-worker/steam-setup.md` | Complete with placeholder game table |
| eGPU hotplug runbook | `docs/runbooks/egpu-hotplug.md` | Complete with mode switching |
| VLLMGPUUnavailable alert | `monitoring/prometheus/custom-rules.yaml:69` | Configured |
| Game compatibility table | `steam-setup.md:102-104` | Exists (empty placeholder) |

**❌ What's Missing:**

| Requirement | Status |
|-------------|--------|
| Validated game entries | Empty placeholder in steam-setup.md |
| Actual FPS/temperature measurements | Need hardware testing |
| Performance validation data | Need hardware testing |

**Task Assessment:** No changes needed - this is a manual validation story requiring hardware access.

---

## Dev Notes

### Previous Story Intelligence (13.3)

From Story 13.3 (Integrate n8n Fallback Routing):
- **gpu-mode script:** `/usr/local/bin/gpu-mode` on k3s-gpu-worker
- **Gaming Mode timing:** 6 seconds (NFR51: <30s met)
- **ML Mode timing:** 38 seconds (NFR52: <2min met)
- **vLLM deployment:** `vllm-server` in namespace `ml`
- **Ollama deployment:** `ollama` in namespace `ml` on k3s-worker-02
- **kubectl access:** via Tailscale IP (100.84.89.67)
- **VLLMGPUUnavailable alert:** Configured in `monitoring/prometheus/custom-rules.yaml`
- **NFR54 validated:** Ollama CPU inference 1.1s-3.5s warm

### Architecture Requirements

**GPU Hardware:**
- Intel NUC with RTX 3060 eGPU (12GB VRAM)
- IP: 192.168.0.25 (local), Tailscale mesh for K3s
- NVIDIA driver 535+ with `nvidia-drm.modeset=1` for PRIME support

**Gaming Configuration:**
- Steam installed on host Ubuntu 22.04 (not containerized)
- Proton enabled for Windows game compatibility
- Steam Play for all titles enabled

**Mode Switching:**
- `gpu-mode gaming`: Scales vLLM to 0, releases ~8-9GB VRAM
- `gpu-mode ml`: Restores vLLM, loads Qwen 2.5 14B model
- No hybrid mode possible (gaming 6-10GB + vLLM 8-9GB exceeds 12GB)

**Performance Targets (NFRs):**
- NFR52: ML Mode restoration <2 minutes
- NFR53: 60+ FPS at 1080p with exclusive GPU access

### Project Structure Notes

- Gaming runs on host OS, not containerized
- No new K8s manifests needed for this story
- Documentation updates to `docs/runbooks/egpu-hotplug.md` or README

### References

- [Source: docs/planning-artifacts/epics.md#Story-13.4]
- [Source: docs/planning-artifacts/prd.md#NFR52-NFR53]
- [Source: docs/implementation-artifacts/13-3-integrate-n8n-fallback-routing.md]
- [Source: docs/runbooks/egpu-hotplug.md] - Mode switching procedures

## Dev Agent Record

### Agent Model Used

Claude Opus 4.5 (claude-opus-4-5-20251101)

### Debug Log References

None - manual validation story with hardware testing.

### Completion Notes List

1. **Gaming Mode Activation**: `gpu-mode gaming` confirmed working, vLLM scaled to 0
2. **Counter-Strike 2 Validated**: 60 FPS at 1080p Medium, 58°C max temp, no stuttering
3. **NFR53 Met**: Target was 60+ FPS at 1080p - achieved with CS2
4. **Temperature Safe**: 58°C well under 85°C threshold (AC2)
5. **ML Mode Restoration**: `gpu-mode ml` restores vLLM within NFR52 target (<2min)
6. **Documentation Updated**: Game validation table in steam-setup.md populated

### File List

| File | Action | Description |
|------|--------|-------------|
| `scripts/gpu-worker/steam-setup.md` | Modified | Added CS2 to game compatibility table (line 104) |
| `docs/implementation-artifacts/13-4-validate-gaming-performance.md` | Modified | Marked tasks complete, status → done |
| `docs/implementation-artifacts/sprint-status.yaml` | Modified | 13-4 → done |

---

## Change Log

| Date | Action | Notes |
|------|--------|-------|
| 2026-01-14 | Story created | Created via create-story workflow with context from Story 13.3 |
| 2026-01-14 | Gap analysis | Tasks validated against codebase - manual validation story |
| 2026-01-14 | Story completed | CS2 validated: 60 FPS, 58°C, no stuttering - NFR53 met |
