# SOLUCIÓN — LAB 12.2 · Diagnosticar cuatro Pods rotos

> **MATERIAL DEL INSTRUCTOR.**

## Tabla de diagnóstico

| Pod | Síntoma | Comando que lo revela | Causa raíz | Corrección |
|---|---|---|---|---|
| `p-image` | `ImagePullBackOff` | `describe pod` → *Failed to pull image "nginx:1.27-alpime"* | Tag inexistente (`alpime`) | Tag → `nginx:1.27-alpine` |
| `p-crash` | `CrashLoopBackOff` | `logs --previous` → *ERROR: config no encontrada* + `exit 1` | El comando termina con código ≠ 0 | Comando que se mantiene vivo |
| `p-oom` | `CrashLoopBackOff`, `Last State: OOMKilled` | `describe pod` (Last State) · `top pod` | `limits.memory: 8Mi` < lo que necesita nginx | Subir a `128Mi` |
| `p-pending` | `Pending` | `describe pod` → *0/N nodes available: Insufficient cpu* | `requests.cpu: "40"` (40 núcleos) | `requests.cpu: 100m` |

## Procedimiento

```bash
k apply -f ../RECURSOS/YAML/03-diagnostico-pods.yaml
k -n c12-diag get pods -o wide
k -n c12-diag get events --sort-by=.lastTimestamp | tail -20

# p-image
k -n c12-diag describe pod -l app=p-image | sed -n '/Events/,$p'
k -n c12-diag set image deploy/p-image c=nginx:1.27-alpine

# p-crash
k -n c12-diag logs -l app=p-crash --previous --tail=10
k -n c12-diag patch deploy p-crash --type=json -p='[{"op":"replace",
  "path":"/spec/template/spec/containers/0/command",
  "value":["sh","-c","echo arrancado; sleep infinity"]}]'

# p-oom
k -n c12-diag describe pod -l app=p-oom | grep -A4 'Last State'
k -n c12-diag top pod -l app=p-oom 2>/dev/null || echo "instala metrics-server"
k -n c12-diag patch deploy p-oom --type=json -p='[{"op":"replace",
  "path":"/spec/template/spec/containers/0/resources/limits/memory","value":"128Mi"},
  {"op":"replace","path":"/spec/template/spec/containers/0/resources/requests/memory","value":"32Mi"}]'

# p-pending
k -n c12-diag describe pod -l app=p-pending | sed -n '/Events/,$p'
k -n c12-diag patch deploy p-pending --type=json -p='[{"op":"replace",
  "path":"/spec/template/spec/containers/0/resources/requests/cpu","value":"100m"}]'

k -n c12-diag get pods -w
k -n c12-diag top pod
```

## Validación

```bash
k -n c12-diag get pods
k -n c12-diag get deploy -o custom-columns=NAME:.metadata.name,READY:.status.readyReplicas
```

## Resultado esperado

Los cuatro Deployments con `READY 1/1` y `RESTARTS` estable.

## Error frecuente

* Mirar `kubectl logs` (sin `--previous`) de `p-crash` y ver el arranque **actual**, que aún no ha escrito nada.
* Interpretar `OOMKilled` como "la app tiene un bug de memoria" sin comprobar antes el `limits.memory`.
* Subir el `limits.memory` de `p-oom` a `2Gi` "para que no vuelva a pasar": hay que ajustarlo al consumo real (`top`).
* Para `p-pending`, añadir un nodo o un `nodeSelector` en vez de corregir el `requests` imposible.
* Borrar y recrear el Deployment: se pierde la traza de qué estaba mal.

## CKA Tip

```bash
k get pod -A --field-selector=status.phase!=Running
k get events -A --sort-by=.lastTimestamp | tail -30
k describe pod <p> | sed -n '/Events/,$p'
k logs <p> --previous
k get pod <p> -o jsonpath='{.status.containerStatuses[0].lastState}{"\n"}'
```
