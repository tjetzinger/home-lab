# PostgreSQL Backup & Recovery

**Purpose:** Backup and recovery procedures for PostgreSQL database in home-lab cluster

**Story:** 5.3 - Setup PostgreSQL Backup with pg_dump
**Date Created:** 2026-01-06
**Last Updated:** 2026-01-06

---

## Overview

This runbook documents the automated backup system for PostgreSQL using pg_dumpall with gzip compression, storing backups on NFS storage with 7-day retention.

**Backup Components:**
- **CronJob**: `postgres-backup` - Automated daily backups at 2 AM UTC
- **Backup PVC**: `postgres-backup` - 10Gi NFS-backed storage for backup files
- **Backup Method**: pg_dumpall (logical backup of all databases)
- **Compression**: gzip
- **Retention**: Last 7 daily backups

**Key Features:**
- Automated daily backups via Kubernetes CronJob
- NFS-backed persistent storage for backups
- Automatic retention policy (7 days)
- Manual backup trigger capability
- Compressed backups to save storage space

---

## Prerequisites

- PostgreSQL deployed and running (Story 5.1)
- NFS persistence configured (Story 5.2)
- `postgres-backup` CronJob deployed
- `postgres-backup` PVC bound
- kubectl access to cluster

---

## Backup Configuration

### CronJob Details

**CronJob:** `postgres-backup`
**Namespace:** `data`
**Schedule:** `0 2 * * *` (daily at 2 AM UTC)
**Image:** `registry-1.docker.io/bitnami/postgresql:latest`

**Manifest Location:** `/home/tt/Workspace/home-lab/applications/postgres/backup-cronjob.yaml`

### Backup Storage

**PVC:** `postgres-backup`
**Size:** 10Gi
**StorageClass:** nfs-client
**Access Mode:** ReadWriteOnce (RWO)
**NFS Server:** 192.168.2.2 (Synology DS920+)
**NFS Path:** `/volume1/k8s-data/data-postgres-backup-pvc-<uid>/`

**Backup File Pattern:** `postgres-backup-YYYY-MM-DD-HHMMSS.sql.gz`

### Retention Policy

- **Retention Period:** 7 days (last 7 backups)
- **Cleanup:** Automatic (runs after each backup)
- **Method:** `ls -t postgres-backup-*.sql.gz | tail -n +8 | xargs -r rm`

---

## Verify CronJob Configuration

### Check CronJob Status

```bash
# View CronJob
kubectl get cronjob -n data

# Expected output:
# NAME              SCHEDULE    TIMEZONE   SUSPEND   ACTIVE   LAST SCHEDULE   AGE
# postgres-backup   0 2 * * *   <none>     False     0        Xh              Xd

# Describe CronJob
kubectl describe cronjob postgres-backup -n data
```

### Check Backup PVC

```bash
# Verify PVC is bound
kubectl get pvc -n data postgres-backup

# Expected output:
# NAME              STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
# postgres-backup   Bound    pvc-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx   10Gi       RWO            nfs-client     Xd

# Describe PVC
kubectl describe pvc postgres-backup -n data
```

---

## Manual Backup Procedures

### Trigger Manual Backup

```bash
# Create manual backup job from CronJob
kubectl create job --from=cronjob/postgres-backup manual-backup-$(date +%Y%m%d%H%M%S) -n data

# Verify job created
kubectl get jobs -n data

# Monitor job status
kubectl get jobs -n data -w

# Check job logs
kubectl logs -n data job/manual-backup-<timestamp>
```

### Example Manual Backup Log

```
Starting PostgreSQL backup at Mon Jan 06 04:49:22 PM UTC 2026
Backup file: /backup/postgres-backup-2026-01-06-164922.sql.gz
Backup completed successfully
Backup size: 2.2K
Applying retention policy (keep last 7 backups)
removed 'postgres-backup-2026-01-06-165436.sql.gz'
Current backups:
-rw-r--r-- 1 1001 users 2.2K Jan  6 16:54 postgres-backup-2026-01-06-165438.sql.gz
...
Backup job finished at Mon Jan 06 04:49:24 PM UTC 2026
```

---

## List and Verify Backups

### List Backup Files

```bash
# Create temporary pod to list backups
kubectl run backup-list --image=busybox --restart=Never -n data \
  --overrides='{"spec":{"containers":[{"name":"list","image":"busybox","command":["sleep","60"],"volumeMounts":[{"name":"backup","mountPath":"/backup"}]}],"volumes":[{"name":"backup","persistentVolumeClaim":{"claimName":"postgres-backup"}}]}}' && \
  sleep 3 && \
  kubectl exec backup-list -n data -- ls -lh /backup && \
  kubectl delete pod backup-list -n data

# Expected output:
# total 28K
# -rw-r--r--    1 1001     users       2.1K Jan  6 16:54 postgres-backup-2026-01-06-165438.sql.gz
# -rw-r--r--    1 1001     users       2.1K Jan  6 16:54 postgres-backup-2026-01-06-165440.sql.gz
# ...
```

