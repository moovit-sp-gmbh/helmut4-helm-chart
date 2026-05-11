# Storage Migration Guide

Bei der Migration von Docker Compose zu Kubernetes kannst du bestehende Netzwerk-Shares (SMB, NFS, etc.) wiederverwenden. Das Chart konfiguriert automatisch PVCs, die auf existierende externe Shares zeigen.

## Übersicht

```
Docker Compose:                    Kubernetes:
/Volumes (Host-Mount)      ====>   SMB/NFS Share
MongoDB Backups            ====>   SMB/NFS Share
                                   
                                   ↓ CSI Driver
                                   ↓
                                   StorageClass
                                   ↓
                                   PVC (neu)
                                   ↓
                                   Pod mounts zu /Volumes
```

---

## Scenario: SMB-Share Migration

### Schritt 1: CSI-Treiber installieren

```bash
# SMB CSI Driver (Azure)
helm repo add smb-csi-driver https://raw.githubusercontent.com/kubernetes-csi/csi-driver-smb/master/charts
helm install csi-driver-smb smb-csi-driver/csi-driver-smb \
  --namespace kube-system

# NFS CSI Driver (alternativ)
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
helm install nfs-subdir-external-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
  --namespace kube-system \
  --set nfs.server=nfs-server.example.com \
  --set nfs.path=/exports
```

### Schritt 2: Credentials für SMB-Share erstellen (falls nötig)

```bash
# Für SMB: Secret mit Username/Password erstellen
kubectl create secret generic smb-creds \
  --from-literal=username=admin \
  --from-literal=password=your-password \
  -n helmut4

# Optional: In values.yaml für Storage-Klasse konfigurieren
```

### Schritt 3: values-migration-pv-names.yaml anpassen

```yaml
global:
  storage:
    csiDriver: "smb.csi.k8s.io"          # SMB CSI Driver
    storageClassName: "helmut4-csi-storage"
    
    volume:
      size: "100Gi"
      # Bestehender SMB-Share (von Docker)
      source: "//storage-server.local/helmut-volumes"
```

### Schritt 4: Helm installieren

```bash
helm install helmut4 helmut4/ \
  -f examples/values-migration-pv-names.yaml \
  -n helmut4 \
  --create-namespace
```

### Schritt 5: Verifikation

```bash
# PVCs erstellt?
kubectl -n helmut4 get pvc
# NAME                   STATUS  VOLUME              CAPACITY
# helmut-storage-pvc     Bound   pvc-xxx             100Gi

# Pods mit Volume gemountet?
kubectl -n helmut4 get pods -o wide
kubectl -n helmut4 exec <pod> -- mount | grep helmut
kubectl -n helmut4 exec <pod> -- ls -la /Volumes
```

---

## Scenario: NFS-Share Migration

### Schritt 1: NFS CSI Driver installieren

```bash
helm repo add nfs-subdir-external-provisioner \
  https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/

helm install nfs-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
  --namespace kube-system \
  --set nfs.server=nfs-server.example.com \
  --set nfs.path=/exports/helmut
```

### Schritt 2: values.yaml konfigurieren

```yaml
global:
  storage:
    csiDriver: "nfs.csi.k8s.io"         # NFS CSI Driver
    storageClassName: "nfs-helmut"
    volumes:
      - name: helmut-storage
        mountPath: "/Volumes/Helmut"
        size: "100Gi"
        # NFS-Share im Format: server:/path
        source: "nfs-server.example.com:/exports/helmut-volumes"
        appMount: true
      - name: mongobackup
        mountPath: "/Volumes/Backup"
        size: "50Gi"
        source: "nfs-server.example.com:/exports/mongodb-backups"
        appMount: false
```

### Schritt 3: Installieren

```bash
helm install helmut4 helmut4/ \
  -f examples/values-migration-pv-names.yaml \
  -n helmut4 \
  --create-namespace
```

---

## Scenario: Ohne externe Shares (Dynamisches Provisioning)

Falls du keine externen Shares hast und Kubernetes dynamisch Storage erstellen lässt:

