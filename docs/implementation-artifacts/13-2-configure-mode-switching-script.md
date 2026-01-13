# Story 13.2: Configure Mode Switching Script

Status: done

## Story

As a **platform operator**,
I want **a script to switch between Gaming Mode and ML Mode**,
So that **I can easily transition the GPU between gaming and K8s ML workloads**.

## Acceptance Criteria

**AC1: Create gpu-mode Script**
Given Intel NUC has both Steam and K3s agent installed
When I create `/usr/local/bin/gpu-mode` script
Then script accepts `gaming` or `ml` argument
And script is executable: `chmod +x /usr/local/bin/gpu-mode`
And this validates FR97 (mode switching script)

**AC2: Gaming Mode Activation**
Given script is created
When I run `gpu-mode gaming`
Then script executes: `kubectl scale deployment/vllm-server --replicas=0 -n ml`
And vLLM pods terminate and release GPU memory
And script outputs: "Gaming Mode: vLLM scaled to 0, GPU available for Steam"
And completion time is <30 seconds (NFR51)
And this validates FR98 (Gaming Mode)

**AC3: ML Mode Restoration**
Given Gaming Mode is active
When I run `gpu-mode ml`
Then script executes: `kubectl scale deployment/vllm-server --replicas=1 -n ml`
And vLLM pod starts and loads models
And script outputs: "ML Mode: vLLM scaled to 1, GPU available for inference"
And completion time is <2 minutes (NFR52)
And this validates FR99 (ML Mode restoration)

**AC4: Status Check**
Given script is installed
When I run `gpu-mode status`
Then script shows current vLLM replica count
And script shows GPU memory usage (nvidia-smi)
And script shows Ollama fallback availability

## Tasks / Subtasks

- [x] Task 0: Configure kubectl on Intel NUC (prerequisite)
  - [x] 0.1 Copy kubeconfig from control plane to Intel NUC ~/.kube/config
  - [x] 0.2 Updated kubeconfig to use Tailscale IP (100.84.89.67) for cross-subnet access
  - [x] 0.3 Verify kubectl works: `kubectl get nodes` - shows all 4 nodes

