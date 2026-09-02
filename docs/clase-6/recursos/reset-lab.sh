#!/usr/bin/env bash
set -uo pipefail
kubectl delete namespace c6-estados c6-pedidos c6-sprint c6-prueba tienda \
  --ignore-not-found --wait=false
for N in $(kubectl get nodes -o name); do
  kubectl uncordon "${N#node/}" >/dev/null 2>&1 || true
  kubectl label "$N" incidente- tier- hardware- --overwrite >/dev/null 2>&1 || true
done
echo ">> Reset de la Clase 6 completado."
