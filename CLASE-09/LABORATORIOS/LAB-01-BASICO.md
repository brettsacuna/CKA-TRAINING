# LAB 9.1 — La IP que desaparece y el ClusterIP

## Nivel

Básico.

## Duración

22 minutos.

## Objetivo

Ver con tus propios ojos que la IP de un Pod no es estable, y comprobar que un
Service `ClusterIP` y su `EndpointSlice` absorben ese cambio sin que el cliente se
entere.

## Competencias

* Observar la IP de un Pod y verla cambiar tras un reschedule.
* Crear un Service `ClusterIP` y resolverlo por nombre.
* Leer un `EndpointSlice` y relacionarlo con los Pods `Ready`.
* Identificar quién balancea las peticiones a un Service.

## Escenario

Un compañero te pasa una integración que "lleva semanas funcionando" y que apunta
directamente a `10.244.1.7`. Antes de discutir, lo vas a demostrar en el cluster.

## Estado inicial

* Namespace de trabajo: **`c9-basico`**.
* CoreDNS funcionando en `kube-system`.

## Requerimientos

### Parte A — La IP efímera

1. Crea el namespace `c9-basico` y fíjalo como namespace por defecto del contexto.
2. Aplica el Deployment `web` (3 réplicas de `nginx:1.27-alpine`, label `app=web`, puerto 80):
   ```bash
   kubectl apply -f ../RECURSOS/YAML/01-pod-ip-efimera.yaml
   ```
3. Lista los Pods con `-o wide` y **anota la IP y el nodo** de uno de ellos.
4. Borra ese Pod. Espera a que el Deployment cree el sustituto.
5. Vuelve a listar con `-o wide`. Comprueba que el Pod nuevo tiene **otra IP** (y puede que otro nodo). Anótalo.

### Parte B — El ClusterIP no cambia

6. Expón `web` con un Service **`web-ci`** de tipo `ClusterIP` en el puerto 80:
   ```bash
   kubectl apply -f ../RECURSOS/YAML/02-service-clusterip.yaml
   ```
   o hazlo con `kubectl expose deployment web --name web-ci --port 80`.
7. Anota la `CLUSTER-IP` de `web-ci`.
8. Lanza un Pod temporal y, desde él, resuelve y consulta el Service por nombre:
   ```bash
   kubectl run tmp --rm -it --image=nicolaka/netshoot --restart=Never -- bash
     nslookup web-ci
     curl -s http://web-ci | head -1
     exit
   ```
9. Borra otro Pod de `web`. Repite la consulta del paso 8. La `CLUSTER-IP` **no ha cambiado** y sigue respondiendo.

### Parte C — El EndpointSlice

10. Muestra el `EndpointSlice` de `web-ci`:
    ```bash
    kubectl get endpointslices -l kubernetes.io/service-name=web-ci
    kubectl get endpointslices -l kubernetes.io/service-name=web-ci -o yaml | grep -A3 addresses
    ```
    Comprueba que lista **exactamente** las IPs de los 3 Pods `Ready`.
11. Escala `web` a 5 réplicas. Vuelve a mirar el `EndpointSlice`. Escálalo de nuevo a 3.
12. Provoca que una réplica deje de estar `Ready` añadiendo una `readinessProbe` a un puerto cerrado:
    ```bash
    kubectl patch deploy web --type=json -p='[{"op":"add",
      "path":"/spec/template/spec/containers/0/readinessProbe",
      "value":{"httpGet":{"path":"/","port":9999},"periodSeconds":3}}]'
    ```
    Observa los Pods (`0/1 READY`) y el `EndpointSlice` (sin esas direcciones). **Deshaz el cambio**:
    ```bash
    kubectl patch deploy web --type=json -p='[{"op":"remove",
      "path":"/spec/template/spec/containers/0/readinessProbe"}]'
    ```

### Parte D — Quién balancea

13. Personaliza el `index.html` de cada Pod para que muestre su nombre:
    ```bash
    for p in $(kubectl get pods -l app=web -o name); do
      n=${p#pod/}
      kubectl exec "$n" -- sh -c "echo '<h1>$n</h1>' > /usr/share/nginx/html/index.html"
    done
    ```
14. Desde un Pod temporal, haz `curl` diez veces a `web-ci` y observa qué Pod responde:
    ```bash
    kubectl run tmp --rm -it --image=nicolaka/netshoot --restart=Never -- \
      sh -c 'for i in $(seq 1 10); do curl -s http://web-ci; done'
    ```
15. Explica en una frase **quién** está repartiendo las peticiones (no es el DNS).

## Restricciones

* No uses `type: NodePort` ni `LoadBalancer` en este laboratorio.
* Revierte la `readinessProbe` del paso 12 antes de terminar.
* No borres el Deployment `web` hasta acabar la Parte D.

## Validación

```bash
kubectl -n c9-basico get deploy,svc,endpointslices
kubectl -n c9-basico get svc web-ci -o jsonpath='{.spec.clusterIP}{"\n"}'
kubectl -n c9-basico get endpointslices -l kubernetes.io/service-name=web-ci \
  -o jsonpath='{range .items[*]}{range .endpoints[*]}{.addresses[0]}{"\n"}{end}{end}'
```

## Resultado esperado

* El Pod recreado en la Parte A tiene **una IP distinta** de la que anotaste.
* `web-ci` tiene una `CLUSTER-IP` que **no cambia** aunque se recreen Pods detrás.
* El `EndpointSlice` de `web-ci` contiene las IPs de los Pods `Ready`, y solo esas.
* Al dejar una réplica no `Ready`, su dirección **desaparece** del `EndpointSlice`; al recuperarse, vuelve.
* Los `curl` alternan entre Pods: reparte **`kube-proxy`** en el nodo, no el DNS.

## Criterios de éxito

- [ ] Vi cambiar la IP de un Pod tras borrarlo y recrearse.
- [ ] Creé un Service `ClusterIP` y lo resolví por nombre desde otro Pod.
- [ ] Comprobé que la `CLUSTER-IP` no cambia aunque cambien los Pods.
- [ ] Relacioné el contenido del `EndpointSlice` con los Pods `Ready`.
- [ ] Vi entrar y salir direcciones del `EndpointSlice` al escalar y al romper la readiness.
- [ ] Reverti la `readinessProbe`.
- [ ] Identifiqué que quien balancea es `kube-proxy`, no el DNS.
