# MEJORAS OPCIONALES DEL CURSO

Contenidos que aportarían valor pero **no caben en las 18 horas** sin sacrificar práctica. Todos guardan relación directa con el material analizado.

Cada mejora indica: prioridad, duración estimada, con qué contenido del curso enlaza y por qué quedó fuera.

---

## ALTA PRIORIDAD

### 1. Gateway API en profundidad — 3 h
**Enlaza con:** Clase 5 (Ingress).
**Contenido:** `GatewayClass`, `Gateway`, `HTTPRoute`, filtros (`URLRewrite`, `RequestHeaderModifier`), `ReferenceGrant` entre namespaces, migración de Ingress a Gateway API.
**Por qué importa:** el currículum CKA vigente ya la incluye, y tras la retirada de `ingress-nginx` en marzo de 2026 es la dirección del ecosistema. En el curso se presenta conceptualmente y con un manifiesto de referencia, pero no se practica.
**Por qué quedó fuera:** requiere instalar CRDs y un controlador que las implemente, y la API Ingress sigue siendo lo que más se pide en el examen.

### 2. Helm y Kustomize — 3 h
**Enlaza con:** todas las clases (los manifiestos se aplican a mano).
**Contenido:** `helm install/upgrade/rollback/list`, valores, charts; `kustomize build`, overlays, `patchesStrategicMerge`, generadores de ConfigMap y Secret.
**Por qué importa:** ambos están explícitamente en el dominio *Cluster Architecture, Installation & Configuration* del currículum CKA vigente.
**Por qué quedó fuera:** el material original no los trata en absoluto y su inclusión desplazaría laboratorios de troubleshooting, que pesan el 30 %.

### 3. Cluster HA y bootstrap con kubeadm — 4 h
**Enlaza con:** Clase 2 (upgrade, etcd).
**Contenido:** `kubeadm init` y `kubeadm join` desde cero, tokens, `--control-plane-endpoint`, etcd apilado frente a externo, upgrade de un control plane de tres nodos, rotación de certificados (`kubeadm certs check-expiration`, `renew`).
**Por qué importa:** el curso restaura y actualiza un cluster de un solo control plane; la operación real casi siempre es HA.
**Por qué quedó fuera:** necesita al menos cinco máquinas y una sesión propia.

### 4. Probes completas y sondas de arranque — 1,5 h
**Enlaza con:** Clase 4 (`readinessProbe`).
**Contenido:** `livenessProbe`, `startupProbe`, `exec`/`tcpSocket`/`grpc`, `failureThreshold`, `initialDelaySeconds`, y el efecto de una liveness mal configurada (reinicios en bucle de una aplicación sana).
**Por qué importa:** una liveness mal puesta es una de las causas más frecuentes de `CrashLoopBackOff` en producción.
**Por qué quedó fuera:** en el curso solo se usa `readinessProbe`, lo justo para explicar los rollouts y los endpoints.

---

## MEDIA PRIORIDAD

### 5. CRDs, Operators y ValidatingAdmissionPolicy — 3 h
**Enlaza con:** Clase 2 (arquitectura del API server).
**Contenido:** crear una CRD, entender el patrón operator, y políticas de admisión basadas en CEL sin webhooks.
**Por qué importa:** figuran en el currículum vigente.
**Por qué quedó fuera:** son conceptos de extensión del API, no de operación diaria; sin base sólida en lo anterior no se aprovechan.

### 6. HorizontalPodAutoscaler y escalado automático — 2 h
**Enlaza con:** Clase 4 (Metrics Server, `requests`, `scale`).
**Contenido:** `autoscaling/v2`, métricas de CPU y memoria, `behavior`, y por qué el HPA no funciona sin `requests` definidos.
**Por qué importa:** es la continuación natural del laboratorio de recursos.
**Por qué quedó fuera:** el escalado manual cubre lo que pide el examen; el HPA necesita carga sintética para demostrarse bien.

### 7. Jobs, CronJobs y DaemonSets — 2 h
**Enlaza con:** Clase 3 (controladores de workload).
**Contenido:** `completions`, `parallelism`, `backoffLimit`, `activeDeadlineSeconds`, `ttlSecondsAfterFinished`; `schedule`, `concurrencyPolicy`, `startingDeadlineSeconds`; DaemonSets y su relación con `drain --ignore-daemonsets`.
**Por qué importa:** completa el mapa de controladores; los DaemonSets ya aparecen implícitamente en el `drain` de la Clase 2.
**Por qué quedó fuera:** el material original no los cubre y la Clase 3 ya está llena.

