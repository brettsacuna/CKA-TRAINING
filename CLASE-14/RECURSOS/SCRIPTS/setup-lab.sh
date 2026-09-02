#!/usr/bin/env bash
# SESION 14 - Prepara el escenario del LAB 14.4 (Challenge de Helm).
#
# Copia el chart ROTO a una carpeta de trabajo para que el alumno la edite sin
# tocar el original. El chart tiene 4 defectos:
#   1. Chart.yaml sin 'apiVersion'                       -> helm lint falla
#   2. deployment.yaml usa .Values.image.repo (es .repository) -> image: ":tag" (InvalidImageName)
#   3. deployment.yaml usa .Values.replicas|default 2 (es .replicaCount) -> --set replicaCount no tiene efecto
#   4. service.yaml targetPort = .Values.service.port (80); el contenedor escucha en 8080 -> endpoints inutiles
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
SRC="$HERE/../CHART-ROTO/gratitud"
DST="$HERE/chart-lab/gratitud"

command -v helm >/dev/null || { echo "helm no esta instalado."; exit 1; }

rm -rf "$HERE/chart-lab"
mkdir -p "$HERE/chart-lab"
cp -r "$SRC" "$DST"

kubectl create namespace gratitud-cd --dry-run=client -o yaml | kubectl apply -f -

echo
echo "==============================================================="
echo " LAB 14.4 listo. Chart de trabajo en:"
echo "   CLASE-14/RECURSOS/SCRIPTS/chart-lab/gratitud"
echo
echo " Empieza por:  helm lint chart-lab/gratitud"
echo "               helm template t chart-lab/gratitud"
echo " Luego:        helm upgrade --install gratitud chart-lab/gratitud \\"
echo "                 -n gratitud-cd --set replicaCount=3 --wait"
echo
echo " Hay 4 fallos: Chart.yaml, clave de imagen, clave de replicas, targetPort."
echo " NO recrees el chart con 'helm create'."
echo "==============================================================="
