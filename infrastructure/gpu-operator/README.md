# NVIDIA GPU Operator

Runs the Kubernetes side of the GPU on `k3s-gpu-worker`: device plugin, GPU feature discovery,
DCGM exporter and the operator validator. Deployed in Story 12.3; decisions in
[ADR-020](../../docs/adrs/ADR-020-clear-standing-alerts.md).

| | |
|---|---|
| Chart | `nvidia/gpu-operator` v25.10.1 (`https://helm.ngc.nvidia.com/nvidia`) |
| Namespace | `gpu-operator` |
| Values | `values-homelab.yaml` |
| Host driver | `nvidia-driver-570-server` 570.211.01 (CUDA 12.8), installed on the node, not by the operator |

## Deploy / upgrade

```bash
helm upgrade --install gpu-operator nvidia/gpu-operator --version v25.10.1 \
  -n gpu-operator -f infrastructure/gpu-operator/values-homelab.yaml
```

Check the change first with `--dry-run=server` and compare against
`helm get manifest gpu-operator -n gpu-operator`.

## What the values do

- **`driver.enabled: false`, `toolkit.enabled: false`** - the driver and container toolkit live on
  the host. The operator never touches them.
- **Tolerations for `gpu=true:NoSchedule`** - the GPU worker's taint.
- **`validator.cuda.env: WITH_WORKLOAD=false`** - the validator's CUDA test can never pass on a
  GeForce card (forward-compat error 804). Driver and toolkit validation still run.
- **NFD worker tolerates `workload-type=lightweight`** - so it runs on `k3s-nas-worker` too.

## Healthy state

```bash
kubectl --context default -n gpu-operator get ds        # every DaemonSet DESIRED == READY
kubectl --context default -n gpu-operator get pods      # all Running/Completed; no nvidia-cuda-validator-*
kubectl --context default get node k3s-gpu-worker \
  -o jsonpath='{.status.allocatable.nvidia\.com/gpu}'   # 1
```

A `nvidia-cuda-validator-*` pod in `Init:CrashLoopBackOff` means the `WITH_WORKLOAD` setting was
lost. Re-run the upgrade above. For eGPU disconnects, see `docs/runbooks/egpu-hotplug.md`.
