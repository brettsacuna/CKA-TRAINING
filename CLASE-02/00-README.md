# Clase 2 — Administración del Cluster: Upgrade, ETCD y RBAC

## Duración

180 minutos.

## Objetivos

1. Inventariar los componentes de un cluster kubeadm y sus versiones.
2. Vaciar y devolver un nodo al servicio con `cordon`, `drain` y `uncordon`.
3. Actualizar un cluster kubeadm completo: control plane primero, workers después.
4. Localizar la configuración, los certificados y el endpoint de etcd a partir del manifiesto estático del API server.
5. Crear y **validar** un snapshot de etcd, y restaurarlo.
6. Diseñar permisos RBAC con Role, RoleBinding, ClusterRole y ClusterRoleBinding.
7. Diagnosticar un `Forbidden` con `kubectl auth can-i`.

## Contenidos

* Arquitectura kubeadm: static Pods en `/etc/kubernetes/manifests`, `kubelet`, `kubeadm`, `kubectl`, `crictl`.
* Version skew: qué se actualiza antes que qué y por qué.
* `cordon` / `drain --ignore-daemonsets --delete-emptydir-data` / `uncordon`.
* Repositorios `pkgs.k8s.io` por minor version. `apt-mark hold` / `unhold`.
* `kubeadm upgrade plan`, `kubeadm upgrade apply`, `kubeadm upgrade node`.
* etcd: `--etcd-servers`, `--etcd-cafile`, `--etcd-certfile`, `--etcd-keyfile`. `/var/lib/etcd`.
* `etcdctl snapshot save`, `etcdctl endpoint status`, **`etcdutl snapshot status`**, **`etcdutl snapshot restore`**.
* RBAC: whitelisting, permisos aditivos, mínimo privilegio.
* Role vs ClusterRole; RoleBinding vs ClusterRoleBinding; la combinación ClusterRole + RoleBinding.
* Users, Groups y ServiceAccounts. `kubectl auth can-i --as`, `--as-group`, `-A`.

## Actualizaciones técnicas respecto al material original

| Tema | Estado | Cambio aplicado |
|---|---|---|
| Repositorio `apt.kubernetes.io` / `packages.cloud.google.com` | **LEGACY** | Sustituido por `pkgs.k8s.io`, con repositorio distinto por cada minor |
| `etcdctl snapshot restore` | **REQUIERE ACTUALIZACIÓN** | Deprecado en favor de **`etcdutl snapshot restore`** |
| `ETCDCTL_API=3` | **LEGACY** | v3 es el valor por defecto; se mantiene solo como nota histórica |
| `--record` en cambios | **ELIMINADO** | Sustituido por la anotación `kubernetes.io/change-cause` |
| `crictl ps` con Docker | **LEGACY** | El runtime es containerd; `crictl` es la herramienta correcta |
| Versiones 1.23 / 1.26 / 1.27 | **REQUIERE ACTUALIZACIÓN** | El curso trabaja **v1.34.x → v1.35.x** |

## Agenda (180 min)

| Tiempo | Actividad |
|---|---|
| 00–12 | Repaso de la Clase 1 y objetivos |
| 12–35 | Conceptos: arquitectura kubeadm, static Pods, version skew |
| 35–50 | **Demo**: `drain` en vivo, ver a dónde se mueven los Pods, `uncordon` |
| 50–70 | **LAB 2.1 — Básico**: inventario, cordon, drain, uncordon |
| 70–105 | **LAB 2.2 — Intermedio**: upgrade del control plane y del worker |
| 105–118 | Conceptos: etcd, certificados y estrategia de backup |
| 118–145 | **LAB 2.3 — Avanzado**: snapshot, validación y restore de etcd |
| 145–158 | Conceptos: RBAC en 10 minutos (los 4 objetos y las 3 combinaciones) |
| 158–176 | **LAB 2.4 — Challenge**: `Forbidden` en producción |
| 176–180 | Cierre y CKA Tips |

## Presentación

[`01-CLASE-02-CKA.pptx`](01-CLASE-02-CKA.pptx)

## Laboratorios

| Lab | Nivel | Archivo |
|---|---|---|
| LAB 2.1 | Básico | [LABORATORIOS/LAB-01-BASICO.md](LABORATORIOS/LAB-01-BASICO.md) |
| LAB 2.2 | Intermedio | [LABORATORIOS/LAB-02-INTERMEDIO.md](LABORATORIOS/LAB-02-INTERMEDIO.md) |
| LAB 2.3 | Avanzado | [LABORATORIOS/LAB-03-AVANZADO.md](LABORATORIOS/LAB-03-AVANZADO.md) |
| LAB 2.4 | Challenge | [LABORATORIOS/LAB-04-CHALLENGE.md](LABORATORIOS/LAB-04-CHALLENGE.md) |

## Recursos

* [`RECURSOS/YAML/`](RECURSOS/YAML/) — manifiestos RBAC de referencia.
* [`RECURSOS/SCRIPTS/`](RECURSOS/SCRIPTS/) — `setup-lab.sh`, `validate-lab.sh`, `reset-lab.sh`, `etcd-backup.sh`.

> **Aviso de entorno.** Los LAB 2.2 y 2.3 modifican el cluster. Ejecútalos en el cluster de laboratorio, **nunca** en uno compartido, y toma un snapshot de etcd antes de empezar el upgrade.

## Checklist final de la clase

- [ ] Sé listar las versiones de `kubeadm`, `kubelet`, `kubectl` y del servidor.
- [ ] Vacío un nodo con `drain` y entiendo por qué necesita `--ignore-daemonsets`.
- [ ] Actualizo el control plane con `kubeadm upgrade apply`.
- [ ] Actualizo un worker con `kubeadm upgrade node`.
- [ ] Sé en qué orden van `kubeadm`, `kubelet` y `kubectl`.
- [ ] Localizo el endpoint y los certificados de etcd sin buscar en Google.
- [ ] Creo un snapshot y lo valido con `etcdutl snapshot status`.
- [ ] Restauro etcd y recupero el estado del cluster.
- [ ] Distingo Role de ClusterRole y RoleBinding de ClusterRoleBinding.
- [ ] Diagnostico un `Forbidden` con `kubectl auth can-i --as`.
