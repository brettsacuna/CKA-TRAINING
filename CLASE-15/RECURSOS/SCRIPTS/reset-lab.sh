#!/usr/bin/env bash
# SESION 15 - Elimina lo creado durante la sesion.
set -uo pipefail
helm -n gratitud uninstall gratitud 2>/dev/null || true
kubectl delete namespace gratitud --ignore-not-found --wait=false
kubectl delete pv gratitud-pv-uploads --ignore-not-found
echo ">> Reset de la Sesion 15 completado."
echo "   metrics-server y el Ingress Controller se dejan instalados."
echo "   Si algun PV quedo en Released: kubectl get pv | grep Released"
