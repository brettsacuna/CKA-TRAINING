# LAB 15.3 — Examen práctico: escenario roto de extremo a extremo

## Nivel

Examen práctico — contra reloj.

## Duración

40 minutos.

## Objetivo

GRATITUD desplegado pero con **9 fallos** repartidos por las seis capas.
Diagnosticar y reparar en el tiempo asignado. Se puntúa con `evaluar.sh` según la
rúbrica.

```
IDENTIFICAR -> DIAGNOSTICAR -> CORREGIR -> VALIDAR
```

## Reglas

* **40 minutos**. Al acabar, `./evaluar.sh` para la puntuación.
* Aprobado: **≥ 80 %** del total.
* **Prohibido**: `cluster-admin` o `edit` para "desatascar" RBAC; borrar `default-deny`; quitar sondas o límites; convertir Services a `NodePort`; recrear objetos desde cero.
* Permitido: `kubectl edit`/`patch`, `helm upgrade`, recrear un PVC (campo inmutable), y consultar `kubernetes.io/docs`.

## Estado inicial

```bash
cd CLASE-15/RECURSOS/SCRIPTS
chmod +x *.sh
./setup-examen.sh
```

Instala GRATITUD y le inyecta **9 fallos**. Síntomas visibles:

* algún Pod no llega a `Ready`; algún Service sin endpoints;
* la API no arranca del todo; la caché no monta su volumen;
* el Ingress no responde y el HTTPS no presenta tu certificado;
* la ServiceAccount de despliegue no puede actualizar nada;
* el portal no alcanza a la API.

## Método sugerido

1. **Clasifica** los síntomas por capa antes de tocar nada:
   ```bash
   kubectl -n gratitud get pod,svc,endpointslices,ingress,pvc
   kubectl -n gratitud get events --sort-by=.lastTimestamp | tail -20
   kubectl -n gratitud describe pod -l tier=api | sed -n '/Events/,$p'
   ```
2. **Repara de dentro hacia fuera**:
   * Capa 1 — selector y `targetPort` de los Services; `endpointslices`.
   * Capa 3 — `secretKeyRef`/`configMapRef` de la API; `claimName` del volumen de la caché; `PVC`.
   * Capa 4 — puerto de la `readinessProbe` del portal.
   * Capa 2 — `ingressClassName`; `secretName` del bloque `tls`.
   * Capa 5 — `subjects` del `RoleBinding`; la NetworkPolicy `portal → api` que falta.
3. **Verifica cada arreglo** antes de pasar al siguiente (`kubectl get`, `exec`, `auth can-i`).
4. Cuando creas haber terminado:
   ```bash
   ./evaluar.sh
   ```

## Comandos de diagnóstico

```bash
kubectl -n gratitud get svc api -o yaml | grep -E 'selector|Port'
kubectl -n gratitud get endpointslices
kubectl -n gratitud describe pod -l tier=api  | sed -n '/Events/,$p'
kubectl -n gratitud describe pod -l tier=cache | sed -n '/Events/,$p'
kubectl -n gratitud get deploy portal -o jsonpath='{.spec.template.spec.containers[0].readinessProbe}{"\n"}'
kubectl -n gratitud get ingress gratitud -o yaml | grep -E 'ingressClassName|secretName'
kubectl -n gratitud get rolebinding gratitud-deployer -o yaml
kubectl -n gratitud get networkpolicy
kubectl auth can-i update deploy -n gratitud --as=system:serviceaccount:gratitud:gratitud-deployer
```

## Validación

```bash
cd CLASE-15/RECURSOS/SCRIPTS && ./evaluar.sh
# imprime la puntuación por área y el total; APROBADO si >= 80 %
```

## Los 9 fallos (para el instructor — no mirar antes)

<details>
<summary>Spoiler</summary>

| # | Capa | Fallo | Corrección |
|---|---|---|---|
| 1 | Services | `svc/api` selector `tier: api-v2` | `tier: api` |
| 2 | Services | `svc/cache` `targetPort: 80` | `8080` |
| 3 | Ingress | `ingressClassName: nginx` | el del controlador (`traefik`) |
| 4 | Ingress/TLS | `tls[0].secretName: gratitud-tls-old` | `gratitud-tls` |
| 5 | Config | `api` `secretKeyRef.key: PARTNER` | `PARTNER_TOKEN` |
| 6 | Storage | `cache` volumen `claimName: gratitud-upload` | `gratitud-uploads` |
| 7 | Observabilidad | `portal` `readinessProbe.httpGet.port: 9090` | `8080` |
| 8 | Seguridad/RBAC | `rolebinding/gratitud-deployer` `subjects[0].name: gratitud-deploy` | `gratitud-deployer` |
| 9 | Seguridad/NetPol | falta la NetworkPolicy `allow-portal-to-api` | recrearla (`helm upgrade` la reinstala) |

</details>

## Resultado esperado

* `./evaluar.sh` con **≥ 80 %** y, idealmente, `./validar-gratitud.sh` todo en `[OK]`.

## Criterios de éxito

- [ ] Clasifiqué los 9 síntomas por capa antes de tocar nada.
- [ ] Reparé de dentro hacia fuera, verificando cada arreglo.
- [ ] No usé `cluster-admin` ni borré `default-deny` ni quité sondas.
- [ ] `./evaluar.sh` da **APROBADO**.