### 8. Contenedores sidecar e init containers — 1,5 h
**Enlaza con:** Clases 3 y 4 (multi-contenedor, `emptyDir`).
**Contenido:** `initContainers`, sidecars nativos (init container con `restartPolicy: Always`), patrones ambassador y adapter, orden de arranque y terminación.
**Por qué importa:** el sidecar nativo es una incorporación reciente que aparece en el examen y que la mayoría de guías antiguas no cubren.
**Por qué quedó fuera:** el LAB 3.2 ya usa dos contenedores; profundizar exigiría una sesión aparte.

### 9. Seguridad del workload — 3 h
**Enlaza con:** Clase 2 (RBAC).
**Contenido:** `securityContext`, `runAsNonRoot`, `readOnlyRootFilesystem`, capabilities, Pod Security Standards y las etiquetas `pod-security.kubernetes.io/enforce`.
**Por qué importa:** sustituye a las PodSecurityPolicies, ya eliminadas, y aparece en el examen.
**Por qué quedó fuera:** cae más del lado del CKS; el CKA lo toca de forma superficial.

### 10. Observabilidad y agregación de logs — 2,5 h
**Enlaza con:** Clase 6 (troubleshooting).
**Contenido:** limitaciones de `kubectl logs`, rotación de logs del nodo, un stack básico de recolección, y métricas del kube-state.
**Por qué importa:** en producción no se diagnostica con `kubectl logs`.
**Por qué quedó fuera:** el examen no lo evalúa.

---

## BAJA PRIORIDAD

### 11. Backup y restore de etcd en cluster HA — 2 h
**Enlaza con:** Clase 2 (LAB 2.3).
**Contenido:** snapshot desde un miembro concreto, restore coordinado en tres nodos, `--initial-cluster` e `--initial-advertise-peer-urls`.
**Por qué quedó fuera:** el examen plantea el caso de un solo control plane.

### 12. Comparativa de CNIs — 1,5 h
**Enlaza con:** Clase 5 (NetworkPolicy).
**Contenido:** Calico frente a Cilium frente a Flannel, encapsulación, eBPF, políticas extendidas (`CiliumNetworkPolicy`, políticas L7).
**Por qué quedó fuera:** el examen usa un CNI ya instalado y no pregunta por su implementación.

### 13. `ReadWriteMany` con NFS y CSI drivers — 2 h
**Enlaza con:** Clase 3 (modos de acceso).
**Contenido:** montar un servidor NFS, aprovisionador externo, drivers CSI, `volumeBindingMode: WaitForFirstConsumer`, expansión de volúmenes.
**Por qué quedó fuera:** requiere infraestructura de almacenamiento adicional; el curso demuestra RWX solo conceptualmente.

### 14. ResourceQuota y LimitRange — 1,5 h
**Enlaza con:** Clase 4 (`requests` y `limits`).
**Contenido:** cuotas por namespace, límites por defecto, `LimitRange` para forzar `requests` en Pods que no los declaran.
**Por qué importa:** el material original mencionaba `kubectl create quota` de pasada, sin desarrollarlo.
**Por qué quedó fuera:** es más gobernanza de plataforma que administración pura.

### 15. GitOps con Argo CD o Flux — 3 h
**Enlaza con:** el curso completo.
**Contenido:** despliegue declarativo desde Git, reconciliación, drift, estrategia de rollback basada en Git en lugar de en `rollout undo`.
**Por qué quedó fuera:** no está en el currículum CKA, aunque sea la forma habitual de operar hoy.

---

## Recomendación de secuencia posterior

Si hay presupuesto para una segunda tanda de 18 horas, este es el orden que más rendimiento da:

```
Módulo 7   Helm y Kustomize + Jobs, CronJobs y DaemonSets          (5 h)
Módulo 8   Probes completas + sidecars + HPA                        (5 h)
Módulo 9   Gateway API en profundidad                               (3 h)
Módulo 10  Cluster HA: bootstrap, certificados y upgrade            (5 h)
```

Esa secuencia cierra por completo el currículum CKA vigente y prepara el terreno para el CKS.
