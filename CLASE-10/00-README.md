# Sesión 10 — Control de Tráfico Excluyente (Ingress)

> **Sesión especial.** Continúa el programa GRATITUD: pone un **Ingress
> Controller** delante de los Services internos y decide, por host y por path,
> quién entra y a dónde. Termina TLS en el borde y balancea en capa 7.

## Duración

180 minutos.

## Objetivos

1. Explicar qué añade un Ingress Controller sobre un Service `NodePort` o `LoadBalancer`.
2. Distinguir el **objeto Ingress** (reglas) del **controlador** (el proxy que las ejecuta) y el papel de `ingressClassName`.
3. Enrutar por **path** y por **host** tras una única entrada, con el `pathType` correcto.
4. Terminar **TLS** en el borde con un Secret `kubernetes.io/tls` y probarlo con `curl --resolve`.
5. Describir el **balanceo de capa 7** del controlador frente al de `kube-proxy`.
6. Publicar el portal, la API, la documentación y el panel de GRATITUD tras un solo Ingress.
7. Diagnosticar un Ingress que no enruta: clase, backend, `pathType` o TLS.

## Contenidos

* **Ingress vs. Service.** Capa 4 (conexiones) frente a capa 7 (peticiones). Una entrada para muchas aplicaciones.
* **Objeto y controlador.** El Ingress declara host/path/Service/puerto/Secret; el controlador (Deployment aparte) lo ejecuta. `ingressClassName` ↔ `IngressClass`. Sin controlador, ADDRESS vacío y ningún error.
* **Estado del ecosistema (2026).** `kubernetes/ingress-nginx` retirado en marzo de 2026. La API Ingress sigue vigente; el curso usa **Traefik**, mantenido.
* **Enrutamiento.** `pathType` (`Prefix`, `Exact`, `ImplementationSpecific`). Reglas por host, por path y combinadas. `defaultBackend`. Precedencia por path más largo. Reescritura de path (anotación propietaria).
* **TLS.** Sección `spec.tls`, Secret `kubernetes.io/tls` (`tls.crt` + `tls.key`) en el mismo namespace. Terminación en el borde, selección por SNI, certificado por defecto del controlador.
* **Balanceo L7.** Reparto petición a petición, afinidad por cookie, reintentos, health checks activos; frente al reparto por conexión de `kube-proxy`.

## El programa GRATITUD en esta sesión

Todo el frente web de GRATITUD vive en el namespace **`gratitud-web`** (los
laboratorios 10.2–10.4 son autocontenidos; no dependen de los namespaces de la
Sesión 9):

| Deployment | Imagen | Puerto | Service | Ruta pública |
|---|---|---|---|---|
| `portal` | `nginx:1.27-alpine` | 80 | `portal` ClusterIP `80` | `gratitud.example.com/` |
| `api` | `nginxinc/nginx-unprivileged:1.27-alpine` | **8080** | `api` ClusterIP `80 → 8080` | `gratitud.example.com/api` |
| `docs` | `nginx:1.27-alpine` | 80 | `docs` ClusterIP `80` | `gratitud.example.com/docs` |
| `panel` | `nginx:1.27-alpine` | 80 | `panel` ClusterIP `80` | `admin.gratitud.example.com/` |

```
   curl --resolve gratitud.example.com:32080:<IP-NODO> http://gratitud.example.com:32080/api
                                   |
      [ Ingress Controller · Traefik ]   NodePort 32080 (HTTP) / 32443 (HTTPS)
                                   |  regla host + path
      gratitud.example.com  /      -> Service portal -> Pods portal
                            /api   -> Service api    -> Pods api  (rewrite a /)
                            /docs  -> Service docs   -> Pods docs
      admin.gratitud.example.com / -> Service panel  -> Pods panel
```

> **El Ingress solo referencia Services de su propio namespace.** Por eso el
> frente web va junto en `gratitud-web`. En producción, cada equipo suele tener
> su propio objeto Ingress con el mismo host y su path: el controlador los
> combina. Se comenta en la solución del LAB 10.2.

## Agenda (180 min)

