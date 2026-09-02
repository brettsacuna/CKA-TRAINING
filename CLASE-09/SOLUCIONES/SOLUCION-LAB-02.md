# SOLUCIÓN — LAB 9.2 · Publicar y descubrir por labels

> **MATERIAL DEL INSTRUCTOR.**

## Diagnóstico

1. **Los tres tipos de Service se apilan.** `NodePort` es un `ClusterIP` + puerto en cada nodo; `LoadBalancer` es un `NodePort` + IP externa del proveedor. El `EndpointSlice` es el mismo porque el selector es el mismo.
2. **El selector construye el `EndpointSlice`; la anotación no toca nada.** Cambiar una label puede dejar un Service sin endpoints; cambiar una anotación nunca hace eso.
3. **`LoadBalancer` sin nube = `EXTERNAL-IP <pending>` para siempre**, pero el `ClusterIP` y el `NodePort` subyacentes funcionan.

## Procedimiento

```bash
k create ns c9-publicar && k config set-context --current --namespace=c9-publicar

# A - Los tres tipos
k apply -f ../RECURSOS/YAML/03-nodeport-loadbalancer.yaml
k get svc -o wide
# tienda-ci  ClusterIP     10.96.a.b   80/TCP
# tienda-np  NodePort      10.96.c.d   80:31700/TCP
# tienda-lb  LoadBalancer  10.96.e.f   80:31xxx/TCP   EXTERNAL-IP <pending>

for s in tienda-ci tienda-np tienda-lb; do
  echo "== $s =="; k get endpointslices -l kubernetes.io/service-name=$s \
    -o jsonpath='{range .items[*]}{range .endpoints[*]}{.addresses[0]}{"\n"}{end}{end}'
done                                   # las MISMAS 2 IPs en los tres

curl -s -o /dev/null -w '%{http_code}\n' http://<IP-NODO>:31700/   # 200

# B - El selector es lo que engancha
POD=$(k get pod -l app=tienda -o name | head -1)
k label $POD app=tienda-roto --overwrite
k get endpointslices -l kubernetes.io/service-name=tienda-ci \
  -o jsonpath='{range .items[*]}{range .endpoints[*]}{.addresses[0]}{"\n"}{end}{end}'   # 1 IP
k get pod --show-labels                 # el Pod sigue Running, con app=tienda-roto
# reparar: devolver la label
k label $POD app=tienda --overwrite

# selector que no cuadra con nadie
k patch svc tienda-ci --type=merge -p '{"spec":{"selector":{"app":"tienda","tier":"web"}}}'
k get endpointslices -l kubernetes.io/service-name=tienda-ci      # EndpointSlice vacio, sin error
k patch svc tienda-ci --type=merge -p '{"spec":{"selector":{"app":"tienda"}}}'

# C - Anotaciones
k annotate svc tienda-ci gratitud.io/owner=equipo-tienda prometheus.io/scrape=true prometheus.io/port=80
k get endpointslices -l kubernetes.io/service-name=tienda-ci     # NO cambia nada
k apply -f ../RECURSOS/YAML/04-labels-anotaciones.yaml
k get svc tienda-web -o jsonpath='{.metadata.annotations}{"\n"}' | tr ',' '\n'
# las claves service.beta.kubernetes.io/aws-... solo las entiende el CCM de AWS: NO son portables

# D - Acotar el selector a v1
k rollout status deploy/tienda-v2
k get endpointslices -l kubernetes.io/service-name=tienda-ci \
  -o jsonpath='{range .items[*]}{range .endpoints[*]}{.addresses[0]}{"\n"}{end}{end}' | wc -l   # 4 (v1 + v2)
k patch svc tienda-ci --type=merge -p '{"spec":{"selector":{"app":"tienda","version":"v1"}}}'
k get endpointslices -l kubernetes.io/service-name=tienda-ci \
  -o jsonpath='{range .items[*]}{range .endpoints[*]}{.addresses[0]}{"\n"}{end}{end}' | wc -l   # 2 (solo v1)
k get pod -l version=v2                 # los Pods v2 siguen Running
```

## Respuestas a las preguntas del enunciado

* **Paso 6.** `tienda-lb` queda `<pending>` porque no hay un `cloud-controller-manager` ni MetalLB que aprovisione una IP externa. Lo que **sí** funciona es su `ClusterIP` y el `nodePort` que Kubernetes le asignó automáticamente.
* **Paso 8.** El Pod sale del `EndpointSlice` porque el controlador de endpoints ya no lo ve como coincidencia del selector `app: tienda`. El Pod está sano; simplemente el Service ya no lo "conoce".
* **Paso 13.** Las anotaciones `service.beta.kubernetes.io/aws-load-balancer-*` solo las interpreta el controlador de nube de AWS. En GCP, Azure u on-prem se ignoran. No son portables: es el mismo problema que tuvo Ingress con sus anotaciones propietarias.

## Validación

```bash
k get svc -o wide
k get endpointslices
k get svc tienda-ci -o jsonpath='{.spec.selector}{"\n"}'          # {"app":"tienda","version":"v1"}
k get pod -l app=tienda --show-labels
```

## Resultado esperado

* `tienda-ci`, `tienda-np` (`80:31700/TCP`), `tienda-lb` (`<pending>`), los tres con los mismos endpoints mientras el selector sea `app: tienda`.
* Cambiar/devolver la label de un Pod lo saca/reincorpora al Service sin errores.
* Selector que no cuadra → `EndpointSlice` vacío, sin error.
* Anotaciones sin efecto sobre los endpoints.
* Con `version: v1` en el selector, los Pods `v2` quedan fuera del Service pero siguen `Running`.

## Error frecuente

* Poner `nodePort` fuera del rango 30000–32767 (`Invalid value ... provided port is not in the valid range`).
* Esperar a que `tienda-lb` obtenga `EXTERNAL-IP` en un cluster sin nube. No va a pasar.
* Creer que una anotación puede cambiar a qué Pods apunta el Service.
* Olvidar que el selector del **Service** y el `matchLabels` del **Deployment** son cosas distintas: acotar el del Service no cambia qué Pods gestiona el Deployment.

## CKA Tip

```bash
k expose deploy <d> --type=NodePort --port 80 --target-port 8080 --name <svc>
k patch svc <svc> --type=merge -p '{"spec":{"selector":{"app":"x","version":"v1"}}}'
k get endpointslices -l kubernetes.io/service-name=<svc> -o wide
k annotate svc <svc> key=value            # k annotate svc <svc> key-   para quitarla
```
