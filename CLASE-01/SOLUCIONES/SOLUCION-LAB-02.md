# SOLUCIÓN — LAB 1.2 · Services, EndpointSlice y DNS

> **MATERIAL DEL INSTRUCTOR.**

## Diagnóstico

El laboratorio culmina en un fallo provocado: al cambiar el label del Pod, el `selector` del Service deja de coincidir, el controlador de EndpointSlice retira la dirección y el Service pasa a tener **0 endpoints**. El Service sigue existiendo, sigue teniendo ClusterIP y sigue resolviendo por DNS: **lo único que falla es que no hay backends**. Ese matiz es exactamente lo que confunde a los alumnos en el examen.

## Razonamiento técnico resumido

```
Service  ->  selector  ->  EndpointSlice  ->  Pod labels  ->  Pod  ->  targetPort
```

* `port` = puerto del Service. `targetPort` = puerto del contenedor. `nodePort` = puerto publicado en cada nodo (rango 30000–32767).
* El DNS del cluster (CoreDNS) resuelve `<svc>.<ns>.svc.cluster.local` a la **ClusterIP**, no a la IP del Pod. Por eso la resolución sigue funcionando aunque no haya endpoints.
* `Endpoints` es el objeto legado; desde hace varias versiones el objeto vivo es **`EndpointSlice`**. Enseña `kubectl get endpointslices` como comando por defecto.

## Procedimiento

```bash
k create ns c1-inter
k config set-context --current --namespace=c1-inter

# 2-3
k run webserver --image=httpd:2.4-alpine -l app=webserver
k run dbserver  --image=postgres:16-alpine -l app=dbserver --env=POSTGRES_PASSWORD=Sup3rS3cret

# 4  (imperativo)
k expose pod dbserver --name=svc-dbserver --port=15432 --target-port=5432

# 5  NodePort con nodePort fijo: kubectl expose no permite fijar nodePort,
#    hay que generar y editar (esto es un patrón de examen)
k expose pod webserver --name=svc-webserver --type=NodePort \
  --port=8080 --target-port=80 $do > svc-web.yaml
# añadir  nodePort: 31100  bajo ports[0]
k apply -f svc-web.yaml
```

`svc-web.yaml` resultante:

```yaml
spec:
  type: NodePort
  selector:
    app: webserver
  ports:
    - port: 8080
      targetPort: 80
      nodePort: 31100
      protocol: TCP
```

```bash
# 6-7
k run tmp --rm -it --image=nicolaka/netshoot --restart=Never -- bash
  nslookup svc-webserver
  nslookup svc-dbserver.c1-inter.svc.cluster.local
  curl http://svc-webserver:8080
  exit

# alternativa sin netshoot
k run tmp --rm -it --image=busybox:1.36 --restart=Never -- sh
  nslookup svc-webserver
  wget -qO- http://svc-webserver:8080

# 8  (desde tu equipo)
curl http://<IP-WORKER>:31100

# 9
k get endpointslices
k get endpointslices -l kubernetes.io/service-name=svc-webserver -o yaml
```

### Romper y reparar

```bash
# 10
k label pod webserver app=web-old --overwrite

# 11
k get endpointslices -l kubernetes.io/service-name=svc-webserver
# -> ENDPOINTS: <unset>  /  ADDRESSES vacio
k describe svc svc-webserver | grep -i endpoints
curl http://<IP-WORKER>:31100     # timeout / connection refused

# 12  reparar sin recrear nada
k label pod webserver app=webserver --overwrite
```

Alternativa igualmente válida: modificar el `selector` del Service con `k patch svc svc-webserver -p '{"spec":{"selector":{"app":"web-old"}}}'`. Discute con el grupo cuál de las dos es la correcta **en producción** (depende de cuál sea la verdad: el contrato del Service o el label del Pod).

## Validación

```bash
k get svc
k get endpointslices
k get pods --show-labels
curl -s -o /dev/null -w '%{http_code}\n' http://<IP-WORKER>:31100   # 200
```

## Resultado esperado

```
NAME            TYPE        CLUSTER-IP      PORT(S)
svc-dbserver    ClusterIP   10.96.14.201    15432/TCP
svc-webserver   NodePort    10.96.201.33    8080:31100/TCP

NAME                  ADDRESSTYPE   PORTS   ENDPOINTS
svc-dbserver-abcde    IPv4          5432    10.244.1.9
svc-webserver-fghij   IPv4          80      10.244.1.8
```

## Error frecuente

* Poner `targetPort: 8080` porque el `port` del Service es 8080. El `targetPort` es el del **contenedor**.
* Intentar fijar `nodePort` con `kubectl expose`: no existe la opción. Hay que generar YAML y editar.
* Creer que "el DNS está roto" cuando el Service no tiene endpoints. El DNS resuelve perfectamente; lo que no hay es a quién enviar el tráfico. `nslookup` OK + `curl` timeout = **problema de endpoints, no de DNS**.
* Usar `kubectl get endpoints` y no ver nada raro. Usa `endpointslices`.

## CKA Tip

```bash
# Diagnóstico de Service en 3 comandos
k get svc <svc> -o yaml | grep -A5 -E 'selector|ports'
k get endpointslices -l kubernetes.io/service-name=<svc>
k get pods --show-labels

# Pod desechable para pruebas de red
k run tmp --rm -it --image=busybox:1.36 --restart=Never -- sh
```
