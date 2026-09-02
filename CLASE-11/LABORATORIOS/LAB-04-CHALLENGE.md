# LAB 11.4 — Challenge: «GRATITUD no arranca»

## Nivel

Challenge / Troubleshooting.

## Duración

20 minutos.

## Objetivo

Distinguir **cuatro fallos** de configuración y almacenamiento que impiden
arrancar la API de GRATITUD: una clave de Secret inexistente, un nombre de
ConfigMap equivocado, un `storageClassName` que no enlaza y un `subPath` mal
escrito.

```
IDENTIFICAR -> DIAGNOSTICAR -> CORREGIR -> VALIDAR
```

## Competencias

* Leer `CreateContainerConfigError` y localizar la referencia que falla.
* Distinguir un fallo por `secretKeyRef` de uno por `configMapRef`.
* Diagnosticar un PVC en `Pending` (`storageClassName`, `accessModes`, capacidad).
* Detectar un `subPath` que deja el fichero fuera del contenedor.

## Escenario

Tras un despliegue, el Pod de `api` está en `CreateContainerConfigError` y no
llega a arrancar. Además, el Deployment `datos` está en `Pending` porque su PVC
no se enlaza. Nadie ha tocado nada, oficialmente. **Hay 4 fallos.**

## Estado inicial

```bash
cd CLASE-11/RECURSOS/SCRIPTS
chmod +x *.sh
./setup-lab.sh
```

Crea:

* **`gratitud-api`**: `gratitud-config` (ConfigMap con `app.conf`), `gratitud-db` y `gratitud-api-tokens` (Secrets) **correctos**, y un Deployment `api` **con 3 defectos**.
* **`gratitud-datos`**: un PV estático `gratitud-pv-uploads`, un PVC `gratitud-uploads` **con 1 defecto**, y un Deployment `datos` que lo monta.

## Requerimientos

1. Empieza por el estado y los eventos del Pod `api`:
   ```bash
   kubectl -n gratitud-api get pods
   kubectl -n gratitud-api describe pod -l app=gratitud-api | sed -n '/Events/,$p'
   ```
   `CreateContainerConfigError` te dice que una referencia de `env`/`envFrom` no resuelve.
2. Recorre la ruta:
   ```
   secretKeyRef (clave) -> configMapRef (nombre) -> PVC (storageClassName / accessModes) -> volumeMount / subPath
   ```
3. Identifica los **4 fallos**.
4. Documenta, por cada uno: síntoma, comando que lo reveló, causa raíz y campo que lo corrige.
5. Corrige hasta que:
   * el Pod `api` esté `Running` y `1/1`,
   * `printenv DB_PASSWORD` dentro de `api` devuelva un valor,
   * `cat /etc/gratitud/app.conf` dentro de `api` muestre el fichero,
   * el PVC `gratitud-uploads` esté `Bound` y el Pod `datos` `Running`.

## Restricciones

* **No** marques las referencias como `optional: true` para "saltártelas".
* **No** borres el PVC ni los Secrets/ConfigMap.
* No cambies la imagen ni el comando del contenedor.

## Ruta de diagnóstico

```
Pod api CreateContainerConfigError
  |-- describe pod -> "couldn't find key DB_PASS in Secret gratitud-db"   -> secretKeyRef.key
  |-- describe pod -> "configmap \"gratitud-cfg\" not found"              -> configMapRef.name
Pod api Running pero /etc/gratitud/app.conf vacio o ausente
  |-- exec -- ls -l /etc/gratitud  -> subPath no coincide con items.path -> volumeMounts.subPath
Pod datos Pending
  |-- describe pvc gratitud-uploads -> "no persistent volumes available"  -> storageClassName del PVC
```

## Comandos de diagnóstico

```bash
kubectl -n gratitud-api get deploy api -o yaml | grep -E 'configMapRef|secretRef|secretKeyRef|key:|name:|subPath|mountPath'
kubectl -n gratitud-api get secret gratitud-db -o jsonpath='{.data}' | tr ',' '\n'
kubectl -n gratitud-datos describe pvc gratitud-uploads
kubectl get pv gratitud-pv-uploads -o jsonpath='{.spec.storageClassName}{"  "}{.spec.accessModes}{"  "}{.spec.capacity.storage}{"\n"}'
```

## Validación

```bash
cd CLASE-11/RECURSOS/SCRIPTS && ./validate-lab.sh

# manual
kubectl -n gratitud-api  exec deploy/api -- printenv DB_PASSWORD
kubectl -n gratitud-api  exec deploy/api -- cat /etc/gratitud/app.conf
kubectl -n gratitud-datos get pvc gratitud-uploads
```

## Los 4 fallos (para el instructor — no mirar antes de intentarlo)

<details>
<summary>Spoiler</summary>

1. **`secretKeyRef.key`.** El Deployment `api` pide `key: DB_PASS` de `gratitud-db`; la clave real es `DB_PASSWORD`. → `CreateContainerConfigError`. Corregir a `DB_PASSWORD`.
2. **`configMapRef.name`.** `envFrom` referencia `gratitud-cfg`; el ConfigMap se llama `gratitud-config`. → `CreateContainerConfigError`. Corregir el nombre.
3. **`subPath`.** El volumen expone `app.conf` (`items[].path: app.conf`) pero el `volumeMounts[].subPath` es `app.cnf`. El fichero no aparece en el contenedor. → `subPath: app.conf`.
4. **`storageClassName` del PVC.** El PVC `gratitud-uploads` pide `storageClassName: gratitud-manual`; el PV `gratitud-pv-uploads` es `storageClassName: manual`. No enlazan. → alinear el `storageClassName` del PVC con el del PV (`manual`).

</details>

## Resultado esperado

* Pod `api` `Running` `1/1`; `printenv DB_PASSWORD` y `cat /etc/gratitud/app.conf` devuelven contenido.
* PVC `gratitud-uploads` en `Bound`; Pod `datos` `Running` `1/1`.
* `./validate-lab.sh` termina con `LAB 11.4 SUPERADO`.

## Criterios de éxito

- [ ] Leí `CreateContainerConfigError` y localicé las dos referencias que fallaban.
- [ ] Distinguí el fallo de `secretKeyRef` del de `configMapRef`.
- [ ] Corregí el `subPath` y el fichero apareció en el contenedor.
- [ ] Diagnostiqué el PVC `Pending` por `storageClassName` y lo enlacé.
- [ ] No usé `optional: true` ni borré objetos de configuración.
- [ ] `./validate-lab.sh` pasa.
