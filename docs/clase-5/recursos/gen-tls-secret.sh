#!/usr/bin/env bash
# CLASE 5 - Genera un certificado autofirmado y crea el Secret TLS del LAB 5.2.
set -euo pipefail
CN=${CN:-secure-ingress.com}
NS=${NS:-c5-ingress}
NAME=${NAME:-secure-ingress}
DIR=$(mktemp -d)

echo ">> Generando certificado autofirmado para CN=${CN} (3650 dias)..."
openssl req -x509 -newkey rsa:4096 -nodes -days 3650 \
  -keyout "$DIR/key.pem" -out "$DIR/cert.pem" \
  -subj "/C=PE/ST=LIMA/L=LIMA/O=CKA-TRAINING/OU=LAB/CN=${CN}" \
  -addext "subjectAltName=DNS:${CN}"

echo ">> Creando Secret ${NAME} de tipo kubernetes.io/tls en ${NS}..."
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl -n "$NS" create secret tls "$NAME" \
  --cert="$DIR/cert.pem" --key="$DIR/key.pem" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl -n "$NS" get secret "$NAME" -o jsonpath='{.type}{"\n"}'
echo ">> Certificado en: $DIR"
echo ">> Verifica el CN con: openssl x509 -in $DIR/cert.pem -noout -subject"
