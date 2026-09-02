#!/usr/bin/env bash
# SESION 12 - Prepara el escenario del LAB 12.4 (Challenge de salud y observabilidad) DEGRADADO.
#
# 4 fallos:
#   1. api: livenessProbe agresiva sin startupProbe; el contenedor tarda ~20 s -> CrashLoopBackOff
#   2. api: readinessProbe.httpGet.port = 8080 (el contenedor escucha en 80)   -> 0 endpoints
#   3. portal: resources.limits.memory = 8Mi (nginx no arranca en tan poco)    -> OOMKilled
#   4. worker: escribe los logs a /var/log/worker.log en vez de a stdout       -> kubectl logs vacio
set -euo pipefail

kubectl create namespace gratitud-api --dry-run=client -o yaml | kubectl apply -f -
kubectl label ns gratitud-api part-of=gratitud tier=api --overwrite >/dev/null

cat <<'YAML' | kubectl apply -f -
# ---------- api: arranque lento + 2 fallos de sonda ----------
apiVersion: apps/v1
kind: Deployment
metadata: {name: api, namespace: gratitud-api, labels: {app: gratitud-api, part-of: gratitud}}
spec:
  replicas: 1
  selector: {matchLabels: {app: gratitud-api}}
  template:
    metadata: {labels: {app: gratitud-api, part-of: gratitud}}
    spec:
      containers:
        - name: api
          image: nginx:1.27-alpine
          command: ["sh", "-c", "sleep 20 && nginx -g 'daemon off;'"]
          ports: [{containerPort: 80}]
          livenessProbe:                       # FALLO 1: sin startupProbe, mata el contenedor durante el arranque
            httpGet: {path: /, port: 80}
            initialDelaySeconds: 2
            periodSeconds: 3
            failureThreshold: 1
          readinessProbe:                      # FALLO 2: puerto equivocado
            httpGet: {path: /, port: 8080}
            periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata: {name: api, namespace: gratitud-api, labels: {part-of: gratitud}}
spec:
  selector: {app: gratitud-api}
  ports: [{port: 80, targetPort: 80}]
---
# ---------- portal: limite de memoria insuficiente ----------
apiVersion: apps/v1
kind: Deployment
metadata: {name: portal, namespace: gratitud-api, labels: {app: gratitud-portal, part-of: gratitud}}
spec:
  replicas: 1
  selector: {matchLabels: {app: gratitud-portal}}
  template:
    metadata: {labels: {app: gratitud-portal, part-of: gratitud}}
    spec:
      containers:
        - name: nginx
          image: nginx:1.27-alpine
          ports: [{containerPort: 80}]
          resources:                           # FALLO 3
            requests: {memory: 8Mi, cpu: 10m}
            limits: {memory: 8Mi}
---
apiVersion: v1
kind: Service
metadata: {name: portal, namespace: gratitud-api, labels: {part-of: gratitud}}
spec:
  selector: {app: gratitud-portal}
  ports: [{port: 80, targetPort: 80}]
---
# ---------- worker: logs a un fichero ----------
apiVersion: apps/v1
kind: Deployment
metadata: {name: worker, namespace: gratitud-api, labels: {app: gratitud-worker, part-of: gratitud}}
spec:
  replicas: 1
  selector: {matchLabels: {app: gratitud-worker}}
  template:
    metadata: {labels: {app: gratitud-worker, part-of: gratitud}}
    spec:
      containers:
        - name: worker
          image: busybox:1.36
          command: ["sh", "-c", "mkdir -p /var/log; while true; do echo \"$(date) worker latido\" >> /var/log/worker.log; sleep 5; done"]   # FALLO 4
YAML

echo
echo "==============================================================="
echo " LAB 12.4 listo. GRATITUD esta DEGRADADO a proposito."
echo " Sintomas: api en CrashLoopBackOff; endpoints de 'api' vacios;"
echo "           portal OOMKilled; 'kubectl logs deploy/worker' vacio."
echo " Hay 4 fallos: liveness/startup, readiness/puerto, limits.memory, logs a stdout."
echo " NO quites sondas ni limites. NO pongas al worker a hacer solo sleep."
echo "==============================================================="
