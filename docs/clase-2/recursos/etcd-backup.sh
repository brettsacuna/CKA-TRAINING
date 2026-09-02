#!/usr/bin/env bash
# CLASE 2 - Snapshot de etcd para cluster kubeadm de un solo control plane.
# Ejecutar como root EN EL NODO DEL CONTROL PLANE.
set -euo pipefail

PKI=/etc/kubernetes/pki/etcd
DEST=${1:-/opt/backup/etcd-$(date +%Y%m%d-%H%M%S).db}
ENDPOINT=${ENDPOINT:-https://127.0.0.1:2379}

command -v etcdctl >/dev/null || { echo "etcdctl no esta instalado en este nodo"; exit 1; }
mkdir -p "$(dirname "$DEST")"

echo ">> Endpoint : $ENDPOINT"
echo ">> Destino  : $DEST"

etcdctl --endpoints="$ENDPOINT" \
  --cacert="$PKI/ca.crt" --cert="$PKI/server.crt" --key="$PKI/server.key" \
  endpoint health

etcdctl --endpoints="$ENDPOINT" \
  --cacert="$PKI/ca.crt" --cert="$PKI/server.crt" --key="$PKI/server.key" \
  snapshot save "$DEST"

echo
echo ">> Validando el snapshot (etcdutl):"
if command -v etcdutl >/dev/null; then
  etcdutl snapshot status "$DEST" --write-out=table
else
  echo "   etcdutl no disponible; instalalo desde el release de etcd de tu cluster."
fi

echo
echo ">> Snapshot listo: $DEST"
echo "   Restore:  etcdutl snapshot restore $DEST --data-dir /var/lib/etcd-restore"
