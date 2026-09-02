# LAB 10.1 — Controlador y primer Ingress

## Nivel

Básico.

## Duración

22 minutos.

## Objetivo

Instalar un Ingress Controller mantenido, publicar una aplicación con un Ingress
de un host y un path, y comprobar con tus propias manos que **sin controlador, o
con una clase inexistente, un Ingress no hace nada**.

## Competencias

* Instalar un Ingress Controller y localizar su `IngressClass` y sus puertos.
* Escribir un Ingress mínimo (`rules`, `host`, `http.paths`, `pathType`, `backend.service`).
* Probar una ruta desde fuera con `curl --resolve`.
* Reconocer el síntoma de `ingressClassName` incorrecto: `ADDRESS` vacío, sin error.

## Escenario

Tienes la aplicación `web` corriendo y expuesta por `NodePort`. Vas a ponerle un
Ingress por delante para dejar de depender de puertos altos y preparar el terreno
para servir varias aplicaciones por el 80/443.

## Estado inicial

* Namespace de trabajo: **`c10-basico`**.
* `helm` disponible en tu equipo.
* Necesitas la IP de un nodo accesible desde tu máquina.

## Requerimientos

### Parte A — El controlador

1. Instala Traefik con el script de apoyo:
   ```bash
   cd CLASE-10/RECURSOS/SCRIPTS && ./install-ingress-controller.sh
   ```
2. Comprueba qué `IngressClass` quedó registrada y **anota su nombre**:
   ```bash
   kubectl get ingressclass
   ```
3. Localiza el Service del controlador y anota sus `nodePort` de HTTP y HTTPS:
   ```bash
   kubectl -n ingress get svc traefik
   ```
   (con el script serán `32080` y `32443`).

### Parte B — La aplicación y su Service

4. Crea el namespace `c10-basico` y aplica la aplicación:
   ```bash
   kubectl apply -f ../RECURSOS/YAML/01-app-basica.yaml
   ```
   Contiene un Deployment `web` (2 réplicas de `nginx:1.27-alpine`, `app=web`) y un Service `web` `ClusterIP` en el 80.
5. **Verifica el Service antes de tocar el Ingress**. Si esto falla, el Ingress también:
   ```bash
   kubectl -n c10-basico run tmp --rm -it --image=nicolaka/netshoot --restart=Never -- curl -s http://web
   ```

### Parte C — El primer Ingress

6. Aplica un Ingress de un host y un path:
   ```bash
   kubectl apply -f ../RECURSOS/YAML/02-ingress-basico.yaml
   ```
   Enruta `web.example.com/` → Service `web:80` con `ingressClassName` = el que anotaste.
7. Espera a que el Ingress obtenga `ADDRESS` (puede tardar 1–2 min):
   ```bash
   kubectl -n c10-basico get ingress -w
   ```
8. Prueba desde fuera, sin tocar tu `/etc/hosts`:
   ```bash
   curl -s -o /dev/null -w '%{http_code}\n' \
     --resolve web.example.com:32080:<IP-NODO> \
     http://web.example.com:32080/
   ```

### Parte D — El fallo silencioso

9. Edita el Ingress y ponle un `ingressClassName` que **no existe** (por ejemplo `nginx`):
   ```bash
   kubectl -n c10-basico patch ingress web --type=merge -p '{"spec":{"ingressClassName":"nginx"}}'
   ```
10. Espera 1 min y vuelve a mirar `kubectl get ingress`. Observa que:
    * **no hay ningún error**,
    * el `ADDRESS` desaparece o nunca aparece,
    * `curl` deja de responder.
11. Devuelve el `ingressClassName` correcto y comprueba que vuelve a funcionar.

### Parte E — Comparación

12. Anota la diferencia entre los dos accesos a la misma aplicación:
    * `NodePort` directo: `http://<IP-NODO>:<nodePort-de-web>` (si expusiste `web` como NodePort) o el `curl` interno del paso 5.
    * Ingress: `http://web.example.com:32080/` — un solo puerto para, en el próximo lab, muchas aplicaciones.

## Restricciones

* No borres el controlador al terminar: se reutiliza en los LAB 10.2–10.4.
* No uses anotaciones propietarias del controlador en este laboratorio.

## Validación

```bash
kubectl get ingressclass
kubectl -n c10-basico get ingress web -o jsonpath='{.spec.ingressClassName}{"  ADDRESS="}{.status.loadBalancer.ingress[0].ip}{.status.loadBalancer.ingress[0].hostname}{"\n"}'
kubectl -n c10-basico describe ingress web
curl -s -o /dev/null -w '%{http_code}\n' --resolve web.example.com:32080:<IP-NODO> http://web.example.com:32080/
```

## Resultado esperado

* `kubectl get ingressclass` muestra una clase (p. ej. `traefik`) con su controlador.
* Con el `ingressClassName` correcto, el Ingress tiene `ADDRESS` y `curl` devuelve `200`.
* Con un `ingressClassName` inexistente, el Ingress se crea/edita **sin error**, se queda **sin `ADDRESS`** y `curl` no responde.
* La misma aplicación es accesible por el Ingress en el puerto `32080` con la cabecera `Host: web.example.com`.

## Criterios de éxito

- [ ] Instalé el Ingress Controller y anoté su `IngressClass` y sus `nodePort`.
- [ ] Verifiqué el Service `web` **antes** de crear el Ingress.
- [ ] Creé un Ingress de un host y un path y obtuvo `ADDRESS`.
- [ ] Probé la ruta desde fuera con `curl --resolve`.
- [ ] Vi el `ADDRESS` vacío al poner un `ingressClassName` inexistente, sin ningún error.
- [ ] Restauré la clase correcta y volvió a funcionar.
- [ ] Sé enunciar qué aporta el Ingress frente al `NodePort` directo.
