# LAB 3.2 — Volúmenes: emptyDir, PersistentVolume y PersistentVolumeClaim

## Nivel

Intermedio.

## Duración

30 minutos.

## Objetivo

Compartir datos entre contenedores de un Pod y aprovisionar almacenamiento persistente de forma estática, entendiendo por qué un PVC enlaza con un PV concreto y no con otro.

## Competencias

* `emptyDir` entre dos contenedores del mismo Pod.
* Crear PV con `capacity`, `accessModes`, `storageClassName` y `persistentVolumeReclaimPolicy`.
* Crear PVC y comprobar el binding.
* Consumir un PVC desde un Pod con `volumeMounts`.
* Forzar el enlace a un PV concreto mediante labels y `selector`.

## Escenario

Un equipo de contenido despliega un sitio estático. Un contenedor descarga el contenido; otro lo sirve. Además, el sitio necesita un directorio que **sobreviva** a la eliminación del Pod.

## Estado inicial

* Namespace de trabajo: **`c3-inter`**.
* Al menos un worker con acceso para crear directorios (`/mnt/data-*`).
* Sin PV ni PVC previos del laboratorio.

## Requerimientos

### Parte A — emptyDir entre dos contenedores

1. Crea el namespace `c3-inter`.
2. Crea un Pod **`sitio`** con **dos contenedores** que comparten un volumen `emptyDir` llamado `www`:
   * `writer`: imagen `busybox:1.36`, escribe `<h1>Hola CKA</h1>` en `/data/index.html` y luego duerme.
   * `web`: imagen `nginx:1.27-alpine`, monta el mismo volumen en `/usr/share/nginx/html`.
3. Verifica desde un `curl` interno que el sitio responde con el contenido escrito por `writer`.
4. Borra el Pod y vuelve a crearlo. Comprueba si el contenido persiste y **explica el resultado**.

### Parte B — PV y PVC estáticos

5. En **un worker concreto**, crea los directorios `/mnt/data-a` y `/mnt/data-b` y escribe dentro de cada uno un `index.html` distinguible.
6. Crea **dos PersistentVolumes**, ambos de **2Gi**, `ReadWriteOnce`, `storageClassName: manual`, `persistentVolumeReclaimPolicy: Retain`:
   * `pv-a`, con label `contenido=alfa`, apuntando a `/mnt/data-a`.
   * `pv-b`, con label `contenido=beta`, apuntando a `/mnt/data-b`.
7. Crea un PVC **`pvc-sitio`** que pida **1Gi**, `ReadWriteOnce`, `storageClassName: manual` y que enlace **exactamente con `pv-b`**, usando un `selector` por label.
8. Comprueba el estado de ambos PV y del PVC.
9. Crea un Pod **`web-persistente`** que monte `pvc-sitio` en `/usr/share/nginx/html` y sirva su contenido. Comprueba con `curl` que responde el `index.html` de `/mnt/data-b`.
10. Borra el Pod y vuelve a crearlo. Comprueba que el contenido **sigue ahí**.
11. Borra el PVC. Observa en qué estado queda `pv-b` y **explica qué significa** y qué hay que hacer para poder reutilizarlo.

## Restricciones

* Trabaja en `c3-inter` (los PV no tienen namespace: nómbralos con el prefijo del laboratorio).
* En el paso 7 **no vale** que el PVC enlace por casualidad: debe hacerlo por `selector`, y hay que poder demostrarlo.
* No uses una StorageClass dinámica en este laboratorio.
* Si tu cluster tiene una StorageClass por defecto, asegúrate de que no interfiere.

## Validación

```bash
kubectl -n c3-inter get pods -o wide
kubectl get pv -o wide
kubectl -n c3-inter get pvc
kubectl get pv pv-b -o jsonpath='{.status.phase} {.spec.claimRef.name}{"\n"}'
kubectl -n c3-inter describe pvc pvc-sitio | sed -n '/Events/,$p'
kubectl -n c3-inter exec web-persistente -- cat /usr/share/nginx/html/index.html
```

## Resultado esperado

* Parte A: `curl` devuelve `<h1>Hola CKA</h1>`; tras recrear el Pod el contenido **se pierde**, porque `emptyDir` vive y muere con el Pod.
* Parte B: `pv-a` en `Available`, `pv-b` en `Bound` a `pvc-sitio`, PVC en `Bound` con `CAPACITY 2Gi`.
* `web-persistente` sirve el `index.html` de `/mnt/data-b`, y sigue haciéndolo tras recrearse.
* Tras borrar el PVC, `pv-b` queda en **`Released`** (no `Available`), porque `reclaimPolicy: Retain` conserva los datos y el `claimRef`.

## Criterios de éxito

- [ ] Pod `sitio` con dos contenedores compartiendo `emptyDir`.
- [ ] Demostré que `emptyDir` no persiste al recrear el Pod.
- [ ] `pv-a` y `pv-b` creados con capacidad, modo de acceso, clase y política correctos.
- [ ] `pvc-sitio` enlaza con `pv-b` por `selector`, no por azar.
- [ ] `pv-a` permanece `Available`.
- [ ] El PVC muestra `CAPACITY 2Gi` aunque pidió 1Gi, y sé explicar por qué.
- [ ] El Pod monta el PVC y sirve el contenido correcto.
- [ ] El contenido persiste tras recrear el Pod.
- [ ] `pv-b` queda `Released` y sé qué hacer para reutilizarlo.
