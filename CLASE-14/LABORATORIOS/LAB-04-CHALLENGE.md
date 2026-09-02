# LAB 14.4 — Challenge: «el chart de GRATITUD no despliega»

## Nivel

Challenge / Troubleshooting.

## Duración

20 minutos.

## Objetivo

Distinguir **cuatro fallos** en un chart de Helm con síntomas distintos:
`helm lint` falla, el render deja la imagen sin repositorio, el número de
réplicas no responde a los *values*, y el Service apunta al puerto equivocado.

```
IDENTIFICAR -> DIAGNOSTICAR -> CORREGIR -> VALIDAR
```

## Competencias

* Leer un error de `helm lint`.
* Detectar en `helm template` una clave de *values* mal escrita.
* Relacionar `--set` que no tiene efecto con una plantilla que usa otra clave.
* Detectar un `targetPort` que no coincide con el `containerPort`.

## Escenario

Un compañero te pasa un chart de GRATITUD "que casi funciona". `helm lint` se
queja, y cuando lo instalas, el Pod no arranca y el Service no sirve. **Hay 4
fallos, todos en el chart.**

## Estado inicial

```bash
cd CLASE-14/RECURSOS/SCRIPTS
chmod +x *.sh
./setup-lab.sh
```

Copia el chart roto a **`CLASE-14/RECURSOS/SCRIPTS/chart-lab/gratitud`** (edita
esa copia) y crea el namespace `gratitud-cd`.

## Requerimientos

1. Empieza por las herramientas de Helm, sin tocar el cluster:
   ```bash
   helm lint chart-lab/gratitud
   helm template t chart-lab/gratitud --set replicaCount=3
   ```
   Los **dos primeros fallos** salen aquí.
2. Corrige y despliega:
   ```bash
   helm upgrade --install gratitud chart-lab/gratitud -n gratitud-cd --set replicaCount=3 --wait
   kubectl -n gratitud-cd get deploy,endpoints gratitud
   ```
   Los **dos últimos** se ven ya en el cluster.
3. Identifica los **4 fallos**. Documenta, por cada uno: síntoma, comando que lo reveló, causa raíz y línea que lo corrige.
4. Deja el chart de forma que:
   * `helm lint` pase,
   * `helm template | grep image:` muestre `nginxinc/nginx-unprivileged:1.27-alpine`,
   * `helm upgrade --install ... --set replicaCount=3` deje **3** réplicas,
   * el Service tenga endpoints en el puerto **8080**.

## Restricciones

* **No** recrees el chart con `helm create` desde cero: corrige los ficheros.
* No "arregles" el número de réplicas con `helm upgrade --set replicas=3`: el fallo está en la plantilla.
* No cambies el `containerPort` del contenedor para que cuadre con el Service: el fallo está en el Service.

## Ruta de diagnóstico

```
helm lint falla                         Chart.yaml: 'apiVersion is required'   -> añade apiVersion: v2
helm template -> image: ":1.27-alpine"  la plantilla usa .Values.image.repo    -> es .Values.image.repository
--set replicaCount=3 -> replicas: 2     la plantilla usa .Values.replicas      -> es .Values.replicaCount
Service sin endpoints utiles            targetPort 80, containerPort 8080       -> targetPort: {{ .Values.service.targetPort }}
```

## Comandos de diagnóstico

```bash
helm lint chart-lab/gratitud
helm template t chart-lab/gratitud --set replicaCount=3 | grep -E 'replicas:|image:|targetPort:|containerPort:'
cat chart-lab/gratitud/Chart.yaml
grep -n 'Values' chart-lab/gratitud/templates/deployment.yaml chart-lab/gratitud/templates/service.yaml
cat chart-lab/gratitud/values.yaml
kubectl -n gratitud-cd get pod -l app.kubernetes.io/instance=gratitud
kubectl -n gratitud-cd get endpoints gratitud -o yaml
```

## Validación

```bash
cd CLASE-14/RECURSOS/SCRIPTS && ./validate-lab.sh
```

## Los 4 fallos (para el instructor — no mirar antes de intentarlo)

<details>
<summary>Spoiler</summary>

1. **`Chart.yaml` sin `apiVersion`.** `helm lint` → *apiVersion is required. The value must be either "v1" or "v2"*. → añadir `apiVersion: v2`.
2. **`templates/deployment.yaml` · `.Values.image.repo`.** `values.yaml` tiene `image.repository`. El render da `image: ":1.27-alpine"` → `InvalidImageName` en el Pod. → `{{ .Values.image.repository }}`.
3. **`templates/deployment.yaml` · `replicas: {{ .Values.replicas | default 2 }}`.** `values.yaml` usa `replicaCount`. `--set replicaCount=3` no tiene efecto: siempre 2. → `replicas: {{ .Values.replicaCount }}`.
4. **`templates/service.yaml` · `targetPort: {{ .Values.service.port }}`.** Vale 80; el contenedor escucha en `{{ .Values.image.containerPort }}` = 8080. El Service tiene endpoints pero al puerto equivocado. → `targetPort: {{ .Values.service.targetPort }}` (que en `values.yaml` es `8080`).

</details>

## Resultado esperado

* `helm lint` pasa.
* `helm template | grep image:` → `nginxinc/nginx-unprivileged:1.27-alpine`.
* `helm upgrade --install ... --set replicaCount=3` → Deployment con `3/3`.
* `kubectl -n gratitud-cd get endpoints gratitud` → dirección(es) en el puerto `8080`.
* `./validate-lab.sh` termina con `LAB 14.4 SUPERADO`.

## Criterios de éxito

- [ ] `helm lint` y `helm template` me dieron los dos primeros fallos antes de tocar el cluster.
- [ ] Corregí la clave de la imagen (`repo` → `repository`).
- [ ] Corregí la clave de réplicas (`replicas` → `replicaCount`) en la plantilla, no con `--set`.
- [ ] Corregí el `targetPort` del Service, no el `containerPort`.
- [ ] No recreé el chart desde cero.
- [ ] `./validate-lab.sh` pasa.
