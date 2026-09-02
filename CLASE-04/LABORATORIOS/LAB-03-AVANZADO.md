# LAB 4.3 — Recursos, QoS, escalado y métricas

## Nivel

Avanzado.

## Duración

26 minutos.

## Objetivo

Dimensionar aplicaciones a partir de requerimientos: definir `requests` y `limits`, provocar y reconocer los dos fallos clásicos (`Pending` por requests y `OOMKilled` por limits), y medir el consumo real.

## Competencias

* `resources.requests` y `resources.limits` de CPU y memoria.
* Clases de QoS.
* Instalar y validar Metrics Server.
* `kubectl top nodes` y `kubectl top pods`.
* `kubectl scale`.
* Distinguir un fallo por CPU de uno por memoria.

## Escenario

Producción se ha quedado sin capacidad dos veces este mes porque nadie declaraba recursos. Te piden implantar una política mínima y demostrar sus efectos.

Tú decides los manifiestos, los comandos y las validaciones.

## Estado inicial

* Namespace de trabajo: **`c4-recursos`**.
* Metrics Server **no instalado** (si lo está, verifica su versión).
* Anota antes de empezar la capacidad asignable de tus nodos:
  ```bash
  kubectl describe node <worker> | sed -n '/Allocatable/,/System Info/p'
  ```

## Requerimientos

### R1 — Métricas

1. Instala **Metrics Server v0.8.1** con el manifiesto oficial.
2. Si los Pods no llegan a `Ready`, diagnostícalo. En clusters de laboratorio con certificados de kubelet autofirmados hay que añadir un argumento al contenedor: averigua cuál leyendo los logs, no la solución.
3. Comprueba que `kubectl top nodes` y `kubectl top pods -A` devuelven datos.

### R2 — Las tres clases de QoS

4. Crea en `c4-recursos` tres Pods, cada uno de una clase de QoS distinta, usando la imagen `nginx:1.27-alpine`:
   * `pod-guaranteed`
   * `pod-burstable`
   * `pod-besteffort`
5. Comprueba la clase asignada a cada uno leyendo su `status.qosClass` y **explica la regla** que la determina.

### R3 — Requests que no caben

6. Crea un Deployment **`hambriento`** con 2 réplicas de `nginx:1.27-alpine` que solicite (`requests`) **más CPU de la que ofrece cualquiera de tus nodos**.
7. Observa el estado y documenta el evento exacto.
8. Corrígelo bajando los `requests` a un valor realista y comprueba que arranca.

### R4 — Limits de memoria

9. Crea un Pod **`memoria`** con la imagen `polinux/stress` (o `busybox` con un bucle de asignación) que intente consumir **más memoria de la que su `limits.memory` permite**.
   Sugerencia de comando: `stress --vm 1 --vm-bytes 250M --vm-hang 1` con `limits.memory: 100Mi`.
10. Observa el estado del Pod y el motivo de terminación del contenedor. Documenta el `Reason` y el `Exit Code`.
11. Responde: ¿por qué un exceso de **CPU** no mata el contenedor y un exceso de **memoria** sí?

### R5 — Escalado y medición

12. Crea un Deployment **`medido`** con 2 réplicas, `requests` de `100m` CPU y `64Mi` de memoria, y `limits` de `500m` y `128Mi`.
13. Escálalo a **6 réplicas** con un comando imperativo.
14. Mide el consumo real con `kubectl top pods` y compáralo con lo solicitado. Responde: ¿estás sobredimensionando?
15. Comprueba con `kubectl describe node` cuánta CPU y memoria del nodo están **reservadas** por `requests` frente a cuánta se usa realmente.

## Restricciones

* Metrics Server debe instalarse desde el manifiesto oficial, no editando versiones antiguas.
* No uses `--limits` ni `--requests` de `kubectl run` como única solución: al menos un Pod debe definirse en YAML.
* No modifiques la capacidad de los nodos.
* El Pod `memoria` debe demostrar el fallo, no evitarlo.

## Validación

```bash
kubectl -n kube-system get deploy metrics-server
kubectl top nodes
kubectl top pods -n c4-recursos
kubectl -n c4-recursos get pods -o custom-columns=\
NAME:.metadata.name,QOS:.status.qosClass,STATUS:.status.phase
kubectl -n c4-recursos describe pod memoria | sed -n '/Last State/,/Ready/p'
kubectl describe node <worker> | sed -n '/Allocated resources/,$p'
```

## Resultado esperado

* `kubectl top nodes` devuelve CPU y memoria por nodo.
* `pod-guaranteed` → `Guaranteed`, `pod-burstable` → `Burstable`, `pod-besteffort` → `BestEffort`.
* `hambriento` queda `Pending` con `FailedScheduling ... Insufficient cpu`, y arranca al corregir los requests.
* `memoria` muestra `Last State: Terminated, Reason: OOMKilled, Exit Code: 137` y reinicios crecientes.
* `describe node` muestra los `requests` como porcentaje reservado del nodo.

## Criterios de éxito

- [ ] Metrics Server v0.8.1 instalado y `Ready`.
- [ ] Diagnostiqué por mi cuenta el argumento que faltaba (si aplicaba).
- [ ] `kubectl top nodes` y `kubectl top pods` funcionan.
- [ ] Los tres Pods tienen las tres clases de QoS y sé explicar la regla.
- [ ] Provoqué un `Pending` por `requests` y documenté el evento.
- [ ] Corregí los `requests` y el Deployment arrancó.
- [ ] Provoqué un `OOMKilled` y documenté `Reason` y `Exit Code`.
- [ ] Expliqué la diferencia entre CPU (comprimible) y memoria (no comprimible).
- [ ] Escalé `medido` a 6 réplicas y comparé consumo real vs solicitado.
- [ ] Leí la sección `Allocated resources` de un nodo.
