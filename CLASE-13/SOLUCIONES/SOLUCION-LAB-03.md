# SOLUCIÓN — LAB 13.3 · Endurecer los contenedores de GRATITUD

> **MATERIAL DEL INSTRUCTOR.**

## Diagnóstico

1. **`securityContext`** se pone a nivel de Pod (todos los contenedores) y de contenedor (gana el del contenedor).
2. **`restricted`** exige, además de lo de `baseline`: `runAsNonRoot`, `allowPrivilegeEscalation: false`, `capabilities.drop: [ALL]` y `seccompProfile` (`RuntimeDefault` o `Localhost`).
3. **PSA se activa por etiquetas del namespace.** `warn`/`audit` para medir; `enforce` para rechazar. Un Pod rechazado por `enforce` **no se crea** (Deployment a 0).
4. **`readOnlyRootFilesystem`** obliga a montar `emptyDir` en las rutas escribibles (`nginx-unprivileged`: `/tmp`, `/var/cache/nginx`, `/var/run`).

## Procedimiento

```bash
k apply -f ../RECURSOS/YAML/04-gratitud-api-plano.yaml

# medir primero
k label ns gratitud-api \
  pod-security.kubernetes.io/warn=restricted \
  pod-security.kubernetes.io/audit=restricted
k apply -f ../RECURSOS/YAML/04-gratitud-api-plano.yaml    # avisos: allowPrivilegeEscalation, capabilities, runAsNonRoot, seccomp

# endurecer
k -n gratitud-api patch deploy api --type=merge -p '
spec:
  template:
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 101
        fsGroup: 101
        seccompProfile: {type: RuntimeDefault}
      containers:
        - name: api
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities: {drop: ["ALL"]}
          volumeMounts:
            - {name: tmp, mountPath: /tmp}
            - {name: cache, mountPath: /var/cache/nginx}
            - {name: run, mountPath: /var/run}
      volumes:
        - {name: tmp, emptyDir: {}}
        - {name: cache, emptyDir: {}}
        - {name: run, emptyDir: {}}'
k -n gratitud-api rollout status deploy/api

# enforce cuando warn ya no protesta
k label ns gratitud-api pod-security.kubernetes.io/enforce=restricted
k -n gratitud-api rollout restart deploy/api && k -n gratitud-api rollout status deploy/api
```

Referencia: `../RECURSOS/YAML/05-gratitud-api-hardened-referencia.yaml`.

## Prueba de que el enforce funciona

```bash
k -n gratitud-api run mal --image=busybox:1.36 --restart=Never -- sleep 60
# Error from server (Forbidden): ... violates PodSecurity "restricted:latest":
#   allowPrivilegeEscalation != false, unrestricted capabilities, runAsNonRoot != true, seccompProfile
```

## Validación

```bash
k get ns gratitud-api --show-labels | tr ',' '\n' | grep pod-security
P=$(k -n gratitud-api get pod -l app=gratitud-api -o name | head -1)
k -n gratitud-api exec $P -- id                              # uid=101 ...
k -n gratitud-api exec $P -- sh -c 'echo x > /probando' 2>&1 # Read-only file system
k -n gratitud-api exec $P -- sh -c 'grep CapEff /proc/1/status'   # CapEff: 0000000000000000
k -n gratitud-api get deploy api -o jsonpath='{.spec.template.spec.containers[0].securityContext}{"\n"}'
```

## Resultado esperado

* `gratitud-api` con `enforce`, `warn` y `audit` = `restricted`.
* `api` desplegando `2/2` con el `securityContext` conforme.
* Dentro: UID `101`, `/` de solo lectura, `CapEff` a cero.
* Un Pod sin `securityContext` en ese namespace es rechazado.

## Error frecuente

* Poner `enforce` antes de haber ajustado el `securityContext`: el Deployment se queda a 0 y parece que "se borró".
* `runAsNonRoot: true` sin `runAsUser`: si la imagen no declara un usuario, el kubelet no puede verificar que no es root y el Pod falla.
* `readOnlyRootFilesystem: true` sin `emptyDir`: `nginx` no puede escribir el `pid` ni la caché y entra en `CrashLoopBackOff`.
* Poner `capabilities.drop: [ALL]` a nivel de Pod: `capabilities` es un campo de **contenedor**, no de Pod.
* Olvidar `seccompProfile`: `restricted` lo exige desde la versión que fija el `enforce-version`.

## CKA Tip

```bash
k label ns NS pod-security.kubernetes.io/enforce=restricted pod-security.kubernetes.io/warn=restricted
k label ns NS pod-security.kubernetes.io/enforce-version=v1.35
k get ns -L pod-security.kubernetes.io/enforce
k -n NS create deploy t --image=... --dry-run=server -o yaml   # el server devuelve el warning de PSA
```

Niveles: `privileged` < `baseline` < `restricted`. Modos: `enforce` (rechaza), `audit` (registra), `warn` (avisa).
