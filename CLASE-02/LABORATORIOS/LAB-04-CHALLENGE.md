# LAB 2.4 — Challenge: `Forbidden` en producción

## Nivel

Challenge / Troubleshooting.

## Duración

18 minutos.

## Objetivo

Diagnosticar y reparar un conjunto de permisos RBAC mal diseñados, aplicando mínimo privilegio y sin conceder de más.

```
IDENTIFICAR -> DIAGNOSTICAR -> CORREGIR -> VALIDAR
```

## Competencias

* Leer un `Forbidden` y extraer identidad, verbo, recurso y namespace.
* Usar `kubectl auth can-i --as` y `--as-group`.
* Distinguir Role de ClusterRole y RoleBinding de ClusterRoleBinding.
* Detectar un permiso **excesivo**, no solo uno insuficiente.

## Escenario

La plataforma tiene dos namespaces de aplicación, `red` y `blue`, y un namespace `project-hamster` para automatización.

El diseño **aprobado por seguridad** es este:

| Identidad | Debe poder | En |
|---|---|---|
| Usuaria `jane` | `get` sobre `secrets` | `red` |
| Usuaria `jane` | `get` y `list` sobre `secrets` | `blue` |
| Usuaria `jane` | `delete` sobre `deployments` | **todos** los namespaces |
| Usuario `jim` | `delete` sobre `deployments` | **solo** `red` |
| ServiceAccount `processor` | `create` sobre `secrets` y `configmaps` | `project-hamster` |

Todo lo demás debe estar **denegado**.

La implementación actual **no coincide** con el diseño. Hay permisos que faltan y hay al menos un permiso concedido de más, que es el que preocupa a seguridad.

## Estado inicial

```bash
cd CLASE-02/RECURSOS/SCRIPTS
./setup-lab.sh
```

Esto crea los namespaces `red`, `blue` y `project-hamster` con un conjunto de Roles, ClusterRoles y Bindings **incorrecto**.

## Requerimientos

1. Audita el estado actual: qué puede hacer realmente cada identidad, usando `kubectl auth can-i`.
2. Construye una tabla comparativa **diseño aprobado vs. estado real**.
3. Corrige la implementación para que coincida **exactamente** con el diseño.
4. Verifica cada fila de la tabla con `kubectl auth can-i --as`.
5. Identifica y documenta el **permiso excesivo** y explica por qué es peligroso.

## Restricciones

* Aplica **mínimo privilegio**: no concedas verbos ni recursos que no aparezcan en la tabla.
* No uses el ClusterRole `cluster-admin` ni `edit` ni `admin` para resolverlo.
* No crees usuarios ni certificados: en Kubernetes los usuarios no son objetos del API. Trabaja con `--as`.
* Mantén los nombres de objetos que ya existen; puedes modificarlos, no renombrarlos.
* La ServiceAccount debe llamarse `processor` y vivir en `project-hamster`.

## Comandos de auditoría

```bash
kubectl -n red  auth can-i get    secrets      --as jane
kubectl -n red  auth can-i list   secrets      --as jane
kubectl -n red  auth can-i delete secrets      --as jane
kubectl -n blue auth can-i list   secrets      --as jane
kubectl        auth can-i delete deployments   --as jane -A
kubectl -n red  auth can-i delete deployments  --as jim
kubectl -n default auth can-i delete deployments --as jim
kubectl -n project-hamster auth can-i create secrets \
  --as system:serviceaccount:project-hamster:processor
kubectl -n project-hamster auth can-i delete secrets \
  --as system:serviceaccount:project-hamster:processor

# Vista global de lo que puede una identidad
kubectl auth can-i --list --as jane -n red
```

## Validación

```bash
kubectl get roles,rolebindings -A | grep -E 'red|blue|hamster'
kubectl get clusterroles,clusterrolebindings | grep -iE 'deploy|hamster'
kubectl -n project-hamster get sa processor

cd CLASE-02/RECURSOS/SCRIPTS && ./validate-lab.sh
```

## Resultado esperado

Cada comando de la tabla de auditoría devuelve exactamente `yes` o `no` según el diseño aprobado:

```
red  / jane / get secrets                -> yes
red  / jane / list secrets               -> no
red  / jane / delete secrets             -> no
blue / jane / list secrets               -> yes
*    / jane / delete deployments         -> yes
red  / jim  / delete deployments         -> yes
default / jim / delete deployments       -> no
project-hamster / processor / create secrets    -> yes
project-hamster / processor / delete secrets    -> no
```

Y `./validate-lab.sh` termina con `LAB 2.4 SUPERADO`.

## Criterios de éxito

- [ ] Tabla diseño vs. real completada antes de tocar nada.
- [ ] Identifiqué y documenté el permiso excesivo.
- [ ] `jane` tiene `get` (y solo `get`) sobre secrets en `red`.
- [ ] `jane` tiene `get` y `list` sobre secrets en `blue`.
- [ ] `jane` puede borrar deployments en **todos** los namespaces.
- [ ] `jim` puede borrar deployments **solo** en `red`.
- [ ] La SA `processor` puede crear secrets y configmaps en `project-hamster` y nada más.
- [ ] No usé `cluster-admin`, `admin` ni `edit`.
- [ ] `./validate-lab.sh` pasa.
