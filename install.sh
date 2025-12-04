#!/bin/bash
# Installation Script für Helmut4

set -e

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}Helmut4 Helm Chart Installation${NC}"
echo -e "${GREEN}======================================${NC}"

# Prüfe ob helm installiert ist
if ! command -v helm &> /dev/null; then
    echo -e "${RED}Helm ist nicht installiert. Bitte installieren Sie Helm 3+${NC}"
    exit 1
fi

# Prüfe ob kubectl installiert ist
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}kubectl ist nicht installiert. Bitte installieren Sie kubectl${NC}"
    exit 1
fi

# Namespace abfragen
read -p "Namespace (standard: helmut4): " NAMESPACE
NAMESPACE=${NAMESPACE:-helmut4}

# Domain abfragen
read -p "Domain (z.B. api.example.com): " DOMAIN

# Docker Registry Credentials abfragen
read -p "Docker Registry Username: " DOCKER_USER
read -sp "Docker Registry Password: " DOCKER_PASS
echo
read -p "Docker Registry Email: " DOCKER_EMAIL

# Chart Path abfragen
read -p "Chart Path (standard: ./helmut4): " CHART_PATH
CHART_PATH=${CHART_PATH:-./helmut4}

echo -e "${YELLOW}Konfiguration:${NC}"
echo "  Namespace: $NAMESPACE"
echo "  Domain: $DOMAIN"
echo "  Chart: $CHART_PATH"

# Namespace erstellen
echo -e "${YELLOW}Erstelle Namespace...${NC}"
kubectl create namespace $NAMESPACE 2>/dev/null || true

# Chart installieren
echo -e "${YELLOW}Installiere Helmut4 Chart...${NC}"
helm install helmut4 $CHART_PATH \
  --namespace $NAMESPACE \
  --create-namespace \
  --set global.domain="$DOMAIN" \
  --set docker.username="$DOCKER_USER" \
  --set docker.password="$DOCKER_PASS" \
  --set docker.email="$DOCKER_EMAIL"

echo -e "${GREEN}Installation erfolgreich!${NC}"
echo ""
echo -e "${YELLOW}Nächste Schritte:${NC}"
echo "1. Pods starten lassen:"
echo "   kubectl get pods -n $NAMESPACE -w"
echo ""
echo "2. MongoDB initialisieren:"
echo "   kubectl exec -n $NAMESPACE -it mongodb-0 -- mongo -u root -p <password>"
echo ""
echo "3. Ingress prüfen:"
echo "   kubectl get ingress -n $NAMESPACE"
