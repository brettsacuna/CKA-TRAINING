# SOLUCIÓN — LAB 9.4 · Challenge «GRATITUD no conecta»

> **MATERIAL DEL INSTRUCTOR.**

## Los 4 fallos

| # | Objeto | Fallo | Capa | Síntoma | Comando que lo revela |
|---|---|---|---|---|---|
| 1 | `svc/api` (`gratitud-api`) | `selector: app=gratitud-api-v2` (los Pods son `app=gratitud-api`) | Selector / labels | `EndpointSlice` vacío | `k -n gratitud-api get endpointslices` |
| 2 | `svc/api` (`gratitud-api`) | `targetPort: 80` (el contenedor escucha en `8080`) | Puerto | Hay endpoints pero `connection refused` | `k -n gratitud-api get svc api -o yaml` |
| 3 | `svc/portal-np` (`gratitud-frontend`) | `type: ClusterIP` sin `nodePort` (debe ser `NodePort 31900`) | Tipo de Service | Interno OK, `curl` externo no conecta | `k -n gratitud-frontend get svc portal-np -o yaml` |
| 4 | `svc/cache` | Creado en `gratitud-api`, no en `gratitud-datos` | Namespace / FQDN | `cache.gratitud-datos` → NXDOMAIN; `cache.gratitud-api` sin endpoints | `k get svc -A -l part-of=gratitud` + `nslookup` |

## Método

El síntoma "no responde" es idéntico en las cuatro capas. Hay que recorrer la
ruta de dentro hacia fuera y no saltarse pasos:

```
Pod Ready? -> EndpointSlice tiene direcciones? -> responde por ClusterIP:port?
   -> resuelve el nombre desde el otro namespace? -> entra desde fuera por el nodePort?
```

## Procedimiento

```bash
cd CLASE-09/RECURSOS/SCRIPTS && ./setup-lab.sh
k -n gratitud-api rollout status deploy/probe
k get pods -A -l part-of=gratitud --show-labels

# ---- Fallo 1: selector de svc/api ----
k -n gratitud-api get endpointslices -l kubernetes.io/service-name=api   # <none>
k -n gratitud-api get svc api -o jsonpath='{.spec.selector}{"\n"}'       # {"app":"gratitud-api-v2"}
k -n gratitud-api get pod -l app=gratitud-api --show-labels              # los Pods son app=gratitud-api
k -n gratitud-api patch svc api --type=merge -p '{"spec":{"selector":{"app":"gratitud-api"}}}'
k -n gratitud-api get endpointslices -l kubernetes.io/service-name=api   # ahora 2 direcciones

# ---- Fallo 2: targetPort de svc/api ----
k -n gratitud-api exec deploy/probe -- curl -s --max-time 3 http://api || echo "connection refused"
k -n gratitud-api get svc api -o jsonpath='{.spec.ports[0]}{"\n"}'       # targetPort 80
k -n gratitud-api exec deploy/api -c api -- sh -c 'netstat -ltn 2>/dev/null | grep 8080 || echo listen 8080'
k -n gratitud-api patch svc api --type=json -p='[{"op":"replace","path":"/spec/ports/0/targetPort","value":8080}]'
k -n gratitud-api exec deploy/probe -- curl -s --max-time 3 -o /dev/null -w '%{http_code}\n' http://api   # 200

# ---- Fallo 3: portal-np debe ser NodePort 31900 ----
k -n gratitud-frontend get svc portal-np -o jsonpath='{.spec.type}{"\n"}'   # ClusterIP
k -n gratitud-frontend patch svc portal-np --type=merge -p \
  '{"spec":{"type":"NodePort","ports":[{"port":80,"targetPort":80,"nodePort":31900}]}}'
k -n gratitud-frontend get svc portal-np                                     # 80:31900/TCP
curl -s -o /dev/null -w '%{http_code}\n' http://<IP-NODO>:31900/             # 200

# ---- Fallo 4: cache esta en el namespace equivocado ----
k get svc -A -l part-of=gratitud                                             # 'cache' aparece en gratitud-api
k -n gratitud-api exec deploy/probe -- nslookup cache.gratitud-datos || echo NXDOMAIN
k -n gratitud-datos get deploy cache                                        # el Deployment SI esta aqui
# recrear el Service en el namespace correcto
k -n gratitud-api delete svc cache
k -n gratitud-datos expose deploy cache --name cache --port 80 --target-port 80
k -n gratitud-api exec deploy/probe -- curl -s --max-time 3 -o /dev/null -w '%{http_code}\n' http://cache.gratitud-datos  # 200
```

> **Sobre la restricción "no borres los Services".** El fallo 4 exige recrear
> `cache` en `gratitud-datos`; borrar la copia mal ubicada de `gratitud-api` es
> parte de la corrección, no una vía de escape. Lo prohibido es borrar Services
> para "resolver" saltándose el diagnóstico, o convertir `api`/`cache` en
> `NodePort`.

## Validación

```bash
cd CLASE-09/RECURSOS/SCRIPTS && ./validate-lab.sh
# LAB 9.4 SUPERADO (12 comprobaciones)

# manual
curl -s -o /dev/null -w '%{http_code}\n' http://<IP-NODO>:31900/
```

## Resultado esperado

* `svc/api`: `selector app=gratitud-api`, `targetPort 8080`, `EndpointSlice` con 2 direcciones, responde `200` por su `ClusterIP`.
* `svc/portal-np`: `NodePort`, `nodePort 31900`, `200` desde fuera.
* `svc/cache`: existe en `gratitud-datos`, con endpoints; `cache.gratitud-datos` responde desde `gratitud-api`.
* Ningún Deployment borrado. `api` y `cache` siguen siendo `ClusterIP`.

## Error frecuente

* "Arreglar" el fallo 1 recreando el Service con `expose` y heredar el `targetPort 80` por defecto → seguir con el fallo 2 sin verlo.
* Cambiar `portal-np` a `NodePort` sin fijar el `nodePort`: funciona, pero el `./validate-lab.sh` espera exactamente `31900`.
* Perseguir el fallo 4 como si fuera de DNS ("CoreDNS está roto") cuando es un Service en el namespace equivocado. `nslookup cache.gratitud-datos` → NXDOMAIN es "no existe ese Service ahí", no "el DNS no va".
* Tocar CoreDNS o los Pods. Los cuatro fallos están en los cuatro Services.

## CKA Tip

```bash
k get svc -A -l <label>                                   # inventario rapido, ver namespaces
k get endpointslices -l kubernetes.io/service-name=<svc>  # vacio -> selector/labels
k get svc <svc> -o jsonpath='{.spec.ports[0]}{"\n"}'      # port vs targetPort
k -n <ns> exec deploy/<d> -- curl -s --max-time 3 http://<svc>.<ns-destino>
```

Ruta mental para cualquier "no llego" a un Service:
**selector → endpoints → targetPort → FQDN/namespace → tipo de Service.**
