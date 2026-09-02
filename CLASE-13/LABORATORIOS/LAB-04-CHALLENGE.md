# LAB 13.4 — Challenge: «GRATITUD ni despliega ni conecta»

## Nivel

Challenge / Troubleshooting.

## Duración

20 minutos.

## Objetivo

Distinguir **cuatro fallos** que tocan las tres capas de seguridad: uno de RBAC,
dos de NetworkPolicy y uno de Pod Security, cada uno con un síntoma distinto —
`Forbidden`, `nslookup` que falla, tráfico bloqueado y un Deployment a cero
réplicas con `violates PodSecurity`.

```
IDENTIFICAR -> DIAGNOSTICAR -> CORREGIR -> VALIDAR
```

## Competencias

* Leer un error `Forbidden` de la API y localizar el `RoleBinding` que falla.
* Detectar una política de `egress` que no permite el DNS.
* Detectar un `podSelector` de `from` con un label que el origen no tiene.
* Reconocer un Pod rechazado por `enforce=restricted`.

## Escenario

Tras aplicar la política de seguridad, GRATITUD "no arranca del todo": la
ServiceAccount de despliegue no puede crear nada, la API no resuelve nombres, el
frontend no llega a la API y un componente de tareas ni se crea. **Hay 4 fallos.**

## Estado inicial

```bash
cd CLASE-13/RECURSOS/SCRIPTS
chmod +x *.sh
./setup-lab.sh
```

Crea:

* **`gratitud-frontend`**: `frontend` (`nicolaka/netshoot`) + sus NetworkPolicies (correctas).
* **`gratitud-api`**: `api` (`nginxinc/nginx-unprivileged`, 8080) + Service `api`; `probe` (`netshoot`); la ServiceAccount `gratitud-deployer`, el `Role` `deployer` (permisos completos) y el `RoleBinding` `deployer-bind` — **1 defecto**. Sus NetworkPolicies — **2 defectos**.
* **`gratitud-datos`**: `cache` + Service `cache` + NetworkPolicies (correctas).
* **`gratitud-batch`**: etiquetado `pod-security.kubernetes.io/enforce=restricted`; Deployment `worker` (`busybox`) — **1 defecto**.

## Requerimientos

1. Clasifica lo que ves:
   ```bash
   kubectl auth can-i create deployments -n gratitud-api \
     --as=system:serviceaccount:gratitud-api:gratitud-deployer          # no
   kubectl -n gratitud-api exec deploy/probe -- nslookup cache.gratitud-datos   # falla
   kubectl -n gratitud-frontend exec deploy/frontend -- curl -s --max-time 3 http://api.gratitud-api   # bloqueado
   kubectl -n gratitud-batch get deploy worker                          # 0/1
   kubectl -n gratitud-batch describe rs -l app=gratitud-worker | grep -i podsecurity
   ```
2. Recorre la ruta:
   ```
   RoleBinding (subjects) -> allow-dns (egress 53) -> podSelector del 'from' -> securityContext del Pod
   ```
3. Identifica los **4 fallos**.
4. Documenta, por cada uno: síntoma, comando que lo reveló, causa raíz y campo que lo corrige.
5. Corrige hasta que:
   * `auth can-i create deployments --as=...:gratitud-deployer` diga `yes`,
   * `probe` resuelva y alcance `cache.gratitud-datos`,
   * `frontend` alcance `api.gratitud-api`,
   * `worker` en `gratitud-batch` tenga `1/1`.

## Restricciones

* **No** concedas `cluster-admin` ni `edit` a `gratitud-deployer`: ajusta el binding.
* **No** borres ningún `default-deny`.
* **No** quites la etiqueta `enforce` de `gratitud-batch`.
* Corrige in situ (`patch`/`edit`), salvo donde el campo sea inmutable.

## Ruta de diagnóstico

```
'Forbidden' al desplegar        auth can-i --as ... --list   -> RoleBinding: subject mal escrito o roleRef equivocado
nslookup falla en un Pod        describe networkpolicy       -> falta allow-dns (egress UDP/TCP 53 a kube-system)
nslookup OK, curl bloqueado     get networkpolicy -o yaml    -> el podSelector del 'from' apunta a un label inexistente
Deploy a 0, 'violates PodSecurity'  describe rs               -> falta securityContext conforme a 'restricted'
```

## Comandos de diagnóstico

```bash
kubectl -n gratitud-api get rolebinding deployer-bind -o yaml
kubectl -n gratitud-api get networkpolicy
kubectl -n gratitud-api get networkpolicy allow-frontend-to-api -o yaml
kubectl -n gratitud-api get pod -l app=gratitud-frontend --show-labels    # (en gratitud-frontend)
kubectl -n gratitud-frontend get pod --show-labels
kubectl -n gratitud-batch describe rs -l app=gratitud-worker | sed -n '/Events/,$p'
```

## Validación

```bash
cd CLASE-13/RECURSOS/SCRIPTS && ./validate-lab.sh
```

## Los 4 fallos (para el instructor — no mirar antes de intentarlo)

<details>
<summary>Spoiler</summary>

1. **RBAC — `RoleBinding.subjects`.** `deployer-bind` referencia la ServiceAccount `gratitud-deploy`; la SA se llama `gratitud-deployer`. → `Forbidden`. Los `subjects` son mutables: `kubectl -n gratitud-api patch rolebinding deployer-bind --type=json -p='[{"op":"replace","path":"/subjects/0/name","value":"gratitud-deployer"}]'`.
2. **NetworkPolicy — falta `allow-dns`.** `gratitud-api` tiene `default-deny` de `Ingress` y `Egress` pero **ninguna** política que permita el puerto 53. → `nslookup` falla. Crear una NetworkPolicy de `egress` a `kube-system` en los puertos 53 UDP y TCP.
3. **NetworkPolicy — `podSelector` del `from`.** `allow-frontend-to-api` permite entrada a `app=gratitud-api` desde `namespaceSelector: gratitud-frontend` **AND** `podSelector: {app: frontend}`; los Pods de origen son `app=gratitud-frontend`. → tráfico bloqueado. → `app: gratitud-frontend`.
4. **Pod Security.** `gratitud-batch` tiene `enforce=restricted`; el Deployment `worker` no lleva `securityContext`. → ReplicaSet con `FailedCreate ... violates PodSecurity "restricted"`, 0 réplicas. → añadir `securityContext` de Pod y de contenedor (`runAsNonRoot`, `runAsUser`, `allowPrivilegeEscalation: false`, `capabilities.drop: [ALL]`, `seccompProfile: RuntimeDefault`).

</details>

## Resultado esperado

* `auth can-i create deployments --as=...:gratitud-deployer -n gratitud-api` → `yes`.
* `probe` resuelve y alcanza `cache.gratitud-datos`.
* `frontend` alcanza `api.gratitud-api`.
* `worker` en `gratitud-batch` con `1/1`.
* `./validate-lab.sh` termina con `LAB 13.4 SUPERADO`.

## Criterios de éxito

- [ ] Clasifiqué los cuatro síntomas antes de tocar nada.
- [ ] Corregí el `subject` del `RoleBinding` sin dar permisos de más.
- [ ] Añadí una política que permite el DNS (53 UDP y TCP).
- [ ] Alineé el `podSelector` del `from` con el label real del origen.
- [ ] Añadí el `securityContext` conforme a `restricted` al `worker`.
- [ ] No concedí `cluster-admin` ni borré ningún `default-deny`.
- [ ] `./validate-lab.sh` pasa.
