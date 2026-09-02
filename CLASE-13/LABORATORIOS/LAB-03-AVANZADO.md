# LAB 13.3 — Endurecer los contenedores de GRATITUD

## Nivel

Avanzado.

## Duración

30 minutos.

## Objetivo

Dejar la API de GRATITUD corriendo como usuario sin privilegios, sin
*capabilities*, con `seccomp` y con la raíz en solo lectura, y que el namespace
**rechace** cualquier Pod que no cumpla el nivel `restricted` —todo **a partir de
requerimientos**.

## Competencias

* Escribir un `securityContext` de Pod y de contenedor.
* Aplicar los Pod Security Standards con las etiquetas del namespace.
* Usar `warn`/`audit` para medir el impacto antes de `enforce`.
* Montar `emptyDir` para las rutas escribibles cuando la raíz es de solo lectura.

## Escenario

Seguridad exige lo siguiente para el Deployment `api` del namespace
**`gratitud-api`**:

| # | Requisito |
|---|---|
| R1 | El contenedor **no** puede correr como `root` (`runAsNonRoot`, UID ≠ 0). |
| R2 | No puede escalar privilegios (`allowPrivilegeEscalation: false`). |
| R3 | No tiene **ninguna** *capability* del kernel (`drop: [ALL]`). |
| R4 | Aplica el perfil `seccomp` `RuntimeDefault`. |
| R5 | La raíz del contenedor es de **solo lectura**; lo escribible va en `emptyDir`. |
| R6 | El namespace `gratitud-api` **rechaza** (`enforce`) cualquier Pod que no cumpla `restricted`, y **avisa** (`warn`) con la misma vara. |

Tú decides los valores y el orden.

## Estado inicial

```bash
kubectl apply -f ../RECURSOS/YAML/04-gratitud-api-plano.yaml
```

Namespace `gratitud-api` con el Deployment `api`
(`nginxinc/nginx-unprivileged:1.27-alpine`, escucha en 8080) **sin** ningún
`securityContext` y **sin** etiquetas de Pod Security.

## Pistas de método (no de solución)

* Empieza midiendo: `kubectl label ns gratitud-api pod-security.kubernetes.io/warn=restricted pod-security.kubernetes.io/audit=restricted` y vuelve a hacer `apply` para ver los avisos.
* `securityContext` de **Pod** (`runAsNonRoot`, `seccompProfile`, `fsGroup`) y de **contenedor** (`allowPrivilegeEscalation`, `capabilities`, `runAsUser`, `readOnlyRootFilesystem`). Gana el del contenedor.
* La imagen `nginx-unprivileged` ya corre como UID `101`; aun así hay que declararlo.
* Con `readOnlyRootFilesystem: true`, `nginx-unprivileged` necesita `emptyDir` en `/tmp`, `/var/cache/nginx` y `/var/run` (ahí escribe el `nginx.pid`).
* Solo cuando `warn` no proteste, pon `enforce=restricted`.
* `kubectl -n gratitud-api get events` muestra `FailedCreate ... violates PodSecurity` si el `enforce` rechaza el Pod.

## Validación

```bash
kubectl get ns gratitud-api --show-labels | tr ',' '\n' | grep pod-security
kubectl -n gratitud-api rollout status deploy/api
kubectl -n gratitud-api get pod -l app=gratitud-api \
  -o jsonpath='{.items[0].spec.securityContext} | {.items[0].spec.containers[0].securityContext}{"\n"}'

# dentro del contenedor
P=$(kubectl -n gratitud-api get pod -l app=gratitud-api -o name | head -1)
kubectl -n gratitud-api exec $P -- id                       # uid != 0
kubectl -n gratitud-api exec $P -- sh -c 'touch /probando' 2>&1   # Read-only file system
kubectl -n gratitud-api exec $P -- sh -c 'grep Cap /proc/1/status'  # CapEff: 0000000000000000
```

## Resultado esperado

* `gratitud-api` con `pod-security.kubernetes.io/enforce=restricted` y `warn=restricted`.
* El Deployment `api` **desplegando** (el `securityContext` cumple `restricted`).
* Dentro del contenedor: `id` da UID ≠ 0; `/` es de solo lectura; `CapEff` a cero.
* Un Pod de prueba sin `securityContext` en ese namespace es **rechazado**.

## Criterios de éxito

- [ ] Medí con `warn`/`audit` antes de `enforce`.
- [ ] `api` corre como no-root con UID explícito.
- [ ] `allowPrivilegeEscalation: false` y `capabilities.drop: [ALL]`.
- [ ] `seccompProfile: RuntimeDefault`.
- [ ] `readOnlyRootFilesystem: true` con `emptyDir` en las rutas escribibles.
- [ ] `gratitud-api` con `enforce=restricted` y `api` sigue desplegando.
