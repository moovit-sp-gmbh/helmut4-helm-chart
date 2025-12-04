# Troubleshooting Guide

## 1. Pod-Probleme

### Pod startet nicht oder bleibt Pending

```bash
# Status prüfen
kubectl get pods -n helmut4
kubectl describe pod -n helmut4 <pod-name>

# Mögliche Ursachen:
# - Insufficient resources (CPU, Memory)
# - PersistentVolumeClaim pending
# - Image Pull Fehler
```

**Lösung:**
```bash
# 1. Resources prüfen
kubectl describe node | grep -A 5 "Allocated resources"

# 2. PVC Status prüfen
kubectl get pvc -n helmut4

# 3. Image verfügbar?
kubectl describe pod -n helmut4 <pod-name> | grep -A 5 "Events:"
```

### CrashLoopBackOff

Pod startet und crasht sofort wieder.

```bash
# Logs anschauen
kubectl logs -n helmut4 <pod-name> --tail=50

# Mit Previous Log (letzter Crash)
kubectl logs -n helmut4 <pod-name> --previous
```

**Häufige Ursachen:**
- Abhängigkeit nicht erreichbar (MongoDB, RabbitMQ)
- Falsche Konfiguration
- Falsche Credentials

### ImagePullBackOff

Image kann nicht gepullt werden.

```bash
# Pull Secrets prüfen
kubectl get secret -n helmut4 docker-registry-secret -o yaml

# Pod Events prüfen
kubectl describe pod -n helmut4 <pod-name> | grep "Pull"
```

**Lösung:**
```bash
# Credentials überprüfen
echo "Username: $DOCKER_USER"
echo "Password: $DOCKER_PASS"

# Manuell testen
docker login repo.moovit24.de:443
docker pull repo.moovit24.de:443/mcp_fx:4.9.1.1
```

## 2. Database-Probleme

### MongoDB Pods nicht ready

```bash
# MongoDB Status
kubectl get statefulset mongodb -n helmut4
kubectl get pods -n helmut4 -l app=mongodb

# Logs prüfen
kubectl logs -n helmut4 mongodb-0

# Replica-Set Status
kubectl exec -n helmut4 -it mongodb-0 -- mongo -u root -p bitte --eval "rs.status()"
```

**Typische Fehler:**
```
error: connect ECONNREFUSED 127.0.0.1:27017
# → MongoDB läuft noch nicht, warten

error: auth failed
# → Credentials falsch
```

**Lösung:**
```bash
# 1. Sicherstellen, dass alle Pods laufen
kubectl wait --for=condition=ready pod -l app=mongodb -n helmut4 --timeout=300s

# 2. Replica-Set manuell initialisieren
kubectl exec -n helmut4 -it mongodb-0 -- mongo -u root -p bitte --eval \
  "rs.initiate({_id:'rs0',members:[{_id:0,host:'mongodb-0.mongodb-headless'}]})"

# 3. Weitere Nodes hinzufügen
kubectl exec -n helmut4 -it mongodb-0 -- mongo -u root -p bitte --eval \
  "rs.add('mongodb-1.mongodb-headless'); rs.add('mongodb-2.mongodb-headless')"
```

### RabbitMQ Pods nicht ready

```bash
# RabbitMQ Status
kubectl get statefulset rabbitmq -n helmut4
kubectl get pods -n helmut4 -l app=rabbitmq

# Logs prüfen
kubectl logs -n helmut4 rabbitmq-0

# Health Check
kubectl exec -n helmut4 -it rabbitmq-0 -- rabbitmq-diagnostics ping
```

**Lösung:**
```bash
# 1. Warten bis alle Pods starten
kubectl wait --for=condition=ready pod -l app=rabbitmq -n helmut4 --timeout=300s

# 2. Cluster Status prüfen
kubectl exec -n helmut4 -it rabbitmq-0 -- rabbitmqctl cluster_status
```

### Services können nicht auf Datenbanken zugreifen

```bash
# Service → Database Connectivity prüfen
kubectl exec -n helmut4 -it fx-0 -- nc -zv mongodb-0.mongodb-headless 27017

# DNS Auflösung testen
kubectl exec -n helmut4 -it fx-0 -- nslookup mongodb.helmut4.svc.cluster.local

# Logs des Services prüfen
kubectl logs -n helmut4 deployment/fx --tail=100
```

## 3. Ingress-Probleme

### Ingress wird nicht erstellt

```bash
# Ingress Status prüfen
kubectl get ingress -n helmut4

# Ingress Details
kubectl describe ingress -n helmut4 helmut4-helmut4-ingress
```

**Lösungen:**
```bash
# 1. Nginx Ingress Controller installiert?
kubectl get ingressclass
kubectl get pods -n ingress-nginx

# 2. Wenn nicht, installieren:
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install nginx-ingress ingress-nginx/ingress-nginx -n ingress-nginx --create-namespace
```

### Domain nicht erreichbar

```bash
# Ingress IP/Hostname prüfen
kubectl get ingress -n helmut4 helmut4-helmut4-ingress -o wide

# DNS prüfen
nslookup api.your-domain.com

# Ingress testen
curl -k https://api.your-domain.com/health
```

**Typische Fehler:**

1. **503 Service Unavailable**
   - Backend Service nicht erreichbar
   - Pods sind nicht ready

2. **502 Bad Gateway**
   - Backend Service Fehler
   - Falsche Port-Konfiguration

3. **404 Not Found**
   - Path nicht im Ingress definiert
   - Falsche Route

