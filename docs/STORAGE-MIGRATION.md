# Storage Migration Guide

When migrating from Docker Compose to Kubernetes, you can keep using your
existing network shares (SMB, NFS, …). The chart provisions the necessary
StorageClasses and PVCs to point at those shares rather than allocating
fresh block storage.

## Overview

```
Docker Compose:                    Kubernetes:
/Volumes (host bind mount)  ====>  SMB/NFS share

                                   ↓ CSI driver
                                   ↓
                                   StorageClass
                                   ↓
                                   PVC (new)
                                   ↓
                                   Pod mounts /Volumes/Helmut
```

---

## Scenario: SMB share migration

### Step 1 — install the CSI driver

```bash
# SMB CSI driver (Azure)
helm repo add smb-csi-driver \
  https://raw.githubusercontent.com/kubernetes-csi/csi-driver-smb/master/charts
helm install csi-driver-smb smb-csi-driver/csi-driver-smb \
  --namespace kube-system

# NFS CSI driver (alternative)
helm repo add nfs-subdir-external-provisioner \
  https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
helm install nfs-subdir-external-provisioner \
  nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
  --namespace kube-system \
  --set nfs.server=nfs-server.example.com \
  --set nfs.path=/exports
```

### Step 2 — create SMB credentials (if required)

```bash
# Either populate the chart values (preferred — let the chart create the
# Secret as part of the release):
#
#   credentials:
#     storage:
#       smb:
#         username: "admin"
#         password: "..."
#
# Or create the Secret out-of-band:
kubectl create secret generic smb-creds \
  --from-literal=username=admin \
  --from-literal=password=your-password \
  -n helmut4
```

### Step 3 — adapt `values-migration-pv-names.yaml`

```yaml
global:
  storage:
    csiDriver: "smb.csi.k8s.io"          # SMB CSI driver
    storageClassName: "helmut4-csi-storage"
    volumes:
      - name: helmut-storage
        mountPath: "/Volumes/Helmut"
        size: "100Gi"
        # Existing SMB share (from the Docker Compose deployment)
        source: "//storage-server.local/helmut-volumes"
        appMount: true
```

### Step 4 — install via Helm

```bash
helm install helmut4 helmut4/ \
  -f examples/values-migration-pv-names.yaml \
  -n helmut4 \
  --create-namespace
```

### Step 5 — verify

```bash
# PVCs bound?
kubectl -n helmut4 get pvc
# NAME                   STATUS  VOLUME              CAPACITY
# helmut-storage-pvc     Bound   pvc-...             100Gi

# Pods seeing the volume?
kubectl -n helmut4 get pods -o wide
kubectl -n helmut4 exec <pod> -- mount | grep helmut
kubectl -n helmut4 exec <pod> -- ls -la /Volumes
```

---

## Scenario: NFS share migration

### Step 1 — install the NFS CSI driver

```bash
helm repo add nfs-subdir-external-provisioner \
  https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/

helm install nfs-provisioner \
  nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
  --namespace kube-system \
  --set nfs.server=nfs-server.example.com \
  --set nfs.path=/exports/helmut
```

### Step 2 — configure `values.yaml`

```yaml
global:
  storage:
    csiDriver: "nfs.csi.k8s.io"         # NFS CSI driver
    storageClassName: "nfs-helmut"
    volumes:
      - name: helmut-storage
        mountPath: "/Volumes/Helmut"
        size: "100Gi"
        # NFS share, format: server:/path
        source: "nfs-server.example.com:/exports/helmut-volumes"
        appMount: true
      - name: mongobackup
        mountPath: "/Volumes/Backup"
        size: "50Gi"
        source: "nfs-server.example.com:/exports/mongodb-backups"
        appMount: false
```

### Step 3 — install

```bash
helm install helmut4 helmut4/ \
  -f examples/values-migration-pv-names.yaml \
  -n helmut4 \
  --create-namespace
```

---

## Scenario: no external share (dynamic provisioning)

