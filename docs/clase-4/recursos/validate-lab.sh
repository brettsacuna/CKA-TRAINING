#!/usr/bin/env bash
# CLASE 4 - Valida el LAB 4.4.
set -uo pipefail
NS=c4-challenge; OK=0; FAIL=0
chk(){ if [ "$2" = "$3" ]; then echo "  [OK]    $1"; OK=$((OK+1)); else echo "  [FALLA] $1 (obtenido '$2', esperado '$3')"; FAIL=$((FAIL+1)); fi; }

echo "== Validando LAB 4.4 =="

READY=$(kubectl -n $NS get deploy billing -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
chk "billing con 3 replicas Ready" "${READY:-0}" "3"

IMG=$(kubectl -n $NS get deploy billing -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || echo "-")
case "$IMG" in nginx:*) echo "  [OK]    imagen valida de la familia nginx ($IMG)"; OK=$((OK+1));;
  *) echo "  [FALLA] imagen inesperada: $IMG"; FAIL=$((FAIL+1));; esac

CM=$(kubectl -n $NS get deploy billing -o jsonpath='{.spec.template.spec.containers[0].envFrom[0].configMapRef.name}' 2>/dev/null || echo "-")
chk "envFrom apunta al ConfigMap existente" "$CM" "billing-cfg"

SK=$(kubectl -n $NS get deploy billing -o jsonpath='{.spec.template.spec.containers[0].env[0].valueFrom.secretKeyRef.key}' 2>/dev/null || echo "-")
chk "secretKeyRef usa la clave correcta" "$SK" "db-password"

CPU=$(kubectl -n $NS get deploy billing -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null || echo "-")
if [ -n "$CPU" ] && [ "${CPU%m}" != "$CPU" ] || [ "$CPU" = "1" ] || [ "$CPU" = "0.5" ]; then
  echo "  [OK]    requests de CPU realistas ($CPU)"; OK=$((OK+1))
else
  echo "  [FALLA] requests de CPU siguen siendo irreales ($CPU)"; FAIL=$((FAIL+1))
fi

PWD_OK=$(kubectl -n $NS get deploy billing -o jsonpath='{.spec.template.spec.containers[0].env[0].value}' 2>/dev/null || echo "")
if [ -z "$PWD_OK" ]; then echo "  [OK]    la contrasena no esta en texto plano en el Deployment"; OK=$((OK+1));
else echo "  [FALLA] hay un valor en texto plano en env[0].value"; FAIL=$((FAIL+1)); fi

CAUSE=$(kubectl -n $NS get deploy billing -o jsonpath='{.metadata.annotations.kubernetes\.io/change-cause}' 2>/dev/null || echo "")
if [ -n "$CAUSE" ]; then echo "  [OK]    causa del cambio registrada"; OK=$((OK+1));
else echo "  [FALLA] falta la anotacion kubernetes.io/change-cause"; FAIL=$((FAIL+1)); fi

echo
if [ "$FAIL" -eq 0 ]; then echo "LAB 4.4 SUPERADO (${OK} comprobaciones)"; exit 0
else echo "LAB 4.4 NO superado: ${FAIL} pendiente(s)."; exit 1; fi
