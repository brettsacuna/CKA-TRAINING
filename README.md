# CKA HANDS-ON TRAINING — 18 HORAS

Entrenamiento práctico de administración de Kubernetes orientado al examen **CKA (Certified Kubernetes Administrator)**.

Este paquete es una **evolución del curso existente** (`Kubernetes - Completo (1).pptx`): conserva su alcance temático, sus escenarios y sus ejercicios, pero los reorganiza, los actualiza técnicamente y los convierte en un entrenamiento hands-on con laboratorios de dificultad progresiva.

---

## 1. Descripción

| | |
|---|---|
| **Duración total** | 18 horas (6 clases × 180 minutos) |
| **Formato** | 30 % explicación y demostración / 70 % laboratorio |
| **Modalidad** | Presencial o remota con cluster propio por participante o por pareja |
| **Idioma** | Español (comandos y manifiestos en inglés) |
| **Versión Kubernetes** | **v1.35** (ver §5) |

## 2. Objetivos del curso

Al finalizar, el participante será capaz de:

1. Crear, inspeccionar y exponer workloads de forma imperativa y declarativa.
2. Controlar dónde se ejecuta un Pod mediante labels, `nodeSelector`, taints, tolerations, affinity y PriorityClass.
3. Actualizar un cluster kubeadm (control plane y workers) sin perder disponibilidad.
4. Respaldar y restaurar etcd, y validar la recuperación del cluster.
5. Diseñar y depurar permisos RBAC aplicando mínimo privilegio.
6. Administrar workloads stateless y stateful, y almacenamiento persistente (PV, PVC, StorageClass, `volumeClaimTemplates`).
7. Ejecutar Rolling Updates y Rollbacks, escalar aplicaciones y gestionar `requests`/`limits`.
8. Externalizar configuración con ConfigMaps y Secrets.
9. Publicar aplicaciones (ClusterIP, NodePort, LoadBalancer, Ingress, Gateway API) y controlar el tráfico con NetworkPolicy.
10. **Diagnosticar y reparar de forma autónoma** fallos de scheduling, servicios, almacenamiento, configuración, permisos, DNS y red.

La progresión metodológica del curso es:

```
COMPRENDER -> EJECUTAR -> PRACTICAR -> INTEGRAR -> DIAGNOSTICAR -> RESOLVER
```

## 3. Público objetivo

* Administradores de sistemas y SRE que operan o van a operar clusters Kubernetes.
* Ingenieros DevOps / plataforma que necesitan pasar de "usar" a "administrar" Kubernetes.
* Candidatos al examen CKA.

## 4. Prerrequisitos

* Linux a nivel intermedio: `systemctl`, `journalctl`, `vim`, permisos, red básica.
* Conceptos de contenedores (imágenes, registries, runtime).
* Nociones de YAML.
* Haber levantado o tenido contacto previo con un cluster Kubernetes (no obligatorio, pero recomendable).

## 5. Entorno de laboratorio

### Topología mínima

```
cka-master   (control plane)   2 vCPU / 4 GB RAM / 30 GB
cka-worker1  (worker)          2 vCPU / 4 GB RAM / 30 GB
cka-worker2  (worker, opcional pero recomendado para affinity y anti-affinity)
```

Cualquier proveedor sirve: VirtualBox, VMware, Proxmox, GCP, AWS, Azure o multipass.
Las clases 2 y 6 requieren **acceso root por SSH a los nodos**, no solo `kubectl`.

### Software

| Componente | Versión utilizada en el curso |
|---|---|
| Kubernetes (kubeadm, kubelet, kubectl) | **v1.34.x → v1.35.x** (LAB de upgrade en Clase 2) |
| Container runtime | containerd 2.x + `crictl` |
| cgroups | v2 |
| CNI | Calico o Cilium (debe soportar NetworkPolicy) |
| etcd | 3.5.x / 3.6.x — `etcdctl` y `etcdutl` |
| Metrics Server | v0.8.1 |
| Ingress Controller | Traefik (mantenido) — ver nota |
| Gateway API | CRDs v1.x |

> **Nota técnica importante (2026).** El controlador comunitario `kubernetes/ingress-nginx` fue **retirado en marzo de 2026** y su repositorio quedó archivado: no recibe parches de seguridad. El curso original lo utilizaba. Este material conserva la **API Ingress** (que sigue vigente y sigue en el examen), pero la implementa con un controlador mantenido y presenta **Gateway API** como la dirección recomendada por el proyecto. Ver `CLASE-05/`.

### Versión del examen

El currículum CKA vigente se alinea a **Kubernetes v1.35** con esta ponderación:

| Dominio | Peso |
|---|---|
| Cluster Architecture, Installation & Configuration | 25 % |
| Workloads & Scheduling | 15 % |
| Storage | 10 % |
| Services & Networking | 20 % |
| **Troubleshooting** | **30 %** |

Verifica siempre el *Candidate Handbook* de la Linux Foundation antes de rendir: la versión se actualiza con cada release.

