# SOLUCIÓN — LAB 2.3 · ETCD snapshot, validación y restore

> **MATERIAL DEL INSTRUCTOR.**

## Diagnóstico

El error clásico es intentar el restore **con etcd corriendo y sobre `/var/lib/etcd`**. El proceso escribe sobre el data dir vivo, etcd se corrompe y el cluster no vuelve. El orden correcto es: restaurar a un **directorio nuevo**, parar el control plane, reapuntar el manifiesto y devolverlo.

## Razonamiento técnico resumido

* etcd guarda **todo el estado del cluster**. Restaurarlo devuelve el cluster a ese instante: los objetos creados después desaparecen.
* Los certificados de cliente que necesita `etcdctl` están en `/etc/kubernetes/pki/etcd/`. El API server declara cuáles usa él en su propio manifiesto: eso te da el endpoint y las rutas sin memorizar nada.
* `etcdctl` habla con un etcd **vivo** (snapshot save, endpoint status). `etcdutl` trabaja **sobre archivos** (snapshot status, snapshot restore). Desde etcd 3.5, `etcdctl snapshot restore` está deprecado y avisa por consola.
* Mover los manifiestos fuera de `/etc/kubernetes/manifests/` es la forma soportada de parar el control plane sin tocar systemd: el kubelet los ve desaparecer y mata los contenedores.

## Procedimiento

### Fase 1 — Reconocimiento

```bash
sudo grep etcd /etc/kubernetes/manifests/kube-apiserver.yaml
#  --etcd-cafile=/etc/kubernetes/pki/etcd/ca.crt
#  --etcd-certfile=/etc/kubernetes/pki/apiserver-etcd-client.crt
#  --etcd-keyfile=/etc/kubernetes/pki/apiserver-etcd-client.key
#  --etcd-servers=https://127.0.0.1:2379

sudo grep -A3 'name: etcd-data' /etc/kubernetes/manifests/etcd.yaml
#  path: /var/lib/etcd

export E="--endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key"

sudo etcdctl $E endpoint health
sudo etcdctl $E endpoint status --write-out=table
```

### Fase 2 — Punto de restauración

```bash
kubectl create ns c2-etcd
kubectl -n c2-etcd create deployment antes --image=nginx:1.27-alpine --replicas=2

sudo mkdir -p /opt/backup
sudo etcdctl $E snapshot save /opt/backup/etcd-$(date +%F).db
sudo etcdutl snapshot status /opt/backup/etcd-$(date +%F).db --write-out=table
```

Salida esperada:

```
+----------+----------+------------+------------+
|   HASH   | REVISION | TOTAL KEYS | TOTAL SIZE |
+----------+----------+------------+------------+
| 8f1c3d0a |    18422 |       1147 |     5.2 MB |
+----------+----------+------------+------------+
```

### Fase 3 — Cambio posterior

```bash
kubectl -n c2-etcd create deployment despues --image=nginx:1.27-alpine --replicas=2
kubectl -n c2-etcd get deploy      # antes, despues
```

### Fase 4 — Restore

```bash
# 9  restaurar a un DIRECTORIO NUEVO
sudo etcdutl snapshot restore /opt/backup/etcd-$(date +%F).db \
  --data-dir /var/lib/etcd-restore

# 10  parar el control plane
sudo mkdir -p /etc/kubernetes/manifests-off
sudo mv /etc/kubernetes/manifests/*.yaml /etc/kubernetes/manifests-off/
sudo crictl ps            # los contenedores del control plane desaparecen

# 11  reapuntar el volumen etcd-data
sudo vim /etc/kubernetes/manifests-off/etcd.yaml
```

```yaml
  volumes:
    - hostPath:
        path: /var/lib/etcd-restore     # antes: /var/lib/etcd
        type: DirectoryOrCreate
      name: etcd-data
```

```bash
# 12  devolver los manifiestos
sudo mv /etc/kubernetes/manifests-off/*.yaml /etc/kubernetes/manifests/
sudo crictl ps -a        # esperar a que vuelvan etcd y kube-apiserver
watch kubectl get nodes

# 13
kubectl -n c2-etcd get deploy
# NAME    READY
# antes   2/2        <- 'despues' ha desaparecido
```

### Fase 5 — Explicación (punto 14)

`despues` se creó **después** del snapshot, por lo que su registro nunca llegó al archivo `.db`. El restore devuelve el keyspace exactamente al estado del momento del `snapshot save`: todo lo posterior se pierde. Es la definición de RPO (*Recovery Point Objective*) y es el argumento para automatizar snapshots frecuentes.

Si se restaura sobre `/var/lib/etcd` con el static Pod aún corriendo, se escriben archivos WAL y snap bajo un etcd activo: la base queda inconsistente, etcd no arranca y el API server queda inaccesible. La recuperación entonces exige borrar el data dir y volver a restaurar con etcd parado.

## Validación

```bash
kubectl get nodes
kubectl -n kube-system get pods
kubectl -n c2-etcd get deploy       # solo 'antes'
sudo etcdctl $E endpoint status --write-out=table
```

## Error frecuente

* Usar `etcdctl snapshot restore`: funciona pero **avisa de deprecación**; en el examen usa `etcdutl`.
* Restaurar sin parar el control plane.
* Restaurar sobre `/var/lib/etcd`.
* Olvidar cambiar el `hostPath` del volumen y preguntarse por qué el restore "no hizo nada".
* Cambiar el `mountPath` del contenedor en lugar del `hostPath` del volumen: el contenedor espera `/var/lib/etcd` **dentro**; lo que cambia es de dónde viene ese directorio **fuera**.
* Dejar los certificados de `apiserver-etcd-client` en el comando de `etcdctl`: funcionan, pero los del laboratorio son los de `server.crt`. Cualquiera de los dos pares es válido; lo importante es entender por qué.

## CKA Tip

```bash
# Backup en una línea (memorízala)
etcdctl --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  snapshot save /opt/backup/etcd.db

# Validar (no necesita certificados: trabaja sobre el archivo)
etcdutl snapshot status /opt/backup/etcd.db --write-out=table

# Restore (tampoco necesita certificados)
etcdutl snapshot restore /opt/backup/etcd.db --data-dir /var/lib/etcd-restore
```

**Regla:** `etcdctl` = cluster vivo (necesita certificados). `etcdutl` = archivo (no los necesita). Si te piden certificados para un `snapshot status`, estás usando el binario equivocado.
