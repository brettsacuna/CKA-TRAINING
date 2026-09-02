# LAB 14.2 — Empaquetar GRATITUD como chart

## Nivel

Intermedio.

## Duración

34 minutos.

## Objetivo

Convertir los manifiestos de GRATITUD en un **chart de Helm**: Deployment,
Service, Ingress y ConfigMap parametrizados con *values*, *labels* comunes desde
un *helper*, y varios entornos mediante ficheros de *values*.

## Competencias

* Estructurar un chart (`Chart.yaml`, `values.yaml`, `templates/`, `_helpers.tpl`).
* Usar `{{ .Values.* }}`, `{{ .Release.* }}`, `{{ .Chart.* }}` e `include`.
* `helm template` para verificar el render antes de instalar.
* `helm install`/`upgrade` con `--set` y con `-f`.

## Escenario

GRATITUD se despliega hoy con `kubectl apply -f` de cuatro ficheros fijos. Vas a
empaquetarlo para poder desplegarlo en dev, staging y prod cambiando solo unos
*values*.

## Estado inicial

* `helm` v3 y `kubectl` contra un cluster.
* Puedes partir del chart de referencia [`../RECURSOS/CHART/gratitud/`](../RECURSOS/CHART/gratitud/) para comparar, pero **escribe el tuyo**.

## Requerimientos

### Parte A — Estructura

1. Crea el árbol del chart:
   ```
   gratitud/
     Chart.yaml            # apiVersion: v2, name, version, appVersion
     values.yaml
     templates/
       _helpers.tpl
       deployment.yaml
       service.yaml
       ingress.yaml
       configmap.yaml
   ```
2. `values.yaml` debe cubrir, como mínimo: `replicaCount`, `image.{repository,tag,pullPolicy,containerPort}`, `service.{type,port,targetPort}`, `ingress.{enabled,className,host,path}`, `config` (mapa de clave-valor), `resources`.

### Parte B — Plantillas

3. `_helpers.tpl`: define `gratitud.fullname`, `gratitud.labels` y `gratitud.selectorLabels`.
4. `deployment.yaml`:
   * `metadata.name: {{ include "gratitud.fullname" . }}`,
   * `spec.replicas: {{ .Values.replicaCount }}`,
   * `image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"`,
   * `containerPort: {{ .Values.image.containerPort }}`,
   * `envFrom` al ConfigMap del chart,
   * `resources` con `{{- toYaml .Values.resources | nindent 12 }}`.
5. `service.yaml`: `port: {{ .Values.service.port }}`, `targetPort: {{ .Values.service.targetPort }}`.
6. `ingress.yaml`: envuelto en `{{- if .Values.ingress.enabled }} ... {{- end }}`.
7. `configmap.yaml`: `{{- range $k, $v := .Values.config }}{{ $k }}: {{ $v | quote }}{{- end }}`.

### Parte C — Verificar y desplegar

8. **Antes de instalar nada**, revisa el render:
   ```bash
   helm lint gratitud
   helm template gratitud gratitud | less
   helm template gratitud gratitud --set replicaCount=4 | grep -A1 replicas:
   ```
9. Instala en el cluster:
   ```bash
   kubectl create ns gratitud
   helm install gratitud ./gratitud -n gratitud
   kubectl -n gratitud get deploy,svc,cm -l app.kubernetes.io/instance=gratitud
   ```
10. `helm upgrade` cambiando el `tag` de la imagen y `replicaCount`; comprueba el `rollout`.

### Parte D — Entornos

11. Crea `values-prod.yaml` con más réplicas, otro `image.tag`, `ingress.enabled: true` y otro `host`.
12. Despliega con él:
    ```bash
    helm upgrade gratitud ./gratitud -n gratitud -f values-prod.yaml
    helm get manifest gratitud -n gratitud | grep -E 'kind: Ingress|host:|replicas:'
    ```

## Restricciones

* Un solo chart para todos los entornos: lo que cambia va en `values-*.yaml`, no en las plantillas.
* No pongas valores fijos en `templates/`: todo lo variable pasa por `values`.
* `helm template` debe pasar limpio **antes** de cualquier `helm install`.

## Validación

```bash
helm lint gratitud
helm template gratitud gratitud --set replicaCount=4 | grep 'replicas: 4'
helm -n gratitud list
helm -n gratitud get manifest gratitud | grep -E 'kind:|targetPort:|image:'
kubectl -n gratitud get endpoints -l app.kubernetes.io/instance=gratitud
```

## Resultado esperado

* `helm lint` sin errores.
* `helm template ... --set replicaCount=4` produce `replicas: 4`.
* La *release* `gratitud` desplegada, con Deployment + Service + ConfigMap (+ Ingress con `values-prod.yaml`).
* El `targetPort` del Service coincide con el `containerPort` del Deployment.
* `helm upgrade -f values-prod.yaml` cambia réplicas, `tag` y activa el Ingress.

## Criterios de éxito

- [ ] El chart tiene la estructura estándar y `helm lint` pasa.
- [ ] Deployment, Service, Ingress y ConfigMap están parametrizados con *values*.
- [ ] Las *labels* comunes salen de `_helpers.tpl` con `include`.
- [ ] Verifiqué el render con `helm template` antes de instalar.
- [ ] `helm install` y `helm upgrade` funcionan; el Service tiene endpoints.
- [ ] `values-prod.yaml` cambia el comportamiento sin tocar las plantillas.
