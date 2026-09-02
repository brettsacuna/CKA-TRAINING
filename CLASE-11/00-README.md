# Sesión 11 — Configuración y Seguridad de Aplicaciones

> **Sesión especial.** Continúa el programa GRATITUD: saca la configuración de la
> imagen de la API con **ConfigMaps** y **Secrets**, la inyecta como **variables
> de entorno** y como **archivos montados**, y le da almacenamiento persistente
> con **PV**, **PVC** y **StorageClass**.

## Duración

180 minutos.

## Objetivos

1. Externalizar la configuración de una aplicación con **ConfigMaps** (valores y ficheros).
2. Guardar credenciales y tokens en **Secrets**, y explicar qué protege un Secret y qué **no** (base64 ≠ cifrado).
3. Inyectar configuración como **variables de entorno** (`env`, `envFrom`, `valueFrom`) y como **archivos** (volúmenes `configMap`/`secret`, `subPath`).
4. Elegir entre env var y archivo según haga falta **propagación de cambios** en caliente.
5. Describir el **ciclo de vida** de un PersistentVolume: `Available → Bound → Released` y el efecto de la `reclaimPolicy`.
6. Escribir un **PVC** y entender los criterios de *binding* (`storageClassName`, `accessModes`, capacidad).
7. Aprovisionar almacenamiento **dinámicamente** con una **StorageClass**.

## Contenidos

* **ConfigMap vs. Secret.** Para qué es cada uno; formas de crearlos (`--from-literal`, `--from-file`, `--from-env-file`, `data`/`stringData`); `immutable: true`.
* **Seguridad de un Secret.** base64 no es cifrado. Cifrado en reposo = `EncryptionConfiguration` en el API server (tarea del administrador). RBAC sobre `secrets`. Montaje en `tmpfs`.
* **Inyección.** `env`/`envFrom`/`valueFrom` frente a volúmenes `configMap`/`secret`. Propagación: env **no** se actualiza; volumen **sí** (< 1 min) salvo `subPath`; el montaje oculta el directorio.
* **PV / PVC.** Ciclo de vida, `accessModes` (RWO/ROX/RWX/RWOP), `persistentVolumeReclaimPolicy` (`Retain`/`Delete`; `Recycle` eliminado). El Pod monta un PVC, nunca un PV.
* **StorageClass.** `provisioner`, `parameters`, `reclaimPolicy`, `volumeBindingMode` (`Immediate` vs `WaitForFirstConsumer`), `allowVolumeExpansion`, StorageClass por defecto, `storageClassName: ""`.

## El programa GRATITUD en esta sesión

La API de GRATITUD, en el namespace **`gratitud-api`**, toda su configuración
fuera de la imagen:

| Objeto | Tipo | Contenido |
|---|---|---|
| `gratitud-config` | ConfigMap | `LOG_LEVEL`, `FEATURE_GRATITUD_V2`, `UPSTREAM_CACHE`, y la clave `app.conf` (fichero multilínea) |
| `gratitud-db` | Secret `Opaque` | `DB_USER`, `DB_PASSWORD`, `DB_HOST` |
| `gratitud-api-tokens` | Secret `Opaque` | `PARTNER_TOKEN`, `WEBHOOK_SIGNING_KEY` |

Inyección en el Deployment `api`:

```
envFrom:  configMapRef: gratitud-config   +  secretRef: gratitud-db
env:      PARTNER_TOKEN  <- secretKeyRef gratitud-api-tokens
volume:   app.conf  ->  /etc/gratitud/app.conf   (subPath)
```

La capa de datos, en **`gratitud-datos`**, necesita un volumen que sobreviva a
sus Pods: PVC **`gratitud-uploads`** (1Gi, RWO), montado en `/data/uploads`,
aprovisionado por una StorageClass o, en su defecto, por un PV estático.

## Agenda (180 min)

