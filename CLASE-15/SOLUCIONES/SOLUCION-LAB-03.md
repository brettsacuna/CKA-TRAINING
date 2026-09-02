# SOLUCIÓN — LAB 15.3 · Examen práctico

> **MATERIAL DEL INSTRUCTOR.**

## Los 9 fallos y su corrección

| # | Capa | Objeto · campo | Síntoma | Corrección |
|---|---|---|---|---|
| 1 | Services | `svc/api` `selector.tier: api-v2` | `endpoints api` vacío; portal→api falla | `tier: api` |
| 2 | Services | `svc/cache` `targetPort: 80` | `api` no alcanza `cache` (puerto) | `targetPort: 8080` |
| 3 | Ingress | `ingress/gratitud` `ingressClassName: nginx` | Ingress sin `ADDRESS` | la clase real (`traefik`) |
| 4 | Ingress/TLS | `ingress/gratitud` `tls[0].secretName: gratitud-tls-old` | HTTPS con cert por defecto | `gratitud-tls` |
| 5 | Config | `deploy/api` `env[0].valueFrom.secretKeyRef.key: PARTNER` | `api` en `CreateContainerConfigError` | `PARTNER_TOKEN` |
| 6 | Storage | `deploy/cache` volumen `claimName: gratitud-upload` | `cache` no arranca (volumen) | `gratitud-uploads` |
| 7 | Observabilidad | `deploy/portal` `readinessProbe.httpGet.port: 9090` | `portal` `0/2` Ready; sin endpoints | `8080` |
| 8 | Seguridad/RBAC | `rolebinding/gratitud-deployer` `subjects[0].name: gratitud-deploy` | `Forbidden` para la SA | `gratitud-deployer` |
| 9 | Seguridad/NetPol | falta `networkpolicy/allow-portal-to-api` | portal no alcanza a api | recrearla |

## Procedimiento

```bash
cd CLASE-15/RECURSOS/SCRIPTS && ./setup-examen.sh
kubectl -n gratitud get pod,svc,endpointslices,ingress,pvc

# ---- Capa 1 ----
kubectl -n gratitud patch svc api --type=merge \
  -p '{"spec":{"selector":{"app.kubernetes.io/instance":"gratitud","tier":"api"}}}'
kubectl -n gratitud patch svc cache --type=json -p='[{"op":"replace","path":"/spec/ports/0/targetPort","value":8080}]'

# ---- Capa 3 ----
kubectl -n gratitud patch deploy api --type=json \
  -p='[{"op":"replace","path":"/spec/template/spec/containers/0/env/0/valueFrom/secretKeyRef/key","value":"PARTNER_TOKEN"}]'
# claimName de la caché (indice 3 con persistence habilitada; si no, 2)
kubectl -n gratitud patch deploy cache --type=json \
  -p='[{"op":"replace","path":"/spec/template/spec/volumes/3/persistentVolumeClaim/claimName","value":"gratitud-uploads"}]'

# ---- Capa 4 ----
kubectl -n gratitud patch deploy portal --type=json \
  -p='[{"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/port","value":8080}]'

# ---- Capa 2 ----
kubectl -n gratitud patch ingress gratitud --type=merge -p '{"spec":{"ingressClassName":"traefik"}}'
kubectl -n gratitud patch ingress gratitud --type=json \
  -p='[{"op":"replace","path":"/spec/tls/0/secretName","value":"gratitud-tls"}]'

# ---- Capa 5 ----
kubectl -n gratitud patch rolebinding gratitud-deployer --type=json \
  -p='[{"op":"replace","path":"/subjects/0/name","value":"gratitud-deployer"}]'
kubectl -n gratitud apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: allow-portal-to-api, namespace: gratitud}
spec:
  podSelector: {matchLabels: {tier: portal}}
  policyTypes: [Egress]
  egress:
    - to: [{podSelector: {matchLabels: {tier: api}}}]
EOF

kubectl -n gratitud rollout status deploy/api
kubectl -n gratitud rollout status deploy/cache
kubectl -n gratitud rollout status deploy/portal
```

Alternativa para los fallos 5–9 y el 3: `helm upgrade gratitud
../CHART/gratitud -n gratitud -f ../CHART/gratitud/values-examen.yaml --set
ingress.className=traefik` reinstala las plantillas correctas de todo lo que
proviene del chart (deja los fallos 1, 2, 7 y 8, que son `kubectl patch`
directos sobre objetos vivos y que hay que corregir a mano).

## Validación

```bash
cd CLASE-15/RECURSOS/SCRIPTS && ./evaluar.sh
# Services   20 / 20
# Ingress    15 / 15
# Config     15 / 15
# Obs        15 / 15
# Seguridad  25 / 25
# Metodo     10 / 10
# TOTAL     100 / 100  -> APROBADO
```

## Error frecuente

* Corregir el fallo 7 (readiness del portal) mirando el Deployment `api` por costumbre.
* "Arreglar" el fallo 8 dando `edit` a la SA en vez de corregir el `subject`.
* Recrear `allow-portal-to-api` con **dos** guiones en el `to` (OR) y abrir de más.
* Reinstalar con `helm upgrade` sin `-f values-examen.yaml` y romper el `storageClassName`.
* Convertir `api` a `NodePort` para "probar" y perder los 10 puntos de método.

## CKA Tip

Ruta del examen: **selector → targetPort → config/PVC → probes → Ingress/TLS →
RBAC/NetPol**, de dentro hacia fuera, verificando cada arreglo.
