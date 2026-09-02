#!/usr/bin/env bash
# SESION 12 - Instala metrics-server (para 'kubectl top' y el HPA).
#
# En clusters kubeadm de laboratorio, los certificados de serving del kubelet
# suelen ser autofirmados; por eso se aplica --kubelet-insecure-tls (SOLO laboratorio).
set -euo pipefail
VER=${VER:-v0.8.1}

echo ">> Instalando metrics-server ${VER}..."
kubectl apply -f "https://github.com/kubernetes-sigs/metrics-server/releases/download/${VER}/components.yaml"

echo ">> Parche de laboratorio (NO usar en produccion)..."
kubectl -n kube-system patch deploy metrics-server --type=json -p='[
  {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"},
  {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-preferred-address-types=InternalIP"}
]' || true

kubectl -n kube-system rollout status deploy/metrics-server --timeout=120s || true

echo
echo "Validar (puede tardar ~30 s en dar cifras):"
echo "   kubectl top node"
echo "   kubectl top pod -A"
echo
echo "Si 'Metrics API not available' persiste:"
echo "   kubectl -n kube-system logs deploy/metrics-server | tail -20"
