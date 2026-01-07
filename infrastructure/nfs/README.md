# NFS Storage Provisioner

This directory contains the configuration for the NFS dynamic storage provisioner, which enables automatic PersistentVolume creation for applications requesting storage.

## Overview

| Component | Details |
|-----------|---------|
| **Provisioner** | nfs-subdir-external-provisioner |
| **StorageClass** | nfs-client (default) |
| **NFS Server** | Synology DS920+ (192.168.2.2) |
| **Export Path** | /volume1/k8s-data |
| **Namespace** | infra |

## Prerequisites

### NFS Server Configuration (Synology)

1. **Enable NFS Service:**
   - DSM → Control Panel → File Services → NFS tab
   - Enable NFS service
   - Set maximum protocol to NFSv4.1

2. **Create Shared Folder:**
   - Control Panel → Shared Folder → Create `k8s-data`
   - Location: Volume 1

3. **Configure NFS Permissions:**
   - Edit `k8s-data` → NFS Permissions → Create rule:
     - Hostname/IP: `192.168.2.0/24`
     - Privilege: Read/Write
     - Squash: Map all users to admin
     - Enable asynchronous: Yes
     - Allow connections from non-privileged ports: Yes
     - Allow users to access mounted subfolders: Yes

### Cluster Node Requirements

All K3s nodes must have NFS utilities installed:

```bash
# On each node (Ubuntu/Debian)
apt-get update && apt-get install -y nfs-common
```

## Installation

### 1. Add Helm Repository

```bash
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
helm repo update
```

### 2. Create Namespace

```bash
kubectl create namespace infra
```

### 3. Deploy Provisioner

```bash
helm install nfs-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
  -f values-homelab.yaml \
  -n infra
```

### 4. Verify Installation

```bash
# Check pod is running
kubectl get pods -n infra

# Check StorageClass exists
kubectl get storageclass

# Verify nfs-client is default
kubectl describe storageclass nfs-client
```

## Files

| File | Purpose |
|------|---------|
| `values-homelab.yaml` | Helm values for NFS provisioner configuration |
| `README.md` | This documentation |

## Usage

Once installed, applications can request storage using PersistentVolumeClaims:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-app-data
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  # storageClassName: nfs-client  # Optional - nfs-client is default
```

The provisioner will automatically create a subdirectory on the NFS share:
```
/volume1/k8s-data/{namespace}-{pvc-name}-{pv-id}/
```

### Complete Example with Test Pod

```yaml
# 1. Create namespace for testing
kubectl create namespace test-storage

# 2. Create PVC
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
  namespace: test-storage
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi

# 3. Create pod that mounts the PVC
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
  namespace: test-storage
spec:
  containers:
    - name: test
      image: busybox
      command: ["sleep", "3600"]
      volumeMounts:
        - name: data
          mountPath: /data
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: test-pvc
```

### Verification Commands

```bash
# Check PVC is Bound
kubectl get pvc -n test-storage

# Verify mount inside pod
kubectl exec -n test-storage test-pod -- df -h /data

# Write test data
kubectl exec -n test-storage test-pod -- sh -c 'echo "test" > /data/test.txt'

# Cleanup
kubectl delete pod test-pod -n test-storage
kubectl delete pvc test-pvc -n test-storage
kubectl delete namespace test-storage
```

## Validation Status

**Validated:** 2026-01-05 (Story 2.2)

| Test | Result |
|------|--------|
| PVC binds within 30 seconds | PASS |
| Volume mounts within 10 seconds | PASS |
| Data persists on NFS | PASS |
| Data survives pod restart | PASS |
| Reclaim policy (Delete) works | PASS |

## Troubleshooting

### Pod stuck in ContainerCreating

**Symptom:** Pods using NFS PVCs stay in `ContainerCreating` state.

**Cause:** NFS client utilities not installed on the node.

**Fix:**
```bash
# SSH to the affected node
ssh root@<node-ip>
apt-get install -y nfs-common
```

### Mount failed: bad option

**Symptom:** Error message about needing `/sbin/mount.<type>` helper.

**Cause:** Same as above - `nfs-common` not installed.

### NFS server not responding

**Symptom:** `showmount -e 192.168.2.2` fails or times out.

**Check:**
1. NFS service enabled on Synology
2. Firewall not blocking NFS ports (2049, 111)
3. Network connectivity: `ping 192.168.2.2`

### Permission denied on NFS mount

**Symptom:** Pods can't write to mounted volumes.

**Check:**
1. NFS permissions allow the node IPs
2. Squash setting is correct (Map all users to admin)
3. Folder permissions on Synology

## Uninstallation

```bash
helm uninstall nfs-provisioner -n infra
kubectl delete namespace infra
```

**Warning:** This does not delete existing PVCs or data on the NFS share.

## References

- [NFS Subdir External Provisioner](https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner)
- [Synology NFS Setup](https://kb.synology.com/en-us/DSM/tutorial/How_to_access_files_on_Synology_NAS_within_the_local_network_NFS)
- [Architecture: Storage Architecture](../../docs/planning-artifacts/architecture.md#storage-architecture)
