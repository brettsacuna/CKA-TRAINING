# SOLUCIÓN — LAB 3.1 · Deployment, ReplicaSet y self-healing

> **MATERIAL DEL INSTRUCTOR.**

## Diagnóstico

Laboratorio demostrativo. El momento clave es el paso 8: el Pod `huerfano` lleva el label del selector del ReplicaSet, así que el ReplicaSet lo **cuenta como suyo**. Con 5 deseados y 6 contados, elimina uno. La mayoría de los alumnos espera que "no pase nada".

## Razonamiento técnico resumido

```
Deployment  --gestiona-->  ReplicaSet  --gestiona-->  Pod
     (versiones)                (número de réplicas)
```

* El **Deployment** gestiona *versiones*: cada cambio en `spec.template` crea un ReplicaSet nuevo.
* El **ReplicaSet** gestiona *cantidad*: solo cuenta Pods que casen con su selector y ajusta.
* `kubectl scale` cambia `spec.replicas`, no `spec.template`: **no** genera un ReplicaSet nuevo.
* Un ReplicaSet **no hace rolling update**: cambiar su imagen solo afecta a los Pods futuros.

## Procedimiento

```bash
k create ns c3-basico && k config set-context --current --namespace=c3-basico

# 2
k create deployment front --image=nginx:1.27-alpine --replicas=3

# 3
k get deploy,rs,pods -o wide

# 4
POD=$(k get pods -l app=front -o name | head -1)
k get $POD -o jsonpath='{.metadata.ownerReferences}{"\n"}'      # kind: ReplicaSet
k get rs -o jsonpath='{.items[0].metadata.ownerReferences}{"\n"}' # kind: Deployment

# 5
k get deploy front -o jsonpath='{.spec.selector}{"\n"}'          # matchLabels: app=front
k get pods --show-labels

# 6
k delete $POD
k get pods -w                 # aparece uno nuevo en 1-3 s
k get events --sort-by=.lastTimestamp | tail -5
#   SuccessfulCreate  replicaset/front-xxxx  Created pod: front-xxxx-yyyy

# 7
k scale deployment front --replicas=5
k get rs                      # SIGUE HABIENDO UN SOLO ReplicaSet

# 8
k run huerfano --image=nginx:1.27-alpine -l app=front
k get pods -l app=front       # el ReplicaSet elimina un Pod para volver a 5

# 9
k scale deployment front --replicas=3

# 10
k create -f - <<'YAML'
apiVersion: apps/v1
kind: ReplicaSet
metadata: {name: rs-legacy, namespace: c3-basico}
spec:
  replicas: 2
  selector: {matchLabels: {app: legacy}}
  template:
    metadata: {labels: {app: legacy}}
    spec:
      containers: [{name: nginx, image: "nginx:1.27-alpine"}]
YAML
k set image rs/rs-legacy nginx=nginx:1.28-alpine
k get pods -l app=legacy -o jsonpath='{range .items[*]}{.spec.containers[0].image}{"\n"}{end}'
#   -> siguen en 1.27: los Pods existentes NO se actualizan

# 11
k delete pod huerfano --ignore-not-found
k delete rs rs-legacy
```

## Validación

```bash
k get deploy,rs,pods
k get deploy front -o jsonpath='{.status.readyReplicas}{"\n"}'   # 3
```

## Resultado esperado

```
NAME                     READY   UP-TO-DATE   AVAILABLE
deployment.apps/front    3/3     3            3

NAME                                DESIRED   CURRENT   READY
replicaset.apps/front-6c4d9b7f8d    3         3         3
```

## Error frecuente

* Creer que `kubectl scale` crea una revisión nueva. No: la revisión depende de `spec.template`.
* No entender el paso 8 y concluir que "Kubernetes borró mi Pod sin motivo". El motivo es el selector.
* Intentar cambiar `spec.selector` de un Deployment existente: es **inmutable** desde `apps/v1`. Si hay que cambiarlo, se recrea el Deployment.
* Usar `kubectl get pods` sin `-l` y perderse entre Pods de distintos laboratorios.

## CKA Tip

```bash
# Ver la jerarquía completa de un tirón
k get deploy,rs,pods -o wide

# ¿Quién es el dueño de este Pod?
k get pod <pod> -o jsonpath='{.metadata.ownerReferences[0].kind}/{.metadata.ownerReferences[0].name}{"\n"}'

# Deployment imperativo con réplicas en un solo comando
k create deployment <n> --image=<img> --replicas=3
```
