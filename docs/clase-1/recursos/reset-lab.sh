#!/usr/bin/env bash
# CLASE 1 - Limpia todo lo creado durante la clase.
set -uo pipefail
for NS in c1-basico c1-inter c1-avanzado c1-challenge; do
  echo ">> Eliminando namespace ${NS}..."
  kubectl delete namespace "${NS}" --ignore-not-found --wait=false
done

echo ">> Retirando PriorityClasses del laboratorio..."
kubectl delete priorityclass low-priority critical-priority --ignore-not-found

echo ">> Retirando labels y taints del laboratorio de los nodos..."
for N in $(kubectl get nodes -o name); do
  kubectl label  "$N" environment- disktype- --overwrite >/dev/null 2>&1 || true
  kubectl taint  "$N" team-        >/dev/null 2>&1 || true
  kubectl taint  "$N" maintenance- >/dev/null 2>&1 || true
done

echo ">> Reset de la Clase 1 completado."
