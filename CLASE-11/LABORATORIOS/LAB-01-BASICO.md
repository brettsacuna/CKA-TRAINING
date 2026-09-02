# LAB 11.1 — Crear e inyectar ConfigMap y Secret

## Nivel

Básico.

## Duración

22 minutos.

## Objetivo

Crear un ConfigMap y un Secret por las dos vías (imperativa y declarativa),
inyectarlos en un Pod como variables de entorno y como archivos, y comprobar de
primera mano que un Secret **no está cifrado**.

## Competencias

* Crear ConfigMap/Secret con `--from-literal`, `--from-file` y `stringData`.
* Inyectar con `env`, `envFrom` y `valueFrom`.
* Montar un ConfigMap/Secret como volumen de archivos.
* Revertir un valor de un Secret con `base64 -d`.

## Escenario

Antes de tocar GRATITUD, dominas el mecanismo con objetos de juguete: entender
qué llega al contenedor como variable y qué como fichero, y qué se actualiza solo.

## Estado inicial

* Namespace de trabajo: **`c11-basico`**.

## Requerimientos

### Parte A — Crear los objetos

1. Crea el namespace `c11-basico` y fíjalo en el contexto.
2. Crea un ConfigMap **`demo-lit`** con `--from-literal`:
   ```bash
   kubectl create configmap demo-lit --from-literal=LOG_LEVEL=info --from-literal=TZ=UTC
   ```
3. Crea un fichero `app.conf` con tres o cuatro líneas y un ConfigMap **`demo-file`** a partir de él:
   ```bash
   printf '[demo]\nworkers = 4\nmode = prod\n' > app.conf
   kubectl create configmap demo-file --from-file=app.conf
   ```
4. Mira el YAML de ambos: `kubectl get cm demo-lit demo-file -o yaml`. Fíjate en que en `demo-file` la clave es `app.conf` y el valor es el contenido entero.
5. Aplica el ConfigMap y el Secret declarativos:
   ```bash
   kubectl apply -f ../RECURSOS/YAML/01-configmap-secret.yaml
   ```
   `demo-config` (ConfigMap) y `demo-secret` (Secret con `stringData`).

### Parte B — Un Secret no está cifrado

6. Mira el Secret: `kubectl get secret demo-secret -o yaml`. Los valores están en `data:` en base64.
7. Revierte uno:
   ```bash
   kubectl get secret demo-secret -o jsonpath='{.data.password}' | base64 -d ; echo
   ```
8. Anota la conclusión: cualquiera con permiso de **lectura** sobre el objeto ve el valor. Lo que protege un Secret es el RBAC sobre `secrets` y el cifrado en reposo (que se configura en el API server), no el objeto en sí.

### Parte C — Inyección como variables de entorno

9. Crea un Pod que reciba **todas** las claves de `demo-lit` con `envFrom` y **una** clave de `demo-secret` con `valueFrom`:
   ```bash
   kubectl run envtest --image=busybox:1.36 --restart=Never --command -- sleep 3600 --dry-run=client -o yaml > envtest.yaml
   # edita envtest.yaml y añade en el contenedor:
   #   envFrom: [{configMapRef: {name: demo-lit}}]
   #   env: [{name: DB_PASS, valueFrom: {secretKeyRef: {name: demo-secret, key: password}}}]
   kubectl apply -f envtest.yaml
   ```
10. Comprueba las variables dentro del Pod:
    ```bash
    kubectl exec envtest -- printenv | grep -E 'LOG_LEVEL|TZ|DB_PASS'
    ```

### Parte D — Inyección como archivos

11. Crea un Pod que monte `demo-config` como volumen en `/etc/demo` y `demo-secret` en `/etc/secret`:
    ```bash
    # en el spec del Pod:
    #   volumes:
    #     - {name: cfg, configMap: {name: demo-config}}
    #     - {name: sec, secret: {secretName: demo-secret}}
    #   volumeMounts:
    #     - {name: cfg, mountPath: /etc/demo}
    #     - {name: sec, mountPath: /etc/secret}
    kubectl exec filetest -- ls -l /etc/demo /etc/secret
    kubectl exec filetest -- cat /etc/demo/APP_MODE
    ```
    Cada clave es un fichero cuyo contenido es el valor.

### Parte E — Propagación de un cambio

12. Edita `demo-config` y cambia el valor de una clave: `kubectl edit configmap demo-config`.
13. Comprueba:
    * en el Pod de la Parte C (env): `kubectl exec envtest -- printenv` → **no ha cambiado**.
    * en el Pod de la Parte D (volumen): espera hasta 1 min y `kubectl exec filetest -- cat /etc/demo/<clave>` → **sí cambia**.
14. Explica por qué, y qué harías para que el Pod de la Parte C recogiera el cambio.

## Restricciones

* No uses `optional: true` en las referencias.
* No borres `demo-config` para "forzar" la actualización de las env var.

## Validación

```bash
kubectl -n c11-basico get cm,secret
kubectl -n c11-basico exec envtest  -- printenv | grep -E 'LOG_LEVEL|DB_PASS'
kubectl -n c11-basico exec filetest -- ls /etc/demo /etc/secret
kubectl -n c11-basico get secret demo-secret -o jsonpath='{.data.password}' | base64 -d ; echo
```

## Resultado esperado

* `demo-lit`, `demo-file`, `demo-config` (ConfigMaps) y `demo-secret` (Secret) creados.
* `base64 -d` devuelve el valor en claro del Secret.
* En el Pod de env: `LOG_LEVEL`, `TZ` y `DB_PASS` presentes.
* En el Pod de volumen: un fichero por clave en `/etc/demo` y `/etc/secret`.
* Tras editar el ConfigMap: las env var **no** cambian; los ficheros montados **sí** (en < 1 min).

## Criterios de éxito

- [ ] Creé ConfigMaps con `--from-literal` y con `--from-file`.
- [ ] Creé un Secret con `stringData` y reverti un valor con `base64 -d`.
- [ ] Enuncié qué protege realmente un Secret.
- [ ] Inyecté con `envFrom` y con `valueFrom`, y lo verifiqué con `printenv`.
- [ ] Monté ConfigMap y Secret como archivos y vi un fichero por clave.
- [ ] Comprobé que el cambio llega al volumen pero no a las env var, y sé por qué.
