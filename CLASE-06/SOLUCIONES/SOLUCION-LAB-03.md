# SOLUCIÓN — LAB 6.3 · Cadena de fallos

> **MATERIAL DEL INSTRUCTOR.**

## Diagnóstico

**6 fallos encadenados.** Cada corrección destapa el siguiente.

| # | Capa | Síntoma | Comando | Causa raíz |
|---|---|---|---|---|
| 1 | **RBAC** | La SA `deployer` no puede desplegar | `auth can-i --list --as system:serviceaccount:c6-pedidos:deployer` | El `RoleBinding` tiene como sujeto un **User** llamado `deployer`, no la ServiceAccount; y el Role solo concede `get` sobre `pods` |
| 2 | **Scheduling** | Pods `Pending`, `Insufficient cpu` | `describe pod pedidos-0` | `requests.cpu: "6"`: ningún nodo lo ofrece |
| 3 | **Storage** | PVC `Pending` | `get pvc` + `describe pvc` | `storageClassName: inexistente` |
| 4 | **Configuración** | `CreateContainerConfigError` | `describe pod` + `get cm` | `envFrom` referencia `pedidos-config`; el real es `pedidos-cfg` |
| 5 | **Configuración** | `CreateContainerConfigError` | `get secret pedidos-secret -o jsonpath='{.data}'` | `secretKeyRef.key: password`; la clave real es `db-password` |
| 6 | **Red / DNS** | `pedidos-0.pedidos` no resuelve | `get sts pedidos -o jsonpath='{.spec.serviceName}'` + `get svc` | `serviceName: pedidos-headless` (no existe) y el Service `pedidos` selecciona `app=pedidos-v2` |

## Razonamiento técnico resumido

El orden **no es negociable**: sin permisos no operas; sin nodo no hay Pod; sin volumen el Pod no monta; sin configuración el contenedor no arranca; sin contenedor no hay red que probar.

```
PERMISOS -> SCHEDULING -> STORAGE -> CONFIGURACIÓN -> APLICACIÓN -> RED
```

Intentar diagnosticar la red mientras el Pod está `Pending` es la forma más rápida de perder veinte minutos.

## Procedimiento

```bash
NS=c6-pedidos
SA=system:serviceaccount:c6-pedidos:deployer

# --- 1  RBAC (mínimo privilegio: desplegar y consultar, nada más)
k -n $NS auth can-i --list --as $SA
k -n $NS delete rolebinding deployer
k -n $NS apply -f - <<'YAML'
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata: {name: deployer, namespace: c6-pedidos}
rules:
  - apiGroups: ["apps"]
    resources: ["statefulsets", "deployments"]
    verbs: ["get","list","watch","create","update","patch"]
  - apiGroups: [""]
    resources: ["pods","services","persistentvolumeclaims","configmaps"]
    verbs: ["get","list","watch"]
YAML
k -n $NS create rolebinding deployer --role=deployer \
  --serviceaccount=c6-pedidos:deployer

# --- 2  Scheduling
k -n $NS describe pod pedidos-0 | sed -n '/Events/,$p'
k -n $NS patch sts pedidos --type=json -p='[
  {"op":"replace","path":"/spec/template/spec/containers/0/resources/requests/cpu","value":"100m"}]'

# --- 3  Storage. volumeClaimTemplates es inmutable: hay que recrear el STS.
#        Se recrea con --cascade=orphan para no perder los Pods... pero como los PVC
#        estan Pending, aqui es limpio borrar STS y PVC y rehacerlo.
k -n $NS delete sts pedidos --cascade=orphan
k -n $NS delete pvc -l app=pedidos --ignore-not-found

# --- 4, 5 y 6 se corrigen en el manifiesto nuevo del StatefulSet
k -n $NS get cm                      # pedidos-cfg
k -n $NS get secret pedidos-secret -o jsonpath='{.data}{"\n"}'   # {"db-password": ...}

k -n $NS patch svc pedidos -p '{"spec":{"selector":{"app":"pedidos"}}}'

k -n $NS apply -f - <<'YAML'
apiVersion: apps/v1
kind: StatefulSet
metadata: {name: pedidos, namespace: c6-pedidos}
spec:
  serviceName: pedidos
  replicas: 3
  selector: {matchLabels: {app: pedidos}}
  template:
    metadata: {labels: {app: pedidos}}
    spec:
      containers:
        - name: app
          image: nginx:1.27-alpine
          ports: [{containerPort: 80, name: http}]
          envFrom: [{configMapRef: {name: pedidos-cfg}}]
          env:
            - name: DB_PASSWORD
              valueFrom: {secretKeyRef: {name: pedidos-secret, key: db-password}}
          resources: {requests: {cpu: "100m", memory: "64Mi"}}
          volumeMounts: [{name: datos, mountPath: /data}]
  volumeClaimTemplates:
    - metadata: {name: datos, labels: {app: pedidos}}
      spec:
        accessModes: ["ReadWriteOnce"]
        resources: {requests: {storage: 1Gi}}
YAML
```

> Si el cluster no tiene StorageClass por defecto, crea antes tres PV de 1Gi con `storageClassName: ""` y ajusta el `volumeClaimTemplates`.

```bash
# --- validación de la red
k -n $NS run tmp --rm -it --image=busybox:1.36 --restart=Never -- \
  sh -c 'nslookup pedidos-0.pedidos; wget -qO- http://pedidos-0.pedidos'
```

## Validación

```bash
cd CLASE-06/RECURSOS/SCRIPTS && ./validate-lab.sh cadena
```

## Resultado esperado

```
  [OK]    StatefulSet pedidos con 3 replicas Ready
  [OK]    3 PVC en Bound
  [OK]    serviceName apunta a un Service existente (pedidos)
  [OK]    El Headless Service selecciona app=pedidos
  [OK]    /data escribible en pedidos-0
  [OK]    la configuracion llega al contenedor
  [OK]    la credencial llega al contenedor
  [OK]    deployer puede crear statefulsets
  [OK]    deployer NO puede borrar secrets
LAB 6.3 SUPERADO
```

## Error frecuente

* Dar `cluster-admin` a `deployer` "para descartar el RBAC". Prohibido, y además enseña el hábito contrario al que se busca.
* Intentar editar `volumeClaimTemplates` de un StatefulSet existente: es inmutable. Hay que recrear el StatefulSet.
* Diagnosticar el DNS con los Pods en `Pending`.
* Corregir el `serviceName` y olvidar el selector del Service (o al revés): hacen falta los dos para el DNS por Pod.
* Poner el sujeto del RoleBinding como `User: deployer`. La identidad de una SA es `system:serviceaccount:<ns>:<nombre>`.

## CKA Tip

```bash
# Auditoría completa de una identidad, en un comando
k auth can-i --list --as system:serviceaccount:<ns>:<sa> -n <ns>

# Estado global de un namespace, en un comando
k -n <ns> get all,pvc,cm,secret,networkpolicy

# ¿Qué claves tiene realmente este Secret?
k -n <ns> get secret <s> -o jsonpath='{.data}{"\n"}'
```

**Diagnostica siempre de abajo hacia arriba.** Un Pod que no arranca no puede tener un problema de red.
