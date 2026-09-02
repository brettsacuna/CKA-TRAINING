# LAB 12.4 — Challenge: «GRATITUD está degradado»

## Nivel

Challenge / Troubleshooting.

## Duración

20 minutos.

## Objetivo

Distinguir **cuatro fallos** de salud y observabilidad con síntomas distintos:
`CrashLoopBackOff`, un Service sin endpoints, `OOMKilled` y `kubectl logs` vacío.

```
IDENTIFICAR -> DIAGNOSTICAR -> CORREGIR -> VALIDAR
```

## Competencias

* Reconocer una `livenessProbe` que mata la app durante el arranque.
* Detectar una `readinessProbe` apuntando al puerto equivocado (0 endpoints).
* Identificar `OOMKilled` por `limits.memory` insuficiente.
* Explicar por qué un componente no produce salida en `kubectl logs`.

## Escenario

Tras un despliegue, GRATITUD "va a trompicones": la API se reinicia sin parar, el
portal muere cada poco, la API no aparece en su Service y de un componente no sale
ni una línea de log. Nadie ha tocado nada, oficialmente. **Hay 4 fallos.**

## Estado inicial

```bash
cd CLASE-12/RECURSOS/SCRIPTS
chmod +x *.sh
./setup-lab.sh
```

Crea el namespace **`gratitud-api`** con:

* Deployment `api` (`nginx:1.27-alpine`, arranque deliberadamente lento) y Service `api` — **2 defectos**.
* Deployment `portal` (`nginx:1.27-alpine`) y Service `portal` — **1 defecto**.
* Deployment `worker` (`busybox`) — **1 defecto**.

## Requerimientos

1. Clasifica lo que ves:
   ```bash
   kubectl -n gratitud-api get pods -o wide
   kubectl -n gratitud-api get endpoints
   ```
2. Recorre la ruta:
   ```
   liveness / startup (api)  ->  readiness / puerto (api)  ->  limits.memory (portal)  ->  logs a stdout (worker)
   ```
3. Identifica los **4 fallos**.
4. Documenta, por cada uno: síntoma, comando que lo reveló, causa raíz y campo que lo corrige.
5. Corrige hasta que:
   * el Pod `api` esté `Running` y estable (`RESTARTS` no sube),
   * `kubectl -n gratitud-api get endpoints api` liste una dirección,
   * el Pod `portal` esté `Running` sin `OOMKilled` en `Last State`,
   * `kubectl -n gratitud-api logs deploy/worker` muestre líneas.

## Restricciones

* **No** elimines ninguna sonda «para que arranque».
* **No** elimines los `limits`; ajústalos.
* **No** cambies la imagen ni pongas al `worker` a hacer solo `sleep`.

## Ruta de diagnóstico

```
api CrashLoopBackOff
  |-- describe pod -> Liveness failed ... Killing        -> falta startupProbe / initialDelay
api Running pero endpoints api vacio
  |-- describe pod -> Readiness probe failed: connection refused :<puerto>  -> readinessProbe.httpGet.port
portal CrashLoopBackOff, Last State: OOMKilled
  |-- describe pod -> Reason: OOMKilled                  -> resources.limits.memory
worker Running pero 'kubectl logs' vacio
  |-- exec worker -- ls -l /var/log                      -> la app escribe a un fichero, no a stdout
```

## Comandos de diagnóstico

```bash
kubectl -n gratitud-api describe pod -l app=gratitud-api  | sed -n '/Events/,$p'
kubectl -n gratitud-api describe pod -l app=gratitud-portal | grep -A3 'Last State'
kubectl -n gratitud-api get deploy api -o jsonpath='{.spec.template.spec.containers[0].readinessProbe}{"\n"}'
kubectl -n gratitud-api get deploy portal -o jsonpath='{.spec.template.spec.containers[0].resources}{"\n"}'
kubectl -n gratitud-api exec deploy/worker -- ls -l /var/log
kubectl -n gratitud-api logs deploy/worker --tail=5
```

## Validación

```bash
cd CLASE-12/RECURSOS/SCRIPTS && ./validate-lab.sh

# manual
kubectl -n gratitud-api get pods
kubectl -n gratitud-api get endpoints api
kubectl -n gratitud-api logs deploy/worker --tail=3
```

## Los 4 fallos (para el instructor — no mirar antes de intentarlo)

<details>
<summary>Spoiler</summary>

1. **Liveness sin `startupProbe`.** `api` tarda ~20 s en servir; su `livenessProbe` (`initialDelaySeconds: 2`, `periodSeconds: 3`, `failureThreshold: 1`) lo mata antes de arrancar → `CrashLoopBackOff`. → Añadir un `startupProbe` con margen (o subir `initialDelaySeconds`/`failureThreshold` de la liveness).
2. **`readinessProbe` al puerto equivocado.** `api` escucha en el **80**; la `readinessProbe` es `httpGet.port: 8080` → nunca pasa → el Pod no entra en el `EndpointSlice` → `get endpoints api` vacío. → `port: 80`.
3. **`limits.memory` insuficiente.** `portal` tiene `resources.limits.memory: 8Mi`; nginx no arranca en tan poco → `OOMKilled` en bucle. → subir a `128Mi` (con `requests` acorde).
4. **Logs a un fichero.** El `worker` corre `sh -c 'while true; do date >> /var/log/worker.log; sleep 5; done'` → `kubectl logs` vacío. → que escriba en **stdout** (`echo` sin redirección, o `tee /proc/1/fd/1`).

</details>

## Resultado esperado

* `api` `Running` y estable; `get endpoints api` con una dirección.
* `portal` `Running` sin `OOMKilled`.
* `kubectl logs deploy/worker` muestra líneas.
* `./validate-lab.sh` termina con `LAB 12.4 SUPERADO`.

## Criterios de éxito

- [ ] Clasifiqué los cuatro síntomas antes de tocar nada.
- [ ] Añadí un `startupProbe` en vez de quitar la liveness.
- [ ] Corregí el puerto de la `readinessProbe` y el endpoint reapareció.
- [ ] Subí `limits.memory` de `portal` y dejó de haber `OOMKilled`.
- [ ] Hice que el `worker` escriba a stdout y `kubectl logs` dejó de estar vacío.
- [ ] `./validate-lab.sh` pasa.
