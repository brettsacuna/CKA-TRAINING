#!/usr/bin/env bash
# SESION 13 - Prepara el escenario del LAB 13.4 (Challenge de seguridad) ROTO.
#
# 4 fallos:
#   1. RBAC : RoleBinding deployer-bind -> subject 'gratitud-deploy' (la SA es 'gratitud-deployer') -> Forbidden
#   2. NetPol: gratitud-api tiene default-deny pero NINGUN allow-dns                                 -> nslookup falla
#   3. NetPol: allow-frontend-to-api usa podSelector {app: frontend} (los Pods son gratitud-frontend) -> trafico bloqueado
#   4. PSA  : gratitud-batch con enforce=restricted; el Deployment worker no lleva securityContext   -> 0 replicas
set -euo pipefail

for ns in gratitud-frontend gratitud-api gratitud-datos gratitud-batch; do
  kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
done
kubectl label ns gratitud-frontend part-of=gratitud --overwrite >/dev/null
kubectl label ns gratitud-api      part-of=gratitud --overwrite >/dev/null
kubectl label ns gratitud-datos    part-of=gratitud --overwrite >/dev/null
kubectl label ns gratitud-batch    part-of=gratitud \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/warn=restricted --overwrite >/dev/null

cat <<'YAML' | kubectl apply -f -
# ---------------- workloads ----------------
apiVersion: apps/v1
kind: Deployment
metadata: {name: frontend, namespace: gratitud-frontend, labels: {app: gratitud-frontend, part-of: gratitud}}
spec:
  replicas: 1
  selector: {matchLabels: {app: gratitud-frontend}}
  template:
    metadata: {labels: {app: gratitud-frontend, part-of: gratitud}}
    spec:
      containers: [{name: netshoot, image: "nicolaka/netshoot", command: ["sleep", "36000"]}]
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: api, namespace: gratitud-api, labels: {app: gratitud-api, part-of: gratitud}}
spec:
  replicas: 1
  selector: {matchLabels: {app: gratitud-api}}
  template:
    metadata: {labels: {app: gratitud-api, part-of: gratitud}}
    spec:
      containers: [{name: api, image: "nginxinc/nginx-unprivileged:1.27-alpine", ports: [{containerPort: 8080}]}]
---
apiVersion: v1
kind: Service
metadata: {name: api, namespace: gratitud-api}
spec: {selector: {app: gratitud-api}, ports: [{port: 80, targetPort: 8080}]}
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
apiVersion: apps/v1
kind: Deployment
metadata: {name: cache, namespace: gratitud-datos, labels: {app: gratitud-cache, part-of: gratitud}}
spec:
  replicas: 1
  selector: {matchLabels: {app: gratitud-cache}}
  template:
    metadata: {labels: {app: gratitud-cache, part-of: gratitud}}
    spec:
      containers: [{name: cache, image: "nginxinc/nginx-unprivileged:1.27-alpine", ports: [{containerPort: 8080}]}]
---
apiVersion: v1
kind: Service
metadata: {name: cache, namespace: gratitud-datos}
spec: {selector: {app: gratitud-cache}, ports: [{port: 80, targetPort: 8080}]}
---
# FALLO 4: sin securityContext en un namespace enforce=restricted
apiVersion: apps/v1
kind: Deployment
metadata: {name: worker, namespace: gratitud-batch, labels: {app: gratitud-worker, part-of: gratitud}}
spec:
  replicas: 1
  selector: {matchLabels: {app: gratitud-worker}}
  template:
    metadata: {labels: {app: gratitud-worker, part-of: gratitud}}
    spec:
      containers: [{name: worker, image: "busybox:1.36", command: ["sh", "-c", "while true; do echo latido; sleep 10; done"]}]
---
# ---------------- RBAC ----------------
apiVersion: v1
kind: ServiceAccount
metadata: {name: gratitud-deployer, namespace: gratitud-api}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata: {name: deployer, namespace: gratitud-api}
rules:
  - apiGroups: ["apps"]
    resources: ["deployments", "replicasets"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: [""]
    resources: ["pods", "configmaps"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
# FALLO 1: subject 'gratitud-deploy' (la SA es 'gratitud-deployer')
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata: {name: deployer-bind, namespace: gratitud-api}
roleRef: {apiGroup: rbac.authorization.k8s.io, kind: Role, name: deployer}
subjects:
  - {kind: ServiceAccount, name: gratitud-deploy, namespace: gratitud-api}
---
# ---------------- NetworkPolicies ----------------
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: default-deny, namespace: gratitud-frontend}
spec: {podSelector: {}, policyTypes: [Ingress, Egress]}
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: allow-dns, namespace: gratitud-frontend}
spec:
  podSelector: {}
  policyTypes: [Egress]
  egress:
    - to: [{namespaceSelector: {matchLabels: {kubernetes.io/metadata.name: kube-system}}}]
      ports: [{protocol: UDP, port: 53}, {protocol: TCP, port: 53}]
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: allow-frontend-egress-to-api, namespace: gratitud-frontend}
spec:
  podSelector: {matchLabels: {app: gratitud-frontend}}
  policyTypes: [Egress]
  egress:
    - to:
        - namespaceSelector: {matchLabels: {kubernetes.io/metadata.name: gratitud-api}}
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: default-deny, namespace: gratitud-api}
spec: {podSelector: {}, policyTypes: [Ingress, Egress]}
---
# FALLO 2: NO hay allow-dns en gratitud-api
# FALLO 3: podSelector {app: frontend}; los Pods de origen son {app: gratitud-frontend}
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: allow-frontend-to-api, namespace: gratitud-api}
spec:
  podSelector: {matchLabels: {app: gratitud-api}}
  policyTypes: [Ingress]
  ingress:
    - from:
        - namespaceSelector: {matchLabels: {kubernetes.io/metadata.name: gratitud-frontend}}
          podSelector: {matchLabels: {app: frontend}}
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: allow-egress-to-cache, namespace: gratitud-api}
spec:
  podSelector: {}
  policyTypes: [Egress]
  egress:
    - to:
        - namespaceSelector: {matchLabels: {kubernetes.io/metadata.name: gratitud-datos}}
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: default-deny, namespace: gratitud-datos}
spec: {podSelector: {}, policyTypes: [Ingress, Egress]}
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: allow-dns, namespace: gratitud-datos}
spec:
  podSelector: {}
  policyTypes: [Egress]
  egress:
    - to: [{namespaceSelector: {matchLabels: {kubernetes.io/metadata.name: kube-system}}}]
      ports: [{protocol: UDP, port: 53}, {protocol: TCP, port: 53}]
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: allow-from-api, namespace: gratitud-datos}
spec:
  podSelector: {matchLabels: {app: gratitud-cache}}
  policyTypes: [Ingress]
  ingress:
    - from:
        - namespaceSelector: {matchLabels: {kubernetes.io/metadata.name: gratitud-api}}
YAML

echo
echo "==============================================================="
echo " LAB 13.4 listo. GRATITUD tiene 4 fallos de seguridad:"
echo "   1. RBAC   -> 'gratitud-deployer' no puede desplegar (Forbidden)"
echo "   2. NetPol -> 'api'/'probe' no resuelven DNS"
echo "   3. NetPol -> 'frontend' no llega a 'api'"
echo "   4. PSA    -> el Deployment 'worker' (gratitud-batch) no crea Pods"
echo " NO des cluster-admin. NO borres ningun default-deny."
echo "==============================================================="
