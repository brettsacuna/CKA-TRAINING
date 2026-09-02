#!/usr/bin/env bash
# SESION 12 - Valida el LAB 12.4.
set -uo pipefail
NS=gratitud-api; OK=0; FAIL=0
chk(){ if [ "$2" = "$3" ]; then echo "  [OK]    $1"; OK=$((OK+1)); else echo "  [FALLA] $1 (obtenido '$2', esperado '$3')"; FAIL=$((FAIL+1)); fi; }

echo "== Validando LAB 12.4 =="
kubectl -n $NS rollout status deploy/api    --timeout=90s >/dev/null 2>&1 || true
kubectl -n $NS rollout status deploy/portal --timeout=90s >/dev/null 2>&1 || true
kubectl -n $NS rollout status deploy/worker --timeout=60s >/dev/null 2>&1 || true

# --- Fallo 1: startupProbe en api (o liveness con margen) ---
SP=$(kubectl -n $NS get deploy api -o jsonpath='{.spec.template.spec.containers[0].startupProbe}' 2>/dev/null || echo "")
LID=$(kubectl -n $NS get deploy api -o jsonpath='{.spec.template.spec.containers[0].livenessProbe.initialDelaySeconds}' 2>/dev/null || echo 0)
if [ -n "$SP" ] || [ "${LID:-0}" -ge 25 ] 2>/dev/null; then
  echo "  [OK]    api: el arranque lento esta protegido (startupProbe o initialDelay >= 25)"; OK=$((OK+1))
else
  echo "  [FALLA] api: sigue sin startupProbe y con initialDelay bajo"; FAIL=$((FAIL+1))
fi

# --- Fallo 2: readinessProbe al puerto correcto ---
RPORT=$(kubectl -n $NS get deploy api -o jsonpath='{.spec.template.spec.containers[0].readinessProbe.httpGet.port}' 2>/dev/null || echo "-")
chk "api: readinessProbe.httpGet.port = 80" "${RPORT:--}" "80"

# --- api estable y con endpoints ---
AR=$(kubectl -n $NS get deploy api -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
chk "api: 1 replica Ready" "${AR:-0}" "1"
EP=$(kubectl -n $NS get endpoints api -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || echo "")
if [ -n "$EP" ]; then echo "  [OK]    api: el Service tiene endpoints ($EP)"; OK=$((OK+1))
else echo "  [FALLA] api: el Service sigue sin endpoints"; FAIL=$((FAIL+1)); fi
RC=$(kubectl -n $NS get pod -l app=gratitud-api -o jsonpath='{.items[0].status.containerStatuses[0].restartCount}' 2>/dev/null || echo 99)
if [ "${RC:-99}" -le 3 ] 2>/dev/null; then echo "  [OK]    api: RESTARTS estable ($RC)"; OK=$((OK+1))
else echo "  [FALLA] api: sigue reiniciandose (RESTARTS=$RC)"; FAIL=$((FAIL+1)); fi

# --- Fallo 3: limits.memory de portal ---
PMEM=$(kubectl -n $NS get deploy portal -o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}' 2>/dev/null || echo "-")
if [ "$PMEM" = "8Mi" ] || [ "$PMEM" = "-" ]; then
  echo "  [FALLA] portal: limits.memory sigue en '$PMEM'"; FAIL=$((FAIL+1))
else
  echo "  [OK]    portal: limits.memory ajustado ($PMEM)"; OK=$((OK+1))
fi
PR=$(kubectl -n $NS get deploy portal -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
chk "portal: 1 replica Ready" "${PR:-0}" "1"
LS=$(kubectl -n $NS get pod -l app=gratitud-portal -o jsonpath='{.items[0].status.containerStatuses[0].lastState.terminated.reason}' 2>/dev/null || echo "")
if [ "$LS" = "OOMKilled" ]; then echo "  [FALLA] portal: ultimo estado sigue siendo OOMKilled"; FAIL=$((FAIL+1))
else echo "  [OK]    portal: sin OOMKilled reciente"; OK=$((OK+1)); fi

# --- Fallo 4: logs del worker a stdout ---
WLOG=$(kubectl -n $NS logs deploy/worker --tail=5 2>/dev/null | grep -c . || echo 0)
if [ "${WLOG:-0}" -ge 1 ]; then echo "  [OK]    worker: 'kubectl logs' produce salida"; OK=$((OK+1))
else echo "  [FALLA] worker: 'kubectl logs' sigue vacio"; FAIL=$((FAIL+1)); fi

echo
if [ "$FAIL" -eq 0 ]; then
  echo "LAB 12.4 SUPERADO (${OK} comprobaciones)"
  exit 0
else
  echo "LAB 12.4 NO superado: ${FAIL} pendiente(s)."
  exit 1
fi
