# SOLUCIÓN — LAB 9.1 · La IP que desaparece y el ClusterIP

> **MATERIAL DEL INSTRUCTOR.**

## Diagnóstico

Dos ideas que hay que dejar clavadas:

1. **La IP de un Pod pertenece al Pod, no a la aplicación.** Se asigna al arrancar y se pierde al morir. Cualquier cosa que la guarde queda obsoleta en el primer reinicio.
2. **El Service desacopla identidad de instancia.** La `ClusterIP` y el nombre DNS son estables; detrás, el `EndpointSlice` cambia solo. El cliente nunca se entera.

## Razonamiento técnico resumido

```
Cliente -> web-ci (ClusterIP virtual, no existe en ninguna interfaz)
             -> kube-proxy (iptables/IPVS) en el nodo
             -> IP de un Pod del EndpointSlice : targetPort
```

El `EndpointSlice` lo mantiene el **controlador de endpoints** (parte del
kube-controller-manager): observa los Pods que encajan con `spec.selector` del
Service y están `Ready`, y escribe sus IPs. `kube-proxy` lee esos objetos y
programa las reglas del nodo.

## Procedimiento

```bash
k create ns c9-basico
k config set-context --current --namespace=c9-basico

# 2-5  La IP efimera
k apply -f ../RECURSOS/YAML/01-pod-ip-efimera.yaml
k rollout status deploy/web
k get pod -l app=web -o wide            # anota IP y NODE de, p.ej., web-xxxx-aaaaa
k delete pod web-xxxx-aaaaa
k get pod -l app=web -o wide            # el sustituto tiene OTRA IP

# 6-9  El ClusterIP no cambia
k apply -f ../RECURSOS/YAML/02-service-clusterip.yaml   # o: k expose deploy web --name web-ci --port 80
k get svc web-ci -o jsonpath='{.spec.clusterIP}{"\n"}'  # anota
k run tmp --rm -it --image=nicolaka/netshoot --restart=Never -- \
  sh -c 'nslookup web-ci; curl -s http://web-ci | head -1'
k delete pod "$(k get pod -l app=web -o name | head -1 | cut -d/ -f2)"
k run tmp --rm -it --image=nicolaka/netshoot --restart=Never -- curl -s http://web-ci | head -1
# la CLUSTER-IP es la misma y sigue respondiendo

# 10-12  EndpointSlice
k get endpointslices -l kubernetes.io/service-name=web-ci
k get endpointslices -l kubernetes.io/service-name=web-ci \
  -o jsonpath='{range .items[*]}{range .endpoints[*]}{.addresses[0]}{" "}{.conditions.ready}{"\n"}{end}{end}'
k scale deploy web --replicas=5 && sleep 3 && k get endpointslices -l kubernetes.io/service-name=web-ci
k scale deploy web --replicas=3

k patch deploy web --type=json -p='[{"op":"add",
  "path":"/spec/template/spec/containers/0/readinessProbe",
  "value":{"httpGet":{"path":"/","port":9999},"periodSeconds":3}}]'
k get pod -l app=web                    # 0/1 READY
k get endpointslices -l kubernetes.io/service-name=web-ci \
  -o jsonpath='{.items[*].endpoints[*].conditions.ready}{"\n"}'   # false / sin direcciones "serving"
k patch deploy web --type=json -p='[{"op":"remove",
  "path":"/spec/template/spec/containers/0/readinessProbe"}]'

# 13-15  Quien balancea
for p in $(k get pods -l app=web -o name); do
  n=${p#pod/}; k exec "$n" -- sh -c "echo '<h1>$n</h1>' > /usr/share/nginx/html/index.html"
done
k run tmp --rm -it --image=nicolaka/netshoot --restart=Never -- \
  sh -c 'for i in $(seq 1 10); do curl -s http://web-ci; done'
# alternan los Pods -> reparte kube-proxy en el nodo, NO el DNS
```

## Validación

```bash
k get deploy,svc,endpointslices
k get svc web-ci -o jsonpath='{.spec.clusterIP}{"\n"}'
k get endpointslices -l kubernetes.io/service-name=web-ci \
  -o jsonpath='{range .items[*]}{range .endpoints[*]}{.addresses[0]}{"\n"}{end}{end}'   # 3 IPs
```

## Resultado esperado

```
NAME     TYPE        CLUSTER-IP      PORT(S)   SELECTOR
web-ci   ClusterIP   10.96.x.y       80/TCP    app=web
```

* IP del Pod recreado ≠ IP anotada.
* `web-ci` con `CLUSTER-IP` estable pese a recrear Pods.
* `EndpointSlice` con exactamente las IPs de los Pods `Ready`; la del Pod no `Ready` desaparece y vuelve.
* Los 10 `curl` alternan de Pod.

## Error frecuente

* Creer que el DNS reparte carga entre Pods. Resuelve **siempre** a la misma `ClusterIP`.
* Pensar que un Service "sin endpoints" implica Pods caídos: puede ser un selector que no cuadra, o Pods no `Ready`.
* No revertir la `readinessProbe` del paso 12 y dejar el Deployment degradado.
* Confundir `kubectl get endpoints` (legacy) con `kubectl get endpointslices` (lo actual).

## CKA Tip

```bash
k get endpointslices -l kubernetes.io/service-name=<svc>
k get svc <svc> -o jsonpath='{.spec.clusterIP}{"\n"}'
k run tmp --rm -it --image=busybox:1.36 --restart=Never -- wget -qO- http://<svc>
k expose deploy <d> --name <svc> --port <p> [--target-port <tp>]
```

**FQDN de un Service:** `<svc>.<ns>.svc.cluster.local`.
