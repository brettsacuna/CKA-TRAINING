# LAB 9.2 — Publicar y descubrir por labels

## Nivel

Intermedio.

## Duración

30 minutos.

## Objetivo

Exponer la misma aplicación con los tres tipos de Service que entran en el examen,
y usar labels, selectores y anotaciones para controlar **qué** atiende cada Service
y **cómo** se comporta la infraestructura alrededor.

## Competencias

* Crear `ClusterIP`, `NodePort` y `LoadBalancer` sobre un mismo Deployment.
* Comparar sus `EndpointSlice` y entender que seleccionan los mismos Pods.
* Diagnosticar y reparar un Service sin endpoints por un problema de labels.
* Añadir anotaciones a un Service y comprobar que no afectan al descubrimiento.
* Acotar un selector para que atienda solo una versión de la aplicación.

## Escenario

La tienda **`tienda`** ya corre en el cluster. Necesitas publicarla de tres formas
para tres consumidores distintos: otros servicios internos, un balanceador propio
en la red del nodo, y (en teoría) una IP pública. Y necesitas poder desplegar una
versión nueva sin que el Service la sirva hasta que tú lo decidas.

## Estado inicial

* Namespace de trabajo: **`c9-publicar`**.
* Necesitas la IP de un nodo accesible desde tu equipo para probar el `NodePort`.

## Requerimientos

### Parte A — Los tres tipos

1. Crea el namespace `c9-publicar`.
2. Aplica el Deployment y los tres Services de referencia:
   ```bash
   kubectl apply -f ../RECURSOS/YAML/03-nodeport-loadbalancer.yaml
   ```
   Contiene: Deployment `tienda` (2 réplicas de `nginx:1.27-alpine`, `app=tienda`, `version=v1`),
   y los Services `tienda-ci` (ClusterIP), `tienda-np` (NodePort `31700`) y `tienda-lb` (LoadBalancer).
3. Lista los Services. Anota:
   * la `CLUSTER-IP` de cada uno,
   * el `PORT(S)` de `tienda-np` (verás `80:31700/TCP`),
   * el `EXTERNAL-IP` de `tienda-lb` (quedará en `<pending>`).
4. Compara los `EndpointSlice` de los tres Services:
   ```bash
   for s in tienda-ci tienda-np tienda-lb; do
     echo "== $s =="
     kubectl get endpointslices -l kubernetes.io/service-name=$s \
       -o jsonpath='{range .items[*]}{range .endpoints[*]}{.addresses[0]}{"\n"}{end}{end}'
   done
   ```
   Deben apuntar a **las mismas 2 IPs**.
5. Prueba el `NodePort` desde fuera del cluster:
   ```bash
   curl -s -o /dev/null -w '%{http_code}\n' http://<IP-NODO>:31700/
   ```
6. Explica en una frase por qué `tienda-lb` se queda en `<pending>` y qué parte de él **sí** funciona.

### Parte B — El selector es lo que engancha

7. Rompe el descubrimiento cambiando la label de un Pod:
   ```bash
   POD=$(kubectl get pod -l app=tienda -o name | head -1)
   kubectl label $POD app=tienda-roto --overwrite
   ```
8. Mira el `EndpointSlice` de `tienda-ci` y el Pod: sigue `Running` pero **ya no está** en el Service. Explica por qué.
9. Repara **sin tocar el Pod**: haz que el Service vuelva a incluirlo. (Pista: no es la única forma, pero la más limpia es devolver la label).
10. Provoca ahora el caso contrario: edita `tienda-ci` y ponle un selector que **no cuadra con nadie** (`app: tienda, tier: web`). Comprueba que el `EndpointSlice` queda **vacío** y que el Service se crea/edita **sin ningún error**. Devuelve el selector a `app: tienda`.

### Parte C — Anotaciones

11. Añade a `tienda-ci` estas anotaciones:
    ```bash
    kubectl annotate svc tienda-ci \
      gratitud.io/owner=equipo-tienda \
      prometheus.io/scrape=true \
      prometheus.io/port=80
    ```
12. Vuelve a mirar el `EndpointSlice`. Comprueba que **no ha cambiado nada**: las anotaciones no seleccionan Pods.
13. Aplica `04-labels-anotaciones.yaml` y revisa el Service `tienda-web`: lleva anotaciones típicas de `LoadBalancer` (p. ej. `service.beta.kubernetes.io/...`). Responde: ¿son portables esas anotaciones a otra nube? ¿Por qué?

### Parte D — Acotar el selector a una versión

14. El fichero `04-labels-anotaciones.yaml` también añade un Deployment `tienda-v2` con labels `app=tienda, version=v2`.
15. Comprueba que `tienda-ci` (selector `app: tienda`) ahora **también** enruta hacia los Pods `v2`. Verifícalo en el `EndpointSlice` (cuenta las direcciones).
16. Modifica el selector de `tienda-ci` para que atienda **solo `v1`**: `app: tienda, version: v1`.
17. Comprueba que los Pods `v2` han salido del `EndpointSlice` y que `tienda-ci` vuelve a tener solo 2 direcciones. Los Pods `v2` **siguen corriendo**; simplemente el Service ya no los sirve.

## Restricciones

* Los tres Services deben seguir existiendo al final del laboratorio.
* No borres ningún Deployment para "arreglar" un `EndpointSlice`: corrige labels o selector.
* No conviertas `tienda-ci` en `NodePort` para probar nada.

## Validación

```bash
kubectl -n c9-publicar get svc -o wide
kubectl -n c9-publicar get endpointslices
kubectl -n c9-publicar get svc tienda-ci -o jsonpath='{.spec.selector}{"\n"}'
kubectl -n c9-publicar get svc tienda-ci -o jsonpath='{.metadata.annotations}{"\n"}'
kubectl -n c9-publicar get pods -l app=tienda --show-labels
curl -s -o /dev/null -w '%{http_code}\n' http://<IP-NODO>:31700/
```

## Resultado esperado

* `tienda-ci` (ClusterIP), `tienda-np` (`80:31700/TCP`) y `tienda-lb` (`EXTERNAL-IP <pending>`), los tres con **los mismos endpoints** mientras el selector sea `app: tienda`.
* El `NodePort` responde `200` desde fuera; el `ClusterIP` y el `NodePort` de `tienda-lb` también funcionan aunque no haya IP externa.
* Cambiar la label de un Pod lo **saca** del Service sin errores; devolverla lo reincorpora.
* Un selector que no cuadra deja el `EndpointSlice` **vacío** y no genera ningún error.
* Las anotaciones **no** alteran el `EndpointSlice`.
* Con el selector `app: tienda, version: v1`, los Pods `v2` quedan fuera del Service aunque sigan `Running`.

## Criterios de éxito

- [ ] Publiqué el mismo Deployment con `ClusterIP`, `NodePort` y `LoadBalancer`.
- [ ] Comprobé que los tres comparten `EndpointSlice`.
- [ ] Expliqué por qué el `LoadBalancer` queda `pending` y qué sigue funcionando.
- [ ] Saqué un Pod del Service cambiando su label y lo reincorporé.
- [ ] Vi un `EndpointSlice` vacío por un selector que no cuadra, sin ningún error.
- [ ] Añadí anotaciones y confirmé que no cambian los endpoints.
- [ ] Expliqué por qué las anotaciones de `LoadBalancer` no son portables.
- [ ] Acoté el selector a `version: v1` y dejé fuera los Pods `v2`.
