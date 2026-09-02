# LAB 5.4 — Challenge: "la red está rota"

## Nivel

Challenge / Troubleshooting.

## Duración

18 minutos.

## Objetivo

Distinguir, en un solo escenario, cuatro fallos que producen el mismo síntoma aparente —"no llego"— pero cuya causa está en capas distintas: DNS, Service, NetworkPolicy e Ingress.

```
IDENTIFICAR -> DIAGNOSTICAR -> CORREGIR -> VALIDAR
```

## Competencias

* Separar un fallo de DNS de uno de endpoints.
* Detectar una NetworkPolicy que bloquea tráfico legítimo.
* Detectar un Ingress que apunta a un Service o puerto equivocado.
* Recorrer la ruta completa cliente → Ingress → Service → EndpointSlice → Pod.

## Escenario

La tienda **`portal`** dejó de responder desde fuera. Además, el equipo dice que "el backend tampoco contesta desde el frontend". Nadie ha tocado nada, oficialmente.

## Estado inicial

```bash
cd CLASE-05/RECURSOS/SCRIPTS
./setup-lab.sh
```

Crea el namespace **`c5-challenge`** con un frontend, un backend, sus Services, un Ingress y una NetworkPolicy. **Hay 4 fallos.**

Requiere que el Ingress Controller del LAB 5.2 esté instalado.

## Requerimientos

1. Comprueba primero **qué funciona**: no empieces por el `curl` externo.
2. Recorre la ruta de dentro hacia fuera:
   ```
   Pod -> Service -> EndpointSlice -> DNS -> NetworkPolicy -> Ingress -> Cliente
   ```
3. Identifica los 4 fallos.
4. Documenta, por cada uno: síntoma, comando que lo reveló, causa raíz, capa afectada.
5. Corrige hasta que:
   * `frontend` alcance a `backend` por nombre de Service,
   * el Ingress responda `200` desde fuera.

## Restricciones

* **No elimines** la NetworkPolicy `default-deny`: debe seguir existiendo al final.
* No elimines el Ingress ni los Services: corrígelos in situ.
* No conviertas los Services a `NodePort` para "saltarte" el Ingress.
* No abras el egress a `0.0.0.0/0`.

## Ruta de diagnóstico

```
¿Resuelve el nombre?          nslookup <svc>          -> NO: DNS o NetworkPolicy de egress al 53
   |  sí
¿Hay endpoints?               get endpointslices      -> NO: selector o labels del Pod
   |  sí
¿Responde por ClusterIP?      curl <clusterIP>        -> NO: targetPort o NetworkPolicy
   |  sí
¿Responde por el Ingress?     curl <IP-nodo>:<np>     -> NO: ingressClassName, backend, puerto o path
```

## Comandos de diagnóstico

```bash
kubectl -n c5-challenge get pods --show-labels -o wide
kubectl -n c5-challenge get svc,endpointslices
kubectl -n c5-challenge get ingress -o yaml
kubectl -n c5-challenge get networkpolicy
kubectl -n c5-challenge describe networkpolicy default-deny
kubectl -n c5-challenge exec deploy/frontend -- nslookup backend
kubectl -n c5-challenge exec deploy/frontend -- curl -s --max-time 3 http://backend
kubectl get ingressclass
```

## Validación

```bash
kubectl -n c5-challenge exec deploy/frontend -- curl -s --max-time 3 http://backend
curl -s -o /dev/null -w '%{http_code}\n' http://<IP-NODO>:<nodePort-http>/
kubectl -n c5-challenge get networkpolicy default-deny

cd CLASE-05/RECURSOS/SCRIPTS && ./validate-lab.sh
```

## Resultado esperado

* `frontend` resuelve y alcanza `backend` por su nombre de Service.
* El Ingress devuelve `200` desde fuera del cluster.
* La política `default-deny` sigue existiendo y sigue bloqueando lo que no está explícitamente permitido.
* `./validate-lab.sh` termina con `LAB 5.4 SUPERADO`.

## Criterios de éxito

- [ ] Empecé el diagnóstico desde dentro del cluster, no desde el `curl` externo.
- [ ] Identifiqué los 4 fallos y la capa de cada uno.
- [ ] Documenté síntoma, comando y causa raíz.
- [ ] `frontend -> backend` funciona por nombre.
- [ ] El Ingress responde 200.
- [ ] `default-deny` sigue en pie.
- [ ] No convertí ningún Service a NodePort.
- [ ] `./validate-lab.sh` pasa.
