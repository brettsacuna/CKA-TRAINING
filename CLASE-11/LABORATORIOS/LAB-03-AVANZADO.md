# LAB 11.3 — Almacenamiento persistente para GRATITUD

## Nivel

Avanzado.

## Duración

30 minutos.

## Objetivo

Dar a la capa de datos de GRATITUD un volumen que **sobreviva a la recreación de
sus Pods**, aprovisionado dinámicamente cuando sea posible, y demostrar la
persistencia y el efecto de la `reclaimPolicy`.

## Competencias

* Consultar el estado de aprovisionamiento del cluster (`StorageClass`, provisioner).
* Escribir un PVC y entender por qué se enlaza (o no) a un PV.
* Demostrar que los datos persisten a la recreación de un Pod.
* Explicar el ciclo `Bound → Released` y la diferencia entre `Retain` y `Delete`.

## Escenario

`gratitud-datos` guarda los ficheros que suben los usuarios. Hoy están en el
sistema de ficheros efímero del contenedor: al primer reinicio del Pod, se
pierden. Seguridad y negocio piden lo siguiente para el namespace
**`gratitud-datos`**:

| # | Requisito |
|---|---|
| R1 | Un volumen de **1Gi**, modo **RWO**, montado en **`/data/uploads`** del Deployment `datos`. |
| R2 | Los ficheros deben **sobrevivir** a `kubectl delete pod`. |
| R3 | El volumen debe aprovisionarse **dinámicamente** si el cluster tiene una StorageClass con provisioner; si no, con un **PV estático** que satisfaga el PVC. |
| R4 | Debes poder explicar, mirando `kubectl get pv,pvc`, en qué estado está cada objeto y por qué. |
| R5 | Al borrar el PVC, el comportamiento del PV debe ser **conocido y justificado** (`Retain` o `Delete`). |

Tú decides los manifiestos, el orden y las pruebas.

## Estado inicial

* Namespace de trabajo: **`gratitud-datos`**.
* `../RECURSOS/YAML/04-storageclass.yaml` trae una StorageClass de ejemplo **y** un PV estático de reserva por si no hay provisioner.

## Pistas de método (no de solución)

* `kubectl get storageclass` — ¿hay alguna marcada `(default)`? ¿su `PROVISIONER` es real o de ejemplo?
* Dinámico: el PVC nombra `storageClassName: <sc>` (o ninguno, para heredar la por defecto) y el PV lo crea el provisioner.
* Estático: crea tú el PV con `storageClassName`, `capacity`, `accessModes` y `hostPath`; el PVC se enlazará si **todo** encaja.
* `storageClassName: ""` en el PVC desactiva el dinámico y fuerza el enlace con un PV estático.
* Persistencia: escribe un fichero, `kubectl delete pod`, espera el nuevo, vuelve a leer.
* `kubectl get pv <pv> -o jsonpath='{.spec.persistentVolumeReclaimPolicy}'`.

## Validación

```bash
kubectl get storageclass
kubectl -n gratitud-datos get pvc gratitud-uploads -o wide
kubectl get pv | grep -E 'gratitud|NAME'
kubectl -n gratitud-datos get pvc gratitud-uploads -o jsonpath='{.status.phase}{"  "}{.spec.storageClassName}{"  "}{.status.capacity.storage}{"\n"}'

# persistencia
kubectl -n gratitud-datos exec deploy/datos -- sh -c 'echo hola > /data/uploads/prueba.txt; ls -l /data/uploads'
kubectl -n gratitud-datos delete pod -l app=gratitud-datos
kubectl -n gratitud-datos rollout status deploy/datos
kubectl -n gratitud-datos exec deploy/datos -- cat /data/uploads/prueba.txt      # hola

# reclaimPolicy
PV=$(kubectl -n gratitud-datos get pvc gratitud-uploads -o jsonpath='{.spec.volumeName}')
kubectl get pv "$PV" -o jsonpath='{.spec.persistentVolumeReclaimPolicy}{"\n"}'
kubectl -n gratitud-datos delete pvc gratitud-uploads
kubectl get pv "$PV" -o jsonpath='{.status.phase}{"\n"}'      # Released (Retain) o desaparece (Delete)
```

## Resultado esperado

* PVC `gratitud-uploads` en `Bound`, 1Gi, RWO, montado en `/data/uploads`.
* `prueba.txt` sigue existiendo tras borrar el Pod.
* `kubectl get pv,pvc` legible: sabes por qué cada objeto está en su estado.
* Al borrar el PVC: con `Retain`, el PV queda `Released` y los datos se conservan; con `Delete`, el PV y el volumen desaparecen.

## Criterios de éxito

- [ ] Comprobé si el cluster tiene StorageClass con provisioner.
- [ ] El PVC `gratitud-uploads` está `Bound` con 1Gi y RWO.
- [ ] El Deployment `datos` monta el PVC en `/data/uploads`.
- [ ] Demostré que un fichero sobrevive a `kubectl delete pod`.
- [ ] Sé leer el estado de cada PV y PVC y explicar por qué está así.
- [ ] Expliqué el efecto de la `reclaimPolicy` al borrar el PVC.
