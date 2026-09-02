# SOLUCIÓN — LAB 10.2 · Enrutar GRATITUD por host y por path

> **MATERIAL DEL INSTRUCTOR.**

## Diagnóstico

1. **Un Ingress solo referencia Services de su propio namespace.** Por eso los cuatro frentes van en `gratitud-web`. En producción cada equipo tiene su Ingress con el mismo host y su path; el controlador los combina (ver más abajo).
2. **`pathType` importa.** `Prefix` encaja el path y todo lo que cuelga; `Exact` solo el path idéntico. `Exact` en `/api` deja `/api/health` en `404`.
3. **El backend recibe el path tal cual.** `/api` llega como `/api` al Pod `api`. Para que reciba `/` hace falta reescritura, que es una **anotación propietaria** del controlador.

## Procedimiento

```bash
k apply -f ../RECURSOS/YAML/03-gratitud-web.yaml
k -n gratitud-web rollout status deploy/portal
for d in portal docs panel; do
  for p in $(k -n gratitud-web get pod -l app=gratitud-$d -o name); do
    k -n gratitud-web exec "${p#pod/}" -- sh -c "echo '$d' > /usr/share/nginx/html/index.html"
  done
done
# verificar los 4 Services antes del Ingress
k -n gratitud-web run tmp --rm -it --image=nicolaka/netshoot --restart=Never -- \
  sh -c 'for s in portal api docs panel; do echo -n "$s: "; curl -s -o /dev/null -w "%{http_code}\n" http://$s; done'

# B - Ingress host + path (incluye el Middleware de rewrite de Traefik)
k apply -f ../RECURSOS/YAML/04-ingress-host-path.yaml
k -n gratitud-web get ingress gratitud -w        # esperar ADDRESS

for p in / /api /api/health /docs; do
  curl -s -o /dev/null -w "%{http_code}  $p\n" \
    --resolve gratitud.example.com:32080:<IP-NODO> http://gratitud.example.com:32080$p
done
curl -s --resolve admin.gratitud.example.com:32080:<IP-NODO> http://admin.gratitud.example.com:32080/

# C - Prefix vs Exact
k -n gratitud-web patch ingress gratitud --type=json \
  -p='[{"op":"replace","path":"/spec/rules/0/http/paths/1/pathType","value":"Exact"}]'
curl -s -o /dev/null -w '%{http_code} /api\n'        --resolve gratitud.example.com:32080:<IP-NODO> http://gratitud.example.com:32080/api
curl -s -o /dev/null -w '%{http_code} /api/health\n' --resolve gratitud.example.com:32080:<IP-NODO> http://gratitud.example.com:32080/api/health   # 404
k -n gratitud-web patch ingress gratitud --type=json \
  -p='[{"op":"replace","path":"/spec/rules/0/http/paths/1/pathType","value":"Prefix"}]'

# D - Rewrite
k -n gratitud-web logs deploy/api | tail -3          # con rewrite se ve "/", sin rewrite se ve "/api"
```

## El path recibido y la reescritura

Sin reescritura, un `curl .../api` deja en los logs de `api` la línea
`"GET /api HTTP/1.1"`. La aplicación real respondería `404` porque no tiene una
ruta `/api`. Con el `Middleware` `stripPrefix` de Traefik (referenciado por la
anotación `traefik.io/router.middlewares`), el backend recibe `"GET / HTTP/1.1"`.

Con **otro controlador** la anotación cambia (por ejemplo, `ingress-nginx` usaba
`nginx.ingress.kubernetes.io/rewrite-target`). Ese es exactamente el motivo por
el que las anotaciones no son portables y por el que existe Gateway API.

## Alternativa de producción: un Ingress por equipo

En vez de un Ingress con todos los paths, cada namespace tiene el suyo con el
mismo `host` y su path; el controlador los fusiona:

```yaml
# en gratitud-api
kind: Ingress
metadata: {name: gratitud-api, namespace: gratitud-api}
spec:
  ingressClassName: traefik
  rules:
    - host: gratitud.example.com
      http: {paths: [{path: /api, pathType: Prefix, backend: {service: {name: api, port: {number: 80}}}}]}
```

Así cada equipo despliega su ruta sin tocar el Ingress de los demás. El coste es
que la vista completa del routing queda repartida en varios objetos.

## Validación

```bash
k -n gratitud-web get ingress gratitud -o wide
k -n gratitud-web describe ingress gratitud
for p in / /api /api/health /docs; do
  curl -s -o /dev/null -w "%{http_code}  $p\n" --resolve gratitud.example.com:32080:<IP-NODO> http://gratitud.example.com:32080$p
done
```

## Resultado esperado

* `/` → `portal`, `/docs` → `docs`, `admin…/` → `panel`; con `Prefix`, `/api` y `/api/health` → `api`.
* Con `pathType: Exact` en `/api`, `/api/health` → `404`.
* Tras la reescritura, los logs de `api` muestran `/`, no `/api`.
* Un único objeto Ingress `gratitud` con dos hosts y cuatro paths.

## Error frecuente

* Poner los Services en namespaces distintos y que el Ingress no los encuentre (`backend` en otro namespace → el controlador no lo resuelve).
* Elegir `Exact` "porque es más estricto" y romper todas las subrutas.
* Esperar que el backend reciba `/` sin haber configurado el rewrite.
* Copiar una anotación de rewrite de `ingress-nginx` a Traefik. No la entiende.

## CKA Tip

```bash
k create ingress gratitud -n gratitud-web --class=traefik \
  --rule="gratitud.example.com/=portal:80" \
  --rule="gratitud.example.com/api*=api:80" \
  --rule="admin.gratitud.example.com/=panel:80"
k get ingress -n gratitud-web -o yaml | grep -E 'host:|path:|pathType:|name:|number:'
```
