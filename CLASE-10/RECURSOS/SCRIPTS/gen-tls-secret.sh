#!/usr/bin/env bash
# SESION 10 - Genera un certificado autofirmado y crea un Secret kubernetes.io/tls.
#
# Variables de entorno (con sus valores por defecto):
#   CN=gratitud.example.com     Common Name y subjectAltName del certificado
#   NS=gratitud-web             namespace donde se crea el Secret
#   NAME=gratitud-tls           nombre del Secret
#
# Ejemplo para el segundo dominio del LAB 10.3:
#   CN=admin.gratitud.example.com NAME=admin-gratitud-tls NS=gratitud-web ./gen-tls-secret.sh
set -euo pipefail
CN=${CN:-gratitud.example.com}
NS=${NS:-gratitud-web}
NAME=${NAME:-gratitud-tls}
DIR=$(mktemp -d)

echo ">> Certificado autofirmado para CN=${CN} (3650 dias)..."
openssl req -x509 -newkey rsa:4096 -nodes -days 3650 \
  -keyout "$DIR/key.pem" -out "$DIR/cert.pem" \
  -subj "/C=PE/ST=LIMA/L=LIMA/O=CKA-TRAINING/OU=LAB/CN=${CN}" \
  -addext "subjectAltName=DNS:${CN}"

echo ">> Secret ${NAME} (kubernetes.io/tls) en ${NS}..."
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl -n "$NS" create secret tls "$NAME" \
  --cert="$DIR/cert.pem" --key="$DIR/key.pem" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl -n "$NS" get secret "$NAME" -o jsonpath='{.type}{"\n"}'
echo ">> Archivos en: $DIR"
echo ">> Verifica el CN:  openssl x509 -in $DIR/cert.pem -noout -subject"
