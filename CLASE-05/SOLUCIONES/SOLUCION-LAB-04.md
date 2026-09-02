# SOLUCIÓN — LAB 5.4 · Challenge de red

> **MATERIAL DEL INSTRUCTOR.**

## Diagnóstico

**4 fallos, en 4 capas distintas.** Todos producen el mismo síntoma superficial: "no llego".

| # | Capa | Síntoma | Comando que lo revela | Causa raíz |
|---|---|---|---|---|
| 1 | **DNS / NetworkPolicy** | `nslookup backend` da timeout desde `frontend` | `k -n c5-challenge exec deploy/frontend -- nslookup backend` + `describe networkpolicy allow-dns` | La política `allow-dns` permite el puerto **5353**, no el **53** |
| 2 | **Service** | `backend` sin endpoints | `k -n c5-challenge get endpointslices` | El Service `backend` selecciona `app=backend-v2`; los Pods llevan `app=backend` |
| 3 | **Ingress (clase)** | `kubectl get ingress` sin `ADDRESS`; ningún controlador lo adopta | `k get ingressclass` vs `k get ingress portal -o yaml` | `ingressClassName: nginx`, pero la clase registrada es `traefik` |
| 4 | **Ingress (backend)** | El Ingress apunta a un Service que no existe y a un puerto equivocado | `k -n c5-challenge get ingress portal -o yaml` | `service.name: portal-svc` (el real es `portal`) y `port.number: 8080` (el real es `80`) |

## Razonamiento técnico resumido

La ruta completa, y qué rompe cada fallo:

```
Cliente
   |                      <- fallo 3: ningún controlador adopta el Ingress
INGRESS
   |                      <- fallo 4: backend y puerto inexistentes
SERVICE
   |                      <- fallo 2: selector sin coincidencia -> 0 endpoints
ENDPOINTSLICE
   |
POD
   ^
   |                      <- fallo 1: sin DNS, nada resuelve por nombre
CoreDNS
```

Diagnosticar de dentro hacia fuera evita perder tiempo: si `frontend` no resuelve `backend`, el Ingress es irrelevante todavía.

## Procedimiento

```bash
NS=c5-challenge

# --- Reconocimiento
k -n $NS get pods --show-labels
k -n $NS get svc,endpointslices
k -n $NS get networkpolicy
k -n $NS get ingress -o yaml
k get ingressclass

# --- Fallo 1: DNS bloqueado por la política de egress
k -n $NS exec deploy/frontend -- nslookup backend      # timeout
k -n $NS describe networkpolicy allow-dns              # puerto 5353
k -n $NS patch networkpolicy allow-dns --type=json -p='[
  {"op":"replace","path":"/spec/egress/0/ports/0/port","value":53},
  {"op":"add","path":"/spec/egress/0/ports/-","value":{"protocol":"TCP","port":53}}
]'
k -n $NS exec deploy/frontend -- nslookup backend      # resuelve

# --- Fallo 2: selector del Service
k -n $NS get svc backend -o jsonpath='{.spec.selector}{"\n"}'   # {"app":"backend-v2"}
k -n $NS patch svc backend -p '{"spec":{"selector":{"app":"backend"}}}'
k -n $NS get endpointslices                                     # 2 direcciones
k -n $NS exec deploy/frontend -- curl -s -o /dev/null -w '%{http_code}\n' http://backend

# --- Fallo 3: ingressClassName
k get ingressclass                                              # traefik
k -n $NS patch ingress portal -p '{"spec":{"ingressClassName":"traefik"}}'

# --- Fallo 4: backend del Ingress
k -n $NS patch ingress portal --type=json -p='[
  {"op":"replace","path":"/spec/rules/0/http/paths/0/backend/service/name","value":"portal"},
  {"op":"replace","path":"/spec/rules/0/http/paths/0/backend/service/port/number","value":80}
]'

k -n $NS get ingress portal
curl -s -o /dev/null -w '%{http_code}\n' http://<IP-NODO>:32080/
```

> La política `allow-ingress-controller` del escenario ya permite el tráfico entrante desde el namespace `ingress` hacia los Pods `backend`. Si en tu instalación el controlador vive en otro namespace, hay que ajustar ese `namespaceSelector`: es un quinto punto de discusión excelente para el grupo.

## Validación

```bash
k -n c5-challenge get svc,endpointslices,ingress
k -n c5-challenge get networkpolicy default-deny
k -n c5-challenge exec deploy/frontend -- curl -s -o /dev/null -w '%{http_code}\n' http://backend
curl -s -o /dev/null -w '%{http_code}\n' http://<IP-NODO>:32080/

cd CLASE-05/RECURSOS/SCRIPTS && ./validate-lab.sh
```

## Resultado esperado

```
frontend -> backend : 200
Ingress externo      : 200
default-deny         : sigue existiendo
LAB 5.4 SUPERADO
```

## Error frecuente

* **Borrar `default-deny`** para que todo funcione. Es lo primero que intenta medio grupo, y está explícitamente prohibido. Un fallo de conectividad no se arregla desactivando la seguridad: se arregla concediendo el permiso concreto que falta.
* Convertir los Services a `NodePort` para saltarse el Ingress. Resuelve el `curl` y no arregla nada.
* Empezar por el `curl` externo y quedarse atascado media hora en el Ingress cuando el fallo real estaba en el DNS.
* Cambiar los labels de los Pods en vez del selector del Service: el Deployment los recrea y el arreglo se deshace.
* No mirar `kubectl get ingressclass` y suponer que la clase es `nginx` por costumbre.

## CKA Tip

```bash
# Diagnóstico de red, en orden, sin saltarse pasos
k exec <pod> -- nslookup <svc>                     # 1. DNS
k get endpointslices -l kubernetes.io/service-name=<svc>   # 2. endpoints
k exec <pod> -- curl -s --max-time 3 http://<svc>  # 3. Service
k get networkpolicy -n <ns>                        # 4. políticas
k get ingress,ingressclass                         # 5. Ingress
```

**Traducción de síntomas:**
`nslookup` falla → DNS o NetworkPolicy de egress al 53.
`nslookup` OK + `curl` timeout → endpoints o NetworkPolicy.
`curl` interno OK + externo falla → Ingress, clase o controlador.
