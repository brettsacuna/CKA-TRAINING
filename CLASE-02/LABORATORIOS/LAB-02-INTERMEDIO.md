# LAB 2.2 — Upgrade del cluster kubeadm (v1.34 → v1.35)

## Nivel

Intermedio.

## Duración

35 minutos.

## Objetivo

Ejecutar un upgrade completo de un cluster kubeadm, en el orden correcto, sin dejar la aplicación caída y validando cada etapa.

## Competencias

* Cambiar el repositorio `pkgs.k8s.io` a la minor de destino.
* `apt-mark hold` / `unhold`.
* `kubeadm upgrade plan` / `apply` / `node`.
* Actualizar `kubelet` y `kubectl` y reiniciar el agente.
* Validar un upgrade.

## Escenario

El cluster corre **v1.34.x**. Seguridad exige subir a **v1.35.x** esta semana. La aplicación `inventario` de la Clase 2 debe seguir respondiendo durante toda la ventana.

Flujo obligatorio:

```
Validar versiones
      v
Snapshot de etcd (seguro)
      v
CONTROL PLANE:  repo -> kubeadm -> upgrade plan -> upgrade apply -> drain -> kubelet/kubectl -> restart -> uncordon
      v
WORKERS (uno a uno): repo -> kubeadm -> drain -> upgrade node -> kubelet/kubectl -> restart -> uncordon
      v
Validar
```

## Estado inicial

* Cluster kubeadm en **v1.34.x** en todos los nodos.
* Acceso root por SSH a todos los nodos.
* Deployment `inventario` con 4 réplicas en `c2-basico` (del LAB 2.1).
* Salida a Internet para los repositorios de paquetes.

## Requerimientos

1. **Antes de nada**, toma un snapshot de etcd (usa `RECURSOS/SCRIPTS/etcd-backup.sh` o hazlo a mano). Anota la ruta.
2. Registra las versiones de partida de los tres binarios en cada nodo.
3. En `cka-master`, apunta el repositorio de Kubernetes a la minor **v1.35**.
4. Actualiza **solo `kubeadm`** a `1.35.x` y verifica con `kubeadm version`.
5. Ejecuta `kubeadm upgrade plan` y **anota la versión objetivo que propone**.
6. Ejecuta `kubeadm upgrade apply` a esa versión.
7. Vacía el control plane, actualiza `kubelet` y `kubectl`, reinicia `kubelet` y devuélvelo al servicio.
8. Verifica que `kubectl get nodes` muestra el master en `v1.35.x`.
9. Repite el procedimiento en **cada worker**, uno a uno, usando **`kubeadm upgrade node`** (no `apply`).
10. Durante todo el proceso, mantén en otra terminal una comprobación continua de que la aplicación responde.
11. Al finalizar, valida: versiones de nodos, Pods del control plane, versión de CoreDNS y de etcd, y estado de la aplicación.

## Restricciones

* **No saltes minors**: kubeadm no permite `1.34 -> 1.36` en un paso.
* `kubectl` no puede quedar más de una minor por delante o por detrás del API server.
* No actualices `kubelet` antes de `kubeadm upgrade apply`.
* No hagas `drain` de los tres nodos a la vez.
* No borres el Deployment `inventario`.

## Pistas de método (no de solución)

* El repositorio de Kubernetes está en `/etc/apt/sources.list.d/kubernetes.list` y su clave en `/etc/apt/keyrings/`. Hay **un repositorio por minor**.
* Si `apt install kubeadm=<versión>` dice que no encuentra el paquete, el problema está en el repositorio, no en la versión.
* `apt-cache madison kubeadm` te dice qué versiones ve tu sistema.
* `kubeadm upgrade plan` no cambia nada: úsalo tantas veces como quieras.

## Validación

```bash
kubectl get nodes -o wide
kubeadm version && kubelet --version && kubectl version
kubectl -n kube-system get pods -o wide
kubectl -n kube-system get deploy coredns -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
kubectl -n c2-basico get deploy inventario
kubectl get nodes | grep -i SchedulingDisabled     # no debe devolver nada
```

## Resultado esperado

* Todos los nodos en `Ready` y en **v1.35.x**.
* Ningún nodo en `SchedulingDisabled`.
* Los 4 static Pods del control plane `Running` con imágenes `v1.35.x`.
* CoreDNS y etcd actualizados a las versiones que indicó `upgrade plan`.
* `inventario` con 4/4 réplicas disponibles.

## Criterios de éxito

- [ ] Snapshot de etcd tomado **antes** del upgrade.
- [ ] Repositorio apuntando a v1.35 en todos los nodos.
- [ ] `kubeadm` actualizado antes que `kubelet` en cada nodo.
- [ ] `kubeadm upgrade plan` ejecutado y versión objetivo anotada.
- [ ] `kubeadm upgrade apply` completado en el control plane.
- [ ] `kubeadm upgrade node` usado en los workers (no `apply`).
- [ ] `kubelet` reiniciado en cada nodo tras actualizarlo.
- [ ] `uncordon` ejecutado en todos los nodos.
- [ ] Todos los nodos en v1.35.x.
- [ ] La aplicación estuvo disponible durante toda la ventana.
