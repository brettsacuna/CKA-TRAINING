# Clase 6 — Troubleshooting e Integración

## Duración

180 minutos.

## Objetivos

1. Aplicar un método de diagnóstico reproducible en lugar de ir probando comandos.
2. Reconocer cada estado de Pod y saber a qué capa apunta.
3. Diagnosticar fallos de nodo y de control plane, no solo de aplicación.
4. Resolver escenarios que combinan scheduling, workloads, storage, configuración, permisos y red.
5. Desplegar y reparar una arquitectura completa en el **laboratorio integrador final**.
6. Salir de la clase con un checklist de competencias y una hoja de comandos propia.

## Contenidos

Esta clase **no introduce módulos nuevos**: usa todo lo anterior contra escenarios rotos.

* Método general: `observar -> acotar la capa -> formular hipótesis -> verificar -> corregir -> validar`.
* Estados de Pod y su significado: `Pending`, `ContainerCreating`, `ImagePullBackOff`, `CreateContainerConfigError`, `CrashLoopBackOff`, `Running 0/1`, `OOMKilled`, `Error`, `Evicted`, `Terminating`.
* Troubleshooting de nodo: `NotReady`, `SchedulingDisabled`, kubelet parado, disco lleno, runtime caído.
* Troubleshooting del control plane: static Pods, `crictl`, logs del kubelet, certificados expirados.
* Los seis mental models del curso, aplicados juntos.
* Uso eficiente de `kubectl` bajo presión de tiempo.

## Agenda (180 min)

| Tiempo | Actividad |
|---|---|
| 00–12 | Método de diagnóstico y mapa de estados |
| 12–30 | **Demo**: cinco Pods rotos, cinco causas distintas, en 15 minutos |
| 30–50 | **LAB 6.1 — Básico**: identificar el estado y la capa |
| 50–78 | **LAB 6.2 — Intermedio**: nodo y control plane |
| 78–105 | **LAB 6.3 — Avanzado**: cadena de fallos entre capas |
| 105–120 | **LAB 6.4 — Challenge**: contrarreloj, 15 minutos |
| 120–170 | **LAB 6.5 — INTEGRADOR FINAL** |
| 170–178 | Checklist CKA y Cheat Sheet |
| 178–180 | Cierre del curso |

## Presentación

[`01-CLASE-06-CKA.pptx`](01-CLASE-06-CKA.pptx)

## Laboratorios

| Lab | Nivel | Archivo |
|---|---|---|
| LAB 6.1 | Básico | [LABORATORIOS/LAB-01-BASICO.md](LABORATORIOS/LAB-01-BASICO.md) |
| LAB 6.2 | Intermedio | [LABORATORIOS/LAB-02-INTERMEDIO.md](LABORATORIOS/LAB-02-INTERMEDIO.md) |
| LAB 6.3 | Avanzado | [LABORATORIOS/LAB-03-AVANZADO.md](LABORATORIOS/LAB-03-AVANZADO.md) |
| LAB 6.4 | Challenge | [LABORATORIOS/LAB-04-CHALLENGE.md](LABORATORIOS/LAB-04-CHALLENGE.md) |
| LAB 6.5 | **Integrador final** | [LABORATORIOS/LAB-05-INTEGRADOR-FINAL.md](LABORATORIOS/LAB-05-INTEGRADOR-FINAL.md) |

## Material adicional

* [`02-CHECKLIST-CKA.md`](02-CHECKLIST-CKA.md) — competencias trabajadas durante las 18 horas.
* [`03-CHEATSHEET-CKA.md`](03-CHEATSHEET-CKA.md) — comandos agrupados por dominio.

## Recursos

[`RECURSOS/YAML/`](RECURSOS/YAML/) · [`RECURSOS/SCRIPTS/`](RECURSOS/SCRIPTS/)

## Los seis mental models

```
POD                 SCHEDULING            SERVICE
get                 Pending               Service
 v                   v                     v
describe            Events                selector
 v                   v                     v
events              Recursos              EndpointSlice
 v                   v                     v
logs                nodeSelector          Pod labels
 v                   v                     v
logs --previous     Affinity              targetPort
                     v
                    Taints / Tolerations

STORAGE             RBAC                  NETWORKING
PVC                 Identity              Pod
 v                   v                     v
StorageClass        Role / ClusterRole    Service
 v                   v                     v
PV                  Binding               EndpointSlice
 v                   v                     v
AccessMode          Resource              DNS
 v                   v                     v
Capacity            Verb                  NetworkPolicy
 v                   v                     v
Pod                 auth can-i            Ingress
```

## Checklist final de la clase

- [ ] Identifico la capa del fallo antes de tocar nada.
- [ ] Traduzco cada estado de Pod a su causa probable.
- [ ] Diagnostico un nodo `NotReady`.
- [ ] Recupero un control plane con un static Pod mal escrito.
- [ ] Resuelvo una cadena de fallos que cruza varias capas.
- [ ] Trabajo contrarreloj sin perder el método.
- [ ] Despliego la arquitectura completa del laboratorio integrador.
- [ ] Reparo las fallas inyectadas y valido el resultado.
