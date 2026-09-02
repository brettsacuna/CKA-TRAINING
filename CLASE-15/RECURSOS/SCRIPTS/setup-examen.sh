#!/usr/bin/env bash
# SESION 15 - Prepara el ESCENARIO DEL EXAMEN PRACTICO (LAB 15.3).
# Instala GRATITUD y luego inyecta 9 fallos repartidos por las seis capas.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
CHART="$HERE/../CHART/gratitud"
NS=gratitud
command -v helm >/dev/null || { echo "helm no esta instalado."; exit 1; }

# --- namespace con Pod Security ---
kubectl create namespace $NS --dry-run=client -o yaml | kubectl apply -f -
kubectl label ns $NS \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/warn=restricted --overwrite >/dev/null

# --- Secret TLS correcto ---
if command -v openssl >/dev/null; then
  D=$(mktemp -d)
  openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
    -keyout "$D/k.pem" -out "$D/c.pem" \
    -subj "/O=CKA-TRAINING/CN=gratitud.example.com" \
    -addext "subjectAltName=DNS:gratitud.example.com" 2>/dev/null
  kubectl -n $NS create secret tls gratitud-tls --cert="$D/c.pem" --key="$D/k.pem" \
    --dry-run=client -o yaml | kubectl apply -f -
fi

# --- PV estatico para el PVC (proveedor-independiente) ---
kubectl apply -f - <<'YAML'
apiVersion: v1
kind: PersistentVolume
metadata: {name: gratitud-pv-uploads, labels: {app: gratitud}}
spec:
  storageClassName: manual
  capacity: {storage: 1Gi}
  accessModes: ["ReadWriteOnce"]
  persistentVolumeReclaimPolicy: Retain
  hostPath: {path: /mnt/gratitud-uploads, type: DirectoryOrCreate}
YAML

# --- instalar GRATITUD (correcto) ---
helm upgrade --install gratitud "$CHART" -n $NS \
  -f "$CHART/values-examen.yaml" --wait --timeout 180s || true

echo ">> Inyectando fallos..."

# 1. Services/DNS: selector del Service api roto
kubectl -n $NS patch svc api --type=merge -p '{"spec":{"selector":{"app.kubernetes.io/instance":"gratitud","tier":"api-v2"}}}'
# 2. Services/DNS: targetPort de cache equivocado
kubectl -n $NS patch svc cache --type=json -p='[{"op":"replace","path":"/spec/ports/0/targetPort","value":80}]'
# 3. Ingress: clase inexistente
kubectl -n $NS patch ingress gratitud --type=merge -p '{"spec":{"ingressClassName":"nginx"}}'
# 4. Ingress/TLS: secretName inexistente
kubectl -n $NS patch ingress gratitud --type=json -p='[{"op":"replace","path":"/spec/tls/0/secretName","value":"gratitud-tls-old"}]'
# 5. Config: clave de secretKeyRef equivocada en la API
kubectl -n $NS patch deploy api --type=json -p='[{"op":"replace","path":"/spec/template/spec/containers/0/env/0/valueFrom/secretKeyRef/key","value":"PARTNER"}]'
# 6. Storage: claimName con typo en el Deployment cache
kubectl -n $NS patch deploy cache --type=json -p='[{"op":"replace","path":"/spec/template/spec/volumes/3/persistentVolumeClaim/claimName","value":"gratitud-upload"}]' 2>/dev/null || \
kubectl -n $NS patch deploy cache --type=json -p='[{"op":"replace","path":"/spec/template/spec/volumes/2/persistentVolumeClaim/claimName","value":"gratitud-upload"}]'
# 7. Observabilidad: readinessProbe de portal al puerto equivocado
kubectl -n $NS patch deploy portal --type=json -p='[{"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/port","value":9090}]'
# 8. Seguridad/RBAC: subject del RoleBinding mal escrito
kubectl -n $NS patch rolebinding gratitud-deployer --type=json -p='[{"op":"replace","path":"/subjects/0/name","value":"gratitud-deploy"}]'
# 9. Seguridad/NetPol: se elimina la politica portal->api
kubectl -n $NS delete networkpolicy allow-portal-to-api --ignore-not-found

echo
echo "==============================================================="
echo " EXAMEN PRACTICO (LAB 15.3) listo. GRATITUD tiene 9 fallos"
echo " repartidos por las seis capas. Diagnostica y repara."
echo " Puntuacion:  cd CLASE-15/RECURSOS/SCRIPTS && ./evaluar.sh"
echo " Prohibido: cluster-admin, borrar default-deny, quitar sondas/limites."
echo "==============================================================="
