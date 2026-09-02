# LAB 11.2 — Cablear la configuración de GRATITUD

## Nivel

Intermedio.

## Duración

32 minutos.

## Objetivo

Externalizar **toda** la configuración de la API de GRATITUD: un ConfigMap con
valores y con un fichero, dos Secrets, e inyección combinada por `envFrom`,
`valueFrom` y volumen. Comprobar cómo se propaga (o no) un cambio.

## Competencias

* Combinar `envFrom` (todas las claves) y `env`/`valueFrom` (una clave) en un mismo contenedor.
* Guardar un fichero de configuración como clave de un ConfigMap y montarlo con `subPath`.
* Provocar y explicar la no-propagación de un cambio inyectado por `env`.
* Marcar un ConfigMap como `immutable` y ver qué deja de permitir el API server.

## Escenario

La imagen de `api` no debe llevar ninguna configuración dentro. Todo —nivel de
log, flags, URL de la caché, credenciales de BD y tokens de socio— entra en
tiempo de ejecución desde objetos de Kubernetes.

## Estado inicial

* Namespace de trabajo: **`gratitud-api`**.

## Requerimientos

### Parte A — Los objetos de configuración

1. Crea el namespace `gratitud-api` y aplica los objetos:
   ```bash
   kubectl apply -f ../RECURSOS/YAML/02-gratitud-config.yaml
   ```
   Contiene:
   * `gratitud-config` (ConfigMap): `LOG_LEVEL=info`, `FEATURE_GRATITUD_V2=true`, `UPSTREAM_CACHE=http://cache.gratitud-datos`, y la clave `app.conf` (fichero multilínea).
   * `gratitud-db` (Secret): `DB_USER`, `DB_PASSWORD`, `DB_HOST`.
   * `gratitud-api-tokens` (Secret): `PARTNER_TOKEN`, `WEBHOOK_SIGNING_KEY`.
2. Verifica el fichero embebido: `kubectl get cm gratitud-config -o jsonpath='{.data.app\.conf}'`.

### Parte B — La inyección

3. Crea el Deployment `api` (imagen `nginxinc/nginx-unprivileged:1.27-alpine`) con las **tres** formas:
   * `envFrom`: todas las claves de `gratitud-config` **y** de `gratitud-db`.
   * `env` + `valueFrom`: `PARTNER_TOKEN` desde `gratitud-api-tokens`.
   * volumen `configMap` que monte **solo** `app.conf` en `/etc/gratitud/app.conf` con `subPath`.

   Puedes partir de `../RECURSOS/YAML/03-gratitud-api-deploy.yaml`.
4. Comprueba dentro del Pod:
   ```bash
   kubectl -n gratitud-api exec deploy/api -- printenv | grep -E 'LOG_LEVEL|FEATURE_|UPSTREAM_|DB_|PARTNER_TOKEN'
   kubectl -n gratitud-api exec deploy/api -- cat /etc/gratitud/app.conf
   kubectl -n gratitud-api exec deploy/api -- ls -l /etc/gratitud
   ```
   Fíjate en que `/etc/gratitud` conserva lo que ya hubiera (por el `subPath`), no solo `app.conf`.

### Parte C — Propagación

5. Cambia `LOG_LEVEL` a `debug` en `gratitud-config` (`kubectl edit configmap`).
6. Comprueba que `printenv LOG_LEVEL` en el Pod **sigue** en `info`.
7. Fuerza la recogida del cambio:
   ```bash
   kubectl -n gratitud-api rollout restart deploy/api
   kubectl -n gratitud-api rollout status deploy/api
   kubectl -n gratitud-api exec deploy/api -- printenv LOG_LEVEL   # debug
   ```
8. Cambia ahora una línea dentro de `app.conf` en el ConfigMap. Como se montó con `subPath`, el fichero del Pod **no** cambia aunque esperes. Anótalo.

### Parte D — Inmutabilidad

9. Añade `immutable: true` a `gratitud-config` con `kubectl patch` o `kubectl apply`.
10. Intenta editar cualquier clave (`kubectl edit configmap gratitud-config`). El API server lo **rechaza**.
11. Explica cómo se cambia entonces un ConfigMap inmutable y para qué sirve marcarlo así.

## Restricciones

* Un solo Deployment `api`. Nada de configuración dentro de la imagen.
* No uses `optional: true`.
* El `app.conf` debe montarse con `subPath` (no debe ocultar `/etc/gratitud`).

## Validación

```bash
kubectl -n gratitud-api get cm,secret
kubectl -n gratitud-api get cm gratitud-config -o jsonpath='{.immutable}{"\n"}'
kubectl -n gratitud-api exec deploy/api -- printenv | grep -E 'LOG_LEVEL|DB_PASSWORD|PARTNER_TOKEN'
kubectl -n gratitud-api exec deploy/api -- cat /etc/gratitud/app.conf
```

## Resultado esperado

* En el Pod: `LOG_LEVEL`, `FEATURE_GRATITUD_V2`, `UPSTREAM_CACHE`, `DB_USER`, `DB_PASSWORD`, `DB_HOST` y `PARTNER_TOKEN` como variables de entorno.
* `/etc/gratitud/app.conf` con el contenido de la clave del ConfigMap; el resto de `/etc/gratitud` intacto.
* Editar `LOG_LEVEL` no cambia la env var hasta un `rollout restart`.
* Con `subPath`, el cambio de `app.conf` no llega al Pod.
* Con `immutable: true`, el API server rechaza editar `gratitud-config`.

## Criterios de éxito

- [ ] `gratitud-config`, `gratitud-db` y `gratitud-api-tokens` creados, con `app.conf` embebido.
- [ ] El Deployment `api` inyecta por `envFrom`, `valueFrom` y volumen a la vez.
- [ ] `app.conf` montado con `subPath` sin ocultar `/etc/gratitud`.
- [ ] Reproduje la no-propagación por `env` y la resolví con `rollout restart`.
- [ ] Comprobé que `subPath` no recibe la actualización.
- [ ] Marqué el ConfigMap como `immutable` y sé cómo cambiarlo después.
