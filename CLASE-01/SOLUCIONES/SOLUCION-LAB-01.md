# SOLUCIÓN — LAB 1.1 · Pods, YAML e inspección

> **MATERIAL DEL INSTRUCTOR.** No distribuir antes de que el alumno resuelva el laboratorio.

## Diagnóstico

No hay diagnóstico: es un laboratorio de construcción. El punto crítico es que el alumno **no escriba YAML a mano**. Si lo hace, en el examen pierde entre 30 y 60 segundos por tarea.

## Razonamiento técnico resumido

* `kubectl run` crea **un Pod**; `kubectl create deployment` crea un Deployment. En el CKA se pide una cosa u otra con precisión.
* `--dry-run=client -o yaml` renderiza el objeto sin enviarlo al API server: es el generador de plantillas.
* `kubectl explain` es la única "documentación" que no cuesta cambiar de pestaña.
* Un Pod con imagen inexistente **no queda `Pending`**, queda `ImagePullBackOff`. Distinguir ambos estados es la base del troubleshooting de la Clase 6.

## Procedimiento

```bash
alias k=kubectl
export do='--dry-run=client -o yaml'
export now='--force --grace-period=0'

# 2
k create ns c1-basico

# 3
k -n c1-basico run web --image=nginx:1.27-alpine

# 4
k -n c1-basico get pod web -o wide

# 5
k -n c1-basico run api --image=httpd:2.4-alpine --port=80 $do > api.yaml
```

Editar `api.yaml` para dejarlo así (el `--port=80` ya genera `ports`, falta nombrarlo y añadir labels):

```yaml
metadata:
  name: api
  labels:
    app: api
    tier: backend
spec:
  containers:
    - name: api
      image: httpd:2.4-alpine
      ports:
        - containerPort: 80
          name: http
```

```bash
# 6
k -n c1-basico apply -f api.yaml
k -n c1-basico get pod api

# 7
k explain pod.spec.terminationGracePeriodSeconds
# -> "Optional duration in seconds the pod needs to terminate gracefully. Defaults to 30 seconds."

# 8
k -n c1-basico logs api
k -n c1-basico exec api -- hostname

# 9
k -n c1-basico label pod web app=web tier=frontend

# 10
k -n c1-basico get pods -l tier=backend

# 11
k -n c1-basico run roto --image=nginx:no-existe
k -n c1-basico get pod roto
k -n c1-basico describe pod roto | sed -n '/Events/,$p'

# 12
k -n c1-basico delete pod roto $now
```

## Validación

```bash
k -n c1-basico get pods -o wide
k -n c1-basico get pod api -o jsonpath='{.metadata.labels}{"\n"}'
k -n c1-basico get pods -l tier=backend --no-headers | wc -l   # -> 1
```

## Resultado esperado

```
NAME   READY   STATUS    RESTARTS   AGE   IP           NODE
api    1/1     Running   0          1m    10.244.1.7   cka-worker1
web    1/1     Running   0          3m    10.244.1.6   cka-worker1
```

Eventos de `roto`:

```
Warning  Failed   ...  Failed to pull image "nginx:no-existe": ... not found
Warning  Failed   ...  Error: ErrImagePull
Normal   BackOff  ...  Back-off pulling image "nginx:no-existe"
```

## Error frecuente

* **Confundir `ImagePullBackOff` con `Pending`.** `Pending` = el scheduler no encontró nodo. `ImagePullBackOff` = ya hay nodo, falla la descarga de la imagen. Son ramas de diagnóstico completamente distintas.
* Olvidar `-n c1-basico` y crear todo en `default`. Enseña desde hoy: `kubectl config set-context --current --namespace=c1-basico`.
* Editar el YAML generado y dejar el campo `status: {}` y `creationTimestamp: null`. No rompe nada, pero conviene explicar por qué aparecen.

## CKA Tip

```bash
# Plantilla en un segundo
k run nginx --image=nginx --port=80 $do > pod.yaml

# Fijar el namespace del contexto y no volver a escribir -n
k config set-context --current --namespace=c1-basico

# Borrado inmediato (el que se usa en el examen para no esperar 30 s)
k delete pod <name> --force --grace-period=0
```
