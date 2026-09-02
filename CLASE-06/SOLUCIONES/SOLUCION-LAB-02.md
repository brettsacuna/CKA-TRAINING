# SOLUCIÓN — LAB 6.2 · Nodo y control plane

> **MATERIAL DEL INSTRUCTOR.**

## Diagnóstico

**Incidente A.** El script aplica un `cordon`: el nodo está `Ready,SchedulingDisabled`. No está averiado, está **cerrado**. La distinción es clave: `NotReady` es un problema; `SchedulingDisabled` es una decisión de un administrador que alguien olvidó revertir.

Variante recomendada para grupos avanzados: en lugar del `cordon`, para el kubelet en un worker (`systemctl stop kubelet`). El nodo pasa a `NotReady` en ~40 s y el diagnóstico es real.

**Incidente B.** El instructor introduce un error en `/etc/kubernetes/manifests/kube-apiserver.yaml` (por ejemplo `--secure-port=6444`, o un `image:` con un tag inexistente). El kubelet intenta arrancar el static Pod, falla, y `kubectl` deja de responder.

## Razonamiento técnico resumido

Orden de diagnóstico de un nodo:

```
kubectl get nodes           ¿Ready? ¿SchedulingDisabled?
kubectl describe node       Conditions: MemoryPressure, DiskPressure, PIDPressure, Ready
   (SSH al nodo)
systemctl status kubelet    ¿está corriendo?
journalctl -u kubelet       ¿qué dice?
systemctl status containerd ¿está el runtime?
df -h /var/lib              ¿hay disco?
```

Cuando `kubectl` no responde, la cadena es:
**kubelet → static Pods → API server**. El kubelet sigue vivo (es un servicio de systemd, no un contenedor), así que **sus logs son la fuente de verdad**, y `crictl` sustituye a `kubectl`.

## Procedimiento

### Incidente A

```bash
kubectl get nodes
# cka-worker1   Ready,SchedulingDisabled

kubectl describe node cka-worker1 | sed -n '/Conditions/,/Addresses/p'
kubectl uncordon cka-worker1
kubectl get nodes
```

Variante con kubelet parado:

```bash
ssh root@cka-worker1
systemctl status kubelet          # inactive (dead)
journalctl -u kubelet -n 50 --no-pager
systemctl start kubelet
systemctl enable kubelet
exit
kubectl get nodes                 # Ready en ~30 s
```

### Incidente B

```bash
kubectl get nodes
# The connection to the server ...:6443 was refused

ssh root@cka-master

# 1. ¿Está vivo el kubelet?
systemctl status kubelet          # active (running)

# 2. ¿Qué contenedores hay? (kubectl no sirve)
crictl ps -a | grep -E 'apiserver|etcd|scheduler|controller'
#   etcd Running, kube-apiserver ausente o en Exited

# 3. La fuente de verdad
journalctl -u kubelet -n 100 --no-pager | grep -i -E 'apiserver|error|failed'
crictl logs $(crictl ps -a --name kube-apiserver -q | head -1) 2>&1 | tail -30

# 4. Comparar el manifiesto con una copia buena
ls -l /etc/kubernetes/manifests/
vim /etc/kubernetes/manifests/kube-apiserver.yaml
#   -> corregir el parámetro alterado

# 5. El kubelet detecta el cambio y recrea el static Pod solo
watch crictl ps
exit

kubectl get nodes
kubectl -n kube-system get pods
```

> Si el manifiesto quedó irrecuperable, kubeadm guarda copias en `/etc/kubernetes/tmp/kubeadm-backup-manifests-*`. Menciónalo, pero solo después de que el grupo lo haya intentado.

## Validación

```bash
kubectl get nodes -o wide
kubectl -n kube-system get pods
kubectl create ns c6-prueba
kubectl -n c6-prueba run probe --image=nginx:1.27-alpine
kubectl -n c6-prueba get pod probe -o wide
kubectl delete ns c6-prueba
```

## Resultado esperado

Todos los nodos `Ready`, sin `SchedulingDisabled`; los cuatro static Pods `Running`; el Pod de prueba se programa.

## Error frecuente

* **Reiniciar el nodo** como primera medida. Muchas veces funciona, no enseña nada y en producción destruye la evidencia.
* Buscar `kube-apiserver` con `kubectl` cuando `kubectl` es justo lo que no funciona.
* Editar el manifiesto y no esperar: el kubelet tarda unos segundos en detectarlo. Vigila con `crictl ps`.
* Intentar `systemctl restart kube-apiserver`: **no existe** ese servicio. El API server es un contenedor gestionado por el kubelet.
* Restaurar etcd para arreglar un problema del API server.
* Confundir `NotReady` con `SchedulingDisabled` y perder diez minutos revisando el kubelet de un nodo perfectamente sano.

## CKA Tip

```bash
# Nodo
k get nodes
k describe node <n> | sed -n '/Conditions/,/Addresses/p'
k uncordon <n>

# En el nodo, cuando kubectl no responde
systemctl status kubelet && journalctl -u kubelet -n 60 --no-pager
crictl ps -a
crictl logs <id> | tail -40
ls -l /etc/kubernetes/manifests/
```

**Regla:** si `kubectl` no responde, deja de usar `kubectl`. La respuesta está en `journalctl -u kubelet` y en `crictl`.
