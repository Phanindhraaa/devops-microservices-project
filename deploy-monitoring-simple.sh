#!/bin/bash

echo "========================================="
echo "  Deploying Monitoring Stack"
echo "========================================="
echo ""

# Deploy everything
echo "Deploying Prometheus + Grafana + Metrics..."
kubectl apply -f monitoring-complete.yaml

echo ""
echo "Waiting for pods to be ready (this may take 2-3 minutes)..."
sleep 10

# Wait for pods
kubectl wait --for=condition=ready pod -l app=prometheus -n monitoring --timeout=300s
kubectl wait --for=condition=ready pod -l app=grafana -n monitoring --timeout=300s
kubectl wait --for=condition=ready pod -l app=kube-state-metrics -n monitoring --timeout=300s

echo ""
echo "========================================="
echo "  Deployment Complete!"
echo "========================================="
echo ""

# Show status
kubectl get pods -n monitoring
echo ""
kubectl get svc -n monitoring

echo ""
echo "========================================="
echo "  Access Information"
echo "========================================="
MINIKUBE_IP=$(minikube ip)
echo ""
echo "Prometheus: http://$MINIKUBE_IP:30090"
echo "Grafana:    http://$MINIKUBE_IP:30300"
echo ""
echo "Grafana Login:"
echo "  Username: admin"
echo "  Password: admin123"
echo ""
echo "Quick Access:"
echo "  minikube service prometheus -n monitoring"
echo "  minikube service grafana -n monitoring"
echo ""
