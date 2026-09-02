#!/usr/bin/env bash
# SESION 13 - Elimina lo creado durante la sesion.
set -uo pipefail
kubectl delete namespace \
  c13-rbac \
  gratitud-frontend gratitud-api gratitud-datos gratitud-batch \
  --ignore-not-found --wait=false
kubectl delete clusterrole node-reader --ignore-not-found
kubectl delete clusterrolebinding app-reader-nodes --ignore-not-found
echo ">> Reset de la Sesion 13 completado."