```yaml
global:
  storage:
    csiDriver: "pd.csi.storage.gke.io"   # GKE, Azure, AWS CSI driver
    storageClassName: "helmut4-csi-storage"
    volumes:
      - name: helmut-storage
        mountPath: "/Volumes/Helmut"
        size: "100Gi"
        source: ""                        # Leer = dynamisch provisioned
        appMount: true
      - name: mongobackup
        mountPath: "/Volumes/Backup"
        size: "50Gi"
        source: ""                        # Leer = dynamisch provisioned
        appMount: false
```

---

## Troubleshooting

### PVC bleibt Pending

```bash
kubectl -n helmut4 describe pvc helmut-storage-pvc

# Ursachen:
# 1. CSI Driver nicht installiert
kubectl get csinode
kubectl get storageclass

# 2. Share nicht erreichbar
kubectl -n kube-system logs -l app.kubernetes.io/name=csi-driver-smb

# 3. Credentials falsch
# Überprüfe Secret:
kubectl get secret smb-creds -n kube-system -o yaml
```

### Pod kann Volume nicht mounten

```bash
# Pod logs
kubectl -n helmut4 logs <pod> -c <container>

# Events
kubectl -n helmut4 describe pod <pod>

# CSI Driver Logs
kubectl -n kube-system logs -l app=csi-driver-smb -f
```

### Share-Verbindung wird abgebrochen

```bash
# Überprüfe Netzwerkverbindung
kubectl -n helmut4 exec <pod> -- ping storage-server.local

# Überprüfe Credentials/Authentifizierung
kubectl -n helmut4 exec <pod> -- smbclient -L //storage-server.local
```

---

## Best Practices

### 1. Share-Größe überprüfen

```bash
# Host: Verfügbaren Platz auf SMB-Share prüfen
net view \\storage-server /share
# oder mit df (Linux/NFS)
df -h /mnt/helmut-volumes

# values.yaml sollte < verfügbarem Platz sein
```

### 2. Backup vor Migration

```bash
# Data aus Docker Compose Volume kopieren
docker run --rm \
  -v helmut-volumes:/data \
  alpine:latest \
  tar czf /backup/helmut-volumes.tar.gz /data
```

### 3. Credentials sicher handhaben

```bash
# Für SMB: Secrets verwenden statt Passwörter in values
kubectl create secret generic smb-migration-creds \
  --from-literal=username=admin \
  --from-literal=password=<password> \
  -n helmut4
```

### 4. Performance-Tuning

```yaml
# Bei schlechter Performance: Blocksize anpassen
# (je nach CSI-Treiber unterschiedlich)
global:
  storage:
    # In StorageClass parameters (CSI-spezifisch)
    # z.B. für SMB: blocksize, caching, etc.
```

### 5. Monitoring

```bash
# Storage-Auslastung überwachen
kubectl -n helmut4 exec <pod> -- df -h /Volumes

# PVC-Auslastung
kubectl -n helmut4 get pvc -w

# Events für Storage-Probleme
kubectl -n helmut4 get events --sort-by='.lastTimestamp'
```

---

## Rollback bei Problemen

Falls die Migration nicht funktioniert:

```bash
# Helm Release löschen (PVCs bleiben erhalten)
helm uninstall helmut4 -n helmut4

# Docker Compose wieder starten
docker-compose up -d

# Oder: Änderungen in values korrigieren
helm upgrade helmut4 helmut4/ \
  -f examples/values-migration-pv-names.yaml \
  -n helmut4
```

---

## CSI-Treiber Übersicht

| Storage | CSI Driver | Installation |
|---------|-----------|--------------|
| SMB/CIFS | `smb.csi.k8s.io` | Azure CSI Driver |
| NFS | `nfs.csi.k8s.io` | NFS Subdir Provisioner |
| GCP Persistent Disk | `pd.csi.storage.gke.io` | GKE default |
| AWS EBS | `ebs.csi.aws.com` | AWS EBS CSI |
| Azure Disk | `disk.csi.azure.com` | Azure CSI |
| Ceph RBD | `rbd.csi.ceph.io` | Ceph Operator |
| Longhorn | `driver.longhorn.io` | Longhorn |
