# LAB 4.1 — Rolling Update y Rollback

## Nivel

Básico.

## Duración

24 minutos.

## Objetivo

Actualizar una aplicación sin cortar el servicio, generar varias revisiones, desplegar deliberadamente una versión rota, detectarla y revertirla.

## Competencias

* `kubectl set image`, `rollout status`, `rollout history`, `rollout undo`.
* Registrar la causa del cambio con la anotación `kubernetes.io/change-cause`.
* Interpretar el ReplicaSet nuevo y el antiguo durante un rollout.
* Detectar un rollout atascado.

## Escenario

La aplicación `versioning` está en producción. Vas a llevarla por tres versiones, meter la pata a propósito en la cuarta y recuperarte sin caída de servicio.

## Estado inicial

* Namespace de trabajo: **`c4-basico`**.
* Sin recursos previos.

## Requerimientos

1. Crea el namespace `c4-basico` y fíjalo en tu contexto.
2. Crea un Deployment **`nginx-deployment`** con **3 réplicas** de **`nginx:1.25-alpine`**, label `app: nginx`, puerto de contenedor 80.
3. Comprueba `rollout status` y `rollout history`. **¿Cuántas revisiones hay?**
4. Actualiza la imagen a **`nginx:1.26-alpine`** y registra la causa del cambio con la anotación adecuada (recuerda: `--record` ya no existe).
5. Sigue el rollout con `rollout status` y observa simultáneamente `kubectl get rs -w` en otra terminal. Anota cuántos ReplicaSets hay y cuántos Pods tiene cada uno durante la transición.
6. Repite con **`nginx:1.27-alpine`**, también con su causa de cambio.
7. Muestra `rollout history` y luego el detalle de la **revisión 2** y de la **revisión 3**.
8. Averigua cuáles son los valores por defecto de `maxSurge` y `maxUnavailable` en tu Deployment y qué significan con 3 réplicas.
9. **Despliega una versión rota**: cambia la imagen a **`nginx:1.99-inexistente`**.
10. Observa qué ocurre. Responde:
    * ¿Cuántas réplicas siguen sirviendo la versión buena?
    * ¿Por qué el rollout **no** tira las 3 réplicas viejas?
    * ¿Qué mensaje da `rollout status` y por qué no termina nunca?
11. Haz **rollback a la revisión anterior**.
12. Ahora haz un rollback dirigido **a la revisión 1** (la de `nginx:1.25-alpine`).
13. Muestra el historial final y explica por qué el número de revisión sigue creciendo aunque estés volviendo hacia atrás.
14. Configura `revisionHistoryLimit: 3` en el Deployment y explica su efecto.

## Restricciones

* No elimines ni recrees el Deployment en ningún momento.
* No uses `kubectl edit` para cambiar la imagen: usa `set image`.
* El servicio no debe quedarse con 0 réplicas disponibles en ningún momento.

## Validación

```bash
kubectl -n c4-basico rollout status deploy/nginx-deployment
kubectl -n c4-basico rollout history deploy/nginx-deployment
kubectl -n c4-basico rollout history deploy/nginx-deployment --revision=2
kubectl -n c4-basico get rs -o wide
kubectl -n c4-basico get deploy nginx-deployment \
  -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
kubectl -n c4-basico get deploy nginx-deployment \
  -o jsonpath='{.spec.strategy}{"\n"}'
```

## Resultado esperado

* Historial con al menos 5 revisiones y `CHANGE-CAUSE` legible en las que anotaste.
* Durante cada rollout conviven **dos ReplicaSets**: el nuevo sube mientras el viejo baja.
* Con la imagen inexistente: el ReplicaSet nuevo crea 1 Pod que queda en `ImagePullBackOff`, **2 réplicas de la versión buena siguen sirviendo**, y `rollout status` se queda esperando.
* Tras el rollback final, la imagen es `nginx:1.25-alpine` y las 3 réplicas están `Running`.

## Criterios de éxito

- [ ] Deployment con 3 réplicas creado.
- [ ] Al menos 3 actualizaciones de imagen ejecutadas con `set image`.
- [ ] `CHANGE-CAUSE` visible en el historial (sin usar `--record`).
- [ ] Observé la convivencia de dos ReplicaSets durante el rollout.
- [ ] Sé los valores por defecto de `maxSurge` y `maxUnavailable` y qué implican.
- [ ] Desplegué una versión rota y expliqué por qué no cayó el servicio.
- [ ] Ejecuté `rollout undo` y `rollout undo --to-revision=1`.
- [ ] Expliqué por qué el número de revisión sigue creciendo.
- [ ] Configuré `revisionHistoryLimit` y sé qué hace.
