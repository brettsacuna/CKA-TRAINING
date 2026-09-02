# Clase 5 — Services, Ingress, Networking, CoreDNS y NetworkPolicy

## Duración

180 minutos.

## Objetivos

1. Elegir el tipo de Service correcto para cada necesidad de publicación.
2. Explicar el modelo de red de Kubernetes: Pod-to-Pod, Pod-to-Service y entrada desde fuera.
3. Resolver nombres con CoreDNS y diagnosticar un fallo de resolución.
4. Publicar varias aplicaciones tras una sola entrada con Ingress, incluyendo HTTPS con un TLS Secret.
5. Conocer el estado actual del ecosistema de Ingress Controllers y la posición de Gateway API.
6. Escribir NetworkPolicies de Ingress y Egress, incluyendo `default deny`.
7. Diagnosticar tráfico bloqueado distinguiendo DNS, Service, NetworkPolicy e Ingress.

## Contenidos

* Tipos de Service: `ClusterIP`, `NodePort`, `LoadBalancer`, `ExternalName`. Headless.
* `kube-proxy`, EndpointSlice y cómo llega realmente un paquete a un Pod.
* CoreDNS: `<svc>.<ns>.svc.cluster.local`, registros por Pod de StatefulSet, `/etc/resolv.conf` del Pod, `ndots`.
* Diagnóstico DNS: `nslookup`, `dig`, logs de CoreDNS, ConfigMap `coredns`.
* Ingress: API, reglas por host y por path, `pathType`, `ingressClassName`, `defaultBackend`.
* Ingress Controller = reverse proxy L7. TLS Secret (`kubernetes.io/tls`).
* **Gateway API**: `GatewayClass`, `Gateway`, `HTTPRoute`. Separación de responsabilidades.
* NetworkPolicy: `podSelector`, `policyTypes`, `ingress`, `egress`, `namespaceSelector`, `ipBlock`.
* Default deny. Políticas aditivas: la unión de todas las que seleccionan un Pod.
* Por qué una NetworkPolicy de Egress rompe el DNS si no se permite el puerto 53.

## Actualizaciones técnicas respecto al material original

| Tema | Estado | Cambio aplicado |
|---|---|---|
| `kubernetes/ingress-nginx` | **RETIRADO (marzo 2026)** | Repositorio archivado, sin parches de seguridad. Los laboratorios usan un controlador mantenido (**Traefik**) |
| Manifiesto `cks-course-environment/.../nginx-ingress-controller.yaml` | **LEGACY** | URL obsoleta. Se instala el controlador desde su fuente oficial actual |
| Ingress como única forma de publicar | **AMPLIADO** | Se añade **Gateway API**, presente en el currículum CKA vigente |
| `kubectl get ep` | **REQUIERE ACTUALIZACIÓN** | Se usa `kubectl get endpointslices` |
| Certificado autofirmado con `openssl` | **VIGENTE** | Se conserva; sigue siendo lo que se pide en el examen |
| NetworkPolicy `backend.yml` del material original | **CONTENÍA UN ERROR** | El `podSelector` decía `run: frontend` cuando debía decir `run: backend`. Corregido y usado como ejercicio de diagnóstico |

> **Aviso.** Si tu cluster tiene instalado `ingress-nginx`, sigue funcionando, pero no recibe parches desde marzo de 2026. Este curso lo trata como deuda técnica, no como opción por defecto.

## Agenda (180 min)

| Tiempo | Actividad |
|---|---|
| 00–10 | Repaso Clase 4 y objetivos |
| 10–30 | Conceptos: modelo de red, tipos de Service, EndpointSlice |
| 30–45 | Conceptos: CoreDNS y resolución de nombres |
| 45–68 | **LAB 5.1 — Básico**: Services y DNS |
| 68–85 | Conceptos: Ingress, Ingress Controller, TLS y Gateway API |
| 85–120 | **LAB 5.2 — Intermedio**: Ingress con HTTP y HTTPS |
| 120–133 | Conceptos: NetworkPolicy |
| 133–160 | **LAB 5.3 — Avanzado**: aislar frontend y backend |
| 160–176 | **LAB 5.4 — Challenge**: tráfico bloqueado |
| 176–180 | Cierre y CKA Tips |

## Presentación

[`01-CLASE-05-CKA.pptx`](01-CLASE-05-CKA.pptx)

## Laboratorios

| Lab | Nivel | Archivo |
|---|---|---|
| LAB 5.1 | Básico | [LABORATORIOS/LAB-01-BASICO.md](LABORATORIOS/LAB-01-BASICO.md) |
| LAB 5.2 | Intermedio | [LABORATORIOS/LAB-02-INTERMEDIO.md](LABORATORIOS/LAB-02-INTERMEDIO.md) |
| LAB 5.3 | Avanzado | [LABORATORIOS/LAB-03-AVANZADO.md](LABORATORIOS/LAB-03-AVANZADO.md) |
| LAB 5.4 | Challenge | [LABORATORIOS/LAB-04-CHALLENGE.md](LABORATORIOS/LAB-04-CHALLENGE.md) |

## Recursos

[`RECURSOS/YAML/`](RECURSOS/YAML/) · [`RECURSOS/SCRIPTS/`](RECURSOS/SCRIPTS/) (incluye `install-ingress-controller.sh` y `gen-tls-secret.sh`)

> **Requisito de CNI.** Las NetworkPolicies solo funcionan si el plugin CNI las implementa (Calico, Cilium, Weave…). Con un CNI que no las soporte, los manifiestos se aplican pero **no bloquean nada**. Verifícalo antes del LAB 5.3.

## Checklist final de la clase

- [ ] Elijo el tipo de Service adecuado y sé qué hace cada uno.
- [ ] Explico la cadena `Service -> EndpointSlice -> Pod`.
- [ ] Resuelvo un Service por su FQDN y sé leer `/etc/resolv.conf` de un Pod.
- [ ] Diagnostico un fallo de DNS distinguiéndolo de un fallo de endpoints.
- [ ] Publico dos aplicaciones por path con un solo Ingress.
- [ ] Creo un TLS Secret y lo asocio a un Ingress.
- [ ] Explico qué es Gateway API y por qué existe.
- [ ] Escribo una NetworkPolicy `default deny`.
- [ ] Permito tráfico frontend → backend con Ingress y Egress.
- [ ] Sé por qué una política de Egress puede romper el DNS y cómo evitarlo.
