# SOLUCIÓN — LAB 5.1 · Services, EndpointSlice y CoreDNS

> **MATERIAL DEL INSTRUCTOR.**

## Diagnóstico

Dos ideas que hay que dejar clavadas:

1. **El DNS no balancea.** `web-ci` resuelve siempre a la misma ClusterIP; quien reparte entre Pods es **kube-proxy** (iptables o IPVS) en el nodo.
2. **Un Pod no `Ready` desaparece del EndpointSlice.** Es el mecanismo que hace que un rollout roto no reciba tráfico, y explica por qué un Service "sin endpoints" a veces sí tiene Pods corriendo.

## Razonamiento técnico resumido

```
Cliente -> ClusterIP (virtual, no existe en ninguna interfaz)
             -> kube-proxy (iptables/IPVS) -> IP de un Pod del EndpointSlice
```

`/etc/resolv.conf` de un Pod:

```
nameserver 10.96.0.10
search c5-basico.svc.cluster.local svc.cluster.local cluster.local
options ndots:5
```

`ndots:5` significa: si el nombre consultado tiene **menos de 5 puntos**, se prueban primero los sufijos de `search`. Por eso `web-ci` funciona dentro del namespace, `web-ci.c5-basico` funciona desde cualquier namespace, y `example.com` genera varias consultas fallidas antes de la buena.

## Procedimiento

```bash
k create ns c5-basico && k config set-context --current --namespace=c5-basico

# 2-6
k apply -f ../RECURSOS/YAML/01-services-tipos.yaml
for p in $(k get pods -l app=web -o name); do
  n=${p#pod/}; k exec $n -- sh -c "echo '<h1>$n</h1>' > /usr/share/nginx/html/index.html"
done

# 7-8
k get endpointslices
k scale deploy web --replicas=5 && k get endpointslices
k scale deploy web --replicas=3

# 9
k patch deploy web --type=json -p='[{"op":"add",
  "path":"/spec/template/spec/containers/0/readinessProbe",
  "value":{"httpGet":{"path":"/","port":9999},"periodSeconds":3}}]'
k get pods            # 0/1 READY
k get endpointslices  # sin direcciones
k patch deploy web --type=json -p='[{"op":"remove",
  "path":"/spec/template/spec/containers/0/readinessProbe"}]'

# 10-12
k run tmp --rm -it --image=nicolaka/netshoot --restart=Never -- bash
  cat /etc/resolv.conf
  nslookup web-ci
  nslookup web-ci.c5-basico
  nslookup web-ci.c5-basico.svc.cluster.local
  nslookup externo                     # CNAME -> example.com
  for i in $(seq 1 10); do curl -s http://web-ci; done   # alternan los Pods
  exit

# 13
k -n kube-system get svc kube-dns
k -n kube-system get deploy coredns

# 14
k -n kube-system edit cm coredns        # añadir la línea 'log' dentro del bloque .:53 { }
k -n kube-system rollout restart deploy/coredns
k run tmp --rm -it --image=busybox:1.36 --restart=Never -- nslookup web-ci.c5-basico
k -n kube-system logs deploy/coredns | tail -20
# revertir
k -n kube-system edit cm coredns        # quitar 'log'
k -n kube-system rollout restart deploy/coredns
```

## Validación

```bash
k get svc,endpointslices
k -n kube-system get cm coredns -o yaml | grep -c '^\s*log$'    # 0 al terminar
```

## Resultado esperado

```
NAME      TYPE           CLUSTER-IP     EXTERNAL-IP   PORT(S)
externo   ExternalName   <none>         example.com   <none>
web-ci    ClusterIP      10.96.140.12   <none>        80/TCP
web-np    NodePort       10.96.55.201   <none>        80:31500/TCP
```

## Error frecuente

* Pensar que el DNS reparte carga entre Pods.
* Creer que `ExternalName` crea un proxy. No crea nada: solo un registro DNS.
* No revertir el `log` de CoreDNS y dejar el cluster generando ruido.
* Diagnosticar "el DNS está roto" cuando lo que falla son los endpoints. `nslookup` OK + `curl` timeout = endpoints, no DNS.
* Olvidar que `kube-dns` es el **nombre del Service**, aunque el software sea CoreDNS. Es un resto histórico y confunde siempre.

## CKA Tip

```bash
k get endpointslices -l kubernetes.io/service-name=<svc>
k run tmp --rm -it --image=busybox:1.36 --restart=Never -- nslookup <svc>.<ns>
k -n kube-system get svc kube-dns -o jsonpath='{.spec.clusterIP}{"\n"}'
k exec <pod> -- cat /etc/resolv.conf
```

**FQDN de un Service:** `<svc>.<ns>.svc.cluster.local` · **de un Pod de StatefulSet:** `<pod>.<svc>.<ns>.svc.cluster.local`.
