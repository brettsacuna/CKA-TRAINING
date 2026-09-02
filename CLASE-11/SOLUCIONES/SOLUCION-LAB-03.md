# SOLUCIÓN — LAB 11.3 · Almacenamiento persistente para GRATITUD

> **MATERIAL DEL INSTRUCTOR.**

## Diagnóstico

1. **El Pod monta un PVC, no un PV.** Mientras el PVC exista y esté `Bound`, el Pod se recrea sin perder datos.
2. **El *binding* exige que TODO encaje**: `storageClassName`, `accessModes` y capacidad (el PV debe ofrecer ≥ lo que pide el PVC).
3. **`reclaimPolicy`** decide qué pasa al borrar el PVC: `Retain` conserva datos y deja el PV `Released` (inutilizable sin intervención); `Delete` borra volumen y PV.

## Camino A — con aprovisionamiento dinámico

```bash
k get storageclass
# NAME                 PROVISIONER            DEFAULT
# gratitud-standard    rancher.io/local-path  false
# (si hay una '(default)' con provisioner real, puedes omitir storageClassName)

cat <<'EOF' | k apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: gratitud-uploads, namespace: gratitud-datos}
spec:
  storageClassName: gratitud-standard
  accessModes: [ReadWriteOnce]
  resources: {requests: {storage: 1Gi}}
EOF
# con volumeBindingMode WaitForFirstConsumer, el PVC queda 'Pending' hasta que haya un Pod que lo use
k apply -f ../RECURSOS/YAML/05-gratitud-uploads-pvc.yaml   # trae el Deployment 'datos'
k -n gratitud-datos get pvc gratitud-uploads -w            # pasa a Bound al programarse el Pod
```

## Camino B — sin provisioner, con PV estático

```bash
# en el nodo:  mkdir -p /mnt/gratitud-uploads
k apply -f ../RECURSOS/YAML/04-storageclass.yaml           # crea gratitud-pv-uploads (storageClassName: manual)
# el PVC debe pedir el MISMO storageClassName y accessModes, y <= capacidad
k apply -f ../RECURSOS/YAML/05-gratitud-uploads-pvc.yaml   # PVC storageClassName: manual
k get pv,pvc -n gratitud-datos
# gratitud-pv-uploads   1Gi   RWO   Retain   Bound   gratitud-datos/gratitud-uploads   manual
```

## Persistencia y reclaimPolicy

```bash
k -n gratitud-datos rollout status deploy/datos
k -n gratitud-datos exec deploy/datos -- sh -c 'echo hola > /data/uploads/prueba.txt; ls -l /data/uploads'
k -n gratitud-datos delete pod -l app=gratitud-datos
k -n gratitud-datos rollout status deploy/datos
k -n gratitud-datos exec deploy/datos -- cat /data/uploads/prueba.txt      # hola  -> persiste

PV=$(k -n gratitud-datos get pvc gratitud-uploads -o jsonpath='{.spec.volumeName}')
k get pv "$PV" -o jsonpath='{.spec.persistentVolumeReclaimPolicy}{"\n"}'   # Retain (estatico) / Delete (dinamico)
k -n gratitud-datos delete pvc gratitud-uploads
k get pv "$PV" -o jsonpath='{.status.phase}{"\n"}'
#   Retain  -> 'Released'  (datos en /mnt/gratitud-uploads intactos; PV NO reutilizable sin editar claimRef)
#   Delete  -> el PV desaparece junto con el volumen
```

Para reutilizar un PV `Released` con `Retain`: `kubectl patch pv $PV --type=json
-p='[{"op":"remove","path":"/spec/claimRef"}]'` y vuelve a `Available`.

## Validación

```bash
k get storageclass
k -n gratitud-datos get pvc gratitud-uploads -o wide
k -n gratitud-datos get pvc gratitud-uploads \
  -o jsonpath='{.status.phase}{"  "}{.spec.storageClassName}{"  "}{.status.capacity.storage}{"\n"}'
k -n gratitud-datos exec deploy/datos -- cat /data/uploads/prueba.txt
```

## Resultado esperado

* PVC `gratitud-uploads` `Bound`, 1Gi, RWO, montado en `/data/uploads`.
* `prueba.txt` sobrevive a `kubectl delete pod`.
* Al borrar el PVC: `Retain` → PV `Released` con datos; `Delete` → PV y volumen eliminados.

## Error frecuente

* PVC en `Pending` para siempre porque el `storageClassName` no coincide con el del PV (o no hay provisioner).
* Pedir `ReadWriteMany` a un `hostPath` o a un disco de bloque: no lo soportan.
* Esperar que un PV `Released` con `Retain` se reutilice solo. Hay que quitarle el `claimRef` a mano.
* Creer que borrar el Pod borra los datos. Los borra borrar el PVC (con `Delete`) o el volumen subyacente.
* Con `WaitForFirstConsumer`, alarmarse por el PVC en `Pending` sin Pod: es lo esperado.

## CKA Tip

```bash
k get pv,pvc -A
k describe pvc <pvc>                       # Events: por qué no enlaza
k get sc                                   # ¿hay (default)? ¿provisioner real?
k patch pv <pv> --type=json -p='[{"op":"remove","path":"/spec/claimRef"}]'   # Released -> Available
```

Estados del PV: `Available → Bound → Released → (Failed)`. `Recycle` **ya no existe**.
