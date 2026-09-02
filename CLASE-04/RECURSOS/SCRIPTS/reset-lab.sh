#!/usr/bin/env bash
set -uo pipefail
kubectl delete namespace c4-basico c4-config c4-recursos c4-challenge --ignore-not-found --wait=false
echo ">> Reset de la Clase 4 completado."
echo "   Metrics Server se deja instalado: se usa en las Clases 5 y 6."
