# Clase 3 — Workloads, Storage y StatefulSets

## Duración

180 minutos.

## Objetivos

1. Explicar la cadena `Deployment -> ReplicaSet -> Pod` y demostrar el self-healing.
2. Elegir el controlador correcto para cada tipo de carga.
3. Compartir datos entre contenedores de un Pod con `emptyDir`.
4. Aprovisionar almacenamiento de forma **estática** (PV creado a mano) y **dinámica** (StorageClass).
5. Enlazar PV, PVC y Pod, y explicar por qué un PVC queda `Pending`.
6. Desplegar un StatefulSet con Headless Service y `volumeClaimTemplates`, y demostrar la identidad estable.
7. Diagnosticar fallos de almacenamiento.

## Contenidos

* Pod → ReplicationController (solo referencia histórica) → ReplicaSet → Deployment → StatefulSet.
* Self-healing, `ownerReferences`, `matchLabels` y por qué el selector es inmutable.
* Volumes: ciclo de vida ligado al Pod, no al contenedor.
* `emptyDir`, `hostPath` (y sus riesgos), `configMap`, `secret`, `persistentVolumeClaim`.
* PersistentVolume: `capacity`, `accessModes`, `persistentVolumeReclaimPolicy`, `storageClassName`.
* PersistentVolumeClaim: `resources.requests.storage`, `accessModes`, `selector`.
* Access modes: `ReadWriteOnce` (RWO), `ReadOnlyMany` (ROX), `ReadWriteMany` (RWX), `ReadWriteOncePod`.
* StorageClass: `provisioner`, `parameters`, `reclaimPolicy`, `volumeBindingMode`, `allowVolumeExpansion`.
* Aprovisionamiento estático vs dinámico. StorageClass por defecto.
* StatefulSet: nombre estable, orden de creación, `serviceName`, Headless Service (`clusterIP: None`), `volumeClaimTemplates`, un PVC por réplica.
* Qué ocurre cuando se borra un Pod de un StatefulSet.

Relación que se enseña de forma explícita:

```
StorageClass -> PersistentVolume -> PersistentVolumeClaim -> Pod -> volumeMount
```

## Actualizaciones técnicas respecto al material original

| Tema | Estado | Cambio aplicado |
|---|---|---|
| Imagen `k8s.gcr.io/nginx-slim:0.8` | **LEGACY** | `k8s.gcr.io` está retirado. Se usa `registry.k8s.io/nginx-slim:0.27` o `nginx:1.27-alpine` |
| `kubectl create -f` para todo | **REQUIERE ACTUALIZACIÓN** | Se usa `apply` (declarativo, idempotente) |
| PV `hostPath` en 3 nodos | **REQUIERE ACTUALIZACIÓN** | Se explica por qué `hostPath` ata el Pod a un nodo y se introduce `local` + `nodeAffinity` y el provisioner dinámico |
| `reclaimPolicy: Recycle` | **ELIMINADO** | Retirado de Kubernetes. Solo existen `Retain` y `Delete` |
| ReplicationController | **SOLO REFERENCIA** | Se menciona en 3 minutos y se pasa a ReplicaSet/Deployment |
| Modo de acceso RWOP | **NUEVO** | Se añade `ReadWriteOncePod`, estable desde v1.29 |

## Agenda (180 min)

| Tiempo | Actividad |
|---|---|
| 00–12 | Repaso Clase 2 y objetivos |
| 12–35 | Conceptos: controladores de workload y self-healing |
| 35–50 | **Demo**: borrar un Pod de un Deployment y de un StatefulSet, comparar |
| 50–72 | **LAB 3.1 — Básico**: Deployment, ReplicaSet y self-healing |
| 72–90 | Conceptos: volúmenes, PV, PVC, StorageClass |
| 90–120 | **LAB 3.2 — Intermedio**: emptyDir, PV y PVC estáticos |
| 120–130 | Conceptos: StatefulSet y Headless Service |
| 130–158 | **LAB 3.3 — Avanzado**: StatefulSet con almacenamiento por réplica |
| 158–176 | **LAB 3.4 — Challenge**: el PVC que nunca enlaza |
| 176–180 | Cierre, mental model de storage y CKA Tips |

## Presentación

[`01-CLASE-03-CKA.pptx`](01-CLASE-03-CKA.pptx)

## Laboratorios

| Lab | Nivel | Archivo |
|---|---|---|
| LAB 3.1 | Básico | [LABORATORIOS/LAB-01-BASICO.md](LABORATORIOS/LAB-01-BASICO.md) |
| LAB 3.2 | Intermedio | [LABORATORIOS/LAB-02-INTERMEDIO.md](LABORATORIOS/LAB-02-INTERMEDIO.md) |
| LAB 3.3 | Avanzado | [LABORATORIOS/LAB-03-AVANZADO.md](LABORATORIOS/LAB-03-AVANZADO.md) |
| LAB 3.4 | Challenge | [LABORATORIOS/LAB-04-CHALLENGE.md](LABORATORIOS/LAB-04-CHALLENGE.md) |

## Recursos

[`RECURSOS/YAML/`](RECURSOS/YAML/) · [`RECURSOS/SCRIPTS/`](RECURSOS/SCRIPTS/)

## Checklist final de la clase

- [ ] Explico la relación Deployment → ReplicaSet → Pod y la demuestro con `ownerReferences`.
- [ ] Demuestro el self-healing borrando un Pod.
- [ ] Comparto un directorio entre dos contenedores del mismo Pod.
- [ ] Creo un PV y un PVC que enlazan, y sé decir por qué enlazan.
- [ ] Sé enumerar las 4 causas por las que un PVC queda `Pending`.
- [ ] Distingo aprovisionamiento estático de dinámico.
- [ ] Explico qué hace `reclaimPolicy: Retain` frente a `Delete`.
- [ ] Despliego un StatefulSet con Headless Service y `volumeClaimTemplates`.
- [ ] Demuestro que un Pod de StatefulSet recupera su nombre y su volumen tras ser borrado.
- [ ] Sé por qué borrar un StatefulSet no borra sus PVC.
