# LAB 1.1 — Pods, YAML e inspección

## Nivel

Básico.

## Duración

25 minutos.

## Objetivo

Crear Pods por la vía imperativa y por la vía declarativa, generar manifiestos sin copiarlos de la documentación e inspeccionar un Pod hasta entender por qué está o no está corriendo.

## Competencias

* Crear Pods con `kubectl run` y con manifiestos YAML.
* Generar YAML con `--dry-run=client -o yaml`.
* Consultar la especificación de un objeto con `kubectl explain`.
* Leer `describe`, `logs` y `events`.
* Etiquetar y filtrar objetos por label.

## Escenario

Eres el nuevo administrador de un cluster de desarrollo. Antes de tocar nada en producción, necesitas soltura absoluta con la unidad mínima de despliegue: el Pod.

## Estado inicial

* Cluster: `cka-master` + al menos un worker, todos `Ready`.
* Context activo: el del cluster de laboratorio (`kubectl config current-context`).
* Namespace de trabajo: **`c1-basico`** (lo creas tú en el paso 1).
* No hay recursos previos.

## Requerimientos

1. Prepara tu shell con `alias k=kubectl` y `export do='--dry-run=client -o yaml'`.
2. Crea el namespace **`c1-basico`**.
3. Crea, de forma **imperativa**, un Pod llamado **`web`** con la imagen `nginx:1.27-alpine` en ese namespace.
4. Verifica en qué nodo quedó ubicado y cuál es su IP de Pod.
5. Genera, **sin escribir YAML a mano**, el manifiesto de un Pod llamado **`api`** con imagen `httpd:2.4-alpine`, guárdalo en `api.yaml`, y **antes de aplicarlo** añádele:
   * el label `app: api`
   * el label `tier: backend`
   * el puerto de contenedor `80` con nombre `http`
6. Aplica `api.yaml` y comprueba que el Pod está `Running`.
7. Usa `kubectl explain` para averiguar qué campo de `pod.spec` define el tiempo de gracia al terminar el Pod, y cuál es su valor por defecto.
8. Muestra los logs del Pod `api` y ejecuta `hostname` dentro de su contenedor.
9. Etiqueta el Pod `web` con `app=web` y `tier=frontend` usando `kubectl label`.
10. Lista únicamente los Pods cuyo label `tier` sea `backend`.
11. Crea un Pod llamado **`roto`** con la imagen **`nginx:no-existe`**. Espera 60 segundos, identifica el estado del Pod y **la línea exacta de los eventos** que explica el problema. Anótala.
12. Elimina el Pod `roto` de forma inmediata (sin esperar el periodo de gracia).

## Restricciones

* Trabaja **exclusivamente** en el namespace `c1-basico`.
* En el paso 5 **no se permite escribir el YAML desde cero ni copiarlo de la documentación**: debe salir de `kubectl`.
* No uses Deployments ni ReplicaSets en este laboratorio.

## Validación

```bash
kubectl -n c1-basico get pods -o wide
kubectl -n c1-basico get pods -l tier=backend
kubectl -n c1-basico get pod api -o jsonpath='{.metadata.labels}{"\n"}'
kubectl -n c1-basico get pod api -o jsonpath='{.spec.containers[0].ports}{"\n"}'
kubectl -n c1-basico describe pod api | head -20
kubectl -n c1-basico get events --sort-by=.lastTimestamp | tail -10
```

## Resultado esperado

* `web` y `api` en estado `Running`, cada uno con su IP y su nodo asignado.
* `api` con los labels `app=api` y `tier=backend` y un puerto de contenedor llamado `http`.
* `kubectl -n c1-basico get pods -l tier=backend` devuelve únicamente `api`.
* El Pod `roto` quedó en `ImagePullBackOff` / `ErrImagePull` y sus eventos muestran un `Failed to pull image`.
* Tras el paso 12, `roto` ya no existe.

## Criterios de éxito

- [ ] Namespace `c1-basico` creado.
- [ ] Pod `web` creado imperativamente y `Running`.
- [ ] `api.yaml` generado con `--dry-run=client -o yaml`.
- [ ] Pod `api` con labels `app=api` y `tier=backend`.
- [ ] Pod `api` con puerto de contenedor `80` nombrado `http`.
- [ ] Sé qué campo controla el periodo de gracia y su valor por defecto.
- [ ] Obtuve logs y ejecuté un comando dentro del contenedor.
- [ ] El filtro por label devuelve solo el Pod esperado.
- [ ] Identifiqué el evento exacto que explica el fallo del Pod `roto`.
- [ ] Eliminé `roto` sin esperar el periodo de gracia.
