# SOLUCIÓN — LAB 4.1 · Rolling Update y Rollback

> **MATERIAL DEL INSTRUCTOR.**

## Diagnóstico

El paso 9 es el corazón del laboratorio: con `readinessProbe` y los valores por defecto de la estrategia, un despliegue roto **no tumba el servicio**. El rollout se queda parado y sigue habiendo réplicas buenas sirviendo. Muchos alumnos creen que un mal deploy borra todo.

## Razonamiento técnico resumido

* Cada cambio en `spec.template` crea un ReplicaSet nuevo. Los antiguos se conservan (hasta `revisionHistoryLimit`) y son lo que hace posible el rollback.
* `maxSurge: 25%` con 3 réplicas → 1 Pod extra permitido (redondeo hacia arriba).
  `maxUnavailable: 25%` con 3 réplicas → 0 Pods indisponibles (redondeo hacia abajo). Por eso el rollout es tan conservador.
* `rollout undo` **no borra revisiones**: crea una revisión nueva con el contenido de la antigua. Por eso el contador sigue subiendo.
* `--record` fue eliminado de kubectl. La causa del cambio se escribe con la anotación `kubernetes.io/change-cause`.

## Procedimiento

```bash
k create ns c4-basico && k config set-context --current --namespace=c4-basico

# 2
k apply -f ../RECURSOS/YAML/01-deployment-versioning.yaml

# 3
k rollout status deploy/nginx-deployment
k rollout history deploy/nginx-deployment      # REVISION 1

# 4
k set image deploy/nginx-deployment nginx=nginx:1.26-alpine
k annotate deploy/nginx-deployment \
  kubernetes.io/change-cause="Actualizacion a nginx 1.26" --overwrite

# 5  (en otra terminal)
k get rs -w
k rollout status deploy/nginx-deployment

# 6
k set image deploy/nginx-deployment nginx=nginx:1.27-alpine
k annotate deploy/nginx-deployment \
  kubernetes.io/change-cause="Actualizacion a nginx 1.27" --overwrite

# 7
k rollout history deploy/nginx-deployment
k rollout history deploy/nginx-deployment --revision=2
k rollout history deploy/nginx-deployment --revision=3

# 8
k get deploy nginx-deployment -o jsonpath='{.spec.strategy}{"\n"}'

# 9
k set image deploy/nginx-deployment nginx=nginx:1.99-inexistente
k annotate deploy/nginx-deployment \
  kubernetes.io/change-cause="PRUEBA: imagen inexistente" --overwrite

# 10
k get pods
k rollout status deploy/nginx-deployment --timeout=30s
k describe pod <pod-nuevo> | sed -n '/Events/,$p'
```

**Respuestas del paso 10:**
* Siguen sirviendo **3** réplicas de la versión buena (con `maxUnavailable: 25%` → 0, el controlador no puede retirar ninguna vieja hasta que una nueva esté `Ready`).
* El Pod nuevo nunca pasa a `Ready` porque la imagen no existe (`ImagePullBackOff`), así que el rollout se **bloquea** en lugar de continuar. Esto es exactamente lo que debe pasar.
* `rollout status` muestra `Waiting for deployment "nginx-deployment" rollout to finish: 1 out of 3 new replicas have been updated...` y no termina.

```bash
# 11
k rollout undo deploy/nginx-deployment
k rollout status deploy/nginx-deployment

# 12
k rollout undo deploy/nginx-deployment --to-revision=1
k get deploy nginx-deployment -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'

# 13
k rollout history deploy/nginx-deployment

# 14
k patch deploy nginx-deployment -p '{"spec":{"revisionHistoryLimit":3}}'
k get rs        # los ReplicaSets antiguos sobrantes se eliminan
```

**13 —** El historial es un registro cronológico de *estados aplicados*, no una pila. Volver atrás es aplicar un estado nuevo que casualmente coincide con uno viejo.
**14 —** `revisionHistoryLimit` limita cuántos ReplicaSets antiguos (con 0 réplicas) se conservan. Ponerlo a 0 hace imposible el rollback.

## Validación

```bash
k rollout history deploy/nginx-deployment
k get deploy nginx-deployment -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'  # nginx:1.25-alpine
k get pods                                          # 3/3 Running
```

## Resultado esperado

```
deployment.apps/nginx-deployment
REVISION  CHANGE-CAUSE
2         Actualizacion a nginx 1.26
3         Actualizacion a nginx 1.27
4         PRUEBA: imagen inexistente
5         Actualizacion a nginx 1.27
6         Despliegue inicial nginx 1.25
```

## Error frecuente

* Usar `--record`: ya no existe; kubectl lo ignora o da error según versión.
* Anotar el Deployment **antes** de `set image`: la anotación se asocia a la revisión que se está creando, así que hay que anotarla junto al cambio (o inmediatamente después).
* Pensar que `rollout undo` borra revisiones.
* Poner `revisionHistoryLimit: 0` y quedarse sin posibilidad de rollback.
* Omitir la `readinessProbe` y luego no entender por qué un despliegue roto sí tumbó el servicio: sin readiness, un Pod que arranca se considera listo aunque la aplicación no responda.

## CKA Tip

```bash
k set image deploy/<d> <contenedor>=<imagen>:<tag>
k annotate deploy/<d> kubernetes.io/change-cause="motivo" --overwrite
k rollout status  deploy/<d>
k rollout history deploy/<d> --revision=N
k rollout undo    deploy/<d> --to-revision=N
k rollout restart deploy/<d>          # recrea Pods sin cambiar la imagen
k rollout pause|resume deploy/<d>     # agrupar varios cambios en una sola revisión
```

**El nombre del contenedor no es el del Deployment.** `k get deploy <d> -o jsonpath='{.spec.template.spec.containers[*].name}'` antes de `set image`.
