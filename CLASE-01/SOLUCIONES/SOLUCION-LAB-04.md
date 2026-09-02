# SOLUCIÓN — LAB 1.4 · Challenge `shop`

> **MATERIAL DEL INSTRUCTOR.** No entregar hasta que el grupo haya intentado el diagnóstico.

## Diagnóstico

El escenario contiene **4 fallos** encadenados. Están diseñados para que el alumno no pueda "arreglar uno y probar": hasta que no corrige los cuatro, el `curl` no responde.

| # | Síntoma | Comando que lo revela | Causa raíz |
|---|---|---|---|
| 1 | El único Pod queda `Pending` | `k -n c1-challenge describe pod <p>` → `FailedScheduling ... didn't match node selector` | El Deployment tiene `nodeSelector: environment=gpu` y **ningún nodo** tiene ese label |
| 2 | El Deployment declara `1/1`, no `3/3` | `k -n c1-challenge get deploy shop-web` | `spec.replicas: 1` en lugar de 3 |
| 3 | El Service no tiene endpoints | `k -n c1-challenge get endpointslices` → vacío | `spec.selector.app: shop`, pero los Pods llevan `app: shop-web` |
| 4 | Con endpoints, el `curl` sigue sin responder | `k -n c1-challenge get svc shop-svc -o yaml` | `targetPort: 8080`, pero el contenedor nginx escucha en **80** |

## Razonamiento técnico resumido

Dos mental models, aplicados en orden:

```
POD:      get -> describe -> events -> logs -> logs --previous
SERVICE:  Service -> selector -> EndpointSlice -> Pod labels -> targetPort
```

El fallo 1 es de **scheduling** (el Pod ni siquiera existe en un nodo). Los fallos 3 y 4 son de **publicación**. El fallo 2 es de **capacidad declarada**. Un alumno que empieza por el `curl` se pierde; uno que empieza por `get pods` avanza en línea recta.

## Procedimiento

```bash
NS=c1-challenge

# --- Reconocimiento
k -n $NS get deploy,rs,pods -o wide
k -n $NS get svc,endpointslices
k -n $NS get events --sort-by=.lastTimestamp | tail -20

# --- Fallo 1: nodeSelector inexistente
k -n $NS describe pod -l app=shop-web | sed -n '/Events/,$p'
k get nodes --show-labels | grep -c environment=gpu     # -> 0
# Opción correcta (no existe hardware GPU): eliminar el nodeSelector
k -n $NS patch deploy shop-web --type=json \
  -p='[{"op":"remove","path":"/spec/template/spec/nodeSelector"}]'

# --- Fallo 2: replicas
k -n $NS scale deploy shop-web --replicas=3

# --- Fallo 3: selector del Service
k -n $NS get svc shop-svc -o jsonpath='{.spec.selector}{"\n"}'   # {"app":"shop"}
k -n $NS get pods --show-labels                                   # app=shop-web
k -n $NS patch svc shop-svc -p '{"spec":{"selector":{"app":"shop-web"}}}'

# --- Fallo 4: targetPort
k -n $NS patch svc shop-svc --type=json \
  -p='[{"op":"replace","path":"/spec/ports/0/targetPort","value":80}]'
```

Alternativa admitida: `k -n c1-challenge edit deploy shop-web` y `k -n c1-challenge edit svc shop-svc`. Lo que **no** se admite es `delete` + `apply`.

## Validación

```bash
k -n c1-challenge get deploy shop-web        # 3/3
k -n c1-challenge get endpointslices         # 3 direcciones
curl -s -o /dev/null -w '%{http_code}\n' http://<IP-WORKER>:31200   # 200

cd CLASE-01/RECURSOS/SCRIPTS && ./validate-lab.sh
```

## Resultado esperado

```
NAME       READY   UP-TO-DATE   AVAILABLE
shop-web   3/3     3            3

NAME              ADDRESSTYPE   PORTS   ENDPOINTS
shop-svc-x7f2k    IPv4          80      10.244.1.11,10.244.2.7,10.244.2.8

LAB 1.4 SUPERADO
```

## Error frecuente

* **Añadir el label `environment=gpu` a un nodo** para "hacer que funcione". Técnicamente arregla el síntoma, pero mentir sobre las capacidades de un nodo es exactamente lo que causa incidentes reales. Discútelo con el grupo: la corrección correcta es retirar el `nodeSelector`, porque el requisito de GPU no existe.
* Cambiar el label de los Pods (`app=shop`) en lugar del selector del Service. Como los Pods los gobierna un Deployment, el ReplicaSet los recrea con el label original y el arreglo "se deshace solo". Buen momento para explicar la relación `Deployment -> ReplicaSet -> Pod`.
* Parar en el fallo 3 al ver que ya hay endpoints y no probar el `curl`.
* Borrar el Service y reaplicarlo: viola la restricción y es exactamente lo que no se puede hacer en producción.

## CKA Tip

```bash
# Comparar lo declarado con lo real, de un vistazo
k -n <ns> get deploy,rs,pods -o wide

# Los eventos ordenados son el 80% del diagnóstico
k -n <ns> get events --sort-by=.lastTimestamp | tail -20

# patch quirúrgico en vez de edit (más rápido y reproducible)
k -n <ns> patch svc <svc> -p '{"spec":{"selector":{"app":"valor"}}}'
k -n <ns> patch deploy <d> --type=json -p='[{"op":"remove","path":"/spec/template/spec/nodeSelector"}]'
```

**Regla de oro:** si `nslookup` funciona pero `curl` no, el problema está entre el Service y el Pod (selector, endpoints, targetPort), no en el DNS.
