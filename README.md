# Helmut4 Helm Chart

A complete Helm chart for the Helmut4 microservices application with Kubernetes integration.

## Features

- **Nginx-based Ingress**: Path-based routing for all services including WebStomp
- **MongoDB Replica Set**: 3 replicas with automatic RS (`rs0`) via `cloudpirates/mongodb v0.10.3`
- **RabbitMQ StatefulSet**: 3 replicas for message queuing with persistent storage
- **Longhorn Block Storage**: MongoDB PVCs on Longhorn (50 Gi per replica)
- **SMB CSI Driver Support**: For application file storage (`/Volumes/Helmut`)
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

### 1. Clone repository

```bash
git clone <repo-url>
cd helmut4-helm-chart
```

### 2. Configure `install-values.yaml`

All configuration belongs in `install-values.yaml` — no `--set` flags needed:

```yaml
ingress:
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
    volume:
      size: "100Gi"
      source: "//server/share"
```

### 3. Install the chart

```bash
helm upgrade helmut4 --install \
  -n helmut4 \
  --create-namespace \
  -f install-values.yaml \
  ./helmut4
```

Or use the preconfigured scripts:

```bash
./install.sh              # generic
./install-moovit24.sh     # Rancher cluster (sets KUBECONFIG)
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
    erlangCookie: "secretcookie"
```

### Ingress & TLS

```yaml
ingress:
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

```yaml
global:
  storage:
    csiDriver: "smb.csi.k8s.io"
    storageClassName: "helmut4-csi-storage"
    mountPath: "/Volumes/Helmut"
    volume:
      size: "100Gi"
      source: "//server/share"
    mongobackup:
      size: "50Gi"
      source: "//server/share/backups"

credentials:
  storage:
    smb:
      username: "smb-user"
      password: "smb-password"
      domain: ""
```

Services with volume mount: `fx`, `co`, `io`, `users`, `streams`, `license`, `xmlgenerator`

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

- Always put credentials in `install-values.yaml` (never commit to git)
- Set MongoDB and RabbitMQ passwords before first deployment
- Configure TLS/SSL via cert-manager or a custom certificate
- RBAC is enabled by default (namespace-scoped Role/RoleBinding)

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