- [x] Task 1: Create gpu-mode script (AC: #1, #2, #3, #4)
  - [x] 1.1 Create `/usr/local/bin/gpu-mode` shell script on k3s-gpu-worker
  - [x] 1.2 Implement argument parsing: `gaming`, `ml`, `status`
  - [x] 1.3 Implement `gaming` mode: scale vLLM to 0, verify pod termination
  - [x] 1.4 Implement `ml` mode: scale vLLM to 1, wait for pod ready
  - [x] 1.5 Implement `status` mode: show vLLM replicas, GPU memory, Ollama status
  - [x] 1.6 Add timing output for NFR51/NFR52 validation
  - [x] 1.7 Make script executable: `chmod +x /usr/local/bin/gpu-mode`

- [x] Task 2: Validate Gaming Mode (AC: #2)
  - [x] 2.1 Run `gpu-mode gaming` and measure completion time: 6 seconds
  - [x] 2.2 Verify vLLM pods are terminated: confirmed no pods
  - [x] 2.3 Verify GPU memory released: 244 MiB (from 8754 MiB)
  - [x] 2.4 Confirm completion time <30 seconds (NFR51): **6s - PASS**

- [x] Task 3: Validate ML Mode (AC: #3)
  - [x] 3.1 Run `gpu-mode ml` and measure completion time: 38 seconds
  - [x] 3.2 Verify vLLM pod starts and becomes Ready: 1/1 Running
  - [x] 3.3 Verify vLLM models endpoint responds: confirmed Qwen2.5-7B-Instruct-AWQ
  - [x] 3.4 Confirm completion time <2 minutes (NFR52): **38s - PASS**

- [x] Task 4: Update Documentation (AC: all)
  - [x] 4.1 Update `scripts/gpu-worker/steam-setup.md` with gpu-mode usage
  - [x] 4.2 Update `docs/runbooks/egpu-hotplug.md` to reference gpu-mode script
  - [x] 4.3 Add gpu-mode script to repository: `scripts/gpu-worker/gpu-mode`

## Gap Analysis

**Last Run:** 2026-01-13
**Accuracy Score:** 80% (4/5 tasks validated, 1 prerequisite added)

### Codebase Scan Results

**✅ What Exists:**

| Asset | Location | Status |
|-------|----------|--------|
| vLLM deployment | `applications/vllm/deployment.yaml` | name: `vllm-server`, namespace: `ml` |
| Current replicas | vLLM | 1 replica running |
| Steam setup docs | `scripts/gpu-worker/steam-setup.md` | Contains manual kubectl commands |
| K3s agent | Intel NUC | Running and connected to cluster |
| Control plane | `192.168.2.20:6443` | Accessible |

**❌ What's Missing:**

| Requirement | Status |
|-------------|--------|
| `/usr/local/bin/gpu-mode` script | Not created |
| kubeconfig on Intel NUC | Not configured - kubectl fails |
| `scripts/gpu-worker/gpu-mode` in repo | Not created |

**Task Validation:** Added Task 0 (configure kubectl) as prerequisite. Original tasks validated.

---

## Dev Notes

### Previous Story Intelligence (13.1)

From Story 13.1 (Install Steam and Proton on Intel NUC):
- **Steam installed:** version 1.0.0.74-1ubuntu2 via `apt install steam`
- **nvidia-drm.modeset=1:** already configured in `/etc/modprobe.d/nvidia-drm.conf`
- **Steam setup docs:** `scripts/gpu-worker/steam-setup.md`
- **Host IP:** 192.168.0.25 (LAN), 100.80.98.64 (Tailscale)
- **Hostname:** k3s-gpu-worker

### Architecture Requirements

**vLLM Deployment Details:**
- Deployment name: `vllm-server`
- Namespace: `ml`
- Replicas: 1 (default)
- Service: `vllm-api.ml.svc.cluster.local:8000`
- GPU requirement: nvidia.com/gpu: 1
- Model: Qwen/Qwen2.5-7B-Instruct-AWQ (~5GB VRAM)

**Ollama Fallback (CPU):**
- Deployment: `ollama` in namespace `ml`
- Node: k3s-worker-02
- Models: llama3.2:1b, qwen2.5:3b (slim models)
- Memory limit: 4Gi

**Timing Requirements:**
- NFR51: Gaming Mode activation <30 seconds
- NFR52: ML Mode restoration <2 minutes (includes model load)
- NFR54: Ollama CPU inference <5 seconds

**Script Location:**
- Install path: `/usr/local/bin/gpu-mode` (on k3s-gpu-worker host)
- Repository copy: `scripts/gpu-worker/gpu-mode`

### Project Structure Notes

- Script runs on HOST OS (k3s-gpu-worker), not in K8s
- kubectl available via K3s agent installed on host
- Script should be idempotent (safe to run multiple times)
- Consider edge cases: vLLM already scaled, pod stuck terminating

### References

- [Source: docs/planning-artifacts/epics.md#Story-13.2]
- [Source: docs/planning-artifacts/prd.md#FR97-FR99]
- [Source: docs/planning-artifacts/prd.md#NFR51-NFR52]
- [Source: docs/runbooks/egpu-hotplug.md] - Existing hot-plug procedures
- [Source: scripts/gpu-worker/steam-setup.md] - Steam setup with mode switching notes
- [Source: docs/implementation-artifacts/13-1-install-steam-and-proton-on-intel-nuc.md]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.5 (claude-opus-4-5-20251101)

### Debug Log References

- kubectl connection issue resolved by using Tailscale IP instead of LAN IP for cross-subnet access
- vLLM readiness probe initialDelaySeconds reduced from 180s to 30s to meet NFR52 target

### Completion Notes List

1. **Task 0 Complete:** kubectl configured on Intel NUC using Tailscale IP (100.84.89.67) for cross-subnet access to control plane
2. **Task 1 Complete:** gpu-mode script created with gaming/ml/status commands, colorful output, NFR timing validation
3. **Task 2 Complete:** Gaming Mode validated - 6 seconds completion (NFR51: <30s target met)
4. **Task 3 Complete:** ML Mode validated - 38 seconds completion (NFR52: <2min target met). Required updating vLLM deployment readiness probe from 180s to 30s initialDelaySeconds
5. **Task 4 Complete:** Documentation updated in steam-setup.md and egpu-hotplug.md

### File List

- `scripts/gpu-worker/gpu-mode` - New: Mode switching script
- `scripts/gpu-worker/steam-setup.md` - Updated: Added gpu-mode usage section
- `docs/runbooks/egpu-hotplug.md` - Updated: Added Quick Mode Switching section
- `applications/vllm/deployment.yaml` - Updated: Reduced readiness probe initialDelaySeconds from 180s to 30s

---

## Change Log

| Date | Action | Notes |
|------|--------|-------|
| 2026-01-13 | Story created | Created via create-story workflow with context from Story 13.1 |
| 2026-01-13 | Status: in-progress | Gap analysis added Task 0 (kubectl prerequisite) |
| 2026-01-13 | All tasks complete | Gaming Mode: 6s, ML Mode: 38s - both NFRs met |
| 2026-01-13 | Status: done | Story complete |
