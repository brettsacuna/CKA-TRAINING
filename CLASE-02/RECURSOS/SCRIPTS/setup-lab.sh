#!/usr/bin/env bash
# CLASE 2 - Prepara el escenario RBAC del LAB 2.4 con una implementacion INCORRECTA.
set -euo pipefail

for NS in red blue project-hamster; do
  kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
done

echo ">> Aplicando la implementacion RBAC actual (con defectos)..."
cat <<'YAML' | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata: {name: secret-manager, namespace: red}
rules:
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata: {name: secret-manager, namespace: red}
roleRef: {apiGroup: rbac.authorization.k8s.io, kind: Role, name: secret-manager}
subjects:
  - {apiGroup: rbac.authorization.k8s.io, kind: User, name: jane}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata: {name: secret-manager, namespace: blue}
rules:
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata: {name: secret-manager, namespace: blue}
roleRef: {apiGroup: rbac.authorization.k8s.io, kind: Role, name: secret-manager}
subjects:
  - {apiGroup: rbac.authorization.k8s.io, kind: User, name: jane}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata: {name: deploy-deleter}
rules:
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata: {name: deploy-deleter, namespace: red}
roleRef: {apiGroup: rbac.authorization.k8s.io, kind: ClusterRole, name: deploy-deleter}
subjects:
  - {apiGroup: rbac.authorization.k8s.io, kind: User, name: jane}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata: {name: deploy-deleter-jim}
roleRef: {apiGroup: rbac.authorization.k8s.io, kind: ClusterRole, name: deploy-deleter}
subjects:
  - {apiGroup: rbac.authorization.k8s.io, kind: User, name: jim}
---
apiVersion: v1
kind: ServiceAccount
metadata: {name: processor, namespace: project-hamster}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata: {name: processor, namespace: project-hamster}
rules:
  - apiGroups: [""]
    resources: ["secrets", "configmaps"]
    verbs: ["create", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata: {name: processor, namespace: project-hamster}
roleRef: {apiGroup: rbac.authorization.k8s.io, kind: Role, name: processor}
subjects:
  - {apiGroup: rbac.authorization.k8s.io, kind: User, name: processor}
YAML

echo
echo "==============================================================="
echo " LAB 2.4 listo. La implementacion RBAC NO coincide con el"
echo " diseno aprobado del laboratorio. Audita con 'auth can-i'."
echo " Hay permisos que faltan y permisos concedidos de mas."
echo "==============================================================="
