#!/usr/bin/env bash
# CLASE 3 - Limpieza.
set -uo pipefail
kubectl delete namespace c3-basico c3-inter c3-sts c3-challenge --ignore-not-found --wait=true
kubectl delete pv pv-a pv-b pv-sts-0 pv-sts-1 pv-sts-2 \
  pv-reportes-small pv-reportes-ro pv-reportes-ok --ignore-not-found
echo ">> Reset de la Clase 3 completado."
echo "   Recuerda borrar en los workers: /mnt/data-a /mnt/data-b /mnt/sts-* /mnt/rep-*"
