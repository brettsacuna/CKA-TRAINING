# LAB 12.2 — Diagnosticar cuatro Pods rotos

## Nivel

Intermedio.

## Duración

30 minutos.

## Objetivo

Aplicar el kit de troubleshooting a un namespace con cuatro Pods en estados
distintos —`ImagePullBackOff`, `CrashLoopBackOff`, `OOMKilled` y `Pending`—,
identificar la causa de cada uno y repararlos.

## Competencias

* Clasificar Pods por estado y `RESTARTS`.
* Usar `describe`, `logs --previous`, `top` y `get events` para llegar a la causa raíz.
* Corregir un tag de imagen, un comando, un `limits.memory` y una condición de scheduling.

## Escenario

Te pasan un namespace con cuatro despliegues y "nada funciona". Tu trabajo es
diagnosticar cada uno con datos, no a ojo, y dejar constancia de síntoma, comando
y causa.

## Estado inicial

```bash
kubectl apply -f ../RECURSOS/YAML/03-diagnostico-pods.yaml
kubectl -n c12-diag get pods
```

Crea el namespace `c12-diag` con:

| Deployment | Estado esperado |
|---|---|
| `p-image` | `ImagePullBackOff` |
| `p-crash` | `CrashLoopBackOff` |
| `p-oom` | `OOMKilled` (en `CrashLoopBackOff` con `Last State: OOMKilled`) |
| `p-pending` | `Pending` |

## Requerimientos

1. Clasifica los cuatro:
   ```bash
   kubectl -n c12-diag get pods -o wide
   kubectl -n c12-diag get events --sort-by=.lastTimestamp | tail -20
   ```
2. Para cada uno, llega a la causa raíz **con el comando adecuado** y anótala:
   * `p-image` → `describe pod` (sección `Events`): ¿qué dice del *pull*?
   * `p-crash` → `logs --previous`: ¿qué imprime antes de morir? ¿con qué código sale?
   * `p-oom` → `describe pod` (`Last State`) y `kubectl top pod`: ¿qué `Reason`? ¿qué `limits.memory` tiene?
   * `p-pending` → `describe pod` (`Events`): ¿por qué el scheduler no lo coloca?
3. Corrige cada Deployment **in situ**:
   * `p-image`: arregla el **tag** de la imagen.
   * `p-crash`: arregla el **comando** para que el proceso no salga con error.
   * `p-oom`: sube `limits.memory` a un valor razonable (p. ej. `128Mi`).
   * `p-pending`: quita o corrige la condición que lo bloquea (`nodeSelector`/`requests` imposible).
4. Comprueba que los cuatro quedan `Running` y estables:
   ```bash
   kubectl -n c12-diag get pods -w
   kubectl -n c12-diag top pod
   ```
5. Escribe una tabla: Pod · síntoma · comando que lo reveló · causa raíz · corrección.

## Restricciones

* No borres y recrees un Deployment "desde cero": corrige el campo que falla.
* No subas `limits.memory` a un valor absurdo para `p-oom`; ajústalo a lo que consume.
* `kubectl top` requiere metrics-server; si no está, instálalo con `../RECURSOS/SCRIPTS/install-metrics-server.sh`.

## Validación

```bash
kubectl -n c12-diag get pods
kubectl -n c12-diag get deploy -o custom-columns=NAME:.metadata.name,READY:.status.readyReplicas
kubectl -n c12-diag top pod
```

## Resultado esperado

* Los cuatro Deployments con `READY 1/1` y `RESTARTS` estable.
* `p-image` con un tag de imagen válido.
* `p-crash` con un comando que se mantiene vivo.
* `p-oom` con un `limits.memory` acorde al consumo real.
* `p-pending` programado en un nodo.

## Criterios de éxito

- [ ] Clasifiqué los cuatro Pods por estado antes de tocar nada.
- [ ] Usé `logs --previous` para `p-crash` (el actual no había escrito nada).
- [ ] Identifiqué `OOMKilled` en `Last State` de `p-oom` y lo confirmé con `top`.
- [ ] Leí en `describe` por qué `p-pending` no se programa.
- [ ] Los cuatro quedan `Running` corrigiendo el campo, no recreando.
- [ ] Documenté síntoma, comando y causa de cada uno.
