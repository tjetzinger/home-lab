# eGPU Hot-Plug Runbook

This runbook documents the procedure for safely disconnecting and reconnecting the RTX 3060 eGPU from the Intel NUC GPU worker node, with automatic fallback to Ollama CPU inference during maintenance.

## Overview

| Item | Details |
|------|---------|
| **Scope** | eGPU hot-plug for k3s-gpu-worker |
| **Impact** | vLLM pods evicted, AI workflows fallback to Ollama CPU |
| **Duration** | Disconnect: 2-5 minutes, Reconnect: 2-5 minutes + model load (~60s) |
| **Risk Level** | Low (with graceful degradation) |

## Prerequisites

Before starting:

1. **Cluster Access**: Verify kubectl works
   ```bash
   kubectl get nodes
   ```

2. **GPU Worker Status**: Confirm k3s-gpu-worker is Ready
   ```bash
   kubectl get node k3s-gpu-worker
   ```

3. **vLLM Status**: Check vLLM pod is running
   ```bash
   kubectl get pods -n ml -l app=vllm-server
   ```

4. **Ollama Fallback Ready**: Verify Ollama CPU is available
   ```bash
   kubectl exec -it deploy/ollama -n ml -- curl -s http://localhost:11434/api/tags | jq .
   ```

5. **PDB Exists**: Confirm PodDisruptionBudget allows drain
   ```bash
   kubectl get pdb -n ml vllm-pdb
   # Should show ALLOWED DISRUPTIONS: 1
   ```

## Node Topology Reference

| Node | Role | IP (LAN) | IP (Tailscale) | Hardware |
|------|------|----------|----------------|----------|
| k3s-gpu-worker | GPU compute | 192.168.0.25 | 100.80.98.64 | Intel NUC + RTX 3060 eGPU |
| k3s-worker-02 | General compute | 192.168.2.22 | 100.88.186.68 | Ollama CPU fallback |

---

## Procedure 1: Disconnect eGPU (Maintenance Mode)

### Step 1: Drain the GPU Worker

Evict all pods from k3s-gpu-worker:

```bash
kubectl drain k3s-gpu-worker --ignore-daemonsets --delete-emptydir-data
```

**Expected Output:**
```
node/k3s-gpu-worker cordoned
Warning: ignoring DaemonSet-managed Pods: gpu-operator/...
evicting pod ml/vllm-server-XXXXXXXXXX-XXXXX
pod/vllm-server-XXXXXXXXXX-XXXXX evicted
node/k3s-gpu-worker drained
```

**Timing:** ~10-30 seconds (vLLM termination grace period)

### Step 2: Verify vLLM is Down

Confirm vLLM pod is evicted:

```bash
kubectl get pods -n ml -l app=vllm-server -o wide
# Should show no pods or Terminating status
```

Confirm vLLM health endpoint fails:

```bash
kubectl exec -it deploy/ollama -n ml -- curl -s -o /dev/null -w "%{http_code}" http://vllm-api.ml.svc.cluster.local:8000/health --connect-timeout 5
# Should return 000 (connection refused) or timeout
```

### Step 3: Verify Fallback Active

Test Ollama CPU responds:

```bash
kubectl exec -it deploy/ollama -n ml -- curl -s -X POST http://localhost:11434/api/generate \
  -d '{"model":"llama3.2:1b","prompt":"Say hello","stream":false}' | jq -r .response
```

**Expected:** Response within 5 seconds (NFR54)

### Step 4: Disconnect eGPU Hardware

Now safe to physically disconnect the eGPU:

1. Power off eGPU enclosure (if applicable)
2. Disconnect Thunderbolt cable from Intel NUC
3. Node remains in cluster but cordoned (no GPU workloads scheduled)

---

## Procedure 2: Reconnect eGPU (Resume ML Mode)

### Step 1: Reconnect Hardware

1. Connect Thunderbolt cable to Intel NUC
2. Power on eGPU enclosure (if applicable)
3. Wait 5-10 seconds for device enumeration

### Step 2: Verify GPU on Host

SSH to the GPU worker and verify nvidia-smi:

```bash
ssh tt@100.80.98.64 nvidia-smi
```

**Expected Output:**
```
+-----------------------------------------------------------------------------+
| NVIDIA-SMI 535.274.02    Driver Version: 535.274.02    CUDA Version: 12.2   |
|-------------------------------+----------------------+----------------------+
| GPU  Name        Persistence-M| Bus-Id        Disp.A | Volatile Uncorr. ECC |
| Fan  Temp  Perf  Pwr:Usage/Cap|         Memory-Usage | GPU-Util  Compute M. |
|===============================+======================+======================|
|   0  NVIDIA GeForce ...  Off  | 00000000:06:00.0 Off |                  N/A |
|  0%   38C    P8    10W / 170W |      0MiB / 12288MiB |      0%      Default |
+-------------------------------+----------------------+----------------------+
```

If nvidia-smi fails, wait 30 seconds and retry. May need to restart containerd:

```bash
ssh tt@100.80.98.64 sudo systemctl restart containerd
```

### Step 3: Uncordon the Node

Allow scheduling on the GPU worker:

```bash
kubectl uncordon k3s-gpu-worker
```

**Expected Output:**
```
node/k3s-gpu-worker uncordoned
```

### Step 4: Verify vLLM Reschedules

Wait for vLLM to reschedule (Deployment has 1 replica):

```bash
# Watch pod scheduling
kubectl get pods -n ml -l app=vllm-server -w

# Should see:
# vllm-server-XXXXX   0/1   ContainerCreating   0   5s
# vllm-server-XXXXX   0/1   Running             0   15s
# vllm-server-XXXXX   1/1   Running             0   90s  (model loaded)
```

