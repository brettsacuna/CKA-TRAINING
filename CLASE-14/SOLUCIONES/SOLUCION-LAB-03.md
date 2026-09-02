# SOLUCIÓN — LAB 14.3 · GRATITUD al estilo GitOps

> **MATERIAL DEL INSTRUCTOR.**

## Diagnóstico

1. **Repo de manifiestos separado del código.** Contiene el estado deseado; nadie hace `kubectl` a mano.
2. **El despliegue es un render + apply**, reproducible y sin pasos manuales. ArgoCD hace exactamente eso en bucle.
3. **La `Application` es la unidad**: de qué repo/ruta/revisión, a qué cluster/namespace, con qué `syncPolicy`.
4. **El CI valida y empaqueta; no despliega.** Ni `kubectl apply` ni `KUBECONFIG` en el pipeline.
5. **Drift**: un cambio en el cluster que no está en Git; `selfHeal` lo revierte.

## Layout (R1)

```
gratitud-manifests/
├── charts/gratitud/            # el chart del LAB 14.2
├── envs/
│   ├── dev/values.yaml
│   └── prod/values.yaml
├── apps/
│   ├── gratitud-dev.yaml       # Application -> envs/dev
│   └── gratitud-prod.yaml      # Application -> envs/prod
└── .github/workflows/chart.yml
```

Referencias completas en `../RECURSOS/CICD/`.

## Despliegue declarativo (R2)

```bash
k create ns gratitud
helm template gratitud charts/gratitud -f envs/prod/values.yaml --namespace gratitud \
  | kubectl apply -n gratitud -f -
```

Volver a ejecutarlo es idempotente: es la esencia de la reconciliación.

## Application de ArgoCD (R3)

`apps/gratitud-prod.yaml` — ver `../RECURSOS/CICD/argocd-application.yaml`. Lo esencial:

```yaml
spec:
  source:
    repoURL: https://git.gratitud.internal/plataforma/gratitud-manifests.git
    targetRevision: main
    path: charts/gratitud
    helm: {valueFiles: ["../../envs/prod/values.yaml"]}
  destination: {server: https://kubernetes.default.svc, namespace: gratitud}
  syncPolicy:
    automated: {prune: true, selfHeal: true}
    syncOptions: [CreateNamespace=true]
```

Si ArgoCD está instalado: `kubectl apply -n argocd -f apps/gratitud-prod.yaml` y
`argocd app get gratitud`. Si no, se queda como documento.

## CI (R4)

`../RECURSOS/CICD/github-actions-chart.yml` y `gitlab-ci-chart.yml`. Ambos:
`helm lint` → `helm template | kubeconform -strict` → `helm package` → (solo en
`main`) `helm push` OCI con token OIDC. **No** hay `kubectl` ni `KUBECONFIG`.

```bash
grep -RniE 'kubectl apply|KUBECONFIG' .github/ .gitlab-ci.yml || echo "OK: el CI no toca el cluster"
```

## Drift y reconciliación (R5)

```bash
kubectl -n gratitud scale deploy/gratitud --replicas=9        # cambio a mano = drift
helm template gratitud charts/gratitud -f envs/prod/values.yaml --namespace gratitud \
  | kubectl diff -n gratitud -f -                             # ArgoCD lo veria como OutOfSync
helm template gratitud charts/gratitud -f envs/prod/values.yaml --namespace gratitud \
  | kubectl apply -n gratitud -f -                            # reconcilia (lo que haria selfHeal)
```

Con `selfHeal: true`, ArgoCD detecta el `OutOfSync` causado por el cambio en el
cluster y vuelve a aplicar el estado de Git sin que nadie intervenga. Un
`rollback` sería `git revert` del commit correspondiente.

## Resultado esperado

* Layout `charts/` + `envs/` + `apps/`.
* Despliegue reproducible por `helm template | kubectl apply`.
* `Application` válida con `prune` y `selfHeal`.
* Pipelines en las dos plataformas, sin credenciales del cluster.
* `kubectl diff` muestra el drift; reaplicar lo corrige.

## Error frecuente

* Mezclar el chart y las `Application` en el repo del **código** de la app.
* Meter `kubectl apply` en el pipeline "para ir más rápido": rompe el modelo pull y da al CI acceso al cluster.
* `Application` sin `selfHeal`: el drift se detecta pero no se corrige solo.
* `prune: false` y quedarse con recursos huérfanos al borrar algo de Git.
* Referenciar `valueFiles` con una ruta que se sale del `path` del chart y que ArgoCD no resuelve.

## CKA Tip

```bash
helm template <rel> <chart> -f envs/<e>/values.yaml -n <ns> | kubectl apply -n <ns> -f -
kubectl diff -f -            # ver el drift antes de aplicar
kubectl apply --dry-run=server -f app.yaml
# ArgoCD: argocd app get <app> ; argocd app diff <app> ; argocd app sync <app>
```
