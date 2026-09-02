# LAB 9.4 — Challenge: «GRATITUD no conecta»

## Nivel

Challenge / Troubleshooting.

## Duración

20 minutos.

## Objetivo

Distinguir, en un solo escenario multi-namespace, **cuatro fallos** que producen el
mismo síntoma aparente —"no responde"— pero cuya causa está en capas distintas:
selector, `targetPort`, tipo de Service y FQDN entre namespaces.

```
IDENTIFICAR -> DIAGNOSTICAR -> CORREGIR -> VALIDAR
```

## Competencias

* Separar un `EndpointSlice` vacío por selector de uno vacío por labels del Pod.
* Detectar un `targetPort` que no coincide con el puerto del contenedor.
* Detectar un Service que debería ser `NodePort` y es `ClusterIP`.
* Detectar una llamada entre namespaces que usa el nombre corto en vez del FQDN.
* Recorrer la ruta completa `Pod → EndpointSlice → Service → FQDN → NodePort`.

## Escenario

El programa **GRATITUD** dejó de funcionar tras un despliegue. El portal responde
"desde dentro" pero no desde fuera, y el equipo de API dice que "la caché no
contesta". Nadie ha tocado nada, oficialmente. **Hay 4 fallos.**

## Estado inicial

```bash
cd CLASE-09/RECURSOS/SCRIPTS
chmod +x *.sh
./setup-lab.sh
```

Crea los namespaces **`gratitud-frontend`**, **`gratitud-api`** y
**`gratitud-datos`** con:

* Deployments `portal` (nginx), `api` (nginx-unprivileged, escucha en 8080) y `cache` (nginx).
* Un Deployment `probe` (`nicolaka/netshoot`) en cada namespace, para que puedas hacer `exec` y `curl`.
* Sus Services **con 4 defectos**.

## Requerimientos

1. Comprueba primero **qué funciona**. No empieces por el `curl` externo.
2. Recorre la ruta de dentro hacia fuera:
   ```
   Pod -> EndpointSlice -> Service (port/targetPort) -> FQDN entre namespaces -> NodePort -> Cliente
   ```
3. Identifica los **4 fallos**.
4. Documenta, por cada uno: síntoma, comando que lo reveló, causa raíz y capa afectada.
5. Corrige hasta que:
   * el `EndpointSlice` de `api` tenga las 2 direcciones de sus Pods,
   * `probe` en `gratitud-api` alcance a `api` **y** a `cache.gratitud-datos`,
   * `curl http://<IP-NODO>:31900/` devuelva `200`.

## Restricciones

* **No borres** los Deployments.
* No conviertas `api` ni `cache` en `NodePort` para "saltarte" el problema.
* No expongas `api` ni `cache` fuera del cluster: la única entrada es `portal-np`.
* Corrige los Services in situ (`edit` / `patch` / `apply`); si un Service está en el namespace equivocado, recréalo **en el correcto**.

## Ruta de diagnóstico

```
¿Tiene endpoints el Service?     get endpointslices        -> NO: selector del Service vs. labels del Pod
   |  sí
¿Responde por su ClusterIP?      curl <clusterIP>:<port>   -> NO: targetPort, o el contenedor no escucha ahí
   |  sí
¿Resuelve desde el otro ns?      nslookup <svc>.<ns>       -> NO: falta el namespace en el nombre, o el Service está en otro ns
   |  sí
¿Entra desde fuera?              curl <IP-nodo>:<nodePort> -> NO: el Service es ClusterIP, o le falta el nodePort
```

## Comandos de diagnóstico

```bash
kubectl get pods -A -l part-of=gratitud --show-labels -o wide
kubectl -n gratitud-api    get svc,endpointslices
kubectl -n gratitud-api    get svc api  -o yaml | grep -E 'selector|Port|port'
kubectl -n gratitud-datos  get svc,endpointslices
kubectl -n gratitud-frontend get svc portal-np -o yaml | grep -E 'type|nodePort|Port'
kubectl -n gratitud-api    exec deploy/probe -- nslookup cache.gratitud-datos
kubectl -n gratitud-api    exec deploy/probe -- curl -s --max-time 3 http://api
kubectl -n gratitud-api    exec deploy/probe -- curl -s --max-time 3 http://cache.gratitud-datos
```

## Validación

```bash
kubectl -n gratitud-api   exec deploy/probe -- curl -s --max-time 3 -o /dev/null http://api
kubectl -n gratitud-api   exec deploy/probe -- curl -s --max-time 3 -o /dev/null http://cache.gratitud-datos
curl -s -o /dev/null -w '%{http_code}\n' http://<IP-NODO>:31900/

cd CLASE-09/RECURSOS/SCRIPTS && ./validate-lab.sh
```

## Resultado esperado

* `api` tiene `EndpointSlice` con 2 direcciones y responde por su `ClusterIP` en el puerto 80.
* `cache` existe en `gratitud-datos`, con endpoints, y responde desde `gratitud-api` como `cache.gratitud-datos`.
* `portal-np` es `NodePort` con `nodePort: 31900` y devuelve `200` desde fuera del cluster.
* `./validate-lab.sh` termina con `LAB 9.4 SUPERADO`.

## Los 4 fallos (para el instructor — no mirar antes de intentarlo)

<details>
<summary>Spoiler</summary>

1. **Selector.** `svc/api` tiene `selector: app=gratitud-api-v2`; los Pods son `app=gratitud-api`. `EndpointSlice` vacío. → Corregir el selector.
2. **targetPort.** `svc/api` usa `port: 80, targetPort: 80`; el contenedor escucha en **8080**. Con endpoints pero `connection refused`. → `targetPort: 8080`.
3. **Tipo de Service.** `svc/portal-np` es `ClusterIP`; debería ser `NodePort` con `nodePort: 31900`. Interno OK, externo no entra. → Cambiar `type` y fijar el `nodePort`.
4. **Namespace / FQDN.** El Service `cache` se creó en `gratitud-api` en vez de `gratitud-datos`. `cache.gratitud-datos` no resuelve (NXDOMAIN) y `cache.gratitud-api` no tiene endpoints. → Recrear `cache` en `gratitud-datos`.

</details>

## Criterios de éxito

- [ ] Empecé el diagnóstico desde dentro del cluster, no por el `curl` externo.
- [ ] Identifiqué los 4 fallos y la capa de cada uno.
- [ ] Documenté síntoma, comando y causa raíz de cada fallo.
- [ ] `api` tiene endpoints y responde en el puerto 80.
- [ ] `cache.gratitud-datos` resuelve y responde desde `gratitud-api`.
- [ ] `portal-np` responde `200` desde fuera.
- [ ] No convertí `api` ni `cache` en `NodePort`.
- [ ] `./validate-lab.sh` pasa.
