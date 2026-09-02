# SOLUCIÓN — LAB 3.4 · Challenge de almacenamiento

> **MATERIAL DEL INSTRUCTOR.**

## Diagnóstico

**4 fallos.** Tres impiden el binding del PVC; el cuarto impide que el Pod arranque aunque el PVC ya esté `Bound`.

| # | Síntoma | Comando que lo revela | Causa raíz |
|---|---|---|---|
| 1 | PVC `Pending`, evento `no persistent volumes available` | `k -n c3-challenge describe pvc pvc-reportes` | El PVC pide `storageClassName: manual`; **ningún PV** tiene esa clase (todos son `slow`) y esa clase **no existe** |
| 2 | Sigue `Pending` tras corregir la clase | `k get pv -o wide` | El PVC pide `ReadWriteMany`; ningún PV lo ofrece (`RWO` y `ROX`) |
| 3 | Sigue `Pending`: el único PV compatible no se ofrece | `k get pv pv-reportes-ok -o yaml` → `status.phase: Released`, `spec.claimRef` presente | El PV quedó **reservado** por un PVC ya borrado (`reclaimPolicy: Retain`) |
| 4 | PVC `Bound` pero el Pod en `Pending` con `persistentvolumeclaim "pvc-reportes-data" not found` | `k -n c3-challenge describe pod <p>` | El Deployment referencia un `claimName` inexistente |

Los otros dos PV son **distractores intencionados**: `pv-reportes-small` (500Mi, menor que los 2Gi pedidos) y `pv-reportes-ro` (`ReadOnlyMany`).

## Razonamiento técnico resumido

```
PVC -> StorageClass -> PV -> AccessMode -> Capacity -> Pod
```

Cada eslabón debe cumplirse. Un PVC `Pending` casi siempre es uno de estos cinco: clase que no coincide, modo de acceso que nadie ofrece, capacidad insuficiente, ningún PV libre, o `selector` que no casa.

Un `claimRef` sobrante bloquea un PV aunque el PV parezca perfecto: `Released` **no** es `Available`.

## Procedimiento

```bash
NS=c3-challenge

# --- Reconocimiento
k -n $NS get deploy,pods,pvc
k get pv -o custom-columns=NAME:.metadata.name,CAP:.spec.capacity.storage,\
MODES:.spec.accessModes,SC:.spec.storageClassName,PHASE:.status.phase,CLAIM:.spec.claimRef.name
k get storageclass
k -n $NS describe pvc pvc-reportes | sed -n '/Events/,$p'

# --- Fallos 1 y 2: el PVC. spec de un PVC es casi todo inmutable -> recrear.
k -n $NS delete pvc pvc-reportes
k -n $NS apply -f - <<'YAML'
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: pvc-reportes, namespace: c3-challenge}
spec:
  storageClassName: slow
  accessModes: ["ReadWriteOnce"]
  resources: {requests: {storage: 2Gi}}
YAML

# --- Fallo 3: liberar el PV Released (justificado: el claim al que apunta ya no existe)
k get pv pv-reportes-ok -o jsonpath='{.status.phase} {.spec.claimRef.name}{"\n"}'
k patch pv pv-reportes-ok --type=json -p='[{"op":"remove","path":"/spec/claimRef"}]'
k get pv pv-reportes-ok        # Available -> y el PVC enlaza en segundos

# --- Fallo 4: el claimName del Deployment
k -n $NS get deploy reportes \
  -o jsonpath='{.spec.template.spec.volumes[0].persistentVolumeClaim.claimName}{"\n"}'
k -n $NS patch deploy reportes --type=json \
  -p='[{"op":"replace","path":"/spec/template/spec/volumes/0/persistentVolumeClaim/claimName","value":"pvc-reportes"}]'

k -n $NS rollout status deploy/reportes
```

> Recrear el PVC es aceptable y necesario: `spec.accessModes` y `spec.storageClassName` son inmutables. Lo que **no** se puede hacer es borrar los PV.

## Validación

```bash
k -n c3-challenge get pvc,deploy,pods
k get pv
k -n c3-challenge exec deploy/reportes -- ls -la /data
cd CLASE-03/RECURSOS/SCRIPTS && ./validate-lab.sh
```

## Resultado esperado

```
NAME                                 STATUS   VOLUME            CAPACITY   ACCESS MODES   STORAGECLASS
persistentvolumeclaim/pvc-reportes   Bound    pv-reportes-ok    5Gi        RWO            slow

NAME                       READY   UP-TO-DATE   AVAILABLE
deployment.apps/reportes   1/1     1            1

LAB 3.4 SUPERADO
```

## Error frecuente

* **Crear un PV nuevo** en lugar de arreglar el existente. Resuelve el síntoma y esconde la lección: los PV `Released` acumulados son un problema real de operación.
* **Marcar una StorageClass como por defecto** para que el PVC "enlace solo". Está prohibido por las restricciones y en un cluster real cambia el comportamiento de todos los PVC futuros.
* Intentar `k edit pvc` para cambiar `accessModes`: el API server lo rechaza. Hay que recrear.
* Parar tras conseguir el `Bound` y no comprobar el Pod.
* Borrar `pv-reportes-small` o `pv-reportes-ro` "porque no sirven". Sirven: son la práctica de descartar candidatos.

## CKA Tip

```bash
# Comparación PV vs PVC de un vistazo (el comando que resuelve el 90% de estos casos)
k get pv -o custom-columns=NAME:.metadata.name,CAP:.spec.capacity.storage,\
MODES:.spec.accessModes,SC:.spec.storageClassName,PHASE:.status.phase
k get pvc -A -o custom-columns=NS:.metadata.namespace,NAME:.metadata.name,\
REQ:.spec.resources.requests.storage,MODES:.spec.accessModes,SC:.spec.storageClassName,PHASE:.status.phase

# Los eventos del PVC dicen literalmente por qué no enlaza
k describe pvc <pvc> | sed -n '/Events/,$p'

# Liberar un PV Released
k patch pv <pv> --type=json -p='[{"op":"remove","path":"/spec/claimRef"}]'
```

**Regla de oro:** `Pending` en un PVC = problema de **emparejamiento**. `Pending` en el Pod con PVC ya `Bound` = problema de **referencia** (nombre del claim) o de **nodo** (el volumen no puede montarse ahí).
