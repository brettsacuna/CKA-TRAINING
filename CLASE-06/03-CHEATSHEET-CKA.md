# CHEAT SHEET CKA

Comandos limitados a los temas trabajados en este curso.

---

## Preparación del entorno

```bash
alias k=kubectl
export do='--dry-run=client -o yaml'
export now='--force --grace-period=0'
source <(kubectl completion bash)
complete -o default -F __start_kubectl k
```

## Context y namespace

```bash
k config get-contexts
k config current-context
k config use-context <ctx>
k config set-context --current --namespace=<ns>
k get ns
k create ns <ns>
k api-resources                        # recursos y si son namespaced
k explain <recurso>.<campo> --recursive
```

## Pods

```bash
k run <p> --image=<img>
k run <p> --image=<img> --port=80 -l app=web $do > pod.yaml
k run tmp --rm -it --image=busybox:1.36 --restart=Never -- sh
k get pods -o wide --show-labels
k get pods -A | grep -vE 'Running|Completed'
k describe pod <p>
k logs <p> [-c <cont>] [--previous] [-f]
k exec -it <p> [-c <cont>] -- sh
k delete pod <p> $now
k label pod <p> key=value --overwrite
k get pod <p> -o jsonpath='{.spec.containers[*].name}{"\n"}'
```

## Deployments y ReplicaSets

```bash
k create deployment <d> --image=<img> --replicas=3
k get deploy,rs,pods -o wide
k scale deployment <d> --replicas=5
k set image deploy/<d> <cont>=<img>:<tag>
k set resources deploy/<d> --requests=cpu=100m,memory=64Mi --limits=cpu=500m,memory=256Mi
k annotate deploy/<d> kubernetes.io/change-cause="motivo" --overwrite
k rollout status  deploy/<d>
k rollout history deploy/<d> [--revision=N]
k rollout undo    deploy/<d> [--to-revision=N]
k rollout restart deploy/<d>
k rollout pause|resume deploy/<d>
k expose deployment <d> --port=80 --target-port=8080 --name=<svc>
```

## Scheduling

```bash
k get nodes --show-labels
k get nodes -L environment,disktype
k label node <n> environment=production
k label node <n> environment-
k taint node <n> key=value:NoSchedule
k taint node <n> key-
k describe nodes | grep -i -A1 taint
k get priorityclass
k describe pod <p> | sed -n '/Events/,$p'
```

Fragmentos:

```yaml
nodeSelector: {environment: production}

tolerations:
  - {key: team, operator: Equal, value: data, effect: NoSchedule}

affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
        - matchExpressions:
            - {key: environment, operator: In, values: ["production"]}
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 60
        preference:
          matchExpressions:
            - {key: disktype, operator: In, values: ["ssd"]}
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector: {matchLabels: {app: web}}
        topologyKey: kubernetes.io/hostname
```

## Administración del cluster

```bash
k get nodes -o wide
k describe node <n> | sed -n '/Conditions/,/Addresses/p'
k describe node <n> | sed -n '/Allocated resources/,$p'
k cordon <n>
k drain <n> --ignore-daemonsets --delete-emptydir-data
k uncordon <n>

# En el nodo
systemctl status kubelet
journalctl -u kubelet -n 80 --no-pager
crictl ps -a
crictl logs <id> | tail -40
ls -l /etc/kubernetes/manifests/
```

### Upgrade (una minor cada vez)

```bash
# Control plane
sed -i 's#/v1.34/#/v1.35/#' /etc/apt/sources.list.d/kubernetes.list
apt update
apt-mark unhold kubeadm && apt install -y kubeadm=<v> && apt-mark hold kubeadm
kubeadm upgrade plan
kubeadm upgrade apply v<v>
kubectl drain <n> --ignore-daemonsets --delete-emptydir-data
apt-mark unhold kubelet kubectl && apt install -y kubelet=<v> kubectl=<v> && apt-mark hold kubelet kubectl
systemctl daemon-reload && systemctl restart kubelet
kubectl uncordon <n>

# Worker: igual, pero  kubeadm upgrade node
```

## ETCD

```bash
grep etcd /etc/kubernetes/manifests/kube-apiserver.yaml
grep -A3 'name: etcd-data' /etc/kubernetes/manifests/etcd.yaml

export E="--endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key"

etcdctl $E endpoint health
etcdctl $E endpoint status --write-out=table
etcdctl $E snapshot save /opt/backup/etcd.db

etcdutl snapshot status  /opt/backup/etcd.db --write-out=table
etcdutl snapshot restore /opt/backup/etcd.db --data-dir /var/lib/etcd-restore
```

`etcdctl` = cluster vivo (necesita certificados). `etcdutl` = archivo (no los necesita).

## RBAC

```bash
k create role <r> --verb=get,list --resource=pods -n <ns>
k create rolebinding <rb> --role=<r> --user=<u> -n <ns>
k create clusterrole <cr> --verb=delete --resource=deployments
k create clusterrolebinding <crb> --clusterrole=<cr> --user=<u>
k create rolebinding <rb> --clusterrole=<cr> --user=<u> -n <ns>   # alcance limitado
k create sa <sa> -n <ns>
k create rolebinding <rb> --role=<r> --serviceaccount=<ns>:<sa> -n <ns>

k auth can-i <verb> <resource> --as <user> -n <ns>
k auth can-i <verb> <resource> --as system:serviceaccount:<ns>:<sa> -n <ns>
k auth can-i --list --as <user> -n <ns>
```

