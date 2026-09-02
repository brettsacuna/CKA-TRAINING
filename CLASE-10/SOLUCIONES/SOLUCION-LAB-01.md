# SOLUCIÓN — LAB 10.1 · Controlador y primer Ingress

> **MATERIAL DEL INSTRUCTOR.**

## Diagnóstico

1. **El objeto Ingress no hace nada por sí mismo.** Es una declaración de reglas. Quien enruta es el controlador, un Deployment aparte.
2. **`ingressClassName` es el pegamento.** Cada controlador adopta los Ingress que nombran su `IngressClass`. Una clase inexistente = Ingress creado sin error y sin `ADDRESS`.
3. **`ADDRESS` vacío tras 1–2 min** es el primer indicador que hay que mirar: o la clase, o el controlador no corre, o hay un evento en el Ingress.

## Procedimiento

```bash
# A - Controlador
cd CLASE-10/RECURSOS/SCRIPTS && ./install-ingress-controller.sh
k get ingressclass
# NAME      CONTROLLER                      DEFAULT
# traefik   traefik.io/ingress-controller   true
k -n ingress get svc traefik           # 80:32080/TCP  443:32443/TCP

# B - App
k create ns c10-basico
k apply -f ../RECURSOS/YAML/01-app-basica.yaml
k -n c10-basico run tmp --rm -it --image=nicolaka/netshoot --restart=Never -- curl -s http://web | head -1

# C - Primer Ingress
k apply -f ../RECURSOS/YAML/02-ingress-basico.yaml
k -n c10-basico get ingress web -w        # esperar a que aparezca ADDRESS
curl -s -o /dev/null -w '%{http_code}\n' \
  --resolve web.example.com:32080:<IP-NODO> http://web.example.com:32080/     # 200

# D - Fallo silencioso
k -n c10-basico patch ingress web --type=merge -p '{"spec":{"ingressClassName":"nginx"}}'
k -n c10-basico get ingress web            # sin error, ADDRESS desaparece
curl -s -m 5 -o /dev/null -w '%{http_code}\n' \
  --resolve web.example.com:32080:<IP-NODO> http://web.example.com:32080/     # 404 / sin respuesta
k -n c10-basico patch ingress web --type=merge -p '{"spec":{"ingressClassName":"traefik"}}'
k -n c10-basico get ingress web            # vuelve el ADDRESS
```

## Validación

```bash
k get ingressclass
k -n c10-basico get ingress web \
  -o jsonpath='{.spec.ingressClassName}{"  ADDRESS="}{.status.loadBalancer.ingress[0].ip}{.status.loadBalancer.ingress[0].hostname}{"\n"}'
curl -s -o /dev/null -w '%{http_code}\n' --resolve web.example.com:32080:<IP-NODO> http://web.example.com:32080/
```

## Resultado esperado

* `IngressClass` `traefik` registrada, marcada `DEFAULT`.
* Con `ingressClassName: traefik`, el Ingress obtiene `ADDRESS` y `curl` → `200`.
* Con `ingressClassName: nginx` (inexistente), el Ingress se edita **sin error**, se queda **sin `ADDRESS`** y `curl` deja de responder.

## Error frecuente

* Esperar que el Ingress funcione sin haber instalado ningún controlador.
* Probar con `curl http://<IP-NODO>:32080/` sin cabecera `Host:`: el controlador no encuentra regla y devuelve `404`. Hay que usar `--resolve` o `-H "Host: web.example.com"`.
* Confundir el `nodePort` del controlador (`32080`) con un `nodePort` de la aplicación. La app no tiene `NodePort`: entra por el controlador.
* Dar por hecho que la `IngressClass` se llama `nginx`. Se llama como la registre el controlador; con Traefik, `traefik`.

## CKA Tip

```bash
k get ingressclass
k get ingress -A
k describe ingress <ing>            # mira los Events al final
k create ingress <n> --class=<c> --rule="host/path=svc:port"
curl --resolve <host>:<port>:<IP> http://<host>:<port>/<path>
```
