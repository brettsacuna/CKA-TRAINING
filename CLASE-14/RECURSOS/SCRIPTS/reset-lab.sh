#!/usr/bin/env bash
# SESION 14 - Elimina lo creado durante la sesion.
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)

helm -n gratitud-cd uninstall gratitud 2>/dev/null || true
helm -n gratitud uninstall gratitud 2>/dev/null || true
kubectl delete namespace gratitud-cd gratitud c14-helm --ignore-not-found --wait=false
rm -rf "$HERE/chart-lab"

echo ">> Reset de la Sesion 14 completado."
echo "   (los charts de referencia en RECURSOS/CHART y CHART-ROTO se conservan)"
