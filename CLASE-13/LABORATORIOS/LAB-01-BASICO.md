# LAB 13.1 — Una ServiceAccount con permisos mínimos

## Nivel

Básico.

## Duración

22 minutos.

## Objetivo

Crear una ServiceAccount, darle un `Role` acotado con un `RoleBinding`, probar con
`kubectl auth can-i --as`, y ver de primera mano la diferencia entre un permiso
*namespaced* y uno de cluster.

## Competencias

* Crear `ServiceAccount`, `Role`, `RoleBinding`, `ClusterRole`, `ClusterRoleBinding`.
* Comprobar permisos con `kubectl auth can-i` y `--as`.
* Distinguir el ámbito de cada objeto.

## Escenario

Vas a darle a una aplicación exactamente los permisos que necesita —ni uno más— y
a verificar cada paso antes de seguir.

## Estado inicial

* Namespace de trabajo: **`c13-rbac`**.

## Requerimientos

### Parte A — Sin permisos

1. Crea el namespace `c13-rbac` y una ServiceAccount `app-reader`:
   ```bash
   kubectl create ns c13-rbac
   kubectl -n c13-rbac create serviceaccount app-reader
   ```
2. Comprueba que, sin ningún binding, no puede hacer nada:
   ```bash
   kubectl auth can-i list pods -n c13-rbac \
     --as=system:serviceaccount:c13-rbac:app-reader        # no
   kubectl auth can-i --list -n c13-rbac \
     --as=system:serviceaccount:c13-rbac:app-reader        # solo lo de todo el mundo (selfsubjectreviews...)
   ```

### Parte B — Solo lectura de Pods

3. Crea un `Role` de solo lectura de Pods y enlázalo a la SA:
   ```bash
   kubectl -n c13-rbac create role pod-reader \
     --verb=get,list,watch --resource=pods
   kubectl -n c13-rbac create rolebinding app-reader-bind \
     --role=pod-reader --serviceaccount=c13-rbac:app-reader
   ```
4. Verifica:
   ```bash
   kubectl auth can-i list pods   -n c13-rbac --as=system:serviceaccount:c13-rbac:app-reader   # yes
   kubectl auth can-i create pods -n c13-rbac --as=system:serviceaccount:c13-rbac:app-reader   # no
   kubectl auth can-i list pods   -n default  --as=system:serviceaccount:c13-rbac:app-reader   # no (otro namespace)
   ```

### Parte C — Ampliar el Role

5. Añade `create` y `delete` sobre `configmaps` al mismo `Role` (`kubectl edit role pod-reader` o recreándolo).
6. Vuelve a verificar `can-i create configmaps` y `can-i delete configmaps` en `c13-rbac`.

### Parte D — Un permiso de cluster

7. Crea un `ClusterRole` para leer nodos y un `ClusterRoleBinding` a la SA:
   ```bash
   kubectl create clusterrole node-reader --verb=get,list --resource=nodes
   kubectl create clusterrolebinding app-reader-nodes \
     --clusterrole=node-reader --serviceaccount=c13-rbac:app-reader
   ```
8. Verifica `kubectl auth can-i list nodes --as=system:serviceaccount:c13-rbac:app-reader` → `yes`. Los nodos no tienen namespace: hace falta un binding de cluster.

### Parte E — RoleBinding a un ClusterRole

9. Enlaza el `ClusterRole` por defecto `view` a la SA **solo dentro de `c13-rbac`**:
   ```bash
   kubectl -n c13-rbac create rolebinding app-reader-view \
     --clusterrole=view --serviceaccount=c13-rbac:app-reader
   ```
10. Comprueba que ahora puede `list services` en `c13-rbac` pero **no** en `default`: un `RoleBinding` a un `ClusterRole` solo aplica en su namespace.

## Restricciones

* No uses el `ClusterRole` `cluster-admin` en ningún momento.
* Cada ampliación de permisos debe verificarse con `auth can-i` antes de pasar a la siguiente parte.

## Validación

```bash
SA=system:serviceaccount:c13-rbac:app-reader
kubectl auth can-i list pods       -n c13-rbac --as=$SA    # yes
kubectl auth can-i create configmaps -n c13-rbac --as=$SA  # yes
kubectl auth can-i list nodes                   --as=$SA   # yes
kubectl auth can-i list services   -n c13-rbac --as=$SA    # yes
kubectl auth can-i list services   -n default  --as=$SA    # no
kubectl auth can-i --list          -n c13-rbac --as=$SA
```

## Resultado esperado

* Sin binding: la SA no puede nada.
* Con `pod-reader`: `get/list/watch pods` en `c13-rbac`, nada más y solo ahí.
* Tras ampliar: `create/delete configmaps` en `c13-rbac`.
* Con el `ClusterRoleBinding`: `list nodes` en todo el cluster.
* Con el `RoleBinding` a `view`: lectura amplia **solo** en `c13-rbac`.

## Criterios de éxito

- [ ] La SA sin binding no tiene permisos.
- [ ] El `Role` + `RoleBinding` concede solo lo declarado y solo en su namespace.
- [ ] Amplié el `Role` y lo verifiqué.
- [ ] Usé un `ClusterRoleBinding` para un recurso sin namespace (`nodes`).
- [ ] Comprobé que un `RoleBinding` a un `ClusterRole` no cruza el namespace.
- [ ] No usé `cluster-admin`.
