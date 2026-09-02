#!/usr/bin/env bash
# CLASE 3 - Valida el LAB 3.4.
set -uo pipefail
NS=c3-challenge; OK=0; FAIL=0
chk(){ if [ "$2" = "$3" ]; then echo "  [OK]    $1"; OK=$((OK+1)); else echo "  [FALLA] $1 (obtenido '$2', esperado '$3')"; FAIL=$((FAIL+1)); fi; }

echo "== Validando LAB 3.4 =="

PHASE=$(kubectl -n $NS get pvc pvc-reportes -o jsonpath='{.status.phase}' 2>/dev/null || echo "-")
chk "PVC pvc-reportes en Bound" "$PHASE" "Bound"

PVN=$(kubectl -n $NS get pvc pvc-reportes -o jsonpath='{.spec.volumeName}' 2>/dev/null || echo "-")
chk "PVC enlazado a pv-reportes-ok" "$PVN" "pv-reportes-ok"

READY=$(kubectl -n $NS get deploy reportes -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
chk "Deployment reportes 1/1 Ready" "${READY:-0}" "1"

CLAIM=$(kubectl -n $NS get deploy reportes -o jsonpath='{.spec.template.spec.volumes[0].persistentVolumeClaim.claimName}' 2>/dev/null || echo "-")
chk "El Pod referencia el PVC correcto" "$CLAIM" "pvc-reportes"

PVCOUNT=$(kubectl get pv --no-headers 2>/dev/null | grep -c '^pv-reportes' || echo 0)
chk "Los 3 PersistentVolumes siguen existiendo" "$PVCOUNT" "3"

if kubectl -n $NS exec deploy/reportes -- sh -c 'touch /data/.probe && rm -f /data/.probe' >/dev/null 2>&1; then
  echo "  [OK]    /data es escribible desde el contenedor"; OK=$((OK+1))
else
  echo "  [FALLA] /data no es escribible desde el contenedor"; FAIL=$((FAIL+1))
fi

echo
if [ "$FAIL" -eq 0 ]; then echo "LAB 3.4 SUPERADO (${OK} comprobaciones)"; exit 0
else echo "LAB 3.4 NO superado: ${FAIL} pendiente(s)."; exit 1; fi
