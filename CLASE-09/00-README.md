# Sesión 9 — Networking en Kubernetes (Services)

> **Sesión especial.** Amplía el bloque de Services de la Clase 5 con una sesión
> dedicada: la IP efímera del Pod, los tres tipos de Service que se piden en el
> examen, el papel de labels/selectores y anotaciones, y la comunicación entre
> namespaces. Hilo conductor: el programa **GRATITUD**.

## Duración

180 minutos.

## Objetivos

1. Explicar por qué la dirección IP de un Pod es efímera y qué integración concreta rompe.
2. Elegir entre `ClusterIP`, `NodePort` y `LoadBalancer` según quién tenga que alcanzar el servicio.
3. Describir cómo el selector de labels de un Service construye su `EndpointSlice` (descubrimiento dinámico).
4. Distinguir para qué sirven las **labels y los selectores** y para qué las **anotaciones** en un Service.
5. Diferenciar `port`, `targetPort` y `nodePort` sin dudar.
6. Resolver un Service de otro namespace por su **FQDN** y saber cuándo es imprescindible.
7. Conectar los tres tramos del programa GRATITUD (`gratitud-frontend` → `gratitud-api` → `gratitud-datos`).
8. Modelar un servicio externo con `ExternalName`.
9. Diagnosticar un Service sin endpoints separando selector, puerto y namespace.

## Contenidos

* **La IP efímera.** Cómo se asigna la IP de un Pod, por qué no sobrevive a un reinicio ni a un reschedule, y qué rompe apuntar a ella.
* **ClusterIP.** IP virtual, `kube-proxy` (iptables / IPVS), la cadena `Service → EndpointSlice → Pod`.
* **Tipos de Service.** `ClusterIP`, `NodePort` (rango 30000–32767), `LoadBalancer` (una IP por Service, `pending` sin integración de nube). Casos aparte: `ExternalName` y `headless`.
* **Los tres puertos.** `port` (del Service), `targetPort` (del contenedor), `nodePort` (del nodo).
* **Descubrimiento dinámico.** El selector del Service, el controlador de endpoints y los `EndpointSlice`. Por qué una label que no cuadra deja un Service sin endpoints.
* **Labels vs. anotaciones.** Las labels identifican y emparejan; las anotaciones configuran controladores y guardan metadatos. Las anotaciones de `LoadBalancer` no son portables entre nubes.
* **Resolución entre namespaces.** `<svc>.<ns>.svc.cluster.local`, la línea `search` del `/etc/resolv.conf`, cuándo hace falta el FQDN. El namespace separa nombres, no red.
* **Programa GRATITUD.** Tres namespaces por responsabilidad, un `NodePort` como única entrada, `ClusterIP` para el tráfico interno, `ExternalName` para la base de datos externa.

## El programa GRATITUD

Aplicación de ejemplo repartida en tres namespaces:

| Namespace | Workload | Service | Rol |
|---|---|---|---|
| `gratitud-frontend` | Deployment `portal` (`nginx:1.27-alpine`) | `portal-np` — **NodePort** `31900` | Portal web. Única entrada desde fuera. Llama a `api.gratitud-api`. |
| `gratitud-api` | Deployment `api` (`nginxinc/nginx-unprivileged:1.27-alpine`, escucha en **8080**) | `api` — **ClusterIP** `80 → 8080` | Lógica de negocio. Llama a `cache.gratitud-datos` y a `db-externa`. |
| `gratitud-datos` | Deployment `cache` (`nginx:1.27-alpine`) | `cache` — **ClusterIP** · `db-externa` — **ExternalName** → `db.corp.example.com` | Caché y acceso a datos. |

Etiquetas comunes: `part-of=gratitud`, `tier={frontend|api|datos}`, `app=gratitud-{portal|api|cache}`.

```
                 curl http://<IP-NODO>:31900
                            |
   gratitud-frontend   [ portal-np : NodePort ] --> Pods portal
                            |  curl http://api.gratitud-api
   gratitud-api        [ api : ClusterIP 80->8080 ] --> Pods api
                            |  curl http://cache.gratitud-datos
   gratitud-datos      [ cache : ClusterIP ] --> Pods cache
                       [ db-externa : ExternalName ] --> db.corp.example.com
```

## Agenda (180 min)

