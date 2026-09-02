# Sesión 12 — Salud de Aplicaciones y Observabilidad

> **Sesión especial.** El enunciado traía el título de otra sesión
> («Almacenamiento Persistente en el Clúster»); el contenido real —y este
> material— es **sondas de salud, troubleshooting, logs y monitoreo**. Continúa
> el programa GRATITUD: le pone sondas, define el kit de diagnóstico y presenta
> la arquitectura de monitoreo con metrics-server, Prometheus y Grafana.

## Duración

180 minutos.

## Objetivos

1. Configurar **liveness**, **readiness** y **startup** probes y saber qué desencadena cada una.
2. Elegir el *handler* correcto: `httpGet`, `tcpSocket`, `exec` o `grpc`, y ajustar la temporización.
3. Diagnosticar un Pod con `kubectl describe`, `logs --previous`, `exec`, `top` y `get events`.
4. Reconocer `CrashLoopBackOff`, `OOMKilled`, `ImagePullBackOff` y `Pending` por su causa.
5. Leer y seguir logs con `kubectl logs`: `-f`, `--previous`, `--since`, `--tail`, por label.
6. Explicar **metrics-server** frente a **Prometheus**, y para qué sirve cada uno.
7. Describir la arquitectura de monitoreo: App `/metrics` → Prometheus → Alertmanager / Grafana.

## Contenidos

* **Sondas.** Qué hace cada una (liveness reinicia; readiness corta tráfico; startup da margen). *Handlers* y campos (`initialDelaySeconds`, `periodSeconds`, `timeoutSeconds`, `failureThreshold`, `successThreshold`). El error clásico: liveness contra una dependencia externa.
* **Troubleshooting.** El kit en orden: `describe` → `logs [--previous]` → `exec` / `debug` → `top` → `get events`. Estados de Pod y dónde mirar.
* **Logs.** A `stdout`/`stderr`, no a ficheros. `kubectl logs` con todas sus banderas. Centralización (DaemonSet recolector + backend con búsqueda: EFK / Loki) como patrón institucional.
* **Métricas.** `metrics-server` (una muestra reciente en memoria, para `kubectl top` y el HPA) frente a **Prometheus** (series temporales, PromQL, retención, alertas). Modelo *pull* sobre `/metrics`. Descubrimiento por anotaciones o `ServiceMonitor`.
* **Prometheus + Grafana.** App/exporters → Prometheus (scrape + TSDB) → PromQL/reglas → Alertmanager; Grafana = tableros. `kube-prometheus-stack`.

## El programa GRATITUD en esta sesión

* **`gratitud-api`**: al Deployment `api` (y a `portal`) se les añaden `startupProbe`, `livenessProbe` (proceso) y `readinessProbe` (dependencias), más `requests`/`limits` coherentes con lo que muestra `kubectl top`.
* Los Services `api` y `portal` se anotan con `prometheus.io/scrape` y `prometheus.io/port`.
* El **LAB 12.4** rompe esta configuración: liveness agresiva (CrashLoop), readiness al puerto equivocado (0 endpoints), `limits.memory` bajo (OOMKilled) y un componente que escribe sus logs a un fichero (`kubectl logs` vacío).

## Agenda (180 min)

| Tiempo | Actividad |
|---|---|
| 00–10 | Por qué un Pod «arriba» no siempre está sano |
| 10–30 | Conceptos: liveness, readiness, startup y sus *handlers* |
| 30–52 | **LAB 12.1 — Básico**: las tres sondas en acción |
| 52–70 | Conceptos: el kit de troubleshooting y los estados de Pod |
| 70–102 | **LAB 12.2 — Intermedio**: diagnosticar cuatro Pods rotos |
| 102–120 | Conceptos: logs, metrics-server, Prometheus y Grafana |
| 120–150 | **LAB 12.3 — Avanzado**: sondas, `top` y métricas para GRATITUD |
| 150–170 | **LAB 12.4 — Challenge**: «GRATITUD está degradado» |
| 170–180 | Cierre y CKA Tips |

## Presentación

[`01-CLASE-12-CKA.pptx`](01-CLASE-12-CKA.pptx)

## Laboratorios

| Lab | Nivel | Archivo |
|---|---|---|
| LAB 12.1 | Básico | [LABORATORIOS/LAB-01-BASICO.md](LABORATORIOS/LAB-01-BASICO.md) |
| LAB 12.2 | Intermedio | [LABORATORIOS/LAB-02-INTERMEDIO.md](LABORATORIOS/LAB-02-INTERMEDIO.md) |
| LAB 12.3 | Avanzado | [LABORATORIOS/LAB-03-AVANZADO.md](LABORATORIOS/LAB-03-AVANZADO.md) |
| LAB 12.4 | Challenge | [LABORATORIOS/LAB-04-CHALLENGE.md](LABORATORIOS/LAB-04-CHALLENGE.md) |

## Recursos

[`RECURSOS/YAML/`](RECURSOS/YAML/) · [`RECURSOS/SCRIPTS/`](RECURSOS/SCRIPTS/)

| Archivo | Uso |
|---|---|
| `YAML/01-probes-demo.yaml` | App de prueba del LAB 12.1 (sin sondas, para añadirlas) |
| `YAML/02-probes-tres.yaml` | La misma app con las tres sondas bien configuradas (referencia) |
| `YAML/03-diagnostico-pods.yaml` | Cuatro Pods rotos del LAB 12.2 (ImagePull, Crash, OOM, Pending) |
| `YAML/04-gratitud-probes.yaml` | `api` y `portal` de GRATITUD con sondas, recursos y anotaciones (LAB 12.3) |
| `YAML/05-gratitud-obs-referencia.yaml` | Referencia completa |
| `SCRIPTS/install-metrics-server.sh` | Instala metrics-server (para `kubectl top` y el HPA) |
| `SCRIPTS/setup-lab.sh` | Despliega el escenario **degradado** del LAB 12.4 |
| `SCRIPTS/validate-lab.sh` | Comprueba el LAB 12.4 |
| `SCRIPTS/reset-lab.sh` | Elimina lo creado por la sesión |

## Preparación

```bash
alias k=kubectl
cd CLASE-12/RECURSOS/SCRIPTS && chmod +x *.sh
```

Al terminar:

```bash
./reset-lab.sh
```

## Checklist final de la sesión

- [ ] Explico qué desencadena liveness, readiness y startup.
- [ ] Sé por qué una liveness contra la BD es un error, y por qué la readiness sí puede mirarla.
- [ ] Elijo `httpGet`, `tcpSocket`, `exec` o `grpc` según el caso.
- [ ] Calculo el presupuesto de detección de una sonda.
- [ ] Diagnostico con `describe → logs --previous → exec → top → events`.
- [ ] Reconozco `OOMKilled`, `CrashLoopBackOff`, `ImagePullBackOff` y `Pending`.
- [ ] Sigo logs con `-f`, `--previous`, `--since`, `--tail` y por label.
- [ ] Sé por qué `kubectl logs` sale vacío si la app escribe a un fichero.
- [ ] Distingo `metrics-server` de Prometheus y para qué es cada uno.
- [ ] Describo el flujo App → Prometheus → Alertmanager / Grafana.
