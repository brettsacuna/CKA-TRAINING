# SOLUCIÓN — LAB 14.1 · Helm de principio a fin

> **MATERIAL DEL INSTRUCTOR.**

## Diagnóstico

1. **Una *release* es una instancia de un chart** con un nombre y unos *values*. Helm guarda cada revisión en un `Secret` del namespace (`sh.helm.release.v1.<rel>.v<n>`).
2. **`helm get manifest`** muestra lo que se aplicó; **`helm get values --all`** los *values* efectivos (defaults + overrides).
3. **`rollback` no borra revisiones**: crea una nueva que es copia de la elegida.
4. **`helm template`** renderiza sin aplicar: es el modo "generador".

## Procedimiento

```bash
k create ns c14-helm

# A
helm repo add bitnami https://charts.bitnami.com/bitnami && helm repo update
helm install web bitnami/nginx -n c14-helm --set service.type=ClusterIP
helm list -n c14-helm
k -n c14-helm get all -l app.kubernetes.io/instance=web

# B
helm get manifest web -n c14-helm | head -40
helm get values web -n c14-helm --all

# C
helm upgrade web bitnami/nginx -n c14-helm --reuse-values --set replicaCount=3
helm history web -n c14-helm          # rev 2
helm rollback web 1 -n c14-helm
helm history web -n c14-helm          # rev 3 (= rev 1)
k -n c14-helm get deploy -l app.kubernetes.io/instance=web   # 1 replica

# D
helm uninstall web -n c14-helm
helm list -n c14-helm ; k -n c14-helm get all

# E
cd /tmp && helm create demo
helm lint demo
helm template demo demo --set replicaCount=5 | grep -A1 'replicas:'
```

Sin salida a Internet: `helm install web ../RECURSOS/CHART/gratitud -n c14-helm`
y los mismos pasos.

## Validación

```bash
helm list -n c14-helm        # vacío
helm lint /tmp/demo          # 0 errores
helm template /tmp/demo /tmp/demo --set replicaCount=5 | grep 'replicas: 5'
```

## Resultado esperado

* `web` instalada, actualizada a 3 réplicas y revertida a 1, todo con historial.
* `helm uninstall` no deja recursos.
* El chart esqueleto pasa `helm lint` y responde a `--set`.

## Error frecuente

* `helm upgrade` sin `--reuse-values` ni `-f`: se pierden los *values* anteriores y vuelve a los defaults.
* Buscar los recursos por `app=nginx` en vez de por `app.kubernetes.io/instance=<release>`.
* Creer que `helm rollback` borra la revisión "mala": la deja en el historial.
* Editar los recursos con `kubectl` en vez de con `helm upgrade`: el siguiente `upgrade` los pisa.
* `helm delete` (alias antiguo) esperando que conserve el historial: `helm uninstall` lo borra salvo `--keep-history`.

## CKA Tip

```bash
helm repo add <n> <url> && helm repo update
helm install <rel> <chart> -n <ns> [-f values.yaml] [--set k=v]
helm upgrade --install <rel> <chart> -n <ns> --reuse-values --set k=v
helm history <rel> -n <ns> ; helm rollback <rel> <rev> -n <ns>
helm get manifest <rel> -n <ns> ; helm get values <rel> -n <ns> --all
helm template <rel> <chart> [--set k=v]        # render sin aplicar
```
