#!/usr/bin/env bash
# CLASE 5 - Instala un Ingress Controller MANTENIDO (Traefik) mediante Helm.
#
# NOTA IMPORTANTE (2026): el controlador comunitario kubernetes/ingress-nginx fue
# RETIRADO en marzo de 2026. Su repositorio esta archivado y no recibe parches de
# seguridad. Por eso este curso usa Traefik, que soporta la API Ingress estandar
# y ademas implementa Gateway API.
set -euo pipefail
NS=${NS:-ingress}

command -v helm >/dev/null || { echo "Helm no esta instalado. Instalalo primero."; exit 1; }

helm repo add traefik https://traefik.github.io/charts >/dev/null
helm repo update >/dev/null

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install traefik traefik/traefik \
  --namespace "$NS" \
  --set service.type=NodePort \
  --set ports.web.nodePort=32080 \
  --set ports.websecure.nodePort=32443 \
  --set ingressClass.enabled=true \
  --set ingressClass.isDefaultClass=true

kubectl -n "$NS" rollout status deploy/traefik --timeout=180s

echo
echo "== IngressClass registrada =="
kubectl get ingressclass
echo
echo "== Service del controlador =="
kubectl -n "$NS" get svc traefik
echo
echo "Prueba con:  curl http://<IP-de-un-nodo>:32080/<path>"
echo "HTTPS en   :  https://<host>:32443/<path>"
