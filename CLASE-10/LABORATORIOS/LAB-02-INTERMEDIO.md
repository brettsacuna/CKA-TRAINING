# LAB 10.2 — Enrutar GRATITUD por host y por path

## Nivel

Intermedio.

## Duración

32 minutos.

## Objetivo

Publicar el portal, la API, la documentación y el panel de administración de
GRATITUD tras un **único Ingress**, combinando reglas por **host** y por **path**,
y entender el efecto de `pathType` y de la reescritura de path.

## Competencias

* Escribir un Ingress con varias reglas por host y varios paths por host.
* Elegir `pathType` (`Prefix` vs. `Exact`) y ver la diferencia en `/api/algo`.
* Aplicar reescritura de path con una anotación del controlador.
* Verificar cada ruta con `curl --resolve`.

## Escenario

GRATITUD ya no es una sola página. Hay cuatro frentes web y todos deben servirse
por el 80/443 detrás del controlador que instalaste en el LAB 10.1:

| Ruta pública | Va a |
|---|---|
| `gratitud.example.com/` | `portal` |
| `gratitud.example.com/api` | `api` (el backend debe recibir `/`, no `/api`) |
| `gratitud.example.com/docs` | `docs` |
| `admin.gratitud.example.com/` | `panel` |

## Estado inicial

* Namespace de trabajo: **`gratitud-web`**.
* Ingress Controller del LAB 10.1 instalado (`kubectl get ingressclass`).
* IP de un nodo accesible desde tu equipo.

## Requerimientos

### Parte A — Las aplicaciones

1. Crea el namespace `gratitud-web` y despliega los cuatro frentes con sus Services:
   ```bash
   kubectl apply -f ../RECURSOS/YAML/03-gratitud-web.yaml
   ```
   Incluye `portal`, `api` (escucha en **8080**), `docs` y `panel`, cada uno con su Service `ClusterIP`.
2. Personaliza el `index.html` de cada aplicación para que devuelva su nombre, y así distinguir las rutas:
   ```bash
   for d in portal docs panel; do
     for p in $(kubectl -n gratitud-web get pod -l app=gratitud-$d -o name); do
       kubectl -n gratitud-web exec "${p#pod/}" -- sh -c "echo '$d' > /usr/share/nginx/html/index.html"
     done
   done
   ```
3. **Verifica los cuatro Services** desde un Pod temporal **antes** de crear el Ingress.

### Parte B — Ingress por host y por path

4. Crea un Ingress **`gratitud`** con:
   * `ingressClassName` el de tu controlador,
   * regla `host: gratitud.example.com` con tres paths `Prefix`: `/` → `portal:80`, `/api` → `api:80`, `/docs` → `docs:80`,
   * regla `host: admin.gratitud.example.com` con un path `/` → `panel:80`.

   Puedes partir de `../RECURSOS/YAML/04-ingress-host-path.yaml`.
5. Espera a que el Ingress obtenga `ADDRESS`.
6. Prueba las cuatro rutas desde fuera:
   ```bash
   for p in / /api /docs; do
     curl -s -o /dev/null -w "%{http_code}  $p\n" \
       --resolve gratitud.example.com:32080:<IP-NODO> \
       http://gratitud.example.com:32080$p
   done
   curl -s -o /dev/null -w '%{http_code}  admin\n' \
     --resolve admin.gratitud.example.com:32080:<IP-NODO> \
     http://admin.gratitud.example.com:32080/
   ```

### Parte C — `pathType`: Prefix frente a Exact

7. Cambia el `pathType` de la regla `/api` a `Exact`.
8. Prueba `http://gratitud.example.com:32080/api` y luego `http://gratitud.example.com:32080/api/health`. Explica por qué el segundo devuelve `404`.
9. Devuelve el `pathType` a `Prefix` y comprueba que `/api/health` vuelve a enrutar.

### Parte D — Reescritura de path

10. Observa qué path recibe la API: hazle un `curl` a `/api` y mira en los logs del Pod `api` la ruta solicitada (`kubectl -n gratitud-web logs deploy/api`). Verás `/api`, no `/`.
11. Añade la reescritura de path propia de tu controlador para que el backend `api` reciba `/` en lugar de `/api`.
    * En **Traefik** se hace con un `Middleware` (`traefik.io/v1alpha1`, `spec.replacePathRegex` o `stripPrefix`) referenciado por anotación:
      ```yaml
      apiVersion: traefik.io/v1alpha1
      kind: Middleware
      metadata: {name: strip-api, namespace: gratitud-web}
      spec:
        stripPrefix:
          prefixes: ["/api"]
      ```
      y en el Ingress: `annotations: {traefik.io/router.middlewares: "gratitud-web-strip-api@kubernetescrd"}`.
12. Repite el `curl` a `/api` y confirma en los logs de `api` que ahora recibe `/`.

## Restricciones

* Un **solo** objeto Ingress para las cuatro rutas.
* No expongas ninguna de las cuatro aplicaciones por `NodePort`: la única entrada es el controlador.
* No uses `defaultBackend` para tapar un `pathType` mal elegido.

## Validación

```bash
kubectl -n gratitud-web get ingress gratitud -o wide
kubectl -n gratitud-web describe ingress gratitud
kubectl -n gratitud-web get svc,endpointslices
for p in / /api /api/health /docs; do
  curl -s -o /dev/null -w "%{http_code}  $p\n" --resolve gratitud.example.com:32080:<IP-NODO> http://gratitud.example.com:32080$p
done
curl -s --resolve admin.gratitud.example.com:32080:<IP-NODO> http://admin.gratitud.example.com:32080/
kubectl -n gratitud-web logs deploy/api | tail -5
```

## Resultado esperado

* `/` → `portal`, `/docs` → `docs`, `admin…/` → `panel`, todos `200` con la página que los identifica.
* Con `pathType: Prefix`, `/api` y `/api/health` enrutan a `api`; con `Exact`, `/api/health` da `404`.
* Tras la reescritura, los logs de `api` muestran que recibe `/`, no `/api`.
* Un único Ingress `gratitud` con dos reglas de host y cuatro paths en total.

## Criterios de éxito

- [ ] Verifiqué los cuatro Services antes de crear el Ingress.
- [ ] Un solo Ingress enruta por host y por path a las cuatro aplicaciones.
- [ ] Todas las rutas responden `200` desde fuera con `curl --resolve`.
- [ ] Reproduje y expliqué la diferencia entre `pathType: Prefix` y `Exact`.
- [ ] Apliqué reescritura de path y lo confirmé en los logs del backend.
- [ ] No expuse ninguna aplicación por `NodePort`.
