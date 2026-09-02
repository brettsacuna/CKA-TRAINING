#!/usr/bin/env bash
# CLASE 4 - Prepara el escenario del LAB 4.4 (Challenge) YA ROTO.
set -euo pipefail
NS=c4-challenge
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -

cat <<'YAML' | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata: {name: billing-cfg, namespace: c4-challenge}
data:
  APP_MODE: prod
  LOG_LEVEL: info
---
apiVersion: v1
kind: Secret
metadata: {name: billing-secret, namespace: c4-challenge}
type: Opaque
stringData:
  db-password: F4ctur4cion2026
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: billing, namespace: c4-challenge}
spec:
  replicas: 3
  selector: {matchLabels: {app: billing}}
  template:
    metadata: {labels: {app: billing}}
    spec:
      containers:
        - name: app
          image: nginx:1.99-alpine
          ports: [{containerPort: 80}]
          envFrom:
            - configMapRef: {name: billing-config}
          env:
            - name: DB_PASSWORD
              valueFrom:
                secretKeyRef: {name: billing-secret, key: password}
          resources:
            requests: {cpu: "8", memory: "64Mi"}
            limits:   {cpu: "10", memory: "256Mi"}
---
apiVersion: v1
kind: Service
metadata: {name: billing, namespace: c4-challenge}
spec:
  selector: {app: billing}
  ports: [{port: 80, targetPort: 80}]
YAML

echo
echo "==============================================================="
echo " LAB 4.4 listo. El Deployment 'billing' NO levanta ninguna"
echo " replica. Objetivo: 3/3 Running y Ready, y el Service responde."
echo " No elimines el Deployment ni el Service."
echo "==============================================================="
