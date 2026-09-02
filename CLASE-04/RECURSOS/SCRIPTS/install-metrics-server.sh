#!/usr/bin/env bash
# CLASE 4 - Instala Metrics Server v0.8.1.
# En clusters kubeadm de laboratorio, los certificados de serving del kubelet suelen
# ser autofirmados; por eso se ofrece el parche --kubelet-insecure-tls (SOLO laboratorio).
set -euo pipefail
VER=${VER:-v0.8.1}

echo ">> Instalando Metrics Server ${VER}..."
kubectl apply -f "https://github.com/kubernetes-sigs/metrics-server/releases/download/${VER}/components.yaml"

echo ">> Esperando al despliegue (puede quedarse en 0/1: es el sintoma que debes diagnosticar)..."
kubectl -n kube-system rollout status deploy/metrics-server --timeout=90s || true

echo
echo "Si los Pods no llegan a Ready, revisa:"
echo "   kubectl -n kube-system logs deploy/metrics-server | tail -20"
echo
echo "Parche habitual en laboratorio (NO usar en produccion):"
cat <<'TXT'
   kubectl -n kube-system patch deploy metrics-server --type=json -p='[
     {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"},
     {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-preferred-address-types=InternalIP"}
   ]'
TXT
echo
echo "Validar:  kubectl top nodes && kubectl top pods -A"
