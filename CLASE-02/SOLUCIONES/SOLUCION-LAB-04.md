# SOLUCIÓN — LAB 2.4 · Challenge RBAC `Forbidden`

> **MATERIAL DEL INSTRUCTOR.**

## Diagnóstico

Seis desviaciones respecto al diseño aprobado. Dos de ellas son **permisos de más**, que es lo que un auditor busca y lo que un alumno principiante nunca mira.

| # | Objeto | Estado real | Diseño | Tipo |
|---|---|---|---|---|
| 1 | Role `secret-manager` en `red` | verbos `get, list` | solo `get` | **exceso** |
| 2 | Role `secret-manager` en `blue` | verbo `get` | `get, list` | falta |
| 3 | Binding de `jane` a `deploy-deleter` | `RoleBinding` en `red` | `ClusterRoleBinding` | falta (alcance) |
| 4 | Binding de `jim` a `deploy-deleter` | `ClusterRoleBinding` | `RoleBinding` en `red` | **exceso grave** |
| 5 | Role `processor` | verbos `create, delete` | solo `create` | **exceso** |
| 6 | RoleBinding `processor` | sujeto `kind: User` | sujeto `kind: ServiceAccount` | falta |

El **permiso excesivo más peligroso** es el #4: `jim` puede borrar Deployments en **todos** los namespaces, incluido `kube-system`. Un `ClusterRoleBinding` donde debía ir un `RoleBinding` es el fallo de RBAC más común y más caro en producción.

## Razonamiento técnico resumido

Las tres combinaciones válidas y su alcance:

| Role usado | Binding usado | Alcance |
|---|---|---|
| `Role` | `RoleBinding` | Ese namespace |
| `ClusterRole` | `ClusterRoleBinding` | Todo el cluster (incluye recursos no namespaced) |
| `ClusterRole` | `RoleBinding` | **Solo ese namespace**, reutilizando la definición |

No es válido: `Role` + `ClusterRoleBinding`.

Además: RBAC es **whitelisting** (todo lo no concedido está denegado) y los permisos son **aditivos** (no existen reglas de denegación; solo se suman).

En Kubernetes **los usuarios no son objetos del API**: `jane` y `jim` solo existen como cadenas dentro de los bindings y en los certificados de cliente. Por eso se auditan con `--as`.

## Procedimiento

```bash
# --- Auditoría inicial
kubectl auth can-i --list --as jane -n red
kubectl auth can-i --list --as jim  -n default
kubectl -n project-hamster auth can-i --list \
  --as system:serviceaccount:project-hamster:processor

# --- 1  quitar el exceso en red
kubectl -n red patch role secret-manager --type=json \
  -p='[{"op":"replace","path":"/rules/0/verbs","value":["get"]}]'

# --- 2  añadir list en blue
kubectl -n blue patch role secret-manager --type=json \
  -p='[{"op":"replace","path":"/rules/0/verbs","value":["get","list"]}]'

# --- 3  jane debe poder en TODOS los namespaces
kubectl -n red delete rolebinding deploy-deleter
kubectl create clusterrolebinding deploy-deleter \
  --clusterrole=deploy-deleter --user=jane

# --- 4  jim SOLO en red  (ClusterRole + RoleBinding)
kubectl delete clusterrolebinding deploy-deleter-jim
kubectl -n red create rolebinding deploy-deleter-jim \
  --clusterrole=deploy-deleter --user=jim

# --- 5  quitar delete a la SA
kubectl -n project-hamster patch role processor --type=json \
  -p='[{"op":"replace","path":"/rules/0/verbs","value":["create"]}]'

# --- 6  el sujeto debe ser la ServiceAccount, no un User
kubectl -n project-hamster delete rolebinding processor
kubectl -n project-hamster create rolebinding processor \
  --role=processor --serviceaccount=project-hamster:processor
```

Equivalente declarativo: `RECURSOS/YAML/01-rbac-diseno-aprobado.yaml` y `02-serviceaccount-processor.yaml`.

## Validación

```bash
cd CLASE-02/RECURSOS/SCRIPTS && ./validate-lab.sh
```

## Resultado esperado

```
  [OK]    red/jane  get secrets = yes
  [OK]    red/jane  list secrets = no
  [OK]    blue/jane list secrets = yes
  [OK]    jane delete deploy (-A) = yes
  [OK]    jim  delete deploy red = yes
  [OK]    jim  delete deploy default = no
  [OK]    SA create secrets = yes
  [OK]    SA delete secrets = no
LAB 2.4 SUPERADO (15 comprobaciones)
```

## Error frecuente

* **Resolver el #3 dando `cluster-admin` a `jane`.** Funciona el `can-i` de deployments y rompe todo el diseño de seguridad. Rechazar la solución.
* Crear un `Role` y luego un `ClusterRoleBinding` que lo referencie: el API server lo acepta sintácticamente pero el binding nunca concede nada. Muy buen momento para mostrarlo en vivo.
* Escribir el sujeto de la ServiceAccount como `--user=processor`. La identidad real es `system:serviceaccount:<ns>:<name>`.
* Olvidar `-n` en `auth can-i` y auditar contra `default` sin darse cuenta.
* Suponer que quitar un verbo de un Role exige recrearlo: `patch` basta.

## CKA Tip

```bash
# Crear RBAC imperativamente (rápido y sin errores de indentación)
k create role     r1 --verb=get,list --resource=pods -n ns1
k create rolebinding rb1 --role=r1 --user=jane -n ns1
k create clusterrole      cr1 --verb=delete --resource=deployments
k create clusterrolebinding crb1 --clusterrole=cr1 --user=jane
k create rolebinding rb2 --clusterrole=cr1 --user=jim -n red   # alcance limitado

# Auditar
k auth can-i <verb> <resource> --as <user> -n <ns>
k auth can-i --list --as <user> -n <ns>
k auth can-i create pods --as system:serviceaccount:<ns>:<sa> -n <ns>
```

**Pregunta que resuelve el 90 % de las tareas RBAC del examen:**
*¿el permiso vale en un namespace o en todos?* La respuesta decide `RoleBinding` o `ClusterRoleBinding`. El `ClusterRole` puede ser el mismo en ambos casos.
