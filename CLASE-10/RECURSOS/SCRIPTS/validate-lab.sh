#!/usr/bin/env bash
# SESION 10 - Valida el LAB 10.4.
set -uo pipefail
NS=gratitud-web; OK=0; FAIL=0
chk(){ if [ "$2" = "$3" ]; then echo "  [OK]    $1"; OK=$((OK+1)); else echo "  [FALLA] $1 (obtenido '$2', esperado '$3')"; FAIL=$((FAIL+1)); fi; }

echo "== Validando LAB 10.4 =="

# --- Fallo 1: ingressClassName adoptado por un controlador real ---
ICLASS=$(kubectl -n $NS get ingress gratitud -o jsonpath='{.spec.ingressClassName}' 2>/dev/null || echo "-")
if kubectl get ingressclass "$ICLASS" >/dev/null 2>&1; then
  echo "  [OK]    ingressClassName '$ICLASS' existe en el cluster"; OK=$((OK+1))
else
  echo "  [FALLA] ingressClassName '$ICLASS' no corresponde a ninguna IngressClass"; FAIL=$((FAIL+1))
fi

ADDR=$(kubectl -n $NS get ingress gratitud \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
if [ -n "$ADDR" ]; then echo "  [OK]    el Ingress tiene ADDRESS ($ADDR)"; OK=$((OK+1))
else echo "  [FALLA] el Ingress sigue sin ADDRESS (revisa ingressClassName / controlador)"; FAIL=$((FAIL+1)); fi

# --- Fallo 2: backend de '/' -> portal:80 ---
BSVC=$(kubectl -n $NS get ingress gratitud -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.name}' 2>/dev/null || echo "-")
BPORT=$(kubectl -n $NS get ingress gratitud -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.port.number}' 2>/dev/null || echo "-")
chk "El path / apunta al Service portal" "$BSVC" "portal"
chk "El path / apunta al puerto 80" "$BPORT" "80"

# --- Fallo 3: pathType de /api = Prefix ---
APIPT=$(kubectl -n $NS get ingress gratitud -o jsonpath='{range .spec.rules[0].http.paths[*]}{.path}={.pathType}{"\n"}{end}' 2>/dev/null | awk -F= '$1=="/api"{print $2}')
chk "El path /api tiene pathType Prefix" "${APIPT:--}" "Prefix"

# --- Fallo 4: secretName TLS existe y es de tipo tls ---
TSEC=$(kubectl -n $NS get ingress gratitud -o jsonpath='{.spec.tls[0].secretName}' 2>/dev/null || echo "-")
TTYPE=$(kubectl -n $NS get secret "$TSEC" -o jsonpath='{.type}' 2>/dev/null || echo "-")
chk "El secretName del Ingress ($TSEC) es un Secret kubernetes.io/tls" "$TTYPE" "kubernetes.io/tls"

# --- Endpoints de los backends ---
for s in portal api; do
  E=$(kubectl -n $NS get endpointslices -l kubernetes.io/service-name=$s \
    -o jsonpath='{range .items[*]}{range .endpoints[*]}{.addresses[0]}{"\n"}{end}{end}' 2>/dev/null | grep -c . || echo 0)
  if [ "$E" -ge 1 ]; then echo "  [OK]    Service $s con $E endpoint(s)"; OK=$((OK+1))
  else echo "  [FALLA] Service $s sin endpoints"; FAIL=$((FAIL+1)); fi
done

# --- Ingress intacto ---
IEXISTS=$(kubectl -n $NS get ingress gratitud -o name 2>/dev/null | wc -l | tr -d ' ')
chk "El Ingress gratitud sigue existiendo" "$IEXISTS" "1"

# --- Conectividad a traves del controlador (desde dentro del cluster) ---
kubectl -n $NS rollout status deploy/probe --timeout=60s >/dev/null 2>&1 || true
TIP=$(kubectl -n ingress get svc traefik -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "")
if [ -n "$TIP" ]; then
  C1=$(kubectl -n $NS exec deploy/probe -- curl -s -o /dev/null -w '%{http_code}' --max-time 5 -H 'Host: gratitud.example.com' "http://$TIP/" 2>/dev/null || echo 000)
  chk "GET / a traves del controlador = 200" "$C1" "200"
  C2=$(kubectl -n $NS exec deploy/probe -- curl -s -o /dev/null -w '%{http_code}' --max-time 5 -H 'Host: gratitud.example.com' "http://$TIP/api/health" 2>/dev/null || echo 000)
  chk "GET /api/health a traves del controlador = 200" "$C2" "200"
else
  echo "  [AVISO] no encuentro el Service del controlador (ns 'ingress'); omito el curl interno"
fi

echo
if [ "$FAIL" -eq 0 ]; then
  echo "LAB 10.4 SUPERADO (${OK} comprobaciones)"
  echo "Ultimo paso manual (desde tu equipo):"
  echo "  curl -kv --resolve gratitud.example.com:32443:<IP-NODO> https://gratitud.example.com:32443/ 2>&1 | grep -E 'subject:|issuer:'"
  exit 0
else
  echo "LAB 10.4 NO superado: ${FAIL} pendiente(s)."
  exit 1
fi