**Debugging:**
```bash
# Ingress Controller Logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx -f

# Service Endpoints prüfen
kubectl get endpoints -n helmut4

# Port-Forward testen
kubectl port-forward -n helmut4 svc/fx 8100:8100
curl http://localhost:8100/health
```

## 4. Storage-Probleme

### PVC bleibt Pending

```bash
# PVC Status
kubectl get pvc -n helmut4
kubectl describe pvc helmut-storage-pvc -n helmut4

# StorageClass prüfen
kubectl get storageclass
```

**Lösungen:**
```bash
# 1. CSI Driver installiert?
kubectl get pods -n kube-system | grep csi

# 2. Available PersistentVolumes?
kubectl get pv

# 3. Fallback auf Minikube/Local Storage
kubectl create storageclass local-storage \
  --provisioner kubernetes.io/no-provisioner \
  --reclaim-policy Delete
```

### Pod kann nicht an PVC binden

```bash
# Pod Events prüfen
kubectl describe pod -n helmut4 <pod-name> | grep -A 10 "Events:"

# Volume Status prüfen
kubectl get volumeattachments

# CSI Driver Logs
kubectl logs -n kube-system -l app=csi-driver -f
```

## 5. Performance-Probleme

### Pods sind langsam

```bash
# Resource Usage prüfen
kubectl top nodes
kubectl top pods -n helmut4

# Wenn nicht verfügbar: Metrics Server installieren
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

**Optimierungen:**
```bash
# 1. Limits prüfen
kubectl describe pod -n helmut4 <pod-name> | grep -A 5 "Limits\|Requests"

# 2. Zu niedrig? Erhöhen
kubectl set resources deployment fx -n helmut4 \
  --requests=cpu=1,memory=2Gi \
  --limits=cpu=2,memory=4Gi

# 3. Nodes prüfen
kubectl describe nodes | grep -A 5 "Allocated resources"
```

### High CPU/Memory Usage

```bash
# Top Pods anschauen
kubectl top pods -n helmut4 --sort-by=cpu
kubectl top pods -n helmut4 --sort-by=memory

# Service-spezifische Logs
kubectl logs -n helmut4 <high-usage-pod> --tail=200
```

## 6. Network-Probleme

### Pods können sich nicht untereinander erreichen

```bash
# Connectivity testen
kubectl run -it --image=busybox --restart=Never test-pod -- sh

# Im Pod:
wget http://fx:8100/health  # Sollte funktionieren
nc -zv mongodb 27017        # Sollte offen sein
```

### DNS Resolution Fehler

```bash
# DNS Service prüfen
kubectl get pods -n kube-system | grep coredns

# DNS testen
kubectl exec -it <pod> -- nslookup kubernetes.default
kubectl exec -it <pod> -- nslookup fx.helmut4.svc.cluster.local
```

## 7. Logging und Monitoring

### Alle Logs einer Komponente

```bash
# MongoDB Logs
kubectl logs -n helmut4 -l app=mongodb --all-containers=true --tail=100

# RabbitMQ Logs
kubectl logs -n helmut4 -l app=rabbitmq --all-containers=true --tail=100

# Alle Service Logs
kubectl logs -n helmut4 --all-containers=true -f
```

### Events monitoren

```bash
# Neueste Events
kubectl get events -n helmut4 --sort-by='.lastTimestamp'

# Kontinuierlich
kubectl get events -n helmut4 -w
```

## 8. Debug Commands

### Shell in Pod bekommen

```bash
# Interaktive Shell
kubectl exec -it -n helmut4 <pod-name> -- /bin/bash

# Oder sh für Alpine
kubectl exec -it -n helmut4 <pod-name> -- /bin/sh
```

### Port-Forwarding

```bash
# Service direkt zugreifen
kubectl port-forward -n helmut4 svc/mongodb 27017:27017

# Im anderen Terminal
mongo -u root -p bitte localhost:27017
```

### Copy Dateien

```bash
# Aus Pod kopieren
kubectl cp helmut4/<pod>:/path/to/file ./local-file

# In Pod kopieren
kubectl cp ./local-file helmut4/<pod>:/path/to/file
```

## 9. Checkliste für neuen Deployment

- [ ] Alle Pods sind in Ready state
- [ ] Keine CrashLoopBackOff oder Pending Pods
- [ ] MongoDB Replica-Set funktioniert
- [ ] RabbitMQ Cluster funktioniert
- [ ] Ingress ist erstellt
- [ ] Domain ist erreichbar
- [ ] Logs sind sauber (kein Errors)
- [ ] PVCs sind Bound
- [ ] Alle Services sind verfügbar
- [ ] Credentials sind korrekt

## 10. Emergency Procedures

### Kompletter Reset

```bash
# WARNUNG: LÖSCHT ALLE DATEN!
helm uninstall helmut4 -n helmut4
kubectl delete pvc --all -n helmut4
kubectl delete namespace helmut4

# Neu deployen
helm install helmut4 ./helmut4 -n helmut4 --create-namespace
```

### Schneller Restart

```bash
# Alle Pods neustarten
kubectl rollout restart deployment -n helmut4
kubectl rollout restart statefulset -n helmut4
```

### Dry-Run für Debugging

```bash
helm install helmut4 ./helmut4 -n helmut4 --dry-run --debug > output.yaml
```

## Kontakt und Support

Für weitere Hilfe:
1. Prüfen Sie die Logs: `kubectl logs`
2. Beschreiben Sie die Ressourcen: `kubectl describe`
3. Prüfen Sie Events: `kubectl get events`
4. Kontaktieren Sie das Team mit den Logs
