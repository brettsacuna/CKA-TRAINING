# SOLUCIÓN — LAB 6.5 · INTEGRADOR FINAL

> **MATERIAL DEL INSTRUCTOR.** No distribuir en ningún caso antes de la Fase 2.

---

# FASE 1 — CONSTRUCCIÓN

## Razonamiento técnico resumido

La arquitectura toca las cinco áreas del currículum CKA a la vez. El orden de construcción importa: si se despliega la NetworkPolicy `default-deny` antes que las aplicaciones, nada arranca correctamente y el alumno pierde el hilo.

**Orden recomendado:**

```
Namespace -> ConfigMap + Secret -> Storage -> StatefulSet -> Deployments
   -> Services -> TLS -> Ingress -> NetworkPolicies -> Validación
```

Las políticas **al final**, cuando ya sabes que todo funciona sin ellas. Así, si algo se rompe al aplicarlas, sabes con certeza que la causa es la red.

## Procedimiento

Manifiesto completo de referencia: `RECURSOS/YAML/01-tienda-referencia.yaml` y `02-tienda-networkpolicies.yaml`.

```bash
# R1
k apply -f ../RECURSOS/YAML/01-tienda-referencia.yaml    # sin las NetworkPolicies aún

# Si no hay StorageClass por defecto, antes:
#   crear 3 PV de 1Gi RWO con storageClassName: "" y ajustar volumeClaimTemplates

# R2-R4  (incluidos en el manifiesto)
k -n tienda rollout status sts/db
k -n tienda rollout status deploy/backend
k -n tienda rollout status deploy/frontend
k -n tienda get pods -o wide            # comprobar el reparto entre nodos

# R5  TLS
CN=tienda.local NS=tienda NAME=tienda-tls \
  ../../CLASE-05/RECURSOS/SCRIPTS/gen-tls-secret.sh
k -n tienda get secret tienda-tls -o jsonpath='{.type}{"\n"}'

# R6  NetworkPolicies (al final)
k apply -f ../RECURSOS/YAML/02-tienda-networkpolicies.yaml
k label ns ingress kubernetes.io/metadata.name=ingress --overwrite  # normalmente ya existe

# R7
k top pods -n tienda
k -n tienda get events --sort-by=.lastTimestamp | tail -20
```

### Puntos de fricción esperados en la Fase 1

| Punto | Qué pasa | Qué debe aprender el alumno |
|---|---|---|
| `PGDATA` | Postgres se niega a inicializarse sobre un directorio no vacío (`lost+found`) | Por eso se define `PGDATA=/var/lib/postgresql/data/pgdata`, un subdirectorio |
| `default-deny` antes de tiempo | Nada arranca y el diagnóstico se vuelve imposible | Orden de construcción |
| DNS bloqueado | Al aplicar `default-deny` sin `allow-dns`, todo deja de resolver | El fallo de NetworkPolicy más común |
| Ingress Controller en otro namespace | El `namespaceSelector` no coincide y el tráfico externo no entra | Verificar con `k get ns --show-labels` |
| Anti-affinity `required` con 2 nodos y 3 réplicas | La tercera queda `Pending` | Por eso el requisito dice "siempre que sea posible" → `preferred` |

## Validación de la Fase 1

```bash
cd CLASE-06/RECURSOS/SCRIPTS && ./validate-lab.sh final
curl -sk -o /dev/null -w '%{http_code}\n' https://tienda.local:32443/ \
  --resolve tienda.local:32443:<IP-NODO>
curl -sk -o /dev/null -w '%{http_code}\n' https://tienda.local:32443/api \
  --resolve tienda.local:32443:<IP-NODO>
```

---

# FASE 2 — TROUBLESHOOTING

## Diagnóstico

`inject-failures.sh` aplica **7 fallas**:

| # | Categoría | Objeto alterado | Cambio | Síntoma |
|---|---|---|---|---|
| 1 | Selector incorrecto | `svc/backend` | `selector.app: backend-old` | `backend` sin endpoints; `/api` da 503 |
| 2 | `targetPort` incorrecto | `svc/frontend` | `targetPort: 8080` | `/` da 502 o timeout aunque hay endpoints |
| 3 | ConfigMap mal referenciado | `deploy/backend` | `configMapRef: app-config-v2` | `CreateContainerConfigError` |
| 4 | Clave de Secret errónea | `deploy/backend` | `secretKeyRef.key: passwd` | `CreateContainerConfigError` |
| 5 | NetworkPolicy bloqueando | `netpol/allow-frontend-to-backend` | `podSelector.app: ninguno` | `frontend -> backend` con timeout |
| 6 | Ingress a Service inexistente | `ingress/tienda` | `service.name: frontend-svc` | El path `/` no enruta |
| 7 | Scheduling | `deploy/frontend` | `nodeSelector: tier=gold` | Pods de `frontend` en `Pending` |

## Procedimiento de reparación

