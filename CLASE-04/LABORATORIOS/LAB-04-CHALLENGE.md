# LAB 4.4 — Challenge: el despliegue que no arranca

## Nivel

Challenge / Troubleshooting.

## Duración

20 minutos.

## Objetivo

Diagnosticar un Deployment que no consigue levantar ninguna réplica, donde el fallo está repartido entre configuración, secretos y recursos.

```
IDENTIFICAR -> DIAGNOSTICAR -> CORREGIR -> VALIDAR
```

## Competencias

* Distinguir `CreateContainerConfigError`, `CrashLoopBackOff`, `Pending` e `ImagePullBackOff`.
* Rastrear una referencia rota a un ConfigMap o a un Secret.
* Detectar un rollout atascado y explicar por qué no avanza.
* Reparar sin recrear el Deployment.

## Escenario

El equipo de facturación desplegó anoche la versión nueva de **`billing`** y desde entonces **ninguna réplica arranca**. El servicio está caído.

## Estado inicial

```bash
cd CLASE-04/RECURSOS/SCRIPTS
./setup-lab.sh
```

Crea el namespace **`c4-challenge`** con un Deployment `billing`, un Service `billing`, un ConfigMap y un Secret. **No funciona.**

Hay **4 fallos**. No se te dice cuáles.

## Requerimientos

1. Identifica el estado real de los Pods y **qué significa exactamente cada estado** que veas.
2. Encuentra las referencias rotas.
3. Documenta, por cada fallo: síntoma, comando que lo reveló, causa raíz.
4. Corrige hasta que `billing` tenga **3/3** réplicas `Running` y `Ready`.
5. Comprueba que el Service responde.
6. Deja registrada la causa del cambio en el historial del Deployment.

## Restricciones

* **No elimines** el Deployment `billing` ni el Service.
* No pegues valores sensibles en el manifiesto del Deployment: deben venir del Secret.
* No aumentes los `limits` por encima de lo que el nodo puede dar; si un `requests` es irreal, **corrígelo**, no amplíes el cluster.
* No cambies la imagen a una distinta de la familia `nginx`.

## Ruta de diagnóstico sugerida

```
get pods                      -> ¿qué estado exacto?
   |
   +-- Pending                -> describe -> Events -> requests / nodeSelector / taints
   +-- ImagePullBackOff       -> describe -> Events -> nombre y tag de la imagen
   +-- CreateContainerConfigError -> describe -> Events -> ConfigMap / Secret que falta
   +-- CrashLoopBackOff       -> logs / logs --previous
   |
rollout status                -> ¿avanza o está bloqueado?
get cm,secret                 -> ¿existen los nombres referenciados?
describe deploy               -> ¿qué claves referencia exactamente?
```

## Comandos de diagnóstico

```bash
kubectl -n c4-challenge get deploy,rs,pods
kubectl -n c4-challenge describe pod <pod> | sed -n '/Events/,$p'
kubectl -n c4-challenge logs <pod> --previous
kubectl -n c4-challenge get cm,secret
kubectl -n c4-challenge get deploy billing -o yaml | grep -A6 -E 'envFrom|valueFrom|resources|volumes'
kubectl -n c4-challenge rollout status deploy/billing --timeout=20s
kubectl describe node <worker> | sed -n '/Allocatable/,/Allocated/p'
```

## Validación

```bash
kubectl -n c4-challenge get deploy billing         # 3/3
kubectl -n c4-challenge get pods
kubectl -n c4-challenge rollout history deploy/billing
kubectl run tmp --rm -it -n c4-challenge --image=busybox:1.36 --restart=Never -- \
  wget -qO- http://billing

cd CLASE-04/RECURSOS/SCRIPTS && ./validate-lab.sh
```

## Resultado esperado

* `billing` con **3/3** réplicas `Running` y `Ready`.
* El Service `billing` responde con la página de nginx.
* `rollout history` muestra un `CHANGE-CAUSE` describiendo la reparación.
* `./validate-lab.sh` termina con `LAB 4.4 SUPERADO`.

## Criterios de éxito

- [ ] Identifiqué los 4 fallos sin consultar la solución.
- [ ] Sé explicar la diferencia entre los estados que observé.
- [ ] Documenté síntoma, comando y causa raíz de cada fallo.
- [ ] Las 3 réplicas están `Running` y `Ready`.
- [ ] Los valores sensibles siguen viniendo del Secret.
- [ ] El Service responde.
- [ ] Registré la causa del cambio.
- [ ] No eliminé el Deployment ni el Service.
- [ ] `./validate-lab.sh` pasa.
