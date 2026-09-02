# LAB 1.4 — Challenge: la aplicación `shop` no responde

## Nivel

Challenge / Troubleshooting.

## Duración

20 minutos.

## Objetivo

Diagnosticar y reparar, sin pistas previas, un escenario roto que combina un fallo de scheduling y un fallo de publicación de servicio.

```
IDENTIFICAR -> DIAGNOSTICAR -> CORREGIR -> VALIDAR
```

## Competencias

* Aplicar el mental model de un Pod `Pending`.
* Aplicar el mental model de un Service sin endpoints.
* Distinguir un problema de scheduling de un problema de selector o de puerto.
* Reparar sin destruir el recurso.

## Escenario

El namespace **`c1-challenge`** contiene una aplicación de tienda que **funcionaba ayer**. Hoy:

* El equipo reporta que `http://<IP-worker>:31200` no responde.
* El compañero de guardia "hizo unos cambios" antes de irse y no dejó notas.

Tú entras de guardia. Nadie te va a decir qué está roto.

## Estado inicial

Prepara el escenario:

```bash
cd CLASE-01/RECURSOS/SCRIPTS
./setup-lab.sh
```

Esto crea el namespace `c1-challenge` con:

* Un Deployment `shop-web` (3 réplicas declaradas).
* Un Service `shop-svc` de tipo NodePort en el `nodePort` 31200.
* Estado del cluster modificado.

**Hay entre 3 y 4 fallos.** No se te dice cuáles.

## Requerimientos

1. Identifica **todos** los problemas.
2. Documenta para cada uno: síntoma observado, comando que lo reveló, causa raíz.
3. Corrígelos.
4. Valida que `curl http://<IP-de-cualquier-worker>:31200` devuelve la página de nginx.
5. Valida que las **3 réplicas** están `Running` y repartidas.

## Restricciones

* **No elimines** el Deployment `shop-web` ni el Service `shop-svc`. Debes repararlos in situ (`edit`, `patch`, `set`, `label`, `scale`, `taint`).
* No cambies el `nodePort` 31200.
* No cambies el nombre del Service ni del Deployment.
* Trabaja únicamente en `c1-challenge` (salvo lo que debas corregir a nivel de nodo).
* No apliques los YAML de `RECURSOS/YAML/` encima para "sobrescribir" el problema: se trata de diagnosticar.

## Ruta de diagnóstico sugerida

```
POD                          SERVICE
get                          Service
 v                            v
describe                    selector
 v                            v
events                      EndpointSlice
 v                            v
logs                        Pod labels
 v                            v
logs --previous             targetPort
```

Y para scheduling:

```
Pod Pending -> Events -> Recursos -> nodeSelector -> Affinity -> Taints/Tolerations
```

## Validación

```bash
kubectl -n c1-challenge get deploy,rs,pods -o wide
kubectl -n c1-challenge get svc shop-svc -o yaml | grep -A8 'ports:\|selector:'
kubectl -n c1-challenge get endpointslices
kubectl -n c1-challenge get events --sort-by=.lastTimestamp | tail -20
kubectl get nodes -L environment
kubectl describe nodes | grep -i -A1 taint
curl -s -o /dev/null -w '%{http_code}\n' http://<IP-WORKER>:31200
```

Comprobación automática:

```bash
cd CLASE-01/RECURSOS/SCRIPTS
./validate-lab.sh
```

## Resultado esperado

* `kubectl -n c1-challenge get deploy shop-web` muestra `3/3` réplicas listas.
* `kubectl -n c1-challenge get endpointslices` muestra **3 direcciones**.
* `curl http://<IP-worker>:31200` devuelve `200` y el HTML de bienvenida de nginx.
* `./validate-lab.sh` termina con `LAB 1.4 SUPERADO`.

## Criterios de éxito

- [ ] Identifiqué todos los fallos sin mirar la solución.
- [ ] Documenté síntoma, comando y causa raíz de cada uno.
- [ ] Las 3 réplicas de `shop-web` están `Running`.
- [ ] El `EndpointSlice` de `shop-svc` tiene 3 direcciones.
- [ ] El acceso por NodePort 31200 devuelve HTTP 200.
- [ ] No eliminé ni recreé el Deployment ni el Service.
- [ ] `./validate-lab.sh` pasa.
