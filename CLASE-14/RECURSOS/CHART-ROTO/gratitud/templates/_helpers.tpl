{{- define "gratitud.name" -}}
{{- default .Chart.Name .Values.nameOverride -}}
{{- end -}}

{{- define "gratitud.fullname" -}}
{{- $name := include "gratitud.name" . -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "gratitud.labels" -}}
app.kubernetes.io/name: {{ include "gratitud.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
{{- end -}}

{{- define "gratitud.selectorLabels" -}}
app.kubernetes.io/name: {{ include "gratitud.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
