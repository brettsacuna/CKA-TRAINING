#!/usr/bin/env bash
# CLASE 5 - Valida el LAB 5.4.
set -uo pipefail
NS=c5-challenge; OK=0; FAIL=0
chk(){ if [ "$2" = "$3" ]; then echo "  [OK]    $1"; OK=$((OK+1)); else echo "  [FALLA] $1 (obtenido '$2', esperado '$3')"; FAIL=$((FAIL+1)); fi; }

echo "== Validando LAB 5.4 =="

DD=$(kubectl -n $NS get networkpolicy default-deny -o name 2>/dev/null | wc -l)
chk "La politica default-deny sigue existiendo" "$DD" "1"

SEL=$(kubectl -n $NS get svc backend -o jsonpath='{.spec.selector.app}' 2>/dev/null || echo "-")
chk "Selector del Service backend" "$SEL" "backend"

ADDR=$(kubectl -n $NS get endpointslices -l kubernetes.io/service-name=backend \
  -o jsonpath='{range .items[*]}{range .endpoints[*]}{.addresses[0]}{"\n"}{end}{end}' 2>/dev/null | grep -c . || echo 0)
chk "EndpointSlice de backend con 2 direcciones" "$ADDR" "2"

DNSPORT=$(kubectl -n $NS get networkpolicy allow-dns -o jsonpath='{.spec.egress[0].ports[0].port}' 2>/dev/null || echo "-")
chk "La politica de DNS permite el puerto 53" "$DNSPORT" "53"

ICLASS=$(kubectl -n $NS get ingress portal -o jsonpath='{.spec.ingressClassName}' 2>/dev/null || echo "-")
if kubectl get ingressclass "$ICLASS" >/dev/null 2>&1; then
  echo "  [OK]    ingressClassName '$ICLASS' existe en el cluster"; OK=$((OK+1))
else
  echo "  [FALLA] ingressClassName '$ICLASS' no corresponde a ninguna IngressClass"; FAIL=$((FAIL+1))
fi

ISVC=$(kubectl -n $NS get ingress portal -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.name}' 2>/dev/null || echo "-")
chk "El Ingress apunta al Service portal" "$ISVC" "portal"

IPORT=$(kubectl -n $NS get ingress portal -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.port.number}' 2>/dev/null || echo "-")
chk "El Ingress apunta al puerto 80" "$IPORT" "80"

if kubectl -n $NS exec deploy/frontend -- curl -s --max-time 5 -o /dev/null http://backend 2>/dev/null; then
  echo "  [OK]    frontend alcanza a backend por nombre"; OK=$((OK+1))
else
  echo "  [FALLA] frontend NO alcanza a backend por nombre"; FAIL=$((FAIL+1))
fi

echo
if [ "$FAIL" -eq 0 ]; then
  echo "LAB 5.4 SUPERADO (${OK} comprobaciones)"
  echo "Ultimo paso manual: curl -s -o /dev/null -w '%{http_code}\n' http://<IP-nodo>:32080/"
  exit 0
else echo "LAB 5.4 NO superado: ${FAIL} pendiente(s)."; exit 1; fi
