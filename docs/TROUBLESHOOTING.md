# Troubleshooting Guide

## 1. Pods not starting

### Check pod status

```bash
kubectl get pods -n helmut4
kubectl describe pod -n helmut4 <pod-name>
kubectl logs -n helmut4 <pod-name>
```

### Common states

| State | Cause | Solution |
|-------|-------|----------|
| `Pending` | No resources / PVC not bound | Check nodes, PVCs |
| `CrashLoopBackOff` | App error / DB not ready | Check logs |
| `ImagePullBackOff` | Wrong credentials / image not found | Check docker secret |
| `Init:Error` | Init container failed | Check init container logs |

### Init container logs

```bash
kubectl logs -n helmut4 <pod-name> -c <init-container-name>
```

## 2. MongoDB issues

### Replica set not forming

```bash
# Check RS status
kubectl exec -n helmut4 -it mongodb-0 -- mongosh   -u root -p <password> --eval "rs.status()"

# Check MongoDB pods
kubectl get pods -n helmut4 -l app.kubernetes.io/name=mongodb

# Check logs
kubectl logs -n helmut4 mongodb-0
```

### Manual RS initialization

```bash
kubectl exec -n helmut4 -it mongodb-0 -- mongosh -u root -p <password> --eval   "rs.initiate({
    _id: 'rs0',
    members: [
      {_id: 0, host: 'mongodb-0.mongodb-headless:27017'},
      {_id: 1, host: 'mongodb-1.mongodb-headless:27017'},
      {_id: 2, host: 'mongodb-2.mongodb-headless:27017'}
    ]
  })"
```

### Authentication failing

```bash
# Verify secret
kubectl get secret mongodb -n helmut4 -o yaml

# Test connection
kubectl exec -n helmut4 -it mongodb-0 -- mongosh   -u root -p <password> --authenticationDatabase admin --eval "db.adminCommand('ping')"
```

## 3. RabbitMQ issues

### Cluster not forming

```bash
# Check cluster status
kubectl exec -n helmut4 -it rabbitmq-0 -- rabbitmqctl cluster_status

# Check connectivity
kubectl exec -n helmut4 -it rabbitmq-0 -- rabbitmq-diagnostics ping

# Check logs
kubectl logs -n helmut4 rabbitmq-0
```

### Authentication failing

```bash
# Verify Erlang cookie
kubectl get secret rabbitmq -n helmut4 -o yaml

# Test RabbitMQ
kubectl exec -n helmut4 -it rabbitmq-0 -- rabbitmqctl list_users
```

## 4. Storage issues

### PVC stuck in Pending

```bash
kubectl describe pvc helmut-storage-pvc -n helmut4

# Check StorageClass
kubectl get storageclass

# Check CSI driver
kubectl get csinode
```

### SMB volume not mounting

```bash
# Check credentials secret
kubectl get secret smb-credentials -n helmut4 -o yaml

# Check CSI driver logs
kubectl logs -n kube-system -l app=csi-driver-smb

# Check volume attachments
kubectl get volumeattachments
```

### Longhorn PVC issues

```bash
# Check Longhorn volumes
kubectl get volumes.longhorn.io -n longhorn-system

# Check Longhorn manager
kubectl logs -n longhorn-system -l app=longhorn-manager --tail=50
```

## 5. Performance issues

### Pods are slow

```bash
# Check resource usage
kubectl top nodes
kubectl top pods -n helmut4

# Install Metrics Server if not available
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

**Optimizations:**
```bash
# Check limits
kubectl describe pod -n helmut4 <pod-name> | grep -A 5 "Limits\|Requests"

# Increase resources via install-values.yaml
# services:
#   fx:
#     resources:
#       requests: {cpu: "1", memory: "2Gi"}
#       limits:   {cpu: "2", memory: "4Gi"}
helm upgrade helmut4 ./helmut4 -n helmut4 -f install-values.yaml
```

### High CPU/Memory usage

```bash
kubectl top pods -n helmut4 --sort-by=cpu
kubectl top pods -n helmut4 --sort-by=memory
kubectl logs -n helmut4 <high-usage-pod> --tail=200
```

## 6. Network issues

### Pods cannot reach each other

```bash
# Test connectivity
kubectl run -it --image=busybox --restart=Never test-pod -- sh

# Inside the pod:
wget http://fx:8100/health
nc -zv mongodb-headless 27017  # Headless service (RS mode)
nc -zv rabbitmq 5672
```

### DNS resolution errors

```bash
# Check CoreDNS
kubectl get pods -n kube-system | grep coredns

# Test DNS
kubectl exec -it <pod> -n helmut4 -- nslookup kubernetes.default
kubectl exec -it <pod> -n helmut4 -- nslookup mongodb-headless.helmut4.svc.cluster.local
```

## 7. Logging and Monitoring

### All logs for a component

```bash
# MongoDB logs
kubectl logs -n helmut4 -l app.kubernetes.io/name=mongodb --all-containers=true --tail=100

# RabbitMQ logs
kubectl logs -n helmut4 -l app.kubernetes.io/name=rabbitmq --all-containers=true --tail=100

# All service logs
kubectl logs -n helmut4 --all-containers=true -f
```

### Monitor events

```bash
# Latest events
kubectl get events -n helmut4 --sort-by='.lastTimestamp'

# Continuous watch
kubectl get events -n helmut4 -w
```

## 8. Debug Commands

### Get a shell in a pod

```bash
# Interactive shell
kubectl exec -it -n helmut4 <pod-name> -- /bin/bash

# Or sh for Alpine
kubectl exec -it -n helmut4 <pod-name> -- /bin/sh
```

### Port-forwarding

```bash
# Access MongoDB directly
kubectl port-forward -n helmut4 svc/mongodb 27017:27017

# In another terminal
mongosh -u root -p <password> localhost:27017
```

### Copy files

```bash
# Copy from pod
kubectl cp helmut4/<pod>:/path/to/file ./local-file

# Copy to pod
kubectl cp ./local-file helmut4/<pod>:/path/to/file
```

## 9. New Deployment Checklist

- [ ] All pods are in Ready state
- [ ] No CrashLoopBackOff or Pending pods
- [ ] MongoDB replica set is healthy
- [ ] RabbitMQ cluster is healthy
- [ ] Ingress is created
- [ ] Domain is reachable
- [ ] Logs are clean (no errors)
- [ ] PVCs are Bound
- [ ] All services are available
- [ ] Credentials are correct

## 10. Emergency Procedures

### Full reset

```bash
# WARNING: ALL DATA WILL BE LOST!
helm uninstall helmut4 -n helmut4
kubectl delete pvc --all -n helmut4
kubectl delete namespace helmut4

# Redeploy
helm upgrade helmut4 --install -n helmut4 --create-namespace -f install-values.yaml ./helmut4
```

### Quick restart

```bash
# Restart all pods
kubectl rollout restart deployment -n helmut4
kubectl rollout restart statefulset -n helmut4
```

### Dry-run for debugging

```bash
helm upgrade helmut4 ./helmut4 -n helmut4 -f install-values.yaml --dry-run --debug > output.yaml
```

## Contact and Support

For further help:
1. Check the logs: `kubectl logs`
2. Describe resources: `kubectl describe`
3. Check events: `kubectl get events`
4. Run health check: `./scripts/health-check.sh helmut4`
