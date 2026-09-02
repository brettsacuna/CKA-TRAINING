#!/usr/bin/env bash
# CLASE 1 - Valida el LAB 1.4 (Challenge).
set -uo pipefail
NS=c1-challenge
OK=0; FAIL=0
chk() { if [ "$2" = "$3" ]; then echo "  [OK]   $1"; OK=$((OK+1)); else echo "  [FALLA] $1 (esperado: $3 / obtenido: $2)"; FAIL=$((FAIL+1)); fi; }

echo "== Validando LAB 1.4 =="

REP=$(kubectl -n $NS get deploy shop-web -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "-")
chk "Deployment shop-web declara 3 replicas" "$REP" "3"

READY=$(kubectl -n $NS get deploy shop-web -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
chk "3 replicas Ready" "${READY:-0}" "3"

SEL=$(kubectl -n $NS get svc shop-svc -o jsonpath='{.spec.selector.app}' 2>/dev/null || echo "-")
chk "Selector del Service apunta a app=shop-web" "$SEL" "shop-web"

TPORT=$(kubectl -n $NS get svc shop-svc -o jsonpath='{.spec.ports[0].targetPort}' 2>/dev/null || echo "-")
chk "targetPort del Service es 80" "$TPORT" "80"

NPORT=$(kubectl -n $NS get svc shop-svc -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "-")
chk "nodePort sigue siendo 31200" "$NPORT" "31200"

ADDR=$(kubectl -n $NS get endpointslices -l kubernetes.io/service-name=shop-svc \
       -o jsonpath='{range .items[*]}{range .endpoints[*]}{.addresses[0]}{"\n"}{end}{end}' 2>/dev/null | grep -c . || echo 0)
chk "EndpointSlice con 3 direcciones" "$ADDR" "3"

echo
if [ "$FAIL" -eq 0 ]; then
  echo "LAB 1.4 SUPERADO  (${OK}/${OK} comprobaciones)"
  echo "Ultimo paso manual: curl -s -o /dev/null -w '%{http_code}\n' http://<IP-worker>:31200"
  exit 0
else
  echo "LAB 1.4 NO superado todavia: ${FAIL} comprobacion(es) pendiente(s)."
  exit 1
fi
