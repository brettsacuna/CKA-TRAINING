# LAB 15.1 — Desplegar GRATITUD de extremo a extremo

## Nivel

Integrador — solo especificación.

## Duración

60 minutos.

## Objetivo

A partir de la especificación, dejar **GRATITUD completo** funcionando: las seis
capas, empaquetadas como un chart de Helm e instaladas en el cluster, con
`validar-gratitud.sh` en verde.

## Competencias

Todas las del track (S9–S14) aplicadas a la vez sobre una arquitectura real.

## Estado inicial

* Cluster con **Ingress Controller** (Traefik), **metrics-server** y un **CNI con NetworkPolicy**.
* `helm` v3, `kubectl`, `openssl`.
* Lee primero [`../RECURSOS/ESPECIFICACION-INTEGRADOR.md`](../RECURSOS/ESPECIFICACION-INTEGRADOR.md).

## Requerimientos

### Parte A — Preparación

1. Crea el namespace y etiquétalo para Pod Security:
   ```bash
   kubectl create ns gratitud
   kubectl label ns gratitud \
     pod-security.kubernetes.io/enforce=restricted \
     pod-security.kubernetes.io/warn=restricted
   ```
2. Crea el Secret TLS `gratitud-tls` para `gratitud.example.com` (con `openssl` o el script `gen-tls-secret.sh` de la Sesión 10, `NS=gratitud`).
3. Si vas a usar un PV estático para el PVC, créalo (`storageClassName: manual`, 1Gi, RWO).

### Parte B — El chart

4. Revisa el chart de referencia [`../RECURSOS/CHART/gratitud/`](../RECURSOS/CHART/gratitud/). Debe cubrir las seis capas:
   * `workloads.yaml` — Deployments + Services de `portal`, `api`, `cache` + `db-externa` (ExternalName).
   * `config.yaml` — ConfigMap `gratitud-config` + Secrets `gratitud-db` y `gratitud-tokens`.
   * `pvc.yaml` — PVC `gratitud-uploads`.
   * `ingress.yaml` — Ingress `gratitud` con `tls`.
   * `rbac.yaml` — SA + Role + RoleBinding `gratitud-deployer`.
   * `networkpolicy.yaml` — `default-deny`, `allow-dns` y las cadenas.
   * `_helpers.tpl` — contenedor común (sondas, recursos, `securityContext` restricted, volúmenes `emptyDir`).
5. Verifica **sin aplicar nada**:
   ```bash
   helm lint ../RECURSOS/CHART/gratitud
   helm template gratitud ../RECURSOS/CHART/gratitud -n gratitud | less
   helm template gratitud ../RECURSOS/CHART/gratitud -n gratitud \
     -f ../RECURSOS/CHART/gratitud/values-examen.yaml | grep -c 'kind:'
   ```

### Parte C — Instalar

6. Instala GRATITUD:
   ```bash
   helm install gratitud ../RECURSOS/CHART/gratitud -n gratitud \
     -f ../RECURSOS/CHART/gratitud/values-examen.yaml --wait --timeout 3m
   ```
7. Comprueba que todo levanta:
   ```bash
   kubectl -n gratitud get deploy,svc,ingress,pvc,networkpolicy,sa,role,rolebinding
   kubectl -n gratitud get pod -o wide
   ```

### Parte D — Ajustar hasta pasar la validación

8. Ejecuta la validación de extremo a extremo:
   ```bash
   cd ../SCRIPTS && ./validar-gratitud.sh
   ```
9. Corrige lo que quede en `[FALLA]` (un `storageClassName` que no enlaza, el `ingressClassName` real de tu cluster, el CNI…) editando **`values`** y haciendo `helm upgrade`, no `kubectl` a mano.
10. Prueba externa manual:
    ```bash
    IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
    NP=$(kubectl -n <ns-ingress> get svc <traefik> -o jsonpath='{.spec.ports[?(@.name=="websecure")].nodePort}')
    curl -sk -o /dev/null -w '%{http_code}\n' --resolve gratitud.example.com:$NP:$IP https://gratitud.example.com:$NP/api
    curl -skv --resolve gratitud.example.com:$NP:$IP https://gratitud.example.com:$NP/ 2>&1 | grep -E 'subject:|issuer:'
    ```

## Restricciones

* Todo lo que cambie entre entornos va en `values`, no en las plantillas.
* No uses `cluster-admin` para nada.
* `helm lint` y `helm template` deben pasar antes de cualquier `helm install`.

## Validación

```bash
cd CLASE-15/RECURSOS/SCRIPTS && ./validar-gratitud.sh
# Todas las líneas [OK] · "INTEGRADOR SUPERADO"
```

## Resultado esperado

Todas las comprobaciones de `validar-gratitud.sh` en `[OK]`:

* `portal` 2/2, `api` 2/2, `cache` 1/1; Services con endpoints en el 8080; `db-externa` ExternalName.
* Ingress con `ADDRESS` y Secret TLS válido; HTTPS externo `200` con tu certificado.
* ConfigMap + 2 Secrets inyectados en la API; PVC `Bound`; el fichero de `uploads` persiste tras borrar el Pod.
* `kubectl top pod` con cifras; `kubectl logs` de los tres tiers con salida.
* `gratitud-deployer` puede `update deployments` pero **no** `get secrets`; `default-deny` + cadenas de NetworkPolicy; namespace `enforce=restricted`.
* Release de Helm `gratitud` desplegada.

## Criterios de éxito

- [ ] Las seis capas funcionan **a la vez**, verificadas de extremo a extremo.
- [ ] `helm lint`/`template` pasan; el despliegue es reproducible con `helm upgrade`.
- [ ] HTTPS externo devuelve `200` con el certificado propio.
- [ ] Los datos de `uploads` persisten a la recreación del Pod.
- [ ] La ServiceAccount de despliegue tiene el mínimo privilegio.
- [ ] `./validar-gratitud.sh` termina con `INTEGRADOR SUPERADO`.
