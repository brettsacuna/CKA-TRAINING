#!/usr/bin/env bash
# CLASE 5 - Prepara el escenario del LAB 5.4 (Challenge de red) YA ROTO.
set -euo pipefail
NS=c5-challenge
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -

cat <<'YAML' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata: {name: frontend, namespace: c5-challenge}
spec:
  replicas: 1
  selector: {matchLabels: {app: frontend}}
  template:
    metadata: {labels: {app: frontend}}
    spec:
      containers: [{name: web, image: "nicolaka/netshoot", command: ["sleep","36000"]}]
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: backend, namespace: c5-challenge}
spec:
  replicas: 2
  selector: {matchLabels: {app: backend}}
  template:
    metadata: {labels: {app: backend}}
    spec:
      containers:
        - name: web
          image: nginx:1.27-alpine
          ports: [{containerPort: 80}]
---
apiVersion: v1
kind: Service
metadata: {name: backend, namespace: c5-challenge}
spec:
  selector: {app: backend-v2}
  ports: [{port: 80, targetPort: 80}]
---
apiVersion: v1
kind: Service
metadata: {name: portal, namespace: c5-challenge}
spec:
  selector: {app: backend}
  ports: [{port: 80, targetPort: 80}]
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: default-deny, namespace: c5-challenge}
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: allow-dns, namespace: c5-challenge}
spec:
  podSelector: {}
  policyTypes: [Egress]
  egress:
    - to:
        - namespaceSelector:
            matchLabels: {kubernetes.io/metadata.name: kube-system}
      ports:
        - {protocol: UDP, port: 5353}
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: allow-frontend-to-backend, namespace: c5-challenge}
spec:
  podSelector: {matchLabels: {app: backend}}
  policyTypes: [Ingress]
  ingress:
    - from:
        - podSelector: {matchLabels: {app: frontend}}
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: allow-frontend-egress, namespace: c5-challenge}
spec:
  podSelector: {matchLabels: {app: frontend}}
  policyTypes: [Egress]
  egress:
    - to:
        - podSelector: {matchLabels: {app: backend}}
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: allow-ingress-controller, namespace: c5-challenge}
spec:
  podSelector: {matchLabels: {app: backend}}
  policyTypes: [Ingress]
  ingress:
    - from:
        - namespaceSelector:
            matchLabels: {kubernetes.io/metadata.name: ingress}
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata: {name: portal, namespace: c5-challenge}
spec:
  ingressClassName: nginx
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service: {name: portal-svc, port: {number: 8080}}
YAML

echo
echo "==============================================================="
echo " LAB 5.4 listo. El escenario esta ROTO a proposito."
echo " Objetivo: frontend alcanza backend por nombre, y el Ingress"
echo " responde 200 desde fuera. NO borres la politica default-deny."
echo "==============================================================="
