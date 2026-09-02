# SOLUCIÓN — LAB 14.2 · Empaquetar GRATITUD como chart

> **MATERIAL DEL INSTRUCTOR.**

## Diagnóstico

1. **El chart es la plantilla; los `values` son los datos.** Todo lo que cambia entre entornos va en `values-*.yaml`, nunca fijo en `templates/`.
2. **`_helpers.tpl`** evita repetir el bloque de *labels* y la lógica de nombres en cada manifiesto.
3. **`helm template` es la red de seguridad**: caza claves mal escritas y `{{ }}` que renderizan vacío antes de tocar el cluster.
4. **`targetPort` del Service** tiene que coincidir con el `containerPort` del contenedor.

## Chart de referencia

`../RECURSOS/CHART/gratitud/`. Puntos clave:

`templates/_helpers.tpl`

```gotemplate
{{- define "gratitud.fullname" -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}{{ .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else -}}{{ printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}{{- end -}}
{{- end -}}

{{- define "gratitud.selectorLabels" -}}
app.kubernetes.io/name: {{ default .Chart.Name .Values.nameOverride }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
```

`templates/deployment.yaml` (extracto)

```gotemplate
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels: { {{- include "gratitud.selectorLabels" . | nindent 6 }} }
  template:
    spec:
      containers:
        - name: api
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          ports: [{containerPort: {{ .Values.image.containerPort }}}]
          resources: {{- toYaml .Values.resources | nindent 12 }}
```

`templates/service.yaml`

```gotemplate
  ports:
    - port: {{ .Values.service.port }}
      targetPort: {{ .Values.service.targetPort }}
```

`templates/ingress.yaml`: todo el fichero envuelto en `{{- if .Values.ingress.enabled }} ... {{- end }}`.

## Procedimiento

```bash
helm lint gratitud
helm template gratitud gratitud | less
helm template gratitud gratitud --set replicaCount=4 | grep -A1 replicas:

k create ns gratitud
helm install gratitud ./gratitud -n gratitud
k -n gratitud get deploy,svc,cm,endpoints -l app.kubernetes.io/instance=gratitud

helm upgrade gratitud ./gratitud -n gratitud --set image.tag=1.27-alpine --set replicaCount=3
helm upgrade gratitud ./gratitud -n gratitud -f values-prod.yaml
helm -n gratitud get manifest gratitud | grep -E 'kind: Ingress|host:|replicas:'
```

## Validación

```bash
helm lint gratitud
helm template gratitud gratitud --set replicaCount=4 | grep 'replicas: 4'
helm -n gratitud list
kubectl -n gratitud get endpoints -l app.kubernetes.io/instance=gratitud
```

## Resultado esperado

* `helm lint` limpio; `--set replicaCount=4` → `replicas: 4`.
* *Release* `gratitud` con Deployment + Service + ConfigMap; Ingress al aplicar `values-prod.yaml`.
* `targetPort` del Service = `containerPort` del Deployment; Service con endpoints.

## Error frecuente

* Escribir la misma clave de dos formas (`replicas` en el template, `replicaCount` en values): renderiza vacío o ignora `--set`.
* `nindent` mal calculado en el `include` de *labels*: YAML inválido tras el render.
* Olvidar `{{- if .Values.ingress.enabled }}` y desplegar siempre el Ingress.
* `image.tag` numérico sin comillas (`tag: 1.27`) → YAML lo interpreta como *float* `1.27`.
* Meter valores de un entorno concreto en `values.yaml` en vez de en `values-prod.yaml`.

## CKA Tip

```bash
helm create <name>                      # esqueleto de referencia
helm lint <chart>
helm template <rel> <chart> [-f v.yaml] [--set k=v] | kubectl apply --dry-run=server -f -
helm install <rel> <chart> -n <ns> -f values-prod.yaml
helm -n <ns> get manifest <rel>
```
