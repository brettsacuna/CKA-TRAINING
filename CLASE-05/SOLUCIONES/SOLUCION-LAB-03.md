# SOLUCIÓN — LAB 5.3 · NetworkPolicy

> **MATERIAL DEL INSTRUCTOR.**

## Diagnóstico

El momento pedagógico está en el paso 6: al aplicar el `default deny`, **el DNS deja de funcionar** y de repente nada resuelve. Casi todos los alumnos concluyen que "CoreDNS se cayó". No: la política de egress también bloquea el tráfico al puerto 53. Es el efecto colateral más frecuente en producción.

## Razonamiento técnico resumido

* Un Pod **no seleccionado** por ninguna NetworkPolicy acepta todo el tráfico.
* En cuanto **una** política lo selecciona para un `policyType`, ese Pod queda aislado para ese tipo y solo se permite lo que las políticas autoricen.
* Las políticas son **aditivas**: se aplica la **unión** de todas las que seleccionan al Pod. **No existen reglas de denegación** y el orden no importa.
* `podSelector: {}` = todos los Pods del namespace. `policyTypes: [Ingress, Egress]` sin secciones `ingress`/`egress` = denegar todo.
* Ingress y Egress son **independientes**: para que `frontend` hable con `backend` hacen falta *dos* permisos, uno de salida en `frontend` y otro de entrada en `backend`.
* Diferencia crítica de sintaxis:

```yaml
- from:
    - namespaceSelector: {matchLabels: {ns: datos}}
      podSelector: {matchLabels: {run: db}}     # AND (un solo elemento de lista)
```
```yaml
- from:
    - namespaceSelector: {matchLabels: {ns: datos}}
    - podSelector: {matchLabels: {run: db}}     # OR (dos elementos)
```

Un guion de más cambia por completo el alcance.

## Procedimiento

```bash
k create ns c5-netpol && k create ns c5-datos
k label ns c5-datos ns=datos
k config set-context --current --namespace=c5-netpol

# 2-3
k run frontend --image=nicolaka/netshoot -l run=frontend -- sleep 3600
k run backend  --image=nginx:1.27-alpine -l run=backend
k run otro     --image=nicolaka/netshoot -l run=otro     -- sleep 3600
k expose pod backend --port=80
k -n c5-datos run db --image=nginx:1.27-alpine -l run=db
k -n c5-datos expose pod db --port=80

# 4  linea base: todo funciona
k exec frontend -- curl -s --max-time 3 -o /dev/null -w '%{http_code}\n' http://backend
k exec otro     -- curl -s --max-time 3 -o /dev/null -w '%{http_code}\n' http://backend
k exec frontend -- curl -s --max-time 3 -o /dev/null -w '%{http_code}\n' http://example.com

# 5  R1
k apply -f ../RECURSOS/YAML/05-networkpolicies.yaml   # solo el primer documento, o aplica todo y ve quitando

# 6  comprobar el dano
k exec frontend -- nslookup backend       # ;; connection timed out
```

**Explicación:** la política de egress bloquea también el tráfico UDP/53 hacia CoreDNS. Sin resolución, **ningún** nombre funciona, y el síntoma se confunde con "la red está muerta".

```bash
# 7  R5
k apply -f - <<'YAML'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: allow-dns, namespace: c5-netpol}
spec:
  podSelector: {}
  policyTypes: [Egress]
  egress:
    - to:
        - namespaceSelector:
            matchLabels: {kubernetes.io/metadata.name: kube-system}
      ports:
        - {protocol: UDP, port: 53}
        - {protocol: TCP, port: 53}
YAML
k exec frontend -- nslookup backend       # vuelve a resolver

# 8  R2 y R3   (frontend-egress y backend-ingress)
# 9  R4        (backend-egress-datos)
# ver RECURSOS/YAML/05-networkpolicies.yaml

# 10-11
k exec frontend -- curl -s --max-time 3 http://example.com  || echo BLOQUEADO
k exec otro     -- curl -s --max-time 3 http://backend      || echo BLOQUEADO

# 12
k apply -f - <<'YAML'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: otro-ingress-from-frontend, namespace: c5-netpol}
spec:
  podSelector: {matchLabels: {run: otro}}
  policyTypes: [Ingress]
  ingress:
    - from:
        - podSelector: {matchLabels: {run: frontend}}
YAML
```

**12 —** Para que `frontend -> otro` funcione hacen falta también permisos de **egress** en `frontend`. Si solo se añade el ingress en `otro`, sigue bloqueado. Ese es exactamente el punto: las políticas suman permisos, pero hay que cubrir **las dos direcciones**. Amplía `frontend-egress` con un segundo `to` (no lo sustituyas: añádelo) o crea una política adicional de egress.

## Validación

```bash
k get networkpolicy
for src in frontend otro; do for dst in backend example.com; do
  echo -n "$src -> $dst: "
  k exec $src -- curl -s --max-time 3 -o /dev/null http://$dst && echo OK || echo BLOQUEADO
done; done
k exec backend -- curl -s --max-time 3 -o /dev/null http://db.c5-datos && echo OK || echo BLOQUEADO
```

## Resultado esperado

```
frontend -> backend:     OK
frontend -> example.com: BLOQUEADO
otro     -> backend:     BLOQUEADO
backend  -> db.c5-datos: OK
DNS desde cualquiera:    OK
```

## Error frecuente

* **Olvidar el DNS.** Es el fallo estrella.
* Poner solo la política de ingress y esperar que el tráfico fluya: falta el egress del origen.
* Confundir `AND` con `OR` por un guion mal puesto en `namespaceSelector`/`podSelector`.
* Usar `namespaceSelector` con un label que el namespace no tiene. Recuerda que Kubernetes añade automáticamente `kubernetes.io/metadata.name: <ns>` a todos los namespaces: úsalo.
* Aplicar políticas en un cluster cuyo CNI no las implementa y concluir que "no funcionan". Verifícalo antes.
* Creer que existe un `deny` explícito. No existe: la denegación es la ausencia de permiso.

## CKA Tip

```bash
# No hay generador imperativo: parte de la doc o de este esqueleto
k explain networkpolicy.spec.ingress.from
k explain networkpolicy.spec.egress.to

# Probar conectividad rápido
k exec <pod> -- curl -s --max-time 3 -o /dev/null -w '%{http_code}\n' http://<svc>
k exec <pod> -- nc -zv <svc> 80

# Ver qué Pods selecciona una política
k describe networkpolicy <np>
```

**Las tres preguntas que resuelven cualquier tarea de NetworkPolicy:**
1. ¿A qué Pods se aplica? (`podSelector`)
2. ¿Ingress, Egress o ambos? (`policyTypes`)
3. ¿Desde/hacia qué exactamente, y en qué puerto? (`from`/`to` + `ports`)
Y una cuarta que se olvida: **¿he permitido el DNS?**
