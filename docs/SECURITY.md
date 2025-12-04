# Security Best Practices

## 1. Docker Registry Credentials

### Sichere Verwaltung

**NICHT empfohlen**: Credentials in `values.yaml` speichern
```yaml
# ❌ Nicht in Versionskontrolle!
docker:
  username: "myuser"
  password: "mypassword"
```

**Empfohlen**: Via Secrets oder Umgebungsvariablen
```bash
# Option 1: Helm CLI
helm install helmut4 ./helmut4 \
  --set docker.username="myuser" \
  --set docker.password="mypassword"

# Option 2: Separate Secret-Datei (nicht in git!)
helm install helmut4 ./helmut4 \
  -f docker-secrets.yaml

# Option 3: Existierendes Secret verwenden
kubectl create secret docker-registry my-creds \
  --docker-server=repo.moovit24.de:443 \
  --docker-username=myuser \
  --docker-password=mypassword
```

## 2. Database Credentials

### MongoDB Passwort ändern

```bash
# In values.yaml oder via helm set
helm install helmut4 ./helmut4 \
  --set mongodb.auth.rootPassword="super-secure-password"

# Nach Installation ändern
kubectl set env statefulset/mongodb \
  -n helmut4 \
  MONGO_INITDB_ROOT_PASSWORD="new-password"
```

### RabbitMQ Passwort ändern

```bash
# In values.yaml oder via helm set
helm install helmut4 ./helmut4 \
  --set rabbitmq.auth.defaultPassword="super-secure-password"
```

## 3. RBAC (Role-Based Access Control)

Das Chart erstellt automatisch RBAC-Ressourcen:

```yaml
rbac:
  create: true
```

### Eingeschränkte RBAC
Falls Sie mehr Kontrolle brauchen:

```bash
kubectl create rolebinding helmut4-admin \
  --clusterrole=edit \
  --serviceaccount=helmut4:helmut4-sa \
  -n helmut4
```

## 4. Network Policies

### Traffic beschränken

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: helmut4-deny-external
  namespace: helmut4
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: helmut4
```

Anwenden:
```bash
kubectl apply -f network-policy.yaml
```

## 5. TLS/SSL Konfiguration

### Mit cert-manager

```bash
# 1. cert-manager installieren
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# 2. ClusterIssuer erstellen
cat > letsencrypt-issuer.yaml <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF

kubectl apply -f letsencrypt-issuer.yaml

# 3. Chart mit TLS installieren
helm install helmut4 ./helmut4 \
  --set ingress.annotations."cert-manager\.io/cluster-issuer"=letsencrypt-prod \
  --set ingress.tls[0].secretName=helmut4-tls \
  --set ingress.tls[0].hosts[0]=api.your-domain.com
```

## 6. Pod Security Policies

### Restricted PSP

```yaml
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: helmut4-restricted
spec:
  privileged: false
  allowPrivilegeEscalation: false
  requiredDropCapabilities:
  - ALL
  volumes:
  - 'configMap'
  - 'emptyDir'
  - 'projected'
  - 'secret'
  - 'downwardAPI'
  - 'persistentVolumeClaim'
  hostNetwork: false
  hostIPC: false
  hostPID: false
  runAsUser:
    rule: 'MustRunAsNonRoot'
  seLinux:
    rule: 'MustRunAs'
    seLinuxOptions:
      level: "s0:c123,c456"
  supplementalGroups:
    rule: 'MustRunAs'
    ranges:
    - min: 1
      max: 65535
  fsGroup:
    rule: 'MustRunAs'
    ranges:
    - min: 1
      max: 65535
```

## 7. Secrets Management

### Using External Secrets (ESO)

```bash
# 1. External Secrets Operator installieren
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets -n external-secrets-system

# 2. SecretStore erstellen
cat > secretstore.yaml <<EOF
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: helmut4-vault
  namespace: helmut4
spec:
  provider:
    vault:
      server: "https://vault.example.com:8200"
      path: "secret"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "helmut4"
EOF

# 3. ExternalSecret erstellen
cat > external-secret.yaml <<EOF
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: docker-credentials
  namespace: helmut4
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: helmut4-vault
    kind: SecretStore
  target:
    name: docker-registry-secret
    creationPolicy: Owner
  data:
  - secretKey: username
    remoteRef:
      key: docker-username
  - secretKey: password
    remoteRef:
      key: docker-password
EOF
```

## 8. Resource Limits und Quotas

### Namespace Quota

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: helmut4
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: helmut4-quota
  namespace: helmut4
spec:
  hard:
    requests.cpu: "10"
    requests.memory: "20Gi"
    limits.cpu: "20"
    limits.memory: "40Gi"
    pods: "100"
    persistentvolumeclaims: "10"
```

### Pod Limits

```bash
kubectl set resources deployment fx \
  --limits=cpu=2,memory=2Gi \
  --requests=cpu=500m,memory=1Gi \
  -n helmut4
```

## 9. Audit Logging

### Enable API Audit

```yaml
# /etc/kubernetes/audit-policy.yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
- level: RequestResponse
  verbs: ["delete", "create", "update", "patch"]
  resources: ["statefulsets", "deployments", "pods"]
  namespaces: ["helmut4"]
```

## 10. Compliance Checkliste

- [ ] Docker Credentials nicht in git
- [ ] Database Passwörter geändert von Default
- [ ] RBAC aktiviert
- [ ] Network Policies definiert
- [ ] TLS/SSL konfiguriert
- [ ] Resource Limits gesetzt
- [ ] Audit Logging aktiviert
- [ ] Pod Security Policies durchgesetzt
- [ ] External Secrets für sensible Daten
- [ ] Regelmäßige Backups getestet

## Weitere Ressourcen

- [Kubernetes Security Best Practices](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [NIST Kubernetes Security](https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-190.pdf)
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
- [cert-manager Documentation](https://cert-manager.io/)
- [External Secrets Operator](https://external-secrets.io/)