### Verify Backup File Content

```bash
# Create temporary pod to verify backup content
kubectl run backup-verify --image=busybox --restart=Never -n data \
  --overrides='{"spec":{"containers":[{"name":"verify","image":"busybox","command":["sleep","60"],"volumeMounts":[{"name":"backup","mountPath":"/backup"}]}],"volumes":[{"name":"backup","persistentVolumeClaim":{"claimName":"postgres-backup"}}]}}' && \
  sleep 3 && \
  kubectl exec backup-verify -n data -- sh -c "zcat /backup/postgres-backup-*.sql.gz | head -20" && \
  kubectl delete pod backup-verify -n data

# Expected output (first 20 lines of SQL dump):
# --
# -- PostgreSQL database cluster dump
# --
# SET default_transaction_read_only = off;
# SET client_encoding = 'UTF8';
# ...
```

### Count Backup Files

```bash
# Count number of backup files (should be <= 7)
kubectl run backup-count --image=busybox --restart=Never -n data \
  --overrides='{"spec":{"containers":[{"name":"count","image":"busybox","command":["sleep","60"],"volumeMounts":[{"name":"backup","mountPath":"/backup"}]}],"volumes":[{"name":"backup","persistentVolumeClaim":{"claimName":"postgres-backup"}}]}}' && \
  sleep 3 && \
  kubectl exec backup-count -n data -- sh -c "ls -1 /backup/postgres-backup-*.sql.gz | wc -l" && \
  kubectl delete pod backup-count -n data

# Expected output: 7 (or less if fewer backups exist)
```

---

## Restore Procedures

### Restore from Backup (Story 5.4)

**✅ VALIDATED:** Restore procedures have been tested and validated with destructive testing (Story 5.4).

**Quick Restore Steps:**
1. Identify backup file from postgres-backup PVC
2. Create restore pod mounting backup PVC
3. Execute restore: `zcat postgres-backup-YYYY-MM-DD-HHMMSS.sql.gz | psql -U postgres`
4. Verify restored data (row counts, foreign keys, data integrity)
5. Clean up temporary pods

**Validated Performance:**
- Small database (2.2K backup): 2 seconds restore time
- Expected RTO for disaster recovery: < 10 minutes

**For comprehensive restore procedures, disaster recovery scenarios, and troubleshooting, see:** [PostgreSQL Restore Runbook](postgres-restore.md)

---

## Monitoring Backups

### Check Recent Backup Jobs

```bash
# List recent backup jobs (last 3 successful + 3 failed)
kubectl get jobs -n data | grep backup

# View job history
kubectl get cronjob postgres-backup -n data -o jsonpath='{.status.lastScheduleTime}'
kubectl get cronjob postgres-backup -n data -o jsonpath='{.status.lastSuccessfulTime}'
```

### Check Backup Job Logs

```bash
# Get latest backup job name
LATEST_JOB=$(kubectl get jobs -n data -l app.kubernetes.io/component=backup --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1].metadata.name}')

# View logs
kubectl logs -n data job/$LATEST_JOB

# View logs with timestamps
kubectl logs -n data job/$LATEST_JOB --timestamps
```

### Prometheus Metrics (Future Enhancement)

Backup metrics can be exposed to Prometheus for monitoring:
- Last backup timestamp
- Backup success/failure rate
- Backup file size
- Backup duration

---

## Troubleshooting

### Backup Job Failing

**Symptoms:**
- Backup job shows Failed status
- No backup files created

**Diagnosis:**
```bash
# Check job status
kubectl get jobs -n data

# Describe failed job
kubectl describe job <failed-job-name> -n data

# Check pod events
kubectl get pods -n data -l job-name=<failed-job-name>
kubectl describe pod <failed-pod> -n data

# View pod logs
kubectl logs -n data <failed-pod>
```

**Common Issues:**
1. **PostgreSQL connection failure**: Verify PostgreSQL is running and accessible
2. **Permission denied**: Check secret `postgres-postgresql` exists and has correct password
3. **PVC not bound**: Verify `postgres-backup` PVC is bound
4. **Image pull error**: Verify image tag is correct (`:latest` matches PostgreSQL image)

**Resolution:**
```bash
# Verify PostgreSQL is running
kubectl get pods -n data -l app.kubernetes.io/name=postgresql

# Verify secret exists
kubectl get secret postgres-postgresql -n data

# Verify PVC is bound
kubectl get pvc postgres-backup -n data

# Check CronJob image
kubectl get cronjob postgres-backup -n data -o jsonpath='{.spec.jobTemplate.spec.template.spec.containers[0].image}'
```

