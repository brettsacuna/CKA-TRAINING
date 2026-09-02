# SOLUCIÓN — LAB 11.4 · Challenge «GRATITUD no arranca»

> **MATERIAL DEL INSTRUCTOR.**

## Los 4 fallos

| # | Objeto · campo | Fallo | Síntoma | Comando que lo revela |
|---|---|---|---|---|
| 1 | `deploy/api` · `env[].valueFrom.secretKeyRef.key` | `DB_PASS` (la clave del Secret es `DB_PASSWORD`) | `CreateContainerConfigError` | `k describe pod` → *couldn't find key DB_PASS* |
| 2 | `deploy/api` · `envFrom[].configMapRef.name` | `gratitud-cfg` (el ConfigMap es `gratitud-config`) | `CreateContainerConfigError` | `k describe pod` → *configmap "gratitud-cfg" not found* |
| 3 | `deploy/api` · `volumeMounts[].subPath` | `app.cnf` (`items[].path` es `app.conf`) | Pod arranca pero `/etc/gratitud/app.conf` no existe | `k exec deploy/api -- ls -l /etc/gratitud` |
| 4 | `pvc/gratitud-uploads` · `storageClassName` | `gratitud-manual` (el PV es `manual`) | PVC `Pending`; Pod `datos` `Pending` | `k describe pvc gratitud-uploads` |

## Método

Los fallos 1 y 2 impiden **crear el contenedor** (mismo síntoma,
`CreateContainerConfigError`): hay que leer los eventos para separarlos. El 3 solo
se ve cuando el Pod ya arranca. El 4 es independiente y está en otro namespace.

## Procedimiento

```bash
cd CLASE-11/RECURSOS/SCRIPTS && ./setup-lab.sh
k -n gratitud-api get pods
k -n gratitud-api describe pod -l app=gratitud-api | sed -n '/Events/,$p'

# ---- Fallo 1: secretKeyRef.key ----
# Events: Error: couldn't find key DB_PASS in Secret gratitud-api/gratitud-db
k -n gratitud-api get secret gratitud-db -o jsonpath='{.data}' | tr ',' '\n'   # ...DB_PASSWORD...
k -n gratitud-api patch deploy api --type=json \
  -p='[{"op":"replace","path":"/spec/template/spec/containers/0/env/0/valueFrom/secretKeyRef/key","value":"DB_PASSWORD"}]'

# ---- Fallo 2: configMapRef.name ----
# Events: configmap "gratitud-cfg" not found
k -n gratitud-api get configmap                    # gratitud-config
k -n gratitud-api patch deploy api --type=json \
  -p='[{"op":"replace","path":"/spec/template/spec/containers/0/envFrom/0/configMapRef/name","value":"gratitud-config"}]'
k -n gratitud-api rollout status deploy/api        # ahora arranca

# ---- Fallo 3: subPath ----
k -n gratitud-api exec deploy/api -- ls -l /etc/gratitud    # no aparece app.conf
k -n gratitud-api get deploy api -o jsonpath='{.spec.template.spec.containers[0].volumeMounts[0].subPath}{"\n"}'  # app.cnf
k -n gratitud-api patch deploy api --type=json \
  -p='[{"op":"replace","path":"/spec/template/spec/containers/0/volumeMounts/0/subPath","value":"app.conf"}]'
k -n gratitud-api rollout status deploy/api
k -n gratitud-api exec deploy/api -- cat /etc/gratitud/app.conf

# ---- Fallo 4: storageClassName del PVC ----
k -n gratitud-datos describe pvc gratitud-uploads   # "no persistent volumes available for this claim"
k get pv gratitud-pv-uploads -o jsonpath='{.spec.storageClassName}{"\n"}'   # manual
# storageClassName es inmutable en un PVC: hay que recrearlo
k -n gratitud-datos get pvc gratitud-uploads -o yaml > /tmp/pvc.yaml
# edita storageClassName: manual  (y quita status/uid/resourceVersion/creationTimestamp)
k -n gratitud-datos delete pvc gratitud-uploads
sed -i 's/gratitud-manual/manual/' /tmp/pvc.yaml
k apply -f /tmp/pvc.yaml
k -n gratitud-datos get pvc gratitud-uploads        # Bound
k -n gratitud-datos rollout status deploy/datos
```

> **Nota.** `spec.storageClassName` de un PVC es inmutable: el fallo 4 se corrige
> **recreando** el PVC. Como el Pod `datos` aún no había escrito nada (estaba
> `Pending`), no se pierde nada.

## Validación

```bash
cd CLASE-11/RECURSOS/SCRIPTS && ./validate-lab.sh
# LAB 11.4 SUPERADO (12 comprobaciones)

k -n gratitud-api  exec deploy/api -- printenv DB_PASSWORD
k -n gratitud-api  exec deploy/api -- cat /etc/gratitud/app.conf
k -n gratitud-datos get pvc gratitud-uploads
```

## Resultado esperado

* Pod `api` `Running` `1/1`; `DB_PASSWORD` y `/etc/gratitud/app.conf` con contenido.
* PVC `gratitud-uploads` `Bound`; Pod `datos` `Running` `1/1`, `/data/uploads` escribible.
* `./validate-lab.sh` termina con `LAB 11.4 SUPERADO`.

## Error frecuente

* Corregir solo uno de los dos `CreateContainerConfigError` y no volver a mirar los eventos: el segundo sigue ahí.
* Intentar `kubectl edit pvc` para cambiar `storageClassName`: el API server lo rechaza (campo inmutable). Hay que recrear.
* "Arreglar" el fallo 3 montando el volumen sin `subPath`: entonces `/etc/gratitud` se convierte en un directorio con solo `app.conf` y oculta lo demás.
* Marcar las referencias como `optional: true`: el Pod arranca pero sin la configuración; los criterios de éxito no se cumplen.

## CKA Tip

```bash
k describe pod <pod> | sed -n '/Events/,$p'          # la causa exacta del ConfigError
k get secret <s> -o jsonpath='{.data}' | tr ',' '\n' # ver las claves reales
k describe pvc <pvc>                                 # por qué no enlaza
k get pv,pvc -A                                      # storageClassName / accessModes / capacidad
```

Ruta mental de config + storage rota:
**clave de Secret → nombre de ConfigMap → ruta/subPath del volumen → binding del PVC.**
