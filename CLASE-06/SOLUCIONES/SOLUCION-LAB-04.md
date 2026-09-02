# SOLUCIÓN — LAB 6.4 · Challenge contrarreloj

> **MATERIAL DEL INSTRUCTOR.**

## Diagnóstico

| Tarea | Peso | Causa raíz | Tiempo objetivo |
|---|---|---|---|
| T1 | 8 % | `requests.cpu: "5"` en el Deployment `api`: ningún nodo lo ofrece | 2 min |
| T2 | 5 % | El Service `api-svc` selecciona `app=api-backend`; los Pods llevan `app=api` | 1 min |
| T3 | 12 % | El Pod `batch` ejecuta `cat /config/job.conf`, que no existe: sale con error en bucle | 3 min |
| T4 | 7 % | La SA `viewer` no tiene ningún Role ni Binding | 2 min |
| T5 | 3 % | Un nodo quedó `cordon` | 30 s |

Orden óptimo por relación peso/tiempo: **T5 → T2 → T1 → T4 → T3**. Casi nadie lo hace: la mayoría empieza por T1 porque es la primera de la lista. Es exactamente el hábito que este laboratorio pretende corregir.

## Procedimiento

```bash
NS=c6-sprint

# T5 (30 s, 3 puntos: lo más barato del examen)
k get nodes | grep SchedulingDisabled
k uncordon <nodo>

# T2 (1 min, 5 puntos)
k -n $NS get svc api-svc -o jsonpath='{.spec.selector}{"\n"}'
k -n $NS get pods --show-labels
k -n $NS patch svc api-svc -p '{"spec":{"selector":{"app":"api"}}}'

# T1 (2 min, 8 puntos)
k -n $NS describe pod -l app=api | sed -n '/Events/,$p'
k -n $NS set resources deploy/api --requests=cpu=100m,memory=64Mi
k -n $NS rollout status deploy/api

# T4 (2 min, 7 puntos)
k -n $NS create role viewer --verb=get,list,watch \
  --resource=pods,deployments.apps
k -n $NS create rolebinding viewer --role=viewer \
  --serviceaccount=c6-sprint:viewer
k -n $NS auth can-i list pods   --as system:serviceaccount:c6-sprint:viewer   # yes
k -n $NS auth can-i delete pods --as system:serviceaccount:c6-sprint:viewer   # no

# T3 (3 min, 12 puntos: el más caro, pero también el que más se atasca)
k -n $NS logs batch --previous
#   cat: can't open '/config/job.conf': No such file or directory
k -n $NS delete pod batch
k -n $NS run batch --image=busybox:1.36 -- sleep 3600
#   o, si se quiere conservar la intención original, crear el ConfigMap y montarlo:
#   k -n $NS create cm job-config --from-literal=job.conf='parametros'
#   y montarlo en /config
```

## Validación

```bash
cd CLASE-06/RECURSOS/SCRIPTS && ./validate-lab.sh sprint
```

## Resultado esperado

```
  T1 [OK]  api 3/3            (+8)
  T2 [OK]  api-svc con endpoints (+5)
  T3 [OK]  batch Running        (+12)
  T4 [OK]  viewer minimo        (+7)
  T5 [OK]  nodos disponibles     (+3)

PUNTUACION: 35/35  (100%)   -- aprobado CKA: 66%
```

## Debriefing (dedica 5 minutos a esto: vale más que el laboratorio)

Pregunta al grupo, en este orden:

1. ¿En qué orden lo hiciste? ¿Por qué ese?
2. ¿Cuál te llevó más tiempo del previsto? ¿En qué momento deberías haberlo abandonado?
3. ¿Validaste cada tarea al terminarla o al final? (Al final es un error: si te quedas sin tiempo, no sabes qué tienes.)
4. ¿Cuántos puntos dejaste sobre la mesa por no leer las cinco tareas primero?

## Error frecuente

* Empezar por T1 sin leer el resto.
* Atascarse en T3 los 15 minutos y sacar 12 de 35 pudiendo haber sacado 23 con las cuatro fáciles.
* No validar. Una tarea "casi hecha" puntúa cero, en el laboratorio y en el examen.
* Olvidar T5, que son 3 puntos gratis en 30 segundos.
* Crear el Role de T4 con `--verb=*`: concede de más y el validador lo detecta.

## CKA Tip

Estrategia de examen destilada:

1. **Primer minuto:** lee todas las tareas y anota su peso.
2. Ordénalas: primero las que sabes hacer rápido y valen mucho.
3. **Marca y salta** cualquier tarea que se pase de tu presupuesto de tiempo.
4. Cambia siempre el contexto y el namespace que te indica el enunciado antes de empezar.
5. Valida cada tarea nada más terminarla.
6. Guarda los últimos 10 minutos para las tareas marcadas.

```bash
alias k=kubectl
export do='--dry-run=client -o yaml'
export now='--force --grace-period=0'
k config use-context <el-que-diga-la-tarea>
```
