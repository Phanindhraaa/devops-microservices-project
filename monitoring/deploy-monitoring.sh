#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Deploying Monitoring Stack           ${NC}"
echo -e "${BLUE}  (Prometheus + Grafana)                ${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}✗ kubectl not found${NC}"
    exit 1
fi

# Check if minikube is running
if ! minikube status &> /dev/null; then
    echo -e "${RED}✗ Minikube is not running${NC}"
    echo "Start it with: minikube start"
    exit 1
fi

echo -e "${GREEN}✓ Prerequisites check passed${NC}\n"

# Deploy monitoring stack
echo -e "${YELLOW}=== Deploying Monitoring Stack ===${NC}\n"

echo -e "${BLUE}1. Creating monitoring namespace...${NC}"
kubectl apply -f 00-namespace.yaml
sleep 2

echo -e "\n${BLUE}2. Deploying Prometheus...${NC}"
kubectl apply -f 01-prometheus-config.yaml
kubectl apply -f 02-prometheus-rbac.yaml
kubectl apply -f 03-prometheus-deployment.yaml
kubectl apply -f 04-prometheus-service.yaml
echo -e "${GREEN}✓ Prometheus deployed${NC}"
sleep 3

echo -e "\n${BLUE}3. Deploying Grafana...${NC}"
kubectl apply -f 05-grafana-datasource.yaml
kubectl apply -f 06-grafana-deployment.yaml
kubectl apply -f 07-grafana-service.yaml
echo -e "${GREEN}✓ Grafana deployed${NC}"
sleep 3

echo -e "\n${BLUE}4. Deploying kube-state-metrics...${NC}"
kubectl apply -f 08-kube-state-metrics.yaml
echo -e "${GREEN}✓ kube-state-metrics deployed${NC}"
sleep 3

echo -e "\n${BLUE}5. Deploying node-exporter...${NC}"
kubectl apply -f 09-node-exporter.yaml
echo -e "${GREEN}✓ node-exporter deployed${NC}"
sleep 3

echo -e "\n${YELLOW}=== Waiting for pods to be ready ===${NC}\n"
echo "This may take a minute..."

# Wait for all pods in monitoring namespace to be ready
kubectl wait --for=condition=ready pod --all -n monitoring --timeout=300s

echo -e "\n${GREEN}✓ All monitoring pods are ready!${NC}\n"

# Display status
echo -e "${YELLOW}=== Monitoring Stack Status ===${NC}\n"
kubectl get all -n monitoring

# Get access URLs
echo -e "\n${YELLOW}=== Access Information ===${NC}\n"

MINIKUBE_IP=$(minikube ip)

echo -e "${GREEN}Prometheus:${NC}"
echo "  URL: http://$MINIKUBE_IP:30090"
echo "  Command: minikube service prometheus -n monitoring"

echo -e "\n${GREEN}Grafana:${NC}"
echo "  URL: http://$MINIKUBE_IP:30300"
echo "  Command: minikube service grafana -n monitoring"
echo "  Username: admin"
echo "  Password: admin123"

echo -e "\n${BLUE}Quick Access Commands:${NC}"
echo "  Open Prometheus: minikube service prometheus -n monitoring"
echo "  Open Grafana:    minikube service grafana -n monitoring"

echo -e "\n${GREEN}Deployment complete!${NC}"
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Access Grafana and login with admin/admin123"
echo "  2. Import dashboards (see MONITORING_SETUP.md)"
echo "  3. Explore your metrics in Prometheus"
