# SOLUCIÓN — LAB 4.2 · ConfigMaps y Secrets

> **MATERIAL DEL INSTRUCTOR.**

## Diagnóstico

Dos conceptos que casi nadie tiene claros al llegar:

1. **Un Secret no cifra nada.** El valor está en base64, que es codificación reversible por cualquiera. Lo que protege un Secret es *el acceso al objeto* (RBAC), *el cifrado en reposo de etcd* si está configurado, y el hecho de no estar dentro de la imagen.
2. **Un ConfigMap montado como volumen se actualiza solo; una variable de entorno no.** Es la diferencia práctica que decide cómo diseñas la aplicación.

## Razonamiento técnico resumido

| Forma de consumo | Se actualiza en caliente | Cuándo usarla |
|---|---|---|
| `env` + `configMapKeyRef` / `secretKeyRef` | **No** | Una o dos claves concretas |
| `envFrom` | **No** | Todas las claves de golpe |
| Volumen | **Sí** (proyección refrescada por el kubelet) | Archivos de configuración, certificados |

Los Secrets montados como volumen aparecen en **`tmpfs`**: viven en memoria del nodo, nunca se escriben en su disco.

## Procedimiento

### Parte A

```bash
k create ns c4-config && k config set-context --current --namespace=c4-config

# 2
k create configmap app-config --from-literal=APP_COLOR=blue --from-literal=APP_MODE=prod

# 3
k create configmap configmap-web-moon-html --from-file=index.html=web-moon.html

# 4
k get cm app-config -o yaml
k get cm configmap-web-moon-html -o yaml     # la clave usa el bloque literal '|'

# 5
k apply -f ../RECURSOS/YAML/03-deployment-web-moon.yaml

# 6
k exec deploy/web-moon -- env | grep APP_
k exec deploy/web-moon -- cat /usr/share/nginx/html/index.html

# 7
k run tmp --rm -it --image=busybox:1.36 --restart=Never -- wget -qO- http://web-moon
```

### Parte B

```bash
# 8
k create secret generic db-cred \
  --from-literal=user=admin --from-literal=password=Sup3rS3cret

# 9
k get secret db-cred -o yaml
k get secret db-cred -o jsonpath='{.data.password}' | base64 -d; echo
# -> Sup3rS3cret     (base64 NO es cifrado)

# 10  ya está en el YAML de referencia
k apply -f ../RECURSOS/YAML/03-deployment-web-moon.yaml

# 11
k exec deploy/web-moon -- env | grep DB_PASSWORD
k exec deploy/web-moon -- ls -l /etc/db-cred
k exec deploy/web-moon -- cat /etc/db-cred/user
k exec deploy/web-moon -- mount | grep db-cred
# tmpfs on /etc/db-cred type tmpfs (ro,relatime,...)
```

### Parte C

```bash
# 12
k patch cm app-config -p '{"data":{"APP_COLOR":"green"}}'
k create configmap configmap-web-moon-html \
  --from-file=index.html=web-moon-v2.html --dry-run=client -o yaml | k apply -f -

# 13
k exec deploy/web-moon -- env | grep APP_COLOR        # sigue blue
sleep 70
k exec deploy/web-moon -- cat /usr/share/nginx/html/index.html   # contenido nuevo

# 14
k rollout restart deploy/web-moon
k exec deploy/web-moon -- env | grep APP_COLOR        # ahora green
```

**14 —** Las variables de entorno se resuelven **una sola vez**, al crear el contenedor. Para que cambien hay que recrear el Pod: `kubectl rollout restart`.

## Validación

```bash
k get cm,secret
k exec deploy/web-moon -- env | grep -E 'APP_|DB_PASSWORD'
k exec deploy/web-moon -- ls /etc/db-cred
k run tmp --rm -it --image=busybox:1.36 --restart=Never -- wget -qO- http://web-moon
```

## Resultado esperado

```
APP_COLOR=blue
APP_MODE=prod
DB_PASSWORD=Sup3rS3cret

/etc/db-cred:
  password
  user
tmpfs on /etc/db-cred type tmpfs (ro,...)
```

## Error frecuente

* Decir "los Secrets están encriptados". Corrígelo siempre y en voz alta.
* Usar `data:` con texto plano en un Secret YAML: el API server exige base64 en `data`. Para texto plano, `stringData:`.
* Olvidar la clave al usar `--from-file`: `--from-file=web-moon.html` crea la clave `web-moon.html`, no `index.html`. Hay que escribir `--from-file=index.html=web-moon.html`.
* Referenciar un ConfigMap inexistente: el Pod queda en `CreateContainerConfigError`, no en `CrashLoopBackOff`. Es el fallo del LAB 4.4.
* Esperar que la variable de entorno cambie sola.
* Montar un Secret sin `readOnly: true`.

## CKA Tip

```bash
k create configmap <n> --from-literal=k=v --from-file=clave=archivo --from-env-file=f.env
k create secret generic <n> --from-literal=user=admin --from-literal=password=x
k create secret tls <n> --cert=cert.pem --key=key.pem
k get secret <n> -o jsonpath='{.data.password}' | base64 -d

# Generar el YAML de consumo sin memorizar la sintaxis
k explain pod.spec.containers.envFrom
k explain pod.spec.containers.env.valueFrom.secretKeyRef
```

**Si algo debe recargarse sin reiniciar el Pod, móntalo como volumen. Si no, usa variables.**
