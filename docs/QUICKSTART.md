# Quick Start Guide

## 1. Prerequisites

Make sure the following tools are installed and configured:

- `kubectl` (configured for your cluster)
- `helm` 3+
- Longhorn installed in the cluster (for MongoDB)
- SMB CSI Driver installed in the cluster (for application storage)

## 2. Configure `install-values.yaml`

Create your `install-values.yaml` with cluster-specific settings:

```yaml
ingress:
  domain: "helmut.your-domain.com"

docker:
  registry: "repo.moovit24.de:443"
  username: "your-username"
  password: "your-password"
  email: "your@email.com"

mongodb:
  persistence:
    storageClass: "longhorn"
    size: "50Gi"
  auth:
    rootUsername: "root"
    rootPassword: "your-very-secure-password"

rabbitmq:
  auth:
    username: "root"
    password: "your-rabbit-password"
    erlangCookie: "your-erlang-cookie"
    existingErlangCookieKey: "erlang-cookie"
    existingPasswordKey: "password"

credentials:
  storage:
    smb:
      username: "smb-user"
      password: "smb-password"
      domain: ""

global:
  storage:
    csiDriver: "smb.csi.k8s.io"
    storageClassName: "helmut4-csi-storage"
    mountPath: "/Volumes/Helmut"
    volume:
      size: "100Gi"
      source: "//your-server/share"
    mongobackup:
      size: "50Gi"
      source: "//your-server/share/backups"

ingress:
  enabled: true
  className: "nginx"
  tls:
    enabled: true
    provider: "letsencrypt"
    certIssuer: "letsencrypt-prod"
    secretName: "helmut4-tls"
```

## 3. Install the chart

```bash
helm upgrade helmut4 --install \
  -n helmut4 \
  --create-namespace \
  -f install-values.yaml \
  ./helmut4
```

Or use the preconfigured script:

```bash
./install.sh              # generic
./install-moovit24.sh     # Rancher-specific (sets KUBECONFIG)
```

## 4. Monitor the installation

```bash
# Watch pods
kubectl get pods -n helmut4 -w

# All resources
kubectl get all -n helmut4
```

All 34 pods should show `Running 1/1` after a few minutes.

## 5. Verify status

### MongoDB replica set

```bash
kubectl exec -n helmut4 -it mongodb-0 -- mongosh \
  -u root -p <password> \
  --eval "rs.status()"
```

### RabbitMQ

```bash
kubectl exec -n helmut4 -it rabbitmq-0 -- rabbitmq-diagnostics ping
kubectl exec -n helmut4 -it rabbitmq-0 -- rabbitmqctl cluster_status
```

### Ingress

```bash
kubectl get ingress -n helmut4
```

## 6. View logs

```bash
# Service logs
kubectl logs -n helmut4 -f deployment/fx

# MongoDB logs
kubectl logs -n helmut4 -f statefulset/mongodb

# RabbitMQ logs
kubectl logs -n helmut4 -f statefulset/rabbitmq
```

## 7. Upgrade

```bash
helm upgrade helmut4 ./helmut4 \
  -n helmut4 \
  -f install-values.yaml

# Check status
helm status helmut4 -n helmut4

# Roll back if needed
helm rollback helmut4 -n helmut4
```

## 8. Uninstall

```bash
# Remove chart (PVCs are retained)
helm uninstall helmut4 -n helmut4

# Delete namespace and PVCs (DATA WILL BE LOST!)
kubectl delete pvc --all -n helmut4
kubectl delete namespace helmut4
```

## Common Issues

### Pod not starting / CrashLoopBackOff

```bash
kubectl describe pod -n helmut4 <pod-name>
kubectl logs -n helmut4 <pod-name>
```

Common causes:
- MongoDB or RabbitMQ not yet ready — wait a bit longer
- Wrong password in `install-values.yaml` — check your values

### MongoDB replica set not initialized

The cloudpirates chart initializes the RS automatically. If needed manually:

```bash
kubectl exec -n helmut4 -it mongodb-0 -- mongosh \
  -u root -p <password> \
  --eval "rs.initiate({_id:'rs0',members:[{_id:0,host:'mongodb-0.mongodb-headless:27017'},{_id:1,host:'mongodb-1.mongodb-headless:27017'},{_id:2,host:'mongodb-2.mongodb-headless:27017'}]})"
```

### Ingress not working

```bash
# Nginx Ingress Controller installed?
kubectl get pods -n ingress-nginx

# TLS certificate present?
kubectl get certificate -n helmut4
kubectl describe certificate helmut4-tls -n helmut4
```

See [SSL_TROUBLESHOOTING.md](../SSL_TROUBLESHOOTING.md) for more details.

## Further Reading

- Full documentation: [../README.md](../README.md)
- Examples: [../examples/](../examples/)
- HA setup: [HA-DATABASE.md](HA-DATABASE.md)
- Troubleshooting: [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
