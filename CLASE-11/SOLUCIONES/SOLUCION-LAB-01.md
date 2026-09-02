# SOLUCIÓN — LAB 11.1 · Crear e inyectar ConfigMap y Secret

> **MATERIAL DEL INSTRUCTOR.**

## Diagnóstico

Tres ideas que hay que dejar fijadas:

1. **ConfigMap y Secret son el mismo mecanismo** con distinta intención. Uno para config legible, otro para datos sensibles.
2. **base64 no es cifrado.** `kubectl get secret ... -o jsonpath | base64 -d` revierte cualquier valor. Lo que protege un Secret es el RBAC y el cifrado en reposo del API server.
3. **La forma de inyectar decide la propagación.** `env`/`envFrom` se fija al arrancar; un volumen `configMap`/`secret` se actualiza (sin `subPath`).

## Procedimiento

```bash
k create ns c11-basico && k config set-context --current --namespace=c11-basico

# A
k create configmap demo-lit --from-literal=LOG_LEVEL=info --from-literal=TZ=UTC
printf '[demo]\nworkers = 4\nmode = prod\n' > app.conf
k create configmap demo-file --from-file=app.conf
k get cm demo-lit demo-file -o yaml | grep -A4 'data:'
k apply -f ../RECURSOS/YAML/01-configmap-secret.yaml

# B - un Secret no esta cifrado
k get secret demo-secret -o yaml | grep -A3 'data:'
k get secret demo-secret -o jsonpath='{.data.password}' | base64 -d; echo

# C - env
cat <<'EOF' | k apply -f -
apiVersion: v1
kind: Pod
metadata: {name: envtest, namespace: c11-basico}
spec:
  restartPolicy: Never
  containers:
    - name: c
      image: busybox:1.36
      command: ["sleep","3600"]
      envFrom:
        - configMapRef: {name: demo-lit}
      env:
        - name: DB_PASS
          valueFrom: {secretKeyRef: {name: demo-secret, key: password}}
EOF
k exec envtest -- printenv | grep -E 'LOG_LEVEL|TZ|DB_PASS'

# D - archivos
cat <<'EOF' | k apply -f -
apiVersion: v1
kind: Pod
metadata: {name: filetest, namespace: c11-basico}
spec:
  restartPolicy: Never
  containers:
    - name: c
      image: busybox:1.36
      command: ["sleep","3600"]
      volumeMounts:
        - {name: cfg, mountPath: /etc/demo}
        - {name: sec, mountPath: /etc/secret}
  volumes:
    - {name: cfg, configMap: {name: demo-config}}
    - {name: sec, secret: {secretName: demo-secret}}
EOF
k exec filetest -- ls -l /etc/demo /etc/secret
k exec filetest -- cat /etc/demo/APP_MODE

# E - propagacion
k patch configmap demo-config --type=merge -p '{"data":{"APP_MODE":"staging"}}'
k exec envtest  -- printenv APP_MODE     # (no existe: envtest usa demo-lit) -> el ejemplo real: editar demo-lit
k patch configmap demo-lit --type=merge -p '{"data":{"LOG_LEVEL":"debug"}}'
k exec envtest  -- printenv LOG_LEVEL    # sigue 'info' -> env NO se actualiza
sleep 60
k exec filetest -- cat /etc/demo/APP_MODE   # 'staging' -> el volumen SI se actualiza
```

## Validación

```bash
k get cm,secret
k exec envtest  -- printenv | grep -E 'LOG_LEVEL|DB_PASS'
k exec filetest -- ls /etc/demo /etc/secret
k get secret demo-secret -o jsonpath='{.data.password}' | base64 -d; echo
```

## Resultado esperado

* `demo-lit`, `demo-file`, `demo-config`, `demo-secret` creados.
* `base64 -d` devuelve `c4mbi4-esto-ya`.
* `envtest`: `LOG_LEVEL`, `TZ`, `DB_PASS` presentes.
* `filetest`: un fichero por clave en `/etc/demo` y `/etc/secret`.
* Editar el ConfigMap: `envtest` no cambia; `filetest` sí, tras < 1 min.

## Error frecuente

* Creer que un Secret está cifrado. Está en base64, que no es cifrado.
* `--from-file=app.conf` esperando varias claves: crea **una** clave `app.conf` con todo el contenido. Para una clave por línea, `--from-env-file`.
* Editar un ConfigMap inyectado por `env` y esperar que el Pod cambie sin `rollout restart`.
* Montar un volumen `configMap` sobre `/etc` y quedarse sin `/etc/passwd`: el montaje **oculta** el directorio.

## CKA Tip

```bash
k create configmap <n> --from-literal=K=V --from-file=f.conf --from-env-file=vars.env
k create secret generic <n> --from-literal=password=... --from-file=tls.crt=...
k create configmap <n> --from-literal=K=V --dry-run=client -o yaml
k get secret <n> -o jsonpath='{.data.<k>}' | base64 -d
```
