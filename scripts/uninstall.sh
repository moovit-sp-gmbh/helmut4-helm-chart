#!/bin/bash

# Helmut4 Uninstall Script
# Entfernt das Chart und räumt auf

set -e

NAMESPACE=${1:-helmut4}
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${RED}⚠️  Helmut4 Uninstall - WARNUNG${NC}"
echo "========================================"
echo -e "Namespace: $NAMESPACE"
echo -e "Dies wird alle Ressourcen aus dem Namespace löschen!"
echo ""
read -p "Sind Sie sicher? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo -e "${YELLOW}Abgebrochen.${NC}"
  exit 0
fi

echo -e "\n${YELLOW}Uninstalling Helmut4...${NC}"

# Helm Release löschen
echo "Helm release uninstall..."
helm uninstall helmut4 -n $NAMESPACE || true

# Warten
sleep 5

# PVCs löschen (optional)
read -p "PVCs löschen? (yes/no): " DELETE_PVC
if [ "$DELETE_PVC" = "yes" ]; then
  echo "Deleting PVCs..."
  kubectl delete pvc --all -n $NAMESPACE || true
  sleep 5
fi

# Namespace löschen (optional)
read -p "Namespace löschen? (yes/no): " DELETE_NS
if [ "$DELETE_NS" = "yes" ]; then
  echo "Deleting namespace..."
  kubectl delete namespace $NAMESPACE || true
fi

echo -e "${GREEN}Uninstall complete!${NC}"
