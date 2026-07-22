# Helmut4 Helm Chart

[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
[![Chart](https://img.shields.io/badge/dynamic/yaml?url=https://raw.githubusercontent.com/moovit-sp-gmbh/helmut4-helm-chart/main/helmut4/Chart.yaml&query=%24.version&label=Chart&color=blue&logo=helm)](helmut4/Chart.yaml)
[![AppVersion](https://img.shields.io/badge/dynamic/yaml?url=https://raw.githubusercontent.com/moovit-sp-gmbh/helmut4-helm-chart/main/helmut4/Chart.yaml&query=%24.appVersion&label=AppVersion&color=informational)](helmut4/Chart.yaml)
[![Release](https://img.shields.io/github/v/release/moovit-sp-gmbh/helmut4-helm-chart?include_prereleases&label=release)](https://github.com/moovit-sp-gmbh/helmut4-helm-chart/releases)
[![Helm](https://img.shields.io/badge/Helm-3.0%2B-blue?logo=helm)](https://helm.sh/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.24%2B-blue?logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![CI](https://github.com/moovit-sp-gmbh/helmut4-helm-chart/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/moovit-sp-gmbh/helmut4-helm-chart/actions/workflows/ci.yml)
[![Pages](https://github.com/moovit-sp-gmbh/helmut4-helm-chart/actions/workflows/pages.yml/badge.svg?branch=main)](https://moovit-sp-gmbh.github.io/helmut4-helm-chart/)

A complete Helm chart for the Helmut4 microservices application — MongoDB replica set, RabbitMQ with HTTP-backend auth wired to the Helmut user store, the full microservice fleet, an Ingress (or Gateway API HTTPRoute) with WebSTOMP, and an optional multi-volume storage layer that backs onto SMB / NFS / cloud CSI drivers.

## Features

- **Ingress / Gateway API routing**: Path-based routing for all services, including STOMP-over-WebSocket on `/ws`. Works with any Ingress controller (defaults tuned for ingress-nginx) or, opt-in, a Gateway API HTTPRoute.
- **MongoDB Replica Set**: 3-node RS (`rs0`) via `cloudpirates/mongodb v0.10.3`, with all seeds wired into the Spring driver
- **RabbitMQ**: single-node deployment by default (see [helmut4/values.yaml](helmut4/values.yaml) for the four pieces an HA cluster needs)
- **Longhorn Block Storage**: MongoDB PVCs on Longhorn (50 Gi per replica)
- **SMB / NFS CSI Driver Support**: multi-volume list for application file storage and any additional shares (e.g. backups)
- **Private Registry Credentials**: Docker Registry authentication integrated
- **Linux Clients** (optional, off by default): headless `mcp_hc` render nodes, several types side by side, each autoscalable — every pod claims its own render-node user on startup, so replicas are interchangeable (see [Linux clients](#linux-clients-optional))
- **Fully Configurable**: All aspects manageable via `values.yaml`

## Prerequisites

- Kubernetes 1.24+
- Helm 3.0+
- An Ingress controller **or** a Gateway API implementation installed (see [Ingress controllers](#ingress-controllers) below)
- Longhorn installed (for MongoDB block storage)
- SMB CSI Driver (for application storage via `/Volumes`)
- cert-manager (optional, for automatic TLS via Let's Encrypt)
- metrics-server (optional, only for autoscaling — the HPAs read CPU from it)

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
  api: "ingress"                    # or "gateway" (HTTPRoute)
  className: "nginx"                # ignored when api: gateway
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

### Ingress controllers

> **⚠️ ingress-nginx retirement.** `kubernetes/ingress-nginx` (the controller
> the chart defaults to) is being [retired in March 2026](https://kubernetes.io/blog/2025/11/11/ingress-nginx-retirement/) — existing
> deployments keep running but get no security patches afterwards. Plan a
> migration to another controller or to Gateway API.

The chart's Ingress template is controller-neutral; only the default
annotations in `appIngress.annotations` are nginx-specific. Pick the row
that matches your cluster and override `className` + `annotations`:

| Controller | `className` | Required annotations (for STOMP-over-WS) |
|---|---|---|
| ingress-nginx (default) | `nginx` | `nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"`<br>`nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"`<br>`nginx.ingress.kubernetes.io/proxy-http-version: "1.1"`<br>`nginx.ingress.kubernetes.io/ssl-redirect: "true"` |
| NGINX Inc. (`nginxinc/kubernetes-ingress`) | `nginx` | `nginx.org/websocket-services: "rabbitmq,users"`<br>`nginx.org/proxy-read-timeout: "3600s"`<br>`nginx.org/proxy-send-timeout: "3600s"` |
| Traefik | `traefik` | None on Ingress — WebSocket passes natively. Tune entrypoint `respondingTimeouts` in Traefik's static config if 60s default is too short. See [examples/values-ingress-traefik.yaml](examples/values-ingress-traefik.yaml). |
| HAProxy (`haproxytech/kubernetes-ingress`) | `haproxy` | `haproxy.org/timeout-tunnel: "3600s"`<br>`haproxy.org/timeout-client: "3600s"`<br>`haproxy.org/timeout-server: "3600s"` |

### Gateway API

Set `appIngress.api: "gateway"` to render a `gateway.networking.k8s.io/v1`
HTTPRoute instead of an Ingress. Requires a Gateway API implementation
(Envoy Gateway, Istio, Cilium, Contour, etc.) and a pre-existing `Gateway`
resource owned by your platform team:

```yaml
appIngress:
  enabled: true
  api: "gateway"
  domain: "helmut.your-domain.com"
  gateway:
    parentRef:
      name: "platform-gateway"
      namespace: "gateway-system"
      sectionName: "https"      # optional listener name
```

In Gateway mode the `appIngress.tls.*` block is ignored — TLS is
terminated on the Gateway listener (operator-owned). cert-manager
integration uses the `cert-manager.io/cluster-issuer` annotation on the
**Gateway**, not the HTTPRoute. WebSocket passes natively on conformant
implementations, but the **idle timeout is controller-specific** (Envoy
defaults to 5 minutes — configure your controller's policy CRD if STOMP
connections need longer). See [examples/values-gateway-api.yaml](examples/values-gateway-api.yaml).

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

The `mongobackup` share (`appMount: false`) feeds the optional scheduled backup
Deployment — set `mongobackup.enabled: true` to dump every database to it on a
cron. See [docs/HA-DATABASE.md](docs/HA-DATABASE.md#backup-and-restore).

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

### Linux clients (optional)

Headless render nodes (`mcp_hc`) that pull jobs over AMQP. Off by default. Each entry under
`linuxClients.types` becomes its own Deployment — its own mounts, sizing and pool of
render-node users — and can be autoscaled independently.

A Linux client normally authenticates from a `helmut.auto.login` file generated by hand for
one machine, which would give every replica the same identity. Instead each pod runs an
initContainer ([`client-autologin/`](client-autologin/)) that logs in as an admin, picks a
*free* user whose name starts with the type's `userPrefix`, and generates that user's autologin
file. Pods therefore stay interchangeable and an HPA can scale them.

```yaml
linuxClients:
  enabled: true
  # kubectl -n helmut4 create secret generic helmut-client-admin \
  #   --from-literal=username=admin --from-literal=password=...
  adminCredentials:
    existingSecret: "helmut-client-admin"    # keys: username / password
  autoscaling:
    enabled: true
  types:
    render:
      userPrefix: "linux-render-"            # matches linux-render-01 … -08
      appMounts: true                        # mount the shared /Volumes/Helmut share
      autoscaling:
        maxReplicas: 8                       # never above the size of the pool
```

The users must already exist in Helmut with "Render Node" enabled — the chart does not create
them. Two separate limits bound `maxReplicas`:

- **the user pool** — a pod with no free user left to claim stays in `Init:CrashLoopBackOff`,
  with the reason in `kubectl logs <pod> -c autologin`;
- **the concurrent-client licence** (`GET /v1/license` → `license_count`) — every connected UI
  session takes a seat too. Over the limit, the pod still reports `Running` but its log shows
  `Websocket close: 1002` right after connecting. There are no probes to catch this, because the
  client opens no port.

Autoscaling also interrupts work — Kubernetes chooses which pod to remove, and a client
rendering at that moment is sent SIGTERM regardless. Leave it off for types running long jobs.

**Full setup guide: [docs/LINUX-CLIENTS.md](docs/LINUX-CLIENTS.md)** — creating the user pool,
storage layouts, autoscaling limits, how a pod claims its user, and troubleshooting. A worked
two-type example is in [examples/values-linux-clients.yaml](examples/values-linux-clients.yaml),
and [client-autologin/README.md](client-autologin/README.md) covers the init image itself.

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
| `/v1/metadata`, `/v1/metadataSet` | metadata | 8003 |
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

### Linux client not picking up jobs

The client opens no port, so nothing probes it — a pod can sit `Running` while being refused.
Check the two containers in order:

```bash
kubectl logs -n helmut4 <pod> -c autologin        # which user it claimed
kubectl logs -n helmut4 <pod> -c client-<type>    # whether the socket stayed up
```

| Symptom | Cause |
|---------|-------|
| `Init:CrashLoopBackOff`, `no free user for prefix … pool exhausted` | every user matching `userPrefix` is already connected — add users or lower `maxReplicas` |
| `Init:` error on the login call | wrong `adminCredentials`, or the users service is not up yet (the pod retries) |
| `Running`, log shows `Websocket close: 1002` after connecting | concurrent-client licence exhausted — `GET /v1/license` reports `license_count`, and every UI session takes a seat too |
| `Running`, no `HCWebsocketClient` line at all | endpoints wrong — check `service-config` and what the initContainer wrote |
| HPA stuck at `<unknown>` targets | no CPU request on the client container, or `metrics-server` is missing |

`wss://localhost:8881` in the client log is normal — that is the client's own loopback socket,
not the server.

### MongoDB replica set status

```bash
kubectl exec -n helmut4 -it mongodb-0 -- mongosh \
  -u root -p <password> --eval "rs.status()"
```

### RabbitMQ status

```bash
kubectl exec -n helmut4 -it rabbitmq-0 -- rabbitmq-diagnostics ping
```

### Ingress / HTTPRoute not working

```bash
# Ingress mode (default)
kubectl get ingress -n helmut4
kubectl describe ingress -n helmut4 helmut4-ingress

# Gateway API mode (appIngress.api: gateway)
kubectl get httproute -n helmut4
kubectl describe httproute -n helmut4 helmut4-route
```

See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for more details, and
[docs/LINUX-CLIENTS.md](docs/LINUX-CLIENTS.md#troubleshooting) for the Linux clients.

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
| `examples/values-production.yaml` | Production setup (ingress-nginx) |
| `examples/values-development.yaml` | Development setup (ingress-nginx) |
| `examples/values-ingress-traefik.yaml` | Traefik Ingress recipe |
| `examples/values-gateway-api.yaml` | Gateway API (HTTPRoute) recipe |
| `examples/values-aws-csi.yaml` | AWS EBS CSI Driver |
| `examples/values-azure-csi.yaml` | Azure Disk CSI Driver |
| `examples/values-migration-pv-names.yaml` | Migration with existing PV names |
| `examples/values-migration-pv-labels.yaml` | Migration with PV labels |
| `examples/values-linux-clients.yaml` | Autoscaled Linux render clients |

## Additional Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Helm Documentation](https://helm.sh/docs/)
- [ingress-nginx](https://kubernetes.github.io/ingress-nginx/) — note: [retiring March 2026](https://kubernetes.io/blog/2025/11/11/ingress-nginx-retirement/)
- [Gateway API](https://gateway-api.sigs.k8s.io/) — the K8s-recommended successor; tool: [ingress2gateway](https://github.com/kubernetes-sigs/ingress2gateway)
- [Longhorn](https://longhorn.io/docs/)
- [RabbitMQ Kubernetes](https://www.rabbitmq.com/kubernetes/operator/operator-overview.html)
- [docs/HA-DATABASE.md](docs/HA-DATABASE.md) — MongoDB/RabbitMQ HA
- [docs/STORAGE-MIGRATION.md](docs/STORAGE-MIGRATION.md) — Storage Migration
- [docs/CSI-DRIVER.md](docs/CSI-DRIVER.md) — CSI Driver Configuration
- [docs/LINUX-CLIENTS.md](docs/LINUX-CLIENTS.md) — Linux render clients: user pool, storage, autoscaling
