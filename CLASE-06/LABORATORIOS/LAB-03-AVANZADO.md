# LAB 6.3 — Cadena de fallos entre capas

## Nivel

Avanzado.

## Duración

27 minutos.

## Objetivo

Resolver un incidente en el que **cada corrección destapa el siguiente fallo**, obligando a recorrer todas las capas del curso sin poder saltarse ninguna.

## Competencias

* Encadenar los seis mental models.
* Priorizar: qué se arregla primero cuando todo parece roto.
* Trabajar con permisos limitados.
* Validar cada paso antes de seguir al siguiente.

## Escenario

La aplicación **`pedidos`** se despliega en el namespace `c6-pedidos` mediante un pipeline que corre con la ServiceAccount `deployer`. Desde el último cambio:

* el pipeline falla,
* y cuando se despliega a mano, la aplicación tampoco arranca.

Tienes que resolver ambas cosas.

## Estado inicial

```bash
cd CLASE-06/RECURSOS/SCRIPTS
./setup-lab.sh cadena
```

Crea el namespace `c6-pedidos` con una ServiceAccount `deployer`, sus permisos, un StatefulSet, sus PVC, ConfigMaps, Secrets, Services y políticas de red. **Hay 6 fallos encadenados.**

## Requerimientos

1. Averigua qué puede y qué no puede hacer la ServiceAccount `deployer`, y corrige sus permisos al mínimo necesario para desplegar y consultar la aplicación (no más).
2. Consigue que el StatefulSet `pedidos` levante sus **3 réplicas**.
3. Consigue que cada réplica tenga su volumen montado y escribible.
4. Consigue que la aplicación reciba su configuración y sus credenciales.
5. Consigue que `pedidos-0` sea alcanzable por su nombre DNS individual desde otro Pod del namespace.
6. Documenta, por cada fallo: capa, síntoma, comando, causa raíz, corrección.
7. Al terminar, escribe en tres líneas **en qué orden** habrías tenido que atacarlos y por qué ese orden es el correcto.

## Restricciones

* No uses `cluster-admin` en ningún momento.
* No elimines el StatefulSet: corrígelo o recréalo conservando los PVC si es imprescindible (justifícalo).
* No borres las NetworkPolicies existentes.
* No pongas credenciales en texto plano.
* El almacenamiento debe seguir siendo un volumen por réplica.

## Método sugerido

Trabaja de abajo hacia arriba. Un Pod que no arranca no puede tener un problema de red.

```
1. PERMISOS      -> ¿puedo siquiera operar?           auth can-i
2. SCHEDULING    -> ¿hay nodo para el Pod?            describe pod / events
3. STORAGE       -> ¿enlaza el PVC? ¿monta?           get pvc / describe pod
4. CONFIGURACIÓN -> ¿existen ConfigMap y Secret?      get cm,secret / describe pod
5. APLICACIÓN    -> ¿arranca el proceso?              logs / logs --previous
6. RED           -> ¿resuelve? ¿llega?                nslookup / curl / networkpolicy
```

## Comandos de diagnóstico

```bash
kubectl -n c6-pedidos auth can-i --list \
  --as system:serviceaccount:c6-pedidos:deployer
kubectl -n c6-pedidos get sts,pods,pvc,cm,secret,svc,networkpolicy
kubectl -n c6-pedidos describe pod pedidos-0 | sed -n '/Events/,$p'
kubectl -n c6-pedidos logs pedidos-0 --previous
kubectl -n c6-pedidos get endpointslices
kubectl get pv
kubectl -n c6-pedidos exec <otro-pod> -- nslookup pedidos-0.pedidos
```

## Validación

```bash
kubectl -n c6-pedidos get sts pedidos            # 3/3
kubectl -n c6-pedidos get pvc                    # 3 Bound
kubectl -n c6-pedidos exec pedidos-0 -- sh -c 'touch /data/.probe && rm /data/.probe'
kubectl -n c6-pedidos exec pedidos-0 -- env | grep -E 'APP_|DB_'
kubectl -n c6-pedidos auth can-i create statefulsets \
  --as system:serviceaccount:c6-pedidos:deployer
kubectl -n c6-pedidos auth can-i delete secrets \
  --as system:serviceaccount:c6-pedidos:deployer   # debe ser 'no'

cd CLASE-06/RECURSOS/SCRIPTS && ./validate-lab.sh cadena
```

## Resultado esperado

* `pedidos` con 3/3 réplicas `Running` y `Ready`.
* Tres PVC `Bound`, uno por réplica, escribibles.
* Variables de configuración y credenciales presentes en el contenedor.
* `pedidos-0.pedidos.c6-pedidos.svc.cluster.local` resuelve y responde.
* `deployer` puede desplegar pero **no** puede borrar secretos.
* `./validate-lab.sh cadena` termina con `LAB 6.3 SUPERADO`.

## Criterios de éxito

- [ ] Documenté los 6 fallos con capa, síntoma, comando, causa y corrección.
- [ ] Corregí los permisos sin usar `cluster-admin`.
- [ ] Las 3 réplicas están `Running` y `Ready`.
- [ ] Los 3 PVC están `Bound` y son escribibles.
- [ ] La configuración y las credenciales llegan al contenedor.
- [ ] El DNS por Pod del StatefulSet funciona.
- [ ] No eliminé NetworkPolicies ni usé credenciales en texto plano.
- [ ] Escribí la justificación del orden de ataque.
