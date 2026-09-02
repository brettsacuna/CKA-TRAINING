#!/usr/bin/env bash
# SESION 14 - Valida el LAB 14.4.
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
CHART="$HERE/chart-lab/gratitud"
NS=gratitud-cd
OK=0; FAIL=0
chk(){ if [ "$2" = "$3" ]; then echo "  [OK]    $1"; OK=$((OK+1)); else echo "  [FALLA] $1 (obtenido '$2', esperado '$3')"; FAIL=$((FAIL+1)); fi; }

[ -d "$CHART" ] || { echo "No encuentro $CHART. Ejecuta primero ./setup-lab.sh"; exit 1; }

echo "== Validando LAB 14.4 =="

# --- Fallo 1: helm lint ---
if helm lint "$CHART" >/dev/null 2>&1; then echo "  [OK]    helm lint pasa"; OK=$((OK+1))
else echo "  [FALLA] helm lint sigue fallando"; FAIL=$((FAIL+1)); fi

# --- Fallo 2: el render deja el repositorio de la imagen ---
IMG=$(helm template t "$CHART" 2>/dev/null | grep -m1 'image:' | tr -d ' "' | sed 's/image://')
case "$IMG" in
  :*| "" ) echo "  [FALLA] la imagen renderiza sin repositorio ('$IMG')"; FAIL=$((FAIL+1)) ;;
  */* )    echo "  [OK]    la imagen renderiza con repositorio ('$IMG')"; OK=$((OK+1)) ;;
  * )      echo "  [FALLA] imagen inesperada ('$IMG')"; FAIL=$((FAIL+1)) ;;
esac

# --- desplegar ---
helm upgrade --install gratitud "$CHART" -n $NS --create-namespace \
  --set replicaCount=3 --wait --timeout 120s >/dev/null 2>&1 || true
kubectl -n $NS rollout status deploy/gratitud --timeout=90s >/dev/null 2>&1 || true

# --- Fallo 3: replicaCount respetado ---
RC=$(kubectl -n $NS get deploy gratitud -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "-")
chk "el Deployment tiene 3 replicas (--set replicaCount=3)" "${RC:--}" "3"
RR=$(kubectl -n $NS get deploy gratitud -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
chk "las 3 replicas estan Ready" "${RR:-0}" "3"

# --- Fallo 4: targetPort del Service ---
TP=$(kubectl -n $NS get svc gratitud -o jsonpath='{.spec.ports[0].targetPort}' 2>/dev/null || echo "-")
chk "el Service apunta al puerto 8080" "${TP:--}" "8080"
EP=$(kubectl -n $NS get endpoints gratitud -o jsonpath='{.subsets[*].ports[0].port}' 2>/dev/null || echo "")
chk "el EndpointSlice del Service usa el puerto 8080" "${EP:-none}" "8080"

# --- release desplegada ---
ST=$(helm -n $NS status gratitud -o json 2>/dev/null | grep -o '"status":"deployed"' | head -1)
if [ -n "$ST" ]; then echo "  [OK]    la release 'gratitud' esta deployed"; OK=$((OK+1))
else echo "  [FALLA] la release 'gratitud' no esta deployed"; FAIL=$((FAIL+1)); fi

echo
if [ "$FAIL" -eq 0 ]; then
  echo "LAB 14.4 SUPERADO (${OK} comprobaciones)"
  exit 0
else
  echo "LAB 14.4 NO superado: ${FAIL} pendiente(s)."
  exit 1
fi
