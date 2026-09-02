# LAB 12.3 — Sondas, `top` y métricas para GRATITUD

## Nivel

Avanzado.

## Duración

30 minutos.

## Objetivo

Dar a la API y al portal de GRATITUD sondas correctas y límites de recursos
coherentes, dejar `kubectl top` operativo y exponer sus métricas para que un
Prometheus pueda recogerlas —todo **a partir de requerimientos**.

## Competencias

* Instalar y validar metrics-server.
* Diseñar las tres sondas para una aplicación real (proceso vs. dependencias).
* Fijar `requests`/`limits` a partir de datos de `kubectl top`.
* Preparar un workload para el descubrimiento de Prometheus.

## Escenario

Operaciones exige lo siguiente para los Deployments `api` y `portal` del
namespace **`gratitud-api`**:

| # | Requisito |
|---|---|
| R1 | `kubectl top node` y `kubectl top pod -n gratitud-api` deben funcionar. |
| R2 | Un **proceso colgado** (que deja de responder pero no muere) debe **reiniciarse** solo. |
| R3 | Un Pod **recién arrancado o calentando** **no** debe recibir tráfico hasta estar listo. |
| R4 | Un arranque lento (hasta ~1 min) **no** debe provocar reinicios. |
| R5 | Cada contenedor debe declarar `requests` y `limits` de CPU y memoria coherentes con su consumo real. |
| R6 | Los Services `api` y `portal` deben quedar **descubribles por Prometheus** (anotaciones `prometheus.io/*`). |

Tú decides las sondas, los umbrales y los valores de recursos.

## Estado inicial

* Namespace `gratitud-api` con `api` y `portal` desplegados (sin sondas ni recursos).
  ```bash
  kubectl apply -f ../RECURSOS/YAML/04-gratitud-probes.yaml   # trae api y portal SIN sondas
  ```
* `helm` no es necesario.

## Pistas de método (no de solución)

* metrics-server: `../RECURSOS/SCRIPTS/install-metrics-server.sh`. En kubeadm de laboratorio suele hacer falta `--kubelet-insecure-tls` (el script lo explica).
* `startupProbe` con `failureThreshold` alto y `periodSeconds` bajo = margen de arranque = `failureThreshold × periodSeconds`.
* `livenessProbe` → un endpoint que solo diga «el proceso responde» (no la BD).
* `readinessProbe` → un endpoint que compruebe dependencias; puede fallar sin reiniciar.
* Mira `kubectl top pod` un rato bajo carga antes de fijar `limits`.
* Descubrimiento Prometheus: `annotations` en el **Service** — `prometheus.io/scrape: "true"`, `prometheus.io/port: "<puerto>"`, `prometheus.io/path: "/metrics"`.

## Validación

```bash
kubectl -n kube-system get deploy metrics-server
kubectl top node
kubectl top pod -n gratitud-api --containers

# sondas presentes y con sentido
kubectl -n gratitud-api get deploy api -o jsonpath='{range .spec.template.spec.containers[0]}{.startupProbe.httpGet.path}{" | "}{.livenessProbe.httpGet.path}{" | "}{.readinessProbe.httpGet.path}{"\n"}{end}'

# recursos
kubectl -n gratitud-api get deploy api    -o jsonpath='{.spec.template.spec.containers[0].resources}{"\n"}'
kubectl -n gratitud-api get deploy portal -o jsonpath='{.spec.template.spec.containers[0].resources}{"\n"}'

# anotaciones de descubrimiento
kubectl -n gratitud-api get svc api -o jsonpath='{.metadata.annotations}{"\n"}'

# comportamiento
kubectl -n gratitud-api exec deploy/api -- sh -c 'kill -STOP 1'   # cuelga el proceso -> debe reiniciarse
kubectl -n gratitud-api get pod -l app=gratitud-api -w
```

## Resultado esperado

* `kubectl top node` y `kubectl top pod -n gratitud-api` devuelven cifras.
* `api` y `portal` con `startupProbe`, `livenessProbe` y `readinessProbe`.
* `requests`/`limits` de CPU y memoria en ambos, en el orden de magnitud de `kubectl top`.
* Los Services `api` y `portal` con anotaciones `prometheus.io/scrape` y `prometheus.io/port`.
* Un proceso colgado (`kill -STOP 1`) provoca un reinicio; un Pod calentando no aparece en los endpoints.

## Criterios de éxito

- [ ] metrics-server instalado; `kubectl top` funciona.
- [ ] `api` y `portal` con las tres sondas, cada una en su endpoint correcto.
- [ ] El `startupProbe` da ≥ 1 min de margen sin que la liveness intervenga.
- [ ] `requests`/`limits` fijados a partir de `kubectl top`, no a ojo.
- [ ] Los Services quedan descubribles por Prometheus.
- [ ] Demostré el reinicio por proceso colgado y el corte de tráfico por readiness.
