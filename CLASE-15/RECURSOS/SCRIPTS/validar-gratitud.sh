#!/usr/bin/env bash
# SESION 15 - Validacion de extremo a extremo de GRATITUD (LAB 15.1 y 15.2).
# Recorre las seis capas y marca cada punto [OK] / [FALLA].
set -uo pipefail
NS=${NS:-gratitud}
SA=system:serviceaccount:${NS}:gratitud-deployer
OK=0; FAIL=0
ok(){   echo "  [OK]    $1"; OK=$((OK+1)); }
bad(){  echo "  [FALLA] $1"; FAIL=$((FAIL+1)); }
chk(){ [ "$2" = "$3" ] && ok "$1" || bad "$1 (obtenido '$2', esperado '$3')"; }
EX="kubectl -n $NS exec"

echo "== Validando GRATITUD en el namespace '$NS' =="

echo "-- Capa 1: aplicacion y Services --"
for t in portal:2 api:2 cache:1; do
  d=${t%%:*}; want=${t##*:}
  rr=$(kubectl -n $NS get deploy "$d" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
  chk "Deployment $d con $want replica(s) Ready" "${rr:-0}" "$want"
  ep=$(kubectl -n $NS get endpointslices -l kubernetes.io/service-name=$d \
        -o jsonpath='{range .items[*]}{range .endpoints[*]}{.addresses[0]}{"\n"}{end}{end}' 2>/dev/null | grep -c . || echo 0)
  [ "${ep:-0}" -ge 1 ] && ok "Service $d con $ep endpoint(s)" || bad "Service $d sin endpoints"
  tp=$(kubectl -n $NS get svc "$d" -o jsonpath='{.spec.ports[0].targetPort}' 2>/dev/null || echo "-")
  chk "Service $d targetPort 8080" "${tp:--}" "8080"
done
en=$(kubectl -n $NS get svc db-externa -o jsonpath='{.spec.type}/{.spec.externalName}' 2>/dev/null || echo "-")
chk "Service db-externa (ExternalName)" "$en" "ExternalName/db.corp.example.com"

echo "-- Capa 2: entrada e Ingress --"
addr=$(kubectl -n $NS get ingress gratitud \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
[ -n "$addr" ] && ok "el Ingress tiene ADDRESS ($addr)" || bad "el Ingress sigue sin ADDRESS"
ts=$(kubectl -n $NS get ingress gratitud -o jsonpath='{.spec.tls[0].secretName}' 2>/dev/null || echo "-")
tt=$(kubectl -n $NS get secret "$ts" -o jsonpath='{.type}' 2>/dev/null || echo "-")
chk "el Secret TLS del Ingress ($ts) es kubernetes.io/tls" "$tt" "kubernetes.io/tls"
echo "  [NOTA] HTTPS externo: curl -k --resolve gratitud.example.com:443:<IP-NODO> https://gratitud.example.com/api"

echo "-- Capa 3: configuracion y almacenamiento --"
for o in "configmap gratitud-config" "secret gratitud-db" "secret gratitud-tokens"; do
  e=$(kubectl -n $NS get $o -o name 2>/dev/null | wc -l | tr -d ' '); chk "$o existe" "$e" "1"
done
$EX deploy/api -- sh -c 'test -n "$DB_PASSWORD" && test -n "$PARTNER_TOKEN" && test -n "$LOG_LEVEL"' 2>/dev/null \
  && ok "la API tiene DB_PASSWORD, PARTNER_TOKEN y LOG_LEVEL" || bad "faltan variables inyectadas en la API"
ph=$(kubectl -n $NS get pvc gratitud-uploads -o jsonpath='{.status.phase}' 2>/dev/null || echo "-")
chk "PVC gratitud-uploads en Bound" "$ph" "Bound"
$EX deploy/cache -- sh -c 'echo integrador > /data/uploads/marca.txt' 2>/dev/null
kubectl -n $NS delete pod -l tier=cache >/dev/null 2>&1
kubectl -n $NS rollout status deploy/cache --timeout=90s >/dev/null 2>&1 || true
$EX deploy/cache -- cat /data/uploads/marca.txt 2>/dev/null | grep -q integrador \
  && ok "el fichero de uploads sobrevive a borrar el Pod" || bad "los datos NO persisten"

echo "-- Capa 4: observabilidad --"
kubectl -n $NS top pod >/dev/null 2>&1 && ok "kubectl top pod devuelve cifras" || bad "kubectl top no funciona (metrics-server?)"
for d in portal api cache; do
  kubectl -n $NS logs deploy/$d --tail=1 2>/dev/null | grep -q . \
    && ok "kubectl logs deploy/$d produce salida" || bad "kubectl logs deploy/$d vacio"
done

echo "-- Capa 5: seguridad --"
c1=$(kubectl auth can-i update deploy -n $NS --as=$SA 2>/dev/null || echo no)
chk "gratitud-deployer puede update deployments" "$c1" "yes"
c2=$(kubectl auth can-i get secrets -n $NS --as=$SA 2>/dev/null || echo no)
chk "gratitud-deployer NO puede leer secrets" "$c2" "no"
np=$(kubectl -n $NS get networkpolicy -o name 2>/dev/null | wc -l | tr -d ' ')
[ "${np:-0}" -ge 5 ] && ok "hay $np NetworkPolicies" || bad "faltan NetworkPolicies (hay $np)"
kubectl -n $NS get networkpolicy default-deny >/dev/null 2>&1 && ok "existe default-deny" || bad "no existe default-deny"
psa=$(kubectl get ns $NS -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}' 2>/dev/null || echo "-")
chk "el namespace tiene enforce=restricted" "${psa:--}" "restricted"

echo "-- Capa 6: empaquetado --"
helm -n $NS status gratitud >/dev/null 2>&1 && ok "la release helm 'gratitud' esta desplegada" || bad "no hay release helm 'gratitud'"

echo
echo "== $OK OK · $FAIL FALLA =="
[ "$FAIL" -eq 0 ] && { echo "INTEGRADOR SUPERADO"; exit 0; } || { echo "Quedan $FAIL punto(s)."; exit 1; }
