#!/bin/bash
#
# Helmut4 backup helper
#
# Usage:
#   ./backup.sh [NAMESPACE] [BACKUP_DIR]
#
# Reads MongoDB credentials from the cluster (mongodb-credentials Secret)
# so nothing sensitive lives in this script. Pass MONGODB_USER /
# MONGODB_PASSWORD as env vars to override.

set -euo pipefail

NAMESPACE="${1:-helmut4}"
BACKUP_DIR="${2:-./backups}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

mkdir -p "$BACKUP_DIR"

echo "Creating backups for Helmut4 (namespace: $NAMESPACE)..."

# --- MongoDB ----------------------------------------------------------------
# Pull credentials out of the Secret the chart creates (or that the
# subchart creates when mongodb.auth.existingSecret is set).
MONGODB_USER="${MONGODB_USER:-$(kubectl -n "$NAMESPACE" get secret mongodb-credentials \
  -o jsonpath='{.data.username}' 2>/dev/null | base64 -d || echo root)}"

MONGODB_PASSWORD="${MONGODB_PASSWORD:-$(kubectl -n "$NAMESPACE" get secret mongodb-credentials \
  -o jsonpath='{.data.mongodb-root-password}' 2>/dev/null | base64 -d)}"

if [ -z "${MONGODB_PASSWORD:-}" ]; then
  echo "ERROR: could not resolve MongoDB password. Set MONGODB_PASSWORD or" \
       "create the mongodb-credentials Secret in namespace $NAMESPACE." >&2
  exit 1
fi

echo "Backing up MongoDB..."
kubectl exec -n "$NAMESPACE" mongodb-0 -- mongodump \
  -u "$MONGODB_USER" -p "$MONGODB_PASSWORD" \
  --authenticationDatabase admin \
  --out "/tmp/mongodb-backup-$TIMESTAMP"

kubectl cp "$NAMESPACE/mongodb-0:/tmp/mongodb-backup-$TIMESTAMP" \
  "$BACKUP_DIR/mongodb-$TIMESTAMP"

# --- RabbitMQ definitions ---------------------------------------------------
echo "Exporting RabbitMQ definitions..."
kubectl exec -n "$NAMESPACE" rabbitmq-0 -- \
  rabbitmqctl export_definitions - \
  > "$BACKUP_DIR/rabbitmq-definitions-$TIMESTAMP.json" || true

echo "Backups created in $BACKUP_DIR"
ls -lh "$BACKUP_DIR/"
