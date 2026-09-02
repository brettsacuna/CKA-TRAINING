# SOLUCIÓN — LAB 10.4 · Challenge «el Ingress no enruta»

> **MATERIAL DEL INSTRUCTOR.**

## Los 4 fallos

| # | Campo del Ingress | Fallo | Síntoma | Comando que lo revela |
|---|---|---|---|---|
| 1 | `spec.ingressClassName` | `nginx` (la clase real es `traefik`) | `ADDRESS` vacío; nada responde | `k get ingress` + `k get ingressclass` |
| 2 | `rules[0].http.paths[0].backend.service.port.number` | `8080` (el Service `portal` está en el `80`) | `503` en `/` | `k describe ingress gratitud` + `k get svc portal` |
| 3 | `rules[0].http.paths[1].pathType` | `Exact` (debe ser `Prefix`) | `/api` responde, `/api/health` da `404` | `k get ingress gratitud -o yaml` |
| 4 | `spec.tls[0].secretName` | `gratitud-tls-viejo` (no existe; el bueno es `gratitud-tls`) | HTTPS con el certificado por defecto del controlador | `k get secret` + `curl -kv` |

## Método

Los cuatro dan un síntoma HTTP distinto, así que la clave es no mezclarlos:
primero conseguir `ADDRESS` (fallo 1), luego `/` a `200` (fallo 2), luego
`/api/health` a `200` (fallo 3), y por último el certificado (fallo 4).

## Procedimiento

```bash
cd CLASE-10/RECURSOS/SCRIPTS && ./setup-lab.sh
k -n gratitud-web rollout status deploy/probe

# ---- Fallo 1: ingressClassName ----
k -n gratitud-web get ingress gratitud            # ADDRESS vacio
k get ingressclass                                # la clase real es 'traefik'
k -n gratitud-web patch ingress gratitud --type=merge -p '{"spec":{"ingressClassName":"traefik"}}'
k -n gratitud-web get ingress gratitud -w         # aparece ADDRESS

# ---- Fallo 2: backend puerto ----
TIP=$(k -n ingress get svc traefik -o jsonpath='{.spec.clusterIP}')
k -n gratitud-web exec deploy/probe -- curl -s -o /dev/null -w '%{http_code}\n' -H 'Host: gratitud.example.com' http://$TIP/   # 503
k -n gratitud-web get svc portal -o jsonpath='{.spec.ports[0].port}{"\n"}'   # 80
k -n gratitud-web patch ingress gratitud --type=json \
  -p='[{"op":"replace","path":"/spec/rules/0/http/paths/0/backend/service/port/number","value":80}]'
k -n gratitud-web exec deploy/probe -- curl -s -o /dev/null -w '%{http_code}\n' -H 'Host: gratitud.example.com' http://$TIP/   # 200

# ---- Fallo 3: pathType ----
k -n gratitud-web exec deploy/probe -- curl -s -o /dev/null -w '%{http_code}\n' -H 'Host: gratitud.example.com' http://$TIP/api/health   # 404
k -n gratitud-web get ingress gratitud -o jsonpath='{range .spec.rules[0].http.paths[*]}{.path}={.pathType}{"\n"}{end}'
k -n gratitud-web patch ingress gratitud --type=json \
  -p='[{"op":"replace","path":"/spec/rules/0/http/paths/1/pathType","value":"Prefix"}]'
k -n gratitud-web exec deploy/probe -- curl -s -o /dev/null -w '%{http_code}\n' -H 'Host: gratitud.example.com' http://$TIP/api/health   # 200

# ---- Fallo 4: secretName TLS ----
k -n gratitud-web get ingress gratitud -o jsonpath='{.spec.tls[0].secretName}{"\n"}'   # gratitud-tls-viejo
k -n gratitud-web get secret | grep tls                                               # existe 'gratitud-tls'
k -n gratitud-web patch ingress gratitud --type=json \
  -p='[{"op":"replace","path":"/spec/tls/0/secretName","value":"gratitud-tls"}]'
curl -kv --resolve gratitud.example.com:32443:<IP-NODO> https://gratitud.example.com:32443/ 2>&1 | grep -E 'subject:|issuer:'
# -> subject/issuer con CN=gratitud.example.com
```

## Validación

```bash
cd CLASE-10/RECURSOS/SCRIPTS && ./validate-lab.sh
# LAB 10.4 SUPERADO (11 comprobaciones)

# manual, desde tu equipo
curl -s -o /dev/null -w '%{http_code}\n' --resolve gratitud.example.com:32080:<IP-NODO> http://gratitud.example.com:32080/
curl -s -o /dev/null -w '%{http_code}\n' --resolve gratitud.example.com:32080:<IP-NODO> http://gratitud.example.com:32080/api/health
curl -kv --resolve gratitud.example.com:32443:<IP-NODO> https://gratitud.example.com:32443/ 2>&1 | grep -E 'subject:|issuer:'
```

## Resultado esperado

* El Ingress `gratitud` tiene `ADDRESS`.
* `/` → `200` (portal), `/api` y `/api/health` → `200` (api).
* `https://gratitud.example.com:32443/` presenta el certificado con `CN=gratitud.example.com`, no el del controlador.
* `./validate-lab.sh` termina con `LAB 10.4 SUPERADO`.

## Error frecuente

* Cambiar el `ingressClassName` y no esperar el minuto que tarda el controlador en adoptar el Ingress y publicar `ADDRESS`.
* Interpretar el `503` como "los Pods están caídos". Los Pods están bien; el Ingress apunta a un puerto que el Service no expone.
* Corregir el `pathType` de la ruta equivocada (hay tres paths; `/api` es el índice `1`).
* "Arreglar" el fallo 4 creando un Secret nuevo llamado `gratitud-tls-viejo` en vez de apuntar al que ya existe.
* Probar el HTTPS contra el `32080`.

## CKA Tip

```bash
k get ingress <ing> -o yaml | grep -E 'ingressClassName|host:|path:|pathType:|name:|number:|secretName:'
k describe ingress <ing>                    # Events: clase no encontrada, backend sin resolver...
k get endpointslices -l kubernetes.io/service-name=<svc>
curl -s -o /dev/null -w '%{http_code}\n' -H 'Host: <host>' http://<clusterIP-controlador>/<path>
```

Ruta mental para un Ingress que no enruta:
**clase → backend (Service + puerto) → pathType/path → host + Secret TLS.**