**Timing:** 60-90 seconds for model load (cached on hostPath)

### Step 5: Verify GPU Inference Restored

Test vLLM responds:

```bash
curl -s https://vllm.home.jetzinger.com/health
# Should return 200 OK

curl -s -X POST https://vllm.home.jetzinger.com/v1/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"TheBloke/deepseek-coder-6.7B-instruct-AWQ","prompt":"def hello():","max_tokens":20}' | jq .
```

---

## Expected Behavior During Each Phase

| Phase | vLLM Status | GPU Status | Inference Fallback |
|-------|-------------|------------|-------------------|
| Normal | Running | Available | vLLM GPU (~47 tok/s) |
| Draining | Terminating | Available | Transitioning to Ollama |
| Maintenance | Not scheduled | Unavailable | Ollama CPU (<5s latency) |
| Reconnecting | ContainerCreating | Available | Ollama CPU |
| Model Loading | Running (0/1) | Available | Ollama CPU |
| Restored | Running (1/1) | Available | vLLM GPU (~47 tok/s) |

---

## Timing Requirements

| Metric | Target | Typical |
|--------|--------|---------|
| Drain completion | <30s | ~10-15s |
| GPU unavailability detection (NFR50) | <10s | ~5s |
| Ollama CPU inference (NFR54) | <5s | ~4.2s |
| vLLM pod reschedule | <30s | ~15s |
| Model load (cached) | <90s | ~60s |
| Total reconnection | <3min | ~90s |

---

## Recovery Procedures

### Scenario: nvidia-smi Fails After Reconnect

1. **Check kernel module:**
   ```bash
   ssh tt@100.80.98.64 lsmod | grep nvidia
   ```

2. **Reload nvidia modules:**
   ```bash
   ssh tt@100.80.98.64 sudo modprobe -r nvidia_uvm nvidia_drm nvidia_modeset nvidia
   ssh tt@100.80.98.64 sudo modprobe nvidia
   ```

3. **If persistent failure, reboot:**
   ```bash
   ssh tt@100.80.98.64 sudo reboot
   ```
   Node will rejoin cluster automatically after reboot.

### Scenario: vLLM Pod Stuck in Pending

1. **Check events:**
   ```bash
   kubectl describe pod -n ml -l app=vllm-server
   ```

2. **Verify GPU allocatable:**
   ```bash
   kubectl describe node k3s-gpu-worker | grep -A 5 "Allocatable"
   # Should show: nvidia.com/gpu: 1
   ```

3. **Check GPU device plugin:**
   ```bash
   kubectl get pods -n gpu-operator -l app=nvidia-device-plugin-daemonset
   kubectl logs -n gpu-operator -l app=nvidia-device-plugin-daemonset --tail=50
   ```

4. **Restart device plugin if needed:**
   ```bash
   kubectl delete pod -n gpu-operator -l app=nvidia-device-plugin-daemonset
   ```

### Scenario: Ollama Fallback Slow

1. **Check if model needs loading:**
   ```bash
   kubectl logs -n ml deploy/ollama --tail=20
   ```

2. **Pre-warm model:**
   ```bash
   kubectl exec -it deploy/ollama -n ml -- curl -s -X POST http://localhost:11434/api/generate \
     -d '{"model":"llama3.2:1b","prompt":"hi","stream":false}'
   ```

---

## Validation Checklist

**After Disconnect:**

- [ ] `kubectl get nodes` shows k3s-gpu-worker as Ready,SchedulingDisabled
- [ ] vLLM pod evicted (no pods with app=vllm-server)
- [ ] vLLM /health endpoint unreachable or returns error
- [ ] Ollama API responds with inference results
- [ ] n8n workflows (if active) continue via CPU fallback

**After Reconnect:**

- [ ] `nvidia-smi` shows RTX 3060 on host
- [ ] `kubectl get node k3s-gpu-worker` shows Ready (no SchedulingDisabled)
- [ ] vLLM pod Running (1/1 Ready)
- [ ] vLLM /health returns 200 OK
- [ ] vLLM /v1/completions returns generated text
- [ ] Performance restored (~47 tok/s)

---

## Quick Mode Switching (Gaming vs ML)

For simpler mode switching without hardware disconnect (e.g., switching to/from Steam gaming):

```bash
# SSH to Intel NUC
ssh tt@100.80.98.64

# Switch to Gaming Mode (release GPU for Steam)
gpu-mode gaming
# Completion: ~6s

# Switch to ML Mode (restore vLLM inference)
gpu-mode ml
# Completion: ~38s

# Check current status
gpu-mode status
```

The `gpu-mode` script handles vLLM scaling and waits for proper termination/readiness. See [Steam Setup Guide](../../scripts/gpu-worker/steam-setup.md) for gaming configuration.

---

## Related Documentation

- [vLLM README](../../applications/vllm/README.md) - Graceful degradation configuration
- [Node Removal Runbook](node-removal.md) - General node drain procedures
- [Fallback ConfigMap](../../applications/vllm/fallback-config.yaml) - n8n routing configuration
- [Steam Setup Guide](../../scripts/gpu-worker/steam-setup.md) - Gaming configuration
- [gpu-mode script](../../scripts/gpu-worker/gpu-mode) - Mode switching script
- [NVIDIA GPU Operator](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/)

---

## Revision History

| Date | Version | Changes |
|------|---------|---------|
| 2026-01-12 | 1.0 | Initial creation - Story 12.5 (FR73, FR74, NFR50, NFR54) |
| 2026-01-13 | 1.1 | Added Quick Mode Switching section - Story 13.2 |
