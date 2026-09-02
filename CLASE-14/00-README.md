# Sesión 14 — Entrega Continua: CI/CD, GitOps y Helm

> **Sesión especial.** El enunciado traía el título de otra sesión («Seguridad
> Avanzada (RBAC) y Políticas»); el contenido real —y este material— es **CI/CD,
> imágenes seguras, GitOps y Helm**. Continúa el programa GRATITUD: se automatiza
> su construcción y publicación, se despliega al estilo GitOps con ArgoCD y se
> empaqueta como un chart de Helm.

## Duración

180 minutos.

## Objetivos

1. Describir las **etapas de un pipeline de CI/CD** y el papel de los *runners*.
2. Leer y escribir un **workflow de GitHub Actions** y su equivalente en **GitLab CI**.
3. Construir una imagen con **build multi-stage** y publicarla de forma segura en un registry.
4. Explicar la filosofía **GitOps**: Git como fuente de verdad y reconciliación automática.
5. Describir el ciclo de **ArgoCD**: `Application`, *diff*, *sync*, *drift* y *self-heal*.
6. Empaquetar una aplicación como un **chart de Helm** con *values* y plantillas.
7. Usar `helm install`, `upgrade`, `rollback`, `template` y `get`.

## Contenidos

* **CI/CD.** Etapas (`checkout → build → test → scan → package → deploy`). *Runners* efímeros. Despliegue *push* (el pipeline hace `kubectl`/`helm`) vs. *pull* (GitOps). GitHub Actions (`workflows`/`jobs`/`steps`/`uses`) vs. GitLab CI (`stages`/`jobs`/`script`). Secretos efímeros por OIDC.
* **Imágenes seguras.** Build multi-stage (imagen final mínima, sin *toolchain*). Etiqueta con SHA/semver, despliega por **digest**. Escaneo (Trivy), firma (cosign), SBOM. Publicación con cuenta de robot o token OIDC; `imagePullSecret` en el cluster.
* **GitOps.** Estado deseado en Git; aplicación automática; reconciliación continua; detección de *drift* y *self-heal*. Modelo *pull*: el agente vive en el cluster. ArgoCD y Flux. `Rollback = git revert`.
* **ArgoCD.** `Application` (repo, `path`, `targetRevision` → cluster, namespace). `syncPolicy.automated` (`prune`, `selfHeal`). Render de manifiestos / Helm / Kustomize.
* **Helm.** `Chart.yaml`, `values.yaml`, `templates/` (Go templates), `_helpers.tpl`. `helm install/upgrade/rollback/template/get/lint`. Repos HTTP y registries **OCI**. `values` por entorno con `-f`.

## El programa GRATITUD en esta sesión

* **CI**: un workflow construye la imagen de la API, la escanea y la publica en `registry.gratitud.internal` (ficheros de referencia en `RECURSOS/CICD/`).
* **GitOps**: una `Application` de ArgoCD apunta a `gratitud-manifests` con `automated: {prune, selfHeal}`.
* **Helm**: GRATITUD empaquetado como el chart `gratitud/` (Deployment + Service + Ingress + ConfigMap), con `values.yaml` y `values-prod.yaml`.
* El **LAB 14.4** rompe el chart: `Chart.yaml` sin `apiVersion` (`helm lint` falla), una clave de imagen mal escrita (`image: ":tag"`), otra de réplicas que ignora `--set`, y un `targetPort` que no cuadra con el contenedor.

## Requisitos

* **`helm` v3** instalado en tu equipo (los LAB 14.1–14.4 lo usan).
* Acceso a `kubectl` contra un cluster para los LAB 14.2–14.4.
* Internet para descargar `nginxinc/nginx-unprivileged:1.27-alpine`.

## Agenda (180 min)

