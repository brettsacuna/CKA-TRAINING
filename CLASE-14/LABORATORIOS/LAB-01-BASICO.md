# LAB 14.1 — Helm de principio a fin

## Nivel

Básico.

## Duración

22 minutos.

## Objetivo

Recorrer el ciclo completo de Helm: añadir un repositorio, instalar un chart,
inspeccionar la *release*, cambiar *values* con `upgrade`, hacer `rollback` y
desinstalar. Después, crear un chart esqueleto y renderizarlo sin aplicarlo.

## Competencias

* `helm repo add/update`, `helm search`.
* `helm install/upgrade/rollback/uninstall`.
* `helm list/status/history/get`.
* `helm create` y `helm template`.

## Escenario

Vas a tratar Helm como consumidor: instalar algo, moverte entre versiones y
entender qué genera, antes de escribir tu propio chart en el LAB 14.2.

## Estado inicial

* Namespace de trabajo: **`c14-helm`** (`kubectl create ns c14-helm`).
* `helm` v3 instalado.

## Requerimientos

### Parte A — Instalar un chart

1. Añade un repositorio y refresca el índice:
   ```bash
   helm repo add bitnami https://charts.bitnami.com/bitnami
   helm repo update
   helm search repo bitnami/nginx --versions | head
   ```
   *(Si no hay salida a Internet, usa el chart local: `helm install web ../RECURSOS/CHART/gratitud -n c14-helm` y adapta los pasos.)*
2. Instala una *release* llamada `web`:
   ```bash
   helm install web bitnami/nginx -n c14-helm --set service.type=ClusterIP
   ```
3. Mira la *release* y sus recursos:
   ```bash
   helm list -n c14-helm
   helm status web -n c14-helm
   kubectl -n c14-helm get all -l app.kubernetes.io/instance=web
   ```

### Parte B — Inspeccionar

4. Qué se aplicó realmente y con qué *values*:
   ```bash
   helm get manifest web -n c14-helm | head -40
   helm get values web -n c14-helm            # solo los que cambiaste
   helm get values web -n c14-helm --all      # todos los efectivos
   ```
5. `helm history web -n c14-helm` → una revisión, `deployed`.

### Parte C — Upgrade y rollback

6. Cambia un valor y actualiza:
   ```bash
   helm upgrade web bitnami/nginx -n c14-helm --reuse-values --set replicaCount=3
   kubectl -n c14-helm get deploy -l app.kubernetes.io/instance=web
   helm history web -n c14-helm               # revisión 2
   ```
7. Vuelve a la revisión 1:
   ```bash
   helm rollback web 1 -n c14-helm
   kubectl -n c14-helm get deploy -l app.kubernetes.io/instance=web   # de nuevo 1 réplica
   helm history web -n c14-helm               # revisión 3 = copia de la 1
   ```

### Parte D — Desinstalar

8. `helm uninstall web -n c14-helm` y comprueba que no queda nada:
   ```bash
   helm list -n c14-helm
   kubectl -n c14-helm get all
   ```

### Parte E — Crear y renderizar un chart

9. Genera un esqueleto y explóralo:
   ```bash
   cd /tmp && helm create demo
   find demo -type f
   ```
10. Renderiza SIN aplicar y localiza dónde entran los *values*:
    ```bash
    helm template demo demo | head -60
    helm template demo demo --set replicaCount=5 | grep -A1 'replicas:'
    ```
11. `helm lint demo` → sin errores.

## Restricciones

* No dejes ninguna *release* instalada al terminar.
* Usa siempre `-n c14-helm`; no trabajes en `default`.

## Validación

```bash
helm list -n c14-helm                 # vacío
kubectl -n c14-helm get all           # vacío
helm lint /tmp/demo                   # 0 errores
helm template /tmp/demo /tmp/demo --set replicaCount=5 | grep 'replicas: 5'
```

## Resultado esperado

* `helm install` crea una *release* con sus recursos etiquetados `app.kubernetes.io/instance=web`.
* `helm get manifest`/`values` muestran lo aplicado y los *values* efectivos.
* `helm upgrade` cambia el número de réplicas; `helm rollback 1` lo deshace y añade una revisión nueva.
* `helm uninstall` no deja nada.
* `helm template` renderiza a *stdout* sin tocar el cluster; `--set replicaCount=5` se ve en el `replicas:`.

## Criterios de éxito

- [ ] Instalé un chart y listé sus recursos por la etiqueta de *instance*.
- [ ] Vi lo aplicado con `helm get manifest` y los *values* con `helm get values --all`.
- [ ] Hice `upgrade` de un valor y `rollback` a la revisión 1.
- [ ] Desinstalé sin dejar recursos.
- [ ] Creé un chart con `helm create` y lo rendericé con `helm template`.
- [ ] `helm lint` pasa en el chart esqueleto.
