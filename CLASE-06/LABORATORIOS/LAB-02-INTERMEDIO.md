# LAB 6.2 — Nodo y control plane

## Nivel

Intermedio.

## Duración

28 minutos.

## Objetivo

Salir del namespace de aplicación y diagnosticar lo que hay debajo: un nodo que no acepta trabajo y un control plane que no responde.

## Competencias

* Diagnosticar `NotReady` y `SchedulingDisabled`.
* Leer `journalctl -u kubelet`.
* Usar `crictl` cuando `kubectl` no responde.
* Recuperar un static Pod mal escrito.
* Interpretar condiciones del nodo (`DiskPressure`, `MemoryPressure`, `PIDPressure`).

## Escenario

Dos incidentes seguidos:

**Incidente A.** Un worker deja de aceptar Pods. Las aplicaciones siguen funcionando en el resto del cluster, pero cualquier Pod nuevo asignado a ese nodo se queda esperando.

**Incidente B.** Tras un "cambio menor de configuración" en el control plane, `kubectl` deja de responder por completo:

```
The connection to the server 10.x.x.x:6443 was refused - did you specify the right host or port?
```

## Estado inicial

```bash
cd CLASE-06/RECURSOS/SCRIPTS
./setup-lab.sh nodo        # Incidente A
```

El **Incidente B** lo provoca el instructor en vivo introduciendo un error en un manifiesto de `/etc/kubernetes/manifests/` (por ejemplo, un puerto mal escrito en `kube-apiserver.yaml`). No lo automatices: el valor didáctico está en que los alumnos no sepan qué se cambió.

> **Aviso**: el Incidente B deja el cluster inaccesible durante unos minutos. Toma un snapshot de etcd antes.

## Requerimientos

### Incidente A — El nodo

1. Determina el estado real del nodo y **cuál de las dos condiciones** lo explica: `NotReady` o `SchedulingDisabled`. No son lo mismo.
2. Revisa las `Conditions` del nodo. Anota todas las que no estén en su valor normal.
3. Si el nodo está `NotReady`, entra por SSH y comprueba, en este orden:
   * el estado del servicio `kubelet`,
   * sus últimas líneas de log,
   * el estado del container runtime,
   * el espacio en disco.
4. Corrige el problema y comprueba que el nodo vuelve a aceptar Pods.
5. Documenta: causa raíz, comando que la reveló, corrección aplicada.

### Incidente B — El control plane

6. Con `kubectl` sin respuesta, determina si el problema es de red, de certificado o del propio API server.
7. Desde el nodo del control plane, sin `kubectl`, comprueba qué contenedores están corriendo.
8. Localiza el error en el manifiesto del static Pod y explica **cómo lo has encontrado** (pista: el kubelet lo registra).
9. Corrígelo y espera a que el API server vuelva.
10. Valida que el cluster está sano: nodos, Pods del control plane y una aplicación de prueba.

## Restricciones

* No reinstales el cluster.
* No reinicies los nodos como primera medida: es la salida fácil y esconde la causa.
* En el Incidente B no puedes usar `kubectl` hasta haberlo recuperado.
* No restaures etcd: el problema no está ahí.

## Comandos de diagnóstico

```bash
# Nodo
kubectl get nodes
kubectl describe node <nodo> | sed -n '/Conditions/,/Addresses/p'
kubectl get events -A --sort-by=.lastTimestamp | tail -20

# En el nodo (SSH)
systemctl status kubelet
journalctl -u kubelet -n 80 --no-pager
systemctl status containerd
crictl ps -a
crictl info | head -20
df -h /var/lib
free -m

# Control plane sin kubectl
crictl ps -a | grep -E 'apiserver|etcd|scheduler|controller'
crictl logs <container-id> | tail -40
journalctl -u kubelet -n 100 --no-pager | grep -i -E 'error|failed|manifest'
ls -l /etc/kubernetes/manifests/
```

## Validación

```bash
kubectl get nodes -o wide                     # todos Ready, ninguno SchedulingDisabled
kubectl -n kube-system get pods               # control plane Running
kubectl create ns c6-prueba
kubectl -n c6-prueba run probe --image=nginx:1.27-alpine
kubectl -n c6-prueba get pod probe -o wide    # Running
kubectl delete ns c6-prueba
```

## Resultado esperado

* El nodo vuelve a `Ready` y sin `SchedulingDisabled`, y acepta Pods nuevos.
* `kubectl` responde y los cuatro static Pods del control plane están `Running`.
* Un Pod de prueba se programa correctamente.

## Criterios de éxito

- [ ] Distinguí `NotReady` de `SchedulingDisabled`.
- [ ] Revisé las `Conditions` del nodo.
- [ ] Seguí el orden kubelet → runtime → disco.
- [ ] Documenté causa raíz y corrección del Incidente A.
- [ ] Diagnostiqué el control plane **sin** `kubectl`.
- [ ] Usé `crictl` y `journalctl -u kubelet`.
- [ ] Encontré y corregí el error del static Pod.
- [ ] El cluster quedó sano y validado con un Pod de prueba.
- [ ] No reinicié nodos ni reinstalé nada.
