# Quick-Start Guide

## 1. Vorbereitung

Stellen Sie sicher, dass folgende Tools installiert sind:
- kubectl
- helm 3+
- Docker (für Image-Pull-Secrets)

## 2. Installation für Entwicklung (lokal)

```bash
# 1. Default values mit Development-Profil laden
helm install helmut4 ./helmut4 \
  --namespace helmut4 \
  --create-namespace \
  -f examples/values-development.yaml \
  -f examples/values-docker-credentials.yaml \
  --set docker.username="your-username" \
  --set docker.password="your-password"

# 2. Pods überwachen
kubectl get pods -n helmut4 -w

# 3. Status prüfen
kubectl get all -n helmut4
```

## 3. Installation für Production

```bash
# 1. Production values verwenden
helm install helmut4 ./helmut4 \
  --namespace helmut4 \
  --create-namespace \
  -f examples/values-production.yaml \
  -f examples/values-docker-credentials.yaml \
  --set global.domain="api.your-domain.com" \
  --set docker.username="your-username" \
  --set docker.password="your-password"

# 2. Alle Pods müssen läufen
kubectl get pods -n helmut4
```

## 4. Überprüfung der Installation

### MongoDB Status
```bash
# MongoDB Pods prüfen
kubectl get pods -n helmut4 -l app=mongodb

# MongoDB Replica-Set Status
kubectl exec -n helmut4 -it mongodb-0 -- mongo -u root -p bitte --eval "rs.status()"
```

### RabbitMQ Status
```bash
# RabbitMQ Pods prüfen
kubectl get pods -n helmut4 -l app=rabbitmq

# RabbitMQ Health Check
kubectl exec -n helmut4 -it rabbitmq-0 -- rabbitmq-diagnostics ping
```

### Ingress Status
```bash
kubectl get ingress -n helmut4
kubectl describe ingress -n helmut4 helmut4-helmut4-ingress
```

## 5. Zugriff auf Services

### MongoDB Admin
- URL: `https://api.your-domain.com/mongodb`
- Username: `root`
- Password: `bitte` (oder wie konfiguriert)

### API Endpoints
- Home: `https://api.your-domain.com/`
- FX Service: `https://api.your-domain.com/v1/fx`
- CO Service: `https://api.your-domain.com/v1/co`
- ... (siehe README für vollständige Liste)

## 6. Logs anschauen

```bash
# Service Logs
kubectl logs -n helmut4 -f deployment/fx

# MongoDB Logs
kubectl logs -n helmut4 -f statefulset/mongodb

# RabbitMQ Logs
kubectl logs -n helmut4 -f statefulset/rabbitmq
```

## 7. Services scalieren

```bash
# FX Service auf 5 Replicas skalieren
kubectl scale deployment fx --replicas=5 -n helmut4

# Aktuellen Status prüfen
kubectl get deployment -n helmut4
```

## 8. Upgrade durchführen

```bash
# Neue Version deployen
helm upgrade helmut4 ./helmut4 \
  --namespace helmut4 \
  -f examples/values-production.yaml

# Status checken
helm status helmut4 -n helmut4

# Bei Problemen zurückrollen
helm rollback helmut4 -n helmut4
```

## 9. Deinstallation

```bash
# Chart entfernen
helm uninstall helmut4 -n helmut4

# Namespace löschen (optional)
kubectl delete namespace helmut4

# PVCs löschen (optional - DATEN GEHEN VERLOREN!)
kubectl delete pvc -n helmut4 --all
```

## Häufige Probleme

### Pod startet nicht
```bash
# Pod Status prüfen
kubectl describe pod -n helmut4 <pod-name>

# Logs prüfen
kubectl logs -n helmut4 <pod-name>
```

### CrashLoopBackOff
- MongoDB oder RabbitMQ sind nicht erreichbar
- Prüfen Sie, ob die Dependencies running sind
- Checken Sie die Logs: `kubectl logs -n helmut4 <pod-name>`

### Ingress funktioniert nicht
- Nginx Ingress Controller installiert?
- TLS/Certificates konfiguriert?
- Domain richtig gesetzt?

```bash
# Ingress testen
kubectl port-forward -n helmut4 svc/nginx-ingress-ingress-nginx-controller 8080:80
curl http://localhost:8080/health
```

### MongoDB Replica-Set nicht initialisiert
```bash
# Manuelle Initialisierung
kubectl exec -n helmut4 -it mongodb-0 -- mongo -u root -p bitte --eval \
  "rs.initiate({_id:'rs0',members:[{_id:0,host:'mongodb-0.mongodb-headless:27017'}]})"
```

## Weitere Ressourcen

- Full README: [../README.md](../README.md)
- Examples: [../examples/](../examples/)
- Helm Documentation: https://helm.sh/
- Kubernetes Documentation: https://kubernetes.io/
