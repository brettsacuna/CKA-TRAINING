# SOLUCIÓN — LAB 3.2 · emptyDir, PV y PVC

> **MATERIAL DEL INSTRUCTOR.**

## Diagnóstico

Dos aprendizajes que solo se fijan viéndolos:

1. `emptyDir` **no persiste**. El alumno lo comprueba borrando el Pod (paso 4).
2. Un PVC **no elige** su PV: el control plane empareja por clase, modo de acceso, capacidad y, si existe, `selector`. El PVC pide 1Gi y recibe un PV de 2Gi, y el `CAPACITY` que muestra es **2Gi**, no 1Gi. Eso desconcierta siempre.

## Razonamiento técnico resumido

Un PV y un PVC enlazan si **todo** esto coincide:

| Criterio | Regla |
|---|---|
| `storageClassName` | Debe ser idéntico (incluida la cadena vacía `""`) |
| `accessModes` | El PV debe **ofrecer** el modo que el PVC **pide** |
| `capacity` | El PV debe ser **>=** lo solicitado |
| `selector` (opcional) | Si el PVC lo declara, los labels del PV deben cumplirlo |
| `claimRef` | El PV no debe estar ya reservado por otro claim |

`persistentVolumeReclaimPolicy`:

* `Delete` — al liberar el claim, el PV y su almacenamiento se borran.
* `Retain` — el PV queda en **`Released`**: conserva los datos y el `claimRef`, y **no vuelve a estar disponible** hasta que un administrador borre ese `claimRef`.
* `Recycle` fue eliminado de Kubernetes.

## Procedimiento

### Parte A

```bash
k create ns c3-inter && k config set-context --current --namespace=c3-inter
k apply -f ../RECURSOS/YAML/01-emptydir-sitio.yaml
k get pod sitio                      # 2/2 Running
k run tmp --rm -it --image=busybox:1.36 --restart=Never -- \
  wget -qO- http://$(k get pod sitio -o jsonpath='{.status.podIP}')
# -> <h1>Hola CKA</h1>

k delete pod sitio && k apply -f ../RECURSOS/YAML/01-emptydir-sitio.yaml
# el contenido vuelve porque 'writer' lo reescribe al arrancar,
# pero el directorio se creó VACIO: el volumen anterior se destruyó con el Pod.
```

> Para que el alumno lo vea sin ambigüedad: que escriba un segundo archivo a mano (`k exec sitio -c web -- sh -c 'echo x > /usr/share/nginx/html/manual.txt'`), borre el Pod y compruebe que `manual.txt` **no** vuelve.

### Parte B

```bash
# 5  en el worker
ssh root@cka-worker1 'mkdir -p /mnt/data-a /mnt/data-b; \
  echo "<h1>ALFA</h1>" > /mnt/data-a/index.html; \
  echo "<h1>BETA</h1>" > /mnt/data-b/index.html'

# 6
k apply -f ../RECURSOS/YAML/02-pv-estaticos.yaml
k get pv

# 7-9
k apply -f ../RECURSOS/YAML/03-pvc-selector.yaml
k get pvc,pv
k exec web-persistente -- cat /usr/share/nginx/html/index.html    # <h1>BETA</h1>

# 10
k delete pod web-persistente
k apply -f ../RECURSOS/YAML/03-pvc-selector.yaml
k exec web-persistente -- cat /usr/share/nginx/html/index.html    # sigue BETA

# 11
k delete pvc pvc-sitio
k get pv
# pv-b  ...  Released  ...
```

Para reutilizar `pv-b`:

```bash
k patch pv pv-b --type=json -p='[{"op":"remove","path":"/spec/claimRef"}]'
k get pv pv-b        # -> Available
```

## Validación

```bash
k get pv -o custom-columns=NAME:.metadata.name,CAP:.spec.capacity.storage,\
MODES:.spec.accessModes,SC:.spec.storageClassName,PHASE:.status.phase,CLAIM:.spec.claimRef.name
k get pvc
```

## Resultado esperado

```
NAME   CAP   MODES           SC       PHASE       CLAIM
pv-a   2Gi   [ReadWriteOnce] manual   Available
pv-b   2Gi   [ReadWriteOnce] manual   Bound       pvc-sitio

NAME        STATUS   VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS
pvc-sitio   Bound    pv-b     2Gi        RWO            manual
```

## Error frecuente

* **Esperar que el PVC muestre 1Gi.** Muestra la capacidad del PV enlazado (2Gi). Un PVC es una *solicitud mínima*, no una cuota.
* Omitir `storageClassName: manual` en el PVC. Si el cluster tiene una StorageClass por defecto, el PVC intentará aprovisionamiento dinámico y **nunca** mirará tus PV estáticos. Si no la tiene, quedará `Pending`.
* Confundir `storageClassName: ""` con omitir el campo. **No es lo mismo**: `""` desactiva explícitamente la clase por defecto; omitirlo la aplica.
* `hostPath` en un cluster multinodo: el Pod puede aterrizar en un nodo donde el directorio no existe y ver un directorio vacío. Es el motivo por el que `hostPath` no sirve para producción; menciona `local` + `nodeAffinity` como alternativa correcta.
* Esperar que `pv-b` vuelva a `Available` solo. Con `Retain` no ocurre nunca.

## CKA Tip

```bash
# Tabla de PV que cabe en una pantalla
k get pv -o custom-columns=NAME:.metadata.name,CAP:.spec.capacity.storage,\
MODES:.spec.accessModes,SC:.spec.storageClassName,PHASE:.status.phase

# ¿Por qué no enlaza el PVC?  Siempre los eventos
k describe pvc <pvc> | sed -n '/Events/,$p'

# Liberar un PV Released
k patch pv <pv> --type=json -p='[{"op":"remove","path":"/spec/claimRef"}]'
```
