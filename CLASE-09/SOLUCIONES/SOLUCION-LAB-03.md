# SOLUCIÓN — LAB 9.3 · Conectar el programa GRATITUD

> **MATERIAL DEL INSTRUCTOR.**

## Diagnóstico

Tres decisiones de diseño y por qué:

1. **Solo el `portal` se publica hacia fuera** → `NodePort` (o `LoadBalancer` donde haya nube). `api` y `cache` son internos → `ClusterIP`. Exponer de más es superficie de ataque gratis.
2. **El contenedor de `api` escucha en 8080** pero se quiere consumir en el 80 → `port: 80, targetPort: 8080`. Es el caso que hay que saber escribir sin dudar.
3. **La base de datos está fuera del cluster** → `ExternalName`. Así el código de la API le habla a un nombre interno (`db-externa.gratitud-datos`) y el día que cambie el host real solo se toca el Service.

## Razonamiento técnico resumido

```
Fuera --NodePort 31900--> portal-np --> Pods portal (gratitud-frontend)
   Pod portal --curl api.gratitud-api--> Service api (ClusterIP 80->8080) --> Pods api (gratitud-api)
      Pod api --curl cache.gratitud-datos--> Service cache (ClusterIP 80) --> Pods cache (gratitud-datos)
      Pod api --curl db-externa.gratitud-datos:5432--> CNAME --> db.corp.example.com
```

`portal` usa el nombre corto `api.gratitud-api` (o el FQDN) porque **cruza
namespace**: la línea `search` de su `/etc/resolv.conf` solo añade
`gratitud-frontend.svc.cluster.local`, no `gratitud-api...`.

## Procedimiento

```bash
# Estado inicial: namespaces + Deployments, sin Services
k apply -f ../RECURSOS/YAML/05-gratitud-namespaces.yaml
k -n gratitud-frontend rollout status deploy/portal
k -n gratitud-api       rollout status deploy/api
k -n gratitud-datos     rollout status deploy/cache

# R7 - index.html identificable
for nsd in gratitud-frontend/gratitud-portal gratitud-api/gratitud-api gratitud-datos/gratitud-cache; do
  ns=${nsd%/*}; app=${nsd#*/}
  for p in $(k -n $ns get pod -l app=$app -o name); do
    n=${p#pod/}
    k -n $ns exec "$n" -- sh -c "echo '$n' > /usr/share/nginx/html/index.html 2>/dev/null || \
                                echo '$n' > /tmp/index.html" || true
  done
done
# nota: nginx-unprivileged sirve /usr/share/nginx/html igualmente; si el exec de escritura
# falla por permisos, basta con distinguir los Pods por 'hostname' en los curl.

# R1 - api: ClusterIP 80 -> 8080
k -n gratitud-api expose deploy api --name api --port 80 --target-port 8080
# (equivale a spec.ports: [{port: 80, targetPort: 8080}])

# R2 - cache: ClusterIP 80
k -n gratitud-datos expose deploy cache --name cache --port 80 --target-port 80

# R3 - portal: NodePort 31900 (expose no fija nodePort; se parchea)
k -n gratitud-frontend expose deploy portal --name portal-np --port 80 --target-port 80 --type NodePort
k -n gratitud-frontend patch svc portal-np --type=json \
  -p='[{"op":"replace","path":"/spec/ports/0/nodePort","value":31900}]'

# R6 - db-externa: ExternalName
k -n gratitud-datos create service externalname db-externa --external-name db.corp.example.com
# (o aplicar el bloque correspondiente de 06-gratitud-referencia.yaml)

# R4/R5 - comprobar el flujo
k -n gratitud-frontend exec deploy/portal -- sh -c 'curl -s http://api.gratitud-api' 2>/dev/null \
  || k -n gratitud-frontend run p --rm -i --image=nicolaka/netshoot --restart=Never -- curl -s http://api.gratitud-api
k -n gratitud-api run p --rm -i --image=nicolaka/netshoot --restart=Never -- curl -s http://cache.gratitud-datos
k -n gratitud-api run p --rm -i --image=nicolaka/netshoot --restart=Never -- nslookup db-externa.gratitud-datos

curl -s -o /dev/null -w '%{http_code}\n' http://<IP-NODO>:31900/
```

Atajo equivalente para todo el conjunto:

```bash
k apply -f ../RECURSOS/YAML/06-gratitud-referencia.yaml
```

## Validación

```bash
k get svc -A -l part-of=gratitud
k -n gratitud-api        get svc api        -o jsonpath='{.spec.ports[0].port}->{.spec.ports[0].targetPort}{"\n"}'   # 80->8080
k -n gratitud-frontend   get svc portal-np  -o jsonpath='{.spec.type}/{.spec.ports[0].nodePort}{"\n"}'               # NodePort/31900
k -n gratitud-datos      get svc db-externa -o jsonpath='{.spec.type}/{.spec.externalName}{"\n"}'                    # ExternalName/db.corp.example.com
k -n gratitud-api        get endpointslices -l kubernetes.io/service-name=api
k -n gratitud-datos      get endpointslices -l kubernetes.io/service-name=cache
```

## Resultado esperado

```
NAMESPACE           NAME         TYPE           PORT(S)
gratitud-frontend   portal-np    NodePort       80:31900/TCP
gratitud-api        api          ClusterIP      80/TCP           (targetPort 8080)
gratitud-datos      cache        ClusterIP      80/TCP
gratitud-datos      db-externa   ExternalName   <none>           -> db.corp.example.com
```

* `api` y `cache` con `EndpointSlice` de 2 direcciones.
* `db-externa` sin `ClusterIP` ni `EndpointSlice`; `nslookup` devuelve el CNAME.
* `curl http://api.gratitud-api` desde `gratitud-frontend` → página del Pod `api`.
* `curl http://cache.gratitud-datos` desde `gratitud-api` → página del Pod `cache`.
* `curl http://<IP-NODO>:31900/` → `200`.

## Error frecuente

* Publicar `api` o `cache` como `NodePort` "por si acaso". Rompe el requisito R3.
* Olvidar `--target-port 8080` en `api`: el `EndpointSlice` se llena pero `curl` da `connection refused`.
* Llamar a `api` con el nombre corto desde `gratitud-frontend`: no resuelve porque está en otro namespace.
* Creer que `ExternalName` abre conectividad: solo traduce el nombre. Si el cluster no tiene ruta a `db.corp.example.com`, seguirá sin llegar.
* Usar `kubectl expose` esperando que fije el `nodePort`: no lo hace, hay que parchear o escribir el manifiesto.

## CKA Tip

```bash
k expose deploy <d> --name <svc> --port 80 --target-port 8080 [--type NodePort]
k create service externalname <svc> --external-name host.example.com
k -n <ns-cliente> run p --rm -it --image=nicolaka/netshoot --restart=Never -- \
  sh -c 'cat /etc/resolv.conf; nslookup <svc>.<ns-servidor>; curl -s http://<svc>.<ns-servidor>'
```

**Entre namespaces, siempre `<svc>.<ns>` como mínimo. El FQDN completo nunca falla.**
