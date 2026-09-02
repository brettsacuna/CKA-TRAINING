# LAB 5.2 — Ingress con HTTP, HTTPS y routing por path

## Nivel

Intermedio.

## Duración

35 minutos.

## Objetivo

Publicar dos aplicaciones distintas detrás de una sola entrada, enrutando por path, y añadir HTTPS con un certificado propio.

## Competencias

* Instalar un Ingress Controller mantenido.
* Escribir un Ingress con reglas por path y `pathType`.
* Generar un certificado X.509 y crear un Secret `kubernetes.io/tls`.
* Asociar el certificado al Ingress por host.
* Probar con `curl --resolve`.

## Escenario

Reproduces el escenario clásico del curso: `/service1` debe llegar a una aplicación nginx y `/service2` a una aplicación httpd, ambas por el mismo punto de entrada, primero en HTTP y después en HTTPS con el host `secure-ingress.com`.

> **Contexto técnico.** El controlador comunitario `ingress-nginx` fue retirado en marzo de 2026 y ya no recibe parches. Este laboratorio usa **Traefik**, que está mantenido y soporta la API Ingress estándar. Los manifiestos Ingress que escribas son los mismos: solo cambia el `ingressClassName`.

## Estado inicial

* Namespace de trabajo: **`c5-ingress`**.
* Sin Ingress Controller instalado (o con uno que puedas identificar con `kubectl get ingressclass`).
* Necesitas la IP de un nodo accesible desde tu equipo.

## Requerimientos

### Parte A — Controlador

1. Instala un Ingress Controller con el script de apoyo:
   ```bash
   cd CLASE-05/RECURSOS/SCRIPTS && ./install-ingress-controller.sh
   ```
2. Comprueba qué `IngressClass` quedó registrada y anota su nombre.
3. Localiza el Service del controlador y anota los `nodePort` de HTTP y HTTPS.

### Parte B — Aplicaciones y Services

4. Crea el namespace `c5-ingress`.
5. Crea el Pod **`pod1`** con `nginx:1.27-alpine` y el Pod **`pod2`** con `httpd:2.4-alpine`.
6. Expón `pod1` con un Service **`service1`** en el puerto 80, y `pod2` con **`service2`** en el puerto 80.
7. Verifica ambos Services desde un Pod temporal antes de tocar el Ingress. **Si esto no funciona, el Ingress tampoco lo hará.**

### Parte C — Ingress HTTP

8. Crea un Ingress **`app-ingress`** con:
   * `ingressClassName` el que anotaste,
   * regla `path: /service1` → `service1:80`,
   * regla `path: /service2` → `service2:80`,
   * `pathType: Prefix` en ambos.
9. Comprueba con `kubectl get ingress` que obtiene una dirección.
10. Prueba desde fuera:
    ```bash
    curl http://<IP-NODO>:<nodePort-http>/service1
    curl http://<IP-NODO>:<nodePort-http>/service2
    ```
11. Investiga: la aplicación recibe la petición con el path `/service1` incluido. Averigua cómo hacer que el backend reciba `/` en su lugar (reescritura de path) y aplícalo.

### Parte D — HTTPS

12. Genera un certificado autofirmado para el `Common Name` **`secure-ingress.com`**, válido 3650 días:
    ```bash
    cd CLASE-05/RECURSOS/SCRIPTS && ./gen-tls-secret.sh
    ```
    o hazlo a mano con `openssl req -x509 -newkey rsa:4096 ...`.
13. Crea un Secret de tipo **`kubernetes.io/tls`** llamado **`secure-ingress`** con ese certificado y su clave.
14. Modifica `app-ingress` para:
    * añadir la sección `tls` con el host `secure-ingress.com` y el Secret,
    * añadir `host: secure-ingress.com` a la regla.
15. Prueba HTTPS sin tocar tu `/etc/hosts`:
    ```bash
    curl -kv https://secure-ingress.com:<nodePort-https>/service2 \
      --resolve secure-ingress.com:<nodePort-https>:<IP-NODO>
    ```
16. En la salida verbose, localiza y anota:
    * el `subject` y el `issuer` del certificado presentado,
    * la versión de TLS negociada,
    * el código de estado HTTP.

## Restricciones

* No uses `ingress-nginx` de la comunidad como controlador principal (está retirado).
* El certificado debe tener `CN=secure-ingress.com`.
* No modifiques `/etc/hosts`: usa `curl --resolve`.
* Los Services deben seguir siendo `ClusterIP`: la única entrada desde fuera es el controlador.

## Validación

```bash
kubectl get ingressclass
kubectl -n c5-ingress get pods,svc,ingress
kubectl -n c5-ingress describe ingress app-ingress
kubectl -n c5-ingress get secret secure-ingress -o jsonpath='{.type}{"\n"}'   # kubernetes.io/tls
curl -s -o /dev/null -w '%{http_code}\n' http://<IP-NODO>:<np-http>/service1
curl -sk -o /dev/null -w '%{http_code}\n' https://secure-ingress.com:<np-https>/service2 \
  --resolve secure-ingress.com:<np-https>:<IP-NODO>
```

## Resultado esperado

* `/service1` devuelve la página de bienvenida de nginx.
* `/service2` devuelve `<html><body><h1>It works!</h1></body></html>`.
* En HTTPS, el certificado presentado tiene `CN=secure-ingress.com` (no el certificado por defecto del controlador) y la respuesta es `200`.

## Criterios de éxito

- [ ] Ingress Controller instalado y su `IngressClass` identificada.
- [ ] `service1` y `service2` verificados **antes** de crear el Ingress.
- [ ] Ingress con dos reglas de path y `pathType: Prefix`.
- [ ] Ambos paths responden por HTTP.
- [ ] Implementé la reescritura de path y comprobé el efecto.
- [ ] Certificado generado con `CN=secure-ingress.com`.
- [ ] Secret de tipo `kubernetes.io/tls` creado.
- [ ] El Ingress presenta mi certificado, no el del controlador.
- [ ] HTTPS devuelve 200 usando `curl --resolve`.
- [ ] Anoté subject, issuer, versión TLS y código HTTP.
