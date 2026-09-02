# SOLUCIÓN — LAB 14.4 · Challenge «el chart de GRATITUD no despliega»

> **MATERIAL DEL INSTRUCTOR.**

## Los 4 fallos

| # | Fichero · línea | Fallo | Síntoma | Corrección |
|---|---|---|---|---|
| 1 | `Chart.yaml` | Falta `apiVersion` | `helm lint` → *apiVersion is required* | Añadir `apiVersion: v2` |
| 2 | `templates/deployment.yaml` | `image: "{{ .Values.image.repo }}:..."` (es `repository`) | `helm template` → `image: ":1.27-alpine"`; Pod `InvalidImageName` | `{{ .Values.image.repository }}` |
| 3 | `templates/deployment.yaml` | `replicas: {{ .Values.replicas \| default 2 }}` (es `replicaCount`) | `--set replicaCount=3` no cambia nada: `replicas: 2` | `replicas: {{ .Values.replicaCount }}` |
| 4 | `templates/service.yaml` | `targetPort: {{ .Values.service.port }}` (80) | Service con endpoints al puerto 80; el contenedor escucha en 8080 | `targetPort: {{ .Values.service.targetPort }}` |

## Método

Los fallos 1 y 2 se ven **sin cluster**, con `helm lint` y `helm template`. Los 3
y 4 requieren instalar y mirar el Deployment y el `endpoints`.

## Procedimiento

```bash
cd CLASE-14/RECURSOS/SCRIPTS && ./setup-lab.sh
cd "$(dirname "$0")" 2>/dev/null; cd CLASE-14/RECURSOS/SCRIPTS   # trabaja aquí

# ---- Fallo 1 ----
helm lint chart-lab/gratitud
# [ERROR] Chart.yaml: apiVersion is required. The value must be either "v1" or "v2"
sed -i '1i apiVersion: v2' chart-lab/gratitud/Chart.yaml
helm lint chart-lab/gratitud                                    # 0 errores

# ---- Fallo 2 ----
helm template t chart-lab/gratitud | grep 'image:'
# image: ":1.27-alpine"
grep -n 'image:' chart-lab/gratitud/templates/deployment.yaml
sed -i 's/\.Values\.image\.repo /\.Values\.image\.repository /' chart-lab/gratitud/templates/deployment.yaml
helm template t chart-lab/gratitud | grep 'image:'             # nginxinc/nginx-unprivileged:1.27-alpine

# ---- Fallo 3 ----
helm template t chart-lab/gratitud --set replicaCount=3 | grep 'replicas:'
# replicas: 2
sed -i 's/replicas: {{ .Values.replicas | default 2 }}/replicas: {{ .Values.replicaCount }}/' \
  chart-lab/gratitud/templates/deployment.yaml
helm template t chart-lab/gratitud --set replicaCount=3 | grep 'replicas:'   # replicas: 3

# ---- Fallo 4 ----
grep -n 'targetPort' chart-lab/gratitud/templates/service.yaml
sed -i 's/targetPort: {{ .Values.service.port }}/targetPort: {{ .Values.service.targetPort }}/' \
  chart-lab/gratitud/templates/service.yaml

# ---- desplegar ----
helm upgrade --install gratitud chart-lab/gratitud -n gratitud-cd --create-namespace \
  --set replicaCount=3 --wait
kubectl -n gratitud-cd get deploy gratitud
kubectl -n gratitud-cd get endpoints gratitud -o yaml | grep -E 'ip:|port:'
```

## Validación

```bash
cd CLASE-14/RECURSOS/SCRIPTS && ./validate-lab.sh
# LAB 14.4 SUPERADO (7 comprobaciones)
```

## Resultado esperado

* `helm lint` pasa.
* `helm template | grep image:` → `nginxinc/nginx-unprivileged:1.27-alpine`.
* `helm upgrade --install ... --set replicaCount=3` → Deployment `3/3`.
* `kubectl -n gratitud-cd get endpoints gratitud` → direcciones en el puerto `8080`.

## Error frecuente

* Corregir el fallo 3 con `helm upgrade --set replicas=3` (crea un value que la plantilla ya usa) en vez de arreglar la plantilla.
* Corregir el fallo 4 cambiando `containerPort` a 80: el contenedor `nginx-unprivileged` escucha en 8080; lo que hay que arreglar es el `targetPort` del Service.
* Ver el `helm template` con `image: ":1.27-alpine"` y pensar que falta el `tag`: lo que falta es el **repositorio** (`repo` vs `repository`).
* `helm lint` con `apiVersion: v1`: entonces `type: application` da error (es de `v2`). El valor correcto aquí es `v2`.
* Editar el chart de `../CHART-ROTO/` en vez de la copia `chart-lab/`.

## CKA Tip

```bash
helm lint <chart>
helm template t <chart> [--set k=v] | grep -E 'image:|replicas:|targetPort:'
helm upgrade --install <rel> <chart> -n <ns> --create-namespace --wait
helm -n <ns> get manifest <rel>
kubectl -n <ns> get endpoints <svc> -o yaml
```

Ruta mental de un chart que no despliega:
**`helm lint` → `helm template` (claves de values) → `helm install` → `kubectl get` (Deployment y endpoints).**
