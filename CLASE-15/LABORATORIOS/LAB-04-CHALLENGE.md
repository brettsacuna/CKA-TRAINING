# LAB 15.4 — Examen teórico: casos reales

## Nivel

Examen teórico.

## Duración

20 minutos.

## Instrucciones

Veinte casos. Para **cada uno**, responde en tres líneas:

1. **Causa más probable** (una frase).
2. **Comando** que la confirma.
3. **Capa / sesión** a la que pertenece.

Sin apuntes. Corrige con la plantilla de respuestas (material del instructor).
Aprobado: **≥ 16 / 20**.

---

## Casos

**1.** Un Service tiene Pods `Running` detrás pero `kubectl get endpointslices` no
muestra ninguna dirección.

**2.** `nslookup web-ci` resuelve, pero `curl http://web-ci` da *timeout*. El
Service tiene endpoints.

**3.** Un `LoadBalancer` lleva 20 minutos con `EXTERNAL-IP <pending>` en un
cluster on-prem.

**4.** Desde un Pod de `gratitud-frontend`, `curl http://api` falla; `curl
http://api.gratitud-api` funciona.

**5.** Un Ingress recién creado no obtiene `ADDRESS` tras dos minutos y no hay
ningún error.

**6.** Un Ingress responde por `/api` pero `/api/health` devuelve `404`.

**7.** Con HTTPS, el navegador muestra un certificado con `CN=TRAEFIK DEFAULT
CERT` en vez del tuyo.

**8.** Un Pod está en `CreateContainerConfigError`. Los eventos dicen *couldn't
find key DB_PASS in Secret*.

**9.** Editaste un ConfigMap hace cinco minutos y el Pod sigue con el valor
antiguo en una variable de entorno.

**10.** Montaste un fichero de un ConfigMap con `subPath` y, tras cambiar el
ConfigMap, el fichero del contenedor no se actualiza.

**11.** Un PVC lleva media hora en `Pending`. `kubectl describe pvc` dice *no
persistent volumes available for this claim*.

**12.** Borras un PVC enlazado a un PV con `persistentVolumeReclaimPolicy:
Retain`. El PV queda en `Released` y no lo puedes volver a usar.

**13.** El `RESTARTS` de un Pod sube sin parar. La aplicación tarda ~20 s en
empezar a responder.

**14.** Un Pod está `Running` pero su Service no tiene endpoints y `RESTARTS`
está a 0.

**15.** `kubectl get pod` muestra `OOMKilled` en `Last State`.

**16.** `kubectl logs deploy/worker` sale vacío. El Pod está `Running` y hace su
trabajo.

**17.** `kubectl top pod` devuelve *Metrics API not available*.

**18.** Una ServiceAccount recibe `Error from server (Forbidden)` al hacer
`kubectl get pods`.

**19.** Tras aplicar un `default deny` de NetworkPolicy, ningún Pod del namespace
resuelve nombres DNS.

**20.** Un Deployment se queda a `0/1` réplicas y el evento del ReplicaSet dice
*violates PodSecurity "restricted"*.

---

## Entrega

Una tabla con las 20 filas: `# · causa · comando · capa`.

## Criterios de éxito

- [ ] Respondí los 20 casos con causa + comando + capa.
- [ ] ≥ 16 aciertos frente a la plantilla.
- [ ] Repasé las sesiones de los casos que fallé.
