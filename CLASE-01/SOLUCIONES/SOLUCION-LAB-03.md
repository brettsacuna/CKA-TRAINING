# SOLUCIÓN — LAB 1.3 · Colocación de Pods

> **MATERIAL DEL INSTRUCTOR.**

## Diagnóstico

Laboratorio de construcción con dos puntos de fricción deliberados: la tercera réplica de `spread` **no puede** programarse (anti-affinity obligatoria con menos nodos que réplicas) y `filler` **debe** ser desalojado por `critical`. Ambos son eventos, no errores: el alumno debe leerlos, no "arreglarlos".

## Razonamiento técnico resumido

* `nodeSelector` es igualdad exacta sobre labels de nodo. `nodeAffinity` es lo mismo pero con operadores (`In`, `NotIn`, `Exists`, `Gt`, `Lt`) y con la variante **preferida**.
* Un **taint** repele; una **toleration** solo *permite* aterrizar, **no atrae**. Por eso `data-job` necesita toleration **y** `nodeSelector`: sin el selector podría irse a cualquier otro nodo.
* `podAntiAffinity` + `topologyKey: kubernetes.io/hostname` = "no dos de estos en el mismo host".
* Preemption: cuando un Pod de mayor prioridad no cabe, el scheduler busca víctimas de menor prioridad en un nodo donde, desalojándolas, el Pod sí quepa.

## Procedimiento

```bash
k create ns c1-avanzado
k config set-context --current --namespace=c1-avanzado

# R1
k label node cka-worker1 environment=production
k label node cka-worker2 environment=data
k taint node cka-worker2 team=data:NoSchedule

# R2
k run prod-app --image=nginx:1.27-alpine $do > prod-app.yaml   # añadir nodeSelector
k apply -f prod-app.yaml
k get pod prod-app -o wide
```

```yaml
spec:
  nodeSelector:
    environment: production
```

```bash
# R3
k apply -f - <<'YAML'
apiVersion: v1
kind: Pod
metadata: {name: data-job, namespace: c1-avanzado}
spec:
  nodeSelector: {environment: data}
  tolerations:
    - {key: team, operator: Equal, value: data, effect: NoSchedule}
  containers:
    - {name: busybox, image: "busybox:1.36", command: ["sleep","3600"]}
YAML
k get pod data-job -o wide
```

```bash
# R4
k apply -f ../RECURSOS/YAML/03-scheduling.yaml   # bloque affinity-app
k label node cka-worker1 disktype=ssd
k get pod affinity-app -o wide
```

**R4.9 —** El Pod se habría programado igual porque `preferredDuringScheduling...` solo **puntúa** nodos; no filtra. Si ningún nodo tiene `disktype=ssd`, todos suman 0 por esa regla y el scheduler elige por el resto de criterios. Solo la regla `required` puede dejar un Pod en `Pending`.

```bash
# R5
k apply -f ../RECURSOS/YAML/05-antiaffinity-deployment.yaml
k get pods -l app=spread -o wide          # 2 nodos distintos
k scale deploy spread --replicas=3
k get pods -l app=spread -o wide          # 1 Pending
k describe pod <pending> | sed -n '/Events/,$p'
```

Evento esperado:

```
Warning FailedScheduling ... 0/3 nodes are available:
  1 node(s) had untolerated taint {team: data},
  2 node(s) didn't match pod anti-affinity rules.
```

```bash
# R6
k apply -f ../RECURSOS/YAML/04-priorityclass.yaml
k get priorityclass

k apply -f - <<'YAML'
apiVersion: v1
kind: Pod
metadata: {name: filler, namespace: c1-avanzado}
spec:
  priorityClassName: low-priority
  nodeSelector: {environment: production}
  containers:
    - name: pause
      image: registry.k8s.io/pause:3.10
      resources: {requests: {cpu: "1500m"}}
YAML

k apply -f - <<'YAML'
apiVersion: v1
kind: Pod
metadata: {name: critical, namespace: c1-avanzado}
spec:
  priorityClassName: critical-priority
  nodeSelector: {environment: production}
  containers:
    - name: pause
      image: registry.k8s.io/pause:3.10
      resources: {requests: {cpu: "1500m"}}
YAML

k get pods -o wide -w
k get events --sort-by=.lastTimestamp | grep -i preempt
```

> Ajusta el `cpu` solicitado a la capacidad real del worker: debe caber **uno** de los dos Pods, no los dos. Comprueba con `k describe node cka-worker1 | grep -A5 Allocatable`.

## Validación

```bash
k get nodes -L environment,disktype
k describe nodes | grep -i -A1 taint
k get pods -o wide
k get priorityclass
k get events --sort-by=.lastTimestamp | grep -iE 'preempt|FailedScheduling'
```

## Resultado esperado

* `prod-app` y `affinity-app` en `cka-worker1`; `data-job` en `cka-worker2`; ningún otro Pod en `cka-worker2`.
* `spread`: 2 Running en nodos distintos, 1 Pending con `FailedScheduling`.
* Evento `Preempted by pod critical ...` y `filler` en `Pending`, `critical` en `Running`.

## Limpieza obligatoria

```bash
k taint node cka-worker2 team-
k label node cka-worker1 environment- disktype-
k label node cka-worker2 environment-
```

## Error frecuente

* **Dar toleration sin `nodeSelector`** y esperar que el Pod vaya al nodo tainted. La toleration no atrae: solo levanta el veto.
* Escribir `preferredDuringSchedulingIgnoredDuringExecution` como si fuera una lista de `nodeSelectorTerms`. Su estructura es distinta: lista de `{weight, preference}`.
* Poner `topologyKey` mal escrito (`kubernetes.io/host`): el scheduler no falla, simplemente la regla nunca agrupa nada.
* Olvidar retirar el taint al final y arrastrar Pods `Pending` inexplicables a la Clase 3.

## CKA Tip

```bash
# Taint / untaint (fíjate en el guion final)
k taint node <node> key=value:NoSchedule
k taint node <node> key-

# Ver labels de nodo como columnas
k get nodes -L environment,disktype

# Por qué está Pending: siempre los eventos primero
k describe pod <pod> | sed -n '/Events/,$p'
```

**Ruta mental de scheduling:**

```
Pending -> Events -> Recursos (requests) -> nodeSelector -> Affinity -> Taints/Tolerations
```
