# Clase 1 — Pods, YAML, Services y Scheduling

## Duración

180 minutos.

## Objetivos

Al finalizar la clase el participante podrá:

1. Crear Pods de forma imperativa y declarativa, y decidir cuándo usar cada vía.
2. Generar manifiestos rápidamente con `--dry-run=client -o yaml` y `kubectl explain`.
3. Usar labels y selectors para agrupar y seleccionar objetos.
4. Exponer Pods con Services `ClusterIP` y `NodePort`, y comprender la cadena `Service -> selector -> EndpointSlice -> Pod`.
5. Resolver servicios por DNS dentro del cluster.
6. Controlar dónde se ejecuta un Pod: labels de nodo, `nodeSelector`, taints, tolerations, node affinity, pod (anti-)affinity, PriorityClass y preemption.
7. Diagnosticar un Pod en estado `Pending` y un Service sin endpoints.

## Contenidos

* Pod como unidad de despliegue. Ciclo de vida y estados.
* YAML: `apiVersion`, `kind`, `metadata`, `spec`. `kubectl explain`.
* Imperativo vs declarativo. `kubectl run`, `create`, `apply`, `edit`, `patch`, `replace --force`.
* Inspección: `get`, `describe`, `logs`, `logs --previous`, `exec`, `get events`.
* Labels, selectors, `kubectl label`.
* Services: `ClusterIP`, `NodePort`. `port`, `targetPort`, `nodePort`. `kubectl expose`.
* EndpointSlice y por qué un Service puede quedarse vacío.
* DNS de servicios: `<svc>.<ns>.svc.cluster.local`.
* Scheduling: labels de nodo, `nodeSelector`, Taints y Tolerations, `nodeAffinity`
  (`requiredDuringSchedulingIgnoredDuringExecution` / `preferredDuringSchedulingIgnoredDuringExecution`, `weight`),
  `podAffinity` / `podAntiAffinity`, `topologyKey`.
* PriorityClass, `priority`, `preemptionPolicy` y preemption.
* Mental model de scheduling: `Pending -> events -> recursos -> nodeSelector -> affinity -> taints`.

## Agenda (180 min)

| Tiempo | Actividad |
|---|---|
| 00–15 | Presentación, entorno, alias y atajos de examen |
| 15–45 | Conceptos: Pod, YAML, labels/selectors, Services |
| 45–65 | **Demo del instructor**: crear → inspeccionar → exponer → romper el selector → reparar |
| 65–90 | **LAB 1.1 — Básico**: Pods, YAML e inspección |
| 90–120 | **LAB 1.2 — Intermedio**: Services, EndpointSlice y DNS |
| 120–128 | Conceptos: scheduling (nodeSelector, taints, affinity, priority) |
| 128–155 | **LAB 1.3 — Avanzado**: colocación de Pods por requerimientos |
| 155–175 | **LAB 1.4 — Challenge**: Pod Pending y Service sin endpoints |
| 175–180 | Cierre, mental models y CKA Tips |

## Presentación

[`01-CLASE-01-CKA.pptx`](01-CLASE-01-CKA.pptx)

## Laboratorios

| Lab | Nivel | Archivo |
|---|---|---|
| LAB 1.1 | Básico | [LABORATORIOS/LAB-01-BASICO.md](LABORATORIOS/LAB-01-BASICO.md) |
| LAB 1.2 | Intermedio | [LABORATORIOS/LAB-02-INTERMEDIO.md](LABORATORIOS/LAB-02-INTERMEDIO.md) |
| LAB 1.3 | Avanzado | [LABORATORIOS/LAB-03-AVANZADO.md](LABORATORIOS/LAB-03-AVANZADO.md) |
| LAB 1.4 | Challenge | [LABORATORIOS/LAB-04-CHALLENGE.md](LABORATORIOS/LAB-04-CHALLENGE.md) |

## Recursos

* Manifiestos: [`RECURSOS/YAML/`](RECURSOS/YAML/)
* Scripts: [`RECURSOS/SCRIPTS/`](RECURSOS/SCRIPTS/) — `setup-lab.sh`, `reset-lab.sh`, `validate-lab.sh`

## Checklist final de la clase

- [ ] Creo un Pod imperativa y declarativamente.
- [ ] Genero YAML con `--dry-run=client -o yaml` sin copiar de la documentación.
- [ ] Uso `kubectl explain` para recordar un campo.
- [ ] Etiqueto objetos y los filtro con `-l`.
- [ ] Expongo un Pod con ClusterIP y con NodePort.
- [ ] Explico por qué un Service tiene 0 endpoints y lo reparo.
- [ ] Resuelvo un Service por DNS desde otro Pod.
- [ ] Fuerzo un Pod a un nodo concreto con `nodeSelector`.
- [ ] Aplico y tolero un taint.
- [ ] Escribo `nodeAffinity` required y preferred.
- [ ] Uso `podAntiAffinity` para repartir réplicas.
- [ ] Diagnostico un `FailedScheduling` leyendo los eventos.
