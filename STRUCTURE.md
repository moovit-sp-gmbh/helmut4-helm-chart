# Helmut4 Helm Chart - Struktur

```
helmut4-helm-chart/
├── helmut4/                          # Main Chart Directory
│   ├── Chart.yaml                    # Chart Metadata
│   ├── values.yaml                   # Default Values (hochgradig konfigurierbar)
│   ├── templates/
│   │   ├── _helpers.tpl              # Helm Template Helpers
│   │   ├── _service-deployment.tpl   # Generic Service Deployment Template
│   │   ├── rbac.yaml                 # RBAC, ServiceAccount, Namespace
│   │   ├── secrets.yaml              # Docker Registry Secrets
│   │   ├── configmap.yaml            # Service URL ConfigMap
│   │   ├── ingress/
│   │   │   └── nginx-ingress.yaml    # Nginx-basierte Ingress (statt Traefik)
│   │   ├── services/
│   │   │   └── deployments.yaml      # Alle Microservice Deployments
│   │   ├── databases/
│   │   │   ├── mongodb.yaml          # MongoDB StatefulSet (3 Replicas)
│   │   │   ├── rabbitmq.yaml         # RabbitMQ StatefulSet (3 Replicas)
│   │   │   ├── elasticsearch.yaml    # Elasticsearch Deployment
│   │   │   ├── mongoadmin.yaml       # MongoDB Admin UI
│   │   │   └── mongobackup.yaml      # MongoDB Backup Job
│   │   └── storage/
│   │       └── pvc.yaml              # PersistentVolumeClaims + CSI StorageClass
│   ├── examples/
│   │   ├── values-production.yaml    # Production Konfiguration
│   │   ├── values-development.yaml   # Development Konfiguration
│   │   ├── values-docker-credentials.yaml
│   │   ├── values-azure-csi.yaml     # Azure CSI Driver Config
│   │   └── values-aws-csi.yaml       # AWS CSI Driver Config
│   └── scripts/
│       ├── health-check.sh           # Health Check Script
│       ├── backup.sh                 # Backup Script
│       └── uninstall.sh              # Uninstall Script
├── docs/
│   ├── CSI-DRIVER.md                 # CSI Driver Konfiguration
│   ├── HA-DATABASE.md                # MongoDB/RabbitMQ HA Setup
│   ├── SECURITY.md                   # Security Best Practices
│   └── TROUBLESHOOTING.md            # Troubleshooting Guide
├── README.md                         # Hauptdokumentation
├── QUICKSTART.md                     # Quick-Start Guide
└── install.sh                        # Installation Script

```

## Implementierte Features

### 1. ✅ Nginx-basierte Ingress
- Ersetzt Traefik durch Standard-Nginx Ingress Controller
- Path-basiertes Routing für alle Services
- TLS/SSL Support via cert-manager
- Alle Routes aus traefik.toml übernommen

### 2. ✅ MongoDB StatefulSet
- 3 Replicas für Hochverfügbarkeit
- Automatisches Replica-Set
- Persistente Volumes pro Replica
- Health Checks (Liveness + Readiness Probes)
- Konfigurierbare Ressourcen und Storage

### 3. ✅ RabbitMQ StatefulSet
- 3 Replicas mit automatischem Clustering
- Persistente Volumes für Message-Queuing
- Erlang Cookie für Node-Authentifizierung
- WebStomp Support (Port 15674)
- Konfigurierbare Credentials und Ressourcen

### 4. ✅ CSI Driver Support
- StorageClass für externe Storage Integration
- Support für Azure Disk, AWS EBS, Google Cloud Persistent Disk
- PersistentVolumeClaims für Helmut Storage
- Beispielkonfigurationen für verschiedene Provider

### 5. ✅ Docker Registry Credentials
- ImagePullSecrets für privates Repository
- Flexible Credential-Verwaltung
- Support für beide dockercfg und dockerjson Formate

### 6. ✅ Hochgradig Konfigurierbar
- Alle Parameter in values.yaml
- Separate Example-Dateien für Production/Development
- Service-spezifische Replicas und Ressourcen
- Umgebungsvariablen dynamisch generiert
- ConfigMap für Service-to-Service URLs

### 7. ✅ Umfangreiche Dokumentation
- README mit Installation und Konfiguration
- Quick-Start Guide
- Security Best Practices
- HA Database Setup
- CSI Driver Guide
- Troubleshooting Guide
- Installation Script

### 8. ✅ Hilfsskripte
- health-check.sh für Diagnose
- backup.sh für Backup-Erstellung
- uninstall.sh für sauberes Deinstallieren

## Services mit konfigurierbaren Replicas und Ressourcen

1. **hp** - Panel Service (Port 8081)
2. **hw** - Home Web Service (Port 8080)
3. **fx** - FX Service (Port 8100) + Volume-Mount
4. **co** - CO Service (Port 8101) + Volume-Mount
5. **io** - IO Service (Port 8102) + Volume-Mount
6. **hk** - HK Service (Port 8103)
7. **users** - Users/Members Service (Port 8000) + Volume-Mount
8. **streams** - Streams Service (Port 8001) + Volume-Mount
9. **preferences** - Preferences Service (Port 8002)
10. **metadata** - Metadata Service (Port 8003)
11. **logging** - Logging Service (Port 8004)
12. **amqp** - AMQP Service (Port 8005)
13. **license** - License Service (Port 8006) + Volume-Mount
14. **language** - Language Service (Port 8007)
15. **cronjob** - Cronjob Service
16. **xmlgenerator** - XML Generator Service + Volume-Mount

## Ingress Routes

Alle Routes werden automatisch erstellt:
- `/v1/fx` → fx:8100
- `/v1/co` → co:8101
- `/v1/io` → io:8102
- `/v1/hk` → hk:8103
- `/v1/members`, `/v1/ws` → users:8000
- `/v1/streams`, `/streamdesigner` → streams:8001
- `/v1/preferences` → preferences:8002
- `/v1/metadata` → metadata:8003
- `/v1/logging` → logging:8004
- `/v1/amqp` → amqp:8005
- `/v1/license`, `/v1/client` → license:8006
- `/v1/language`, `/v1/languages` → language:8007
- `/ws` → rabbitmq:15674 (WebStomp)
- `/panel` → hp:8081
- `/mongodb` → mongoadmin:8199
- `/` → hw:8080

## Default Werte (in values.yaml)

- MongoDB: 3 Replicas, 50Gi Storage, rootUser: root, password: bitte
- RabbitMQ: 3 Replicas, 30Gi Storage, defaultUser: root, password: bitte
- Elasticsearch: 1 Replica, 30Gi Storage
- Service Replicas: 2 (für Production anpassen)
- Storage Size: 100Gi
- Namespace: helmut4

## Nächste Schritte zur Verwendung

```bash
# 1. Docker Credentials einstellen
helm install helmut4 ./helmut4 \
  --namespace helmut4 \
  --create-namespace \
  --set docker.username="your-user" \
  --set docker.password="your-pass"

# 2. Oder mit Production Values
helm install helmut4 ./helmut4 \
  -f examples/values-production.yaml \
  -f examples/values-docker-credentials.yaml

# 3. Status prüfen
./scripts/health-check.sh helmut4
```

Alle konfigurierbaren Werte sind dokumentiert in `helmut4/values.yaml`!
