# CSI Driver Konfiguration

## Überblick

Der Helmut4 Chart unterstützt die Montage von externem Storage über CSI (Container Storage Interface) Driver. Dies ermöglicht es, verschiedene Storage-Systeme mit Kubernetes zu integrieren.

## Supported CSI Driver

### Azure Disk CSI Driver
```yaml
global:
  storage:
    csiDriver: "disk.csi.azure.com"
```

Installation:
```bash
helm repo add azuredisk-csi-driver https://raw.githubusercontent.com/kubernetes-sigs/azuredisk-csi-driver/master/charts
helm install azuredisk-csi-driver azuredisk-csi-driver/azuredisk-csi-driver --namespace kube-system
```

### AWS EBS CSI Driver
```yaml
global:
  storage:
    csiDriver: "ebs.csi.aws.com"
```

Installation:
```bash
helm repo add aws-ebs-csi-driver https://kubernetes-sigs.github.io/aws-ebs-csi-driver
helm install aws-ebs-csi-driver aws-ebs-csi-driver/aws-ebs-csi-driver --namespace kube-system
```

### Google Cloud Persistent Disk CSI Driver
```yaml
global:
  storage:
    csiDriver: "pd.csi.storage.gke.io"
```

## Storage Class Definition

Der Chart erstellt automatisch eine StorageClass namens `helmut4-csi-storage`:

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: helmut4-csi-storage
provisioner: <your-csi-driver>
parameters:
  type: pd-ssd
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
```

## Konfiguration im Chart

```yaml
global:
  storage:
    csiDriver: "disk.csi.azure.com"      # CSI Driver Name
    volumePath: "/mnt/helmut"            # Mount Path in Container
    volumeSize: "100Gi"                  # Größe des Volumes
```

## Persistent Volume Claims

Der Chart erstellt zwei PVCs:

### 1. Helmut Storage PVC
```yaml
metadata:
  name: helmut-storage-pvc
spec:
  accessModes:
    - ReadWriteMany              # Für mehrere Pods
  storageClassName: helmut4-csi-storage
  resources:
    requests:
      storage: 100Gi            # Konfigurierbar
```

Verwendet von Services:
- fx
- co
- io
- users
- streams
- license
- xmlgenerator

### 2. MongoDB Backup PVC
```yaml
metadata:
  name: mongodb-backup-pvc
spec:
  accessModes:
    - ReadWriteOnce             # Nur ein Pod
  storageClassName: fast-ssd
  resources:
    requests:
      storage: 50Gi
```

## Troubleshooting

### PVC bleibt Pending
```bash
# PVC Status prüfen
kubectl get pvc -n helmut4

# Details anschauen
kubectl describe pvc helmut-storage-pvc -n helmut4

# CSI Driver Logs
kubectl logs -n kube-system -l app=csi-driver
```

### Pod kann Volume nicht mounten
```bash
# Pod Events prüfen
kubectl describe pod -n helmut4 fx-0

# StorageClass überprüfen
kubectl get storageclass

# Available PVs checken
kubectl get pv
```

### Volume Expansion

```bash
# PVC vergrößern (wenn supportiert)
kubectl patch pvc helmut-storage-pvc -n helmut4 -p \
  '{"spec":{"resources":{"requests":{"storage":"200Gi"}}}}'
```

## Performance Optimization

### Parameter pro CSI Driver

#### Azure
```yaml
kind: StorageClass
parameters:
  skuName: Premium_LRS          # Premium Performance
  location: westeurope
  cachingMode: ReadWrite
```

#### AWS
```yaml
kind: StorageClass
parameters:
  type: gp3                      # GP3 für bessere Performance
  iops: "3000"
  throughput: "125"
```

#### Google Cloud
```yaml
kind: StorageClass
parameters:
  type: pd-ssd                   # SSD für Performance
  replication-type: regional-pd  # Regional für HA
```

## Migration von bestehender Volumes

1. Alte Volumes sichern:
```bash
kubectl cp helmut4/fx-pod:/Users/Shared/Helmut24 ./local-backup
```

2. Neue Volume mit Daten initialisieren
3. Pod neu starten (wird automatisch gemountet)

## Weitere Ressourcen

- [Kubernetes CSI Documentation](https://kubernetes-csi.github.io/)
- [CSI Spec](https://github.com/container-storage-interface/spec)
- [Azure Disk CSI Driver](https://github.com/kubernetes-sigs/azuredisk-csi-driver)
- [AWS EBS CSI Driver](https://github.com/kubernetes-sigs/aws-ebs-csi-driver)
