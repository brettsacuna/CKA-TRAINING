#!/usr/bin/env bash
# SESION 15 - Puntua el EXAMEN PRACTICO (LAB 15.3) segun la rubrica.
#   Services y DNS 20 · Ingress y TLS 15 · Config y storage 15
#   Observabilidad 15 · Seguridad 25 · Metodo 10
set -uo pipefail
NS=${NS:-gratitud}
SA=system:serviceaccount:${NS}:gratitud-deployer
EX="kubectl -n $NS exec"

declare -A GOT MAX
add(){ # add <area> <puntos> <ok?1:0> <texto>
  MAX[$1]=$(( ${MAX[$1]:-0} + $2 ))
  if [ "$3" = "1" ]; then GOT[$1]=$(( ${GOT[$1]:-0} + $2 )); echo "  [OK  +$2] $4"
  else echo "  [--   0 ] $4"; fi
}
pass(){ [ "$1" -eq 0 ]; }   # exit 0 -> ok

echo "== Evaluando el examen practico en '$NS' =="

# ---------- Services y DNS (20) ----------
sel=$(kubectl -n $NS get svc api -o jsonpath='{.spec.selector.tier}' 2>/dev/null)
add SERVICES 6 "$([ "$sel" = api ] && echo 1 || echo 0)" "Service api selecciona tier=api"
ep=$(kubectl -n $NS get endpointslices -l kubernetes.io/service-name=api \
  -o jsonpath='{range .items[*]}{range .endpoints[*]}{.addresses[0]}{"\n"}{end}{end}' 2>/dev/null | grep -c . || echo 0)
add SERVICES 4 "$([ "${ep:-0}" -ge 1 ] && echo 1 || echo 0)" "Service api con endpoints"
tp=$(kubectl -n $NS get svc cache -o jsonpath='{.spec.ports[0].targetPort}' 2>/dev/null)
add SERVICES 6 "$([ "$tp" = 8080 ] && echo 1 || echo 0)" "Service cache targetPort 8080"
$EX deploy/api -- sh -c 'wget -qO- --timeout=5 http://cache >/dev/null 2>&1' 2>/dev/null
add SERVICES 4 "$(pass $? && echo 1 || echo 0)" "la API alcanza a cache por nombre"

# ---------- Ingress y TLS (15) ----------
ic=$(kubectl -n $NS get ingress gratitud -o jsonpath='{.spec.ingressClassName}' 2>/dev/null)
kubectl get ingressclass "$ic" >/dev/null 2>&1
add INGRESS 6 "$(pass $? && echo 1 || echo 0)" "ingressClassName ($ic) existe"
addr=$(kubectl -n $NS get ingress gratitud -o jsonpath='{.status.loadBalancer.ingress[0].ip}{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
add INGRESS 4 "$([ -n "$addr" ] && echo 1 || echo 0)" "el Ingress tiene ADDRESS"
ts=$(kubectl -n $NS get ingress gratitud -o jsonpath='{.spec.tls[0].secretName}' 2>/dev/null)
tt=$(kubectl -n $NS get secret "$ts" -o jsonpath='{.type}' 2>/dev/null)
add INGRESS 5 "$([ "$tt" = "kubernetes.io/tls" ] && echo 1 || echo 0)" "secretName TLS ($ts) valido"

# ---------- Config y storage (15) ----------
$EX deploy/api -- sh -c 'test -n "$PARTNER_TOKEN" && test -n "$DB_PASSWORD"' 2>/dev/null
add CONFIG 6 "$(pass $? && echo 1 || echo 0)" "PARTNER_TOKEN y DB_PASSWORD inyectados en la API"
ph=$(kubectl -n $NS get pvc gratitud-uploads -o jsonpath='{.status.phase}' 2>/dev/null)
add CONFIG 5 "$([ "$ph" = Bound ] && echo 1 || echo 0)" "PVC gratitud-uploads en Bound"
cr=$(kubectl -n $NS get deploy cache -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
add CONFIG 4 "$([ "${cr:-0}" -ge 1 ] && echo 1 || echo 0)" "cache monta el PVC y arranca"

# ---------- Observabilidad (15) ----------
rp=$(kubectl -n $NS get deploy portal -o jsonpath='{.spec.template.spec.containers[0].readinessProbe.httpGet.port}' 2>/dev/null)
add OBS 6 "$([ "$rp" = 8080 ] && echo 1 || echo 0)" "readinessProbe de portal al puerto 8080"
pr=$(kubectl -n $NS get deploy portal -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
add OBS 5 "$([ "${pr:-0}" -ge 2 ] && echo 1 || echo 0)" "portal 2/2 Ready"
kubectl -n $NS top pod >/dev/null 2>&1
add OBS 4 "$(pass $? && echo 1 || echo 0)" "kubectl top pod funciona"

# ---------- Seguridad (25) ----------
c1=$(kubectl auth can-i update deploy -n $NS --as=$SA 2>/dev/null || echo no)
add SEG 8 "$([ "$c1" = yes ] && echo 1 || echo 0)" "gratitud-deployer puede update deployments"
c2=$(kubectl auth can-i get secrets -n $NS --as=$SA 2>/dev/null || echo no)
add SEG 5 "$([ "$c2" = no ] && echo 1 || echo 0)" "gratitud-deployer NO lee secrets"
kubectl -n $NS get networkpolicy allow-portal-to-api >/dev/null 2>&1
add SEG 7 "$(pass $? && echo 1 || echo 0)" "existe la politica portal->api"
$EX deploy/portal -- sh -c 'wget -qO- --timeout=5 http://api >/dev/null 2>&1' 2>/dev/null
add SEG 3 "$(pass $? && echo 1 || echo 0)" "portal alcanza a api (NetworkPolicy)"
psa=$(kubectl get ns $NS -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}' 2>/dev/null)
add SEG 2 "$([ "$psa" = restricted ] && echo 1 || echo 0)" "namespace enforce=restricted"

# ---------- Metodo (10) ----------
star=$(kubectl auth can-i '*' '*' -n $NS --as=$SA 2>/dev/null || echo no)
add METODO 5 "$([ "$star" = no ] && echo 1 || echo 0)" "no se dio cluster-admin/edit a la SA"
kubectl -n $NS get networkpolicy default-deny >/dev/null 2>&1
add METODO 5 "$(pass $? && echo 1 || echo 0)" "default-deny sigue existiendo"

echo
TOTG=0; TOTM=0
for a in SERVICES INGRESS CONFIG OBS SEG METODO; do
  printf "  %-10s %3d / %-3d\n" "$a" "${GOT[$a]:-0}" "${MAX[$a]:-0}"
  TOTG=$((TOTG + ${GOT[$a]:-0})); TOTM=$((TOTM + ${MAX[$a]:-0}))
done
echo "  ---------------------------"
printf "  TOTAL      %3d / %-3d\n" "$TOTG" "$TOTM"
[ "$TOTG" -ge $(( TOTM * 80 / 100 )) ] && { echo "APROBADO (>= 80 %)"; exit 0; } || { echo "NO APROBADO (< 80 %)"; exit 1; }
