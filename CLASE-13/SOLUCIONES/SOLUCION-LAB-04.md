# SOLUCIÓN — LAB 13.4 · Challenge «GRATITUD ni despliega ni conecta»

> **MATERIAL DEL INSTRUCTOR.**

## Los 4 fallos

| # | Capa | Objeto · campo | Fallo | Síntoma |
|---|---|---|---|---|
| 1 | RBAC | `rolebinding/deployer-bind` · `subjects[0].name` | `gratitud-deploy` (la SA es `gratitud-deployer`) | `Forbidden` al desplegar |
| 2 | NetworkPolicy | `gratitud-api` | No hay `allow-dns` (con `default-deny` de egress) | `nslookup` falla en `api`/`probe` |
| 3 | NetworkPolicy | `networkpolicy/allow-frontend-to-api` · `from[].podSelector` | `app: frontend` (los Pods son `app: gratitud-frontend`) | `nslookup` OK, `curl` bloqueado |
| 4 | Pod Security | `deployment/worker` (`gratitud-batch`, `enforce=restricted`) | Sin `securityContext` | Deployment `0/1`, `violates PodSecurity` |

## Método

Cuatro síntomas distintos → cuatro capas distintas. El orden natural: RBAC
(¿puedo actuar?), DNS (¿resuelvo?), tráfico (¿llego?), Pod Security (¿me
crean?).

## Procedimiento

```bash
cd CLASE-13/RECURSOS/SCRIPTS && ./setup-lab.sh

# ---- Fallo 1: RBAC ----
kubectl auth can-i create deployments -n gratitud-api \
  --as=system:serviceaccount:gratitud-api:gratitud-deployer            # no
kubectl -n gratitud-api get rolebinding deployer-bind -o jsonpath='{.subjects[0].name}{"\n"}'   # gratitud-deploy
kubectl -n gratitud-api patch rolebinding deployer-bind --type=json \
  -p='[{"op":"replace","path":"/subjects/0/name","value":"gratitud-deployer"}]'
kubectl auth can-i create deployments -n gratitud-api \
  --as=system:serviceaccount:gratitud-api:gratitud-deployer            # yes

# ---- Fallo 2: falta allow-dns en gratitud-api ----
kubectl -n gratitud-api exec deploy/probe -- nslookup cache.gratitud-datos    # falla
kubectl -n gratitud-api get networkpolicy                                     # no hay allow-dns
kubectl -n gratitud-api apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: allow-dns}
spec:
  podSelector: {}
  policyTypes: [Egress]
  egress:
    - to: [{namespaceSelector: {matchLabels: {kubernetes.io/metadata.name: kube-system}}}]
      ports: [{protocol: UDP, port: 53}, {protocol: TCP, port: 53}]
EOF
kubectl -n gratitud-api exec deploy/probe -- nslookup cache.gratitud-datos    # resuelve

# ---- Fallo 3: podSelector del from ----
kubectl -n gratitud-frontend exec deploy/frontend -- curl -s --max-time 3 -o /dev/null http://api.gratitud-api   # bloqueado
kubectl -n gratitud-api get networkpolicy allow-frontend-to-api -o jsonpath='{.spec.ingress[0].from[0].podSelector}{"\n"}'   # {app: frontend}
kubectl -n gratitud-frontend get pod --show-labels                            # app=gratitud-frontend
kubectl -n gratitud-api patch networkpolicy allow-frontend-to-api --type=json \
  -p='[{"op":"replace","path":"/spec/ingress/0/from/0/podSelector/matchLabels/app","value":"gratitud-frontend"}]'
kubectl -n gratitud-frontend exec deploy/frontend -- curl -s --max-time 3 -o /dev/null http://api.gratitud-api   # 200

# ---- Fallo 4: securityContext bajo enforce=restricted ----
kubectl -n gratitud-batch get deploy worker                                   # 0/1
kubectl -n gratitud-batch describe rs -l app=gratitud-worker | grep -i 'violates PodSecurity'
kubectl -n gratitud-batch patch deploy worker --type=merge -p '
spec:
  template:
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        seccompProfile: {type: RuntimeDefault}
      containers:
        - name: worker
          securityContext:
            allowPrivilegeEscalation: false
            capabilities: {drop: ["ALL"]}'
kubectl -n gratitud-batch rollout status deploy/worker                        # 1/1
```

## Validación

```bash
cd CLASE-13/RECURSOS/SCRIPTS && ./validate-lab.sh
# LAB 13.4 SUPERADO (9 comprobaciones)
```

## Resultado esperado

* `auth can-i create deployments --as=...:gratitud-deployer -n gratitud-api` → `yes`.
* `probe` resuelve y alcanza `cache.gratitud-datos`.
* `frontend` alcanza `api.gratitud-api`.
* `worker` en `gratitud-batch` con `1/1`.
* Los tres `default-deny` siguen en pie.

## Error frecuente

* Intentar `kubectl edit rolebinding` para cambiar `roleRef`: es inmutable. Aquí el fallo está en `subjects`, que **sí** es mutable.
* "Arreglar" el fallo 1 dando `edit` o `cluster-admin` a la SA: el criterio pide ajustar el binding, no ampliar el permiso.
* Corregir el `podSelector` del `from` pero olvidar que el `namespaceSelector` también debe cuadrar (aquí ya cuadra).
* Añadir `allow-dns` solo en `gratitud-api` y que `frontend` siga fallando por el fallo 3 (son independientes).
* Para el fallo 4, poner el `securityContext` solo a nivel de Pod: `capabilities` y `allowPrivilegeEscalation` son de contenedor.

## CKA Tip

```bash
k auth can-i --list -n NS --as=system:serviceaccount:NS:SA
k get rolebinding <rb> -o jsonpath='{.roleRef}{"  "}{.subjects}{"\n"}'
k get networkpolicy -n NS -o yaml | grep -E 'podSelector|namespaceSelector|port:'
k describe rs -l <label> -n NS | sed -n '/Events/,$p'   # 'violates PodSecurity'
```

Tres síntomas, tres capas: **`Forbidden` = RBAC · tráfico que no pasa = NetworkPolicy · Deployment a 0 con `violates PodSecurity` = PSA.**