| Tiempo | Actividad |
|---|---|
| 00–10 | Por qué la configuración no va dentro de la imagen |
| 10–30 | Conceptos: ConfigMap, Secret y qué protege cada uno |
| 30–52 | **LAB 11.1 — Básico**: crear e inyectar ConfigMap y Secret |
| 52–70 | Conceptos: env var frente a archivo montado, propagación |
| 70–102 | **LAB 11.2 — Intermedio**: cablear la configuración de GRATITUD |
| 102–120 | Conceptos: PV, PVC, ciclo de vida y StorageClass |
| 120–150 | **LAB 11.3 — Avanzado**: almacenamiento persistente para GRATITUD |
| 150–170 | **LAB 11.4 — Challenge**: «GRATITUD no arranca» |
| 170–180 | Cierre y CKA Tips |

## Presentación

[`01-CLASE-11-CKA.pptx`](01-CLASE-11-CKA.pptx)

## Laboratorios

| Lab | Nivel | Archivo |
|---|---|---|
| LAB 11.1 | Básico | [LABORATORIOS/LAB-01-BASICO.md](LABORATORIOS/LAB-01-BASICO.md) |
| LAB 11.2 | Intermedio | [LABORATORIOS/LAB-02-INTERMEDIO.md](LABORATORIOS/LAB-02-INTERMEDIO.md) |
| LAB 11.3 | Avanzado | [LABORATORIOS/LAB-03-AVANZADO.md](LABORATORIOS/LAB-03-AVANZADO.md) |
| LAB 11.4 | Challenge | [LABORATORIOS/LAB-04-CHALLENGE.md](LABORATORIOS/LAB-04-CHALLENGE.md) |

## Recursos

[`RECURSOS/YAML/`](RECURSOS/YAML/) · [`RECURSOS/SCRIPTS/`](RECURSOS/SCRIPTS/)

| Archivo | Uso |
|---|---|
| `YAML/01-configmap-secret.yaml` | `demo-config` + `demo-secret` del LAB 11.1 |
| `YAML/02-gratitud-config.yaml` | `gratitud-config`, `gratitud-db`, `gratitud-api-tokens` (LAB 11.2) |
| `YAML/03-gratitud-api-deploy.yaml` | Deployment `api` con las tres formas de inyección (LAB 11.2) |
| `YAML/04-storageclass.yaml` | StorageClass `gratitud-standard` (conceptual) + PV estático de reserva |
| `YAML/05-gratitud-uploads-pvc.yaml` | PVC `gratitud-uploads` + Deployment `datos` que lo monta (LAB 11.3) |
| `YAML/06-gratitud-config-storage-referencia.yaml` | Referencia completa |
| `SCRIPTS/setup-lab.sh` | Despliega el escenario **roto** del LAB 11.4 |
| `SCRIPTS/validate-lab.sh` | Comprueba el LAB 11.4 |
| `SCRIPTS/reset-lab.sh` | Elimina lo creado por la sesión |

> **Sobre el aprovisionamiento dinámico.** Si tu cluster no tiene un
> `provisioner` (comprueba con `kubectl get storageclass`), los laboratorios de
> storage funcionan igual con el **PV estático** de `04-storageclass.yaml`. El
> escenario del LAB 11.4 es independiente del proveedor.

## Preparación

```bash
alias k=kubectl
export do='--dry-run=client -o yaml'
cd CLASE-11/RECURSOS/SCRIPTS && chmod +x *.sh
```

Al terminar:

```bash
./reset-lab.sh
```

## Checklist final de la sesión

- [ ] Creo un ConfigMap por literal, por fichero y por env-file.
- [ ] Creo un Secret con `stringData` y revierto un valor con `base64 -d`.
- [ ] Explico qué protege un Secret y qué necesita para cifrarse **en reposo**.
- [ ] Inyecto configuración por `envFrom`, por `valueFrom` y por volumen.
- [ ] Sé qué se actualiza solo al editar un ConfigMap y qué exige `rollout restart`.
- [ ] Uso `subPath` y conozco su coste (no recibe actualizaciones).
- [ ] Describo el ciclo de vida `Available → Bound → Released`.
- [ ] Escribo un PVC y sé por qué se queda en `Pending`.
- [ ] Diferencio `Retain` de `Delete` en la `reclaimPolicy`.
- [ ] Aprovisiono un volumen dinámicamente con una StorageClass.
