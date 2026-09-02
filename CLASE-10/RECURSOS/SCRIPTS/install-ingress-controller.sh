#!/usr/bin/env bash
# SESION 10 - Instala un Ingress Controller MANTENIDO (Traefik) mediante Helm.
#
# NOTA (2026): kubernetes/ingress-nginx fue RETIRADO en marzo de 2026 (repositorio
# archivado, sin parches de seguridad). La API Ingress sigue vigente; el curso usa
# Traefik, que soporta Ingress estandar y Gateway API.
#
# Es idempotente y comparte configuracion con el script de la Clase 5:
# NodePort 32080 (HTTP) / 32443 (HTTPS), IngressClass 'traefik' por defecto.
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
echo "Prueba:  curl --resolve <host>:32080:<IP-NODO> http://<host>:32080/<path>"
echo "HTTPS :  curl -kv --resolve <host>:32443:<IP-NODO> https://<host>:32443/<path>"
