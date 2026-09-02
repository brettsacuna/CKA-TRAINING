# SOLUCIÓN — LAB 2.2 · Upgrade kubeadm v1.34 → v1.35

> **MATERIAL DEL INSTRUCTOR.**

## Diagnóstico

El error que comete casi todo el mundo la primera vez: `apt install kubeadm=1.35.x` falla con *"Version not found"* porque **el repositorio sigue apuntando a v1.34**. Desde el cambio a `pkgs.k8s.io` hay **un repositorio distinto por cada minor**. Es la primera cosa que hay que enseñar.

## Razonamiento técnico resumido

Orden y por qué:

```
kubeadm  ->  upgrade apply  ->  kubelet + kubectl  ->  restart kubelet
```

* `kubeadm` es quien escribe los nuevos manifiestos de los static Pods; debe ser el primero.
* `kubelet` solo puede estar **igual o hasta 3 minors por debajo** del API server, nunca por encima. Por eso se actualiza después.
* Los workers usan **`kubeadm upgrade node`**: no aplican una versión de cluster, solo actualizan su configuración local de kubelet.
* No se saltan minors: 1.34 → 1.35 → 1.36.

## Procedimiento

### 0. Seguro

```bash
ssh root@cka-master '/path/CLASE-02/RECURSOS/SCRIPTS/etcd-backup.sh /opt/backup/pre-upgrade.db'
```

### 1. Control plane (`cka-master`)

```bash
# Repositorio a la minor de destino
sudo sed -i 's#/v1.34/#/v1.35/#' /etc/apt/sources.list.d/kubernetes.list
sudo curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.35/deb/Release.key \
  | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg --yes
sudo apt update
apt-cache madison kubeadm | head

# Solo kubeadm
sudo apt-mark unhold kubeadm
sudo apt install -y kubeadm=1.35.0-1.1
sudo apt-mark hold kubeadm
kubeadm version

# Plan y aplicación
sudo kubeadm upgrade plan
sudo kubeadm upgrade apply v1.35.0

# kubelet y kubectl
kubectl drain cka-master --ignore-daemonsets --delete-emptydir-data
sudo apt-mark unhold kubelet kubectl
sudo apt install -y kubelet=1.35.0-1.1 kubectl=1.35.0-1.1
sudo apt-mark hold kubelet kubectl
sudo systemctl daemon-reload
sudo systemctl restart kubelet
kubectl uncordon cka-master

kubectl get nodes
```

### 2. Cada worker, uno a uno

```bash
# --- en el worker
sudo sed -i 's#/v1.34/#/v1.35/#' /etc/apt/sources.list.d/kubernetes.list
sudo curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.35/deb/Release.key \
  | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg --yes
sudo apt update
sudo apt-mark unhold kubeadm && sudo apt install -y kubeadm=1.35.0-1.1 && sudo apt-mark hold kubeadm

# --- desde el master
kubectl drain cka-worker1 --ignore-daemonsets --delete-emptydir-data

# --- de vuelta en el worker
sudo kubeadm upgrade node
sudo apt-mark unhold kubelet kubectl
sudo apt install -y kubelet=1.35.0-1.1 kubectl=1.35.0-1.1
sudo apt-mark hold kubelet kubectl
sudo systemctl daemon-reload && sudo systemctl restart kubelet

# --- desde el master
kubectl uncordon cka-worker1
```

Repetir para `cka-worker2`.

### 3. Monitorización durante la ventana

```bash
watch -n2 'kubectl -n c2-basico get deploy inventario; kubectl get nodes'
```

## Validación

```bash
kubectl get nodes -o wide
kubectl -n kube-system get pods -o wide
kubectl -n kube-system get pod -l component=kube-apiserver \
  -o jsonpath='{.items[0].spec.containers[0].image}{"\n"}'
kubectl -n kube-system get deploy coredns \
  -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
kubectl -n c2-basico get deploy inventario
kubectl get nodes | grep -i SchedulingDisabled   # vacío
```

## Resultado esperado

```
NAME          STATUS   ROLES           VERSION
cka-master    Ready    control-plane   v1.35.0
cka-worker1   Ready    <none>          v1.35.0
cka-worker2   Ready    <none>          v1.35.0
```

`inventario  4/4  4  4` durante toda la operación.

## Error frecuente

| Error | Síntoma | Corrección |
|---|---|---|
| No cambiar el repositorio | `apt install kubeadm=1.35.x` → *Version not found* | Editar `kubernetes.list` **y** la clave GPG |
| Actualizar `kubelet` antes de `kubeadm upgrade apply` | El kubelet no arranca o el nodo queda `NotReady` | Orden: kubeadm → apply → kubelet |
| Usar `kubeadm upgrade apply` en un worker | Error de configuración del cluster | En workers: `kubeadm upgrade node` |
| Olvidar `systemctl daemon-reload` | El kubelet arranca con la unidad antigua | Siempre `daemon-reload` antes de `restart` |
| Olvidar `uncordon` | El nodo queda vacío y nadie entiende por qué | `kubectl uncordon <node>` |
| Saltar de 1.34 a 1.36 | `kubeadm` rechaza el salto | Una minor cada vez |

## CKA Tip

```bash
# Secuencia comprimida (control plane)
apt-mark unhold kubeadm && apt install -y kubeadm=<v> && apt-mark hold kubeadm
kubeadm upgrade plan
kubeadm upgrade apply v<v>
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data
apt-mark unhold kubelet kubectl && apt install -y kubelet=<v> kubectl=<v> && apt-mark hold kubelet kubectl
systemctl daemon-reload && systemctl restart kubelet
kubectl uncordon <node>

# Worker: idéntico, cambiando 'upgrade apply' por 'upgrade node'
```

En el examen la tarea de upgrade suele darte la versión exacta. **Léela dos veces**: casi siempre pide actualizar *solo el control plane* o *solo un nodo concreto*.
