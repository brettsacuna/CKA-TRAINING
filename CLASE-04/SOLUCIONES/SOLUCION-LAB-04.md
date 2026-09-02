# SOLUCIÓN — LAB 4.4 · Challenge `billing`

> **MATERIAL DEL INSTRUCTOR.**

## Diagnóstico

**4 fallos.** Se manifiestan por capas: hasta que no se resuelve el scheduling, no se ve el error de imagen; hasta que no se resuelve la imagen, no se ven los de configuración.

| # | Síntoma | Comando que lo revela | Causa raíz |
|---|---|---|---|
| 1 | Pods `Pending`, `0/3 nodes are available: Insufficient cpu` | `k -n c4-challenge describe pod <p>` | `requests.cpu: "8"` y `limits.cpu: "10"`: ningún nodo tiene esa capacidad |
| 2 | `ImagePullBackOff` / `ErrImagePull` | `describe pod` → Events | Imagen `nginx:1.99-alpine`, tag inexistente |
| 3 | `CreateContainerConfigError`: `configmap "billing-config" not found` | `describe pod` + `k get cm` | El `envFrom` referencia `billing-config`; el ConfigMap real se llama **`billing-cfg`** |
| 4 | `CreateContainerConfigError`: `couldn't find key password in Secret` | `describe pod` + `k get secret billing-secret -o yaml` | El `secretKeyRef` pide la clave `password`; la clave real es **`db-password`** |

## Razonamiento técnico resumido

Los estados dicen exactamente en qué fase falló el Pod:

| Estado | Fase | Dónde mirar |
|---|---|---|
| `Pending` | El scheduler no encontró nodo | `describe pod` → Events |
| `ImagePullBackOff` | Ya hay nodo; falla la descarga | Events, nombre y tag de la imagen |
| `CreateContainerConfigError` | Falta un ConfigMap, un Secret o una clave | Events + `get cm,secret` |
| `CrashLoopBackOff` | El contenedor arrancó y murió | `logs` y `logs --previous` |
| `Running` pero `0/1 READY` | Falla la readinessProbe | `describe pod` → Conditions |

`CreateContainerConfigError` es el estado que el material original no cubría y que aparece constantemente en el examen.

## Procedimiento

```bash
NS=c4-challenge

# --- Reconocimiento
k -n $NS get deploy,rs,pods
k -n $NS describe pod -l app=billing | sed -n '/Events/,$p'
k -n $NS get cm,secret
k describe node cka-worker1 | sed -n '/Allocatable/,/Allocated/p'

# --- Fallo 1: requests irreales
k -n $NS set resources deploy/billing \
  --requests=cpu=100m,memory=64Mi --limits=cpu=500m,memory=256Mi

# --- Fallo 2: tag de imagen inexistente
k -n $NS set image deploy/billing app=nginx:1.27-alpine

# --- Fallo 3: nombre del ConfigMap
k -n $NS get cm     # billing-cfg
k -n $NS patch deploy billing --type=json \
  -p='[{"op":"replace","path":"/spec/template/spec/containers/0/envFrom/0/configMapRef/name","value":"billing-cfg"}]'

# --- Fallo 4: clave del Secret
k -n $NS get secret billing-secret -o jsonpath='{.data}{"\n"}'   # {"db-password":"..."}
k -n $NS patch deploy billing --type=json \
  -p='[{"op":"replace","path":"/spec/template/spec/containers/0/env/0/valueFrom/secretKeyRef/key","value":"db-password"}]'

# --- Registro del cambio
k -n $NS annotate deploy/billing \
  kubernetes.io/change-cause="Fix: requests realistas, tag de imagen, nombre de ConfigMap y clave de Secret" \
  --overwrite

k -n $NS rollout status deploy/billing
```

Alternativa admitida: un único `kubectl -n c4-challenge edit deploy billing` corrigiendo las cuatro cosas de golpe. Es más rápido, y en el examen suele serlo. Pero conviene que el alumno haga primero el diagnóstico uno a uno para aprender a leer los estados.

## Validación

```bash
k -n c4-challenge get deploy billing        # 3/3
k -n c4-challenge get pods
k -n c4-challenge exec deploy/billing -- env | grep -E 'APP_MODE|LOG_LEVEL|DB_PASSWORD'
k run tmp --rm -it -n c4-challenge --image=busybox:1.36 --restart=Never -- wget -qO- http://billing
k -n c4-challenge rollout history deploy/billing

cd CLASE-04/RECURSOS/SCRIPTS && ./validate-lab.sh
```

## Resultado esperado

```
NAME      READY   UP-TO-DATE   AVAILABLE
billing   3/3     3            3

APP_MODE=prod
LOG_LEVEL=info
DB_PASSWORD=F4ctur4cion2026

LAB 4.4 SUPERADO
```

## Error frecuente

* **Pegar la contraseña en `env.value`** para "saltarse" el problema del Secret. Rompe la restricción y es exactamente la práctica que el laboratorio combate. El validador lo detecta.
* **Renombrar el ConfigMap** en lugar de corregir la referencia. Funciona, pero en un cluster real ese ConfigMap puede estar en uso por otros objetos. Discútelo.
* Subir los `limits` en lugar de bajar los `requests`: no arregla nada, el `Pending` lo causa el `requests`.
* Quedarse en el primer error. Los estados van apareciendo en cascada: hay que volver a `describe` después de cada corrección.
* No registrar el `change-cause` y perder el punto del validador.

## CKA Tip

```bash
# El comando que más rinde en un Pod que no arranca
k -n <ns> describe pod <pod> | sed -n '/Events/,$p'

# ¿Existe realmente lo que referencia el Pod?
k -n <ns> get cm,secret
k -n <ns> get secret <s> -o jsonpath='{.data}{"\n"}'    # nombres de las claves

# Correcciones quirúrgicas
k set image     deploy/<d> <c>=<img>
k set resources deploy/<d> --requests=cpu=100m,memory=64Mi
k patch deploy <d> --type=json -p='[{"op":"replace","path":"/spec/...","value":"..."}]'
```

**Regla de lectura de estados:** `Pending` = scheduler · `ImagePullBackOff` = registry · `CreateContainerConfigError` = ConfigMap/Secret · `CrashLoopBackOff` = tu aplicación · `Running 0/1` = readinessProbe.
