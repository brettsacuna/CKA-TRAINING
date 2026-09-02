#!/usr/bin/env bash
# SESION 9 - Valida el LAB 9.4.
set -uo pipefail
OK=0; FAIL=0
chk(){ if [ "$2" = "$3" ]; then echo "  [OK]    $1"; OK=$((OK+1)); else echo "  [FALLA] $1 (obtenido '$2', esperado '$3')"; FAIL=$((FAIL+1)); fi; }

echo "== Validando LAB 9.4 =="

# --- Fallo 1: selector de svc/api ---
SEL=$(kubectl -n gratitud-api get svc api -o jsonpath='{.spec.selector.app}' 2>/dev/null || echo "-")
chk "svc/api selecciona 'app=gratitud-api'" "$SEL" "gratitud-api"

# --- Fallo 2: targetPort de svc/api ---
TP=$(kubectl -n gratitud-api get svc api -o jsonpath='{.spec.ports[0].targetPort}' 2>/dev/null || echo "-")
chk "svc/api targetPort = 8080" "$TP" "8080"

# --- Endpoints de api ---
EPA=$(kubectl -n gratitud-api get endpointslices -l kubernetes.io/service-name=api \
  -o jsonpath='{range .items[*]}{range .endpoints[*]}{.addresses[0]}{"\n"}{end}{end}' 2>/dev/null | grep -c . || echo 0)
chk "EndpointSlice de api con 2 direcciones" "$EPA" "2"

# --- Fallo 3: tipo y nodePort de portal-np ---
PT=$(kubectl -n gratitud-frontend get svc portal-np -o jsonpath='{.spec.type}' 2>/dev/null || echo "-")
chk "svc/portal-np es NodePort" "$PT" "NodePort"
NP=$(kubectl -n gratitud-frontend get svc portal-np -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "-")
chk "svc/portal-np nodePort = 31900" "$NP" "31900"

# --- Fallo 4: cache en el namespace correcto ---
CN=$(kubectl -n gratitud-datos get svc cache -o name 2>/dev/null | wc -l | tr -d ' ')
chk "svc/cache existe en gratitud-datos" "$CN" "1"
EPC=$(kubectl -n gratitud-datos get endpointslices -l kubernetes.io/service-name=cache \
  -o jsonpath='{range .items[*]}{range .endpoints[*]}{.addresses[0]}{"\n"}{end}{end}' 2>/dev/null | grep -c . || echo 0)
chk "EndpointSlice de cache (gratitud-datos) con 2 direcciones" "$EPC" "2"

# --- Deployments intactos ---
for nsdep in gratitud-frontend/portal gratitud-api/api gratitud-datos/cache; do
  ns=${nsdep%/*}; d=${nsdep#*/}
  E=$(kubectl -n "$ns" get deploy "$d" -o name 2>/dev/null | wc -l | tr -d ' ')
  chk "Deployment $nsdep sigue existiendo" "$E" "1"
done

# --- Conectividad desde gratitud-api ---
kubectl -n gratitud-api rollout status deploy/probe --timeout=60s >/dev/null 2>&1 || true
if kubectl -n gratitud-api exec deploy/probe -- curl -s --max-time 5 -o /dev/null http://api 2>/dev/null; then
  echo "  [OK]    probe(gratitud-api) alcanza http://api"; OK=$((OK+1))
else
  echo "  [FALLA] probe(gratitud-api) NO alcanza http://api"; FAIL=$((FAIL+1))
fi
if kubectl -n gratitud-api exec deploy/probe -- curl -s --max-time 5 -o /dev/null http://cache.gratitud-datos 2>/dev/null; then
  echo "  [OK]    probe(gratitud-api) alcanza http://cache.gratitud-datos"; OK=$((OK+1))
else
  echo "  [FALLA] probe(gratitud-api) NO alcanza http://cache.gratitud-datos"; FAIL=$((FAIL+1))
fi

echo
if [ "$FAIL" -eq 0 ]; then
  echo "LAB 9.4 SUPERADO (${OK} comprobaciones)"
  echo "Ultimo paso manual: curl -s -o /dev/null -w '%{http_code}\n' http://<IP-NODO>:31900/"
  exit 0
else
  echo "LAB 9.4 NO superado: ${FAIL} pendiente(s)."
  exit 1
fi
