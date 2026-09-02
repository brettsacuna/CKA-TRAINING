# LAB 5.1 — Services, EndpointSlice y CoreDNS

## Nivel

Básico.

## Duración

23 minutos.

## Objetivo

Publicar la misma aplicación con distintos tipos de Service y entender exactamente cómo un Pod encuentra a otro por nombre.

## Competencias

* Crear `ClusterIP`, `NodePort` y `ExternalName`.
* Leer `EndpointSlice`.
* Interpretar `/etc/resolv.conf` de un Pod y el efecto de `ndots`.
* Consultar CoreDNS y sus logs.

## Escenario

Antes de meter un Ingress por delante, hay que dominar lo que hay debajo: el Service y el DNS. La mayoría de los incidentes de "red" en Kubernetes son en realidad uno de estos dos.

## Estado inicial

* Namespace de trabajo: **`c5-basico`**.
* CoreDNS funcionando en `kube-system`.

## Requerimientos

### Parte A — Los tres Services

1. Crea el namespace `c5-basico`.
2. Crea un Deployment **`web`** con 3 réplicas de `nginx:1.27-alpine`, label `app=web`, puerto 80.
3. Personaliza el `index.html` de cada réplica para que muestre su propio nombre de Pod (usa `kubectl exec`).
4. Expón `web` con un Service **`web-ci`** de tipo `ClusterIP` en el puerto 80.
5. Expón `web` con un Service **`web-np`** de tipo `NodePort` en el puerto 80 y `nodePort` **31500**.
6. Crea un Service **`externo`** de tipo `ExternalName` que apunte a `example.com`. Averigua qué hace exactamente ese tipo.

### Parte B — EndpointSlice

7. Muestra los `EndpointSlice` del namespace. Comprueba que `web-ci` y `web-np` apuntan a **las mismas 3 IPs**.
8. Escala `web` a 5 réplicas y vuelve a mirar. Escálalo de nuevo a 3.
9. Provoca que una réplica deje de estar `Ready` (por ejemplo, añadiendo una `readinessProbe` que apunte a un puerto cerrado) y comprueba qué le pasa a su dirección en el EndpointSlice. Deshaz el cambio.

### Parte C — DNS

10. Lanza un Pod temporal y examina su `/etc/resolv.conf`. Anota:
    * el `nameserver`,
    * la lista de `search`,
    * el valor de `ndots`.
11. Desde ese Pod, resuelve y explica la diferencia entre:
    * `web-ci`
    * `web-ci.c5-basico`
    * `web-ci.c5-basico.svc.cluster.local`
    * `externo`
12. Haz `curl` diez veces a `web-ci` y comprueba si responde siempre el mismo Pod. Explica quién está balanceando.
13. Averigua qué IP tiene el Service de CoreDNS y en qué namespace vive.
14. Activa temporalmente el log de consultas de CoreDNS editando su ConfigMap (añadiendo el plugin `log`), genera una consulta y mira los logs. **Deja el ConfigMap como estaba al terminar.**

## Restricciones

* No instales ningún Ingress Controller en este laboratorio.
* Revierte el cambio del ConfigMap de CoreDNS antes de acabar.
* No borres el Deployment `web`: se reutiliza en el LAB 5.2.

## Validación

```bash
kubectl -n c5-basico get deploy,svc,endpointslices
kubectl -n c5-basico get svc externo -o yaml | grep -A2 externalName
kubectl -n kube-system get svc kube-dns
kubectl -n kube-system get cm coredns -o yaml
kubectl run tmp --rm -it -n c5-basico --image=nicolaka/netshoot --restart=Never -- bash
```

## Resultado esperado

* `web-ci` con ClusterIP; `web-np` con `80:31500/TCP`; ambos con 3 endpoints idénticos.
* `externo` **no tiene ClusterIP ni endpoints**: CoreDNS devuelve un CNAME a `example.com`.
* Al dejar una réplica no `Ready`, su IP **desaparece** del EndpointSlice; al recuperarse, vuelve.
* `/etc/resolv.conf` con `search c5-basico.svc.cluster.local svc.cluster.local cluster.local` y `options ndots:5`.
* Los `curl` alternan entre Pods: balancea **kube-proxy**, no el DNS.
* CoreDNS vive en `kube-system` como Service `kube-dns`.

## Criterios de éxito

- [ ] Los tres Services creados y funcionando.
- [ ] Sé qué hace `ExternalName` y en qué se diferencia de los demás.
- [ ] Comprobé que dos Services distintos comparten endpoints.
- [ ] Vi desaparecer y volver una dirección al cambiar la readiness.
- [ ] Leí `/etc/resolv.conf` e identifiqué `search` y `ndots`.
- [ ] Expliqué por qué `web-ci` a secas resuelve dentro del namespace.
- [ ] Identifiqué quién balancea las peticiones.
- [ ] Localicé el Service de CoreDNS.
- [ ] Activé y revertí el log de CoreDNS.
