#!/usr/bin/env bash
# SESION 13 - Valida el LAB 13.4.
set -uo pipefail
OK=0; FAIL=0
chk(){ if [ "$2" = "$3" ]; then echo "  [OK]    $1"; OK=$((OK+1)); else echo "  [FALLA] $1 (obtenido '$2', esperado '$3')"; FAIL=$((FAIL+1)); fi; }

echo "== Validando LAB 13.4 =="
kubectl -n gratitud-api      rollout status deploy/api    --timeout=60s >/dev/null 2>&1 || true
kubectl -n gratitud-api      rollout status deploy/probe  --timeout=60s >/dev/null 2>&1 || true
kubectl -n gratitud-frontend rollout status deploy/frontend --timeout=60s >/dev/null 2>&1 || true

# --- Fallo 1: RBAC ---
CANI=$(kubectl auth can-i create deployments -n gratitud-api \
  --as=system:serviceaccount:gratitud-api:gratitud-deployer 2>/dev/null || echo "no")
chk "gratitud-deployer puede crear deployments en gratitud-api" "$CANI" "yes"

# no debe tener via libre
STAR=$(kubectl auth can-i '*' '*' -n gratitud-api \
  --as=system:serviceaccount:gratitud-api:gratitud-deployer 2>/dev/null || echo "no")
chk "gratitud-deployer NO es cluster-admin del namespace" "$STAR" "no"

# --- Fallo 2: allow-dns en gratitud-api ---
DNS=$(kubectl -n gratitud-api get networkpolicy -o json 2>/dev/null \
  | grep -o '"port": *53' | head -1)
if [ -n "$DNS" ]; then echo "  [OK]    gratitud-api tiene una NetworkPolicy que permite el puerto 53"; OK=$((OK+1))
else echo "  [FALLA] gratitud-api sigue sin permitir el DNS (puerto 53)"; FAIL=$((FAIL+1)); fi

# --- Fallo 2 (efecto): probe resuelve y alcanza cache ---
if kubectl -n gratitud-api exec deploy/probe -- sh -c \
   'nslookup cache.gratitud-datos >/dev/null 2>&1 && curl -s --max-time 5 -o /dev/null http://cache.gratitud-datos' 2>/dev/null; then
  echo "  [OK]    probe(gratitud-api) resuelve y alcanza cache.gratitud-datos"; OK=$((OK+1))
else
  echo "  [FALLA] probe(gratitud-api) no resuelve o no alcanza cache.gratitud-datos"; FAIL=$((FAIL+1))
fi

# --- Fallo 3: frontend -> api ---
if kubectl -n gratitud-frontend exec deploy/frontend -- \
   curl -s --max-time 5 -o /dev/null http://api.gratitud-api 2>/dev/null; then
  echo "  [OK]    frontend alcanza api.gratitud-api"; OK=$((OK+1))
else
  echo "  [FALLA] frontend NO alcanza api.gratitud-api"; FAIL=$((FAIL+1))
fi

# --- Fallo 4: worker desplegado bajo enforce=restricted ---
kubectl -n gratitud-batch rollout status deploy/worker --timeout=60s >/dev/null 2>&1 || true
WR=$(kubectl -n gratitud-batch get deploy worker -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
chk "Deployment worker (gratitud-batch) con 1 replica Ready" "${WR:-0}" "1"

# --- default-deny intactos ---
for ns in gratitud-frontend gratitud-api gratitud-datos; do
  D=$(kubectl -n $ns get networkpolicy default-deny -o name 2>/dev/null | wc -l | tr -d ' ')
  chk "default-deny sigue en $ns" "$D" "1"
done

echo
if [ "$FAIL" -eq 0 ]; then
  echo "LAB 13.4 SUPERADO (${OK} comprobaciones)"
  exit 0
else
  echo "LAB 13.4 NO superado: ${FAIL} pendiente(s)."
  exit 1
fi
