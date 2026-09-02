#!/usr/bin/env bash
# SESION 11 - Valida el LAB 11.4.
set -uo pipefail
OK=0; FAIL=0
chk(){ if [ "$2" = "$3" ]; then echo "  [OK]    $1"; OK=$((OK+1)); else echo "  [FALLA] $1 (obtenido '$2', esperado '$3')"; FAIL=$((FAIL+1)); fi; }

echo "== Validando LAB 11.4 =="

# --- Fallo 1: secretKeyRef.key ---
KEY=$(kubectl -n gratitud-api get deploy api \
  -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="DB_PASSWORD")].valueFrom.secretKeyRef.key}' 2>/dev/null || echo "-")
chk "api: secretKeyRef.key = DB_PASSWORD" "${KEY:--}" "DB_PASSWORD"

# --- Fallo 2: configMapRef.name existe ---
CMREF=$(kubectl -n gratitud-api get deploy api \
  -o jsonpath='{.spec.template.spec.containers[0].envFrom[0].configMapRef.name}' 2>/dev/null || echo "-")
CMOK=$(kubectl -n gratitud-api get configmap "$CMREF" -o name 2>/dev/null | wc -l | tr -d ' ')
chk "api: envFrom.configMapRef '$CMREF' existe" "$CMOK" "1"

# --- Fallo 3: subPath coincide con items.path ---
SP=$(kubectl -n gratitud-api get deploy api \
  -o jsonpath='{.spec.template.spec.containers[0].volumeMounts[?(@.name=="cfg")].subPath}' 2>/dev/null || echo "-")
chk "api: volumeMounts.subPath = app.conf" "${SP:--}" "app.conf"

# --- Pod api Running 1/1 ---
kubectl -n gratitud-api rollout status deploy/api --timeout=90s >/dev/null 2>&1 || true
READY=$(kubectl -n gratitud-api get deploy api -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
chk "Deployment api con 1 replica Ready" "${READY:-0}" "1"

# --- env y fichero dentro del contenedor ---
if kubectl -n gratitud-api exec deploy/api -- sh -c 'test -n "$DB_PASSWORD"' 2>/dev/null; then
  echo "  [OK]    api: \$DB_PASSWORD tiene valor"; OK=$((OK+1))
else
  echo "  [FALLA] api: \$DB_PASSWORD vacio o Pod no operativo"; FAIL=$((FAIL+1))
fi
if kubectl -n gratitud-api exec deploy/api -- sh -c 'test -s /etc/gratitud/app.conf' 2>/dev/null; then
  echo "  [OK]    api: /etc/gratitud/app.conf presente y no vacio"; OK=$((OK+1))
else
  echo "  [FALLA] api: /etc/gratitud/app.conf ausente o vacio (subPath)"; FAIL=$((FAIL+1))
fi

# --- Fallo 4: PVC Bound ---
PHASE=$(kubectl -n gratitud-datos get pvc gratitud-uploads -o jsonpath='{.status.phase}' 2>/dev/null || echo "-")
chk "PVC gratitud-uploads en Bound" "${PHASE:--}" "Bound"

# --- datos Running ---
kubectl -n gratitud-datos rollout status deploy/datos --timeout=90s >/dev/null 2>&1 || true
DR=$(kubectl -n gratitud-datos get deploy datos -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
chk "Deployment datos con 1 replica Ready" "${DR:-0}" "1"
if kubectl -n gratitud-datos exec deploy/datos -- sh -c 'touch /data/uploads/.w && rm /data/uploads/.w' 2>/dev/null; then
  echo "  [OK]    datos: /data/uploads es escribible"; OK=$((OK+1))
else
  echo "  [FALLA] datos: no puedo escribir en /data/uploads"; FAIL=$((FAIL+1))
fi

# --- objetos de config intactos ---
for o in "configmap gratitud-config" "secret gratitud-db" "secret gratitud-api-tokens"; do
  E=$(kubectl -n gratitud-api get $o -o name 2>/dev/null | wc -l | tr -d ' ')
  chk "$o sigue existiendo" "$E" "1"
done

echo
if [ "$FAIL" -eq 0 ]; then
  echo "LAB 11.4 SUPERADO (${OK} comprobaciones)"
  exit 0
else
  echo "LAB 11.4 NO superado: ${FAIL} pendiente(s)."
  exit 1
fi
