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
     - Hostname/IP: `192.168.2.20/30` (k3s nodes .20-.23 only)
     - Privilege: Read/Write
     - Squash: **No mapping** (see "Why No mapping" below)
     - Enable asynchronous: Yes
     - Allow connections from non-privileged ports: Yes
     - Allow users to access mounted subfolders: Yes

#### Why "No mapping" (2026-09-28)

**Applied 2026-09-28.** `/etc/exports` on the NAS now reads
`/volume1/k8s-data 192.168.2.20/30(rw,...,no_root_squash,...)` (was `192.168.2.0/24` with
`root_squash,anonuid=1024`). Verified: the check below returns `uid=0`, and a throwaway PVC written
as UID 1001 with a `0700` folder and a `0600` file was deleted cleanly - PV gone, folder gone
from the NAS, provisioner logged `succeeded`. To read the export yourself, run
`ssh -t nas 'sudo cat /etc/exports'` in a real terminal (sudo needs one for the password).

This README used to prescribe "Map all users to admin". The NAS did not actually do that: files
kept their owners (valkey wrote as UID 1001; CNPG's `pgdata` is UID 26, mode 0700), and only **root** was
mapped to UID 1024 - which is "Map root to admin".

That broke volume deletion. The provisioner runs as root, arrives at the NAS as 1024, and cannot
remove files an app wrote as another user with owner-only permissions. With
`reclaimPolicy: Delete` and `archiveOnDelete: false`, a deleted PVC should remove its folder;
instead the provisioner logged `unlinkat ...: permission denied` 15 times and gave up
(`failures 15 >= threshold 15`). The PV stayed `Released` and the data stayed on the NAS. Four
such volumes (Gitea valkey x3, moltbot) had sat there since January.

"No mapping" lets root on the nodes act as root on this share, so deletes work. The trade-off:
any host the rule allows gets full root on `k8s-data`. That is why the rule is limited to
`192.168.2.20/30`. NFS clients seen by the NAS on 2026-09-28: `.20`, `.21`, `.22` (NFSv4.1).

Do **not** use "Map all users to ...": it would rewrite every app's file ownership and break
anything that checks it - PostgreSQL refuses to start unless it owns its data directory.

**Verify the setting** - root must arrive as root:

```bash
cat <<'EOF' | kubectl --context default apply -f -
apiVersion: v1
kind: Pod
metadata: {name: nfs-whoami, namespace: default}
spec:
  restartPolicy: Never
  containers:
  - name: c
    image: busybox:1.36
    command: ["sh","-c","f=/nfs/.squash-test-$$; touch $f && stat -c 'uid=%u gid=%g' $f; rm -f $f"]
    volumeMounts: [{name: nfs, mountPath: /nfs}]
  volumes: [{name: nfs, nfs: {server: 192.168.2.2, path: /volume1/k8s-data}}]
EOF
kubectl --context default logs nfs-whoami     # want uid=0; uid=1024 means root is still squashed
kubectl --context default delete pod nfs-whoami
```

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
2. Squash setting is "No mapping" (see Prerequisites)
3. Folder permissions on Synology

### PV stuck in `Released` after deleting a PVC

**Symptom:** `kubectl --context default get pv` shows `Released` long after the PVC was deleted,
and the folder is still under `/volume1/k8s-data/`.

**Cause:** the provisioner could not delete the folder - almost always root squashing (see
"Why No mapping"). Confirm in its log:

```bash
kubectl --context default -n infra logs deploy/nfs-provisioner-nfs-subdir-external-provisioner \
  | grep -E 'VolumeFailedDelete|permission denied'
```

**Fix:** correct the squash setting, then restart the provisioner so it retries. If the setting
cannot be changed, clean up by hand - first check the folder really belongs to a retired app:

```bash
kubectl --context default delete pv <pv-name>
ssh -t nas 'cd /volume1/k8s-data && sudo rm -rf -- <namespace>-<pvc-name>-<pv-name>'
```

Deleting the PV object alone does **not** remove the data.

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
