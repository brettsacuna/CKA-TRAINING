# Sesión 13 — Seguridad: RBAC, Red y Pods

> **Sesión especial.** El enunciado traía el título de otra sesión
> («Observabilidad y Mantenimiento»); el contenido real —y este material— es
> **RBAC, NetworkPolicy y seguridad de Pods**. Continúa el programa GRATITUD:
> control de acceso con RBAC, aislamiento de red con NetworkPolicy y contenedores
> endurecidos con `securityContext` y Pod Security Admission.

## Duración

180 minutos.

## Objetivos

1. Diseñar permisos con **Role**, **ClusterRole**, **RoleBinding** y **ClusterRoleBinding**.
2. Comprobar permisos con `kubectl auth can-i`, incluyendo `--as` y `--list`.
3. Distinguir lo *namespaced* de lo *cluster-scoped* y cuándo usar cada binding.
4. Escribir **NetworkPolicies** de `ingress` y `egress`, incluyendo `default deny`.
5. Evitar el fallo de romper el DNS al aplicar una política de `egress`.
6. Endurecer un contenedor con **`securityContext`**: no-root, sin *capabilities*, `seccomp`, raíz de solo lectura.
7. Aplicar los **Pod Security Standards** con **Pod Security Admission** por etiqueta de namespace.

## Contenidos

