# LAB 10.4 — Challenge: «el Ingress no enruta»

## Nivel

Challenge / Troubleshooting.

## Duración

20 minutos.

## Objetivo

Distinguir, en un solo Ingress, **cuatro fallos** que dan síntomas HTTP
distintos —`ADDRESS` vacío, `404`, `503` y certificado equivocado— pero cuya
causa está en cuatro sitios: `ingressClassName`, el `backend` (Service/puerto),
el `pathType` y el Secret TLS.

```
IDENTIFICAR -> DIAGNOSTICAR -> CORREGIR -> VALIDAR
```

## Competencias

* Reconocer un `ingressClassName` que ningún controlador adopta.
* Detectar un `backend` que apunta a un Service o puerto inexistente (`503`).
* Detectar un `pathType: Exact` donde hacía falta `Prefix` (`404` en subrutas).
* Detectar un `secretName` que no existe (certificado por defecto del controlador).
* Recorrer la ruta `clase → backend → pathType → host/TLS`.

## Escenario

Tras un despliegue, la web de GRATITUD "no va": el portal da `404`, `/api` da
`503` y el HTTPS presenta un certificado que no es el nuestro. Nadie ha tocado
nada, oficialmente. **Hay 4 fallos**, todos en el objeto Ingress `gratitud`.

## Estado inicial

```bash
cd CLASE-10/RECURSOS/SCRIPTS
chmod +x *.sh
./setup-lab.sh
```

Requiere el **Ingress Controller del LAB 10.1** (`kubectl get ingressclass`).

`setup-lab.sh` crea el namespace **`gratitud-web`** con:

* Deployments y Services `portal` (80), `api` (escucha en 8080, Service en 80→8080) y `docs` (80).
* Un Deployment `probe` (`nicolaka/netshoot`) para hacer `exec`/`curl`.
* Un Secret `gratitud-tls` de tipo `kubernetes.io/tls` (correcto).
* El Ingress `gratitud` **con 4 defectos**.

## Requerimientos

1. Empieza por lo que funciona: ¿el Ingress tiene `ADDRESS`? ¿los Services tienen endpoints?
2. Recorre la ruta:
   ```
   ingressClassName -> backend (Service + puerto) -> pathType / path -> host + Secret TLS
   ```
3. Identifica los **4 fallos**.
4. Documenta, por cada uno: síntoma HTTP, comando que lo reveló, causa raíz y qué campo lo corrige.
5. Corrige hasta que:
   * `http://gratitud.example.com:32080/` devuelva `200` (portal),
   * `http://gratitud.example.com:32080/api/health` devuelva `200` (api),
   * `https://gratitud.example.com:32443/` presente el certificado con `CN=gratitud.example.com`.

## Restricciones

* **No borres** el Ingress ni los Deployments.
* No expongas `portal`, `api` ni `docs` por `NodePort`.
* No uses `defaultBackend` para tapar el problema de `pathType`.
* Corrige el Ingress in situ (`edit` / `patch` / `apply`).

## Ruta de diagnóstico

```
¿Tiene ADDRESS el Ingress?      get ingress            -> NO: ingressClassName no lo adopta nadie
   |  sí
¿Responde / con 200?            curl Host: ... /        -> 503: backend Service/puerto ; 404: host/path/pathType
   |  sí
¿Responde /api/health?          curl ... /api/health   -> 404: pathType Exact donde debia ir Prefix
   |  sí
¿HTTPS con tu certificado?      curl -kv https://...    -> cert por defecto: secretName inexistente o mal
```

## Comandos de diagnóstico

```bash
kubectl -n gratitud-web get ingress gratitud -o wide
kubectl -n gratitud-web describe ingress gratitud
kubectl get ingressclass
kubectl -n gratitud-web get svc,endpointslices
kubectl -n gratitud-web get secret

TRAEFIK_IP=$(kubectl -n ingress get svc traefik -o jsonpath='{.spec.clusterIP}')
kubectl -n gratitud-web exec deploy/probe -- curl -s -o /dev/null -w '%{http_code}\n' -H 'Host: gratitud.example.com' http://$TRAEFIK_IP/
kubectl -n gratitud-web exec deploy/probe -- curl -s -o /dev/null -w '%{http_code}\n' -H 'Host: gratitud.example.com' http://$TRAEFIK_IP/api/health
```

## Validación

```bash
cd CLASE-10/RECURSOS/SCRIPTS && ./validate-lab.sh

# manual, desde tu equipo
curl -s -o /dev/null -w '%{http_code}\n' --resolve gratitud.example.com:32080:<IP-NODO> http://gratitud.example.com:32080/
curl -s -o /dev/null -w '%{http_code}\n' --resolve gratitud.example.com:32080:<IP-NODO> http://gratitud.example.com:32080/api/health
curl -kv --resolve gratitud.example.com:32443:<IP-NODO> https://gratitud.example.com:32443/ 2>&1 | grep -E 'subject:|issuer:'
```

## Los 4 fallos (para el instructor — no mirar antes de intentarlo)

<details>
<summary>Spoiler</summary>

1. **`ingressClassName`.** El Ingress dice `nginx`; la clase registrada es `traefik`. Nadie lo adopta → `ADDRESS` vacío, sin error. → `ingressClassName: traefik`.
2. **`backend` puerto.** La regla `/` apunta a `portal` en el puerto **8080**; el Service `portal` está en el **80**. El controlador responde `503`. → `port.number: 80`.
3. **`pathType`.** La regla `/api` es `pathType: Exact`; `/api` responde pero `/api/health` da `404`. → `pathType: Prefix`.
4. **`secretName`.** `spec.tls[0].secretName` es `gratitud-tls-viejo`, que no existe; el Secret correcto es `gratitud-tls`. HTTPS presenta el certificado por defecto del controlador. → `secretName: gratitud-tls`.

</details>

## Resultado esperado

* El Ingress `gratitud` tiene `ADDRESS`.
* `/` → `200` (portal); `/api` y `/api/health` → `200` (api).
* `https://gratitud.example.com:32443/` presenta el certificado con `CN=gratitud.example.com`, no el del controlador.
* `./validate-lab.sh` termina con `LAB 10.4 SUPERADO`.

## Criterios de éxito

- [ ] Empecé por comprobar `ADDRESS` y endpoints, no por el `curl` externo.
- [ ] Identifiqué los 4 fallos y el campo del Ingress que corrige cada uno.
- [ ] Documenté síntoma HTTP, comando y causa raíz de cada fallo.
- [ ] `/` y `/api/health` responden `200`.
- [ ] HTTPS presenta mi certificado, no el del controlador.
- [ ] No borré el Ingress ni expuse Services por `NodePort`.
- [ ] `./validate-lab.sh` pasa.
