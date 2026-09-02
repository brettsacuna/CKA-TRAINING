# LAB 2.3 — ETCD: snapshot, validación y restore

## Nivel

Avanzado.

## Duración

27 minutos.

## Objetivo

Respaldar el estado completo del cluster, validar que el respaldo sirve y restaurarlo demostrando que el cluster vuelve a un punto anterior en el tiempo.

## Competencias

* Deducir el endpoint y los certificados de etcd desde el manifiesto del API server.
* `etcdctl snapshot save` y `etcdctl endpoint status`.
* `etcdutl snapshot status` para **validar** un snapshot.
* `etcdutl snapshot restore` a un data dir nuevo.
* Reapuntar el static Pod de etcd y recuperar el control plane.

## Escenario

Vas a demostrarle a tu equipo que el backup del cluster funciona. La demostración es la única prueba válida: un snapshot que nadie ha restaurado nunca no es un backup.

Secuencia:

```
1. identificar configuración
2. localizar certificados
3. identificar endpoint
4. crear snapshot
5. validar snapshot
6. restaurar
7. validar el cluster
```

## Estado inicial

* Cluster kubeadm de **un solo control plane** (`cka-master`), con etcd como static Pod local.
* Acceso root por SSH a `cka-master`.
* `etcdctl` y `etcdutl` disponibles en el master. Si no lo están, instálalos desde el release de etcd que coincida con la versión que usa tu cluster.
* Namespace de trabajo: **`c2-etcd`**.

## Requerimientos

### Fase 1 — Reconocimiento

1. A partir de `/etc/kubernetes/manifests/kube-apiserver.yaml`, determina:
   * el **endpoint** de etcd,
   * la ruta de la **CA**,
   * la ruta del **certificado** y de la **clave** de cliente.
2. A partir de `/etc/kubernetes/manifests/etcd.yaml`, determina el **data dir** de etcd.
3. Comprueba la salud del endpoint (`etcdctl endpoint health` y `endpoint status`).

### Fase 2 — Punto de restauración

4. En el namespace `c2-etcd`, crea un Deployment **`antes`** con 2 réplicas de `nginx:1.27-alpine`.
5. Toma un **snapshot** de etcd en `/opt/backup/etcd-<fecha>.db`.
6. **Valida el snapshot**: muestra su hash, revisión y número total de claves. Anota el número de claves.

### Fase 3 — Cambio posterior al backup

7. Crea un segundo Deployment **`despues`** con 2 réplicas en el mismo namespace.
8. Comprueba que ambos Deployments existen.

### Fase 4 — Restore

9. Restaura el snapshot a un **data dir nuevo** (`/var/lib/etcd-restore`). No sobrescribas `/var/lib/etcd`.
10. Detén el control plane moviendo los manifiestos fuera de `/etc/kubernetes/manifests/` y comprueba con `crictl ps` que los contenedores desaparecen.
11. Reapunta el volumen `etcd-data` del manifiesto `etcd.yaml` al data dir restaurado.
12. Devuelve los manifiestos a su sitio y espera a que el API server vuelva.
13. Comprueba qué Deployments existen ahora en `c2-etcd`.

### Fase 5 — Conclusión

14. Explica por escrito: ¿por qué desapareció `despues` y no `antes`? ¿Qué habría pasado si hubieras restaurado sobre `/var/lib/etcd` con el static Pod aún corriendo?

## Restricciones

* No borres `/var/lib/etcd` original.
* No reinicies el nodo.
* No uses `kubectl` para "recrear" `antes`: debe reaparecer por el restore.
* El restore debe hacerse con **`etcdutl`**, no con `etcdctl` (deprecado para esta operación).

## Validación

```bash
# antes del restore
sudo ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key endpoint status --write-out=table

sudo etcdutl snapshot status /opt/backup/etcd-<fecha>.db --write-out=table

# después del restore
kubectl get nodes
kubectl -n c2-etcd get deploy
kubectl -n kube-system get pods
```

## Resultado esperado

* `etcdutl snapshot status` devuelve una tabla con `HASH`, `REVISION`, `TOTAL KEYS`, `TOTAL SIZE`.
* Tras el restore, `kubectl -n c2-etcd get deploy` muestra **solo `antes`**. `despues` ha desaparecido.
* Todos los nodos siguen `Ready` y el control plane vuelve a estar `Running`.

## Criterios de éxito

- [ ] Deduje endpoint y rutas de certificados sin buscarlas en Internet.
- [ ] Identifiqué el data dir en `etcd.yaml`.
- [ ] `endpoint health` responde correctamente.
- [ ] Snapshot creado en `/opt/backup/`.
- [ ] Snapshot **validado** con `etcdutl snapshot status` y número de claves anotado.
- [ ] Restore hecho a un data dir nuevo con `etcdutl`.
- [ ] Control plane detenido y recuperado moviendo manifiestos.
- [ ] `etcd.yaml` reapuntado al data dir restaurado.
- [ ] Tras el restore solo existe el Deployment `antes`.
- [ ] Redacté la explicación del punto 14.
