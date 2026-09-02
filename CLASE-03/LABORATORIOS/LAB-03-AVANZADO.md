# LAB 3.3 — StatefulSet con identidad estable y almacenamiento por réplica

## Nivel

Avanzado.

## Duración

28 minutos.

## Objetivo

Desplegar, **a partir de requerimientos**, una carga con estado que garantice nombre estable, orden de creación y un volumen propio por réplica, y demostrar empíricamente cada una de esas tres garantías.

## Competencias

* StatefulSet: `serviceName`, `replicas`, `volumeClaimTemplates`.
* Headless Service (`clusterIP: None`) y DNS por Pod.
* Aprovisionamiento dinámico o estático para un StatefulSet.
* Demostrar la persistencia de identidad tras eliminar un Pod.
* Entender por qué borrar el StatefulSet no borra los PVC.

## Escenario

La plataforma necesita alojar un servicio con estado (`web`) de **3 réplicas**. El equipo de datos exige:

* Cada réplica debe tener **un nombre estable y predecible**.
* Cada réplica debe tener **su propio volumen de 1Gi**, no compartido.
* Cada réplica debe ser **direccionable individualmente por DNS**.
* Si una réplica se cae y vuelve, debe **recuperar su nombre y sus datos**.

Tú decides los recursos, el orden y las validaciones.

## Estado inicial

* Namespace de trabajo: **`c3-sts`**.
* Comprueba primero si tu cluster tiene una StorageClass por defecto:
  ```bash
  kubectl get storageclass
  ```
  * **Si la hay**, usa aprovisionamiento **dinámico**.
  * **Si no la hay**, deberás crear manualmente los PV necesarios antes de que el StatefulSet arranque. Averigua cuántos y de qué tamaño.

## Requerimientos

1. Crea el namespace `c3-sts`.
2. Crea el almacenamiento que corresponda a tu cluster (dinámico o estático).
3. Crea un **Headless Service** llamado **`nginx`** que seleccione `app=nginx` y exponga el puerto `80` con nombre `web`.
4. Crea un **StatefulSet** llamado **`web`** con:
   * 3 réplicas,
   * `serviceName: nginx`,
   * imagen `registry.k8s.io/nginx-slim:0.27` (o `nginx:1.27-alpine`),
   * puerto de contenedor `80` con nombre `web`,
   * `volumeClaimTemplates` que cree un PVC llamado `www` de **1Gi**, `ReadWriteOnce`, montado en `/usr/share/nginx/html`.
5. Observa el **orden** en que se crean los Pods. Documenta lo que ves.
6. Lista los PVC creados. Explica el patrón de nombres.
7. Escribe en cada réplica un `index.html` con su propio nombre (`web-0`, `web-1`, `web-2`).
8. Desde un Pod temporal, resuelve por DNS y haz `curl` a:
   * `nginx` (el Headless Service),
   * `web-0.nginx.c3-sts.svc.cluster.local`,
   * `web-2.nginx.c3-sts.svc.cluster.local`.
   Explica en qué se diferencia la respuesta del primero respecto a los otros dos.
9. **Prueba de identidad**: borra el Pod `web-1`. Observa:
   * qué nombre recibe el Pod nuevo,
   * en qué orden se recrea,
   * si conserva su contenido.
10. Escala el StatefulSet a **5 réplicas** y luego de vuelta a **3**. Comprueba qué pasa con los PVC de `web-3` y `web-4`. **Explica por qué Kubernetes hace eso.**
11. Elimina el StatefulSet **sin eliminar los PVC**. Vuelve a crearlo y comprueba si las réplicas recuperan sus datos.

## Restricciones

* No uses un Deployment.
* Cada réplica debe tener su propio PVC: no vale un PVC compartido.
* El Service debe ser **headless** (`clusterIP: None`).
* No borres los PVC manualmente hasta el final del laboratorio.

## Validación

```bash
kubectl -n c3-sts get statefulset,pods,pvc,svc -o wide
kubectl -n c3-sts get svc nginx -o jsonpath='{.spec.clusterIP}{"\n"}'   # None
kubectl -n c3-sts get pvc
kubectl -n c3-sts exec web-0 -- cat /usr/share/nginx/html/index.html
kubectl run tmp --rm -it -n c3-sts --image=busybox:1.36 --restart=Never -- \
  sh -c 'nslookup nginx; nslookup web-0.nginx'
```

## Resultado esperado

* Pods creados **en orden**: `web-0`, luego `web-1`, luego `web-2`.
* PVC llamados `www-web-0`, `www-web-1`, `www-web-2`, todos `Bound`, 1Gi cada uno.
* El Headless Service **no tiene ClusterIP**; su resolución DNS devuelve **las IP de los Pods**, no una VIP.
* `web-1` recreado conserva **el mismo nombre**, el mismo PVC y el mismo contenido.
* Al bajar de 5 a 3 réplicas, los PVC `www-web-3` y `www-web-4` **siguen existiendo**.
* Tras recrear el StatefulSet, cada réplica recupera su contenido anterior.

## Criterios de éxito

- [ ] Headless Service `nginx` con `clusterIP: None`.
- [ ] StatefulSet `web` con `serviceName: nginx` y 3 réplicas.
- [ ] `volumeClaimTemplates` crea un PVC de 1Gi por réplica.
- [ ] Documenté el orden de creación de los Pods.
- [ ] Expliqué el patrón de nombres de los PVC.
- [ ] Resolví por DNS tanto el Service como un Pod individual, y expliqué la diferencia.
- [ ] Al borrar `web-1`, el Pod nuevo conserva nombre, PVC y datos.
- [ ] Expliqué por qué los PVC sobreviven al reducir réplicas.
- [ ] Tras recrear el StatefulSet, los datos siguen ahí.
