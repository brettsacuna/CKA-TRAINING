# LAB 6.5 — LABORATORIO INTEGRADOR FINAL

## Nivel

Integrador (avanzado + challenge).

## Duración

50 minutos.

## Objetivo

Desplegar de principio a fin una arquitectura completa que use **todo** lo visto en las 18 horas, y después repararla cuando el instructor inyecte fallas.

Este laboratorio es la evolución de la evaluación final del curso original.

## Competencias

Todas las del curso, integradas: workloads, scheduling, storage, StatefulSets, configuración, secretos, recursos, Services, Ingress, TLS, DNS y NetworkPolicy.

## Arquitectura a construir

```
                    INTERNET
                       |
                     HTTPS
                       |
                    INGRESS
                       |
              +--------+--------+
              |                 |
          FRONTEND           BACKEND
          (Deployment)      (Deployment)
                                |
                          HEADLESS SVC
                                |
                           STATEFULSET
                                |
                               PVC
                                |
                             STORAGE
```

## Estado inicial

* Namespace de trabajo: **`tienda`** (lo creas tú).
* Ingress Controller instalado (Clase 5).
* Metrics Server instalado (Clase 4).
* Cluster con al menos dos nodos programables.

---

# FASE 1 — CONSTRUCCIÓN (30 minutos)

Construye, a partir de estos requerimientos, sin manifiestos dados.

## R1 — Namespace y configuración

1. Namespace **`tienda`**.
2. ConfigMap **`app-config`** con:
   * `APP_ENV=production`
   * `BACKEND_URL=http://backend.tienda.svc.cluster.local`
3. Secret **`db-credentials`** (tipo `Opaque`) con:
   * `username=appuser`
   * `password=T13nd4-2026`

## R2 — Base de datos con estado

4. **Headless Service** `db` (`clusterIP: None`), puerto 5432.
5. **StatefulSet** `db` con:
   * **3 réplicas**, `serviceName: db`,
   * imagen `postgres:16-alpine`,
   * `POSTGRES_USER` y `POSTGRES_PASSWORD` tomados del Secret `db-credentials`,
   * `volumeClaimTemplates` que cree un PVC de **1Gi** por réplica, modo **`ReadWriteOnce` (RWO)**, montado en `/var/lib/postgresql/data`,
   * `requests`: `cpu=100m`, `memory=128Mi`; `limits`: `cpu=500m`, `memory=512Mi`,
   * las réplicas deben repartirse entre nodos distintos siempre que sea posible.

> Si tu cluster no tiene StorageClass por defecto, crea los PV necesarios antes.

## R3 — Backend

6. **Deployment** `backend`, 2 réplicas, imagen `nginx:1.27-alpine`:
   * recibe **todas** las claves de `app-config` con `envFrom`,
   * recibe `DB_PASSWORD` desde el Secret,
   * monta el Secret completo en `/etc/db-credentials` en solo lectura,
   * `requests` `cpu=100m`, `memory=64Mi`; `limits` `cpu=300m`, `memory=256Mi`,
   * `readinessProbe` HTTP sobre `/` en el puerto 80.
7. Service **`backend`** de tipo ClusterIP, puerto 80.

## R4 — Frontend

8. **Deployment** `frontend`, 2 réplicas, imagen `nginx:1.27-alpine`, con los mismos criterios de recursos y readiness.
9. Service **`frontend`** de tipo ClusterIP, puerto 80.

## R5 — Publicación

10. Certificado autofirmado con `CN=tienda.local` y Secret TLS **`tienda-tls`** en el namespace `tienda`.
11. **Ingress** `tienda` con:
    * el `ingressClassName` de tu controlador,
    * host `tienda.local`,
    * `/` → `frontend:80`,
    * `/api` → `backend:80`,
    * TLS con `tienda-tls`.

## R6 — Seguridad de red

12. NetworkPolicy **`default-deny`** en `tienda` (Ingress y Egress para todos los Pods).
13. Políticas adicionales que permitan **exclusivamente**:
    * DNS para todos los Pods,
    * `frontend` → `backend` (puerto 80),
    * `backend` → `db` (puerto 5432),
    * entrada desde el namespace del Ingress Controller hacia `frontend` y `backend`.

## R7 — Verificación de recursos