### Backup Files Not Appearing

**Symptoms:**
- Backup job succeeds but no files in PVC

**Diagnosis:**
```bash
# Check if PVC is mounted correctly
kubectl run backup-debug --image=busybox --restart=Never -n data \
  --overrides='{"spec":{"containers":[{"name":"debug","image":"busybox","command":["sleep","300"],"volumeMounts":[{"name":"backup","mountPath":"/backup"}]}],"volumes":[{"name":"backup","persistentVolumeClaim":{"claimName":"postgres-backup"}}]}}'

kubectl exec backup-debug -n data -- df -h /backup
kubectl exec backup-debug -n data -- ls -la /backup
kubectl delete pod backup-debug -n data
```

**Resolution:**
- Verify PVC is correctly mounted in backup pod
- Check backup script is writing to /backup directory
- Verify file permissions allow writes

### Retention Policy Not Working

**Symptoms:**
- More than 7 backup files exist
- Old backups not deleted

**Diagnosis:**
```bash
# Check number of backup files
kubectl run backup-count --image=busybox --restart=Never -n data --rm -it \
  --overrides='{"spec":{"containers":[{"name":"count","image":"busybox","command":["sh","-c","ls -lt /backup && ls -1 /backup/postgres-backup-*.sql.gz | wc -l"],"volumeMounts":[{"name":"backup","mountPath":"/backup"}]}],"volumes":[{"name":"backup","persistentVolumeClaim":{"claimName":"postgres-backup"}}]}}'
```

**Resolution:**
- Verify retention script in CronJob manifest
- Check backup job logs for retention messages
- Manually delete old backups if needed:

```bash
kubectl run backup-cleanup --image=busybox --restart=Never -n data --rm -it \
  --overrides='{"spec":{"containers":[{"name":"cleanup","image":"busybox","command":["sh","-c","cd /backup && ls -t postgres-backup-*.sql.gz | tail -n +8 | xargs -r rm -v"],"volumeMounts":[{"name":"backup","mountPath":"/backup"}]}],"volumes":[{"name":"backup","persistentVolumeClaim":{"claimName":"postgres-backup"}}]}}'
```

### CronJob Not Running on Schedule

**Symptoms:**
- LAST SCHEDULE shows <none> or old timestamp
- No backup jobs created at 2 AM

**Diagnosis:**
```bash
# Check CronJob status
kubectl get cronjob postgres-backup -n data

# Check if CronJob is suspended
kubectl get cronjob postgres-backup -n data -o jsonpath='{.spec.suspend}'

# View CronJob events
kubectl describe cronjob postgres-backup -n data
```

**Resolution:**
```bash
# Ensure CronJob is not suspended
kubectl patch cronjob postgres-backup -n data -p '{"spec":{"suspend":false}}'

# Verify schedule is correct (0 2 * * * = daily at 2 AM)
kubectl get cronjob postgres-backup -n data -o jsonpath='{.spec.schedule}'

# Manually trigger job to test
kubectl create job --from=cronjob/postgres-backup test-backup-$(date +%Y%m%d%H%M%S) -n data
```

---

## Backup Best Practices

### Regular Verification

- **Monthly**: Verify backup files can be extracted and contain valid SQL
- **Quarterly**: Perform test restore to separate database (Story 5.4)

### Monitoring

- **Daily**: Check LAST SCHEDULE to ensure backups are running
- **Weekly**: Verify backup file count is 7 (or number of days since deployment)
- **Monthly**: Review backup file sizes for anomalies

### Disaster Recovery

- **Offsite Backup**: Consider copying backups to offsite location
- **Restore Testing**: Regularly test restore procedures (Story 5.4)
- **Documentation**: Keep this runbook updated with any changes

### Backup Retention Adjustment

To change retention period (currently 7 days):

1. Edit CronJob manifest: `applications/postgres/backup-cronjob.yaml`
2. Modify retention line: `ls -t postgres-backup-*.sql.gz | tail -n +X | xargs -r rm`
   - Replace X with (desired days + 1)
   - Example: 14 days = `tail -n +15`
3. Apply updated manifest: `kubectl apply -f applications/postgres/backup-cronjob.yaml`

---

## Related Documentation

- [PostgreSQL Setup Runbook](postgres-setup.md)
- [PostgreSQL Deployment README](../../applications/postgres/README.md)
- [Story 5.3 - Setup PostgreSQL Backup](../implementation-artifacts/5-3-setup-postgresql-backup-with-pg-dump.md)
- [Story 5.4 - Validate PostgreSQL Restore](../implementation-artifacts/5-4-validate-postgresql-restore-procedure.md)

---

## Change Log

- 2026-01-06: Initial backup runbook creation - Automated backup system with 7-day retention (Story 5.3)
