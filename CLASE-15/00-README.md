# Sesión 15 — Proyecto Integrador y Evaluación

> **Cierre del track especial (sesiones 9–14).** Se despliega el programa
> **GRATITUD** completo de extremo a extremo, se valida cada capa en tiempo real
> y se evalúa con un examen teórico-práctico sobre casos reales.

## Duración

180 minutos.

## Objetivos

Demostrar, sobre una arquitectura de microservicios real, que sabes:

1. Desplegar las **seis capas** a partir de una especificación (Services, Ingress/TLS, Config/Storage, Observabilidad, Seguridad, Helm).
2. Conectar las capas: Ingress, Services entre tiers y un servicio externo.
3. Dar **persistencia** a los datos y **externalizar** la configuración.
4. Proteger los workloads con **sondas**, **límites** y **métricas**.
5. Aplicar **RBAC** de mínimo privilegio, **NetworkPolicy** y **Pod Security**.
6. Empaquetarlo todo como un **chart de Helm** reproducible.
7. **Diagnosticar y reparar** fallos repartidos por las seis capas, contra reloj.

## Contenidos

* **La arquitectura GRATITUD**: portal + API + caché + base de datos externa, un Ingress con TLS, ConfigMap y dos Secrets, un PVC de 1Gi, RBAC acotado, NetworkPolicy `default deny` y Pod Security `restricted`. Especificación en [`RECURSOS/ESPECIFICACION-INTEGRADOR.md`](RECURSOS/ESPECIFICACION-INTEGRADOR.md).
* **Validación de extremo a extremo**: recorrer las seis capas de dentro hacia fuera con `validar-gratitud.sh` y a mano.
* **Evaluación**: un examen **práctico** cronometrado (escenario roto, puntuado con `evaluar.sh` según rúbrica) y un examen **teórico** de casos.

## Mapa del track

| Capa | Sesión | Qué integra |
|---|---|---|
| Services y DNS | S9 | ClusterIP, ExternalName, EndpointSlice, FQDN entre tiers |
| Ingress y TLS | S10 | Ingress por path, Secret `kubernetes.io/tls`, controlador |
| Config y storage | S11 | ConfigMap, Secrets, `envFrom`/`valueFrom`, PVC, StorageClass |
| Observabilidad | S12 | `startup`/`liveness`/`readiness`, `requests`/`limits`, metrics-server |
| Seguridad | S13 | RBAC de mínimo privilegio, NetworkPolicy, Pod Security `restricted` |
| Empaquetado | S14 | Chart de Helm, `values` por entorno |

## Requisitos previos

* `helm` v3, `kubectl` contra un cluster, y `openssl`.
* Un **Ingress Controller** (Traefik — script de la Sesión 10) y **metrics-server** (script de la Sesión 12) instalados.
* CNI que implemente NetworkPolicy (Calico, Cilium…).
* Salida a Internet para `nginxinc/nginx-unprivileged:1.27-alpine`.

## Agenda (180 min)

| Tiempo | Actividad |
|---|---|
| 00–10 | Repaso del track: de la sesión 9 a la 14 |
| 10–25 | La arquitectura a construir y sus criterios de aceptación |
| 25–85 | **LAB 15.1 — Integrador**: desplegar GRATITUD de extremo a extremo |
| 85–110 | **LAB 15.2 — Validación** en tiempo real de las seis capas |
| 110–120 | Formato de la evaluación y errores que cuestan puntos |
| 120–160 | **LAB 15.3 — Examen práctico**: escenario roto, contra reloj |
| 160–175 | **LAB 15.4 — Examen teórico**: casos reales |
| 175–180 | Cierre del módulo Kubernetes |

## Presentación

[`01-CLASE-15-CKA.pptx`](01-CLASE-15-CKA.pptx)

## Laboratorios

| Lab | Nivel | Archivo |
|---|---|---|
| LAB 15.1 | Integrador | [LABORATORIOS/LAB-01-BASICO.md](LABORATORIOS/LAB-01-BASICO.md) |
| LAB 15.2 | Validación | [LABORATORIOS/LAB-02-INTERMEDIO.md](LABORATORIOS/LAB-02-INTERMEDIO.md) |
| LAB 15.3 | Examen práctico | [LABORATORIOS/LAB-03-AVANZADO.md](LABORATORIOS/LAB-03-AVANZADO.md) |
| LAB 15.4 | Examen teórico | [LABORATORIOS/LAB-04-CHALLENGE.md](LABORATORIOS/LAB-04-CHALLENGE.md) |

## Recursos

| Ruta | Uso |
|---|---|
| `RECURSOS/ESPECIFICACION-INTEGRADOR.md` | La especificación que hay que cumplir |
| `RECURSOS/CHART/gratitud/` | Chart de Helm del integrador (6 capas, `values-examen.yaml`) |
| `RECURSOS/SCRIPTS/validar-gratitud.sh` | Validación de extremo a extremo (LAB 15.1 y 15.2) |
| `RECURSOS/SCRIPTS/setup-examen.sh` | Despliega GRATITUD con 9 fallos (LAB 15.3) |
| `RECURSOS/SCRIPTS/evaluar.sh` | Puntuación por área según rúbrica (LAB 15.3) |
| `RECURSOS/SCRIPTS/reset-lab.sh` | Elimina lo creado por la sesión |

## Rúbrica del examen práctico

| Área | Peso |
|---|---|
| Services y DNS | 20 % |
| Ingress y TLS | 15 % |
| Config y storage | 15 % |
| Observabilidad | 15 % |
| Seguridad | 25 % |
| Método | 10 % |

Aprobado: **≥ 80 %** del total.

## Preparación

```bash
alias k=kubectl
cd CLASE-15/RECURSOS/SCRIPTS && chmod +x *.sh
```

Al terminar:

```bash
./reset-lab.sh
```
