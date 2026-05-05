# helmut4

![Version: 1.0.0](https://img.shields.io/badge/Version-1.0.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 4.9.1](https://img.shields.io/badge/AppVersion-4.9.1-informational?style=flat-square)

A Helm chart for Helmut4 microservices application

**Homepage:** <https://github.com/yourusername/helmut4-helm-chart>

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| Your Name | <your.email@example.com> |  |

## Source Code

* <https://github.com/yourusername/helmut4-helm-chart>

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| oci://registry-1.docker.io/cloudpirates | mongodb | 0.10.3 |
| oci://registry-1.docker.io/cloudpirates | rabbitmq | 0.7.10 |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| appIngress | object | `{"annotations":{"nginx.ingress.kubernetes.io/proxy-http-version":"1.1","nginx.ingress.kubernetes.io/proxy-read-timeout":"3600","nginx.ingress.kubernetes.io/proxy-send-timeout":"3600","nginx.ingress.kubernetes.io/ssl-redirect":"true"},"className":"nginx","domain":"helmut-k8s.moovit24.de","enabled":true,"tls":{"certFile":"/etc/tls/certs/tls.crt","certIssuer":"letsencrypt-prod","enabled":true,"keyFile":"/etc/tls/certs/tls.key","provider":"letsencrypt","secretName":"helmut4-tls"}}` | Public Ingress that fronts every Helmut4 microservice (one host, many path prefixes). Disabling this requires routing the services through another mechanism. |
| appIngress.annotations | object | `{"nginx.ingress.kubernetes.io/proxy-http-version":"1.1","nginx.ingress.kubernetes.io/proxy-read-timeout":"3600","nginx.ingress.kubernetes.io/proxy-send-timeout":"3600","nginx.ingress.kubernetes.io/ssl-redirect":"true"}` | Annotations applied to the Ingress object. The defaults enable WebSocket support for STOMP-over-WS (RabbitMQ `/ws`) and the users service (`/v1/ws`); ingress-nginx already sets `Upgrade`/`Connection` natively, so only HTTP/1.1 and the long timeouts need to be forced explicitly. |
| appIngress.className | string | `"nginx"` | IngressClass name. The chart is tested against `nginx` (kubernetes/ingress-nginx); other controllers may need different annotations. |
| appIngress.domain | string | `"helmut-k8s.moovit24.de"` | Public hostname terminated by the Ingress. |
| appIngress.enabled | bool | `true` | Render the application Ingress object. |
| appIngress.tls.certFile | string | `"/etc/tls/certs/tls.crt"` | Container path of the TLS certificate when `tls.provider` is `custom`. Mounted from a pre-existing Secret. |
| appIngress.tls.certIssuer | string | `"letsencrypt-prod"` | cert-manager ClusterIssuer used when `tls.provider` is `letsencrypt` (typically `letsencrypt-prod` or `letsencrypt-staging`). |
| appIngress.tls.enabled | bool | `true` | Enable TLS termination on the Ingress. |
| appIngress.tls.keyFile | string | `"/etc/tls/certs/tls.key"` | Container path of the TLS private key when `tls.provider` is `custom`. Mounted from a pre-existing Secret. |
| appIngress.tls.provider | string | `"letsencrypt"` | TLS provider. `letsencrypt` makes cert-manager issue a certificate; `custom` reuses the cert/key paths configured below. |
| appIngress.tls.secretName | string | `"helmut4-tls"` | Name of the Secret used by the TLS section of the Ingress. Created automatically when `tls.provider` is `letsencrypt`. |
| credentials | object | `{"storage":{"nfs":{"password":"","username":""},"smb":{"domain":"","password":"","username":""}}}` | Storage credentials forwarded to CSI drivers (SMB / NFS) that mount external file shares into the Helmut4 pods. Empty values mean the chart does not create the corresponding `Secret`. |
| credentials.storage.nfs.password | string | `""` | NFS password. Most NFS setups are anonymous; leave empty unless your server requires authentication. |
| credentials.storage.nfs.username | string | `""` | NFS user. Most NFS setups are anonymous; leave empty unless your server requires authentication. |
| credentials.storage.smb.domain | string | `""` | Optional SMB domain. |
| credentials.storage.smb.password | string | `""` | SMB password. Leave empty if SMB is not used. |
| credentials.storage.smb.username | string | `""` | SMB user (e.g. `domain\\user` or plain `user`). Leave empty if SMB is not used. |
| docker | object | `{"email":"","password":"public","registry":"repo.moovit24.de:443","username":"moovit"}` | Credentials for the private Docker registry that hosts the Helmut4 images. Rendered into a `kubernetes.io/dockerconfigjson` Secret named `docker-registry-secret-json` and referenced via `global.imagePullSecrets`. |
| docker.email | string | `""` | Optional contact email written into the dockerconfigjson Secret. |
| docker.password | string | `"public"` | Registry password. The default `public` works for the public images. |
| docker.registry | string | `"repo.moovit24.de:443"` | Registry hostname (and optional port) that the Secret is scoped to. |
| docker.username | string | `"moovit"` | Registry username. The default `moovit` works for the public images. |
| global | object | `{"environment":"production","imagePullPolicy":"IfNotPresent","imagePullSecrets":[{"name":"docker-registry-secret-json"}],"registry":"repo.moovit24.de:443","storage":{"csiDriver":"csi-driver-name","mountPath":"/Volumes/Helmut","storageClassName":"helmut4-csi-storage","volume":{"size":"100Gi","source":""}}}` | Cluster-wide defaults shared by every microservice Deployment. |
| global.environment | string | `"production"` | Free-form environment tag exposed to the workloads. Common values are `production`, `staging`, `development`. |
| global.imagePullPolicy | string | `"IfNotPresent"` | Pod-level image pull policy applied to every container the chart renders. One of `Always`, `IfNotPresent`, `Never`. |
| global.imagePullSecrets | list | `[{"name":"docker-registry-secret-json"}]` | List of `imagePullSecrets` attached to every workload. The default entry refers to the Secret created from `docker.*` below. |
| global.registry | string | `"repo.moovit24.de:443"` | Docker registry hostname (and optional port) prefixed to every image reference rendered from `services.<name>.image`. |
| global.storage.csiDriver | string | `"csi-driver-name"` | CSI driver that backs the application file storage (e.g. `smb.csi.k8s.io`, `nfs.csi.k8s.io`). The chart only references the name; the driver itself must already be installed in the cluster. |
| global.storage.mountPath | string | `"/Volumes/Helmut"` | Path inside the containers where the shared storage is mounted. |
| global.storage.storageClassName | string | `"helmut4-csi-storage"` | Name of the StorageClass the chart creates and consumes for the `/Volumes/Helmut` mount. |
| global.storage.volume.size | string | `"100Gi"` | Size requested for the main `/Volumes` PVC. |
| global.storage.volume.source | string | `""` | Backend share to mount. Use `//server/share` for SMB and `server:/path` for NFS. Leave empty to use dynamic provisioning. |
| mongodb | object | `{"auth":{"existingPasswordKey":"mongodb-root-password","existingSecret":"","existingUsernameKey":"","rootPassword":"***REMOVED***","rootUsername":"root"},"database":"helmut4","enabled":true,"extraObjects":[{"apiVersion":"v1","kind":"Service","metadata":{"name":"mongodb","namespace":"{{ .Release.Namespace }}"},"spec":{"ports":[{"port":27017,"protocol":"TCP","targetPort":27017}],"selector":{"app.kubernetes.io/instance":"{{ .Release.Name }}","app.kubernetes.io/name":"mongodb","service-type":"primary-secondary"},"type":"ClusterIP"}}],"fullnameOverride":"mongodb","metrics":{"enabled":false},"persistence":{"accessMode":"ReadWriteOnce","enabled":true,"size":"50Gi","storageClass":"longhorn"},"replicaSet":{"enabled":true,"key":"***REMOVED***=","name":"rs0"},"resources":{"limits":{"cpu":"8","memory":"8Gi"},"requests":{"cpu":"4","memory":"4Gi"}}}` | Bundled cloudpirates/mongodb subchart. Only the keys the parent chart overrides are listed below; everything not mentioned falls through to the subchart's own defaults (see its README and `values.schema.json`). |
| mongodb.auth.existingPasswordKey | string | `"mongodb-root-password"` | Key inside `existingSecret` that holds the password. |
| mongodb.auth.existingSecret | string | `""` | Reuse an existing Secret instead of letting the chart create one. When set, no `mongodb-credentials` Secret is rendered – the subchart already creates a Secret named after `fullnameOverride` with key `mongodb-root-password`, which can be referenced here. |
| mongodb.auth.existingUsernameKey | string | `""` | Key inside `existingSecret` that holds the username. Empty means the subchart's default key. |
| mongodb.auth.rootPassword | string | `"***REMOVED***"` | MongoDB root password. Replace before exposing the service. |
| mongodb.auth.rootUsername | string | `"root"` | MongoDB root username. |
| mongodb.database | string | `"helmut4"` | Database created at first start; the microservices connect to it by name. |
| mongodb.enabled | bool | `true` | Enable the bundled MongoDB subchart. |
| mongodb.extraObjects | list | `[{"apiVersion":"v1","kind":"Service","metadata":{"name":"mongodb","namespace":"{{ .Release.Namespace }}"},"spec":{"ports":[{"port":27017,"protocol":"TCP","targetPort":27017}],"selector":{"app.kubernetes.io/instance":"{{ .Release.Name }}","app.kubernetes.io/name":"mongodb","service-type":"primary-secondary"},"type":"ClusterIP"}}]` | Chart-native extension point (documented in cloudpirates/mongodb README). In replicaSet mode the subchart only creates the headless service (`mongodb-headless`). The microservice startup scripts perform a TCP health-check against `mongodb:27017` before Spring Boot starts, so we add a regular ClusterIP service via `extraObjects` to make that name resolve. Spring Boot itself connects via `SPRING_DATA_MONGODB_HOST`, which still points at the headless service for full replica-set topology awareness. |
| mongodb.fullnameOverride | string | `"mongodb"` | Override the rendered Service / StatefulSet name (kept short so the microservices can reach `mongodb:27017`). |
| mongodb.metrics.enabled | bool | `false` | Enable the metrics exporter sidecar from the subchart. |
| mongodb.persistence | object | `{"accessMode":"ReadWriteOnce","enabled":true,"size":"50Gi","storageClass":"longhorn"}` | Persistent storage for MongoDB data. Use a block-storage class (e.g. Longhorn) – NOT the SMB share. SMB is a file-share and causes problems with MongoDB (locking, stale data on reinstall because the share is not wiped when PVCs are deleted). |
| mongodb.persistence.accessMode | string | `"ReadWriteOnce"` | PVC access mode. |
| mongodb.persistence.enabled | bool | `true` | Bind a PVC to each replica. |
| mongodb.persistence.size | string | `"50Gi"` | Size of every replica's PVC. |
| mongodb.persistence.storageClass | string | `"longhorn"` | StorageClass that backs the PVCs. Block storage only. |
| mongodb.replicaSet.enabled | bool | `true` | Run MongoDB as a 3-node replica set. Disabling this falls back to standalone mode and breaks the microservices' default connection string. |
| mongodb.replicaSet.key | string | `"***REMOVED***="` | Replica set keyfile contents (base64). Replace before exposing. |
| mongodb.replicaSet.name | string | `"rs0"` | Replica set name. |
| mongodb.resources | object | `{"limits":{"cpu":"8","memory":"8Gi"},"requests":{"cpu":"4","memory":"4Gi"}}` | Resource requests / limits forwarded to every MongoDB pod. |
| namespace | string | `"helmut4"` | Kubernetes namespace that owns every resource this chart creates. |
| rabbitmq | object | `{"additionalPlugins":["rabbitmq_stomp","rabbitmq_web_stomp"],"auth":{"erlangCookie":"***REMOVED***","existingErlangCookieKey":"erlang-cookie","existingPasswordKey":"password","password":"***REMOVED***","username":"root"},"config":{"extraConfiguration":"web_stomp.tcp.port = 15674\n"},"extraPorts":[{"containerPort":15674,"name":"web-stomp","port":15674,"targetPort":15674}],"fullnameOverride":"rabbitmq","ingress":{"enabled":false,"tls":[]},"metrics":{"enabled":false},"peerDiscoveryK8sPlugin":{"addressType":"hostname","enabled":false},"persistence":{"enabled":false},"rbac":{"create":true},"replicaCount":1,"service":{"type":"ClusterIP"},"serviceAccount":{"create":true},"webstomp":15674}` | Bundled cloudpirates/rabbitmq subchart. Single-node by design: a multi-node RabbitMQ cluster only delivers HA when ALL of these are in place:   1. Quorum queues (`default_queue_type = quorum`) – classic mirrored      queues were removed in RabbitMQ 4.0, so quorum (or streams) is the      only replicated queue type left. This also requires the Helmut4      services to either declare quorum queues explicitly or rely on the      `default_queue_type` setting.   2. Per-pod persistent storage – without it the Mnesia metadata and any      quorum-queue Raft state are wiped on every pod restart.   3. podAntiAffinity – otherwise multiple rabbitmq pods can land on the      same Kubernetes node and a single node loss takes the cluster below      quorum.   4. A PodDisruptionBudget – to keep node drains from doing the same. Without those four pieces a 3-node cluster shares topology (publish to any node, consume from any node), but each message still lives on the single node that owns its classic queue – so a node loss makes that queue unavailable. Same failure mode as a single node, with more moving parts and split-brain risk on top. Until those four pieces are added, one node is more honest than three. |
| rabbitmq.additionalPlugins | list | `["rabbitmq_stomp","rabbitmq_web_stomp"]` | Plugins enabled in addition to the subchart's defaults. `rabbitmq_web_stomp` serves STOMP-over-WebSocket on `/ws` (port 15674); `rabbitmq_stomp` is the underlying dependency – list it explicitly so `enabled_plugins` does not rely on transitive resolution. |
| rabbitmq.auth.erlangCookie | string | `"***REMOVED***"` | Erlang cookie used by the cluster nodes. Replace before exposing. |
| rabbitmq.auth.existingErlangCookieKey | string | `"erlang-cookie"` | Key inside the existing Secret that holds the Erlang cookie. |
| rabbitmq.auth.existingPasswordKey | string | `"password"` | Key inside the existing Secret that holds the password. |
| rabbitmq.auth.password | string | `"***REMOVED***"` | RabbitMQ password. Replace before exposing the service. |
| rabbitmq.auth.username | string | `"root"` | RabbitMQ user. |
| rabbitmq.config.extraConfiguration | string | `"web_stomp.tcp.port = 15674\n"` | Free-form snippet appended to `rabbitmq.conf`. Pins the web_stomp listener; the plugin default is also `15674` but being explicit avoids surprises on plugin upgrades. |
| rabbitmq.extraPorts | list | `[{"containerPort":15674,"name":"web-stomp","port":15674,"targetPort":15674}]` | Extra ports added to the rabbitmq Service AND StatefulSet pod. The entry below exposes the web_stomp port so the parent Ingress (`/ws -> rabbitmq:15674`) has a real upstream to talk to. |
| rabbitmq.fullnameOverride | string | `"rabbitmq"` | Subchart release name override (controls Service/StatefulSet names). |
| rabbitmq.ingress | object | `{"enabled":false,"tls":[]}` | Disable the subchart's own Ingress – routing is handled by the parent application Ingress (`appIngress`). |
| rabbitmq.metrics.enabled | bool | `false` | Enable the Prometheus exporter shipped with the subchart. |
| rabbitmq.peerDiscoveryK8sPlugin | object | `{"addressType":"hostname","enabled":false}` | K8s peer discovery is only meaningful in a multi-node cluster. Disabled for the single-node deployment so the pod does not waste cycles looking for peers it will never find. |
| rabbitmq.peerDiscoveryK8sPlugin.addressType | string | `"hostname"` | Address type used to discover peers (`hostname` or `ip`). |
| rabbitmq.peerDiscoveryK8sPlugin.enabled | bool | `false` | Enable the rabbitmq_peer_discovery_k8s plugin. |
| rabbitmq.persistence | object | `{"enabled":false}` | PVC settings for the RabbitMQ data directory. Disabled for the single-node deployment; flip to `enabled: true` (and add a real storageClass / size) before scaling out – see the block comment above this `rabbitmq` section. |
| rabbitmq.rbac.create | bool | `true` | Render Role / RoleBinding for the RabbitMQ pods. |
| rabbitmq.replicaCount | int | `1` | Number of RabbitMQ pods. Keep at `1` until quorum queues + persistence + podAntiAffinity + PDB are all in place; see the block comment above for the reasoning. |
| rabbitmq.service.type | string | `"ClusterIP"` | Service type for the RabbitMQ Service. The parent Ingress fronts the WebSocket path, so a ClusterIP is enough. |
| rabbitmq.serviceAccount.create | bool | `true` | Render a dedicated ServiceAccount for the RabbitMQ pods. |
| rabbitmq.webstomp | int | `15674` | Port the parent application Ingress targets for the STOMP-over-WebSocket route (`/ws`). Must match the rabbitmq web_stomp listener configured below. |
| rbac.create | bool | `true` | Render the RBAC `Role` / `RoleBinding` that the microservices need. |
| rbac.createNamespace | bool | `true` | Also render a `Namespace` object. Set to `false` if the namespace already exists or is managed elsewhere. |
| serviceAccount.create | bool | `true` | Render a dedicated ServiceAccount for the workloads. |
| serviceAccount.name | string | `"helmut4-sa"` | Name of the ServiceAccount referenced from every Deployment. |
| serviceReplicas | int | `2` | Default replica count for any microservice that does not set its own `services.<name>.replicas`. |
| services | object | `{"amqp":{"image":"mcc_amqp","name":"amqp","port":8005,"replicas":2,"resources":{"limits":{"cpu":"2","memory":"2Gi"},"requests":{"cpu":"500m","memory":"1Gi"}},"tag":"4.12.0.0"},"co":{"image":"mcp_co","name":"co","port":8101,"replicas":2,"resources":{"limits":{"cpu":"2","memory":"2Gi"},"requests":{"cpu":"500m","memory":"1Gi"}},"tag":"4.12.0.6","volumeMounts":true},"cronjob":{"image":"mcc_cronjob","name":"cronjob","port":8008,"replicas":1,"resources":{"limits":{"cpu":"1","memory":"1Gi"},"requests":{"cpu":"250m","memory":"512Mi"}},"tag":"4.12.0.0"},"fx":{"image":"mcp_fx","name":"fx","port":8100,"replicas":2,"resources":{"limits":{"cpu":"2","memory":"2Gi"},"requests":{"cpu":"500m","memory":"1Gi"}},"tag":"4.12.0.2","volumeMounts":true},"hk":{"image":"mcp_hk","name":"hk","port":8103,"replicas":1,"resources":{"limits":{"cpu":"2","memory":"2Gi"},"requests":{"cpu":"500m","memory":"1Gi"}},"tag":"4.12.0.0"},"hp":{"image":"mcp_hp","name":"hp","port":8081,"replicas":2,"resources":{"limits":{"cpu":"1","memory":"1Gi"},"requests":{"cpu":"250m","memory":"512Mi"}},"tag":"4.12.0.3"},"hw":{"image":"mcp_hw","name":"hw","port":8080,"replicas":2,"resources":{"limits":{"cpu":"1","memory":"1Gi"},"requests":{"cpu":"250m","memory":"512Mi"}},"tag":"4.12.0.3"},"io":{"image":"mcp_io","name":"io","port":8102,"replicas":2,"resources":{"limits":{"cpu":"2","memory":"2Gi"},"requests":{"cpu":"500m","memory":"1Gi"}},"tag":"4.12.0.1","volumeMounts":true},"language":{"image":"mcc_language","name":"language","port":8007,"replicas":2,"resources":{"limits":{"cpu":"1","memory":"1Gi"},"requests":{"cpu":"250m","memory":"512Mi"}},"tag":"4.12.0.0"},"license":{"image":"mcc_license","name":"license","port":8006,"replicas":1,"resources":{"limits":{"cpu":"2","memory":"2Gi"},"requests":{"cpu":"500m","memory":"1Gi"}},"tag":"4.12.0.3","volumeMounts":true},"logging":{"image":"mcc_logging","name":"logging","port":8004,"replicas":2,"resources":{"limits":{"cpu":"1","memory":"1Gi"},"requests":{"cpu":"250m","memory":"512Mi"}},"tag":"4.12.0.0"},"metadata":{"image":"mcc_metadata","name":"metadata","port":8003,"replicas":2,"resources":{"limits":{"cpu":"1","memory":"1Gi"},"requests":{"cpu":"250m","memory":"512Mi"}},"tag":"4.12.0.0"},"preferences":{"image":"mcc_preferences","name":"preferences","port":8002,"replicas":2,"resources":{"limits":{"cpu":"1","memory":"1Gi"},"requests":{"cpu":"250m","memory":"512Mi"}},"tag":"4.12.0.0"},"streams":{"image":"mcc_streams","name":"streams","port":8001,"replicas":2,"resources":{"limits":{"cpu":"2","memory":"2Gi"},"requests":{"cpu":"500m","memory":"1Gi"}},"tag":"4.12.0.5","volumeMounts":true},"users":{"image":"mcc_users","name":"users","port":8000,"replicas":2,"resources":{"limits":{"cpu":"2","memory":"2Gi"},"requests":{"cpu":"500m","memory":"1Gi"}},"tag":"4.12.0.1","volumeMounts":true}}` | Per-microservice deployment settings. Each key is a service identifier (`hp`, `hw`, `fx`, ...) and shares the same shape: `name`, `image`, `tag`, `port`, `replicas`, `resources` and an optional `volumeMounts` flag that enables the shared `/Volumes/Helmut` mount. Anchors below are resolved from the `versions:` block at the top. |
| versions | object | `{"amqp":"4.12.0.0","co":"4.12.0.6","cronjob":"4.12.0.0","fx":"4.12.0.2","hk":"4.12.0.0","hp":"4.12.0.3","hw":"4.12.0.3","io":"4.12.0.1","language":"4.12.0.0","license":"4.12.0.3","logging":"4.12.0.0","metadata":"4.12.0.0","mongodb":"4.12.0.0","preferences":"4.12.0.0","rabbitmq":"4.1.0.0","streams":"4.12.0.5","users":"4.12.0.1"}` | Centralised image tags so the whole stack bumps together. Anchors below are referenced from `mongodb.image.tag`, `rabbitmq.image.tag` and the `services.<name>.tag` entries. |
| versions.amqp | string | `"4.12.0.0"` | Image tag for the `amqp` microservice. |
| versions.co | string | `"4.12.0.6"` | Image tag for the `co` microservice. |
| versions.cronjob | string | `"4.12.0.0"` | Image tag for the `cronjob` microservice. |
| versions.fx | string | `"4.12.0.2"` | Image tag for the `fx` microservice. |
| versions.hk | string | `"4.12.0.0"` | Image tag for the `hk` microservice. |
| versions.hp | string | `"4.12.0.3"` | Image tag for the `hp` (HelmutPanel) microservice. |
| versions.hw | string | `"4.12.0.3"` | Image tag for the `hw` (HelmutWorker) microservice. |
| versions.io | string | `"4.12.0.1"` | Image tag for the `io` microservice. |
| versions.language | string | `"4.12.0.0"` | Image tag for the `language` microservice. |
| versions.license | string | `"4.12.0.3"` | Image tag for the `license` microservice. |
| versions.logging | string | `"4.12.0.0"` | Image tag for the `logging` microservice. |
| versions.metadata | string | `"4.12.0.0"` | Image tag for the `metadata` microservice. |
| versions.mongodb | string | `"4.12.0.0"` | Tag for the bundled cloudpirates/mongodb image. |
| versions.preferences | string | `"4.12.0.0"` | Image tag for the `preferences` microservice. |
| versions.rabbitmq | string | `"4.1.0.0"` | Tag for the bundled cloudpirates/rabbitmq image. |
| versions.streams | string | `"4.12.0.5"` | Image tag for the `streams` microservice. |
| versions.users | string | `"4.12.0.1"` | Image tag for the `users` microservice. |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
