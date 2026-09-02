# SOLUCIÓN — LAB 3.3 · StatefulSet

> **MATERIAL DEL INSTRUCTOR.**

## Diagnóstico

Si el cluster **no tiene StorageClass por defecto**, el StatefulSet se queda en `web-0 Pending` para siempre y el alumno suele culpar al StatefulSet. La causa está en el PVC `www-web-0`, que no encuentra PV. Es una excelente ocasión para aplicar ya el mental model de storage.

## Razonamiento técnico resumido

Las tres garantías del StatefulSet y de dónde salen:

| Garantía | Mecanismo |
|---|---|
| Nombre estable (`web-0`, `web-1`…) | El controlador nombra los Pods por índice ordinal, no por hash |
| Orden de creación y borrado | Política `OrderedReady`: `web-1` no arranca hasta que `web-0` está `Ready` |
| Volumen propio y persistente | `volumeClaimTemplates` crea un PVC **por réplica**: `www-web-N` |
| DNS por Pod | El **Headless Service** (`clusterIP: None`) publica `web-N.<serviceName>.<ns>.svc.cluster.local` |

Los PVC creados por `volumeClaimTemplates` **no se borran** al reducir réplicas ni al eliminar el StatefulSet. Es deliberado: son datos. Kubernetes nunca destruye datos por una operación de escalado.

## Procedimiento

```bash
k create ns c3-sts && k config set-context --current --namespace=c3-sts

# 2  ¿hay StorageClass por defecto?
k get storageclass
#   Si NO la hay:
k apply -f ../RECURSOS/YAML/05-pv-para-statefulset.yaml
ssh root@cka-worker1 'mkdir -p /mnt/sts-0 /mnt/sts-1 /mnt/sts-2'
#   y en el StatefulSet: storageClassName: "" en volumeClaimTemplates

# 3-4
k apply -f ../RECURSOS/YAML/04-statefulset-web.yaml

# 5
k get pods -w        # web-0 -> Ready -> web-1 -> Ready -> web-2

# 6
k get pvc
#   www-web-0, www-web-1, www-web-2   ->  <nombreVolumeClaimTemplate>-<nombreSTS>-<ordinal>

# 7
for i in 0 1 2; do
  k exec web-$i -- sh -c "echo '<h1>soy web-$i</h1>' > /usr/share/nginx/html/index.html"
done

# 8
k run tmp --rm -it --image=busybox:1.36 --restart=Never -- sh
  nslookup nginx                       # devuelve LAS 3 IP de Pod (no una VIP)
  nslookup web-0.nginx
  wget -qO- http://web-0.nginx.c3-sts.svc.cluster.local
  wget -qO- http://web-2.nginx.c3-sts.svc.cluster.local
  wget -qO- http://nginx                # responde CUALQUIERA de los tres
```

**Explicación del paso 8:** el Headless Service no balancea; su registro DNS de tipo A devuelve todas las IP de los Pods listos, y el cliente elige. Los registros por Pod (`web-N.nginx`) apuntan a **un Pod concreto**, que es exactamente lo que necesita una base de datos replicada para hablar con un miembro determinado.

```bash
# 9
k delete pod web-1
k get pods -w
k exec web-1 -- cat /usr/share/nginx/html/index.html    # <h1>soy web-1</h1>
k get pvc                                                # sigue siendo www-web-1

# 10
k scale statefulset web --replicas=5
k get pvc                       # aparecen www-web-3 y www-web-4
k scale statefulset web --replicas=3
k get pods                      # 3 Pods
k get pvc                       # www-web-3 y www-web-4 SIGUEN EXISTIENDO

# 11
k delete statefulset web --cascade=orphan   # o simplemente k delete sts web
k get pvc                                    # los 5 PVC siguen ahí
k apply -f ../RECURSOS/YAML/04-statefulset-web.yaml
k exec web-0 -- cat /usr/share/nginx/html/index.html    # <h1>soy web-0</h1>
```

## Validación

```bash
k get sts,pods,pvc,svc
k get svc nginx -o jsonpath='{.spec.clusterIP}{"\n"}'    # None
k get pvc -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,VOL:.spec.volumeName
```

## Resultado esperado

```
NAME                    READY
statefulset.apps/web    3/3

NAME        READY   STATUS
pod/web-0   1/1     Running
pod/web-1   1/1     Running
pod/web-2   1/1     Running

NAME                        STATUS   CAPACITY
persistentvolumeclaim/www-web-0   Bound   1Gi
persistentvolumeclaim/www-web-1   Bound   1Gi
persistentvolumeclaim/www-web-2   Bound   1Gi
```

## Error frecuente

* **`serviceName` distinto del nombre del Headless Service.** El StatefulSet arranca igual, pero el DNS por Pod no se crea y `web-0.nginx` no resuelve. Fallo silencioso y muy típico.
* Olvidar `clusterIP: None` y crear un Service normal: se pierde el direccionamiento individual.
* Definir el volumen en `spec.template.spec.volumes` en lugar de en `volumeClaimTemplates`: todas las réplicas compartirían el mismo PVC, que es justo lo contrario del requisito.
* Poner `volumeClaimTemplates` dentro de `spec.template`. Va al mismo nivel que `template`, colgando de `spec`.
* Intentar cambiar `volumeClaimTemplates` de un StatefulSet existente: es inmutable. Hay que recrear el StatefulSet (los PVC sobreviven).
* Borrar los PVC "para limpiar" y perder los datos de la demostración del paso 11.

## CKA Tip

```bash
# Plantilla base (no hay generador imperativo para StatefulSet: parte de la doc o de un ejemplo)
k explain statefulset.spec.volumeClaimTemplates
k explain statefulset.spec.serviceName

# Comprobar el DNS por Pod en un segundo
k run tmp --rm -it --image=busybox:1.36 --restart=Never -- nslookup web-0.nginx.<ns>

# Los PVC de un StatefulSet nunca se borran solos
k get pvc -l app=nginx
```

**Regla:** `serviceName` del StatefulSet **debe** ser el nombre del Headless Service. Es el enlace que hace funcionar el DNS por Pod.
