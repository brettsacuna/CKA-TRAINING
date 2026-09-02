# SOLUCIÓN — LAB 15.4 · Plantilla de respuestas del examen teórico

> **MATERIAL DEL INSTRUCTOR.** Aprobado: ≥ 16 / 20.

| # | Causa más probable | Comando de confirmación | Capa · Sesión |
|---|---|---|---|
| 1 | El `selector` del Service no coincide con los labels de los Pods (o los Pods no están `Ready`). | `kubectl get pod --show-labels` + `kubectl get svc <s> -o jsonpath='{.spec.selector}'` | Services · S9 |
| 2 | `targetPort` equivocado, o una NetworkPolicy bloquea el tráfico al Pod. | `kubectl get svc <s> -o yaml` · `kubectl get networkpolicy` | Services / Seguridad · S9 / S13 |
| 3 | No hay integración de nube (ni MetalLB): el `LoadBalancer` no se aprovisiona. Usa `NodePort`. | `kubectl describe svc <s>` (sin eventos de aprovisionamiento) | Services · S9 |
| 4 | Llamada entre namespaces con el nombre corto; falta el sufijo del namespace. | `kubectl exec ... -- cat /etc/resolv.conf` (línea `search`) | Services / DNS · S9 |
| 5 | `ingressClassName` no coincide con ninguna `IngressClass` registrada. | `kubectl get ingressclass` · `kubectl describe ingress <i>` | Ingress · S10 |
| 6 | `pathType: Exact` donde hacía falta `Prefix` (o falta la reescritura de path). | `kubectl get ingress <i> -o yaml` | Ingress · S10 |
| 7 | El `secretName` del bloque `tls` no existe o el host no coincide (SNI): se sirve el cert por defecto. | `kubectl get secret -n <ns-ingress>` · `curl -kv ... \| grep -E 'subject:\|issuer:'` | Ingress / TLS · S10 |
| 8 | Una clave referenciada en `secretKeyRef` no existe en el Secret. | `kubectl describe pod <p>` (Events) · `kubectl get secret <s> -o jsonpath='{.data}'` | Config · S11 |
| 9 | La variable se inyectó por `env`/`envFrom`: no se actualiza sin recrear el Pod. | `kubectl rollout restart deploy/<d>` | Config · S11 |
| 10 | Un montaje con `subPath` no recibe actualizaciones (queda congelado al arranque). | `kubectl get deploy <d> -o yaml \| grep subPath` | Config · S11 |
| 11 | `storageClassName` o `accessModes` no encajan con ningún PV, o no hay provisioner. | `kubectl describe pvc <p>` · `kubectl get sc` | Storage · S11 |
| 12 | `reclaimPolicy: Retain` conserva los datos pero deja el PV `Released` hasta quitar el `claimRef` a mano. | `kubectl patch pv <pv> --type=json -p='[{"op":"remove","path":"/spec/claimRef"}]'` | Storage · S11 |
| 13 | `livenessProbe` demasiado agresiva sin `startupProbe`: mata el contenedor durante el arranque. | `kubectl logs <p> --previous` · `kubectl describe pod <p>` | Observabilidad · S12 |
| 14 | `readinessProbe` que no pasa (puerto o path): el Pod no entra en el `EndpointSlice`. | `kubectl describe pod <p>` · `kubectl get endpoints <s>` | Observabilidad · S12 |
| 15 | El contenedor superó `limits.memory` y el kernel lo mató. | `kubectl describe pod <p>` (Last State) · `kubectl top pod` | Observabilidad · S12 |
| 16 | La aplicación escribe sus logs en un fichero del contenedor, no en `stdout`/`stderr`. | `kubectl exec <p> -- ls -l /var/log` | Observabilidad · S12 |
| 17 | `metrics-server` no está instalado o no está `Ready`. | `kubectl -n kube-system get deploy metrics-server` | Observabilidad · S12 |
| 18 | RBAC: falta el verbo, el recurso o el binding para esa ServiceAccount. | `kubectl auth can-i --list --as=system:serviceaccount:<ns>:<sa> -n <ns>` | Seguridad · S13 |
| 19 | El `default deny` de `egress` también bloquea el puerto 53: hay que permitir el DNS explícitamente. | `kubectl describe networkpolicy <np>` | Seguridad · S13 |
| 20 | El `securityContext` de los Pods no cumple el nivel `enforce` del namespace. | `kubectl describe rs -l <label>` · `kubectl get ns <ns> --show-labels` | Seguridad · S13 |

## Corrección

* **≥ 16 / 20**: aprobado. Repasar las sesiones de los casos fallados.
* **< 16 / 20**: repetir el track de las capas con más fallos antes del examen práctico.

Se admite como correcta cualquier respuesta equivalente (por ejemplo, para el
caso 2, `kubectl get endpointslices` en lugar de `kubectl get svc -o yaml`)
siempre que identifique la **capa** correcta y un comando que **confirme** la
causa, no solo que muestre el síntoma.
