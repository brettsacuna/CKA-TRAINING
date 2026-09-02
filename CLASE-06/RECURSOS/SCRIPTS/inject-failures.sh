#!/usr/bin/env bash
# CLASE 6 - Inyecta fallas en la arquitectura del LAB 6.5 (Fase 2).
# El instructor lo ejecuta cuando el alumno ha superado la Fase 1.
set -uo pipefail
NS=${NS:-tienda}

kubectl get ns "$NS" >/dev/null 2>&1 || { echo "El namespace $NS no existe. Completa la Fase 1 primero."; exit 1; }

echo ">> Inyectando fallas en el namespace ${NS}..."
N=0

# 1. selector incorrecto en el Service backend
kubectl -n $NS patch svc backend -p '{"spec":{"selector":{"app":"backend-old"}}}' >/dev/null 2>&1 && N=$((N+1))

# 2. targetPort incorrecto en el Service frontend
kubectl -n $NS patch svc frontend --type=json \
  -p='[{"op":"replace","path":"/spec/ports/0/targetPort","value":8080}]' >/dev/null 2>&1 && N=$((N+1))

# 3. ConfigMap mal referenciado en backend
kubectl -n $NS patch deploy backend --type=json \
  -p='[{"op":"replace","path":"/spec/template/spec/containers/0/envFrom/0/configMapRef/name","value":"app-config-v2"}]' >/dev/null 2>&1 && N=$((N+1))

# 4. clave de Secret inexistente en backend
kubectl -n $NS patch deploy backend --type=json \
  -p='[{"op":"replace","path":"/spec/template/spec/containers/0/env/0/valueFrom/secretKeyRef/key","value":"passwd"}]' >/dev/null 2>&1 && N=$((N+1))

# 5. NetworkPolicy que bloquea frontend -> backend
kubectl -n $NS patch networkpolicy allow-frontend-to-backend --type=json \
  -p='[{"op":"replace","path":"/spec/ingress/0/from/0/podSelector/matchLabels/app","value":"ninguno"}]' >/dev/null 2>&1 && N=$((N+1))

# 6. Ingress apuntando a un Service inexistente
kubectl -n $NS patch ingress tienda --type=json \
  -p='[{"op":"replace","path":"/spec/rules/0/http/paths/0/backend/service/name","value":"frontend-svc"}]' >/dev/null 2>&1 && N=$((N+1))

# 7. problema de scheduling en frontend
kubectl -n $NS patch deploy frontend --type=json \
  -p='[{"op":"add","path":"/spec/template/spec/nodeSelector","value":{"tier":"gold"}}]' >/dev/null 2>&1 && N=$((N+1))

echo ">> ${N} fallas inyectadas. No se te dira cuales."
echo ">> Repara in situ. Prohibido borrar el namespace o la politica default-deny."
