#!/usr/bin/env bash
# CLASE 2 - Valida el LAB 2.4 (RBAC).
set -uo pipefail
OK=0; FAIL=0
expect() { # descripcion  esperado  comando...
  local d="$1" e="$2"; shift 2
  local r; r=$("$@" 2>/dev/null | tail -1)
  if [ "$r" = "$e" ]; then echo "  [OK]    $d = $e"; OK=$((OK+1));
  else echo "  [FALLA] $d -> obtenido '$r', esperado '$e'"; FAIL=$((FAIL+1)); fi
}

echo "== Validando LAB 2.4 (RBAC) =="
SA=system:serviceaccount:project-hamster:processor

expect "red/jane  get secrets"      yes kubectl -n red  auth can-i get    secrets --as jane
expect "red/jane  list secrets"     no  kubectl -n red  auth can-i list   secrets --as jane
expect "red/jane  delete secrets"   no  kubectl -n red  auth can-i delete secrets --as jane
expect "blue/jane get secrets"      yes kubectl -n blue auth can-i get    secrets --as jane
expect "blue/jane list secrets"     yes kubectl -n blue auth can-i list   secrets --as jane
expect "blue/jane delete secrets"   no  kubectl -n blue auth can-i delete secrets --as jane
expect "jane delete deploy (-A)"    yes kubectl auth can-i delete deployments --as jane -A
expect "jane delete deploy default" yes kubectl -n default auth can-i delete deployments --as jane
expect "jim  delete deploy red"     yes kubectl -n red     auth can-i delete deployments --as jim
expect "jim  delete deploy default" no  kubectl -n default auth can-i delete deployments --as jim
expect "jim  delete deploy (-A)"    no  kubectl auth can-i delete deployments --as jim -A
expect "SA create secrets"          yes kubectl -n project-hamster auth can-i create secrets    --as "$SA"
expect "SA create configmaps"       yes kubectl -n project-hamster auth can-i create configmaps --as "$SA"
expect "SA delete secrets"          no  kubectl -n project-hamster auth can-i delete secrets    --as "$SA"
expect "SA create secrets en red"   no  kubectl -n red auth can-i create secrets --as "$SA"

echo
if [ "$FAIL" -eq 0 ]; then
  echo "LAB 2.4 SUPERADO (${OK} comprobaciones)"; exit 0
else
  echo "LAB 2.4 NO superado: ${FAIL} comprobacion(es) incorrecta(s)."; exit 1
fi
