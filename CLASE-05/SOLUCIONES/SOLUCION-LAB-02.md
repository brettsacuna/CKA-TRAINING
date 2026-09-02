# SOLUCIÓN — LAB 5.2 · Ingress con HTTP y HTTPS

> **MATERIAL DEL INSTRUCTOR.**

## Diagnóstico

El error número uno es escribir un Ingress perfecto **sin haber comprobado antes los Services**. Si `service1` no tiene endpoints, el Ingress devolverá 503 y el alumno pasará veinte minutos revisando el Ingress. De ahí el paso 7 obligatorio.

El segundo error es el `ingressClassName`: si no coincide con ninguna `IngressClass` registrada, ningún controlador adopta el Ingress, `ADDRESS` queda vacío y no hay ningún mensaje de error.

## Razonamiento técnico resumido

```
CLIENTE -> INGRESS CONTROLLER (proxy L7) -> SERVICE -> ENDPOINTSLICE -> POD
```

* El **Ingress** es solo una declaración. Sin un **Ingress Controller** que la lea, no hace nada.
* El controlador termina el TLS: el certificado se presenta en el borde, y del controlador al Pod el tráfico va en claro (salvo mTLS).
* El Secret TLS debe estar **en el mismo namespace** que el Ingress.
* `pathType`: `Prefix` (por segmentos), `Exact` (literal), `ImplementationSpecific`.

### Contexto 2026

`kubernetes/ingress-nginx` fue retirado en marzo de 2026: repositorio archivado, sin parches de seguridad. La recomendación del proyecto es migrar a **Gateway API** o a un controlador mantenido. La **API Ingress no está deprecada** y sigue en el examen; lo retirado es una implementación concreta. Presenta ambos: Ingress para el examen y el día a día, Gateway API como dirección del ecosistema (`RECURSOS/YAML/04-gateway-api.yaml`).

## Procedimiento

```bash
# 1-3
../RECURSOS/SCRIPTS/install-ingress-controller.sh
k get ingressclass                       # -> traefik
k -n ingress get svc traefik             # 80:32080/TCP  443:32443/TCP

# 4-6
k create ns c5-ingress && k config set-context --current --namespace=c5-ingress
k run pod1 --image=nginx:1.27-alpine
k run pod2 --image=httpd:2.4-alpine
k expose pod pod1 --name=service1 --port=80
k expose pod pod2 --name=service2 --port=80

# 7  VERIFICAR ANTES DEL INGRESS
k get endpointslices
k run tmp --rm -it --image=busybox:1.36 --restart=Never -- \
  sh -c 'wget -qO- http://service1; wget -qO- http://service2'

# 8-10
k apply -f ../RECURSOS/YAML/02-ingress-http.yaml
k get ingress
curl http://<IP-NODO>:32080/service1
curl http://<IP-NODO>:32080/service2
```

**11 — Reescritura de path.** Es específica de cada controlador. Con Traefik se hace con un `Middleware`:

```bash
k apply -f - <<'YAML'
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata: {name: strip, namespace: c5-ingress}
spec:
  stripPrefix:
    prefixes: ["/service1", "/service2"]
YAML
k annotate ingress app-ingress \
  traefik.ingress.kubernetes.io/router.middlewares=c5-ingress-strip@kubernetescrd
```

Con ingress-nginx el equivalente era `nginx.ingress.kubernetes.io/rewrite-target: /`. Buen momento para señalar que **las anotaciones no son portables entre controladores**, y que ese fue uno de los motivos de la retirada de ingress-nginx: la configuración arbitraria por anotaciones se volvió inmanejable y insegura. Gateway API resuelve esto con filtros tipados (`URLRewrite`).

```bash
# 12-13
../RECURSOS/SCRIPTS/gen-tls-secret.sh
k get secret secure-ingress -o jsonpath='{.type}{"\n"}'    # kubernetes.io/tls

# 14
k apply -f ../RECURSOS/YAML/03-ingress-tls.yaml

# 15-16
curl -kv https://secure-ingress.com:32443/service2 \
  --resolve secure-ingress.com:32443:<IP-NODO>
```

Salida relevante:

```
* Server certificate:
*  subject: C=PE; ST=LIMA; O=CKA-TRAINING; CN=secure-ingress.com
*  issuer:  C=PE; ST=LIMA; O=CKA-TRAINING; CN=secure-ingress.com
* SSL connection using TLSv1.3 / TLS_AES_256_GCM_SHA384
< HTTP/2 200
<html><body><h1>It works!</h1></body></html>
```

## Validación

```bash
k get ingress app-ingress -o wide
curl -s -o /dev/null -w '%{http_code}\n' http://<IP-NODO>:32080/service1
curl -sk -o /dev/null -w '%{http_code}\n' https://secure-ingress.com:32443/service2 \
  --resolve secure-ingress.com:32443:<IP-NODO>
```

## Error frecuente

| Error | Síntoma | Corrección |
|---|---|---|
| `ingressClassName` inexistente | `ADDRESS` vacío, sin errores | `k get ingressclass` y usar ese nombre |
| Secret TLS en otro namespace | Se presenta el certificado por defecto del controlador | El Secret va en el namespace del Ingress |
| Secret creado como `Opaque` | El Ingress no lo usa | `k create secret tls` (tipo `kubernetes.io/tls`) |
| Falta `host:` en la regla | El TLS no se aplica a la ruta | Añadir `host` a la regla y a `tls.hosts` |
| Services sin endpoints | 503 desde el Ingress | Verificar los Services **antes** |
| `curl` sin `--resolve` | No resuelve `secure-ingress.com` | `--resolve host:puerto:IP` |
| Copiar anotaciones de ingress-nginx a otro controlador | Se ignoran silenciosamente | Usar las del controlador instalado |

## CKA Tip

```bash
# Ingress imperativo (existe desde hace varias versiones y ahorra mucho tiempo)
k create ingress app-ingress --class=traefik \
  --rule="/service1=service1:80" \
  --rule="/service2=service2:80"

# Con host y TLS
k create ingress secure --class=traefik \
  --rule="secure-ingress.com/service1=service1:80,tls=secure-ingress"

k create secret tls secure-ingress --cert=cert.pem --key=key.pem
k describe ingress <ing>          # muestra las reglas y los backends resueltos
```

**Orden de diagnóstico:** Pod → Service → EndpointSlice → Ingress → Controlador. Nunca al revés.
