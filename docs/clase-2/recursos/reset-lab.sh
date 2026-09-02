#!/usr/bin/env bash
# CLASE 2 - Limpieza.
set -uo pipefail
kubectl delete namespace red blue project-hamster c2-basico c2-etcd --ignore-not-found --wait=false
kubectl delete clusterrole deploy-deleter --ignore-not-found
kubectl delete clusterrolebinding deploy-deleter deploy-deleter-jim --ignore-not-found
for N in $(kubectl get nodes -o name); do kubectl uncordon "${N#node/}" >/dev/null 2>&1 || true; done
echo ">> Reset de la Clase 2 completado."
echo "   Nota: el upgrade del LAB 2.2 y el restore del LAB 2.3 NO se revierten."
