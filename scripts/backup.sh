#!/bin/bash

# Helmut4 Backup Script
# Erstellt Backups der Datenbanken

NAMESPACE=${1:-helmut4}
BACKUP_DIR=${2:-./backups}
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

echo "Creating backups for Helmut4..."

# MongoDB Backup
echo "Backing up MongoDB..."
kubectl exec -n $NAMESPACE mongodb-0 -- mongodump \
  -u root -p bitte \
  --authenticationDatabase admin \
  --out /tmp/mongodb-backup-$TIMESTAMP

kubectl cp $NAMESPACE/mongodb-0:/tmp/mongodb-backup-$TIMESTAMP $BACKUP_DIR/mongodb-$TIMESTAMP

# RabbitMQ Definitions
echo "Exporting RabbitMQ definitions..."
kubectl exec -n $NAMESPACE -it rabbitmq-0 -- \
  rabbitmqctl export_definitions - > $BACKUP_DIR/rabbitmq-definitions-$TIMESTAMP.json || true

# Elasticsearch Data (falls aktiv)
if kubectl get pod -n $NAMESPACE -l app=elasticsearch &> /dev/null; then
  echo "Backing up Elasticsearch..."
  kubectl port-forward -n $NAMESPACE svc/elasticsearch 9200:9200 &
  sleep 2
  curl -X PUT http://localhost:9200/_snapshot/local \
    -H "Content-Type: application/json" \
    -d '{"type": "fs", "settings": {"location": "/backup"}}'
  curl -X PUT http://localhost:9200/_snapshot/local/backup-$TIMESTAMP \
    -H "Content-Type: application/json" \
    -d '{}' || true
  kill %1
fi

echo "Backups created in $BACKUP_DIR"
ls -lh $BACKUP_DIR/
