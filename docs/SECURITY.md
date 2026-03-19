# Security Best Practices

## 1. Docker Registry Credentials

### Secure handling

**Not recommended**: Credentials in `values.yaml`
```yaml
# Never commit this to version control!
docker:
  username: "myuser"
  password: "mypassword"
```

**Recommended**: All credentials in `install-values.yaml` (not in git):
```yaml
# install-values.yaml (add to .gitignore!)
docker:
  username: "myuser"
  password: "mypassword"
  email: "my@email.com"
```

```bash
# Install using the values file
helm upgrade helmut4 --install -n helmut4 --create-namespace   -f install-values.yaml ./helmut4

# Alternative: create an existing registry secret
kubectl create secret docker-registry my-creds   --docker-server=repo.moovit24.de:443   --docker-username=myuser   --docker-password=mypassword
```

## 2. Database Credentials

### Set MongoDB password

```yaml
# In install-values.yaml
mongodb:
  auth:
    rootUsername: "root"
    rootPassword: "super-secure-password"
```

```bash
helm upgrade helmut4 --install -n helmut4 --create-namespace   -f install-values.yaml ./helmut4
```

### Set RabbitMQ password

```yaml
# In install-values.yaml
rabbitmq:
  auth:
    username: "root"
    password: "super-secure-password"
    erlangCookie: "your-erlang-cookie"
```

## 3. RBAC (Role-Based Access Control)

The chart creates namespace-scoped RBAC resources by default:

```yaml
rbac:
  create: true
```

This creates a `Role` and `RoleBinding` — no `ClusterRole` is used.

### Custom role binding

```bash
kubectl create rolebinding helmut4-admin   --clusterrole=edit   --serviceaccount=helmut4:helmut4-sa   -n helmut4
```

## 4. Network Policies

### Restrict traffic

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

Apply:
```bash
kubectl apply -f network-policy.yaml
```

## 5. TLS/SSL Configuration

### With cert-manager

```bash
# 1. Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# 2. Create ClusterIssuer
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
```

```yaml
# In install-values.yaml
ingress:
  tls:
    enabled: true
    provider: "letsencrypt"
    certIssuer: "letsencrypt-prod"
    secretName: "helmut4-tls"
```

```bash
helm upgrade helmut4 --install -n helmut4 --create-namespace   -f install-values.yaml ./helmut4
```

## 6. Resource Limits and Quotas

### Namespace quota

```yaml
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

### Pod limits

```yaml
# In install-values.yaml
services:
  fx:
    resources:
      limits:
        cpu: "2"
        memory: "2Gi"
      requests:
        cpu: "500m"
        memory: "1Gi"
```

## 7. Secrets Management

### Using External Secrets Operator (ESO)

```bash
# 1. Install External Secrets Operator
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets -n external-secrets-system

# 2. Create SecretStore
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

# 3. Create ExternalSecret
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

## 8. Audit Logging

### Enable API audit

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

## 9. Compliance Checklist

- [ ] Docker credentials not in git
- [ ] Database passwords changed from defaults
- [ ] RBAC enabled (namespace-scoped)
- [ ] Network policies defined
- [ ] TLS/SSL configured
- [ ] Resource limits set
- [ ] Audit logging enabled
- [ ] External secrets for sensitive data
- [ ] Regular backups tested
- [ ] `install-values.yaml` added to `.gitignore`

## Further Resources

- [Kubernetes Security Best Practices](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
- [cert-manager Documentation](https://cert-manager.io/)
- [External Secrets Operator](https://external-secrets.io/)
