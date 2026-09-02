#!/usr/bin/env bash
# SESION 10 - Elimina lo creado durante la sesion.
set -uo pipefail
kubectl delete namespace c10-basico gratitud-web --ignore-not-found --wait=false
echo ">> Reset de la Sesion 10 completado."
echo "   El Ingress Controller (Traefik, ns 'ingress') se DEJA instalado."
echo "   Para quitarlo:  helm -n ingress uninstall traefik && kubectl delete ns ingress"
