# LAB 2.1 — Inventario del cluster, cordon y drain

## Nivel

Básico.

## Duración

20 minutos.

## Objetivo

Conocer el cluster que vas a administrar antes de tocarlo, y practicar la operación que precede a cualquier mantenimiento: vaciar un nodo y devolverlo al servicio.

## Competencias

* Inventariar versiones de componentes.
* Localizar los static Pods del control plane.
* Usar `crictl` en el nodo.
* `cordon`, `drain` y `uncordon`.
* Interpretar `SchedulingDisabled`.

## Escenario

Te acaban de entregar un cluster que no montaste tú. Antes de la ventana de mantenimiento del próximo laboratorio, necesitas un inventario fiable y comprobar que sabes vaciar un nodo sin dejar la aplicación caída.

## Estado inicial

* Cluster kubeadm con `cka-master` y al menos un worker, todos `Ready`.
* Acceso **root por SSH** a los nodos.
* Namespace de trabajo: **`c2-basico`**.

## Requerimientos

### Parte A — Inventario

1. Crea el namespace `c2-basico`.
2. Obtén y anota, en una tabla:
   * versión de cada nodo (`kubectl get nodes`),
   * versión del cliente y del servidor (`kubectl version`),
   * versión de `kubeadm` y de `kubelet` **en el master**,
   * el container runtime y su versión de cada nodo.
3. En `cka-master`, lista los archivos de `/etc/kubernetes/manifests/` y di qué componente corresponde a cada uno.
4. Lista los contenedores del control plane con `crictl ps`.
5. Averigua dónde guarda etcd sus datos, leyendo el manifiesto `etcd.yaml`.

### Parte B — Vaciar un nodo

6. Despliega en `c2-basico` un Deployment **`inventario`** con **4 réplicas** de `nginx:1.27-alpine`.
7. Comprueba cómo están repartidas las réplicas entre nodos.
8. Marca un worker como **no programable** (`cordon`) y comprueba el cambio en `kubectl get nodes`.
9. Crea un Pod nuevo y verifica que **no** se programa en ese nodo.
10. Ahora **vacía** ese worker con `drain`. Deberás resolver los dos errores que `drain` te va a dar (DaemonSets y datos de `emptyDir`) leyendo el mensaje, no la solución.
11. Comprueba dónde quedaron las 4 réplicas de `inventario`.
12. Devuelve el nodo al servicio con `uncordon`.
13. Responde: tras el `uncordon`, ¿vuelven las réplicas al nodo por sí solas? ¿Por qué?

## Restricciones

* No reinicies ningún nodo.
* No elimines Pods del namespace `kube-system` a mano.
* Trabaja los recursos de aplicación exclusivamente en `c2-basico`.

## Validación

```bash
kubectl get nodes -o wide
kubectl version
kubectl -n c2-basico get pods -o wide
kubectl get nodes | grep -i SchedulingDisabled
ssh root@cka-master 'ls -1 /etc/kubernetes/manifests/; crictl ps | head'
```

## Resultado esperado

* Tabla de inventario completa con las versiones de los tres binarios y del servidor.
* `/etc/kubernetes/manifests/` contiene `etcd.yaml`, `kube-apiserver.yaml`, `kube-controller-manager.yaml`, `kube-scheduler.yaml`.
* Tras el `cordon`, el nodo aparece como `Ready,SchedulingDisabled` y los Pods nuevos lo evitan.
* Tras el `drain`, ninguna réplica de `inventario` queda en ese nodo.
* Tras el `uncordon`, el nodo vuelve a `Ready` pero **las réplicas no vuelven solas**.

## Criterios de éxito

- [ ] Inventario de versiones completo (nodos, cliente, servidor, kubeadm, kubelet, runtime).
- [ ] Identifiqué los 4 static Pods del control plane.
- [ ] Sé dónde vive el data dir de etcd.
- [ ] `cordon` aplicado y verificado.
- [ ] Un Pod nuevo evita el nodo cordonado.
- [ ] `drain` completado resolviendo los dos errores por mi cuenta.
- [ ] Las 4 réplicas siguen `Running` tras el drain.
- [ ] `uncordon` aplicado y el nodo vuelve a `Ready`.
- [ ] Puedo explicar por qué Kubernetes no reequilibra automáticamente.
