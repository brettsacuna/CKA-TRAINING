# LAB 3.4 — Challenge: el PVC que nunca enlaza

## Nivel

Challenge / Troubleshooting.

## Duración

20 minutos.

## Objetivo

Diagnosticar por qué un PVC no consigue enlazar y por qué un Pod nunca llega a `Running`, aplicando el mental model de storage.

```
IDENTIFICAR -> DIAGNOSTICAR -> CORREGIR -> VALIDAR
```

## Competencias

* Aplicar la ruta `PVC -> StorageClass -> PV -> AccessMode -> Capacity -> Pod`.
* Leer los eventos de un PVC y de un Pod `Pending` / `ContainerCreating`.
* Reconocer las causas por las que un PV y un PVC **no** se emparejan.
* Corregir sin destruir datos.

## Escenario

El equipo de la aplicación **`reportes`** dice que su despliegue "lleva media hora creándose". Nadie sabe por qué.

## Estado inicial

```bash
cd CLASE-03/RECURSOS/SCRIPTS
./setup-lab.sh
```

Esto crea el namespace **`c3-challenge`** con varios PersistentVolumes, PersistentVolumeClaims y un Deployment `reportes`. **Nada de ello funciona correctamente.**

Hay **4 fallos**. No se te dice cuáles.

## Requerimientos

1. Identifica por qué el o los PVC no enlazan.
2. Identifica por qué el Pod no arranca.
3. Documenta, por cada fallo: síntoma, comando que lo reveló, causa raíz.
4. Corrige todo hasta que el Deployment `reportes` tenga **1/1** réplicas `Running` y su PVC en `Bound`.
5. Verifica que el contenido del volumen es accesible desde el contenedor.

## Restricciones

* **No elimines los PersistentVolumes** existentes.
* No crees una StorageClass por defecto para "que todo enlace solo".
* Puedes crear, modificar o eliminar **PVC**; los PV solo puedes modificarlos si es imprescindible y debes justificarlo.
* No cambies el nombre del Deployment ni del namespace.

## Mental model a aplicar

```
PVC
 v
StorageClass    -> ¿coinciden los storageClassName? ¿existe la clase? ¿hay clase por defecto?
 v
PV              -> ¿hay algún PV disponible? ¿en qué Phase está?
 v
AccessMode      -> ¿el PVC pide un modo que el PV no ofrece?
 v
Capacity        -> ¿el PV es al menos tan grande como lo que pide el PVC?
 v
Pod             -> ¿el nombre del claim en el Pod coincide con el PVC real?
```

## Comandos de diagnóstico

```bash
kubectl -n c3-challenge get deploy,pods,pvc
kubectl get pv -o wide
kubectl get storageclass
kubectl -n c3-challenge describe pvc <pvc> | sed -n '/Events/,$p'
kubectl -n c3-challenge describe pod  <pod> | sed -n '/Events/,$p'
kubectl get pv <pv> -o jsonpath='{.spec.capacity.storage} {.spec.accessModes} {.spec.storageClassName} {.status.phase}{"\n"}'
```

## Validación

```bash
kubectl -n c3-challenge get deploy reportes      # 1/1
kubectl -n c3-challenge get pvc                  # Bound
kubectl get pv
kubectl -n c3-challenge exec deploy/reportes -- ls -l /data

cd CLASE-03/RECURSOS/SCRIPTS && ./validate-lab.sh
```

## Resultado esperado

* El PVC de `reportes` en estado **`Bound`**.
* El Deployment `reportes` con **1/1** réplicas `Running`.
* El contenedor puede leer y escribir en `/data`.
* `./validate-lab.sh` termina con `LAB 3.4 SUPERADO`.

## Criterios de éxito

- [ ] Identifiqué los 4 fallos sin consultar la solución.
- [ ] Documenté síntoma, comando y causa raíz de cada uno.
- [ ] El PVC está `Bound` a un PV existente.
- [ ] El Pod de `reportes` está `Running`.
- [ ] `/data` es accesible desde el contenedor.
- [ ] No eliminé ningún PersistentVolume.
- [ ] No creé una StorageClass por defecto.
- [ ] `./validate-lab.sh` pasa.
