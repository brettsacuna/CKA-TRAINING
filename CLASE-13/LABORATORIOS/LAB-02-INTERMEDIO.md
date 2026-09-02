# LAB 13.2 — Aislar el tráfico de GRATITUD

## Nivel

Intermedio.

## Duración

32 minutos.

## Objetivo

Pasar de tres namespaces de GRATITUD totalmente abiertos a un modelo donde **solo
circula el tráfico autorizado**, sin romper el DNS ni dejar nada inutilizable,
partiendo únicamente de requisitos de seguridad.

## Competencias

* Escribir NetworkPolicies de `Ingress` y `Egress`.
* Aplicar `default deny` sin dejar el cluster inservible.
* Permitir DNS de forma explícita.
* Usar `namespaceSelector`, `podSelector` e `ipBlock`, y distinguir el AND del OR.

## Escenario

Seguridad audita GRATITUD y emite estos requisitos para los namespaces
**`gratitud-frontend`**, **`gratitud-api`** y **`gratitud-datos`**:

| # | Requisito |
|---|---|
| R1 | Por defecto, **ningún** Pod de esos namespaces puede recibir ni enviar tráfico. |
| R2 | Todos los Pods deben poder **resolver DNS**. |
| R3 | Los Pods `frontend` pueden **enviar** tráfico a los Pods `api` de `gratitud-api`, y solo a ellos. |
| R4 | Los Pods `api` pueden **enviar** tráfico a los Pods `cache` de `gratitud-datos`, y solo ahí. |
| R5 | Los Pods `api` solo **reciben** tráfico de los Pods `frontend`. Los Pods `cache` solo de los Pods `api`. |
| R6 | Ningún Pod puede alcanzar Internet. |
| R7 | El Pod `otro` de `gratitud-frontend` **no** puede hablar con `api` ni con `cache`. |

Tú decides los manifiestos, el orden de aplicación y las pruebas.

## Estado inicial

```bash
kubectl apply -f ../RECURSOS/YAML/02-gratitud-apps.yaml
```

Crea los tres namespaces con:

* `gratitud-frontend`: `frontend` (`app=gratitud-frontend`) y `otro` (`app=otro`), ambos `nicolaka/netshoot`.
* `gratitud-api`: `api` (`app=gratitud-api`, `nginx:1.27-alpine`) + Service `api`.
* `gratitud-datos`: `cache` (`app=gratitud-cache`, `nginx:1.27-alpine`) + Service `cache`.

## Pistas de método (no de solución)

* Verifica **antes** que el CNI implementa NetworkPolicy y documenta la conectividad de partida (todo funciona).
* `default deny`: `podSelector: {}` con `policyTypes: [Ingress, Egress]` y sin secciones.
* DNS: `egress` al puerto **53** (UDP **y** TCP) hacia el namespace `kube-system` (`kubernetes.io/metadata.name: kube-system`).
* AND (un guion) vs. OR (dos guiones) en las reglas `from`/`to`. Casi siempre quieres AND.
* Para `frontend → api` hacen falta DOS políticas: `egress` en `gratitud-frontend` e `ingress` en `gratitud-api`.
* Prueba con `kubectl -n <ns> exec deploy/<d> -- curl -s --max-time 3 http://<svc>.<ns>` y `-- nslookup <svc>.<ns>`.

## Validación

```bash
kubectl get networkpolicy -A

F='kubectl -n gratitud-frontend exec deploy/frontend --'
O='kubectl -n gratitud-frontend exec deploy/otro --'
A='kubectl -n gratitud-api exec deploy/api --'

$F nslookup api.gratitud-api            >/dev/null && echo "DNS frontend OK"
$F curl -s --max-time 3 -o /dev/null http://api.gratitud-api   && echo "frontend->api OK"   || echo "frontend->api BLOQUEADO"
$O curl -s --max-time 3 -o /dev/null http://api.gratitud-api   && echo "otro->api OK"       || echo "otro->api BLOQUEADO"
$A curl -s --max-time 3 -o /dev/null http://cache.gratitud-datos && echo "api->cache OK"    || echo "api->cache BLOQUEADO"
$F curl -s --max-time 3 -o /dev/null http://example.com        && echo "frontend->internet OK" || echo "frontend->internet BLOQUEADO"
```

## Resultado esperado

| Origen | Destino | Resultado |
|---|---|---|
| cualquiera | DNS (CoreDNS) | permitido |
| `frontend` | `api` | permitido |
| `api` | `cache` | permitido |
| `otro` | `api` / `cache` | bloqueado |
| cualquiera | Internet | bloqueado |
| `api` | `frontend` (a la inversa) | bloqueado |

Y el `default deny` sigue existiendo en los tres namespaces.

## Criterios de éxito

- [ ] Verifiqué el soporte de NetworkPolicy del CNI y la conectividad de partida.
- [ ] `default deny` aplicado en los tres namespaces con ambos `policyTypes`.
- [ ] La resolución DNS funciona tras permitir el puerto 53 (UDP y TCP).
- [ ] `frontend → api` funciona con `egress` en origen e `ingress` en destino.
- [ ] `api → cache` funciona por `namespaceSelector` + `podSelector` (AND).
- [ ] `otro` está aislado de `api` y de `cache`.
- [ ] Ningún Pod alcanza Internet.
