# LAB 6.4 — Challenge contrarreloj: 15 minutos

## Nivel

Challenge / Troubleshooting.

## Duración

15 minutos **cronometrados**.

## Objetivo

Reproducir la presión del examen: cinco tareas independientes, tiempo insuficiente para hacerlas con calma, y la obligación de decidir el orden.

## Competencias

* Priorizar tareas por coste y beneficio.
* Ejecutar sin dudar los comandos de uso frecuente.
* Abandonar una tarea a tiempo y volver luego.
* Validar rápido.

## Escenario

Cinco incidentes simultáneos en el namespace **`c6-sprint`** y en el cluster. No te dará tiempo a hacerlos todos con comodidad. **Cada tarea tiene un peso**, igual que en el examen.

## Estado inicial

```bash
cd CLASE-06/RECURSOS/SCRIPTS
./setup-lab.sh sprint
```

Arranca tu cronómetro. **15 minutos.**

## Tareas

| # | Peso | Tarea |
|---|---|---|
| T1 | 8 % | El Deployment `api` no tiene ninguna réplica disponible. Consigue **3/3**. |
| T2 | 5 % | El Service `api-svc` no enruta tráfico a los Pods de `api`. Repáralo sin cambiar los labels de los Pods. |
| T3 | 12 % | El Pod `batch` está en `CrashLoopBackOff`. Averigua por qué e impide que siga reiniciándose, dejándolo `Running`. |
| T4 | 7 % | La ServiceAccount `viewer` en `c6-sprint` debe poder **listar** Pods y Deployments del namespace y nada más. Ahora mismo no puede. |
| T5 | 3 % | Un nodo del cluster no acepta Pods nuevos. Devuélvelo al servicio. |

## Restricciones

* 15 minutos. Cuando suene, para.
* No elimines Deployments ni Services: corrígelos.
* T4 debe cumplirse con mínimo privilegio.
* Puedes usar cualquier comando de `kubectl` y la documentación oficial.

## Recomendación de método

1. **Minuto 0–1:** lee las cinco tareas y ordénalas por peso y dificultad estimada. No empieces por T1 solo porque es la primera.
2. Ataca primero lo de mayor peso que sepas resolver rápido.
3. Si una tarea te lleva más de 4 minutos, **déjala** y vuelve al final.
4. Valida cada tarea nada más terminarla: una tarea "casi hecha" puntúa cero.

## Validación

```bash
kubectl -n c6-sprint get deploy api                  # 3/3
kubectl -n c6-sprint get endpointslices              # api-svc con 3 direcciones
kubectl -n c6-sprint get pod batch                   # Running, sin reinicios nuevos
kubectl -n c6-sprint auth can-i list pods \
  --as system:serviceaccount:c6-sprint:viewer        # yes
kubectl -n c6-sprint auth can-i delete pods \
  --as system:serviceaccount:c6-sprint:viewer        # no
kubectl get nodes                                    # ninguno SchedulingDisabled

cd CLASE-06/RECURSOS/SCRIPTS && ./validate-lab.sh sprint
```

## Resultado esperado

`./validate-lab.sh sprint` muestra el porcentaje conseguido sobre 35 puntos y el detalle por tarea.

## Criterios de éxito

- [ ] Dediqué el primer minuto a leer y priorizar.
- [ ] Validé cada tarea al terminarla.
- [ ] Abandoné a tiempo alguna tarea si se atascó.
- [ ] Conseguí al menos **24 de 35 puntos** (equivalente al 66 % de aprobado del CKA).
- [ ] Puedo explicar la causa raíz de cada tarea que resolví.
- [ ] Identifiqué qué tarea me costó más tiempo del previsto y por qué.
