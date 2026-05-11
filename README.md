# Helmut4 Helm Chart

[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
[![GitHub Release](https://img.shields.io/github/v/release/moovit-sp-gmbh/helmut4-helm-chart?include_prereleases)](https://github.com/moovit-sp-gmbh/helmut4-helm-chart/releases)
[![CI](https://github.com/moovit-sp-gmbh/helmut4-helm-chart/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/moovit-sp-gmbh/helmut4-helm-chart/actions/workflows/ci.yml)

A complete Helm chart for the Helmut4 microservices application — MongoDB replica set, RabbitMQ with HTTP-backend auth wired to the Helmut user store, the full microservice fleet, an nginx Ingress with WebSTOMP, and an optional multi-volume storage layer that backs onto SMB / NFS / cloud CSI drivers.

## Features

- **Nginx-based Ingress**: Path-based routing for all services, including STOMP-over-WebSocket on `/ws`
- **MongoDB Replica Set**: 3-node RS (`rs0`) via `cloudpirates/mongodb v0.10.3`, with all seeds wired into the Spring driver
- **RabbitMQ**: single-node deployment by default (see [helmut4/values.yaml](helmut4/values.yaml) for the four pieces an HA cluster needs)
- **Longhorn Block Storage**: MongoDB PVCs on Longhorn (50 Gi per replica)
- **SMB / NFS CSI Driver Support**: multi-volume list for application file storage and any additional shares (e.g. backups)
- **Private Registry Credentials**: Docker Registry authentication integrated
- **Fully Configurable**: All aspects manageable via `values.yaml`

## Prerequisites

- Kubernetes 1.24+
- Helm 3.0+
- Nginx Ingress Controller installed
- Longhorn installed (for MongoDB block storage)
- SMB CSI Driver (for application storage via `/Volumes`)
- cert-manager (optional, for automatic TLS via Let's Encrypt)

## Installation

You can either pull the packaged chart from the GitHub Pages helm-repo, or clone
the source tree and install from disk. Either way, all real credentials live in
`install-values.yaml`, which is **never** committed.

### Option A — install from the helm repo (preferred)

```bash
helm repo add helmut4 https://moovit-sp-gmbh.github.io/helmut4-helm-chart
helm repo update

# Grab a values template, edit it, then install:
curl -fsSL -o install-values.yaml \
  https://raw.githubusercontent.com/moovit-sp-gmbh/helmut4-helm-chart/main/examples/values-production.yaml
$EDITOR install-values.yaml

helm upgrade helmut4 helmut4/helmut4 --install \
  -n helmut4 --create-namespace \
  -f install-values.yaml
```

### Option B — install from a source checkout

#### 1. Clone the repository

```bash
git clone https://github.com/moovit-sp-gmbh/helmut4-helm-chart.git
cd helmut4-helm-chart
```

#### 2. Create `install-values.yaml`

`install-values.yaml` is **gitignored** (it holds real credentials). Copy one of the
examples as a starting point and edit it for your environment:

```bash
cp examples/values-production.yaml install-values.yaml
$EDITOR install-values.yaml
```

The file collects everything in one place — no `--set` flags needed:

```yaml
appIngress:
  domain: "helmut.your-domain.com"

docker:
  registry: "repo.moovit24.de:443"
  username: "your-username"
  password: "your-password"

mongodb:
  persistence:
    storageClass: "longhorn"
    size: "50Gi"
  auth:
    rootUsername: "root"
    rootPassword: "your-secure-password"

rabbitmq:
  auth:
    username: "root"
    password: "your-secure-password"
    erlangCookie: "your-erlang-cookie"

credentials:
  storage:
    smb:
      username: "smb-user"
      password: "smb-password"

global:
  storage:
    csiDriver: "smb.csi.k8s.io"
    storageClassName: "helmut4-csi-storage"
    volumes:
      - name: helmut-storage
        mountPath: "/Volumes/Helmut"
        size: "100Gi"
        source: "//server/share"
        appMount: true
```

#### 3. Install the chart

```bash
helm upgrade helmut4 --install \
  -n helmut4 \
  --create-namespace \
  -f install-values.yaml \
  ./helmut4
```

Or run the bundled wrapper, which does the same thing with a pre-flight check:

```bash
./install.sh
```

## Configuration

### MongoDB

MongoDB runs as a Helm sub-chart (`cloudpirates/mongodb v0.10.3`) in replica set mode.
Data is persisted on Longhorn block storage (50 Gi per replica).

```yaml
mongodb:
  persistence:
    storageClass: "longhorn"
    size: "50Gi"
  auth:
    rootUsername: "root"
    rootPassword: "your-secure-password"
  replicaSet:
    enabled: true
    name: "rs0"
```

> **Note**: In RS mode the cloudpirates chart only creates the headless service `mongodb-headless`.
> An additional ClusterIP service `mongodb` is created via `extraObjects` in `values.yaml` automatically.

### RabbitMQ

```yaml
rabbitmq:
  auth:
    username: "root"
    password: "your-secure-password"
    erlangCookie: "***REMOVED***"
```

### Ingress & TLS

```yaml
appIngress:
  enabled: true
  className: "nginx"
  domain: "helmut.your-domain.com"
  tls:
    enabled: true
    provider: "letsencrypt"         # or "custom"
    certIssuer: "letsencrypt-prod"
    secretName: "helmut4-tls"
```

For a custom certificate:

```bash
kubectl create secret tls helmut4-tls \
  --cert=path/to/tls.crt \
  --key=path/to/tls.key \
  -n helmut4
```

### Storage (SMB for application volumes)

`global.storage.volumes` is a list — each entry gets its own StorageClass and PVC.
Set `appMount: true` to mount the volume into every service that has
`volumeMounts: true`; set `appMount: false` for volumes used only by ancillary
workloads (e.g. a backup share).

```yaml
global:
  storage:
    csiDriver: "smb.csi.k8s.io"
    storageClassName: "helmut4-csi-storage"
    volumes:
      - name: helmut-storage
        mountPath: "/Volumes/Helmut"
        size: "100Gi"
        source: "//server/share"
        appMount: true
      - name: mongobackup
        mountPath: "/Volumes/Backup"
        size: "50Gi"
        source: "//server/share/backups"
        appMount: false

credentials:
  storage:
    smb:
      username: "smb-user"
      password: "smb-password"
      domain: ""
```

Services with `volumeMounts: true` (auto-mount every `appMount: true` volume):
`fx`, `co`, `io`, `users`, `streams`, `license`.

### Service Replicas and Resources

```yaml
serviceReplicas: 2

services:
  fx:
    replicas: 3
    resources:
      requests:
        cpu: "1"
        memory: "2Gi"
      limits:
        cpu: "2"
        memory: "4Gi"
```

## Ingress Routing

| Path | Service | Port |
|------|---------|------|
| `/v1/fx` | fx | 8100 |
| `/v1/co` | co | 8101 |
| `/v1/io` | io | 8102 |
| `/v1/hk` | hk | 8103 |
| `/v1/members`, `/v1/ws` | users | 8000 |
| `/v1/streams`, `/streamdesigner` | streams | 8001 |
| `/v1/preferences` | preferences | 8002 |
| `/v1/metadata` | metadata | 8003 |
| `/v1/logging` | logging | 8004 |
| `/v1/amqp` | amqp | 8005 |
| `/v1/license`, `/v1/client` | license | 8006 |
| `/v1/language`, `/v1/languages` | language | 8007 |
| `/ws` | rabbitmq (WebStomp) | 15674 |
| `/panel` | hp | 8081 |
| `/` | hw | 8080 |

## Upgrade

```bash
helm upgrade helmut4 ./helmut4 \
  -n helmut4 \
  -f install-values.yaml

# Roll back if problems occur
helm rollback helmut4 -n helmut4
```

## Uninstall

```bash
# Remove chart (PVCs are retained)
helm uninstall helmut4 -n helmut4

# Also delete PVCs (DATA WILL BE LOST!)
kubectl delete pvc --all -n helmut4
kubectl delete namespace helmut4
```

## Troubleshooting

### Pods not starting

```bash
kubectl logs -n helmut4 <pod-name>
kubectl describe pod -n helmut4 <pod-name>
```

### MongoDB replica set status

```bash
kubectl exec -n helmut4 -it mongodb-0 -- mongosh \
  -u root -p <password> --eval "rs.status()"
```

### RabbitMQ status

```bash
kubectl exec -n helmut4 -it rabbitmq-0 -- rabbitmq-diagnostics ping
```

### Ingress not working

```bash
kubectl get ingress -n helmut4
kubectl describe ingress -n helmut4 helmut4-ingress
```

See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for more details.

## Security

- `install-values.yaml` is gitignored — keep all real credentials there. Use the
  files in `examples/` as templates (they contain `CHANGE_ME` placeholders).
- Set MongoDB and RabbitMQ passwords (and the MongoDB replica-set keyfile)
  before first deployment.
- Configure TLS/SSL via cert-manager or a custom certificate.
- RBAC is enabled by default (namespace-scoped Role/RoleBinding).

See [docs/SECURITY.md](docs/SECURITY.md) for more details.

## Example Configurations

| File | Description |
|------|-------------|
| `examples/values-production.yaml` | Production setup |
| `examples/values-development.yaml` | Development setup |
| `examples/values-aws-csi.yaml` | AWS EBS CSI Driver |
| `examples/values-azure-csi.yaml` | Azure Disk CSI Driver |
| `examples/values-migration-pv-names.yaml` | Migration with existing PV names |
| `examples/values-migration-pv-labels.yaml` | Migration with PV labels |

## Additional Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Helm Documentation](https://helm.sh/docs/)
- [Nginx Ingress Controller](https://kubernetes.github.io/ingress-nginx/)
- [Longhorn](https://longhorn.io/docs/)
- [RabbitMQ Kubernetes](https://www.rabbitmq.com/kubernetes/operator/operator-overview.html)
- [docs/HA-DATABASE.md](docs/HA-DATABASE.md) — MongoDB/RabbitMQ HA
- [docs/STORAGE-MIGRATION.md](docs/STORAGE-MIGRATION.md) — Storage Migration
- [docs/CSI-DRIVER.md](docs/CSI-DRIVER.md) — CSI Driver Configuration
