# SOLUCIÓN — LAB 4.3 · Recursos, QoS y métricas

> **MATERIAL DEL INSTRUCTOR.**

## Diagnóstico

Tres fallos provocados que el alumno debe reconocer por su firma:

| Observado | Causa | Recurso implicado |
|---|---|---|
| Metrics Server `0/1 Running` sin llegar a `Ready` | El kubelet presenta un certificado autofirmado que Metrics Server no valida | TLS |
| `Pending` + `Insufficient cpu` | `requests` mayores que la capacidad asignable de cualquier nodo | CPU (en el **scheduler**) |
| `OOMKilled`, exit 137 | El proceso superó `limits.memory` | Memoria (en el **kubelet/cgroup**) |

## Razonamiento técnico resumido

* **`requests`** las usa el **scheduler** para decidir dónde cabe el Pod. Reservan capacidad aunque no se consuma.
* **`limits`** los aplica el **runtime** vía cgroups sobre el contenedor en ejecución.
* **CPU es comprimible**: superar el límite provoca *throttling*, no muerte.
* **Memoria no es comprimible**: superar el límite provoca **OOMKill** (SIGKILL, exit 137).
* QoS:

| Clase | Regla | Orden de desalojo |
|---|---|---|
| `Guaranteed` | `requests == limits` en **todos** los recursos y contenedores | Último |
| `Burstable` | Hay requests o limits pero no coinciden en todo | Intermedio |
| `BestEffort` | Sin requests ni limits | **Primero** |

## Procedimiento

```bash
k create ns c4-recursos && k config set-context --current --namespace=c4-recursos

# R1
../RECURSOS/SCRIPTS/install-metrics-server.sh
k -n kube-system logs deploy/metrics-server | tail -20
#  ... x509: cannot validate certificate ... because it doesn't contain any IP SANs
k -n kube-system patch deploy metrics-server --type=json -p='[
  {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"},
  {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-preferred-address-types=InternalIP"}
]'
k -n kube-system rollout status deploy/metrics-server
k top nodes && k top pods -A

# R2
k apply -f ../RECURSOS/YAML/04-qos-ejemplos.yaml
k get pods -o custom-columns=NAME:.metadata.name,QOS:.status.qosClass

# R3
k create deployment hambriento --image=nginx:1.27-alpine --replicas=2
k set resources deploy/hambriento --requests=cpu=8
k get pods -l app=hambriento
k describe pod -l app=hambriento | sed -n '/Events/,$p'
#  Warning FailedScheduling  0/3 nodes are available: 3 Insufficient cpu.
k set resources deploy/hambriento --requests=cpu=100m
k get pods -l app=hambriento          # Running

# R4
k apply -f ../RECURSOS/YAML/05-oomkilled.yaml
k get pod memoria -w
k describe pod memoria | sed -n '/Last State/,/Ready/p'
#  Last State: Terminated
#    Reason: OOMKilled
#    Exit Code: 137

# R5
k create deployment medido --image=nginx:1.27-alpine --replicas=2
k set resources deploy/medido --requests=cpu=100m,memory=64Mi --limits=cpu=500m,memory=128Mi
k scale deployment medido --replicas=6
k top pods -l app=medido
k describe node cka-worker1 | sed -n '/Allocated resources/,$p'
```

**R4.11 —** La CPU es un recurso *comprimible*: si un contenedor pide más de su límite, el kernel simplemente le da menos ciclos (throttling) y el proceso sigue vivo, solo que más lento. La memoria no se puede "prestar menos": o hay páginas o no las hay. Cuando el cgroup supera su límite, el kernel invoca al OOM killer y mata el proceso.

**R5.14 —** Es normal ver `kubectl top` reportando ~1-3m de CPU frente a los 100m solicitados. Eso significa que se está **reservando 30 veces más de lo que se usa**, y multiplicado por réplicas y despliegues, es la causa habitual de "el cluster está lleno pero no hace nada".

## Validación

```bash
k top nodes
k get pods -o custom-columns=NAME:.metadata.name,QOS:.status.qosClass,STATUS:.status.phase
k describe node <worker> | sed -n '/Allocated resources/,$p'
```

## Resultado esperado

```
NAME             QOS          STATUS
pod-besteffort   BestEffort   Running
pod-burstable    Burstable    Running
pod-guaranteed   Guaranteed   Running
memoria          Burstable    Running (con RESTARTS crecientes)
```

## Error frecuente

* Instalar la versión antigua de Metrics Server y editar la línea 42 del manifiesto: ese arreglo era para clusters que ya no existen. Con v0.8.x el manifiesto oficial se aplica tal cual.
* Usar `--kubelet-insecure-tls` en producción. Es aceptable solo en laboratorio; en producción se configura la rotación de certificados de serving del kubelet.
* Confundir `Pending` por CPU con `OOMKilled`: el primero ocurre **antes** de arrancar (scheduler), el segundo **durante** la ejecución (kernel).
* Creer que `limits.cpu` mata el contenedor.
* Poner solo `limits` sin `requests`: Kubernetes copia los limits a los requests, y el Pod queda `Guaranteed` sin que el alumno lo pretendiera. Buen ejemplo para comentar.

## CKA Tip

```bash
k set resources deploy/<d> --requests=cpu=100m,memory=64Mi --limits=cpu=500m,memory=128Mi
k get pod <p> -o jsonpath='{.status.qosClass}{"\n"}'
k top nodes ; k top pods -A --sort-by=cpu
k describe node <n> | sed -n '/Allocated resources/,$p'

# ¿Por qué murió el contenedor?
k describe pod <p> | grep -A5 'Last State'
k logs <p> --previous
```

**Exit 137 = OOMKilled. Exit 1 = la aplicación falló. `Pending` = nunca llegó a arrancar.** Tres ramas de diagnóstico distintas.
