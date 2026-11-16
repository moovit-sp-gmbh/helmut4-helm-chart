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
  --set mongodb.replicaSet.secondaries=4
```

## RabbitMQ StatefulSet

### Architecture

- **Sub-chart**: `cloudpirates/rabbitmq v0.7.10`
- **3-node cluster** (`replicaCount: 3`), formed by k8s peer discovery
  (`rabbitmq_peer_discovery_k8s`, pods listed through `rabbitmq-headless`)
- `podManagementPolicy: Parallel`, so a full restart does not wait on pod-0
- Erlang cookie for node authentication (`rabbitmq.auth.erlangCookie`)
- Persistent volume per pod (8 Gi, Longhorn): cluster metadata and quorum
  queue data survive pod restarts
- Preferred podAntiAffinity on `kubernetes.io/hostname`, PDB with
  `maxUnavailable: 1`
- `cluster_partition_handling = pause_minority`, `default_queue_type = quorum`
- WebStomp plugin (port 15674) for the browser and HC clients (`/ws`)

### How Helmut4 uses the cluster

- The Java services (`amqp`, `streams`) connect to the `rabbitmq` ClusterIP
  Service (`SPRING_RABBITMQ_HOST`). The Service only routes to ready pods,
  so a reconnect after a pod loss lands on a live node. They only declare
  exchanges (`helmut`, `helmut.sc`), which are cluster-wide metadata.
- The clients (HC, Helmut web, Helmut panel) subscribe over STOMP
  (`/ws` → `rabbitmq:15674`) with exclusive queues. An exclusive queue lives
  on the node the client is connected to. When that node dies the client
  reconnects through the Service to another node and subscribes again,
  usually within a few seconds. Live events published in that window are
  lost, a stream request that was in flight fails and IO re-queues the job.

### DNS Names

```
rabbitmq.helmut4.svc.cluster.local                       # clients, ready pods only
rabbitmq-0.rabbitmq-headless.helmut4.svc.cluster.local   # cluster node names
rabbitmq-1.rabbitmq-headless.helmut4.svc.cluster.local
rabbitmq-2.rabbitmq-headless.helmut4.svc.cluster.local
```

### Check Cluster Status

```bash
kubectl exec -n helmut4 -it rabbitmq-0 -- rabbitmq-diagnostics cluster_status
kubectl exec -n helmut4 -it rabbitmq-0 -- rabbitmq-diagnostics ping
kubectl exec -n helmut4 -it rabbitmq-0 -- rabbitmq-diagnostics status
```

Use any running pod if `rabbitmq-0` is the one that is down.

### Management UI

```bash
# Port-forwarding (management plugin enabled)
kubectl port-forward -n helmut4 svc/rabbitmq 15672:15672
# UI: http://localhost:15672 — root / <password>
```

### Failover Behavior

- **One pod / node lost**: the other two keep the majority and keep serving.
  Clients reconnect through the `rabbitmq` Service. The pod restarts on its
  PVC and rejoins the cluster.
- **Two pods lost**: the remaining node pauses itself (`pause_minority`)
  until a second node is back, so no split brain.
- **Full restart**: all pods start in parallel and wait for each other.

### Single node

For dev / small installs set `rabbitmq.replicaCount: 1`,
`rabbitmq.peerDiscoveryK8sPlugin.enabled: false`, `rabbitmq.pdb.create: false`
and optionally `rabbitmq.persistence.enabled: false`
(see `examples/values-development.yaml`).

### Upgrading from the single-node chart

`podManagementPolicy` and `volumeClaimTemplates` of a StatefulSet cannot be
changed in place, so `helm upgrade` rejects the change. Delete the RabbitMQ
StatefulSet first (the single-node pod had no PVC, there is no data to keep):

```bash
kubectl delete statefulset -n helmut4 rabbitmq
helm upgrade helmut4 ./helmut4 -n helmut4 -f install-values.yaml
```

## Backup and Restore

Two backup options ship with the chart:

- **Scheduled `mongobackup` Deployment** (opt-in) — runs the moovit
  `mcc_mongodb_backup` container on an internal cron; see below.
- **`scripts/backup.sh`** (ad-hoc) — runs `mongodump` inside `mongodb-0`
  and `kubectl cp`s the result to local disk; schedule it from cron / a CI
  runner / a node-level systemd timer to suit your retention policy.

> Restoring a database from the Helmut frontend is served by the
> `preferences` service (`/v1/preferences/restore`), not by these tools.

### Scheduled MongoDB Backup (mongobackup)

Enable the bundled backup Deployment:

```yaml
mongobackup:
  enabled: true
  tag: "4.12.0.1"          # compatible with the bundled MongoDB 8
  schedule: "0 */4 * * *"  # container-internal cron
  maxBackups: 180
  backupClaim: "mongobackup-pvc"
```

It dumps every database to `<mongobackup share>/<timestamp>/…archive.gz`
and prunes to `maxBackups`. Prerequisites:

- A backup volume: add a `global.storage.volumes` entry (e.g. `mongobackup`,
  `appMount: false`), then create its share subfolder — the CSI mount fails
  if the target directory does not exist yet.
- Keep the tag at `4.12.x`; the `4.1.x` tag the upstream docs still list
  fails SASL auth against MongoDB 8.
- It dumps from a single replica member (`mongoHost`, default `mongodb-0`).
  Never point it at the load-balanced `mongodb` service — parallel cursors
  spread across members cause `CursorNotFound`.

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

> The `mongobackup` volume (`appMount: false`) is the share the scheduled
> `mongobackup` Deployment writes its dumps to. With that Deployment
> disabled the PVC is provisioned but unused.

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
