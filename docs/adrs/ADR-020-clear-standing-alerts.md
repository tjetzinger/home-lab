# ADR-020: Clear the Standing Alerts

**Status:** Accepted
**Date:** 2026-09-28
**Related:** [ADR-019](ADR-019-tailscale-lan-policy-rule.md) (the other 5 alerts, and the new
control-plane page), [ADR-016](ADR-016-cluster-update-campaign.md) (the update campaign before this)

## Context

On the morning of 2026-09-28, **11 alerts** were active. Five came from the master's routing fault
(ADR-019). Watchdog always fires by design. The other five had become background noise:

| Alert | Source | Active since |
|---|---|---|
| `KubePodNotReady`, `KubeDaemonSetRolloutStuck` | `nvidia-operator-validator` never Ready | install day, 2026-01-12 |
| `KubeDaemonSetMisScheduled`, `KubeDaemonSetRolloutStuck` | NFD worker on `k3s-nas-worker` | when that node was tainted |
| `CPUThrottlingHigh` | node-exporter on several nodes | recurring, pending/firing |

Standing alerts cost more than their own noise. They teach that "some alerts are always there",
and that is how the master's four-day outage went unseen.

## Decisions

### 1. GPU operator: skip the validator's CUDA workload

`nvidia-cuda-validator` failed on every run with CUDA error 804:

```
Failed to allocate device vector A (error code forward compatibility was attempted on non supported HW)!
```

The validator image (`gpu-operator:v25.10.1`) ships CUDA **forward-compatibility** libraries
(`/usr/local/cuda/compat`) newer than the host driver, 570.211.01 / CUDA 12.8. Forward compatibility
only works on datacenter GPUs, so on the GeForce RTX 3060 the test can never pass. The host's own
`libcuda` is clean 570; vLLM used the GPU the whole time. Story 12.3 recorded the error as
"expected" on day one, and it then alerted for 8 months.

**Fix:** `validator.cuda.env: WITH_WORKLOAD=false`. Checked in the v25.10.1 source
(`cmd/nvidia-validator/main.go`): the flag skips only the vectorAdd test pod. Driver and toolkit
validation still run, and the status file is still written.

**Rejected:** upgrading the host driver to 580 (CUDA 13) only to satisfy a test. 580 had already been
installed and removed on this host once; the reason is not recorded. The driver choice should
follow vLLM's needs, not the validator's.

### 2. NFD worker tolerates the "lightweight" taint

`k3s-nas-worker` carries `workload-type=lightweight:NoSchedule`. The NFD worker pod ran there from
before the taint, so the DaemonSet wanted 4 pods but had 5, and counted one as mis-scheduled.
Node feature discovery is a small labelling DaemonSet, so it fits the taint's intent. It now
tolerates the taint: desired 5, ready 5.

### 3. The GPU operator's values are now in git

The release was installed with `--set` flags in Story 12.3 and had no values file.
`infrastructure/gpu-operator/values-homelab.yaml` now reproduces the release, plus decisions 1 and 2.
A server-side dry-run diff showed exactly those two changes before the upgrade.

### 4. node-exporter has no CPU limit

node-exporter averages about **2m** CPU, but each scrape is a short burst. Against the 200m limit,
the CFS scheduler throttled **22-37%** of periods on the CPU workers and the master (7-day
average). The limit protected nothing and kept `CPUThrottlingHigh` coming back. The CPU limit is
removed; the request (50m) and the memory limit (128Mi) stay. The dry-run diff was one line.

## Result

| | Before | After |
|---|---|---|
| Active alerts | 11 | 1 (`Watchdog`, by design) |
| `nvidia-operator-validator` | 0/1, `Init:CrashLoopBackOff` | 1/1 Running |
| NFD worker DaemonSet | desired 4, running 5 | desired 5, ready 5 |
| node-exporter throttled periods | 22-37% | none (no CFS quota) |

Checked at 11:04 UTC, after two master reboots had settled.

## Also done the same day

- Purged the leftover 535 and 580 NVIDIA packages from `k3s-gpu-worker` (11 packages; 8 were
  config-only). The loaded driver, firmware and DKMS module are all 570. The boot image was rebuilt
  by the purge; the GPU worker has **not** been rebooted since.
- `docs/runbooks/egpu-hotplug.md` now shows real 570 `nvidia-smi` output and explains what a
  crash-looping `nvidia-cuda-validator` pod means.

## Consequences

- **Remove `WITH_WORKLOAD=false`** only if the host driver moves to a branch at least as new as the
  validator image's CUDA. A future operator upgrade may ship newer compat libraries; the setting
  stays correct either way.
- **A crash-looping `nvidia-cuda-validator-*` pod** now means the setting was lost. Re-run the
  upgrade from the values file.
- **Any new DaemonSet meant for every node** must tolerate `workload-type=lightweight`, or it will
  skip `k3s-nas-worker`.
- **Still open:** nothing in the cluster can report a dead master (ADR-019). That needs a dead-man
  switch outside the cluster.
