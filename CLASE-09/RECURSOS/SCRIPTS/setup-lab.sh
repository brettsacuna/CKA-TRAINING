#!/usr/bin/env bash
# SESION 9 - Prepara el escenario del LAB 9.4 (Challenge de Services) YA ROTO.
#
# Despliega el programa GRATITUD en tres namespaces con 4 fallos:
#   1. svc/api          selector 'app=gratitud-api-v2'  (los Pods son 'gratitud-api')  -> EndpointSlice vacio
#   2. svc/api          targetPort 80                   (el contenedor escucha en 8080) -> connection refused
#   3. svc/portal-np    type ClusterIP sin nodePort     (deberia ser NodePort 31900)    -> no entra desde fuera
#   4. svc/cache        creado en 'gratitud-api'         (el Deployment esta en gratitud-datos) -> cache.gratitud-datos no resuelve
set -euo pipefail

for ns in gratitud-frontend gratitud-api gratitud-datos; do
  kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
done
kubectl label ns gratitud-frontend part-of=gratitud tier=frontend --overwrite >/dev/null
kubectl label ns gratitud-api      part-of=gratitud tier=api      --overwrite >/dev/null
kubectl label ns gratitud-datos    part-of=gratitud tier=datos    --overwrite >/dev/null

cat <<'YAML' | kubectl apply -f -
# ---------- gratitud-frontend ----------
apiVersion: apps/v1
kind: Deployment
metadata: {name: portal, namespace: gratitud-frontend, labels: {app: gratitud-portal, tier: frontend, part-of: gratitud}}
spec:
  replicas: 2
  selector: {matchLabels: {app: gratitud-portal}}
  template:
    metadata: {labels: {app: gratitud-portal, tier: frontend, part-of: gratitud}}
    spec:
      containers: [{name: nginx, image: "nginx:1.27-alpine", ports: [{containerPort: 80}]}]
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: probe, namespace: gratitud-frontend, labels: {app: probe, part-of: gratitud}}
spec:
  replicas: 1
  selector: {matchLabels: {app: probe}}
  template:
    metadata: {labels: {app: probe, part-of: gratitud}}
    spec:
      containers: [{name: netshoot, image: "nicolaka/netshoot", command: ["sleep", "36000"]}]
---
# FALLO 3: deberia ser type NodePort con nodePort 31900
apiVersion: v1
kind: Service
metadata: {name: portal-np, namespace: gratitud-frontend, labels: {part-of: gratitud}}
spec:
  type: ClusterIP
  selector: {app: gratitud-portal}
  ports: [{port: 80, targetPort: 80}]
---
# ---------- gratitud-api ----------
apiVersion: apps/v1
kind: Deployment
metadata: {name: api, namespace: gratitud-api, labels: {app: gratitud-api, tier: api, part-of: gratitud}}
spec:
  replicas: 2
  selector: {matchLabels: {app: gratitud-api}}
  template:
    metadata: {labels: {app: gratitud-api, tier: api, part-of: gratitud}}
    spec:
      containers: [{name: api, image: "nginxinc/nginx-unprivileged:1.27-alpine", ports: [{containerPort: 8080}]}]
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: probe, namespace: gratitud-api, labels: {app: probe, part-of: gratitud}}
spec:
  replicas: 1
  selector: {matchLabels: {app: probe}}
  template:
    metadata: {labels: {app: probe, part-of: gratitud}}
    spec:
      containers: [{name: netshoot, image: "nicolaka/netshoot", command: ["sleep", "36000"]}]
---
# FALLO 1: selector 'gratitud-api-v2' no cuadra con ningun Pod
# FALLO 2: targetPort 80, pero el contenedor escucha en 8080
apiVersion: v1
kind: Service
metadata: {name: api, namespace: gratitud-api, labels: {part-of: gratitud}}
spec:
  type: ClusterIP
  selector: {app: gratitud-api-v2}
  ports: [{port: 80, targetPort: 80}]
---
# FALLO 4: el Service cache esta en gratitud-api, pero el Deployment cache
# esta en gratitud-datos. 'cache.gratitud-datos' no resuelve.
apiVersion: v1
kind: Service
metadata: {name: cache, namespace: gratitud-api, labels: {part-of: gratitud}}
spec:
  type: ClusterIP
  selector: {app: gratitud-cache}
  ports: [{port: 80, targetPort: 80}]
---
# ---------- gratitud-datos ----------
apiVersion: apps/v1
kind: Deployment
metadata: {name: cache, namespace: gratitud-datos, labels: {app: gratitud-cache, tier: datos, part-of: gratitud}}
spec:
  replicas: 2
  selector: {matchLabels: {app: gratitud-cache}}
  template:
    metadata: {labels: {app: gratitud-cache, tier: datos, part-of: gratitud}}
    spec:
      containers: [{name: nginx, image: "nginx:1.27-alpine", ports: [{containerPort: 80}]}]
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: probe, namespace: gratitud-datos, labels: {app: probe, part-of: gratitud}}
spec:
  replicas: 1
  selector: {matchLabels: {app: probe}}
  template:
    metadata: {labels: {app: probe, part-of: gratitud}}
    spec:
      containers: [{name: netshoot, image: "nicolaka/netshoot", command: ["sleep", "36000"]}]
---
apiVersion: v1
kind: Service
metadata: {name: db-externa, namespace: gratitud-datos, labels: {part-of: gratitud}}
spec:
  type: ExternalName
  externalName: db.corp.example.com
YAML

# index.html identificable por Pod, para seguir el flujo en los curl
kubectl -n gratitud-frontend rollout status deploy/portal --timeout=120s
for p in $(kubectl -n gratitud-frontend get pod -l app=gratitud-portal -o name); do
  kubectl -n gratitud-frontend exec "${p#pod/}" -- sh -c \
    "echo 'portal ${p#pod/}' > /usr/share/nginx/html/index.html" || true
done

echo
echo "==============================================================="
echo " LAB 9.4 listo. El programa GRATITUD esta ROTO a proposito."
echo " Hay 4 fallos entre: selector, targetPort, tipo de Service y FQDN."
echo " Objetivo: api con endpoints y respondiendo en el 80,"
echo "           cache.gratitud-datos alcanzable desde gratitud-api,"
echo "           y curl http://<IP-NODO>:31900/ = 200."
echo " NO borres Deployments. NO uses NodePort en api ni en cache."
echo "==============================================================="
