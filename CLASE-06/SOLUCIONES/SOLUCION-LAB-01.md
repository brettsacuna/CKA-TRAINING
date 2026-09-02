# SOLUCIÓN — LAB 6.1 · Traducir estados

> **MATERIAL DEL INSTRUCTOR.**

## Diagnóstico

| Pod | Estado | Causa raíz | Comando que lo confirma |
|---|---|---|---|
| `caso-1` | `Pending` | `nodeSelector: hardware=fpga`; ningún nodo tiene ese label | `describe pod caso-1` → `FailedScheduling ... didn't match node selector` |
| `caso-2` | `ImagePullBackOff` | Tag `nginx:version-que-no-existe` | `describe pod caso-2` → `Failed to pull image` |
| `caso-3` | `CreateContainerConfigError` | `envFrom` referencia `caso3-cfg-inexistente` | `describe pod caso-3` → `configmap "caso3-cfg-inexistente" not found` |
| `caso-4` | `CrashLoopBackOff` | El comando escribe en stderr y sale con código 1 | `logs caso-4 --previous` |
| `caso-5` | `Running` pero `0/1 READY` | `readinessProbe` al puerto 8081; nginx escucha en 80 | `describe pod caso-5` → `Readiness probe failed: connection refused` |
| `caso-6` | `CrashLoopBackOff` con `OOMKilled` | `stress` pide 250M con `limits.memory: 64Mi` | `describe pod caso-6` → `Last State: Terminated, Reason: OOMKilled, Exit Code: 137` |

## Razonamiento técnico resumido

El estado dice **en qué fase murió** el Pod, y por tanto qué comando sirve:

```
Pending                     -> el scheduler no encontró nodo        -> describe / events
ContainerCreating atascado  -> montaje de volumen o red del Pod     -> describe / events
ImagePullBackOff            -> el nodo no puede traer la imagen     -> describe / events
CreateContainerConfigError  -> falta un ConfigMap, Secret o clave   -> describe + get cm,secret
CrashLoopBackOff            -> el proceso arrancó y murió           -> logs --previous
Running 0/1 READY           -> la readinessProbe falla              -> describe (Conditions)
OOMKilled (Last State)      -> superó limits.memory                 -> describe (Last State)
```

**`logs` sin `--previous` es inútil en un `CrashLoopBackOff`**: devuelve el contenedor actual, que probablemente aún no ha escrito nada. La causa está en la instancia anterior.

## Procedimiento

```bash
NS=c6-estados

# caso-1
k -n $NS describe pod caso-1 | sed -n '/Events/,$p'
k -n $NS patch pod caso-1 --type=json -p='[{"op":"remove","path":"/spec/nodeSelector"}]' 2>/dev/null \
  || { k -n $NS delete pod caso-1; k -n $NS run caso-1 --image=nginx:1.27-alpine; }
# (spec.nodeSelector de un Pod es inmutable: hay que recrearlo. Discútelo con el grupo.)

# caso-2
k -n $NS set image pod/caso-2 c=nginx:1.27-alpine 2>/dev/null \
  || { k -n $NS delete pod caso-2; k -n $NS run caso-2 --image=nginx:1.27-alpine; }

# caso-3   (el ConfigMap correcto ya existe: se llama caso3-cfg)
k -n $NS get cm
k -n $NS delete pod caso-3
k -n $NS apply -f - <<'YAML'
apiVersion: v1
kind: Pod
metadata: {name: caso-3, namespace: c6-estados}
spec:
  containers:
    - name: c
      image: nginx:1.27-alpine
      envFrom: [{configMapRef: {name: caso3-cfg}}]
YAML

# caso-4
k -n $NS logs caso-4 --previous
k -n $NS delete pod caso-4
k -n $NS run caso-4 --image=busybox:1.36 -- sleep 3600

# caso-5
k -n $NS describe pod caso-5 | sed -n '/Conditions/,/Events/p'
k -n $NS delete pod caso-5
k -n $NS apply -f - <<'YAML'
apiVersion: v1
kind: Pod
metadata: {name: caso-5, namespace: c6-estados}
spec:
  containers:
    - name: c
      image: nginx:1.27-alpine
      readinessProbe: {httpGet: {path: /, port: 80}, periodSeconds: 5}
YAML

# caso-6
k -n $NS describe pod caso-6 | grep -A5 'Last State'
k -n $NS delete pod caso-6
k -n $NS apply -f - <<'YAML'
apiVersion: v1
kind: Pod
metadata: {name: caso-6, namespace: c6-estados}
spec:
  containers:
    - name: c
      image: polinux/stress
      command: ["stress"]
      args: ["--vm","1","--vm-bytes","32M","--vm-hang","1"]
      resources: {requests: {memory: "32Mi"}, limits: {memory: "64Mi"}}
YAML
```

## Validación

```bash
k -n c6-estados get pods
cd CLASE-06/RECURSOS/SCRIPTS && ./validate-lab.sh basico
```

## Resultado esperado

Los seis Pods `1/1 Running`, sin reinicios crecientes.

## Error frecuente

* Usar `k logs` en un `CrashLoopBackOff` y decir "no hay logs".
* Confundir `caso-1` (`Pending`, scheduler) con `caso-2` (`ImagePullBackOff`, ya hay nodo).
* Tratar `caso-5` como si estuviera bien porque dice `Running`. `Running 0/1` significa que **no recibe tráfico**.
* En `caso-6`, subir el límite de memoria a 512Mi en lugar de mirar cuánta pide el proceso. Ambas correcciones son válidas, pero hay que **decidirlo**, no adivinarlo.
* No darse cuenta de que muchos campos del `spec` de un Pod son inmutables: hay que recrearlo. Con un Deployment detrás, esto no pasaría — buen argumento para no usar Pods sueltos.

## CKA Tip

```bash
# Vista de estados que cabe en una pantalla
k get pods -A -o wide | grep -vE 'Running|Completed'

# Los tres comandos que resuelven el 90% de los Pods rotos
k describe pod <p> | sed -n '/Events/,$p'
k logs <p> --previous
k get events -n <ns> --sort-by=.lastTimestamp | tail -20
```
