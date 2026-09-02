#!/usr/bin/env bash
# SESION 12 - Elimina lo creado durante la sesion.
set -uo pipefail
kubectl delete namespace c12-basico c12-diag gratitud-api --ignore-not-found --wait=false
echo ">> Reset de la Sesion 12 completado."
echo "   metrics-server (ns kube-system) se DEJA instalado; se usa en el resto del curso."
echo "   Para quitarlo:"
echo "     kubectl delete -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.8.1/components.yaml"
