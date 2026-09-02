#!/usr/bin/env bash
# SESION 9 - Elimina todo lo creado durante la sesion.
set -uo pipefail
kubectl delete namespace \
  c9-basico c9-publicar \
  gratitud-frontend gratitud-api gratitud-datos \
  --ignore-not-found --wait=false
echo ">> Reset de la Sesion 9 completado."
echo "   Si personalizaste el ConfigMap de CoreDNS en algun paso, revierte tambien eso."
