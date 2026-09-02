#!/usr/bin/env bash
# SESION 11 - Elimina lo creado durante la sesion.
set -uo pipefail
kubectl delete namespace c11-basico gratitud-api gratitud-datos --ignore-not-found --wait=false
kubectl delete pv gratitud-pv-uploads --ignore-not-found
kubectl delete storageclass gratitud-standard --ignore-not-found
echo ">> Reset de la Sesion 11 completado."
echo "   Si algun PV quedo en Released con reclaimPolicy Retain, borralo a mano:"
echo "     kubectl get pv | grep Released"
