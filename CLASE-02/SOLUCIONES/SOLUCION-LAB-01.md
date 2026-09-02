# SOLUCIÓN — LAB 2.1 · Inventario, cordon y drain

> **MATERIAL DEL INSTRUCTOR.**

## Diagnóstico

Laboratorio de reconocimiento. El punto de aprendizaje real es el paso 10: `drain` **falla a propósito** dos veces y el alumno debe leer el mensaje para descubrir `--ignore-daemonsets` y `--delete-emptydir-data`.

## Razonamiento técnico resumido

* En kubeadm, el control plane **no son Deployments**: son **static Pods** que el kubelet arranca leyendo `/etc/kubernetes/manifests/`. No los gobierna el scheduler y no puedes borrarlos con `kubectl`.
* `cordon` = "no aceptes Pods nuevos". `drain` = `cordon` + desalojar los que ya están.
* `drain` se niega a desalojar Pods de DaemonSet (volverían inmediatamente) y Pods con `emptyDir` (perderían datos). Hay que autorizarlo explícitamente.
* Kubernetes **no reequilibra** por sí solo: el scheduler solo decide en el momento de crear un Pod. Tras el `uncordon` nada se mueve hasta que se cree un Pod nuevo.

## Procedimiento

```bash
# 1
k create ns c2-basico

# 2  Inventario
k get nodes -o wide
k version
ssh root@cka-master 'kubeadm version -o short; kubelet --version; kubectl version --client -o yaml | head -5'
k get nodes -o custom-columns=NODE:.metadata.name,RUNTIME:.status.nodeInfo.containerRuntimeVersion,KUBELET:.status.nodeInfo.kubeletVersion

# 3
ssh root@cka-master 'ls -1 /etc/kubernetes/manifests/'
# etcd.yaml  kube-apiserver.yaml  kube-controller-manager.yaml  kube-scheduler.yaml

# 4
ssh root@cka-master 'crictl ps'

# 5
ssh root@cka-master 'grep -A3 "name: etcd-data" -B6 /etc/kubernetes/manifests/etcd.yaml | grep path'
# -> /var/lib/etcd

# 6-7
k -n c2-basico apply -f ../RECURSOS/YAML/03-inventario-deployment.yaml
k -n c2-basico get pods -o wide

# 8-9
k cordon cka-worker1
k get nodes                       # cka-worker1  Ready,SchedulingDisabled
k -n c2-basico run probe --image=nginx:1.27-alpine
k -n c2-basico get pod probe -o wide   # NO esta en cka-worker1

# 10  drain: los dos errores esperados
k drain cka-worker1
#   error: unable to drain node ... cannot delete DaemonSet-managed Pods (use --ignore-daemonsets)
k drain cka-worker1 --ignore-daemonsets
#   error: ... cannot delete Pods with local storage (use --delete-emptydir-data)
k drain cka-worker1 --ignore-daemonsets --delete-emptydir-data

# 11
k -n c2-basico get pods -o wide       # ninguna replica en cka-worker1

# 12
k uncordon cka-worker1
k get nodes
```

**13 —** No, las réplicas no vuelven. El scheduler solo interviene al **crear** un Pod. El ReplicaSet ya tiene sus 4 Pods `Running`; no hay motivo para recrearlos. Si quieres reequilibrar, hay que forzar la recreación (`kubectl rollout restart deployment/inventario`) o usar un descheduler.

## Validación

```bash
k get nodes -o wide
k -n c2-basico get pods -o wide
k get nodes | grep -c SchedulingDisabled     # 0 al terminar
```

## Resultado esperado

```
NAME          STATUS   ROLES           VERSION
cka-master    Ready    control-plane   v1.34.x
cka-worker1   Ready    <none>          v1.34.x
cka-worker2   Ready    <none>          v1.34.x
```

Tras el drain, las 4 réplicas de `inventario` están `Running` en los nodos restantes.

## Error frecuente

* Ejecutar `drain` sobre el **control plane** al principio de la clase y quedarse sin CoreDNS. Explica el orden: primero se practica en un worker.
* Añadir `--force` al `drain` sin entender qué hace: `--force` desaloja Pods **sin controlador** (Pods sueltos), que se pierden para siempre. No es el flag que resuelve los dos errores de este laboratorio.
* Confundir `cordon` con `drain`.

## CKA Tip

```bash
# El drain que funciona el 95% de las veces en el examen
k drain <node> --ignore-daemonsets --delete-emptydir-data --force

# Devolver al servicio (se olvida constantemente)
k uncordon <node>

# ¿Qué versión corre cada nodo, en una línea?
k get nodes -o wide
```
