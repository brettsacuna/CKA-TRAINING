# LAB 12.1 — Las tres sondas en acción

## Nivel

Básico.

## Duración

22 minutos.

## Objetivo

Configurar `livenessProbe`, `readinessProbe` y `startupProbe` en una aplicación de
prueba y **ver en directo** las tres consecuencias: el reinicio, la salida del
`EndpointSlice` y la protección del arranque.

## Competencias

* Añadir sondas con `httpGet` y `exec`.
* Distinguir el efecto de cada sonda observando el Pod y su Service.
* Leer los eventos `Unhealthy`, `Killing`, `Started`.
* Calcular el presupuesto de detección con `periodSeconds` y `failureThreshold`.

## Escenario

Antes de tocar GRATITUD, provocas cada fallo a propósito con una app de juguete y
observas qué hace Kubernetes.

## Estado inicial

* Namespace de trabajo: **`c12-basico`**.

## Requerimientos

### Parte A — Sin sondas

1. Crea el namespace `c12-basico` y despliega la app y su Service:
   ```bash
   kubectl apply -f ../RECURSOS/YAML/01-probes-demo.yaml
   ```
   Deployment `web` (`nginx:1.27-alpine`, 1 réplica) + Service `web`.
2. Comprueba que el Pod está `Running` y que el Service tiene endpoint:
   ```bash
   kubectl -n c12-basico get pod,endpoints web
   ```

### Parte B — Liveness que falla → reinicio

3. Añade una `livenessProbe` que apunte a una ruta inexistente:
   ```bash
   kubectl -n c12-basico patch deploy web --type=json -p='[{"op":"add",
     "path":"/spec/template/spec/containers/0/livenessProbe",
     "value":{"httpGet":{"path":"/no-existe","port":80},"initialDelaySeconds":3,"periodSeconds":3,"failureThreshold":2}}]'
   ```
4. Observa:
   ```bash
   kubectl -n c12-basico get pod -w        # RESTARTS sube; STATUS pasa a CrashLoopBackOff
   kubectl -n c12-basico describe pod -l app=web | sed -n '/Events/,$p'   # Unhealthy, Killing
   ```
5. Quita la `livenessProbe` (`kubectl patch ... op: remove`) y comprueba que el Pod se estabiliza.

### Parte C — Readiness que falla → sin tráfico, sin reinicio

6. Añade una `readinessProbe` que falle:
   ```bash
   kubectl -n c12-basico patch deploy web --type=json -p='[{"op":"add",
     "path":"/spec/template/spec/containers/0/readinessProbe",
     "value":{"httpGet":{"path":"/no-existe","port":80},"periodSeconds":3,"failureThreshold":2}}]'
   ```
7. Observa:
   ```bash
   kubectl -n c12-basico get pod          # READY 0/1, pero RESTARTS NO sube
   kubectl -n c12-basico get endpoints web   # sin direcciones
   ```
8. Cambia el `path` de la readiness a `/` y comprueba que el Pod vuelve a `READY 1/1` y el endpoint reaparece.

### Parte D — Startup protege el arranque

9. Simula un arranque lento sustituyendo el comando del contenedor:
   ```bash
   kubectl -n c12-basico patch deploy web --type=json -p='[{"op":"add",
     "path":"/spec/template/spec/containers/0/command",
     "value":["sh","-c","sleep 25 && nginx -g \"daemon off;\""]}]'
   ```
10. Con la `livenessProbe` de la Parte B (path `/`, `initialDelaySeconds: 3`), el Pod se **mata antes de arrancar**: entra en `CrashLoopBackOff`.
11. Añade un `startupProbe` que dé margen:
    ```bash
    kubectl -n c12-basico patch deploy web --type=json -p='[{"op":"add",
      "path":"/spec/template/spec/containers/0/startupProbe",
      "value":{"httpGet":{"path":"/","port":80},"periodSeconds":3,"failureThreshold":15}}]'
    ```
12. Comprueba que ahora el Pod arranca: mientras el `startupProbe` no pasa, la `livenessProbe` **no actúa**.

### Parte E — Presupuesto de detección

13. Para la `livenessProbe` final, calcula cuánto tarda Kubernetes en dar por caído el contenedor:
    `initialDelaySeconds + periodSeconds × failureThreshold`. Anótalo.

## Restricciones

* No borres el Deployment `web` entre partes: se va parcheando.
* En la Parte D, el `startupProbe` debe dar más margen que el `sleep`.

## Validación

```bash
kubectl -n c12-basico get pod,endpoints web
kubectl -n c12-basico get deploy web -o jsonpath='{.spec.template.spec.containers[0].startupProbe}{"\n"}'
kubectl -n c12-basico describe pod -l app=web | sed -n '/Events/,$p'
```

## Resultado esperado

* Liveness que falla → `RESTARTS` sube, `CrashLoopBackOff`, eventos `Unhealthy`/`Killing`.
* Readiness que falla → `READY 0/1`, endpoint retirado, `RESTARTS` **no** sube.
* Arranque lento + liveness sin startup → `CrashLoopBackOff`.
* Con `startupProbe` de margen suficiente → el Pod arranca y se estabiliza.

## Criterios de éxito

- [ ] Vi subir `RESTARTS` con una liveness que falla.
- [ ] Vi el Pod salir de los endpoints con una readiness que falla, sin reiniciarse.
- [ ] Reproduje el `CrashLoopBackOff` por arranque lento sin `startupProbe`.
- [ ] Añadí un `startupProbe` y el Pod arrancó.
- [ ] Leí los eventos `Unhealthy`, `Killing`, `Started`.
- [ ] Calculé el presupuesto de detección de la liveness.
