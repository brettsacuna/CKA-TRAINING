# LAB 14.3 — GRATITUD al estilo GitOps

## Nivel

Avanzado.

## Duración

30 minutos.

## Objetivo

Dejar el chart de GRATITUD en un **layout de repositorio de manifiestos**,
desplegarlo de forma declarativa como haría un agente, y escribir la
`Application` de ArgoCD y el pipeline de CI que lo automatizarían. Demostrar la
**reconciliación** ante un *drift*.

## Competencias

* Organizar un repo de manifiestos (chart + *values* por entorno + `Application`).
* Renderizar y aplicar un chart de forma declarativa (`helm template | kubectl apply`).
* Escribir una `Application` de ArgoCD con `automated: {prune, selfHeal}`.
* Escribir un workflow de CI (GitHub Actions y GitLab CI) que **no** despliega.
* Reconocer y corregir *drift*.

## Escenario

Plataforma decide mover GRATITUD a GitOps. Los requisitos:

| # | Requisito |
|---|---|
| R1 | Un layout de repo con el chart en `charts/gratitud/` y *values* por entorno en `envs/<entorno>/values.yaml`. |
| R2 | El despliegue se hace renderizando el chart y aplicando el resultado (como haría el agente), **no** con `helm install` interactivo. |
| R3 | Una `Application` de ArgoCD que apunte a ese repo/ruta con `prune` y `selfHeal` activados. |
| R4 | Un workflow de CI que **valide** el chart (`lint` + `template` + validación de esquema) y lo **empaquete**, sin ninguna credencial del cluster. El mismo pipeline en GitHub Actions y en GitLab CI. |
| R5 | Demostrar el *drift*: modificar un recurso a mano y volver a poner el cluster como dice el repo. Documentar qué haría `selfHeal`. |

Tú decides los nombres, los valores y el orden. Referencias en
[`../RECURSOS/CICD/`](../RECURSOS/CICD/).

## Estado inicial

* El chart `gratitud/` del LAB 14.2 (o `../RECURSOS/CHART/gratitud/`).
* `helm` v3 y `kubectl` contra un cluster. ArgoCD **opcional**: si no está instalado, la `Application` se escribe pero no se aplica.

## Pistas de método (no de solución)

* Layout: `charts/gratitud/`, `envs/{dev,prod}/values.yaml`, `apps/gratitud-<entorno>.yaml`, `.github/workflows/chart.yml`.
* Despliegue declarativo:
  ```bash
  helm template gratitud charts/gratitud -f envs/prod/values.yaml --namespace gratitud \
    | kubectl apply -n gratitud -f -
  ```
* `Application`: `spec.source.{repoURL,path,targetRevision}`, `spec.source.helm.valueFiles`, `spec.destination.{server,namespace}`, `spec.syncPolicy.automated.{prune,selfHeal}`.
* CI: `helm lint`, `helm template ... | kubeconform -strict`, `helm package`. Nada de `kubectl apply` en el pipeline.
* *Drift*: `kubectl -n gratitud scale deploy/gratitud --replicas=9`, luego `kubectl diff` contra el render y reaplica.

## Validación

```bash
# R1 - layout
find . -maxdepth 3 -type d | grep -E 'charts/gratitud|envs/|apps/'

# R2 - despliegue declarativo reproducible
helm template gratitud charts/gratitud -f envs/prod/values.yaml --namespace gratitud \
  | kubectl apply -n gratitud --dry-run=server -f -

# R3 - Application
kubectl apply --dry-run=client -f apps/gratitud-prod.yaml
grep -E 'prune:|selfHeal:|repoURL:|path:' apps/gratitud-prod.yaml

# R4 - CI sin credenciales del cluster
grep -RniE 'kubectl apply|kubeconfig|KUBECONFIG' .github/ .gitlab-ci.yml || echo "OK: el pipeline no toca el cluster"
helm lint charts/gratitud

# R5 - drift
kubectl -n gratitud scale deploy/gratitud --replicas=9
helm template gratitud charts/gratitud -f envs/prod/values.yaml --namespace gratitud | kubectl diff -n gratitud -f -   # muestra la diferencia
helm template gratitud charts/gratitud -f envs/prod/values.yaml --namespace gratitud | kubectl apply -n gratitud -f -  # reconcilia
```

## Resultado esperado

* Layout de repo con `charts/`, `envs/` y `apps/`.
* El chart se despliega renderizando + aplicando; el resultado es reproducible.
* `apps/gratitud-prod.yaml` es una `Application` válida con `prune: true` y `selfHeal: true`.
* Los pipelines (GH Actions y GitLab CI) hacen `lint` + `template` + `package` y **no** contienen `kubectl apply` ni `KUBECONFIG`.
* Un *drift* (`--replicas=9`) se detecta con `kubectl diff` y se corrige reaplicando; con `selfHeal`, ArgoCD lo haría solo.

## Criterios de éxito

- [ ] Repo con `charts/gratitud/`, `envs/<entorno>/values.yaml` y `apps/`.
- [ ] Despliegue por `helm template | kubectl apply`, reproducible.
- [ ] `Application` con `automated: {prune, selfHeal}`.
- [ ] Pipeline de CI en las dos plataformas, sin credenciales del cluster.
- [ ] Provoqué un *drift* y lo reconcilié; sé qué haría `selfHeal`.