| Role | Binding | Alcance |
|---|---|---|
| Role | RoleBinding | un namespace |
| ClusterRole | ClusterRoleBinding | todo el cluster |
| ClusterRole | RoleBinding | un namespace, definición reutilizada |

## Storage

```bash
k get pv -o custom-columns=NAME:.metadata.name,CAP:.spec.capacity.storage,\
MODES:.spec.accessModes,SC:.spec.storageClassName,PHASE:.status.phase,CLAIM:.spec.claimRef.name
k get pvc -A
k describe pvc <pvc> | sed -n '/Events/,$p'
k get storageclass
k patch pv <pv> --type=json -p='[{"op":"remove","path":"/spec/claimRef"}]'   # Released -> Available
```

Modos: `ReadWriteOnce` (RWO) · `ReadOnlyMany` (ROX) · `ReadWriteMany` (RWX) · `ReadWriteOncePod` (RWOP).
`reclaimPolicy`: solo `Retain` y `Delete`.

## ConfigMaps y Secrets

```bash
k create configmap <cm> --from-literal=K=V
k create configmap <cm> --from-file=index.html=archivo.html
k create configmap <cm> --from-env-file=vars.env
k create secret generic <s> --from-literal=password=x
k create secret tls <s> --cert=cert.pem --key=key.pem
k get secret <s> -o jsonpath='{.data.password}' | base64 -d; echo
k get secret <s> -o jsonpath='{.data}{"\n"}'          # nombres de las claves
```

```yaml
envFrom: [{configMapRef: {name: app-config}}]
env:
  - name: DB_PASSWORD
    valueFrom: {secretKeyRef: {name: db-cred, key: password}}
volumes:
  - {name: cred, secret: {secretName: db-cred}}
volumeMounts:
  - {name: cred, mountPath: /etc/cred, readOnly: true}
```

Volumen → se actualiza en caliente. Variable de entorno → requiere `rollout restart`.

## Services

```bash
k expose pod <p>        --name=<svc> --port=80 --target-port=8080
k expose deployment <d> --name=<svc> --type=NodePort --port=80
k get svc,endpointslices
k get endpointslices -l kubernetes.io/service-name=<svc>
k get svc <svc> -o jsonpath='{.spec.selector}{"\n"}'
k patch svc <svc> -p '{"spec":{"selector":{"app":"web"}}}'
```

`nodePort` no se puede fijar con `expose`: genera el YAML y edítalo.

## DNS

```bash
k -n kube-system get svc kube-dns
k -n kube-system get cm coredns -o yaml
k -n kube-system logs deploy/coredns | tail
k exec <p> -- cat /etc/resolv.conf
k run tmp --rm -it --image=busybox:1.36 --restart=Never -- nslookup <svc>.<ns>
```

`<svc>.<ns>.svc.cluster.local` · `<pod>.<svc>.<ns>.svc.cluster.local` (StatefulSet).

## Ingress

```bash
k get ingressclass
k create ingress <ing> --class=<class> \
  --rule="/service1=service1:80" --rule="/service2=service2:80"
k create ingress <ing> --class=<class> \
  --rule="host.com/*=svc:80,tls=<secret-tls>"
k describe ingress <ing>
curl -kv https://host.com:<np>/path --resolve host.com:<np>:<IP-NODO>
```

## NetworkPolicy

```bash
k get networkpolicy -n <ns>
k describe networkpolicy <np>
k exec <p> -- curl -s --max-time 3 -o /dev/null -w '%{http_code}\n' http://<svc>
```

```yaml
# default deny
spec: {podSelector: {}, policyTypes: [Ingress, Egress]}

# permitir DNS (imprescindible tras un default deny)
egress:
  - to: [{namespaceSelector: {matchLabels: {kubernetes.io/metadata.name: kube-system}}}]
    ports: [{protocol: UDP, port: 53}, {protocol: TCP, port: 53}]
```

AND (un elemento) frente a OR (dos elementos):

```yaml
- from: [{namespaceSelector: {...}, podSelector: {...}}]   # AND
- from: [{namespaceSelector: {...}}, {podSelector: {...}}] # OR
```

## Troubleshooting

```bash
k get pods -A -o wide | grep -vE 'Running|Completed'
k describe pod <p> | sed -n '/Events/,$p'
k logs <p> --previous
k get events -n <ns> --sort-by=.lastTimestamp | tail -30
k get all,pvc,ingress,networkpolicy -n <ns>
k top nodes ; k top pods -n <ns> --sort-by=cpu
k describe pod <p> | grep -A5 'Last State'
```

| Estado | Capa | Primer comando |
|---|---|---|
| `Pending` | scheduler | `describe pod` → Events |
| `ContainerCreating` atascado | volumen o red del Pod | `describe pod` → Events |
| `ImagePullBackOff` | registry | `describe pod` → Events |
| `CreateContainerConfigError` | ConfigMap / Secret | `describe pod` + `get cm,secret` |
| `CrashLoopBackOff` | aplicación | `logs --previous` |
| `Running 0/1` | readinessProbe | `describe pod` → Conditions |
| `OOMKilled` (exit 137) | `limits.memory` | `describe pod` → Last State |
| Nodo `NotReady` | kubelet / runtime / disco | `journalctl -u kubelet` |
| `kubectl` no responde | static Pod del API server | `crictl ps -a` |
