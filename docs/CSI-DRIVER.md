# CSI Driver Configuration

## Overview

The Helmut4 chart mounts external storage through CSI (Container Storage
Interface) drivers, so any storage backend with a CSI implementation can
back the application volumes — managed cloud disks, SMB / NFS file shares,
Ceph, Longhorn, etc.

## Supported CSI drivers

### Azure Disk CSI driver

```yaml
global:
  storage:
    csiDriver: "disk.csi.azure.com"
```

Installation:

```bash
helm repo add azuredisk-csi-driver \
  https://raw.githubusercontent.com/kubernetes-sigs/azuredisk-csi-driver/master/charts
helm install azuredisk-csi-driver \
  azuredisk-csi-driver/azuredisk-csi-driver \
  --namespace kube-system
```

### AWS EBS CSI driver

```yaml
global:
  storage:
    csiDriver: "ebs.csi.aws.com"
```

Installation:

```bash
helm repo add aws-ebs-csi-driver https://kubernetes-sigs.github.io/aws-ebs-csi-driver
helm install aws-ebs-csi-driver aws-ebs-csi-driver/aws-ebs-csi-driver \
  --namespace kube-system
```

### Google Cloud Persistent Disk CSI driver

```yaml
global:
  storage:
    csiDriver: "pd.csi.storage.gke.io"
```

## StorageClass

The chart generates a StorageClass per declared volume. The class name is
`<storageClassName>-<volume-name>`, so a volume named `helmut-storage`
under `storageClassName: helmut4-csi-storage` yields:

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: helmut4-csi-storage-helmut-storage
provisioner: <your-csi-driver>
parameters:
  source: "//storage-server.example.com/helmut"   # SMB / NFS only
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
```

## Chart configuration

Storage is configured as a list under `global.storage.volumes` — one entry
per PVC/StorageClass the chart should provision:

```yaml
global:
  storage:
    csiDriver: "disk.csi.azure.com"            # CSI driver name
    storageClassName: "helmut4-csi-storage"    # prefix; entry name is appended
    volumes:
      - name: helmut-storage
        mountPath: "/Volumes/Helmut"
        size: "100Gi"
        source: ""                              # empty = dynamic provisioning
        appMount: true                          # mount on every Spring service
                                                # whose values set
                                                # volumeMounts: true
      - name: mongobackup
        mountPath: "/Volumes/Backup"
        size: "50Gi"
        source: ""
        appMount: false                         # PVC only — no app-side mount
```

Set `appMount: false` for volumes that are dedicated to ancillary jobs
(e.g. a backup share) so they don't accidentally get mounted on every
microservice pod.

## Persistent Volume Claims

For the values above the chart provisions:

### `helmut-storage-pvc`

```yaml
metadata:
  name: helmut-storage-pvc
spec:
  accessModes:
    - ReadWriteMany              # shared across all Spring services
  storageClassName: helmut4-csi-storage-helmut-storage
  resources:
    requests:
      storage: 100Gi
```

Mounted into every service whose chart value has `volumeMounts: true` —
by default: `fx`, `co`, `io`, `users`, `streams`, `license`.

### `mongobackup-pvc` (optional)

```yaml
metadata:
  name: mongobackup-pvc
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: helmut4-csi-storage-mongobackup
  resources:
    requests:
      storage: 50Gi
```

Mounted at `/backup` by the optional `mongobackup` Deployment
(`mongobackup.enabled: true`). With that Deployment disabled the PVC is
provisioned but unused. Create the share subfolder before enabling — the
CSI mount fails if the target directory does not exist yet.

## Troubleshooting

### PVC stuck `Pending`

```bash
# Status
kubectl get pvc -n helmut4

# Details
kubectl describe pvc helmut-storage-pvc -n helmut4

# CSI driver logs
kubectl logs -n kube-system -l app=csi-driver
```

### Pod cannot mount the volume

```bash
# Pod events
kubectl describe pod -n helmut4 <pod>

# StorageClass
kubectl get storageclass

# Available PVs
kubectl get pv
```

### Resize a volume

```bash
# Expand the PVC (only when the CSI driver supports it)
kubectl patch pvc helmut-storage-pvc -n helmut4 -p \
  '{"spec":{"resources":{"requests":{"storage":"200Gi"}}}}'
```

## Performance tuning

### Driver-specific parameters

#### Azure

```yaml
kind: StorageClass
parameters:
  skuName: Premium_LRS          # premium disk
  location: westeurope
  cachingMode: ReadWrite
```

#### AWS

```yaml
kind: StorageClass
parameters:
  type: gp3                      # gp3 — better $/IOPS than gp2
  iops: "3000"
  throughput: "125"
```

#### Google Cloud

```yaml
kind: StorageClass
parameters:
  type: pd-ssd                   # SSD-backed
  replication-type: regional-pd  # regional disk for HA
```

## Migrating data from an existing volume

1. Snapshot the source data:

   ```bash
   kubectl cp helmut4/fx-pod:/Volumes/Helmut ./local-backup
   ```

2. Initialise the new volume with the snapshot.
3. Restart the pods — the new PVC gets mounted on next start.

## Further reading

- [Kubernetes CSI documentation](https://kubernetes-csi.github.io/)
- [CSI spec](https://github.com/container-storage-interface/spec)
- [Azure Disk CSI driver](https://github.com/kubernetes-sigs/azuredisk-csi-driver)
- [AWS EBS CSI driver](https://github.com/kubernetes-sigs/aws-ebs-csi-driver)