* **RBAC.** Sujeto (User/Group/**ServiceAccount**) + verbo + recurso (`apiGroup`). `Role`/`ClusterRole` = reglas; *binding* = a quién. `roleRef` inmutable. Roles por defecto: `view`/`edit`/`admin`/`cluster-admin`. `RoleBinding` puede apuntar a un `ClusterRole`. `resourceNames`, ClusterRoles agregados.
* **NetworkPolicy.** Cuatro reglas (sin política = todo; una política = aislado para ese tipo; aditivas; ingress/egress independientes). Requisito de CNI. `default deny`. El fallo del DNS (puerto 53). AND vs. OR: el guion que concede de más; el `podSelector` con un label que el origen no tiene.
* **`securityContext`.** `runAsNonRoot`/`runAsUser`, `allowPrivilegeEscalation: false`, `capabilities.drop: [ALL]`, `readOnlyRootFilesystem`, `seccompProfile: RuntimeDefault`, `privileged: false`. Nivel de Pod vs. nivel de contenedor.
* **Pod Security Admission.** `PodSecurityPolicy` eliminado en 1.25. Tres niveles (`privileged`/`baseline`/`restricted`) × tres modos (`enforce`/`audit`/`warn`) vía etiquetas `pod-security.kubernetes.io/*` en el namespace. Un Pod rechazado por `enforce` no se crea.

## El programa GRATITUD en esta sesión

* **RBAC**: una ServiceAccount `gratitud-deployer` con un `Role` acotado para desplegar en `gratitud-api`.
* **NetworkPolicy**: `default deny` en `gratitud-frontend`, `gratitud-api` y `gratitud-datos`; solo se permite `frontend → api`, `api → datos` y el DNS.
* **Pod Security**: el Deployment `api` se endurece (no-root, `drop ALL`, `seccomp`, raíz de solo lectura) y `gratitud-api` pasa a `enforce=restricted`.
* El **LAB 13.4** rompe las tres capas a la vez: un `RoleBinding` con el sujeto mal escrito (`Forbidden`), una política de `egress` sin DNS (`nslookup` falla), un `podSelector` de `from` con el label equivocado (tráfico bloqueado) y un Pod sin `securityContext` en un namespace `restricted` (`violates PodSecurity`).

## Agenda (180 min)

| Tiempo | Actividad |
|---|---|
| 00–10 | Las tres preguntas: quién, con quién, qué puede hacer |
| 10–32 | Conceptos: RBAC — Roles, ClusterRoles y bindings |
| 32–54 | **LAB 13.1 — Básico**: una ServiceAccount con permisos mínimos |
| 54–72 | Conceptos: NetworkPolicy — default deny, aditividad, DNS |
| 72–104 | **LAB 13.2 — Intermedio**: aislar el tráfico de GRATITUD |
| 104–120 | Conceptos: `securityContext` y Pod Security Admission |
| 120–150 | **LAB 13.3 — Avanzado**: endurecer los contenedores de GRATITUD |
| 150–170 | **LAB 13.4 — Challenge**: «GRATITUD ni despliega ni conecta» |
| 170–180 | Cierre y CKA Tips |

## Presentación

[`01-CLASE-13-CKA.pptx`](01-CLASE-13-CKA.pptx)

## Laboratorios

| Lab | Nivel | Archivo |
|---|---|---|
| LAB 13.1 | Básico | [LABORATORIOS/LAB-01-BASICO.md](LABORATORIOS/LAB-01-BASICO.md) |
| LAB 13.2 | Intermedio | [LABORATORIOS/LAB-02-INTERMEDIO.md](LABORATORIOS/LAB-02-INTERMEDIO.md) |
| LAB 13.3 | Avanzado | [LABORATORIOS/LAB-03-AVANZADO.md](LABORATORIOS/LAB-03-AVANZADO.md) |
| LAB 13.4 | Challenge | [LABORATORIOS/LAB-04-CHALLENGE.md](LABORATORIOS/LAB-04-CHALLENGE.md) |

## Recursos

[`RECURSOS/YAML/`](RECURSOS/YAML/) · [`RECURSOS/SCRIPTS/`](RECURSOS/SCRIPTS/)

| Archivo | Uso |
|---|---|
| `YAML/01-rbac-basico.yaml` | SA + Role + RoleBinding + ClusterRole + ClusterRoleBinding (LAB 13.1) |
| `YAML/02-gratitud-apps.yaml` | `frontend`, `otro`, `api`, `cache` de GRATITUD, sin políticas (LAB 13.2) |
| `YAML/03-networkpolicies-referencia.yaml` | Juego completo de NetworkPolicies de GRATITUD |
| `YAML/04-gratitud-api-plano.yaml` | Deployment `api` SIN `securityContext` (LAB 13.3) |
| `YAML/05-gratitud-api-hardened-referencia.yaml` | `api` conforme al nivel `restricted` |
| `SCRIPTS/setup-lab.sh` | Despliega el escenario **roto** del LAB 13.4 |
| `SCRIPTS/validate-lab.sh` | Comprueba el LAB 13.4 |
| `SCRIPTS/reset-lab.sh` | Elimina lo creado por la sesión |

> **Requisito de CNI.** Los LAB 13.2 y 13.4 solo son significativos si el plugin
> CNI implementa NetworkPolicy (Calico, Cilium…). Verifícalo con
> `kubectl -n kube-system get pods | grep -iE 'calico|cilium|weave'`.

## Preparación

```bash
alias k=kubectl
cd CLASE-13/RECURSOS/SCRIPTS && chmod +x *.sh
```

Al terminar:

```bash
./reset-lab.sh
```

## Checklist final de la sesión

- [ ] Escribo un `Role` y un `RoleBinding` para una ServiceAccount.
- [ ] Sé cuándo necesito un `ClusterRole` y cuándo un `ClusterRoleBinding`.
- [ ] Compruebo permisos con `auth can-i --as` y `--list`.
- [ ] Sé que `roleRef` es inmutable.
- [ ] Escribo un `default deny` y sé qué rompe.
- [ ] Permito DNS en una política de `egress` (puerto 53 UDP y TCP).
- [ ] Distingo el AND del OR en `namespaceSelector` y `podSelector`.
- [ ] Endurezco un contenedor: `runAsNonRoot`, `drop [ALL]`, `seccomp`.
- [ ] Aplico un Pod Security Standard con la etiqueta del namespace.
- [ ] Diagnostico un `Forbidden`, un tráfico bloqueado y un `violates PodSecurity`.
