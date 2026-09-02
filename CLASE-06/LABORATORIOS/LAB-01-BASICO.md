# LAB 6.1 — Traducir estados: seis Pods, seis causas

## Nivel

Básico.

## Duración

20 minutos.

## Objetivo

Convertir el estado de un Pod en una hipótesis de causa **antes** de investigar, y confirmarla con un solo comando.

## Competencias

* Reconocer `Pending`, `ImagePullBackOff`, `CreateContainerConfigError`, `CrashLoopBackOff`, `Running 0/1` y `OOMKilled`.
* Elegir el comando correcto para cada estado.
* Distinguir `logs` de `logs --previous`.
* Reparar cada caso.

## Escenario

En el namespace **`c6-estados`** hay seis Pods, cada uno roto de una forma distinta. Tu trabajo no es solo arreglarlos: es **saber decir, mirando solo `kubectl get pods`, dónde está el problema en cada caso**.

## Estado inicial

```bash
cd CLASE-06/RECURSOS/SCRIPTS
./setup-lab.sh basico
```

## Requerimientos

1. Ejecuta `kubectl -n c6-estados get pods` y, **antes de investigar nada**, rellena esta tabla con tu hipótesis:

| Pod | Estado observado | Capa donde sospecho | Comando que lo confirmará |
|---|---|---|---|
| `caso-1` | | | |
| `caso-2` | | | |
| `caso-3` | | | |
| `caso-4` | | | |
| `caso-5` | | | |
| `caso-6` | | | |

2. Confirma cada hipótesis con **un solo comando** por caso. Si necesitas más de dos, anótalo: significa que la hipótesis no estaba afinada.
3. Anota la causa raíz exacta de cada uno.
4. Repara los seis.
5. Para el caso que reinicia en bucle, obtén los logs de la **instancia anterior** del contenedor, no de la actual. Anota el comando.

## Restricciones

* No borres ningún Pod hasta haber diagnosticado su causa.
* No apliques los YAML de referencia por encima.
* Para cada caso, la reparación debe atacar la causa, no el síntoma.

## Tabla de traducción (rellénala tú durante el laboratorio)

| Estado | Significa que… | Mirar en |
|---|---|---|
| `Pending` | | |
| `ContainerCreating` (atascado) | | |
| `ImagePullBackOff` | | |
| `CreateContainerConfigError` | | |
| `CrashLoopBackOff` | | |
| `Running` con `0/1 READY` | | |
| `OOMKilled` en `Last State` | | |

## Validación

```bash
kubectl -n c6-estados get pods
kubectl -n c6-estados get pods -o custom-columns=\
NAME:.metadata.name,STATUS:.status.phase,READY:.status.containerStatuses[0].ready,\
RESTARTS:.status.containerStatuses[0].restartCount

cd CLASE-06/RECURSOS/SCRIPTS && ./validate-lab.sh basico
```

## Resultado esperado

Los seis Pods en `Running` y `1/1 READY`, sin reinicios crecientes.

## Criterios de éxito

- [ ] Rellené la tabla de hipótesis **antes** de investigar.
- [ ] Confirmé cada caso con uno o dos comandos.
- [ ] Documenté las seis causas raíz.
- [ ] Usé `logs --previous` en el caso que corresponde.
- [ ] Los seis Pods están `Running` y `Ready`.
- [ ] Completé la tabla de traducción de estados.
