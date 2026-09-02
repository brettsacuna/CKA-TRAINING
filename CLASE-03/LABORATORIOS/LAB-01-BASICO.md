# LAB 3.1 — Deployment, ReplicaSet y self-healing

## Nivel

Básico.

## Duración

22 minutos.

## Objetivo

Ver con los propios ojos la cadena `Deployment -> ReplicaSet -> Pod` y comprobar quién repara qué cuando algo se rompe.

## Competencias

* Crear Deployments imperativa y declarativamente.
* Leer `ownerReferences`.
* Escalar un Deployment.
* Demostrar el self-healing.
* Distinguir qué recrea un ReplicaSet y qué no.

## Escenario

Antes de administrar aplicaciones con estado, hay que entender exactamente qué garantiza un Deployment y qué no. Este laboratorio lo demuestra empíricamente en lugar de contarlo.

## Estado inicial

* Namespace de trabajo: **`c3-basico`**.
* Sin recursos previos.

## Requerimientos

1. Crea el namespace `c3-basico` y fíjalo en tu contexto.
2. Crea un Deployment **`front`** con **3 réplicas** de `nginx:1.27-alpine`.
3. Lista, en un solo comando, el Deployment, su ReplicaSet y sus Pods.
4. Averigua, leyendo el objeto, **quién es el propietario** de:
   * uno de los Pods,
   * el ReplicaSet.
   (Pista: `ownerReferences`.)
5. Comprueba cuál es el `selector.matchLabels` del Deployment y qué labels llevan los Pods.
6. Borra **un** Pod. Observa qué ocurre y en cuántos segundos. Anota qué controlador reaccionó.
7. Escala `front` a **5 réplicas** con un comando imperativo. Comprueba si se creó un ReplicaSet nuevo o se reutilizó el existente. Explica por qué.
8. Crea un Pod suelto llamado **`huerfano`** con el label `app=front` en el mismo namespace. Observa qué le hace el ReplicaSet y **explica el resultado**.
9. Vuelve a escalar `front` a 3 réplicas.
10. Crea un **ReplicaSet** llamado **`rs-legacy`** directamente (no un Deployment) con 2 réplicas de `nginx:1.27-alpine` y label `app=legacy`. Cambia su imagen a `nginx:1.28-alpine` y observa si los Pods existentes se actualizan. Explica la diferencia con un Deployment.
11. Elimina `huerfano` y `rs-legacy`.

## Restricciones

* Trabaja exclusivamente en `c3-basico`.
* En el paso 7 usa un comando imperativo, no `edit` ni `apply`.
* No borres el Deployment `front` hasta el final.

## Validación

```bash
kubectl -n c3-basico get deploy,rs,pods -o wide
kubectl -n c3-basico get pod <pod> -o jsonpath='{.metadata.ownerReferences}{"\n"}'
kubectl -n c3-basico get rs -o jsonpath='{.items[0].metadata.ownerReferences}{"\n"}'
kubectl -n c3-basico get deploy front -o jsonpath='{.spec.selector}{"\n"}'
kubectl -n c3-basico get events --sort-by=.lastTimestamp | tail
```

## Resultado esperado

* Un Deployment `front`, un ReplicaSet `front-<hash>` y 3 Pods `front-<hash>-<sufijo>`.
* El `ownerReference` del Pod apunta al ReplicaSet; el del ReplicaSet, al Deployment.
* Al borrar un Pod, aparece uno nuevo en segundos, creado por el **ReplicaSet**.
* Al escalar a 5, **no** se crea un ReplicaSet nuevo: solo cambia `replicas`.
* El Pod `huerfano` es **adoptado** o **eliminado** por el ReplicaSet, porque coincide con su selector y hace que sobre un Pod.
* En `rs-legacy`, cambiar la imagen **no** actualiza los Pods existentes.

## Criterios de éxito

- [ ] `front` con 3 réplicas `Running`.
- [ ] Identifiqué los `ownerReferences` de Pod y ReplicaSet.
- [ ] Documenté qué controlador recrea el Pod borrado.
- [ ] Escalé a 5 con un comando imperativo y expliqué por qué no hubo ReplicaSet nuevo.
- [ ] Expliqué qué le pasó al Pod `huerfano` y por qué.
- [ ] Demostré que un ReplicaSet no hace rolling update.
- [ ] Namespace limpio salvo `front` con 3 réplicas.