| Tiempo | Actividad |
|---|---|
| 00–10 | Repaso de Services y el problema que deja abierto |
| 10–32 | Conceptos: Ingress vs. Service, controlador, `ingressClassName` |
| 32–54 | **LAB 10.1 — Básico**: controlador y primer Ingress |
| 54–72 | Conceptos: routing por host y por path, `pathType`, rewrite |
| 72–104 | **LAB 10.2 — Intermedio**: enrutar GRATITUD por host y por path |
| 104–120 | Conceptos: terminación TLS y balanceo de capa 7 |
| 120–150 | **LAB 10.3 — Avanzado**: HTTPS propio para GRATITUD |
| 150–170 | **LAB 10.4 — Challenge**: «el Ingress no enruta» |
| 170–180 | Cierre y CKA Tips |

## Presentación

[`01-CLASE-10-CKA.pptx`](01-CLASE-10-CKA.pptx)

## Laboratorios

| Lab | Nivel | Archivo |
|---|---|---|
| LAB 10.1 | Básico | [LABORATORIOS/LAB-01-BASICO.md](LABORATORIOS/LAB-01-BASICO.md) |
| LAB 10.2 | Intermedio | [LABORATORIOS/LAB-02-INTERMEDIO.md](LABORATORIOS/LAB-02-INTERMEDIO.md) |
| LAB 10.3 | Avanzado | [LABORATORIOS/LAB-03-AVANZADO.md](LABORATORIOS/LAB-03-AVANZADO.md) |
| LAB 10.4 | Challenge | [LABORATORIOS/LAB-04-CHALLENGE.md](LABORATORIOS/LAB-04-CHALLENGE.md) |

## Recursos

[`RECURSOS/YAML/`](RECURSOS/YAML/) · [`RECURSOS/SCRIPTS/`](RECURSOS/SCRIPTS/)

| Archivo | Uso |
|---|---|
| `YAML/01-app-basica.yaml` | Deployment + Service `web` del LAB 10.1 |
| `YAML/02-ingress-basico.yaml` | Ingress de un host y un path (LAB 10.1) |
| `YAML/03-gratitud-web.yaml` | Deployments y Services de `portal`, `api`, `docs`, `panel` (LAB 10.2) |
| `YAML/04-ingress-host-path.yaml` | Ingress con reglas por host y por path (LAB 10.2) |
| `YAML/05-ingress-tls.yaml` | Ingress con sección `tls` (LAB 10.3) |
| `YAML/06-gratitud-ingress-referencia.yaml` | Referencia completa: apps + Ingress + TLS |
| `SCRIPTS/install-ingress-controller.sh` | Instala Traefik (Helm), NodePorts `32080`/`32443` |
| `SCRIPTS/gen-tls-secret.sh` | Certificado autofirmado + Secret `kubernetes.io/tls` |
| `SCRIPTS/setup-lab.sh` | Despliega el escenario **roto** del LAB 10.4 |
| `SCRIPTS/validate-lab.sh` | Comprueba el LAB 10.4 |
| `SCRIPTS/reset-lab.sh` | Elimina lo creado por la sesión (deja Traefik instalado) |

> **Requisito.** Los LAB 10.2–10.4 necesitan el Ingress Controller del LAB 10.1.
> Comprueba con `kubectl get ingressclass` antes de empezar.

## Preparación

```bash
alias k=kubectl
export do='--dry-run=client -o yaml'
cd CLASE-10/RECURSOS/SCRIPTS && chmod +x *.sh
```

Al terminar:

```bash
./reset-lab.sh
# y, si quieres quitar el controlador:  helm -n ingress uninstall traefik
```

## Checklist final de la sesión

- [ ] Explico qué añade un Ingress Controller sobre un Service.
- [ ] Distingo el objeto Ingress del controlador que lo ejecuta.
- [ ] Sé qué es `ingressClassName` y qué pasa si la clase no existe.
- [ ] Escribo reglas por host y por path en un solo Ingress.
- [ ] Elijo bien entre `pathType: Prefix` y `Exact`.
- [ ] Sé que el backend recibe el path sin reescribir salvo que use *rewrite*.
- [ ] Creo un Secret `kubernetes.io/tls` y lo asocio a un host.
- [ ] Pruebo HTTPS con `curl --resolve` y leo `subject`/`issuer`.
- [ ] Explico el balanceo de capa 7 frente al de `kube-proxy`.
- [ ] Diagnostico un `404`, un `503` y un certificado por defecto.
