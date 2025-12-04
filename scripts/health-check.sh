#!/bin/bash

# Helmut4 Health Check Script
# Überprüft den Status aller Komponenten

set -e

NAMESPACE=${1:-helmut4}
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

FAILED=0

echo -e "${YELLOW}Helmut4 Health Check - Namespace: $NAMESPACE${NC}"
echo "========================================"

# Funktion zum Prüfen
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

# Pod Checks
echo -e "\n${YELLOW}Pod Status:${NC}"
check_component "MongoDB Pods" "kubectl get pods -n $NAMESPACE -l app=mongodb --no-headers | grep -c Running | grep -q 3"
check_component "RabbitMQ Pods" "kubectl get pods -n $NAMESPACE -l app=rabbitmq --no-headers | grep -c Running | grep -q 3"
check_component "Service Pods" "kubectl get pods -n $NAMESPACE -l app=hw --no-headers | grep -q Running"

# Database Checks
echo -e "\n${YELLOW}Database Connectivity:${NC}"
check_component "MongoDB Replica-Set" "kubectl exec -n $NAMESPACE -it mongodb-0 -- mongo -u root -p ***REMOVED*** --eval 'rs.status()' 2>/dev/null | grep -q 'PRIMARY'"
check_component "RabbitMQ Health" "kubectl exec -n $NAMESPACE -it rabbitmq-0 -- rabbitmq-diagnostics ping 2>/dev/null | grep -q 'It is running'"

# Storage Checks
echo -e "\n${YELLOW}Storage:${NC}"
check_component "Helmut Storage PVC" "kubectl get pvc -n $NAMESPACE helmut-storage-pvc --no-headers | grep -q Bound"
check_component "MongoDB PVC" "kubectl get pvc -n $NAMESPACE data-mongodb-0 --no-headers | grep -q Bound"
check_component "RabbitMQ PVC" "kubectl get pvc -n $NAMESPACE data-rabbitmq-0 --no-headers | grep -q Bound"

# Network Checks
echo -e "\n${YELLOW}Network:${NC}"
check_component "Ingress" "kubectl get ingress -n $NAMESPACE helmut4-helmut4-ingress --no-headers | grep -q helmut4"
check_component "Services" "kubectl get svc -n $NAMESPACE | grep -q ClusterIP"

# Resource Checks
echo -e "\n${YELLOW}Resources:${NC}"
echo "CPU Usage:"
kubectl top pods -n $NAMESPACE --no-headers 2>/dev/null | tail -5

echo -e "\nMemory Usage:"
kubectl top pods -n $NAMESPACE --no-headers --sort-by=memory 2>/dev/null | tail -5

# Summary
echo -e "\n${YELLOW}Summary:${NC}"
if [ $FAILED -eq 0 ]; then
  echo -e "${GREEN}All checks passed! ✓${NC}"
  exit 0
else
  echo -e "${RED}$FAILED checks failed! ✗${NC}"
  exit 1
fi
