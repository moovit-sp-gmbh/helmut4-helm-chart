#!/bin/bash
#
# Helmut4 health check
#
# Usage:
#   ./health-check.sh [NAMESPACE]
#
# Reads MongoDB credentials from the cluster (mongodb-credentials Secret)
# so nothing sensitive lives in this script.

set -uo pipefail

NAMESPACE="${1:-helmut4}"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

FAILED=0

echo -e "${YELLOW}Helmut4 Health Check — Namespace: $NAMESPACE${NC}"
echo "========================================"

check_component() {
  local name=$1
  local command=$2

  echo -n "Checking $name... "
  if eval "$command" > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC}"
  else
    echo -e "${RED}✗${NC}"
    FAILED=$((FAILED+1))
  fi
}

# --- Pod status -------------------------------------------------------------
echo -e "\n${YELLOW}Pod Status:${NC}"
check_component "MongoDB pods (>=1 Running)" \
  "kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=mongodb --no-headers 2>/dev/null | grep -q Running"
check_component "RabbitMQ pod (Running)" \
  "kubectl get pod -n $NAMESPACE rabbitmq-0 --no-headers 2>/dev/null | grep -q Running"
check_component "hw service pod (Running)" \
  "kubectl get pods -n $NAMESPACE -l app=hw --no-headers 2>/dev/null | grep -q Running"

# --- Database connectivity --------------------------------------------------
echo -e "\n${YELLOW}Database Connectivity:${NC}"

MONGODB_USER="${MONGODB_USER:-$(kubectl -n "$NAMESPACE" get secret mongodb-credentials \
  -o jsonpath='{.data.username}' 2>/dev/null | base64 -d || echo root)}"
MONGODB_PASSWORD="${MONGODB_PASSWORD:-$(kubectl -n "$NAMESPACE" get secret mongodb-credentials \
  -o jsonpath='{.data.mongodb-root-password}' 2>/dev/null | base64 -d)}"

if [ -n "${MONGODB_PASSWORD:-}" ]; then
  check_component "MongoDB replica set has a PRIMARY" \
    "kubectl exec -n $NAMESPACE mongodb-0 -- mongosh -u '$MONGODB_USER' -p '$MONGODB_PASSWORD' --quiet --eval 'rs.status().members.some(m=>m.stateStr==\"PRIMARY\")' 2>/dev/null | grep -q true"
else
  echo "(skipping MongoDB connectivity — no password resolved)"
fi

check_component "RabbitMQ responds to ping" \
  "kubectl exec -n $NAMESPACE rabbitmq-0 -- rabbitmq-diagnostics ping 2>/dev/null | grep -q 'It is running'"

# --- Storage ----------------------------------------------------------------
echo -e "\n${YELLOW}Storage:${NC}"
echo "All PVCs in namespace $NAMESPACE:"
kubectl get pvc -n "$NAMESPACE" 2>/dev/null

# --- Network ----------------------------------------------------------------
echo -e "\n${YELLOW}Network:${NC}"
check_component "Ingress present" \
  "kubectl get ingress -n $NAMESPACE --no-headers 2>/dev/null | grep -q ."
check_component "Services present" \
  "kubectl get svc -n $NAMESPACE --no-headers 2>/dev/null | grep -q ClusterIP"

# --- Resources --------------------------------------------------------------
echo -e "\n${YELLOW}Top 5 pods by CPU:${NC}"
kubectl top pods -n "$NAMESPACE" --no-headers 2>/dev/null | sort -k2 -h -r | head -5 || \
  echo "(metrics-server not available)"

echo -e "\n${YELLOW}Top 5 pods by memory:${NC}"
kubectl top pods -n "$NAMESPACE" --no-headers --sort-by=memory 2>/dev/null | head -5 || \
  echo "(metrics-server not available)"

# --- Summary ----------------------------------------------------------------
echo -e "\n${YELLOW}Summary:${NC}"
if [ "$FAILED" -eq 0 ]; then
  echo -e "${GREEN}All checks passed ✓${NC}"
  exit 0
else
  echo -e "${RED}$FAILED check(s) failed ✗${NC}"
  exit 1
fi
