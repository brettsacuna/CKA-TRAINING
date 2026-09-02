# Layout del repositorio de manifiestos (GitOps)

Un repo **separado** del código de la aplicación. Contiene *solo* el estado
deseado; nadie hace `kubectl` a mano contra el cluster.

```
gratitud-manifests/
├── charts/
│   └── gratitud/                 # el chart de Helm (Chart.yaml, values.yaml, templates/)
├── envs/
│   ├── dev/values.yaml           # overrides por entorno
│   ├── stg/values.yaml
│   └── prod/values.yaml
├── apps/
│   ├── gratitud-dev.yaml         # Application de ArgoCD -> envs/dev
│   ├── gratitud-stg.yaml
│   └── gratitud-prod.yaml
└── .github/workflows/chart.yml   # CI: lint + render + package + push OCI
```

## Flujo de un cambio

1. **Código de la app** → su pipeline construye la imagen, la escanea y la
   publica como `registry.gratitud.internal/api@sha256:...`.
2. Ese pipeline abre un PR a **`gratitud-manifests`** cambiando `image.tag`
   (o el digest) en `envs/<entorno>/values.yaml`.
3. Al hacer *merge*, ArgoCD detecta que la `Application` está `OutOfSync` y,
   con `automated`, aplica el cambio. El cluster queda igual que Git.
4. **Rollback** = `git revert` del commit en `gratitud-manifests`.

## Reglas

- El pipeline de CI **no** tiene credenciales del cluster.
- El único que aplica cambios en el cluster es ArgoCD (o Flux).
- Un cambio hecho a mano en el cluster se revierte solo (`selfHeal: true`).
- Lo que no está en Git no está en el cluster (`prune: true`).
