# LAB 9.3 — Conectar el programa GRATITUD

## Nivel

Avanzado.

## Duración

30 minutos.

## Objetivo

Partir de tres namespaces con sus Deployments desplegados pero **sin ningún
Service**, y llegar —solo a partir de requerimientos— a un flujo
`portal → api → datos` que funcione de extremo a extremo, con una única puerta de
entrada desde fuera.

## Competencias

* Elegir el tipo de Service correcto para cada tramo de una aplicación.
* Exponer un contenedor cuyo puerto (`targetPort`) no coincide con el `port` del Service.
* Resolver Services de otros namespaces por su FQDN.
* Modelar un servicio externo con `ExternalName`.
* Verificar un flujo multi-namespace de dentro hacia fuera.

## Escenario

El programa **GRATITUD** está partido en tres namespaces por responsabilidad:

| Namespace | Deployment | Puerto del contenedor | Debe hablar con |
|---|---|---|---|
| `gratitud-frontend` | `portal` (`nginx:1.27-alpine`) | 80 | `api` en `gratitud-api` |
| `gratitud-api` | `api` (`nginxinc/nginx-unprivileged:1.27-alpine`) | **8080** | `cache` en `gratitud-datos`, y la B, externa |
| `gratitud-datos` | `cache` (`nginx:1.27-alpine`) | 80 | — |

La base de datos real vive **fuera del cluster**, en `db.corp.example.com`.

## Estado inicial

```bash
kubectl apply -f ../RECURSOS/YAML/05-gratitud-namespaces.yaml
```

Crea los tres namespaces y los tres Deployments con sus labels
(`part-of=gratitud`, `tier=…`, `app=gratitud-…`). **No crea ningún Service.**

## Requerimientos

| # | Requisito |
|---|---|
| R1 | Cada Pod `api` debe ser alcanzable **desde dentro del cluster** en el puerto **80**, aunque el contenedor escuche en el **8080**. |
| R2 | `cache` debe ser alcanzable desde `gratitud-api` por su nombre, en el puerto 80. |
| R3 | El `portal` debe ser accesible **desde fuera del cluster** a través del `nodePort` **31900**. Ningún otro tramo puede ser accesible desde fuera. |
| R4 | Desde un Pod de `gratitud-frontend`, `api.gratitud-api` debe resolver y responder. |
| R5 | Desde un Pod de `gratitud-api`, `cache.gratitud-datos` debe resolver y responder. |
| R6 | La base de datos externa debe poder invocarse como un Service interno llamado **`db-externa`** en `gratitud-datos`, que resuelva (vía CNAME) a `db.corp.example.com`. No debe tener `ClusterIP` ni endpoints. |
| R7 | Personaliza el `index.html` de `portal`, `api` y `cache` para que cada uno devuelva su nombre, de forma que puedas seguir el flujo en los `curl`. |

Tú decides los manifiestos, los nombres de los Services, el orden y las pruebas.
Puedes apoyarte en `../RECURSOS/YAML/06-gratitud-referencia.yaml` **solo para
comprobar**, no para copiar sin entender.

## Pistas de método (no de solución)

* `kubectl expose deployment <d> -n <ns> --name <svc> --port 80 --target-port <p>` crea un `ClusterIP` en un comando.
* El `nodePort` fijo solo se puede poner editando el manifiesto o con `kubectl patch`, no con `expose`.
* `kubectl explain service.spec.type` te recuerda los cuatro valores posibles.
* Para probar desde un namespace concreto: `kubectl -n <ns> run probe --rm -it --image=nicolaka/netshoot --restart=Never -- bash`.
* Dentro del mismo namespace basta el nombre corto; entre namespaces necesitas al menos `<svc>.<ns>`.

## Validación

```bash
# Inventario: 4 Services, tipos correctos
kubectl get svc -A -l part-of=gratitud
kubectl -n gratitud-api   get svc api        -o jsonpath='{.spec.ports[0].port}->{.spec.ports[0].targetPort}{"\n"}'   # 80->8080
kubectl -n gratitud-frontend get svc portal-np -o jsonpath='{.spec.type}/{.spec.ports[0].nodePort}{"\n"}'             # NodePort/31900
kubectl -n gratitud-datos get svc db-externa  -o jsonpath='{.spec.type}/{.spec.externalName}{"\n"}'                   # ExternalName/db.corp.example.com

# Endpoints
kubectl -n gratitud-api   get endpointslices -l kubernetes.io/service-name=api
kubectl -n gratitud-datos get endpointslices -l kubernetes.io/service-name=cache

# Flujo interno
kubectl -n gratitud-frontend exec deploy/portal -- sh -c 'curl -s http://api.gratitud-api'         2>/dev/null || \
  kubectl -n gratitud-frontend run p1 --rm -i --image=nicolaka/netshoot --restart=Never -- curl -s http://api.gratitud-api
kubectl -n gratitud-api run p2 --rm -i --image=nicolaka/netshoot --restart=Never -- curl -s http://cache.gratitud-datos
kubectl -n gratitud-api run p3 --rm -i --image=nicolaka/netshoot --restart=Never -- nslookup db-externa.gratitud-datos

# Flujo externo
curl -s -o /dev/null -w '%{http_code}\n' http://<IP-NODO>:31900/
```

## Resultado esperado

* Cuatro Services: `portal-np` (NodePort `31900`), `api` (ClusterIP `80 → 8080`), `cache` (ClusterIP `80`), `db-externa` (ExternalName).
* `api` y `cache` tienen `EndpointSlice` con las direcciones de sus Pods.
* `db-externa` **no** tiene `ClusterIP` ni `EndpointSlice`; `nslookup` devuelve un CNAME a `db.corp.example.com`.
* Desde `gratitud-frontend`, `curl http://api.gratitud-api` devuelve la página del Pod `api`.
* Desde `gratitud-api`, `curl http://cache.gratitud-datos` devuelve la página del Pod `cache`.
* `curl http://<IP-NODO>:31900/` devuelve `200` y la página del Pod `portal`.

## Criterios de éxito

- [ ] `api` es alcanzable en el puerto 80 aunque el contenedor escuche en el 8080.
- [ ] `cache` es alcanzable por nombre desde `gratitud-api`.
- [ ] Solo `portal` es accesible desde fuera, por el `nodePort` 31900.
- [ ] `api.gratitud-api` resuelve y responde desde `gratitud-frontend`.
- [ ] `cache.gratitud-datos` resuelve y responde desde `gratitud-api`.
- [ ] `db-externa` es un `ExternalName` sin `ClusterIP` ni endpoints.
- [ ] Sé, para cada Service, por qué elegí ese `type`.
