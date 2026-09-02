# LAB 4.2 — ConfigMaps y Secrets

## Nivel

Intermedio.

## Duración

30 minutos.

## Objetivo

Sacar toda la configuración fuera de la imagen: parámetros no sensibles en ConfigMaps, credenciales en Secrets, consumidos como variables de entorno y como archivos.

## Competencias

* Crear ConfigMaps y Secrets desde literales, archivos y YAML.
* Consumir con `env` + `configMapKeyRef` / `secretKeyRef`, con `envFrom` y como volumen.
* Comprobar el contenido dentro del contenedor.
* Explicar el modelo de protección real de un Secret.

## Escenario

El equipo `moonpie` sirve una web con nginx. Hoy el `index.html`, los parámetros de la aplicación y la contraseña de la base de datos están **dentro de la imagen**. Hay que sacarlos.

## Estado inicial

* Namespace de trabajo: **`c4-config`**.
* Crea en tu máquina el archivo `web-moon.html` con este contenido:

```html
<!DOCTYPE html>
<html lang="es">
<head><meta charset="UTF-8"><title>Web Moon</title></head>
<body>Contenido servido desde un ConfigMap.</body>
</html>
```

## Requerimientos

### Parte A — ConfigMaps

1. Crea el namespace `c4-config`.
2. Crea un ConfigMap **`app-config`** con estas claves, **desde literales**:
   * `APP_COLOR=blue`
   * `APP_MODE=prod`
3. Crea un ConfigMap **`configmap-web-moon-html`** con el contenido del archivo `web-moon.html` bajo la clave **`index.html`**, usando `--from-file`.
4. Muestra ambos ConfigMaps en YAML y comprueba la diferencia entre una clave corta y una clave multilínea.
5. Crea un Deployment **`web-moon`** (1 réplica, `nginx:1.27-alpine`) que:
   * reciba **todas** las claves de `app-config` como variables de entorno usando **`envFrom`**,
   * monte `configmap-web-moon-html` en `/usr/share/nginx/html` como volumen.
6. Comprueba desde dentro del contenedor:
   * `env | grep APP_`
   * `cat /usr/share/nginx/html/index.html`
7. Expón el Deployment con un Service ClusterIP `web-moon` en el puerto 80 y comprueba con `curl` desde un Pod temporal que sirve el contenido del ConfigMap.

### Parte B — Secrets

8. Crea un Secret **`db-cred`** de tipo `Opaque` con:
   * `user=admin`
   * `password=Sup3rS3cret`
9. Muestra el Secret en YAML. **Decodifica** el valor de `password` con `base64 -d` y comenta el resultado con el grupo.
10. Modifica el Deployment `web-moon` para que además:
    * reciba la variable de entorno **`DB_PASSWORD`** desde la clave `password` del Secret (`secretKeyRef`),
    * monte el Secret completo en **`/etc/db-cred`** en modo **solo lectura**.
11. Comprueba dentro del contenedor:
    * `env | grep DB_PASSWORD`
    * `ls /etc/db-cred` y `cat /etc/db-cred/user`
    * `mount | grep db-cred` — anota el tipo de sistema de archivos que aparece y por qué.

### Parte C — Actualización en caliente

12. Cambia el valor de `APP_COLOR` a `green` en el ConfigMap `app-config`, y el contenido del `index.html` en `configmap-web-moon-html`.
13. **Sin reiniciar el Pod**, comprueba:
    * si la variable de entorno `APP_COLOR` cambió,
    * si el archivo montado cambió (puede tardar hasta ~1 minuto).
14. Explica la diferencia y di qué hay que hacer para que la variable de entorno tome el valor nuevo.

## Restricciones

* No pongas ningún valor sensible directamente en el manifiesto del Deployment.
* El montaje del Secret debe ser `readOnly: true`.
* En el paso 13 **no puedes** borrar el Pod ni hacer `rollout restart` hasta haber comprobado ambos comportamientos.

## Validación

```bash
kubectl -n c4-config get cm,secret
kubectl -n c4-config get cm configmap-web-moon-html -o yaml
kubectl -n c4-config exec deploy/web-moon -- env | grep -E 'APP_|DB_PASSWORD'
kubectl -n c4-config exec deploy/web-moon -- cat /usr/share/nginx/html/index.html
kubectl -n c4-config exec deploy/web-moon -- ls -l /etc/db-cred
kubectl -n c4-config exec deploy/web-moon -- mount | grep db-cred
kubectl run tmp --rm -it -n c4-config --image=busybox:1.36 --restart=Never -- \
  wget -qO- http://web-moon
```

## Resultado esperado

* `APP_COLOR=blue` y `APP_MODE=prod` en el entorno del contenedor.
* `/usr/share/nginx/html/index.html` con el contenido del ConfigMap; `curl` devuelve esa página.
* `DB_PASSWORD=Sup3rS3cret` en el entorno; `/etc/db-cred/user` y `/etc/db-cred/password` como archivos.
* El montaje del Secret aparece como **`tmpfs`** (en memoria, no en disco del nodo).
* Tras el paso 12: **el archivo montado se actualiza solo**; **la variable de entorno no**.

## Criterios de éxito

- [ ] `app-config` creado desde literales.
- [ ] `configmap-web-moon-html` creado con `--from-file` y clave `index.html`.
- [ ] `envFrom` inyecta todas las claves de `app-config`.
- [ ] El ConfigMap está montado y nginx sirve su contenido.
- [ ] Secret `db-cred` creado y consumido por `secretKeyRef`.
- [ ] Secret montado en `/etc/db-cred` en solo lectura.
- [ ] Identifiqué el `tmpfs` y sé explicarlo.
- [ ] Decodifiqué el base64 y expliqué qué protege realmente un Secret.
- [ ] Comprobé la diferencia de actualización entre volumen y variable de entorno.
- [ ] Sé qué comando fuerza a que la variable tome el valor nuevo.
