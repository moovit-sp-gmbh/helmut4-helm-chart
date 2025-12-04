# Helmut4 Helm Chart

A complete Helm chart for the Helmut4 microservices application with Kubernetes integration.

## Features

- **Nginx-based Ingress**: Replaces Traefik with standard Nginx Ingress with path-based routing
- **MongoDB StatefulSet**: 3 replicas with automatic replica set for high availability
- **RabbitMQ StatefulSet**: 3 replicas for message queuing with persistent storage
- **CSI Driver Support**: Support for external storage mounting (e.g., /Volumes via CSI)
- **Private Registry Credentials**: Docker Registry authentication integrated
- **Configurable Values**: All important aspects manageable via `values.yaml`
- **Elasticsearch Integration**: For logging services
- **MongoDB Admin UI**: For managing the MongoDB database
- **MongoDB Backup**: Automatic backups with configurable schedule

## Installation

### Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- Nginx Ingress Controller installed
- CSI Driver for storage (if using external mounts)

### Perform Installation

```bash
# 1. Clone repository
git clone <repo-url>
cd helmut4-helm-chart

# 2. Create custom values (optional)
cp helmut4/values.yaml my-values.yaml

# 3. Configure Docker credentials
cat > docker-creds.yaml <<EOF
docker:
  username: "your-username"
  password: "your-password"
  email: "your-email@example.com"
EOF

# 4. Install chart
helm install helmut4 ./helmut4 \
  --namespace helmut4 \
  --create-namespace \
  -f docker-creds.yaml
```

## Configuration

### Docker Registry Credentials

The chart uses the private registry `repo.moovit24.de:443`. Configure the credentials before installation:

**Default Credentials:**
- Registry: `repo.moovit24.de:443`
- Username: `moovit`
- Password: `public`

```bash
# Option 1: Via values override
helm install helmut4 ./helmut4 \
  --set docker.username="moovit" \
  --set docker.password="public" \
  --set docker.email="your-email@example.com"

# Option 2: Via separate values file
cat > docker-secrets.yaml <<EOF
docker:
  registry: "repo.moovit24.de:443"
  username: "moovit"
  password: "public"
  email: "your-email@example.com"
EOF

helm install helmut4 ./helmut4 -f docker-secrets.yaml
```

### Storage (CSI Driver & Credentials)

To use external storage like `/Volumes`, configure the CSI driver and credentials:

```yaml
# my-values.yaml
global:
  storage:
    csiDriver: "smb.csi.k8s.io"           # e.g., SMB, NFS, Azure Disk
    storageClassName: "helmut4-csi-storage"
    volume:
      size: "100Gi"
      source: "//server/share"            # SMB: //server/share or NFS: server:/path
    mongobackup:
      size: "50Gi"
      source: "//server/backup"

# Credentials for SMB/NFS
credentials:
  storage:
    smb:
      username: "domain\\username"
      password: "your-password"
      domain: "YOURDOMAIN"              # Optional
    nfs:
      username: ""                       # Usually empty for anonymous NFS
      password: ""
```

**Optional: Customize Mount Path**

The default mount path in containers is `/Volumes/Helmut`. You can customize this:

```yaml
global:
  storage:
    mountPath: "/custom/path"           # Default: /Volumes/Helmut
```

Then install:

```bash
helm install helmut4 ./helmut4 -f my-values.yaml
```

Alternatively via CLI:

```bash
helm install helmut4 ./helmut4 \
  --set global.storage.csiDriver="smb.csi.k8s.io" \
  --set global.storage.volume.source="//server/share" \
  --set credentials.storage.smb.username="user" \
  --set credentials.storage.smb.password="pass"
```

### Ingress Domain and TLS

Set your ingress domain and TLS configuration:

```yaml
# my-values.yaml
ingress:
  domain: "api.your-domain.com"
  tls:
    enabled: true
    secretName: "helmut4-tls"
```

### TLS/SSL Certificates

The chart supports two options for TLS certificates:

#### Option 1: Let's Encrypt (automatic via cert-manager)

```yaml
ingress:
  tls:
    enabled: true
    provider: "letsencrypt"          # Default option
    certIssuer: "letsencrypt-prod"   # or "letsencrypt-staging"
    secretName: "helmut4-tls"
```

Prerequisite: cert-manager must be installed in the cluster.

#### Option 2: Custom Certificate

```yaml
ingress:
  tls:
    enabled: true
    provider: "custom"              # Uses custom certificate
    secretName: "my-custom-cert"    # Your Secret with tls.crt/tls.key
```

