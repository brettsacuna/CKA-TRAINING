#!/usr/bin/env bash
set -uo pipefail
kubectl delete namespace c5-basico c5-ingress c5-netpol c5-datos c5-challenge \
  --ignore-not-found --wait=false
echo ">> Reset de la Clase 5 completado."
echo "   El Ingress Controller se deja instalado: se usa en la Clase 6."
echo "   Para desinstalarlo: helm -n ingress uninstall traefik"
