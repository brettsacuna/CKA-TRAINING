# LAB 1.2 — Services, EndpointSlice y DNS

## Nivel

Intermedio.

## Duración

30 minutos.

## Objetivo

Exponer aplicaciones con Services `ClusterIP` y `NodePort`, entender la cadena que conecta un Service con sus Pods y comprobar la resolución DNS interna del cluster.

## Competencias

* Crear Services de forma imperativa (`kubectl expose`) y declarativa.
* Distinguir `port`, `targetPort` y `nodePort`.
* Leer `EndpointSlice` y relacionarlo con el selector del Service.
* Resolver nombres de Service por DNS desde un Pod.
* Provocar y reparar la pérdida de endpoints.

## Escenario

Tu equipo despliega dos componentes en el cluster: un servidor web (`webserver`) y una base de datos (`dbserver`). El web debe alcanzar a la base de datos **por nombre**, no por IP, porque las IPs de Pod cambian en cada recreación. Además, QA necesita llegar al web desde fuera del cluster sin balanceador.

## Estado inicial

* Namespace de trabajo: **`c1-inter`** (lo creas tú).
* Sin recursos previos.
* Necesitas al menos un worker con la IP accesible desde tu máquina para probar el NodePort.

## Requerimientos

### Parte A — Los Pods

1. Crea el namespace `c1-inter`.
2. Crea el Pod **`webserver`**, imagen `httpd:2.4-alpine`, con el label **`app=webserver`**.
3. Crea el Pod **`dbserver`**, imagen `postgres:16-alpine`, con el label **`app=dbserver`** y la variable de entorno `POSTGRES_PASSWORD=Sup3rS3cret`.
   El contenedor escucha en el puerto **5432**.

### Parte B — Los Services

4. Expón `dbserver` con un Service **`svc-dbserver`** de tipo `ClusterIP` que escuche en el puerto **15432** y reenvíe al **5432** del contenedor.
5. Expón `webserver` con un Service **`svc-webserver`** de tipo `NodePort` que escuche en el puerto **8080**, reenvíe al **80** del contenedor y publique el **`nodePort` 31100**.

### Parte C — Validación funcional

6. Desde un Pod temporal (`kubectl run tmp --rm -it --image=nicolaka/netshoot --restart=Never -- bash` o `busybox`), resuelve por DNS:
   * `svc-webserver`
   * `svc-dbserver.c1-inter.svc.cluster.local`
7. Desde ese mismo Pod, haz `curl http://svc-webserver:8080` y confirma que responde el Apache.
8. Desde fuera del cluster, accede a `http://<IP-de-un-worker>:31100`.
9. Muestra el `EndpointSlice` de `svc-webserver` y comprueba que contiene la IP del Pod `webserver`.

### Parte D — Romper y reparar

10. Cambia el label del Pod `webserver` a `app=web-old`.
11. Vuelve a mirar el `EndpointSlice` y vuelve a hacer `curl`. **Explica con tus palabras qué pasó y por qué.**
12. Repáralo **sin borrar ni recrear el Pod ni el Service**.

## Restricciones

* Trabaja exclusivamente en `c1-inter`.
* En el paso 12 no puedes eliminar ni recrear el Pod `webserver` ni el Service `svc-webserver`.
* No uses Ingress ni LoadBalancer en este laboratorio.

## Validación

```bash
kubectl -n c1-inter get pods --show-labels -o wide
kubectl -n c1-inter get svc
kubectl -n c1-inter get endpointslices
kubectl -n c1-inter describe svc svc-webserver
kubectl -n c1-inter get svc svc-webserver -o jsonpath='{.spec.ports[0]}{"\n"}'
curl -s http://<IP-WORKER>:31100
```

## Resultado esperado

* `svc-dbserver`: `ClusterIP`, `15432 -> 5432`, con un endpoint (la IP de `dbserver`).
* `svc-webserver`: `NodePort`, `8080:31100/TCP -> 80`, con un endpoint (la IP de `webserver`).
* La resolución DNS devuelve la ClusterIP del Service, no la IP del Pod.
* `curl` interno y externo devuelven `<html><body><h1>It works!</h1></body></html>`.
* Tras el paso 10 el EndpointSlice queda **sin direcciones** y el `curl` falla o da timeout.
* Tras el paso 12 el endpoint reaparece y el `curl` vuelve a funcionar.

## Criterios de éxito

- [ ] Ambos Pods `Running` con sus labels correctos.
- [ ] `svc-dbserver` con `port 15432` y `targetPort 5432`.
- [ ] `svc-webserver` con `port 8080`, `targetPort 80` y `nodePort 31100`.
- [ ] La resolución DNS de ambos Services funciona desde un Pod.
- [ ] `curl` interno por nombre de Service responde.
- [ ] `curl` externo por NodePort responde.
- [ ] Sé leer un `EndpointSlice` y relacionarlo con el selector.
- [ ] Provoqué la pérdida de endpoints y expliqué la causa.
- [ ] Restauré el servicio sin recrear Pod ni Service.