Create custom certificate:

```bash
kubectl create secret tls my-custom-cert \
  --cert=path/to/tls.crt \
  --key=path/to/tls.key \
  -n helmut4
```

### Service Replicas and Resources

Adjust replicas and resource limits:

```yaml
# my-values.yaml
serviceReplicas: 3

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

### MongoDB Configuration

```yaml
mongodb:
  replicas: 3  # Minimum 1 for a working replica set
  storage:
    size: "100Gi"
  auth:
    rootPassword: "your-secure-password"
```

### RabbitMQ Configuration

```yaml
rabbitmq:
  replicas: 3
  storage:
    size: "50Gi"
  auth:
    defaultPassword: "your-secure-password"
```

### Elasticsearch Configuration

```yaml
elasticsearch:
  enabled: true
  storage:
    size: "50Gi"
```

## Ingress Routing

The chart automatically configures Nginx Ingress routes for all services:

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
| `/ws` | rabbitmq (webstomp) | 15674 |
| `/panel` | hp | 8081 |
| `/mongodb` | mongoadmin | 8199 |
| `/` | hw | 8080 |

## Volumes and Storage

### Helmut Storage Mounting

The application requires access to storage (mounted as `/Volumes/Helmut` by default in containers).

Services with volume mounts:
- `fx`
- `co`
- `io`
- `users`
- `streams`
- `license`
- `xmlgenerator`

### MongoDB Persistent Storage

MongoDB uses StatefulSet with PVC for persistent data.

### Backup Storage

MongoDB backups are written to a separate PVC.

## Monitoring and Logging

### MongoDB Admin UI

Access via: `https://your-domain.com/mongodb`

Default credentials:
- Username: `root`
- Password: Configured in `mongodb.auth.rootPassword`

### Elasticsearch Logs

Elasticsearch runs at `http://elasticsearch:9200` and stores logs from the logging service.

## Upgrade

```bash
# Upgrade chart
helm upgrade helmut4 ./helmut4 -f my-values.yaml

# Rollback if problems occur
helm rollback helmut4 1
```

## Uninstall

```bash
helm uninstall helmut4 --namespace helmut4
```

## Troubleshooting

### Pods not starting

```bash
# View logs
kubectl logs -n helmut4 <pod-name>

# Pod details
kubectl describe pod -n helmut4 <pod-name>
```

### MongoDB connection issues

```bash
# Check MongoDB replica set status
kubectl exec -n helmut4 -it mongodb-0 -- mongo -u root -p <password> --eval "rs.status()"

# Check MongoDB pods
kubectl get pods -n helmut4 -l app=mongodb
```

### RabbitMQ connection issues

```bash
# Check RabbitMQ status
kubectl exec -n helmut4 -it rabbitmq-0 -- rabbitmq-diagnostics ping

# Check RabbitMQ pods
kubectl get pods -n helmut4 -l app=rabbitmq
```

### Ingress not working

```bash
# Ingress status
kubectl get ingress -n helmut4

# Ingress details
kubectl describe ingress -n helmut4 helmut4-helmut4-ingress
```

## Security

- All credentials should be provided via Secrets (not in values.yaml)
- Private registry credentials are created as Kubernetes Secrets
- Storage credentials (SMB/NFS) are managed as Kubernetes Secrets
- MongoDB and RabbitMQ have default passwords - these should be changed before production
- TLS/SSL is configurable:
  - **Automatic**: Let's Encrypt via cert-manager
  - **Manual**: Provide your own certificate
- Nginx Ingress should be configured with TLS/SSL

## Performance Tips

1. **MongoDB**: 
   - Minimum 3 replicas for high availability
   - Use storage class with SSD
   - Sufficient CPU and memory (min. 2Gi)

2. **RabbitMQ**: 
   - 3 replicas for clustering
   - Nodes should run on different Kubernetes nodes

3. **Services**: 
   - Horizontally scalable - add more replicas via `serviceReplicas`
   - Adjust CPU/memory limits as needed

## Additional Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Helm Documentation](https://helm.sh/docs/)
- [Nginx Ingress Controller](https://kubernetes.github.io/ingress-nginx/)
- [MongoDB Operator](https://www.mongodb.com/docs/kubernetes-operator/)
- [RabbitMQ Kubernetes](https://www.rabbitmq.com/kubernetes/operator/operator-overview.html)

## Support

For questions or issues, contact the Development Team.
