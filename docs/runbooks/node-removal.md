# Node Removal Runbook

This runbook documents the procedure for safely removing a worker node from the K3s cluster, including maintenance operations and rejoining procedures.

## Overview

| Item | Details |
|------|---------|
| **Scope** | K3s worker node removal and rejoin |
| **Impact** | Pods on target node will be evicted |
| **Duration** | 5-10 minutes |
| **Risk Level** | Low (with proper procedure) |

## Prerequisites

Before starting:

1. **Cluster Access**: Verify kubectl works
   ```bash
   kubectl get nodes
   ```

2. **Node Identification**: Confirm target node exists
   ```bash
   kubectl get node <node-name>
   ```

3. **Workload Review**: Check what's running on the target node
   ```bash
   kubectl get pods -A -o wide | grep <node-name>
   ```

4. **Capacity Check**: Ensure remaining nodes have capacity
   ```bash
   kubectl top nodes  # requires metrics-server
   kubectl describe nodes | grep -A 5 "Allocated resources"
   ```

## Node Topology Reference

| Node | Role | IP | Proxmox VMID |
|------|------|-----|--------------|
| k3s-master | Control plane | 192.168.2.20 | 100 |
| k3s-worker-01 | General compute | 192.168.2.21 | 102 |
| k3s-worker-02 | General compute | 192.168.2.22 | 103 |

---

## Procedure 1: Remove Worker Node

### Step 1: Drain the Node

Evict all pods from the target node (excluding DaemonSets):

```bash
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data
```

**Expected Output:**
```
node/<node-name> cordoned
Warning: ignoring DaemonSet-managed Pods: kube-system/svclb-traefik-XXXXX
evicting pod default/test-drain-XXXXXXXXX-XXXXX
pod/test-drain-XXXXXXXXX-XXXXX evicted
node/<node-name> drained
```

**Flags Explained:**
- `--ignore-daemonsets`: DaemonSets are node-local; don't try to evict them
- `--delete-emptydir-data`: Allow eviction of pods with emptyDir volumes (ephemeral data will be lost)

**Verify pods rescheduled:**
```bash
kubectl get pods -o wide
```

All non-DaemonSet pods should now show on other nodes.

### Step 2: Delete the Node

Remove the node from the cluster:

```bash
kubectl delete node <node-name>
```

**Expected Output:**
```
node "<node-name>" deleted
```

**Verify removal:**
```bash
kubectl get nodes
```

Should show only remaining nodes.

> **Note**: The LXC container/VM is still running - only the Kubernetes node object is deleted.

### Step 3: Stop K3s Agent (Optional)

If you want to fully stop K3s on the removed node:

```bash
# Via SSH to the node
ssh root@<node-ip> systemctl stop k3s-agent

# Or via Proxmox (if LXC container)
pct exec <vmid> -- systemctl stop k3s-agent
```

---

## Procedure 2: Rejoin Node to Cluster

### Step 1: Get Join Token

Retrieve the node token from the master:

```bash
# Via SSH
ssh root@192.168.2.20 cat /var/lib/rancher/k3s/server/node-token

# Or via Proxmox
pct exec 100 -- cat /var/lib/rancher/k3s/server/node-token
```

### Step 2: Restart K3s Agent

If K3s agent is already installed (most common case):

```bash
# Via SSH to the worker node
ssh root@<node-ip> systemctl restart k3s-agent

# Or via Proxmox
pct exec <vmid> -- systemctl restart k3s-agent
```

**Alternative - Fresh Installation:**

If K3s agent needs to be reinstalled:

```bash
# On the worker node
curl -sfL https://get.k3s.io | K3S_URL=https://192.168.2.20:6443 K3S_TOKEN=<token> sh -
```

Or use the installation script:
```bash
./infrastructure/k3s/install-worker.sh
```

### Step 3: Verify Node Rejoined

```bash
kubectl get nodes
```

**Expected Output:**
```
NAME            STATUS   ROLES                  AGE   VERSION
k3s-master      Ready    control-plane,master   Xh    v1.34.3+k3s1
k3s-worker-01   Ready    <none>                 Xh    v1.34.3+k3s1
k3s-worker-02   Ready    <none>                 Xs    v1.34.3+k3s1
```

The rejoined node will show a very recent age (seconds/minutes).

### Step 4: Uncordon if Necessary

If the node shows `SchedulingDisabled`:

```bash
kubectl uncordon <node-name>
```

Usually not required after a fresh join, but may be needed if the node was only cordoned (not deleted).

---

## Recovery Procedures

### Scenario: Drain Stuck on PodDisruptionBudget

If drain hangs due to PDB constraints:

```bash
# Check PDB status
kubectl get pdb -A

# Force drain (use with caution - may cause brief unavailability)
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data --force
```

### Scenario: Node Won't Rejoin

1. **Check K3s agent logs:**
   ```bash
   pct exec <vmid> -- journalctl -u k3s-agent -f
   ```

2. **Verify network connectivity:**
   ```bash
   pct exec <vmid> -- ping 192.168.2.20
   pct exec <vmid> -- curl -k https://192.168.2.20:6443
   ```

3. **Verify token is valid:**
   ```bash
   # Token should match on master
   pct exec 100 -- cat /var/lib/rancher/k3s/server/node-token
   ```

4. **Full reinstall if needed:**
   ```bash
   # Uninstall K3s agent
   pct exec <vmid> -- /usr/local/bin/k3s-agent-uninstall.sh

   # Reinstall
   pct exec <vmid> -- bash -c 'curl -sfL https://get.k3s.io | K3S_URL=https://192.168.2.20:6443 K3S_TOKEN=<token> sh -'
   ```

### Scenario: Pods Not Rescheduling

1. **Check pending pods:**
   ```bash
   kubectl get pods -A | grep Pending
   kubectl describe pod <pod-name> -n <namespace>
   ```

2. **Check node resources:**
   ```bash
   kubectl describe nodes | grep -A 10 "Allocated resources"
   ```

3. **Check for node affinity/taints:**
   ```bash
   kubectl get pods <pod-name> -o yaml | grep -A 5 nodeSelector
   kubectl get pods <pod-name> -o yaml | grep -A 5 affinity
   ```

---

## Validation Checklist

After node removal:

- [ ] `kubectl get nodes` shows expected node count
- [ ] All pods previously on removed node are now Running elsewhere
- [ ] No pods in Pending state (unless expected)
- [ ] Applications remain accessible

After node rejoin:

- [ ] `kubectl get nodes` shows node as Ready
- [ ] Node is schedulable (no `SchedulingDisabled` status)
- [ ] DaemonSets are running on the rejoined node
- [ ] New pods can be scheduled to the node

---

## Related Documentation

- [K3s Node Management](https://docs.k3s.io/reference/server-config)
- [Kubernetes: Safely Drain a Node](https://kubernetes.io/docs/tasks/administer-cluster/safely-drain-node/)
- [install-worker.sh](../../infrastructure/k3s/install-worker.sh) - Worker join script

---

## Revision History

| Date | Version | Changes |
|------|---------|---------|
| 2026-01-05 | 1.0 | Initial creation - validated with k3s-worker-02 removal/rejoin cycle |
