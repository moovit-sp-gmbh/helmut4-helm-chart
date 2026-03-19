#!/bin/bash
# Preconfigured install script for helmut-k8s.moovit24.de (Rancher cluster)
# All configuration is in install-values.yaml – no env vars needed here.

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

export KUBECONFIG=/Users/r.hutter/.kube/rancher.surfplanet.yaml

NAMESPACE="helmut4"
CHART_PATH="./helmut4"

echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}Helmut4 – moovit24.de Installation${NC}"
echo -e "${GREEN}======================================${NC}"

if ! command -v helm &>/dev/null; then
    echo -e "${RED}helm is not installed. Please install Helm 3+.${NC}"
    exit 1
fi
if ! command -v kubectl &>/dev/null; then
    echo -e "${RED}kubectl is not installed.${NC}"
    exit 1
fi
if [[ ! -f install-values.yaml ]]; then
    echo -e "${RED}install-values.yaml not found.${NC}"
    exit 1
fi

echo -e "${YELLOW}Namespace: ${NAMESPACE}${NC}"
echo -e "${YELLOW}KUBECONFIG: ${KUBECONFIG}${NC}"

helm upgrade helmut4 --install \
  -n "${NAMESPACE}" \
  --create-namespace \
  -f install-values.yaml \
  "${CHART_PATH}"

echo -e "${GREEN}Done! Watch pods with:${NC}"
echo "  kubectl get pods -n ${NAMESPACE} -w"
