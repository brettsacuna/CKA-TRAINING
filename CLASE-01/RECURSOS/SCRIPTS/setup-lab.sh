#!/usr/bin/env bash
# CLASE 1 - Prepara el escenario del LAB 1.4 (Challenge) YA ROTO.
# Uso: ./setup-lab.sh
set -euo pipefail
NS=c1-challenge

echo ">> Creando namespace ${NS}..."
kubectl create namespace "${NS}" --dry-run=client -o yaml | kubectl apply -f -

echo ">> Desplegando el escenario (con fallos intencionales)..."
cat <<'YAML' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: shop-web
  namespace: c1-challenge
spec:
  replicas: 1
  selector:
    matchLabels:
      app: shop-web
  template:
    metadata:
      labels:
        app: shop-web
    spec:
      nodeSelector:
        environment: gpu
      containers:
        - name: web
          image: nginx:1.27-alpine
          ports:
            - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: shop-svc
  namespace: c1-challenge
spec:
  type: NodePort
  selector:
    app: shop
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8080
      nodePort: 31200
YAML

echo
echo "==============================================================="
echo " LAB 1.4 listo. El escenario esta ROTO a proposito."
echo " Objetivo: curl http://<IP-worker>:31200 debe devolver HTTP 200"
echo "           y shop-web debe tener 3 replicas Running."
echo " No elimines el Deployment ni el Service: repara in situ."
echo "==============================================================="
