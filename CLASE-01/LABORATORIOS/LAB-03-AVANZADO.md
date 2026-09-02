# LAB 1.3 — Colocación de Pods: nodeSelector, Taints, Affinity y Priority

## Nivel

Avanzado.

## Duración

27 minutos.

## Objetivo

Resolver, **únicamente a partir de requerimientos**, un escenario de colocación de workloads: forzar nodos concretos, reservar un nodo, repartir réplicas y garantizar que un workload crítico desplaza a uno prescindible.

## Competencias

* Etiquetar nodos y usar `nodeSelector`.
* Aplicar y retirar taints; escribir tolerations.
* Escribir `nodeAffinity` `required` y `preferred` con `weight`.
* Usar `podAntiAffinity` con `topologyKey`.
* Crear PriorityClass y observar la preemption.
* Diagnosticar `FailedScheduling`.

## Escenario

La plataforma va a alojar tres tipos de carga en un cluster con varios workers:

* Cargas **de producción**, que solo pueden ejecutarse en nodos marcados como tales.
* Un nodo **reservado para el equipo de datos**, donde nadie más debe aterrizar por accidente.
* Un servicio **crítico** que, si no hay capacidad, tiene derecho a desplazar cargas de relleno.

Tú decides los recursos, los comandos, el orden y las validaciones.

## Estado inicial

* Namespace de trabajo: **`c1-avanzado`** (lo creas tú).
* Al menos **dos workers**. Si solo tienes uno, retira el taint del control plane para usarlo como segundo nodo programable (y anótalo como desviación).
* Ningún nodo tiene labels personalizados ni taints adicionales.

Comprueba el punto de partida:

```bash
kubectl get nodes --show-labels
kubectl describe nodes | grep -i -A1 taint
```

## Requerimientos

### R1 — Nodos

1. Etiqueta un worker con `environment=production` y otro con `environment=data`.
2. El nodo `environment=data` debe quedar **reservado**: ningún Pod debe programarse allí salvo que lo declare explícitamente. Usa el taint `team=data:NoSchedule`.

### R2 — Carga de producción con nodeSelector

3. Crea un Pod **`prod-app`** (imagen `nginx:1.27-alpine`) que **solo** pueda ejecutarse en el nodo de producción, usando `nodeSelector`.
4. Verifica en qué nodo aterrizó.

### R3 — Carga del equipo de datos

5. Crea un Pod **`data-job`** (imagen `busybox:1.36`, comando `sleep 3600`) que **sí** pueda ejecutarse en el nodo reservado.
6. Verifica que aterrizó en el nodo `environment=data` y no en otro.

### R4 — Node Affinity

7. Crea un Pod **`affinity-app`** (imagen `nginx:1.27-alpine`) con estas reglas:
   * **Obligatoria**: el nodo debe tener el label `environment` con valor `production` **o** `staging`.
   * **Preferida** con `weight: 60`: el nodo debe tener `disktype=ssd`.
8. Etiqueta el nodo de producción con `disktype=ssd` y comprueba que la preferencia se cumple.
9. Explica por qué el Pod se habría programado igualmente aunque ningún nodo tuviera `disktype=ssd`.

### R5 — Pod Anti-Affinity

10. Crea un **Deployment** llamado **`spread`** con **2 réplicas** de `nginx:1.27-alpine`, label `app=spread`, de modo que **dos réplicas nunca compartan nodo** (regla obligatoria, `topologyKey: kubernetes.io/hostname`).
11. Comprueba que quedaron en nodos distintos.
12. Escala `spread` a **3 réplicas** en un cluster con 2 nodos programables. Observa el estado de la tercera réplica y **explica el evento** que aparece.

### R6 — Priority y Preemption

13. Crea dos PriorityClass:
    * `low-priority` con valor `1000`.
    * `critical-priority` con valor `100000`, `preemptionPolicy: PreemptLowerPriority` y `globalDefault: false`.
14. Crea un Pod **`filler`** con `low-priority` que solicite (`requests`) una cantidad de CPU suficientemente grande como para ocupar prácticamente todo el nodo de producción.
15. Crea un Pod **`critical`** con `critical-priority` que solicite una cantidad similar de CPU y que solo pueda ir a ese mismo nodo.
16. Observa qué le ocurre a `filler`. Documenta el evento de preemption.

## Restricciones

* No elimines ni reinicies nodos.
* No modifiques el control plane más allá de retirar su taint si necesitas un segundo nodo programable.
* `data-job` debe ser el **único** Pod del laboratorio capaz de ejecutarse en el nodo reservado.
* Al terminar, **retira el taint `team=data`** y los labels que hayas añadido.

## Validación

```bash
kubectl get nodes -L environment,disktype
kubectl describe nodes | grep -i -A1 taint
kubectl -n c1-avanzado get pods -o wide
kubectl -n c1-avanzado get deploy spread -o wide
kubectl -n c1-avanzado describe pod <pod-pending> | sed -n '/Events/,$p'
kubectl get priorityclass
kubectl -n c1-avanzado get events --sort-by=.lastTimestamp | grep -i -E 'preempt|FailedScheduling'
```

## Resultado esperado

* `prod-app` en el nodo con `environment=production`.
* `data-job` en el nodo con `environment=data`, y ningún otro Pod allí.
* `affinity-app` en un nodo que cumple la regla obligatoria y, preferentemente, el que tiene `disktype=ssd`.
* Las 2 réplicas de `spread` en nodos distintos; la tercera queda `Pending` con un `FailedScheduling` que menciona las reglas de anti-affinity.
* `filler` es desalojado (`Terminating` / recreado como `Pending`) y aparece un evento de preemption; `critical` queda `Running`.

## Criterios de éxito

- [ ] Los dos workers tienen los labels pedidos.
- [ ] El nodo de datos tiene el taint `team=data:NoSchedule`.
- [ ] `prod-app` usa `nodeSelector` y aterrizó donde debía.
- [ ] `data-job` tiene la toleration correcta y aterrizó en el nodo reservado.
- [ ] `affinity-app` tiene una regla `required` con operador `In` y dos valores.
- [ ] `affinity-app` tiene una regla `preferred` con `weight: 60`.
- [ ] `spread` usa `podAntiAffinity` obligatoria con `topologyKey: kubernetes.io/hostname`.
- [ ] Expliqué el `FailedScheduling` de la tercera réplica leyendo los eventos.
- [ ] Las dos PriorityClass existen con los valores indicados.
- [ ] Documenté el evento de preemption.
- [ ] Dejé los nodos limpios (sin el taint ni los labels del laboratorio).
