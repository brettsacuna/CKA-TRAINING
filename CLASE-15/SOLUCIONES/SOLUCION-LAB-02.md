# SOLUCIÓN — LAB 15.2 · Validación en tiempo real

> **MATERIAL DEL INSTRUCTOR.**

## Qué demuestra cada bloque de `validar-gratitud.sh`

| Bloque | Comprobación | Qué demuestra |
|---|---|---|
| Capa 1 | `readyReplicas` de portal/api/cache | Las sondas pasan y hay capacidad para el número de réplicas |
| Capa 1 | `endpointslices` con direcciones | El **selector** del Service cuadra con los labels de Pods `Ready` |
| Capa 1 | `targetPort` = 8080 | El Service reenvía al puerto donde escucha el contenedor |
| Capa 1 | `wget http://cache` desde `api` | Cadena `DNS → Service → EndpointSlice → Pod` y NetworkPolicy `api→cache` |
| Capa 1 | `db-externa` `ExternalName` | El servicio externo se modela como un Service más |
| Capa 2 | `ADDRESS` del Ingress | Un controlador adoptó el Ingress (`ingressClassName` correcto) |
| Capa 2 | tipo del Secret TLS | El `secretName` apunta a un `kubernetes.io/tls` real |
| Capa 3 | objetos de config existen | ConfigMap y ambos Secrets creados |
| Capa 3 | variables en la API | `envFrom` + `valueFrom` inyectan de verdad |
| Capa 3 | `PVC Bound` + persistencia | El PVC enlazó y los datos sobreviven al Pod |
| Capa 4 | `kubectl top` | metrics-server operativo (alimenta `top` y el HPA) |
| Capa 4 | `kubectl logs` con salida | La app loguea a stdout, no a un fichero |
| Capa 5 | `auth can-i --as` | RBAC de mínimo privilegio: `update deploy` sí, `get secrets` no |
| Capa 5 | nº de NetworkPolicies + `default-deny` | El tráfico está cerrado por defecto y solo se abre lo necesario |
| Capa 5 | etiqueta `enforce` | Pod Security aplica `restricted` en el namespace |
| Capa 6 | `helm status` | Todo se instaló como una release reproducible |

## Reproducir a mano (Parte B)

```bash
# selector -> EndpointSlice
k -n gratitud get endpointslices -l kubernetes.io/service-name=api
# -> si está vacío, el selector del Service no cuadra con los Pods

# conectividad de capa a capa
k -n gratitud exec deploy/api -- sh -c 'wget -qO- http://cache && echo " <- cache OK"'

# inyección de config
k -n gratitud exec deploy/api -- printenv | grep -E 'DB_PASSWORD|PARTNER_TOKEN|LOG_LEVEL'

# RBAC de mínimo privilegio
k auth can-i get secrets -n gratitud --as=system:serviceaccount:gratitud:gratitud-deployer   # no
```

## Provocar y detectar (Parte C)

```bash
k -n gratitud patch svc api --type=merge -p '{"spec":{"selector":{"tier":"api-x"}}}'
./validar-gratitud.sh
#   [FALLA] Service api sin endpoints
#   [FALLA] la API alcanza a cache por nombre     (colateral: portal->api sigue OK pero el test usa el Service)
k -n gratitud patch svc api --type=merge -p '{"spec":{"selector":{"app.kubernetes.io/instance":"gratitud","tier":"api"}}}'
./validar-gratitud.sh   # INTEGRADOR SUPERADO
```

## Error frecuente

* Provocar el fallo con `kubectl` y revertir con `helm upgrade` sin `-f values-examen.yaml`: se pierden overrides.
* Interpretar `[FALLA] la API alcanza a cache` como un problema de NetworkPolicy cuando el fallo real está en el selector del Service (capa 1).
* No revertir y arrastrar el fallo al examen práctico.

## CKA Tip

Un recorrido de validación es un diagnóstico al revés: **de dentro hacia fuera**,
un punto a la vez, y cada `[OK]` respaldado por un comando que sabes explicar.
