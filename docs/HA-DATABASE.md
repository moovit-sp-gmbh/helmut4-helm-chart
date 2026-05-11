# MongoDB and RabbitMQ High Availability

## MongoDB StatefulSet

### Architecture

- **Sub-chart**: `cloudpirates/mongodb v0.10.3`
- **3 replicas** with replica set `rs0`
- **Longhorn block storage**: 3x 50 Gi PVCs (clean slate on reinstall)
- Spring Boot connects via `mongodb-headless` (RS-aware topology)
- Health-check scripts use the ClusterIP service `mongodb` (the headless service round-robins, the ClusterIP gives a stable address)

### DNS Names

```
# For Spring Boot (RS topology):
mongodb-headless.helmut4.svc.cluster.local

# Individual replicas:
mongodb-0.mongodb-headless.helmut4.svc.cluster.local
mongodb-1.mongodb-headless.helmut4.svc.cluster.local
mongodb-2.mongodb-headless.helmut4.svc.cluster.local

# For scripts (ClusterIP, via extraObjects):
mongodb.helmut4.svc.cluster.local
```

### Check Replica Set Status

```bash
kubectl exec -n helmut4 -it mongodb-0 -- mongosh \
  -u root -p <password> --eval "rs.status()"

# Check primary
kubectl exec -n helmut4 -it mongodb-0 -- mongosh \
  -u root -p <password> --eval "db.isMaster()"
```

### Manual RS Initialization (if needed)

```bash
kubectl exec -n helmut4 -it mongodb-0 -- mongosh -u root -p <password> --eval \
  "rs.initiate({
    _id: 'rs0',
    members: [
      {_id: 0, host: 'mongodb-0.mongodb-headless:27017'},
      {_id: 1, host: 'mongodb-1.mongodb-headless:27017'},
      {_id: 2, host: 'mongodb-2.mongodb-headless:27017'}
    ]
  })"
```

### Failover Behavior

- On pod crash: Kubernetes restarts the pod; Longhorn PVC stays attached
- On node crash: pod migrates to another node (Longhorn supports RWO migration)
- Automatic primary election by the replica set

### Scaling

```bash
# Scale to 5 replicas (set value in values.yaml, then helm upgrade)
helm upgrade helmut4 ./helmut4 -n helmut4 -f install-values.yaml \
  --set mongodb.replicaSet.replicaCount=5
```

## RabbitMQ StatefulSet

### Architecture

- **Sub-chart**: `cloudpirates/rabbitmq v0.7.10`
- **3 replicas** with automatic clustering
- Erlang cookie for node authentication
- WebStomp plugin (port 15674)
- Persistent volumes (30 Gi default)

### DNS Names

```
rabbitmq-0.rabbitmq-headless.helmut4.svc.cluster.local
rabbitmq-1.rabbitmq-headless.helmut4.svc.cluster.local
rabbitmq-2.rabbitmq-headless.helmut4.svc.cluster.local
```

### Check Cluster Status

```bash
kubectl exec -n helmut4 -it rabbitmq-0 -- rabbitmqctl cluster_status
kubectl exec -n helmut4 -it rabbitmq-0 -- rabbitmq-diagnostics ping
kubectl exec -n helmut4 -it rabbitmq-0 -- rabbitmq-diagnostics status
```

### Management UI

```bash
# Port-forwarding (management plugin enabled)
kubectl port-forward -n helmut4 rabbitmq-0 15672:15672
# UI: http://localhost:15672 — root / <password>
```

### Failover Behavior

- **Leader election**: Automatic when leader fails
- **Queue replication**: Queues are replicated automatically
- **Message persistence**: Data on PVC, survives node crashes

## Backup and Restore

The chart does not ship a managed backup workload. The bundled
`scripts/backup.sh` wrapper runs `mongodump` inside `mongodb-0` and
`kubectl cp`s the result to local disk; schedule it from cron / a CI
runner / a node-level systemd timer to suit your retention policy.

### MongoDB Backup (ad-hoc)

```bash
./scripts/backup.sh helmut4 ./backups
```

Or inline:

```bash
kubectl exec -n helmut4 mongodb-0 -- mongodump \
  -u root -p <password> \
  --authenticationDatabase admin \
  --out /tmp/mongodb-backup-$(date +%Y%m%d)
kubectl cp helmut4/mongodb-0:/tmp/mongodb-backup-$(date +%Y%m%d) ./backups/
```

### MongoDB Restore

```bash
kubectl cp ./backups/<backup-date> helmut4/mongodb-0:/tmp/restore
kubectl exec -n helmut4 mongodb-0 -- mongorestore \
  -u root -p <password> \
  --authenticationDatabase admin \
  /tmp/restore
```

> The `mongobackup` volume (when configured with `appMount: false`)
> exists so a backup CronJob or sidecar can write to it; the chart
> itself currently provisions only the PVC.

### RabbitMQ Definitions Export

```bash
kubectl exec -n helmut4 -it rabbitmq-0 -- \
  rabbitmqctl export_definitions /tmp/definitions.json
kubectl cp helmut4/rabbitmq-0:/tmp/definitions.json ./definitions.json
```

## Performance Tuning

### MongoDB

```yaml
mongodb:
  resources:
    requests:
      memory: "4Gi"
      cpu: "4"
    limits:
      memory: "8Gi"
      cpu: "8"
  persistence:
    size: "50Gi"
    storageClass: "longhorn"
```

### RabbitMQ

```yaml
rabbitmq:
  resources:
    requests:
      memory: "2Gi"
      cpu: "1"
    limits:
      memory: "4Gi"
      cpu: "2"
```

## Monitoring

```bash
# Watch pods
watch kubectl get pods -n helmut4 -l app.kubernetes.io/name=mongodb
watch kubectl get pods -n helmut4 -l app.kubernetes.io/name=rabbitmq

# Events
kubectl get events -n helmut4 --sort-by='.lastTimestamp'

# Logs
kubectl logs -n helmut4 -l app.kubernetes.io/name=mongodb --tail=100 -f
kubectl logs -n helmut4 -l app.kubernetes.io/name=rabbitmq --tail=100 -f
```

## Disaster Recovery

### Full Reset (DATA WILL BE LOST!)

```bash
helm uninstall helmut4 -n helmut4
kubectl delete pvc --all -n helmut4   # delete Longhorn PVCs
kubectl delete namespace helmut4 --wait=true
helm upgrade helmut4 --install -n helmut4 --create-namespace -f install-values.yaml ./helmut4
```

Because of Longhorn, MongoDB starts with a **clean, empty database** — no duplicate-user
problems from previous installations.

## Further Resources

- [Longhorn Documentation](https://longhorn.io/docs/)
- [RabbitMQ Kubernetes](https://www.rabbitmq.com/kubernetes/operator/operator-overview.html)
- [StatefulSet Documentation](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)
