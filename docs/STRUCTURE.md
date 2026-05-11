# Helmut4 Helm Chart — Structure

```
helmut4-helm-chart/
├── helmut4/                              # Main chart
│   ├── Chart.yaml                        # Metadata + dependency declarations
│   ├── values.yaml                       # Default values
│   ├── charts/
│   │   ├── mongodb-0.10.3.tgz            # cloudpirates/mongodb sub-chart
│   │   └── rabbitmq-0.7.10.tgz           # cloudpirates/rabbitmq sub-chart
│   └── templates/
│       ├── _helpers.tpl                  # Helm helpers (mongodb.host, rabbitmq.host)
│       ├── _service-deployment.tpl       # Generic deployment template
│       ├── rbac.yaml                     # ServiceAccount, Role, RoleBinding
│       ├── secrets.yaml                  # Docker registry + mongodb-credentials
│       ├── configmap.yaml                # service-config ConfigMap (Spring Boot env vars)
│       ├── ingress/
│       │   └── nginx-ingress.yaml        # Nginx ingress with TLS
│       ├── services/
│       │   └── deployments.yaml          # All 16 microservice deployments
│       ├── infrastructure/
│       │   └── brokers/                  # (RabbitMQ via sub-chart)
│       └── storage/
│           ├── credentials.yaml          # SMB credentials secret
│           └── pvc.yaml                  # helmut-storage-pvc + mongodb-backup-pvc
│
├── examples/                             # Example configurations
│   ├── values-production.yaml            # Production setup
│   ├── values-development.yaml           # Development setup
│   ├── values-aws-csi.yaml               # AWS EBS CSI Driver
│   ├── values-azure-csi.yaml             # Azure Disk CSI Driver
│   ├── values-migration-pv-names.yaml    # Migration using PV names
│   └── values-migration-pv-labels.yaml   # Migration using PV labels
│
├── docs/                                 # Documentation
│   ├── CSI-DRIVER.md                     # CSI driver configuration
│   ├── HA-DATABASE.md                    # MongoDB/RabbitMQ HA setup
│   ├── QUICKSTART.md                     # Quick start guide
│   ├── SECURITY.md                       # Security best practices
│   ├── SSL_TROUBLESHOOTING.md            # TLS/SSL troubleshooting
│   ├── STORAGE-MIGRATION.md              # Storage migration guide
│   ├── STRUCTURE.md                      # This file
│   └── TROUBLESHOOTING.md                # Troubleshooting guide
│
├── scripts/
│   ├── health-check.sh                   # Health check script
│   ├── backup.sh                         # MongoDB backup script
│   └── uninstall.sh                      # Uninstall and cleanup
│
├── README.md                             # Main documentation
├── install-values.yaml                   # Cluster-specific overrides (do NOT commit!)
├── install.sh                            # Generic install script
└── install-moovit24.sh                   # Rancher cluster script (sets KUBECONFIG)
```

## Implemented Features

### 1. Nginx-based Ingress
- Replaces Traefik with standard Nginx Ingress
- Path-based routing for all 16 services
- TLS/SSL via cert-manager (Let's Encrypt or custom)
- WebStomp (`/ws` → RabbitMQ port 15674)

### 2. MongoDB Replica Set (cloudpirates/mongodb 0.10.3)
- 3 replicas (`rs0`) for high availability
- **Longhorn block storage** (50 Gi per replica) — clean state on reinstall
- Headless service `mongodb-headless` for RS topology
- ClusterIP service `mongodb` via `extraObjects` so scripts have a stable address
- Auth via `rootUsername` / `rootPassword`

### 3. RabbitMQ StatefulSet (cloudpirates/rabbitmq 0.7.10)
- 3 replicas with automatic clustering
- Erlang cookie authentication
- WebStomp plugin (port 15674)
- Persistent volumes (30 Gi)

### 4. Application Storage (SMB CSI)
- StorageClass `helmut4-csi-storage` (SMB CSI driver)
- `helmut-storage-pvc` (100 Gi, ReadWriteMany) for application volumes
- `mongodb-backup-pvc` (50 Gi, ReadWriteOnce) for backups

### 5. Microservices (16 deployments)
- All Spring Boot env vars via `envFrom` (ConfigMap `service-config`)
- Credentials via `env.valueFrom.secretKeyRef`
- Health checks (liveness + readiness)
- Volume mounts for: `fx`, `co`, `io`, `users`, `streams`, `license`

### 6. RBAC (namespace-scoped)
- ServiceAccount, Role, RoleBinding (no ClusterRole)

## Ingress Routes

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

## Storage Overview

| PVC | StorageClass | Size | Access | Purpose |
|-----|-------------|------|--------|---------|
| `data-mongodb-0/1/2` | longhorn | 50 Gi | RWO | MongoDB data |
| `helmut-storage-pvc` | helmut4-csi-storage (SMB) | 100 Gi | RWX | Application volumes |
| `mongodb-backup-pvc` | helmut4-csi-storage (SMB) | 50 Gi | RWO | MongoDB backups |