If you don't have an existing share and want Kubernetes to allocate storage
dynamically:

```yaml
global:
  storage:
    csiDriver: "pd.csi.storage.gke.io"   # GKE / Azure / AWS CSI driver
    storageClassName: "helmut4-csi-storage"
    volumes:
      - name: helmut-storage
        mountPath: "/Volumes/Helmut"
        size: "100Gi"
        source: ""                        # empty source = dynamic provisioning
        appMount: true
      - name: mongobackup
        mountPath: "/Volumes/Backup"
        size: "50Gi"
        source: ""                        # empty source = dynamic provisioning
        appMount: false
```

---

## Troubleshooting

### PVC stuck in `Pending`

```bash
kubectl -n helmut4 describe pvc helmut-storage-pvc

# Likely causes:
# 1. CSI driver not installed
kubectl get csinode
kubectl get storageclass

# 2. Share unreachable
kubectl -n kube-system logs -l app.kubernetes.io/name=csi-driver-smb

# 3. Wrong credentials — inspect the Secret:
kubectl get secret smb-creds -n kube-system -o yaml
```

### Pod cannot mount the volume

```bash
# Pod logs
kubectl -n helmut4 logs <pod> -c <container>

# Events
kubectl -n helmut4 describe pod <pod>

# CSI driver logs
kubectl -n kube-system logs -l app=csi-driver-smb -f
```

### Share connection drops

```bash
# Network reachability
kubectl -n helmut4 exec <pod> -- ping storage-server.local

# Auth check
kubectl -n helmut4 exec <pod> -- smbclient -L //storage-server.local
```

---

## Best practices

### 1. Verify the share has enough free space

```bash
# Host side — check the SMB share size
net view \\storage-server /share

# Linux / NFS
df -h /mnt/helmut-volumes

# The size you declare in values.yaml must be ≤ what the share can serve.
```

### 2. Back up before migrating

```bash
# Copy the data out of the Docker Compose volume
docker run --rm \
  -v helmut-volumes:/data \
  alpine:latest \
  tar czf /backup/helmut-volumes.tar.gz /data
```

### 3. Handle credentials safely

```bash
# For SMB: use a Secret rather than committing the password to values.yaml
kubectl create secret generic smb-migration-creds \
  --from-literal=username=admin \
  --from-literal=password=<password> \
  -n helmut4
```

### 4. Performance tuning

```yaml
# Driver-specific parameters belong on the StorageClass.
# Example knobs (the names are CSI-driver-specific): blocksize,
# cachingMode, mountOptions[], …
```

### 5. Monitoring

```bash
# Storage utilisation
kubectl -n helmut4 exec <pod> -- df -h /Volumes

# PVC state
kubectl -n helmut4 get pvc -w

# Storage-related events
kubectl -n helmut4 get events --sort-by='.lastTimestamp'
```

---

## Rollback

If the migration doesn't work out:

```bash
# Remove the Helm release (PVCs are retained by default)
helm uninstall helmut4 -n helmut4

# Bring the Docker Compose deployment back up
docker-compose up -d

# Or fix the values and try again
helm upgrade helmut4 helmut4/ \
  -f examples/values-migration-pv-names.yaml \
  -n helmut4
```

---

## CSI driver overview

| Storage             | CSI driver               | Installation              |
|---------------------|--------------------------|---------------------------|
| SMB / CIFS          | `smb.csi.k8s.io`         | Azure CSI driver          |
| NFS                 | `nfs.csi.k8s.io`         | NFS Subdir Provisioner    |
| GCP Persistent Disk | `pd.csi.storage.gke.io`  | GKE default               |
| AWS EBS             | `ebs.csi.aws.com`        | AWS EBS CSI               |
| Azure Disk          | `disk.csi.azure.com`     | Azure CSI                 |
| Ceph RBD            | `rbd.csi.ceph.io`        | Ceph operator             |
| Longhorn            | `driver.longhorn.io`     | Longhorn                  |
