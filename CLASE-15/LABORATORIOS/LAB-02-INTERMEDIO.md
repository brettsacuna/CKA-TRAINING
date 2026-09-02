# LAB 15.2 — Validación en tiempo real

## Nivel

Validación.

## Duración

25 minutos.

## Objetivo

Recorrer las seis capas de GRATITUD con el script de validación y a mano,
entender **qué demuestra cada comprobación** y ver el script detectar un fallo
que provoques a propósito.

## Competencias

* Leer un recorrido de validación de dentro hacia fuera.
* Reproducir a mano las comprobaciones clave de cada capa.
* Confiar en `[OK]`/`[FALLA]` porque sabes qué hay detrás.

## Estado inicial

* GRATITUD desplegado y pasando `validar-gratitud.sh` (LAB 15.1).

## Requerimientos

### Parte A — El recorrido completo

1. Ejecuta la validación y **lee cada línea**:
   ```bash
   cd CLASE-15/RECURSOS/SCRIPTS && ./validar-gratitud.sh
   ```
2. Para cada capa, di en una frase qué demuestra el bloque:
   * Capa 1 — `readyReplicas`, `endpointslices`, `targetPort`, `wget http://cache`.
   * Capa 2 — `ADDRESS` del Ingress, tipo del Secret TLS.
   * Capa 3 — objetos de config, variables inyectadas, `PVC Bound`, persistencia.
   * Capa 4 — `kubectl top`, `kubectl logs`.
   * Capa 5 — `auth can-i --as`, número de NetworkPolicies, `default-deny`, etiqueta `enforce`.
   * Capa 6 — `helm status`.

### Parte B — Reproducir a mano

3. Reproduce **cuatro** comprobaciones sin el script y explica qué demuestran:
   ```bash
   kubectl -n gratitud get endpointslices -l kubernetes.io/service-name=api
   kubectl -n gratitud exec deploy/api -- sh -c 'wget -qO- http://cache && echo " <- cache OK"'
   kubectl -n gratitud exec deploy/api -- printenv | grep -E 'DB_PASSWORD|PARTNER_TOKEN|LOG_LEVEL'
   kubectl auth can-i get secrets -n gratitud --as=system:serviceaccount:gratitud:gratitud-deployer
   ```

### Parte C — Provocar y detectar un fallo

4. Rompe una cosa (elige una):
   ```bash
   # A) endpoints: cambia el selector del Service api
   kubectl -n gratitud patch svc api --type=merge -p '{"spec":{"selector":{"tier":"api-x"}}}'
   # B) config: renombra una clave del ConfigMap
   kubectl -n gratitud patch configmap gratitud-config --type=merge -p '{"data":{"LOG_LEVEL":null,"LOGLEVEL":"info"}}'
   ```
5. Ejecuta `./validar-gratitud.sh` y localiza la línea `[FALLA]` que aparece. Explica por qué.
6. **Revierte** el cambio y confirma que el script vuelve a estar todo en `[OK]`:
   ```bash
   kubectl -n gratitud patch svc api --type=merge -p '{"spec":{"selector":{"app.kubernetes.io/instance":"gratitud","tier":"api"}}}'
   # o helm upgrade gratitud ../CHART/gratitud -n gratitud -f ../CHART/gratitud/values-examen.yaml
   ```

### Parte D — El mapa

7. Escribe una tabla **capa → comando → señal de éxito** con los diez puntos que consideres más representativos. Es tu chuleta para el examen práctico.

## Restricciones

* No dejes ningún fallo sin revertir.
* Al terminar, `validar-gratitud.sh` debe estar todo en `[OK]`.

## Validación

```bash
cd CLASE-15/RECURSOS/SCRIPTS && ./validar-gratitud.sh   # INTEGRADOR SUPERADO
```

## Resultado esperado

* Sabes explicar qué demuestra cada bloque del script.
* Reprodujiste a mano al menos cuatro comprobaciones.
* Provocaste un fallo, lo viste en `[FALLA]`, lo explicaste y lo revertiste.
* Tienes tu mapa capa → comando → señal.

## Criterios de éxito

- [ ] Recorrí las seis capas con el script y entendí cada línea.
- [ ] Reproduje cuatro comprobaciones a mano.
- [ ] El script detectó el fallo que provoqué, en la capa correcta.
- [ ] Reverti y el script quedó todo en `[OK]`.
- [ ] Escribí el mapa capa → comando → señal.
