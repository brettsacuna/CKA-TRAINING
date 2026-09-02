# SOLUCIÓN — LAB 11.2 · Cablear la configuración de GRATITUD

> **MATERIAL DEL INSTRUCTOR.**

## Diagnóstico

1. **`envFrom` + `valueFrom` conviven.** `envFrom` vuelca todas las claves; `env`/`valueFrom` selecciona una y permite renombrarla.
2. **`subPath` inyecta un solo fichero sin ocultar el directorio**, a cambio de **no** recibir actualizaciones.
3. **`env` no se propaga.** Editar `gratitud-config` no cambia las variables del Pod hasta `kubectl rollout restart`.
4. **`immutable: true`** impide editar; para cambiarlo se recrea. Acelera el arranque y evita cambios accidentales.

## Procedimiento

```bash
k apply -f ../RECURSOS/YAML/02-gratitud-config.yaml
k -n gratitud-api get cm gratitud-config -o jsonpath='{.data.app\.conf}'; echo

k apply -f ../RECURSOS/YAML/03-gratitud-api-deploy.yaml
k -n gratitud-api rollout status deploy/api

# B - verificar la inyeccion
k -n gratitud-api exec deploy/api -- printenv | grep -E 'LOG_LEVEL|FEATURE_|UPSTREAM_|DB_|PARTNER_TOKEN'
k -n gratitud-api exec deploy/api -- cat /etc/gratitud/app.conf
k -n gratitud-api exec deploy/api -- ls -l /etc/gratitud     # subPath: no oculta el directorio

# C - propagacion
k -n gratitud-api patch configmap gratitud-config --type=merge -p '{"data":{"LOG_LEVEL":"debug"}}'
k -n gratitud-api exec deploy/api -- printenv LOG_LEVEL       # sigue 'info'
k -n gratitud-api rollout restart deploy/api
k -n gratitud-api rollout status deploy/api
k -n gratitud-api exec deploy/api -- printenv LOG_LEVEL       # 'debug'

# app.conf con subPath: NO cambia
k -n gratitud-api patch configmap gratitud-config --type=merge \
  -p '{"data":{"app.conf":"[gratitud]\nlog_level = debug\n"}}'
sleep 70
k -n gratitud-api exec deploy/api -- cat /etc/gratitud/app.conf   # sin cambios (subPath)

# D - inmutabilidad
k -n gratitud-api patch configmap gratitud-config --type=merge -p '{"immutable":true}'
k -n gratitud-api patch configmap gratitud-config --type=merge -p '{"data":{"LOG_LEVEL":"trace"}}'
# Error: field is immutable
# para cambiarlo: recrear
k -n gratitud-api delete configmap gratitud-config
k -n gratitud-api create configmap gratitud-config --from-literal=LOG_LEVEL=info ... # y volver a aplicar
```

## Validación

```bash
k -n gratitud-api get cm,secret
k -n gratitud-api get cm gratitud-config -o jsonpath='{.immutable}{"\n"}'
k -n gratitud-api exec deploy/api -- printenv | grep -E 'LOG_LEVEL|DB_PASSWORD|PARTNER_TOKEN'
k -n gratitud-api exec deploy/api -- cat /etc/gratitud/app.conf
```

## Resultado esperado

* En el Pod: `LOG_LEVEL`, `FEATURE_GRATITUD_V2`, `UPSTREAM_CACHE`, `DB_USER`, `DB_PASSWORD`, `DB_HOST`, `PARTNER_TOKEN`.
* `/etc/gratitud/app.conf` con el contenido del ConfigMap; `/etc/gratitud` no oculta nada.
* `LOG_LEVEL` no cambia sin `rollout restart`.
* `app.conf` no cambia (montado con `subPath`).
* `gratitud-config` con `immutable: true` no se puede editar.

## Error frecuente

* Poner `subPath` y esperar recarga en caliente del fichero. No la hay.
* Montar el volumen `configMap` en `/etc/gratitud` **sin** `subPath`: oculta todo lo demás del directorio.
* Editar el ConfigMap y no reiniciar el Deployment, y luego "no entiendo por qué sigue igual".
* Marcar `immutable: true` y luego necesitar un cambio urgente sin acordarse de que hay que recrear.
* Usar `data:` en un Secret con el valor en texto plano (falla la validación base64). Para texto plano, `stringData:`.

## CKA Tip

```bash
# generar el deployment y añadir la inyección
k create deploy api --image=nginxinc/nginx-unprivileged:1.27-alpine --dry-run=client -o yaml > api.yaml
k set env deploy/api --from=configmap/gratitud-config
k set env deploy/api --from=secret/gratitud-db
k set env deploy/api PARTNER_TOKEN --from=secret/gratitud-api-tokens --keys=PARTNER_TOKEN
k -n gratitud-api rollout restart deploy/api
```
