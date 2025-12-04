# MongoDB und RabbitMQ High Availability

## MongoDB StatefulSet

### Architektur
- **3 Replicas** für Hochverfügbarkeit
- **Replica-Set** für Datenreplikation
- **Persistent Volumes** für Datenpersistenz

### StatefulSet Konfiguration
```yaml
replicas: 3
serviceName: mongodb-headless  # Headless Service für DNS
volumeClaimTemplates:
  - name: data                 # Pro Replica ein PVC
    storage: 50Gi
```

### DNS Namen
- `mongodb-0.mongodb-headless.helmut4.svc.cluster.local` (Replica 0)
- `mongodb-1.mongodb-headless.helmut4.svc.cluster.local` (Replica 1)
- `mongodb-2.mongodb-headless.helmut4.svc.cluster.local` (Replica 2)

### Replica-Set Initialisierung

Automatisch beim Start, aber manuell wenn nötig:
```bash
kubectl exec -n helmut4 -it mongodb-0 -- mongo -u root -p <password> --eval \
  "rs.initiate({
    _id: 'rs0',
    members: [
      {_id: 0, host: 'mongodb-0.mongodb-headless'},
      {_id: 1, host: 'mongodb-1.mongodb-headless'},
      {_id: 2, host: 'mongodb-2.mongodb-headless'}
    ]
  })"
```

### Health Checks
```bash
# Replica-Set Status
kubectl exec -n helmut4 -it mongodb-0 -- mongo -u root -p <password> --eval "rs.status()"

# Datenbank Ping
kubectl exec -n helmut4 -it mongodb-0 -- mongo -u root -p <password> --eval "db.adminCommand('ping')"

# Primary prüfen
kubectl exec -n helmut4 -it mongodb-0 -- mongo -u root -p <password> --eval "db.isMaster()"
```

### Skalierung
```bash
# Auf 4 Replicas skalieren
kubectl scale statefulset mongodb --replicas=4 -n helmut4

# Replica aus Replica-Set entfernen
kubectl exec -n helmut4 -it mongodb-0 -- mongo -u root -p <password> --eval \
  "rs.remove('mongodb-3.mongodb-headless')"

# Auf 3 Replicas zurück
kubectl scale statefulset mongodb --replicas=3 -n helmut4
```

### Failover Verhalten
- Bei Pod-Crash: K8s startet neuen Pod mit Daten aus PVC
- Bei Node-Crash: Pod wird auf anderem Node gestartet
- Automatische Wahl eines neuen Primary wenn aktueller ausfällt
- Daten bleiben konsistent durch Replica-Set

## RabbitMQ StatefulSet

### Architektur
- **3 Replicas** für Clustering
- **Erlang Cookie** für Node-Authentifizierung
- **Persistent Volumes** für Message-Persistenz

### StatefulSet Konfiguration
```yaml
replicas: 3
serviceName: rabbitmq-headless
volumeClaimTemplates:
  - name: data
    storage: 30Gi
```

### DNS Namen
- `rabbitmq-0.rabbitmq-headless.helmut4.svc.cluster.local`
- `rabbitmq-1.rabbitmq-headless.helmut4.svc.cluster.local`
- `rabbitmq-2.rabbitmq-headless.helmut4.svc.cluster.local`

### Cluster Initialisierung

Wird automatisch via ConfigMap initialisiert:
```bash
# Cluster Status prüfen
kubectl exec -n helmut4 -it rabbitmq-0 -- rabbitmqctl cluster_status

# Nodes im Cluster
kubectl exec -n helmut4 -it rabbitmq-0 -- rabbitmqctl eval "nodes()."
```

### Health Checks
```bash
# Connectivity
kubectl exec -n helmut4 -it rabbitmq-0 -- rabbitmq-diagnostics ping

# Status
kubectl exec -n helmut4 -it rabbitmq-0 -- rabbitmq-diagnostics status

# Quorum Queue Status
kubectl exec -n helmut4 -it rabbitmq-0 -- rabbitmq-diagnostics queues
```

