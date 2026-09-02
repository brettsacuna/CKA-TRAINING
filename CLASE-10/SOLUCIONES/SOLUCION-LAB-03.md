# SOLUCIÓN — LAB 10.3 · HTTPS propio para GRATITUD

> **MATERIAL DEL INSTRUCTOR.**

## Diagnóstico

1. **El certificado vive en un Secret `kubernetes.io/tls`** (`tls.crt` + `tls.key`), en el **mismo namespace** que el Ingress.
2. **`spec.tls` es una lista**: cada entrada asocia `hosts: [...]` con un `secretName`. El controlador elige el certificado por **SNI** (el host que pide el cliente).
3. **Si ningún certificado encaja**, el controlador presenta su **certificado por defecto** autofirmado. Ver ese cert en `curl -kv` es el síntoma de que el Secret no se está aplicando (nombre, namespace o `hosts` mal).

## Procedimiento

```bash
# R1/R2 - dos certificados, dos Secret
CN=gratitud.example.com       NAME=gratitud-tls        NS=gratitud-web ../RECURSOS/SCRIPTS/gen-tls-secret.sh
CN=admin.gratitud.example.com NAME=admin-gratitud-tls  NS=gratitud-web ../RECURSOS/SCRIPTS/gen-tls-secret.sh
k -n gratitud-web get secret | grep tls
k -n gratitud-web get secret gratitud-tls -o jsonpath='{.type}{"\n"}'   # kubernetes.io/tls

# R3 - añadir spec.tls al Ingress del LAB 10.2
k apply -f ../RECURSOS/YAML/05-ingress-tls.yaml
# (o: k -n gratitud-web patch ingress gratitud --type=merge -p '{"spec":{"tls":[
#     {"hosts":["gratitud.example.com"],"secretName":"gratitud-tls"},
#     {"hosts":["admin.gratitud.example.com"],"secretName":"admin-gratitud-tls"}]}}')

# R5 - probar HTTPS sin tocar /etc/hosts
curl -kv --resolve gratitud.example.com:32443:<IP-NODO> \
  https://gratitud.example.com:32443/ 2>&1 | grep -E 'subject:|issuer:|HTTP/'
curl -kv --resolve admin.gratitud.example.com:32443:<IP-NODO> \
  https://admin.gratitud.example.com:32443/ 2>&1 | grep -E 'subject:|issuer:|HTTP/'

# R4 - el HTTP sigue enrutando
curl -s -o /dev/null -w '%{http_code}\n' --resolve gratitud.example.com:32080:<IP-NODO> \
  http://gratitud.example.com:32080/

# prueba de fallo (entender, no dejar así)
k -n gratitud-web patch ingress gratitud --type=json -p='[{"op":"remove","path":"/spec/tls"}]'
curl -kv --resolve gratitud.example.com:32443:<IP-NODO> https://gratitud.example.com:32443/ 2>&1 | grep -E 'subject:|issuer:'
# -> cert por defecto del controlador (p.ej. 'TRAEFIK DEFAULT CERT')
k apply -f ../RECURSOS/YAML/05-ingress-tls.yaml
```

## Lectura de la salida `curl -kv`

```
* Server certificate:
*  subject: O=CKA-TRAINING; CN=gratitud.example.com     <- tu certificado
*  issuer:  O=CKA-TRAINING; CN=gratitud.example.com     <- autofirmado: subject == issuer
*  SSL certificate verify result: self signed certificate (18)   <- por eso el -k
```

Si en `subject`/`issuer` aparece algo como `CN=TRAEFIK DEFAULT CERT`, el Ingress
no está aplicando tu Secret: revisa `secretName`, el namespace y que el host de
`spec.tls[].hosts` coincide **exactamente** con el de la regla.

## Validación

```bash
k -n gratitud-web get ingress gratitud -o jsonpath='{.spec.tls}{"\n"}'
k -n gratitud-web get secret gratitud-tls admin-gratitud-tls -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.type}{"\n"}{end}'
curl -kv --resolve gratitud.example.com:32443:<IP-NODO>       https://gratitud.example.com:32443/       2>&1 | grep -E 'subject:|issuer:|HTTP/'
curl -kv --resolve admin.gratitud.example.com:32443:<IP-NODO> https://admin.gratitud.example.com:32443/ 2>&1 | grep -E 'subject:|issuer:|HTTP/'
```

## Resultado esperado

* `gratitud-tls` y `admin-gratitud-tls`, ambos `kubernetes.io/tls`, en `gratitud-web`.
* `spec.tls` con dos entradas, cada host con su `secretName`.
* `curl -kv` a `gratitud.example.com:32443` → `subject` con `CN=gratitud.example.com`, `HTTP/... 200`.
* `curl -kv` a `admin.gratitud.example.com:32443` → **otro** certificado, con su propio `CN`.
* El HTTP del `32080` sigue devolviendo `200`.
* Sin `spec.tls`, aparece el certificado por defecto del controlador.

## Error frecuente

* Crear el Secret como `Opaque` (con `kubectl create secret generic`) en vez de `tls`. El Ingress necesita `kubernetes.io/tls`.
* Poner el Secret en otro namespace que el Ingress.
* `hosts:` de `spec.tls` distinto del `host:` de la regla → no hay match SNI → cert por defecto.
* Olvidar `-k` en `curl` y culpar al Ingress del error de verificación: el certificado es autofirmado, es esperado en laboratorio.
* Usar el `nodePort` de HTTP (`32080`) para HTTPS. HTTPS va por `32443`.

## CKA Tip

```bash
openssl req -x509 -newkey rsa:4096 -nodes -days 3650 \
  -keyout k.pem -out c.pem -subj "/CN=<host>" -addext "subjectAltName=DNS:<host>"
k create secret tls <name> --cert=c.pem --key=k.pem -n <ns>
k get secret <name> -o jsonpath='{.type}{"\n"}'
openssl x509 -in c.pem -noout -subject -issuer -dates
curl -kv --resolve <host>:443:<IP> https://<host>/ 2>&1 | grep -E 'subject:|issuer:'
```
