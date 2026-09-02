# SOLUCIÓN — LAB 12.4 · Challenge «GRATITUD está degradado»

> **MATERIAL DEL INSTRUCTOR.**

## Los 4 fallos

| # | Objeto · campo | Fallo | Síntoma | Comando que lo revela |
|---|---|---|---|---|
| 1 | `deploy/api` · `livenessProbe` sin `startupProbe` | El contenedor tarda ~20 s; la liveness (`initialDelay 2`, `failureThreshold 1`) lo mata antes | `CrashLoopBackOff` | `describe pod` → *Liveness probe failed ... Killing* |
| 2 | `deploy/api` · `readinessProbe.httpGet.port` | `8080`; el contenedor escucha en `80` | `get endpoints api` vacío; `READY 0/1` | `describe pod` → *Readiness probe failed: connection refused* |
| 3 | `deploy/portal` · `resources.limits.memory` | `8Mi`; nginx no arranca en tan poco | `CrashLoopBackOff`, `Last State: OOMKilled` | `describe pod` (Last State) |
| 4 | `deploy/worker` · `command` | Escribe a `/var/log/worker.log`, no a stdout | `kubectl logs deploy/worker` vacío | `exec worker -- ls -l /var/log` |

## Método

Cuatro síntomas, cuatro sitios. El 1 y el 3 son ambos `CrashLoopBackOff`: hay que
mirar los eventos (`Liveness probe failed` vs `Reason: OOMKilled`) para
separarlos.

## Procedimiento

```bash
cd CLASE-12/RECURSOS/SCRIPTS && ./setup-lab.sh
kubectl -n gratitud-api get pods -o wide
kubectl -n gratitud-api get endpoints

# ---- Fallo 1: liveness mata el arranque ----
kubectl -n gratitud-api describe pod -l app=gratitud-api | sed -n '/Events/,$p'
# Warning  Unhealthy  Liveness probe failed: Get "http://.../": dial tcp ... connection refused
# Normal   Killing    Container api failed liveness probe, will be restarted
kubectl -n gratitud-api patch deploy api --type=json -p='[{"op":"add",
  "path":"/spec/template/spec/containers/0/startupProbe",
  "value":{"httpGet":{"path":"/","port":80},"periodSeconds":3,"failureThreshold":15}}]'

# ---- Fallo 2: readiness al puerto equivocado ----
kubectl -n gratitud-api get deploy api -o jsonpath='{.spec.template.spec.containers[0].readinessProbe}{"\n"}'
# ...httpGet":{"path":"/","port":8080}...
kubectl -n gratitud-api patch deploy api --type=json -p='[{"op":"replace",
  "path":"/spec/template/spec/containers/0/readinessProbe/httpGet/port","value":80}]'
kubectl -n gratitud-api rollout status deploy/api
kubectl -n gratitud-api get endpoints api            # ya tiene direccion

# ---- Fallo 3: OOMKilled ----
kubectl -n gratitud-api describe pod -l app=gratitud-portal | grep -A4 'Last State'
# Last State: Terminated   Reason: OOMKilled
kubectl -n gratitud-api patch deploy portal --type=json -p='[
  {"op":"replace","path":"/spec/template/spec/containers/0/resources/limits/memory","value":"128Mi"},
  {"op":"replace","path":"/spec/template/spec/containers/0/resources/requests/memory","value":"32Mi"}]'
kubectl -n gratitud-api rollout status deploy/portal

# ---- Fallo 4: logs a fichero ----
kubectl -n gratitud-api logs deploy/worker --tail=5          # vacio
kubectl -n gratitud-api exec deploy/worker -- ls -l /var/log # esta worker.log
kubectl -n gratitud-api patch deploy worker --type=json -p='[{"op":"replace",
  "path":"/spec/template/spec/containers/0/command",
  "value":["sh","-c","while true; do echo \"$(date) worker latido\"; sleep 5; done"]}]'
kubectl -n gratitud-api rollout status deploy/worker
kubectl -n gratitud-api logs deploy/worker --tail=3          # ya salen lineas
```

## Validación

```bash
cd CLASE-12/RECURSOS/SCRIPTS && ./validate-lab.sh
# LAB 12.4 SUPERADO (9 comprobaciones)

kubectl -n gratitud-api get pods
kubectl -n gratitud-api get endpoints api
kubectl -n gratitud-api logs deploy/worker --tail=3
```

## Resultado esperado

* `api` `Running` y estable; `get endpoints api` con una dirección.
* `portal` `Running`, sin `OOMKilled` en `Last State`.
* `kubectl logs deploy/worker` muestra líneas.

## Error frecuente

* Quitar la `livenessProbe` de `api` para "que arranque": el criterio pide protegerla con `startupProbe`, no eliminarla.
* Corregir el `readinessProbe` pero no esperar el `rollout`: el endpoint tarda unos segundos en aparecer.
* Subir `limits.memory` de `portal` a un valor gigante en vez de uno razonable.
* Poner al `worker` a hacer solo `sleep infinity`: entonces no hay logs que leer y no se demuestra nada. La corrección es **loguear a stdout**.
* Confundir los dos `CrashLoopBackOff` (fallo 1 y fallo 3) sin leer el motivo en los eventos.

## CKA Tip

```bash
k describe pod <p> | sed -n '/Events/,$p'
k get pod <p> -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}{"\n"}'   # OOMKilled?
k get endpoints <svc>
k logs deploy/<d> --previous --tail=20
```

Ruta mental de un servicio "degradado":
**liveness/startup (reinicios) → readiness/puerto (endpoints) → limits.memory (OOM) → logs a stdout.**