### Management UI
```bash
# Port-Forwarding (falls Management Plugin aktiviert)
kubectl port-forward -n helmut4 rabbitmq-0 15672:15672

# UI erreichbar unter: http://localhost:15672
# Credentials: root / <password>
```

### Skalierung
```bash
# Auf 5 Replicas skalieren
kubectl scale statefulset rabbitmq --replicas=5 -n helmut4

# Join-Prozess ist automatisch
kubectl exec -n helmut4 -it rabbitmq-4 -- rabbitmqctl cluster_status
```

### Failover Verhalten
- **Leader Election**: Automatisch bei Leader-Ausfall
- **Queue Replication**: Queues sind automatisch repliziert
- **Message Persistence**: Daten auf PVC, auch nach Node-Crash

## Backup und Wiederherstellung

### MongoDB Backup

Automatische Backups werden vom `mongobackup` Pod durchgeführt:

```bash
# Manuelles Backup
kubectl exec -n helmut4 mongobackup-xyz -- mongodump \
  -u root -p <password> \
  --out /backup/manual-backup
```

Backup-Dateien unter: `/backup/` (PVC)

### MongoDB Restore

```bash
# Backup wiederherstellen
kubectl exec -n helmut4 mongobackup-xyz -- mongorestore \
  -u root -p <password> \
  --authenticationDatabase admin \
  /backup/backup-datum/
```

### RabbitMQ Definitions Export

```bash
# Definitions exportieren
kubectl exec -n helmut4 -it rabbitmq-0 -- \
  rabbitmqctl export_definitions /tmp/definitions.json

# Aus Container kopieren
kubectl cp helmut4/rabbitmq-0:/tmp/definitions.json ./definitions.json
```

## Performance Tuning

### MongoDB
```yaml
resources:
  requests:
    memory: "4Gi"      # Mindestens 2Gi pro Replica
    cpu: "1"
  limits:
    memory: "8Gi"
    cpu: "2"

# WiredTiger Cache
env:
  - name: MONGO_WIREDTIGER_CACHE_SIZE
    value: "3g"
```

### RabbitMQ
```yaml
resources:
  requests:
    memory: "2Gi"      # 1Gi pro Replica für Testing
    cpu: "1"
  limits:
    memory: "4Gi"
    cpu: "2"

# VM Memory Settings in ConfigMap
env:
  - name: RABBITMQ_VM_MEMORY_HIGH_WATERMARK
    value: "0.6"       # 60% des verfügbaren RAM
```

## Monitoring und Alerting

### Pod Status überwachen
```bash
watch kubectl get pods -n helmut4 -l app=mongodb
watch kubectl get pods -n helmut4 -l app=rabbitmq
```

### Events prüfen
```bash
kubectl get events -n helmut4 --sort-by='.lastTimestamp'
```

### Logs analysieren
```bash
kubectl logs -n helmut4 -l app=mongodb --tail=100 -f
kubectl logs -n helmut4 -l app=rabbitmq --tail=100 -f
```

## Disaster Recovery

### Komplett Restore
```bash
# 1. StatefulSets löschen (ohne Pods zu löschen)
kubectl delete statefulset mongodb -n helmut4 --cascade=orphan
kubectl delete statefulset rabbitmq -n helmut4 --cascade=orphan

# 2. Chart mit alten Daten neu deployen
helm install helmut4 ./helmut4 -n helmut4
```

PVCs bleiben bestehen, neue Pods binden an alte Daten.

## Weitere Ressourcen

- [MongoDB Kubernetes Operator](https://www.mongodb.com/docs/kubernetes-operator/)
- [RabbitMQ Kubernetes](https://www.rabbitmq.com/kubernetes/operator/operator-overview.html)
- [StatefulSet Documentation](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)
