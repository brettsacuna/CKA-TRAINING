# SOLUCIÓN — LAB 12.1 · Las tres sondas en acción

> **MATERIAL DEL INSTRUCTOR.**

## Diagnóstico

Cada sonda tiene **una** consecuencia y no se solapan:

| Sonda | Pregunta | Si falla |
|---|---|---|
| liveness | ¿sigue vivo? | el kubelet **mata y reinicia** el contenedor |
| readiness | ¿puede atender ya? | sale del `EndpointSlice`; **no** reinicia |
| startup | ¿terminó de arrancar? | mientras no pasa, liveness y readiness **quedan en pausa** |

## Procedimiento

```bash
k create ns c12-basico && k config set-context --current --namespace=c12-basico
k apply -f ../RECURSOS/YAML/01-probes-demo.yaml
k get pod,endpoints web

# B - liveness que falla -> reinicio
k patch deploy web --type=json -p='[{"op":"add",
  "path":"/spec/template/spec/containers/0/livenessProbe",
  "value":{"httpGet":{"path":"/no-existe","port":80},"initialDelaySeconds":3,"periodSeconds":3,"failureThreshold":2}}]'
k get pod -w                                   # RESTARTS sube, CrashLoopBackOff
k describe pod -l app=web | sed -n '/Events/,$p'   # Unhealthy (liveness) ... Killing
k patch deploy web --type=json -p='[{"op":"remove","path":"/spec/template/spec/containers/0/livenessProbe"}]'

# C - readiness que falla -> sin trafico, sin reinicio
k patch deploy web --type=json -p='[{"op":"add",
  "path":"/spec/template/spec/containers/0/readinessProbe",
  "value":{"httpGet":{"path":"/no-existe","port":80},"periodSeconds":3,"failureThreshold":2}}]'
k get pod            # READY 0/1, RESTARTS = 0
k get endpoints web  # <none>
k patch deploy web --type=json -p='[{"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/path","value":"/"}]'
k get pod,endpoints web   # READY 1/1, endpoint de vuelta

# D - arranque lento + startup
k patch deploy web --type=json -p='[{"op":"add",
  "path":"/spec/template/spec/containers/0/command",
  "value":["sh","-c","sleep 25 && nginx -g \"daemon off;\""]}]'
k patch deploy web --type=json -p='[{"op":"add",
  "path":"/spec/template/spec/containers/0/livenessProbe",
  "value":{"httpGet":{"path":"/","port":80},"initialDelaySeconds":3,"periodSeconds":3,"failureThreshold":2}}]'
k get pod -w         # CrashLoopBackOff: la liveness mata antes del segundo 25
k patch deploy web --type=json -p='[{"op":"add",
  "path":"/spec/template/spec/containers/0/startupProbe",
  "value":{"httpGet":{"path":"/","port":80},"periodSeconds":3,"failureThreshold":15}}]'
k get pod -w         # arranca: la liveness no actua hasta que startup pasa
```

Referencia final: `../RECURSOS/YAML/02-probes-tres.yaml`.

## Validación

```bash
k get pod,endpoints web
k get deploy web -o jsonpath='{.spec.template.spec.containers[0].startupProbe}{"\n"}'
k describe pod -l app=web | sed -n '/Events/,$p'
```

## Resultado esperado

* Liveness rota → `RESTARTS` sube, `CrashLoopBackOff`, evento `Unhealthy`/`Killing`.
* Readiness rota → `READY 0/1`, endpoint retirado, `RESTARTS` sin cambios.
* Arranque lento sin `startupProbe` → `CrashLoopBackOff`; con `startupProbe` de margen → arranca.
* Presupuesto de detección de la liveness final ≈ `initialDelaySeconds + periodSeconds × failureThreshold`.

## Error frecuente

* Poner un `initialDelaySeconds` enorme en la liveness "por si acaso": lo correcto es un `startupProbe`; el `initialDelay` grande también retrasa la detección de cuelgues reales.
* Confundir `Unhealthy` de liveness con `Unhealthy` de readiness en los eventos: mira el prefijo.
* Creer que una readiness que falla reinicia el Pod. No lo hace.
* `startupProbe` con menos margen que el arranque real: vuelve el `CrashLoopBackOff`.

## CKA Tip

```bash
k explain pod.spec.containers.livenessProbe
# handlers: httpGet | tcpSocket | exec | grpc
# tiempos:  initialDelaySeconds periodSeconds timeoutSeconds failureThreshold successThreshold
k set probe deploy/web --liveness  --get-url=http://:80/healthz --period-seconds=10
k set probe deploy/web --readiness --get-url=http://:80/ready   --period-seconds=5
k set probe deploy/web --startup   --get-url=http://:80/        --failure-threshold=30 --period-seconds=5
```