## 6. Estructura de las seis clases

| Clase | Tema | Objetivo | Duración |
|---|---|---|---|
| 1 | Pods, YAML, Services y Scheduling | Administrar y exponer workloads básicos y controlar dónde se ejecutan | 180 min |
| 2 | Administración del cluster: Upgrade, ETCD y RBAC | Mantener, recuperar y controlar el acceso al cluster | 180 min |
| 3 | Workloads, Storage y StatefulSets | Administrar workloads stateless/stateful y almacenamiento persistente | 180 min |
| 4 | Application Lifecycle, ConfigMaps, Secrets y Recursos | Actualizar, revertir, escalar y configurar aplicaciones | 180 min |
| 5 | Services, Ingress, Networking, CoreDNS y NetworkPolicy | Publicar aplicaciones y controlar el tráfico | 180 min |
| 6 | Troubleshooting e Integración | Diagnosticar y reparar de forma autónoma | 180 min |

Progresión:

```
CLASE 1  Fundamentos prácticos + Scheduling
   v
CLASE 2  Administración + Upgrade + ETCD + RBAC
   v
CLASE 3  Workloads + Storage + StatefulSets
   v
CLASE 4  Lifecycle + Configuration + Resources
   v
CLASE 5  Networking + Ingress + NetworkPolicy
   v
CLASE 6  Troubleshooting + Integración final
```

## 7. Organización de carpetas

```
CKA-HANDS-ON-TRAINING/
├── README.md                     <- este archivo
├── MEJORAS-OPCIONALES.md         <- contenidos fuera de las 18 h
└── CLASE-0X/
    ├── 00-README.md              <- agenda y guía de la clase
    ├── 01-CLASE-0X-CKA.pptx      <- presentación del instructor
    ├── LABORATORIOS/             <- MATERIAL DEL ALUMNO
    │   ├── LAB-01-BASICO.md
    │   ├── LAB-02-INTERMEDIO.md
    │   ├── LAB-03-AVANZADO.md
    │   └── LAB-04-CHALLENGE.md
    ├── SOLUCIONES/               <- MATERIAL DEL INSTRUCTOR
    └── RECURSOS/
        ├── YAML/
        └── SCRIPTS/
```

La Clase 6 añade además `02-CHECKLIST-CKA.md`, `03-CHEATSHEET-CKA.md` y el `LAB-05-INTEGRADOR-FINAL.md`.

> **Separación alumno / instructor.** Entrega al alumno `00-README.md`, el `.pptx`, `LABORATORIOS/` y `RECURSOS/`. La carpeta `SOLUCIONES/` es material del instructor y **no debe distribuirse antes de resolver el laboratorio**.

## 8. Instrucciones generales para los laboratorios

### Preparación de la sesión (una sola vez por clase)

```bash
cd CLASE-0X/RECURSOS/SCRIPTS
chmod +x *.sh
./setup-lab.sh          # prepara namespaces y estado inicial
```

Al terminar la clase:

```bash
./reset-lab.sh          # elimina todo lo creado por la clase
```

En los laboratorios Challenge:

```bash
./setup-lab.sh          # despliega el escenario YA ROTO
./validate-lab.sh       # comprueba si lo reparaste
```

### Convenciones

* Un **namespace por laboratorio**. Nunca trabajes en `default` salvo indicación expresa.
* Los manifiestos de referencia están en `RECURSOS/YAML/`. Los nombres de recursos, namespaces y puertos coinciden exactamente entre presentación, laboratorio, YAML, script y solución.
* Cada laboratorio termina con una sección **Validación** con comandos objetivos y un **checklist**.

### Preparación de tu shell (haz esto en cada clase y en el examen)

```bash
alias k=kubectl
export do='--dry-run=client -o yaml'
export now='--force --grace-period=0'
source <(kubectl completion bash)
complete -o default -F __start_kubectl k
```

### Niveles de laboratorio

| Nivel | Qué se espera |
|---|---|
| **Básico** | Altamente guiado. Comprender sintaxis y comportamiento. |
| **Intermedio** | Se combinan varios conceptos. El alumno decide parte de la solución. |
| **Avanzado** | Solo requerimientos. El alumno decide recursos, comandos, orden y validación. |
| **Challenge** | El escenario arranca **roto**. IDENTIFICAR → DIAGNOSTICAR → CORREGIR → VALIDAR. |

## 9. Método de trabajo en clase

```
EXPLICAR -> DEMOSTRAR -> PRACTICAR -> ROMPER -> DIAGNOSTICAR -> CORREGIR -> VALIDAR
```

Romper deliberadamente lo que acaba de funcionar es parte del método, no un accidente. El 30 % del examen CKA es troubleshooting.

## 10. Documentación permitida

Durante el examen solo se permite `kubernetes.io/docs`, `kubernetes.io/blog` y la documentación de los subproyectos oficiales. Practica desde el primer día usando únicamente esas fuentes y `kubectl explain`.