14. Comprueba con `kubectl top pods -n tienda` el consumo real y compáralo con lo solicitado.
15. Revisa los eventos del namespace y confirma que no hay advertencias pendientes.

## Validación de la Fase 1

```bash
kubectl -n tienda get all,pvc,cm,secret,ingress,networkpolicy
kubectl -n tienda get sts db -o jsonpath='{.spec.serviceName}{"\n"}'
kubectl -n tienda get pvc
kubectl -n tienda get pods -o wide
kubectl -n tienda exec deploy/backend -- env | grep -E 'APP_ENV|BACKEND_URL|DB_PASSWORD'
kubectl -n tienda exec deploy/frontend -- curl -s --max-time 3 -o /dev/null -w '%{http_code}\n' http://backend
curl -sk -o /dev/null -w '%{http_code}\n' https://tienda.local:32443/ \
  --resolve tienda.local:32443:<IP-NODO>
kubectl top pods -n tienda
kubectl -n tienda get events --sort-by=.lastTimestamp | tail -20
```

### Criterios de éxito de la Fase 1

- [ ] Namespace `tienda` con ConfigMap y Secret creados.
- [ ] StatefulSet `db` con 3/3 réplicas y 3 PVC RWO de 1Gi.
- [ ] Headless Service `db` con `clusterIP: None`.
- [ ] Las réplicas de `db` están repartidas entre nodos.
- [ ] `backend` y `frontend` con 2/2 réplicas, readiness y recursos definidos.
- [ ] El Secret está montado como volumen en `backend` en solo lectura.
- [ ] Ingress con host, dos paths y TLS propio.
- [ ] HTTPS responde 200 en `/` y en `/api`.
- [ ] `default-deny` aplicado y el tráfico autorizado sigue funcionando.
- [ ] `kubectl top pods` devuelve datos del namespace.

---

# FASE 2 — TROUBLESHOOTING (20 minutos)

Cuando el instructor lo indique:

```bash
cd CLASE-06/RECURSOS/SCRIPTS
./inject-failures.sh
```

El script inyecta **entre 5 y 8 fallas** en la arquitectura que acabas de construir. Las categorías posibles son:

1. selector incorrecto,
2. ConfigMap mal referenciado,
3. Secret inexistente o clave equivocada,
4. PVC en `Pending`,
5. NetworkPolicy bloqueando `frontend` → `backend`,
6. Ingress apuntando al Service o puerto incorrecto,
7. problema de scheduling (taint, `nodeSelector` o `requests` irreales),
8. `targetPort` incorrecto.

**No se te dice cuáles se han aplicado ni cuántas.**

## Requerimientos de la Fase 2

16. Identifica **todas** las fallas.
17. Documenta, por cada una: capa, síntoma, comando que la reveló, causa raíz, corrección.
18. Repara la arquitectura hasta que vuelva a superar la validación de la Fase 1.
19. **No reconstruyas desde cero**: repara in situ.

## Restricciones de la Fase 2

* Prohibido borrar el namespace y volver a empezar.
* Prohibido borrar la política `default-deny`.
* Prohibido eliminar los PVC del StatefulSet.
* Prohibido usar `cluster-admin`.
* Los datos de la base de datos deben conservarse.

## Validación final

```bash
cd CLASE-06/RECURSOS/SCRIPTS
./validate-lab.sh final
```

## Criterios de éxito de la Fase 2

- [ ] Identifiqué todas las fallas inyectadas.
- [ ] Documenté capa, síntoma, comando, causa raíz y corrección de cada una.
- [ ] La arquitectura vuelve a superar la validación completa.
- [ ] No borré el namespace ni reconstruí desde cero.
- [ ] `default-deny` sigue en pie.
- [ ] Los PVC y sus datos se conservaron.
- [ ] `./validate-lab.sh final` termina con `LABORATORIO INTEGRADOR SUPERADO`.

---

## Entregables (opcional, para evaluación formal)

Si la clase se evalúa, cada participante entrega:

1. Los manifiestos YAML de la Fase 1, empaquetados: `tar -czf tienda-<apellido>.tar.gz manifests/`
2. El host y el puerto por el que se accede al Ingress.
3. Un documento con el desarrollo paso a paso y la tabla de diagnóstico de la Fase 2.
