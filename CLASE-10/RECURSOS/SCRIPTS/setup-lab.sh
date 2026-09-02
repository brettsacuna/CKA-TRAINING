#!/usr/bin/env bash
# SESION 10 - Prepara el escenario del LAB 10.4 (Challenge de Ingress) YA ROTO.
#
# Requiere el Ingress Controller del LAB 10.1 (kubectl get ingressclass).
#
# El Ingress 'gratitud' tiene 4 defectos:
#   1. ingressClassName: nginx        (la clase real es 'traefik')            -> ADDRESS vacio
#   2. regla / -> portal puerto 8080  (el Service portal esta en el 80)       -> 503
#   3. regla /api pathType: Exact     (deberia ser Prefix)                    -> 404 en /api/health
#   4. spec.tls secretName: gratitud-tls-viejo  (el Secret real es gratitud-tls) -> cert por defecto
set -euo pipefail
NS=gratitud-web
command -v openssl >/dev/null || { echo "openssl no esta disponible en este equipo."; exit 1; }

kubectl get ingressclass 2>/dev/null | grep -q . || {
  echo "No hay ninguna IngressClass. Ejecuta primero ./install-ingress-controller.sh"; exit 1; }

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl label ns "$NS" part-of=gratitud tier=web --overwrite >/dev/null

# ---- Secret TLS correcto (gratitud-tls) ----
DIR=$(mktemp -d)
openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -keyout "$DIR/key.pem" -out "$DIR/cert.pem" \
  -subj "/O=CKA-TRAINING/CN=gratitud.example.com" \
  -addext "subjectAltName=DNS:gratitud.example.com" 2>/dev/null
kubectl -n "$NS" create secret tls gratitud-tls \
  --cert="$DIR/cert.pem" --key="$DIR/key.pem" \
  --dry-run=client -o yaml | kubectl apply -f -

cat <<'YAML' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata: {name: portal, namespace: gratitud-web, labels: {app: gratitud-portal, part-of: gratitud}}
spec:
  replicas: 2
  selector: {matchLabels: {app: gratitud-portal}}
  template:
    metadata: {labels: {app: gratitud-portal, part-of: gratitud}}
    spec:
      containers: [{name: nginx, image: "nginx:1.27-alpine", ports: [{containerPort: 80}]}]
---
apiVersion: v1
kind: Service
metadata: {name: portal, namespace: gratitud-web}
spec: {selector: {app: gratitud-portal}, ports: [{port: 80, targetPort: 80}]}
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: api, namespace: gratitud-web, labels: {app: gratitud-api, part-of: gratitud}}
spec:
  replicas: 2
  selector: {matchLabels: {app: gratitud-api}}
  template:
    metadata: {labels: {app: gratitud-api, part-of: gratitud}}
    spec:
      containers: [{name: api, image: "nginxinc/nginx-unprivileged:1.27-alpine", ports: [{containerPort: 8080}]}]
---
apiVersion: v1
kind: Service
metadata: {name: api, namespace: gratitud-web}
spec: {selector: {app: gratitud-api}, ports: [{port: 80, targetPort: 8080}]}
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: docs, namespace: gratitud-web, labels: {app: gratitud-docs, part-of: gratitud}}
spec:
  replicas: 1
  selector: {matchLabels: {app: gratitud-docs}}
  template:
    metadata: {labels: {app: gratitud-docs, part-of: gratitud}}
    spec:
      containers: [{name: nginx, image: "nginx:1.27-alpine", ports: [{containerPort: 80}]}]
---
apiVersion: v1
kind: Service
metadata: {name: docs, namespace: gratitud-web}
spec: {selector: {app: gratitud-docs}, ports: [{port: 80, targetPort: 80}]}
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: probe, namespace: gratitud-web, labels: {app: probe, part-of: gratitud}}
spec:
  replicas: 1
  selector: {matchLabels: {app: probe}}
  template:
    metadata: {labels: {app: probe, part-of: gratitud}}
    spec:
      containers: [{name: netshoot, image: "nicolaka/netshoot", command: ["sleep", "36000"]}]
---
# ----- Ingress con 4 defectos -----
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata: {name: gratitud, namespace: gratitud-web}
spec:
  ingressClassName: nginx                       # FALLO 1: la clase real es 'traefik'
  tls:
    - hosts: ["gratitud.example.com"]
      secretName: gratitud-tls-viejo            # FALLO 4: el Secret real es 'gratitud-tls'
  rules:
    - host: gratitud.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend: {service: {name: portal, port: {number: 8080}}}   # FALLO 2: portal esta en el 80
          - path: /api
            pathType: Exact                                            # FALLO 3: deberia ser Prefix
            backend: {service: {name: api, port: {number: 80}}}
          - path: /docs
            pathType: Prefix
            backend: {service: {name: docs, port: {number: 80}}}
YAML

kubectl -n "$NS" rollout status deploy/portal --timeout=120s
for d in portal docs; do
  for p in $(kubectl -n "$NS" get pod -l app=gratitud-$d -o name); do
    kubectl -n "$NS" exec "${p#pod/}" -- sh -c "echo '$d' > /usr/share/nginx/html/index.html" || true
  done
done

echo
echo "==============================================================="
echo " LAB 10.4 listo. El Ingress 'gratitud' esta ROTO a proposito."
echo " Sintomas: ADDRESS vacio, / da 503, /api/health da 404,"
echo "           y el HTTPS presenta un certificado que no es el tuyo."
echo " Hay 4 fallos: ingressClassName, backend/puerto, pathType, secretName."
echo " NO borres el Ingress. NO uses NodePort en portal/api/docs."
echo "==============================================================="
