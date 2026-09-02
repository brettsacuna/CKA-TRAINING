# SOLUCIÓN — LAB 13.1 · Una ServiceAccount con permisos mínimos

> **MATERIAL DEL INSTRUCTOR.**

## Diagnóstico

1. **Un `Role`/`ClusterRole` no concede nada por sí solo**: es una lista de reglas. Hace falta un *binding*.
2. **Ámbito.** `Role`/`RoleBinding` viven en un namespace. `ClusterRole`/`ClusterRoleBinding` son de cluster; un `ClusterRole` también es obligatorio para recursos sin namespace (`nodes`, `persistentvolumes`).
3. **`RoleBinding` a un `ClusterRole`**: reutiliza la definición pero la aplica **solo** en el namespace del binding.
4. **`auth can-i --as`** es la forma de verificar sin cambiar de identidad.

## Procedimiento

```bash
k create ns c13-rbac
k -n c13-rbac create serviceaccount app-reader
SA=system:serviceaccount:c13-rbac:app-reader

# A - sin permisos
k auth can-i list pods -n c13-rbac --as=$SA        # no

# B - solo lectura de pods
k -n c13-rbac create role pod-reader --verb=get,list,watch --resource=pods
k -n c13-rbac create rolebinding app-reader-bind --role=pod-reader --serviceaccount=c13-rbac:app-reader
k auth can-i list pods   -n c13-rbac --as=$SA      # yes
k auth can-i create pods -n c13-rbac --as=$SA      # no
k auth can-i list pods   -n default  --as=$SA      # no

# C - ampliar
k -n c13-rbac create role pod-reader --verb=get,list,watch,create,delete --resource=pods,configmaps \
  --dry-run=client -o yaml | k apply -f -
k auth can-i create configmaps -n c13-rbac --as=$SA   # yes

# D - recurso sin namespace
k create clusterrole node-reader --verb=get,list --resource=nodes
k create clusterrolebinding app-reader-nodes --clusterrole=node-reader --serviceaccount=c13-rbac:app-reader
k auth can-i list nodes --as=$SA                   # yes

# E - RoleBinding a un ClusterRole por defecto
k -n c13-rbac create rolebinding app-reader-view --clusterrole=view --serviceaccount=c13-rbac:app-reader
k auth can-i list services -n c13-rbac --as=$SA    # yes
k auth can-i list services -n default  --as=$SA    # no
```

Equivalente declarativo: `../RECURSOS/YAML/01-rbac-basico.yaml`.

## Validación

```bash
k auth can-i --list -n c13-rbac --as=system:serviceaccount:c13-rbac:app-reader
```

## Resultado esperado

| Comprobación | Resultado |
|---|---|
| `list pods` en `c13-rbac` | yes |
| `create configmaps` en `c13-rbac` | yes |
| `list nodes` (cluster) | yes |
| `list services` en `c13-rbac` | yes (por `view`) |
| `list services` en `default` | no |
| cualquier cosa sin binding | no |

## Error frecuente

* Crear el `Role` y olvidar el `RoleBinding`: no concede nada.
* Usar un `RoleBinding` para dar acceso a `nodes` o `persistentvolumes` (recursos sin namespace): hace falta `ClusterRoleBinding`.
* Esperar que un `RoleBinding` a `view` dé acceso en todos los namespaces. Solo en el suyo.
* Probar los permisos con `kubectl --as` sin `auth can-i` y pelearse con errores confusos; `can-i --list` es más claro.
* Olvidar el `apiGroups: [""]` para los recursos del *core* (pods, services, configmaps).

## CKA Tip

```bash
k create role R --verb=get,list,watch --resource=pods,deployments.apps --dry-run=client -o yaml
k create rolebinding RB --role=R --serviceaccount=NS:SA
k create clusterrolebinding CRB --clusterrole=view --user=jane
k auth can-i VERB RESOURCE -n NS --as=system:serviceaccount:NS:SA
k auth can-i --list --as=system:serviceaccount:NS:SA -n NS
```
