# LAB 5.3 — NetworkPolicy: aislar frontend y backend

## Nivel

Avanzado.

## Duración

27 minutos.

## Objetivo

Partir de un cluster totalmente abierto y llegar, **solo a partir de requerimientos de seguridad**, a un modelo de red donde únicamente el tráfico autorizado circula.

## Competencias

* Escribir NetworkPolicies de `Ingress` y de `Egress`.
* Aplicar `default deny` sin dejar el cluster inutilizable.
* Usar `podSelector`, `namespaceSelector` e `ipBlock`.
* Entender por qué las políticas son aditivas.
* Diagnosticar el efecto colateral más frecuente: romper el DNS.

## Escenario

Seguridad audita la plataforma y emite estos requisitos para el namespace **`c5-netpol`**:

| # | Requisito |
|---|---|
| R1 | Por defecto, **ningún** Pod del namespace puede recibir ni enviar tráfico |
| R2 | Los Pods `frontend` pueden **enviar** tráfico a los Pods `backend`, y solo a ellos |
| R3 | Los Pods `backend` pueden **recibir** tráfico solo de los Pods `frontend` |
| R4 | Los Pods `backend` pueden **enviar** tráfico al namespace `c5-datos` (etiquetado `ns=datos`), y solo ahí |
| R5 | Todos los Pods deben poder **resolver DNS** |
| R6 | Ningún Pod puede alcanzar Internet |

Tú decides los manifiestos, el orden de aplicación y las pruebas.

## Estado inicial

* Verifica **antes de nada** que tu CNI soporta NetworkPolicy:
  ```bash
  kubectl -n kube-system get pods | grep -iE 'calico|cilium|weave'
  ```
  Si no lo soporta, las políticas se aplicarán pero no bloquearán nada, y el laboratorio no tiene sentido.
* Namespaces: **`c5-netpol`** y **`c5-datos`** (los creas tú).

## Requerimientos

1. Crea ambos namespaces y etiqueta `c5-datos` con `ns=datos`.
2. En `c5-netpol` crea tres Pods con la imagen `nicolaka/netshoot` (o `busybox:1.36`) y `sleep 3600`:
   * `frontend` con label `run=frontend`
   * `backend` con label `run=backend`
   * `otro` con label `run=otro`
3. En `c5-datos` crea un Pod `db` con label `run=db` y un Service `db` en el puerto 80 (usa `nginx:1.27-alpine` para poder hacer `curl`).
4. **Antes de aplicar ninguna política**, documenta la conectividad de partida: quién alcanza a quién. Todo debe funcionar.
5. Implementa R1.
6. Comprueba qué se ha roto. Documenta explícitamente el efecto sobre el DNS.
7. Implementa R5 y verifica que la resolución vuelve.
8. Implementa R2 y R3.
9. Implementa R4.
10. Verifica R6.
11. Comprueba que `otro` **no** puede hablar con `backend` ni con `frontend`.
12. Añade una **segunda** política que permita a `otro` recibir tráfico de `frontend`. Sin borrar ninguna política anterior, comprueba el resultado y **explica por qué funciona**: qué significa que las políticas sean aditivas.

## Restricciones

* No uses `podSelector: {}` con `policyTypes` vacío para "desactivar" el aislamiento.
* La política de `default deny` no puede eliminarse en ningún momento tras el paso 5.
* No abras el egress a `0.0.0.0/0`.
* Debes permitir DNS de forma explícita, no desactivando el egress.

## Pistas de método (no de solución)

* `kubectl explain networkpolicy.spec.egress.to` te dice qué combinaciones existen.
* CoreDNS escucha en el puerto **53** UDP y TCP, en el namespace `kube-system`.
* Cuidado con la diferencia entre estas dos formas, que **no** significan lo mismo:

```yaml
  - from:
      - namespaceSelector: {...}
        podSelector: {...}        # AND: ese Pod en ese namespace
```

```yaml
  - from:
      - namespaceSelector: {...}
      - podSelector: {...}        # OR: ese namespace  O  ese Pod
```

## Validación

```bash
kubectl -n c5-netpol get networkpolicy
kubectl -n c5-netpol describe networkpolicy default-deny

# matriz de conectividad
kubectl -n c5-netpol exec frontend -- nslookup backend
kubectl -n c5-netpol exec frontend -- curl -s --max-time 3 http://backend  && echo OK  || echo BLOQUEADO
kubectl -n c5-netpol exec otro     -- curl -s --max-time 3 http://backend  && echo OK  || echo BLOQUEADO
kubectl -n c5-netpol exec backend  -- curl -s --max-time 3 http://db.c5-datos && echo OK || echo BLOQUEADO
kubectl -n c5-netpol exec frontend -- curl -s --max-time 3 http://example.com && echo OK || echo BLOQUEADO
```

## Resultado esperado

| Origen | Destino | Resultado |
|---|---|---|
| `frontend` | `backend` | permitido |
| `frontend` | Internet | bloqueado |
| `otro` | `backend` | bloqueado |
| `backend` | `db.c5-datos` | permitido |
| `backend` | Internet | bloqueado |
| cualquiera | DNS (CoreDNS) | permitido |

Tras el paso 12, `frontend -> otro` queda permitido **sin haber modificado** ninguna política previa.

## Criterios de éxito

- [ ] Verifiqué que el CNI soporta NetworkPolicy.
- [ ] Documenté la conectividad de partida antes de aplicar políticas.
- [ ] `default deny` aplicado con `podSelector: {}` y ambos `policyTypes`.
- [ ] Documenté que el DNS dejó de funcionar y por qué.
- [ ] Permití DNS de forma explícita (puerto 53 UDP y TCP).
- [ ] `frontend -> backend` funciona en ambas direcciones de la política.
- [ ] `backend -> c5-datos` funciona por `namespaceSelector`.
- [ ] `otro` está aislado.
- [ ] Ningún Pod alcanza Internet.
- [ ] Expliqué el carácter aditivo de las políticas con la prueba del paso 12.