| Tiempo | Actividad |
|---|---|
| 00–12 | De un commit a producción: el flujo completo |
| 12–34 | Conceptos: pipelines de CI/CD e imágenes seguras |
| 34–52 | Conceptos: GitOps y ArgoCD |
| 52–74 | **LAB 14.1 — Básico**: Helm de principio a fin |
| 74–108 | **LAB 14.2 — Intermedio**: empaquetar GRATITUD como chart |
| 108–120 | Conceptos: plantillas, *values* y *releases* |
| 120–150 | **LAB 14.3 — Avanzado**: GRATITUD al estilo GitOps |
| 150–170 | **LAB 14.4 — Challenge**: «el chart de GRATITUD no despliega» |
| 170–180 | Cierre y CKA Tips |

## Presentación

[`01-CLASE-14-CKA.pptx`](01-CLASE-14-CKA.pptx)

## Laboratorios

| Lab | Nivel | Archivo |
|---|---|---|
| LAB 14.1 | Básico | [LABORATORIOS/LAB-01-BASICO.md](LABORATORIOS/LAB-01-BASICO.md) |
| LAB 14.2 | Intermedio | [LABORATORIOS/LAB-02-INTERMEDIO.md](LABORATORIOS/LAB-02-INTERMEDIO.md) |
| LAB 14.3 | Avanzado | [LABORATORIOS/LAB-03-AVANZADO.md](LABORATORIOS/LAB-03-AVANZADO.md) |
| LAB 14.4 | Challenge | [LABORATORIOS/LAB-04-CHALLENGE.md](LABORATORIOS/LAB-04-CHALLENGE.md) |

## Recursos

[`RECURSOS/CHART/`](RECURSOS/CHART/) · [`RECURSOS/CICD/`](RECURSOS/CICD/) · [`RECURSOS/SCRIPTS/`](RECURSOS/SCRIPTS/)

| Ruta | Uso |
|---|---|
| `CHART/gratitud/` | Chart de referencia de GRATITUD (con `values-prod.yaml`) |
| `CHART-ROTO/gratitud/` | Chart con los 4 defectos del LAB 14.4 (no editar; `setup-lab.sh` lo copia) |
| `CICD/github-actions-chart.yml` | Workflow de GitHub Actions para el chart |
| `CICD/gitlab-ci-chart.yml` | Equivalente en GitLab CI |
| `CICD/argocd-application.yaml` | `Application` de ArgoCD (modelo *pull*) |
| `CICD/repo-layout.md` | Layout del repositorio de manifiestos |
| `SCRIPTS/setup-lab.sh` | Copia el chart roto a `chart-lab/` (LAB 14.4) |
| `SCRIPTS/validate-lab.sh` | Comprueba el LAB 14.4 |
| `SCRIPTS/reset-lab.sh` | Elimina lo creado por la sesión |

> **Alcance CKA.** CI/CD, GitOps y la autoría de charts **no** entran en el
> examen CKA como tal; Helm se usa a nivel de consumidor. Esta sesión es una
> introducción práctica al ecosistema de entrega alrededor de Kubernetes.

## Preparación

```bash
alias k=kubectl
cd CLASE-14/RECURSOS/SCRIPTS && chmod +x *.sh
```

Al terminar:

```bash
./reset-lab.sh
```

## Checklist final de la sesión

- [ ] Enumero las etapas de un pipeline de CI/CD.
- [ ] Leo un workflow de GitHub Actions y un `.gitlab-ci.yml`.
- [ ] Explico un build multi-stage y por qué desplegar por **digest**.
- [ ] Sé publicar una imagen sin credenciales de larga vida (OIDC / robot).
- [ ] Enuncio los principios de GitOps.
- [ ] Describo el ciclo `Application → diff → sync → self-heal`.
- [ ] Distingo despliegue *push* de *pull*.
- [ ] Conozco la estructura de un chart de Helm.
- [ ] Uso `install`, `upgrade`, `rollback`, `template` y `get`.
- [ ] Diagnostico un chart que no renderiza o no despliega.
