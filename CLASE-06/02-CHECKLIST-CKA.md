# CHECKLIST CKA — Competencias trabajadas en las 18 horas

Marca cada casilla solo cuando puedas hacerlo **sin consultar apuntes**, en menos de dos minutos y validando el resultado.

Al lado de cada bloque figura la clase donde se trabajó y el peso aproximado del dominio en el examen.

---

## Fundamentos y kubectl · Clase 1

- [ ] Configurar `alias k=kubectl`, `export do`, `export now` y el autocompletado.
- [ ] Cambiar de contexto y de namespace (`kubectl config use-context`, `set-context --current --namespace`).
- [ ] Crear un Pod imperativa y declarativamente.
- [ ] Generar un manifiesto con `--dry-run=client -o yaml`.
- [ ] Consultar un campo con `kubectl explain`.
- [ ] Etiquetar y filtrar objetos con `-l`.
- [ ] Leer `get`, `describe`, `logs`, `logs --previous`, `exec`, `get events`.

## Workloads y Scheduling · Clases 1, 3 y 4 · *15 %*

- [ ] Crear un Deployment y escalarlo.
- [ ] Explicar `Deployment -> ReplicaSet -> Pod` con `ownerReferences`.
- [ ] Demostrar el self-healing.
- [ ] Ejecutar un Rolling Update.
- [ ] Consultar `rollout history` y el detalle de una revisión.
- [ ] Registrar la causa con `kubernetes.io/change-cause`.
- [ ] Ejecutar un rollback a una revisión concreta.
- [ ] Configurar `maxSurge`, `maxUnavailable` y `revisionHistoryLimit`.
- [ ] Etiquetar nodos y usar `nodeSelector`.
- [ ] Aplicar y retirar un taint; escribir una toleration.
- [ ] Escribir `nodeAffinity` `required` y `preferred` con `weight`.
- [ ] Usar `podAntiAffinity` con `topologyKey`.
- [ ] Crear una PriorityClass y explicar la preemption.
- [ ] Diagnosticar un Pod `Pending` leyendo los eventos.
- [ ] Definir `requests` y `limits` y deducir la clase de QoS.
- [ ] Instalar Metrics Server y usar `kubectl top`.

## Cluster Architecture, Installation & Configuration · Clase 2 · *25 %*

- [ ] Inventariar versiones de nodos, `kubeadm`, `kubelet` y `kubectl`.
- [ ] Identificar los static Pods del control plane.
- [ ] Usar `crictl` en un nodo.
- [ ] `cordon`, `drain --ignore-daemonsets --delete-emptydir-data`, `uncordon`.
- [ ] Cambiar el repositorio `pkgs.k8s.io` a otra minor.
- [ ] `kubeadm upgrade plan` y `kubeadm upgrade apply` en el control plane.
- [ ] `kubeadm upgrade node` en un worker.
- [ ] Actualizar y reiniciar `kubelet` en el orden correcto.
- [ ] Localizar endpoint y certificados de etcd desde el manifiesto del API server.
- [ ] `etcdctl snapshot save`.
- [ ] `etcdutl snapshot status` para validar un snapshot.
- [ ] `etcdutl snapshot restore` a un data dir nuevo y reapuntar el static Pod.
- [ ] Crear Role y RoleBinding.
- [ ] Crear ClusterRole y ClusterRoleBinding.
- [ ] Usar ClusterRole + RoleBinding para limitar el alcance a un namespace.
- [ ] Crear una ServiceAccount y vincularla correctamente.
- [ ] Auditar con `kubectl auth can-i --as` y `--list`.

## Storage · Clase 3 · *10 %*

- [ ] Compartir datos entre contenedores con `emptyDir`.
- [ ] Crear un PV con capacidad, modo de acceso, clase y `reclaimPolicy`.
- [ ] Crear un PVC y comprobar el binding.
- [ ] Forzar el enlace a un PV concreto con `selector`.
- [ ] Montar un PVC en un Pod.
- [ ] Enumerar las causas por las que un PVC queda `Pending`.
- [ ] Liberar un PV en `Released`.
- [ ] Distinguir aprovisionamiento estático de dinámico.
- [ ] Explicar `Retain` frente a `Delete`.
- [ ] Desplegar un StatefulSet con `volumeClaimTemplates`.
- [ ] Crear un Headless Service y demostrar el DNS por Pod.
- [ ] Explicar por qué los PVC sobreviven al StatefulSet.

## Configuración de aplicaciones · Clase 4

- [ ] Crear ConfigMaps desde literales, archivos y `--from-env-file`.
- [ ] Consumir un ConfigMap con `env`, `envFrom` y como volumen.
- [ ] Crear un Secret `Opaque` y uno `tls`.
- [ ] Consumir un Secret con `secretKeyRef` y como volumen en solo lectura.
- [ ] Explicar por qué base64 no es cifrado.
- [ ] Explicar qué se actualiza en caliente y qué no.

## Services & Networking · Clase 5 · *20 %*

- [ ] Crear `ClusterIP`, `NodePort`, `LoadBalancer` y `ExternalName`.
- [ ] Distinguir `port`, `targetPort` y `nodePort`.
- [ ] Leer un `EndpointSlice` y relacionarlo con el selector.
- [ ] Resolver un Service por su FQDN.
- [ ] Leer `/etc/resolv.conf` de un Pod y explicar `search` y `ndots`.
- [ ] Diagnosticar un fallo de DNS y distinguirlo de un fallo de endpoints.
- [ ] Crear un Ingress con reglas por path y `pathType`.
- [ ] Identificar la `IngressClass` correcta.
- [ ] Crear un TLS Secret y asociarlo a un Ingress por host.
- [ ] Probar con `curl --resolve`.
- [ ] Explicar qué es Gateway API y por qué existe.
- [ ] Escribir una NetworkPolicy `default deny`.
- [ ] Permitir DNS explícitamente en una política de egress.
- [ ] Permitir tráfico entre Pods con `podSelector` en ambas direcciones.
- [ ] Usar `namespaceSelector` y distinguir el AND del OR.

## Troubleshooting · Clase 6 · *30 %*

- [ ] Traducir `Pending` a su causa probable.
- [ ] Traducir `ImagePullBackOff`.
- [ ] Traducir `CreateContainerConfigError`.
- [ ] Traducir `CrashLoopBackOff` y usar `logs --previous`.
- [ ] Traducir `Running 0/1 READY`.
- [ ] Traducir `OOMKilled` y el exit code 137.
- [ ] Diagnosticar un nodo `NotReady`.
- [ ] Distinguir `NotReady` de `SchedulingDisabled`.
- [ ] Leer `journalctl -u kubelet`.
- [ ] Usar `crictl` cuando `kubectl` no responde.
- [ ] Recuperar un static Pod mal escrito.
- [ ] Diagnosticar un Service sin endpoints.
- [ ] Diagnosticar un PVC que no enlaza.
- [ ] Diagnosticar un `Forbidden` de RBAC.
- [ ] Diagnosticar tráfico bloqueado por NetworkPolicy.
- [ ] Diagnosticar un Ingress que no enruta.
- [ ] Diagnosticar un rollout atascado y revertirlo.
- [ ] Resolver una cadena de fallos entre varias capas, en orden.

## Estrategia de examen

- [ ] Leo todas las tareas y anoto sus pesos antes de empezar.
- [ ] Cambio de contexto y namespace según indica cada tarea.
- [ ] Abandono a tiempo una tarea atascada y vuelvo al final.
- [ ] Valido cada tarea nada más terminarla.
- [ ] Uso solo `kubernetes.io/docs` y `kubectl explain`.