| Tiempo | Actividad |
|---|---|
| 00–10 | El problema: la IP efímera del Pod |
| 10–30 | Conceptos: ClusterIP, `kube-proxy` y EndpointSlice |
| 30–52 | **LAB 9.1 — Básico**: la IP que desaparece y el ClusterIP |
| 52–70 | Conceptos: NodePort, LoadBalancer, labels y anotaciones |
| 70–100 | **LAB 9.2 — Intermedio**: publicar y descubrir por labels |
| 100–115 | Conceptos: FQDN y comunicación entre namespaces |
| 115–145 | **LAB 9.3 — Avanzado**: conectar el programa GRATITUD |
| 145–165 | **LAB 9.4 — Challenge**: «GRATITUD no conecta» |
| 165–180 | Cierre y CKA Tips |

## Presentación

[`01-CLASE-09-CKA.pptx`](01-CLASE-09-CKA.pptx)

## Laboratorios

| Lab | Nivel | Archivo |
|---|---|---|
| LAB 9.1 | Básico | [LABORATORIOS/LAB-01-BASICO.md](LABORATORIOS/LAB-01-BASICO.md) |
| LAB 9.2 | Intermedio | [LABORATORIOS/LAB-02-INTERMEDIO.md](LABORATORIOS/LAB-02-INTERMEDIO.md) |
| LAB 9.3 | Avanzado | [LABORATORIOS/LAB-03-AVANZADO.md](LABORATORIOS/LAB-03-AVANZADO.md) |
| LAB 9.4 | Challenge | [LABORATORIOS/LAB-04-CHALLENGE.md](LABORATORIOS/LAB-04-CHALLENGE.md) |

## Recursos

[`RECURSOS/YAML/`](RECURSOS/YAML/) · [`RECURSOS/SCRIPTS/`](RECURSOS/SCRIPTS/)

| Archivo | Uso |
|---|---|
| `YAML/01-pod-ip-efimera.yaml` | Deployment `web` del LAB 9.1 |
| `YAML/02-service-clusterip.yaml` | Service `web-ci` (ClusterIP) del LAB 9.1 |
| `YAML/03-nodeport-loadbalancer.yaml` | Los tres tipos de Service sobre el mismo Deployment (LAB 9.2) |
| `YAML/04-labels-anotaciones.yaml` | Service con anotaciones + Deployment con labels de versión (LAB 9.2) |
| `YAML/05-gratitud-namespaces.yaml` | Punto de partida del LAB 9.3: namespaces y Deployments (sin Services) |
| `YAML/06-gratitud-referencia.yaml` | Referencia completa de GRATITUD (namespaces, Deployments, Services, ExternalName) |
| `SCRIPTS/setup-lab.sh` | Despliega el escenario **roto** del LAB 9.4 |
| `SCRIPTS/validate-lab.sh` | Comprueba el LAB 9.4 |
| `SCRIPTS/reset-lab.sh` | Elimina todo lo creado por la sesión |

> **Sin dependencia de CNI ni de nube.** Nada de esta sesión necesita NetworkPolicy
> ni un `LoadBalancer` real: los Service de tipo `LoadBalancer` se observan en
> estado `pending` a propósito. El aislamiento del tráfico de GRATITUD se trata en
> la sesión de NetworkPolicy.

## Preparación

```bash
alias k=kubectl
export do='--dry-run=client -o yaml'
```

Al terminar:

```bash
cd CLASE-09/RECURSOS/SCRIPTS && ./reset-lab.sh
```

## Checklist final de la sesión

- [ ] Explico por qué la IP de un Pod es efímera y qué integración rompe apuntar a ella.
- [ ] Elijo `ClusterIP`, `NodePort` o `LoadBalancer` según quién deba llegar.
- [ ] Describo la cadena `Service → EndpointSlice → Pod` y quién balancea.
- [ ] Sé que el **selector** construye el `EndpointSlice` y qué pasa si no cuadra con las labels.
- [ ] Distingo para qué es una **label** y para qué una **anotación** en un Service.
- [ ] Diferencio `port`, `targetPort` y `nodePort`.
- [ ] Resuelvo un Service de otro namespace por su FQDN y sé leer la línea `search`.
- [ ] Conecto `portal → api → datos` entre los namespaces de GRATITUD.
- [ ] Modelo un servicio externo con `ExternalName`.
- [ ] Diagnostico un Service sin endpoints separando selector, puerto y namespace.
