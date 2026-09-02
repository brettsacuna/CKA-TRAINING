# LAB 10.3 — HTTPS propio para GRATITUD

## Nivel

Avanzado.

## Duración

30 minutos.

## Objetivo

Partir del Ingress HTTP del LAB 10.2 y llegar —**solo a partir de requerimientos
de seguridad**— a servir GRATITUD por HTTPS con certificado propio en sus dos
dominios, sabiendo distinguir cuándo el certificado presentado es el tuyo y
cuándo el del controlador.

## Competencias

* Generar un certificado X.509 y crear un Secret `kubernetes.io/tls`.
* Asociar cada host a su Secret en `spec.tls`.
* Probar HTTPS con `curl --resolve` y leer `subject`/`issuer` del certificado.
* Reconocer el certificado por defecto del controlador como síntoma de fallo.

## Escenario

Seguridad audita GRATITUD y emite estos requisitos para el namespace
**`gratitud-web`**:

| # | Requisito |
|---|---|
| R1 | `gratitud.example.com` debe servirse por **HTTPS** con un certificado cuyo `CN`/SAN sea ese host. |
| R2 | `admin.gratitud.example.com` debe servirse por HTTPS con **su propio** certificado, distinto del de R1. |
| R3 | El certificado y su clave privada deben vivir en un Secret de tipo `kubernetes.io/tls`, en el **mismo namespace** que el Ingress. |
| R4 | El tráfico HTTP (puerto 80) debe seguir enrutando igual que en el LAB 10.2 (no se exige redirección a HTTPS, pero se admite). |
| R5 | Debe poder probarse **sin modificar `/etc/hosts`**. |

Tú decides los comandos, el orden y las pruebas.

## Estado inicial

* El Ingress `gratitud` del LAB 10.2, funcionando por HTTP.
* Controlador del LAB 10.1 con su `nodePort` de HTTPS (`32443` con el script).

## Pistas de método (no de solución)

* `openssl req -x509 -newkey rsa:4096 -nodes -days 3650 -keyout key.pem -out cert.pem -subj "/CN=<host>" -addext "subjectAltName=DNS:<host>"`.
* El script `../RECURSOS/SCRIPTS/gen-tls-secret.sh` acepta `CN`, `NS` y `NAME` por variable de entorno: puedes lanzarlo dos veces.
* `kubectl create secret tls <nombre> --cert=cert.pem --key=key.pem -n gratitud-web`.
* En `spec.tls` va una lista: cada entrada tiene `hosts: [...]` y `secretName: ...`.
* `curl -kv --resolve <host>:32443:<IP-NODO> https://<host>:32443/` y busca en la salida `*  subject:` y `*  issuer:`.

## Validación

```bash
kubectl -n gratitud-web get secret | grep tls
kubectl -n gratitud-web get secret gratitud-tls -o jsonpath='{.type}{"\n"}'          # kubernetes.io/tls
kubectl -n gratitud-web get ingress gratitud -o jsonpath='{.spec.tls}{"\n"}'

# gratitud.example.com
curl -kv --resolve gratitud.example.com:32443:<IP-NODO> \
  https://gratitud.example.com:32443/ 2>&1 | grep -E 'subject:|issuer:|HTTP/'

# admin.gratitud.example.com (certificado distinto)
curl -kv --resolve admin.gratitud.example.com:32443:<IP-NODO> \
  https://admin.gratitud.example.com:32443/ 2>&1 | grep -E 'subject:|issuer:|HTTP/'

# HTTP sigue funcionando
curl -s -o /dev/null -w '%{http_code}\n' --resolve gratitud.example.com:32080:<IP-NODO> \
  http://gratitud.example.com:32080/
```

Prueba de fallo (R obligatoria de entender, no de dejar así):

```bash
# quita temporalmente la referencia al Secret y observa el certificado por defecto
kubectl -n gratitud-web patch ingress gratitud --type=json -p='[{"op":"remove","path":"/spec/tls"}]'
curl -kv --resolve gratitud.example.com:32443:<IP-NODO> https://gratitud.example.com:32443/ 2>&1 | grep -E 'subject:|issuer:'
# -> subject/issuer del controlador (TRAEFIK DEFAULT CERT o similar), no tu CN
# vuelve a poner spec.tls
```

## Resultado esperado

* `gratitud-tls` y `admin-gratitud-tls` (o los nombres que elijas), ambos de tipo `kubernetes.io/tls`, en `gratitud-web`.
* `spec.tls` con dos entradas, cada host con su `secretName`.
* `curl -kv` a `https://gratitud.example.com:32443/` presenta un certificado cuyo `subject` contiene `CN=gratitud.example.com`; el de `admin.…` presenta **otro** certificado con su propio `CN`.
* El HTTP del puerto 80 sigue enrutando como en el LAB 10.2.
* Al quitar `spec.tls`, el controlador presenta su **certificado por defecto**: es el síntoma que hay que saber reconocer.

## Criterios de éxito

- [ ] Generé un certificado por dominio con el host en `CN`/SAN.
- [ ] Creé los Secret de tipo `kubernetes.io/tls` en `gratitud-web`.
- [ ] `spec.tls` asocia cada host a su Secret.
- [ ] `curl -kv` muestra **mi** `subject`/`issuer` para cada host, y son distintos entre dominios.
- [ ] Probé todo con `curl --resolve`, sin tocar `/etc/hosts`.
- [ ] Reconozco el certificado por defecto del controlador como señal de que el Secret no se aplica.
