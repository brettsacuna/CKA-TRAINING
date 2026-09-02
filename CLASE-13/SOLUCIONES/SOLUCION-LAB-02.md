# SOLUCIÓN — LAB 13.2 · Aislar el tráfico de GRATITUD

> **MATERIAL DEL INSTRUCTOR.**

## Diagnóstico

1. **El aislamiento no es por defecto.** Hasta que una política selecciona a un Pod, acepta todo.
2. **`default deny` de `egress` rompe el DNS.** Hay que permitir el puerto 53 (UDP **y** TCP) a `kube-system` explícitamente.
3. **Ingress y egress son independientes.** `frontend → api` necesita `egress` en `gratitud-frontend` **y** `ingress` en `gratitud-api`.
4. **AND vs. OR.** `namespaceSelector` + `podSelector` bajo el mismo guion = AND (ese Pod en ese namespace). Es lo que se quiere aquí.

## Procedimiento

```bash
# 0 - CNI + linea base
k -n kube-system get pods | grep -iE 'calico|cilium|weave'
k apply -f ../RECURSOS/YAML/02-gratitud-apps.yaml
k -n gratitud-frontend exec deploy/frontend -- curl -s --max-time 3 -o /dev/null http://api.gratitud-api && echo "abierto de partida"

# R1 - default deny en los 3 namespaces
for ns in gratitud-frontend gratitud-api gratitud-datos; do
  kubectl -n $ns apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: default-deny}
spec: {podSelector: {}, policyTypes: [Ingress, Egress]}
EOF
done
k -n gratitud-frontend exec deploy/frontend -- nslookup api.gratitud-api   # AHORA falla: sin DNS

# R2 - permitir DNS en los 3 namespaces
for ns in gratitud-frontend gratitud-api gratitud-datos; do
  kubectl -n $ns apply -f - <<EOF
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
done

# R3/R5 - frontend -> api  (egress en origen + ingress en destino)
# R4/R5 - api -> cache
k apply -f ../RECURSOS/YAML/03-networkpolicies-referencia.yaml   # trae el resto (allow-frontend-*, allow-*-to-*)
```

El detalle de `allow-frontend-to-api` (AND, un solo guion):

```yaml
ingress:
  - from:
      - namespaceSelector: {matchLabels: {kubernetes.io/metadata.name: gratitud-frontend}}
        podSelector: {matchLabels: {app: gratitud-frontend}}
```

## Validación

```bash
k get networkpolicy -A
F='k -n gratitud-frontend exec deploy/frontend --'
O='k -n gratitud-frontend exec deploy/otro --'
A='k -n gratitud-api exec deploy/api --'

$F nslookup api.gratitud-api >/dev/null && echo "DNS OK"
$F curl -s --max-time 3 -o /dev/null http://api.gratitud-api      && echo "frontend->api OK"
$O curl -s --max-time 3 -o /dev/null http://api.gratitud-api      || echo "otro->api BLOQUEADO"
$A curl -s --max-time 3 -o /dev/null http://cache.gratitud-datos  && echo "api->cache OK"
$F curl -s --max-time 3 -o /dev/null http://example.com           || echo "frontend->internet BLOQUEADO"
```

## Resultado esperado

| Origen → Destino | Resultado |
|---|---|
| cualquiera → DNS | permitido |
| `frontend` → `api` | permitido |
| `api` → `cache` | permitido |
| `otro` → `api` / `cache` | bloqueado |
| cualquiera → Internet | bloqueado |

## Error frecuente

* Aplicar el `default deny` y no entender por qué "todo se rompió": el DNS también.
* Permitir solo el `ingress` en `api` y olvidar el `egress` en `frontend` (o al revés).
* Escribir la regla `from` con **dos** guiones (OR) y abrir a todo el namespace `gratitud-frontend`, incluido `otro`.
* Poner el `podSelector` del `from` con un label que los Pods de origen no tienen (`app: frontend` en vez de `app: gratitud-frontend`): la política no deja pasar a nadie.
* Permitir DNS solo UDP: `nslookup` de respuestas grandes o `tcp` falla.

## CKA Tip

```bash
k get networkpolicy -A
k describe networkpolicy <np> -n <ns>
k explain networkpolicy.spec.ingress.from
k -n <ns> run t --rm -it --image=nicolaka/netshoot --restart=Never -- sh
  nslookup <svc>.<ns> ; curl -s --max-time 3 http://<svc>.<ns>
```
