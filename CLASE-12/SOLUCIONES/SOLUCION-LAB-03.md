# SOLUCIÓN — LAB 12.3 · Sondas, `top` y métricas para GRATITUD

> **MATERIAL DEL INSTRUCTOR.**

## Diagnóstico

1. **`kubectl top` necesita metrics-server.** Sin él: *Metrics API not available*. En kubeadm de laboratorio hace falta `--kubelet-insecure-tls`.
2. **Una sonda por pregunta.** `startupProbe` para el arranque (R4), `livenessProbe` contra un endpoint de proceso (R2), `readinessProbe` contra las dependencias (R3).
3. **`requests`/`limits` se fijan con datos**, no a ojo: mira `kubectl top pod` un rato y deja holgura.
4. **Descubrimiento de Prometheus** por anotaciones en el **Service** (`prometheus.io/scrape`, `prometheus.io/port`).

## Procedimiento

```bash
# R1 - metrics-server
../RECURSOS/SCRIPTS/install-metrics-server.sh
kubectl top node
kubectl top pod -n gratitud-api --containers

kubectl apply -f ../RECURSOS/YAML/04-gratitud-probes.yaml   # api y portal SIN sondas

# R2/R3/R4 - las tres sondas (ejemplo para api; portal analogo)
kubectl -n gratitud-api patch deploy api --type=json -p='[
  {"op":"add","path":"/spec/template/spec/containers/0/startupProbe",
   "value":{"httpGet":{"path":"/","port":80},"periodSeconds":5,"failureThreshold":15}},
  {"op":"add","path":"/spec/template/spec/containers/0/livenessProbe",
   "value":{"httpGet":{"path":"/","port":80},"periodSeconds":10,"failureThreshold":3}},
  {"op":"add","path":"/spec/template/spec/containers/0/readinessProbe",
   "value":{"httpGet":{"path":"/","port":80},"periodSeconds":5,"failureThreshold":3}}]'

# R5 - recursos a partir de top
kubectl -n gratitud-api patch deploy api --type=json -p='[
  {"op":"add","path":"/spec/template/spec/containers/0/resources",
   "value":{"requests":{"cpu":"25m","memory":"32Mi"},"limits":{"cpu":"200m","memory":"128Mi"}}}]'

# R6 - descubrimiento Prometheus
kubectl -n gratitud-api annotate svc api \
  prometheus.io/scrape=true prometheus.io/port=80 prometheus.io/path=/metrics
kubectl -n gratitud-api annotate svc portal prometheus.io/scrape=true prometheus.io/port=80
```

Atajo equivalente para todo: `kubectl apply -f ../RECURSOS/YAML/05-gratitud-obs-referencia.yaml`.

## Demostración del comportamiento

```bash
# R2: proceso colgado -> se reinicia
kubectl -n gratitud-api exec deploy/api -- sh -c 'kill -STOP 1'
kubectl -n gratitud-api get pod -l app=gratitud-api -w    # liveness falla -> Killing -> Running de nuevo

# R3: un Pod calentando no recibe trafico
kubectl -n gratitud-api scale deploy/api --replicas=3
kubectl -n gratitud-api get endpoints api -w             # los nuevos entran solo al pasar la readiness
```

## Validación

```bash
kubectl -n kube-system get deploy metrics-server
kubectl top pod -n gratitud-api --containers
kubectl -n gratitud-api get deploy api -o jsonpath='{.spec.template.spec.containers[0].startupProbe.httpGet.path}{" "}{.spec.template.spec.containers[0].livenessProbe.httpGet.path}{" "}{.spec.template.spec.containers[0].readinessProbe.httpGet.path}{"\n"}'
kubectl -n gratitud-api get deploy api -o jsonpath='{.spec.template.spec.containers[0].resources}{"\n"}'
kubectl -n gratitud-api get svc api -o jsonpath='{.metadata.annotations}{"\n"}'
```

## Resultado esperado

* `kubectl top node` y `kubectl top pod -n gratitud-api` devuelven cifras.
* `api` y `portal` con las tres sondas y con `requests`/`limits`.
* Servicios `api` y `portal` con anotaciones `prometheus.io/*`.
* `kill -STOP 1` provoca un reinicio; al escalar, los nuevos Pods entran a los endpoints solo tras la readiness.

## Error frecuente

* Olvidar el parche `--kubelet-insecure-tls` y pelearse con `metrics-server` en `0/1`.
* Apuntar la `livenessProbe` a un endpoint que también comprueba la BD → reinicios en cadena si la BD parpadea.
* `startupProbe` con `failureThreshold × periodSeconds` menor que el arranque real.
* Poner `limits` sin `requests` (o al revés) y que el scheduler no tenga con qué colocar el Pod.
* Anotar el **Deployment** en vez del **Service** (la convención `prometheus.io/*` se lee del Service o del Pod, según la config del scrape).

## CKA Tip

```bash
k top node ; k top pod -A --sort-by=memory
k set probe deploy/api --startup --get-url=http://:80/ --failure-threshold=15 --period-seconds=5
k set resources deploy/api --requests=cpu=25m,memory=32Mi --limits=cpu=200m,memory=128Mi
k annotate svc api prometheus.io/scrape=true prometheus.io/port=80
```