```bash
NS=tienda

# --- Reconocimiento global (siempre primero)
k -n $NS get all,pvc,ingress,networkpolicy
k -n $NS get pods -o wide
k -n $NS get events --sort-by=.lastTimestamp | tail -30
k -n $NS get endpointslices

# --- 7  Scheduling: frontend Pending
k -n $NS describe pod -l app=frontend | sed -n '/Events/,$p'
k get nodes -L tier                                    # ningún nodo tiene tier=gold
k -n $NS patch deploy frontend --type=json \
  -p='[{"op":"remove","path":"/spec/template/spec/nodeSelector"}]'

# --- 3 y 4  Configuración: backend CreateContainerConfigError
k -n $NS describe pod -l app=backend | sed -n '/Events/,$p'
k -n $NS get cm,secret
k -n $NS patch deploy backend --type=json -p='[
  {"op":"replace","path":"/spec/template/spec/containers/0/envFrom/0/configMapRef/name","value":"app-config"},
  {"op":"replace","path":"/spec/template/spec/containers/0/env/0/valueFrom/secretKeyRef/key","value":"password"}
]'
k -n $NS rollout status deploy/backend

# --- 1  Selector del Service backend
k -n $NS get svc backend -o jsonpath='{.spec.selector}{"\n"}'
k -n $NS patch svc backend -p '{"spec":{"selector":{"app":"backend"}}}'
k -n $NS get endpointslices

# --- 2  targetPort del Service frontend
k -n $NS get svc frontend -o jsonpath='{.spec.ports[0]}{"\n"}'
k -n $NS patch svc frontend --type=json \
  -p='[{"op":"replace","path":"/spec/ports/0/targetPort","value":80}]'

# --- 5  NetworkPolicy
k -n $NS describe networkpolicy allow-frontend-to-backend
k -n $NS patch networkpolicy allow-frontend-to-backend --type=json \
  -p='[{"op":"replace","path":"/spec/ingress/0/from/0/podSelector/matchLabels/app","value":"frontend"}]'
k -n $NS exec deploy/frontend -- curl -s --max-time 3 -o /dev/null -w '%{http_code}\n' http://backend

# --- 6  Ingress
k -n $NS get ingress tienda -o yaml | grep -A4 backend
k -n $NS patch ingress tienda --type=json \
  -p='[{"op":"replace","path":"/spec/rules/0/http/paths/0/backend/service/name","value":"frontend"}]'
#   OJO: comprobar el índice del path. Si /api está primero, el índice a corregir es otro.
```

## Validación final

```bash
cd CLASE-06/RECURSOS/SCRIPTS && ./validate-lab.sh final
curl -sk -o /dev/null -w '%{http_code}\n' https://tienda.local:32443/     --resolve tienda.local:32443:<IP-NODO>
curl -sk -o /dev/null -w '%{http_code}\n' https://tienda.local:32443/api  --resolve tienda.local:32443:<IP-NODO>
k -n tienda get pvc          # los 3 PVC originales, con sus datos
```

## Resultado esperado

```
  [OK]    StatefulSet db con 3 replicas Ready
  [OK]    Service db es headless
  [OK]    3 PVC en Bound
  [OK]    Los PVC son ReadWriteOnce
  [OK]    backend 2/2 Ready
  [OK]    frontend 2/2 Ready
  [OK]    Selector del Service backend
  [OK]    targetPort del Service frontend
  [OK]    La politica default-deny sigue existiendo
  [OK]    Secret TLS de tipo kubernetes.io/tls
  [OK]    El Ingress apunta a un Service existente (frontend)
  [OK]    backend recibe la configuracion
  [OK]    backend recibe la credencial
  [OK]    frontend alcanza a backend
LABORATORIO INTEGRADOR SUPERADO
```

## Error frecuente

* **Borrar el namespace y reconstruir.** Está prohibido y es lo primero que se le ocurre a alguien atascado. Si ocurre, el laboratorio se da por no superado: en producción no existe esa opción.
* Borrar `default-deny` para "descartar la red". Igual de prohibido, y la falla 5 es precisamente una política mal escrita, no la política de denegación.
* Borrar los PVC del StatefulSet. Se pierden los datos, que es el único activo irrecuperable de toda la arquitectura.
* Corregir el `path` equivocado del Ingress por asumir el índice `0` sin mirar el YAML.
* Parar al conseguir el primer `200`: hay dos paths, `/` y `/api`, y ambos deben responder.
* No documentar. La tabla de diagnóstico es la mitad de la nota.

## CKA Tip — cierre del curso

```bash
# Los cinco comandos que resuelven la mayoría de los incidentes reales
k -n <ns> get all,pvc,ingress,networkpolicy
k -n <ns> get events --sort-by=.lastTimestamp | tail -30
k -n <ns> describe pod <p> | sed -n '/Events/,$p'
k -n <ns> get endpointslices
k logs <p> --previous
```

**El método vale más que los comandos.** Acota la capa antes de tocar nada, corrige una cosa cada vez, y valida antes de seguir. Es lo mismo en el examen y a las tres de la mañana en producción.
