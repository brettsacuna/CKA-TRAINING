# Especificación del integrador — programa GRATITUD

Despliega **GRATITUD** completo en el namespace **`gratitud`**, empaquetado como
el chart de Helm de [`CHART/gratitud/`](CHART/gratitud/). Estas son las
condiciones que `validar-gratitud.sh` comprueba.

## 1. Aplicación (S9, S12)

| Tier | Deployment | Réplicas | Imagen | Puerto |
|---|---|---|---|---|
| Portal | `portal` | 2 | `nginxinc/nginx-unprivileged:1.27-alpine` | 8080 |
| API | `api` | 2 | `nginxinc/nginx-unprivileged:1.27-alpine` | 8080 |
| Caché | `cache` | 1 | `nginxinc/nginx-unprivileged:1.27-alpine` | 8080 |

* Cada tier tiene un Service **ClusterIP** con el mismo nombre (`portal`, `api`, `cache`), `port 80 → targetPort 8080`.
* Cada contenedor lleva **`startupProbe`**, **`livenessProbe`** y **`readinessProbe`** (`httpGet /` al 8080), `requests`/`limits` de CPU y memoria, y la anotación `prometheus.io/scrape: "true"`.
* La base de datos externa se modela con un Service **ExternalName** `db-externa` → `db.corp.example.com`.

## 2. Entrada (S10)

* Un Ingress **`gratitud`** con `ingressClassName` el del controlador instalado.
* Reglas por path en `gratitud.example.com`: `/api` → `api:80`, `/` → `portal:80`.
* Sección `tls` con el Secret **`gratitud-tls`** (tipo `kubernetes.io/tls`) para ese host.

## 3. Configuración y almacenamiento (S11)

* ConfigMap **`gratitud-config`**: `LOG_LEVEL`, `FEATURE_GRATITUD_V2`, `UPSTREAM_CACHE=http://cache`.
* Secret **`gratitud-db`**: `DB_USER`, `DB_PASSWORD`, `DB_HOST`.
* Secret **`gratitud-tokens`**: `PARTNER_TOKEN`, `WEBHOOK_SIGNING_KEY`.
* La API los inyecta con `envFrom` (config + db) y `valueFrom` (`PARTNER_TOKEN`).
* PVC **`gratitud-uploads`** de **1Gi**, RWO, montado en la caché en `/data/uploads`. Un fichero escrito debe sobrevivir a `kubectl delete pod`.

## 4. Observabilidad (S12)

* `kubectl top pod -n gratitud` devuelve cifras (metrics-server instalado).
* Los Pods no escriben logs a ficheros: `kubectl logs` de cada uno produce salida.

## 5. Seguridad (S13)

* ServiceAccount **`gratitud-deployer`** con un `Role` que permite `get/list/watch/update/patch` de `deployments` y `configmaps`, y **no** leer `secrets`. Enlazado con un `RoleBinding`.
* NetworkPolicies: **`default-deny`** (Ingress+Egress), **`allow-dns`**, y las cadenas `ingress→portal`, `portal→api`, `api→cache`. Nada más pasa.
* El namespace `gratitud` con `pod-security.kubernetes.io/enforce=restricted` (y `warn`). Todos los contenedores cumplen: `runAsNonRoot`, `allowPrivilegeEscalation: false`, `capabilities.drop: [ALL]`, `seccompProfile: RuntimeDefault`, raíz de solo lectura con `emptyDir` para `/tmp`, `/var/cache/nginx` y `/var/run`.

## 6. Empaquetado (S14)

* Todo lo anterior se instala con `helm install gratitud ./gratitud -n gratitud`.
* `helm lint` pasa; `helm template` renderiza sin errores.
* `values-prod.yaml` (o `-f`/`--set`) cambia réplicas, `image.tag` y el `host` sin tocar las plantillas.

## Criterio final

```bash
cd CLASE-15/RECURSOS/SCRIPTS && ./validar-gratitud.sh
# Todas las líneas en [OK].
```
