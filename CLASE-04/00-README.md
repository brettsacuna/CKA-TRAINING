# Clase 4 — Application Lifecycle, ConfigMaps, Secrets y Recursos

## Duración

180 minutos.

## Objetivos

1. Ejecutar un Rolling Update controlado y seguir su progreso.
2. Consultar el historial de revisiones y volver a una anterior con `rollout undo`.
3. Detectar un despliegue defectuoso **antes** de que afecte a todas las réplicas.
4. Externalizar configuración con ConfigMaps: variables, `envFrom` y montaje como volumen.
5. Gestionar datos sensibles con Secrets, y explicar con precisión qué protegen y qué no.
6. Definir `requests` y `limits`, entender las clases de QoS y el comportamiento ante presión de recursos.
7. Instalar Metrics Server y usar `kubectl top`.

## Contenidos

* Estrategias de Deployment: `RollingUpdate` (`maxSurge`, `maxUnavailable`) y `Recreate`.
* `kubectl rollout status | history | undo | pause | resume | restart`.
* `revisionHistoryLimit`. Anotación `kubernetes.io/change-cause`.
* `kubectl set image`, `kubectl scale`, `kubectl patch`.
* `readinessProbe` como red de seguridad del rollout: por qué un rollout se detiene solo.
* ConfigMap: `--from-literal`, `--from-file`, `--from-env-file`. Consumo por `env`/`configMapKeyRef`, `envFrom` y volumen.
* Secret: tipos (`Opaque`, `kubernetes.io/tls`, `docker-registry`). Consumo por `secretKeyRef`, `envFrom` y volumen.
* Base64 **no es cifrado**. Qué protege realmente un Secret (RBAC, cifrado en reposo de etcd, no aparecer en la imagen).
* Diferencia práctica: un ConfigMap montado como volumen **se actualiza solo**; una variable de entorno **no**.
* `resources.requests` vs `resources.limits`. CPU comprimible, memoria no. `OOMKilled`.
* Clases de QoS: `Guaranteed`, `Burstable`, `BestEffort`.
* Metrics Server, `kubectl top nodes`, `kubectl top pods`.

## Actualizaciones técnicas respecto al material original

| Tema | Estado | Cambio aplicado |
|---|---|---|
| `--record=true` | **ELIMINADO** | Retirado de kubectl. Se usa la anotación `kubernetes.io/change-cause` |
| Metrics Server v0.3.6 + edición manual de la línea 42 (`apiregistration v1beta1`) | **LEGACY** | Se instala **v0.8.1** con el manifiesto oficial; el arreglo de `v1beta1` ya no aplica |
| `kubectl edit deployment --record` | **REQUIERE ACTUALIZACIÓN** | Sustituido por `set image` + `annotate` |
| Imagen `nginx:1.7.9` | **REQUIERE ACTUALIZACIÓN** | Se usan versiones vigentes de nginx |
| Secrets "encriptados" | **CORRECCIÓN CONCEPTUAL** | Se aclara que el contenido está **codificado** en base64, no cifrado |
| `kubectl top` sin readiness | **MEJORA** | Se añade `readinessProbe` para demostrar rollouts que se detienen solos |

## Agenda (180 min)

| Tiempo | Actividad |
|---|---|
| 00–12 | Repaso Clase 3 y objetivos |
| 12–32 | Conceptos: rollout, revisiones, rollback, estrategias |
| 32–48 | **Demo**: rollout con imagen rota y `rollout undo` en vivo |
| 48–72 | **LAB 4.1 — Básico**: Rolling Update y Rollback |
| 72–90 | Conceptos: ConfigMaps y Secrets |
| 90–120 | **LAB 4.2 — Intermedio**: configuración externalizada |
| 120–132 | Conceptos: requests, limits, QoS y Metrics Server |
| 132–158 | **LAB 4.3 — Avanzado**: recursos, escalado y métricas |
| 158–176 | **LAB 4.4 — Challenge**: el despliegue que no arranca |
| 176–180 | Cierre y CKA Tips |

## Presentación

[`01-CLASE-04-CKA.pptx`](01-CLASE-04-CKA.pptx)

## Laboratorios

| Lab | Nivel | Archivo |
|---|---|---|
| LAB 4.1 | Básico | [LABORATORIOS/LAB-01-BASICO.md](LABORATORIOS/LAB-01-BASICO.md) |
| LAB 4.2 | Intermedio | [LABORATORIOS/LAB-02-INTERMEDIO.md](LABORATORIOS/LAB-02-INTERMEDIO.md) |
| LAB 4.3 | Avanzado | [LABORATORIOS/LAB-03-AVANZADO.md](LABORATORIOS/LAB-03-AVANZADO.md) |
| LAB 4.4 | Challenge | [LABORATORIOS/LAB-04-CHALLENGE.md](LABORATORIOS/LAB-04-CHALLENGE.md) |

## Recursos

[`RECURSOS/YAML/`](RECURSOS/YAML/) · [`RECURSOS/SCRIPTS/`](RECURSOS/SCRIPTS/) (incluye `install-metrics-server.sh`)

## Checklist final de la clase

- [ ] Ejecuto un Rolling Update y sigo su progreso con `rollout status`.
- [ ] Consulto `rollout history` y el detalle de una revisión concreta.
- [ ] Registro la causa del cambio sin usar `--record`.
- [ ] Hago rollback a una revisión concreta.
- [ ] Explico `maxSurge` y `maxUnavailable`.
- [ ] Creo un ConfigMap de tres formas distintas.
- [ ] Consumo un ConfigMap como variable y como volumen.
- [ ] Creo un Secret y lo consumo como variable y como volumen.
- [ ] Explico por qué base64 no es cifrado.
- [ ] Defino `requests` y `limits` y sé decir la QoS resultante.
- [ ] Instalo Metrics Server y uso `kubectl top`.
