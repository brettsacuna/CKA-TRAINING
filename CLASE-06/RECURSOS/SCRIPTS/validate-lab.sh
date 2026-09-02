#!/usr/bin/env bash
# CLASE 6 - Validador. Uso: ./validate-lab.sh [basico|cadena|sprint|final]
set -uo pipefail
MODE=${1:-final}
OK=0; FAIL=0
chk(){ if [ "$2" = "$3" ]; then echo "  [OK]    $1"; OK=$((OK+1)); else echo "  [FALLA] $1 (obtenido '$2', esperado '$3')"; FAIL=$((FAIL+1)); fi; }
run(){ if "$@" >/dev/null 2>&1; then return 0; else return 1; fi; }

case "$MODE" in

basico)
  echo "== Validando LAB 6.1 =="
  NS=c6-estados
  for p in caso-1 caso-2 caso-3 caso-4 caso-5 caso-6; do
    R=$(kubectl -n $NS get pod $p -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null || echo "false")
    chk "$p esta Ready" "${R:-false}" "true"
  done
  ;;

cadena)
  echo "== Validando LAB 6.3 =="
  NS=c6-pedidos; SA=system:serviceaccount:c6-pedidos:deployer
  RD=$(kubectl -n $NS get sts pedidos -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
  chk "StatefulSet pedidos con 3 replicas Ready" "${RD:-0}" "3"
  BOUND=$(kubectl -n $NS get pvc --no-headers 2>/dev/null | grep -c Bound || echo 0)
  chk "3 PVC en Bound" "$BOUND" "3"
  SVCN=$(kubectl -n $NS get sts pedidos -o jsonpath='{.spec.serviceName}' 2>/dev/null || echo "-")
  if kubectl -n $NS get svc "$SVCN" >/dev/null 2>&1; then
    echo "  [OK]    serviceName apunta a un Service existente ($SVCN)"; OK=$((OK+1))
  else echo "  [FALLA] serviceName '$SVCN' no existe"; FAIL=$((FAIL+1)); fi
  SEL=$(kubectl -n $NS get svc "$SVCN" -o jsonpath='{.spec.selector.app}' 2>/dev/null || echo "-")
  chk "El Headless Service selecciona app=pedidos" "$SEL" "pedidos"
  if run kubectl -n $NS exec pedidos-0 -- sh -c 'touch /data/.p && rm -f /data/.p'; then
    echo "  [OK]    /data escribible en pedidos-0"; OK=$((OK+1))
  else echo "  [FALLA] /data no escribible en pedidos-0"; FAIL=$((FAIL+1)); fi
  if run kubectl -n $NS exec pedidos-0 -- sh -c 'env | grep -q APP_ENV'; then
    echo "  [OK]    la configuracion llega al contenedor"; OK=$((OK+1))
  else echo "  [FALLA] falta la configuracion en el contenedor"; FAIL=$((FAIL+1)); fi
  if run kubectl -n $NS exec pedidos-0 -- sh -c 'env | grep -q DB_PASSWORD'; then
    echo "  [OK]    la credencial llega al contenedor"; OK=$((OK+1))
  else echo "  [FALLA] falta DB_PASSWORD en el contenedor"; FAIL=$((FAIL+1)); fi
  C1=$(kubectl -n $NS auth can-i create statefulsets --as "$SA" 2>/dev/null | tail -1)
  chk "deployer puede crear statefulsets" "$C1" "yes"
  C2=$(kubectl -n $NS auth can-i delete secrets --as "$SA" 2>/dev/null | tail -1)
  chk "deployer NO puede borrar secrets" "$C2" "no"
  ;;

sprint)
  echo "== Validando LAB 6.4 (35 puntos) =="
  NS=c6-sprint; P=0
  RD=$(kubectl -n $NS get deploy api -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
  if [ "${RD:-0}" = "3" ]; then echo "  T1 [OK]  api 3/3            (+8)"; P=$((P+8)); else echo "  T1 [--]  api ${RD:-0}/3"; fi
  A=$(kubectl -n $NS get endpointslices -l kubernetes.io/service-name=api-svc \
      -o jsonpath='{range .items[*]}{range .endpoints[*]}{.addresses[0]}{"\n"}{end}{end}' 2>/dev/null | grep -c . || echo 0)
  if [ "$A" -ge 3 ]; then echo "  T2 [OK]  api-svc con endpoints (+5)"; P=$((P+5)); else echo "  T2 [--]  api-svc con $A endpoints"; fi
  BR=$(kubectl -n $NS get pod batch -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null || echo false)
  if [ "$BR" = "true" ]; then echo "  T3 [OK]  batch Running        (+12)"; P=$((P+12)); else echo "  T3 [--]  batch no esta Ready"; fi
  V1=$(kubectl -n $NS auth can-i list pods   --as system:serviceaccount:c6-sprint:viewer 2>/dev/null | tail -1)
  V2=$(kubectl -n $NS auth can-i delete pods --as system:serviceaccount:c6-sprint:viewer 2>/dev/null | tail -1)
  if [ "$V1" = "yes" ] && [ "$V2" = "no" ]; then echo "  T4 [OK]  viewer minimo        (+7)"; P=$((P+7)); else echo "  T4 [--]  viewer: list=$V1 delete=$V2"; fi
  SD=$(kubectl get nodes --no-headers 2>/dev/null | grep -c SchedulingDisabled || echo 0)
  if [ "$SD" = "0" ]; then echo "  T5 [OK]  nodos disponibles     (+3)"; P=$((P+3)); else echo "  T5 [--]  hay $SD nodo(s) cordonado(s)"; fi
  PCT=$(( P * 100 / 35 ))
  echo
  echo "PUNTUACION: ${P}/35  (${PCT}%)   -- aprobado CKA: 66%"
  [ "$PCT" -ge 66 ] && exit 0 || exit 1
  ;;

final)
  echo "== Validando LAB 6.5 - INTEGRADOR FINAL =="
  NS=tienda
  DB=$(kubectl -n $NS get sts db -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
  chk "StatefulSet db con 3 replicas Ready" "${DB:-0}" "3"
  HL=$(kubectl -n $NS get svc db -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "-")
  chk "Service db es headless" "$HL" "None"
  PVC=$(kubectl -n $NS get pvc --no-headers 2>/dev/null | grep -c Bound || echo 0)
  chk "3 PVC en Bound" "$PVC" "3"
  RWO=$(kubectl -n $NS get pvc -o jsonpath='{.items[0].spec.accessModes[0]}' 2>/dev/null || echo "-")
  chk "Los PVC son ReadWriteOnce" "$RWO" "ReadWriteOnce"
  BE=$(kubectl -n $NS get deploy backend  -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
  chk "backend 2/2 Ready"  "${BE:-0}" "2"
  FE=$(kubectl -n $NS get deploy frontend -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
  chk "frontend 2/2 Ready" "${FE:-0}" "2"
  BSEL=$(kubectl -n $NS get svc backend -o jsonpath='{.spec.selector.app}' 2>/dev/null || echo "-")
  chk "Selector del Service backend" "$BSEL" "backend"
  FTP=$(kubectl -n $NS get svc frontend -o jsonpath='{.spec.ports[0].targetPort}' 2>/dev/null || echo "-")
  chk "targetPort del Service frontend" "$FTP" "80"
  DD=$(kubectl -n $NS get networkpolicy default-deny -o name 2>/dev/null | wc -l)
  chk "La politica default-deny sigue existiendo" "$DD" "1"
  TLS=$(kubectl -n $NS get secret tienda-tls -o jsonpath='{.type}' 2>/dev/null || echo "-")
  chk "Secret TLS de tipo kubernetes.io/tls" "$TLS" "kubernetes.io/tls"
  ISVC=$(kubectl -n $NS get ingress tienda -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.name}' 2>/dev/null || echo "-")
  if kubectl -n $NS get svc "$ISVC" >/dev/null 2>&1; then
    echo "  [OK]    El Ingress apunta a un Service existente ($ISVC)"; OK=$((OK+1))
  else echo "  [FALLA] El Ingress apunta a '$ISVC', que no existe"; FAIL=$((FAIL+1)); fi
  if run kubectl -n $NS exec deploy/backend -- sh -c 'env | grep -q APP_ENV'; then
    echo "  [OK]    backend recibe la configuracion"; OK=$((OK+1))
  else echo "  [FALLA] backend no recibe APP_ENV"; FAIL=$((FAIL+1)); fi
  if run kubectl -n $NS exec deploy/backend -- sh -c 'env | grep -q DB_PASSWORD'; then
    echo "  [OK]    backend recibe la credencial"; OK=$((OK+1))
  else echo "  [FALLA] backend no recibe DB_PASSWORD"; FAIL=$((FAIL+1)); fi
  if run kubectl -n $NS exec deploy/frontend -- curl -s --max-time 5 -o /dev/null http://backend; then
    echo "  [OK]    frontend alcanza a backend"; OK=$((OK+1))
  else echo "  [FALLA] frontend NO alcanza a backend"; FAIL=$((FAIL+1)); fi
  echo
  if [ "$FAIL" -eq 0 ]; then
    echo "LABORATORIO INTEGRADOR SUPERADO (${OK} comprobaciones)"
    echo "Ultimo paso manual: curl -sk https://tienda.local:32443/ --resolve tienda.local:32443:<IP-NODO>"
    exit 0
  else
    echo "INTEGRADOR NO superado: ${FAIL} comprobacion(es) pendiente(s)."; exit 1
  fi
  ;;

*) echo "Uso: $0 [basico|cadena|sprint|final]"; exit 1;;
esac

echo
if [ "$FAIL" -eq 0 ]; then
  case "$MODE" in basico) echo "LAB 6.1 SUPERADO (${OK} comprobaciones)";;
                  cadena) echo "LAB 6.3 SUPERADO (${OK} comprobaciones)";; esac
  exit 0
else echo "No superado todavia: ${FAIL} pendiente(s)."; exit 1; fi
