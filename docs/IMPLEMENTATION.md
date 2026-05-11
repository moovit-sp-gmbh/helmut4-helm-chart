# Helmut4 Helm Chart — Implementation Summary

## What Has Been Implemented

### 1. Nginx-based Ingress (replacing Traefik)

- Standard Nginx Ingress Controller instead of Traefik
- Path-based routing for all services
- TLS/SSL support via cert-manager annotation
- All routes from `traefik.toml` migrated:
  - Service routes: `/v1/fx`, `/v1/co`, `/v1/io`, `/v1/hk`, etc.
  - WebStomp: `/ws` → RabbitMQ port 15674
  - Admin interface: `/panel`
  - Default: `/` → hw service
  - File: `helmut4/templates/ingress/nginx-ingress.yaml`

### 2. MongoDB Replica Set (sub-chart)

- `cloudpirates/mongodb v0.10.3` as Helm dependency
- 3 replicas with automatic replica set (`rs0`) for HA
- **Longhorn block storage**: 3x 50 Gi PVCs (clean slate on reinstall)
- Headless service `mongodb-headless` for RS topology (Spring Boot connection)
- Additional ClusterIP service `mongodb` via `extraObjects` so health-check scripts have a stable address (the headless service round-robins across all RS members)
- Auth via `rootUsername` / `rootPassword`
- Spring Boot connects via `envFrom` (ConfigMap `service-config` + secret `mongodb-credentials`)

### 3. RabbitMQ StatefulSet (sub-chart)

- `cloudpirates/rabbitmq v0.7.10` as Helm dependency
- 3 replicas for clustering
- Persistent volumes (30 Gi default)
- Erlang cookie for node authentication
- WebStomp plugin (port 15674)
- Headless service for clustering
- Health checks

### 4. Application Storage (SMB CSI)

- StorageClass `helmut4-csi-storage` with SMB CSI provider
- PersistentVolumeClaims:
  - `helmut-storage-pvc` (100 Gi, ReadWriteMany) — application volumes
  - `mongodb-backup-pvc` (50 Gi, ReadWriteOnce) — MongoDB backups
- Example configurations: `examples/values-azure-csi.yaml`, `examples/values-aws-csi.yaml`
- Documentation: `docs/CSI-DRIVER.md`
- File: `helmut4/templates/storage/pvc.yaml`

### 5. Docker Registry Credentials

- Automatic ImagePullSecrets
- Configurable via `install-values.yaml`
- File: `helmut4/templates/secrets.yaml`

### 6. Service ConfigMap & Secret Injection

- ConfigMap `service-config`: all Spring Boot environment variables
- `envFrom` reference in all deployments
- Credentials (MongoDB password, RabbitMQ password) via `env.valueFrom.secretKeyRef`
- No Elasticsearch

### 7. All Microservices

- 15 services with individual deployments:
  - `hp`, `hw`, `fx`, `co`, `io`, `hk`, `users`, `streams`
  - `preferences`, `metadata`, `logging`, `amqp`, `license`, `language`
  - `cronjob`
- Dynamic service-to-service URLs via ConfigMap
- Health checks for all services
- Services with volume mount support
- File: `helmut4/templates/services/deployments.yaml`

### 8. RBAC (namespace-scoped)

- ServiceAccount, Role and RoleBinding (no ClusterRole)
- File: `helmut4/templates/rbac.yaml`

## File Structure

```
helmut4-helm-chart/
├── helmut4/
│   ├── Chart.yaml                        # chart v0.3.0, mongodb 0.10.3, rabbitmq 0.7.10
│   ├── values.yaml                       # Default values
│   ├── charts/
│   │   ├── mongodb-0.10.3.tgz
│   │   └── rabbitmq-0.7.10.tgz
│   └── templates/
│       ├── _helpers.tpl                  # mongodb.host, rabbitmq.host helpers
│       ├── _service-deployment.tpl       # Generic deployment template
│       ├── rbac.yaml                     # Role/RoleBinding (namespace-scoped)
│       ├── secrets.yaml                  # Docker registry + mongodb-credentials
│       ├── configmap.yaml                # service-config ConfigMap
│       ├── ingress/
│       │   └── nginx-ingress.yaml
│       ├── services/
│       │   └── deployments.yaml          # All 16 microservices
│       ├── infrastructure/
│       │   └── brokers/                  # (RabbitMQ managed by sub-chart)
│       └── storage/
│           ├── credentials.yaml          # SMB secret
│           └── pvc.yaml                  # helmut-storage-pvc, mongodb-backup-pvc
├── examples/
│   ├── values-production.yaml
│   ├── values-development.yaml
│   ├── values-aws-csi.yaml
│   ├── values-azure-csi.yaml
│   ├── values-migration-pv-names.yaml
│   └── values-migration-pv-labels.yaml
├── docs/
│   ├── CSI-DRIVER.md
│   ├── HA-DATABASE.md
│   ├── QUICKSTART.md
│   ├── SECURITY.md
│   ├── SSL_TROUBLESHOOTING.md
│   ├── STORAGE-MIGRATION.md
│   ├── STRUCTURE.md
│   └── TROUBLESHOOTING.md
├── scripts/
│   ├── health-check.sh
│   ├── backup.sh
│   └── uninstall.sh
├── README.md
├── install-values.yaml                   # Cluster-specific overrides (do not commit!)
├── install.sh                            # Generic install script
└── install-moovit24.sh                   # Rancher cluster script (sets KUBECONFIG)
```

## Default Values

| Component | Replicas | Storage | StorageClass |
|-----------|----------|---------|--------------|
| MongoDB | 3 | 50 Gi x3 | longhorn |
| RabbitMQ | 3 | 30 Gi | default |
| Helmut Storage | — | 100 Gi | helmut4-csi-storage (SMB) |
| MongoDB Backup | — | 50 Gi | helmut4-csi-storage (SMB) |
| Services | 2 | — | — |

## Notable Design Decisions

1. **MongoDB RS mode**: `cloudpirates/mongodb` in RS mode only creates `mongodb-headless`.
   An additional ClusterIP service `mongodb` is created via `extraObjects` so that
   health-check scripts and ad-hoc backup commands have a stable address.

2. **Spring Boot config**: All environment variables follow Spring Boot relaxed binding
   (`SPRING_DATA_MONGODB_HOST` → `spring.data.mongodb.host`).

3. **No Elasticsearch**: Logging is handled by the `logging` microservice without an external ES instance.

4. **Longhorn for MongoDB**: Unlike an SMB share (which may contain stale data from previous
   installs), Longhorn PVCs always start empty — no duplicate-user problems.

## Validation

- Helm lint: passed
- Template rendering: OK
- All 34 pods running in namespace `helmut4`

## Support

1. Read README.md
2. Consult `docs/TROUBLESHOOTING.md`
3. Check logs: `kubectl logs -n helmut4 <pod>`
4. Run health check: `./scripts/health-check.sh helmut4`

---

**Chart version**: 0.3.0
**MongoDB sub-chart**: cloudpirates/mongodb 0.10.3
**RabbitMQ sub-chart**: cloudpirates/rabbitmq 0.7.10
**Kubernetes**: 1.24+
**Helm**: 3.0+
