{{- define "gratitud.labels" -}}
app.kubernetes.io/name: gratitud
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
part-of: gratitud
{{- end -}}

{{/*
Contenedor comun a los tres tiers.
Uso: {{- include "gratitud.container" (dict "root" $ "name" $tier "persist" $p) | nindent 8 }}
*/}}
{{- define "gratitud.container" -}}
{{- $ := .root -}}
- name: {{ .name }}
  image: "{{ $.Values.image.repository }}:{{ $.Values.image.tag }}"
  imagePullPolicy: {{ $.Values.image.pullPolicy }}
  ports:
    - containerPort: {{ $.Values.image.containerPort }}
  {{- if eq .name "api" }}
  envFrom:
    - configMapRef: {name: gratitud-config}
    - secretRef: {name: gratitud-db}
  env:
    - name: PARTNER_TOKEN
      valueFrom:
        secretKeyRef: {name: gratitud-tokens, key: PARTNER_TOKEN}
  {{- end }}
  startupProbe:
    httpGet: {path: {{ $.Values.probes.path }}, port: {{ $.Values.image.containerPort }}}
    periodSeconds: 5
    failureThreshold: {{ $.Values.probes.startupFailureThreshold }}
  livenessProbe:
    httpGet: {path: {{ $.Values.probes.path }}, port: {{ $.Values.image.containerPort }}}
    periodSeconds: 10
    failureThreshold: 3
  readinessProbe:
    httpGet: {path: {{ $.Values.probes.path }}, port: {{ $.Values.image.containerPort }}}
    periodSeconds: 5
  resources:
    {{- toYaml $.Values.resources | nindent 4 }}
  securityContext:
    {{- toYaml $.Values.containerSecurityContext | nindent 4 }}
  volumeMounts:
    - {name: tmp, mountPath: /tmp}
    - {name: cache-dir, mountPath: /var/cache/nginx}
    - {name: run, mountPath: /var/run}
    {{- if and .persist $.Values.persistence.enabled }}
    - {name: data, mountPath: {{ $.Values.persistence.mountPath }}}
    {{- end }}
{{- end -}}

{{- define "gratitud.volumes" -}}
{{- $ := .root -}}
- {name: tmp, emptyDir: {}}
- {name: cache-dir, emptyDir: {}}
- {name: run, emptyDir: {}}
{{- if and .persist $.Values.persistence.enabled }}
- name: data
  persistentVolumeClaim: {claimName: {{ $.Values.persistence.name }}}
{{- end }}
{{- end -}}
