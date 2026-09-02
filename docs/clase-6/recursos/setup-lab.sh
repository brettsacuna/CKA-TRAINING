#!/usr/bin/env bash
# CLASE 6 - Prepara los escenarios de los laboratorios.
# Uso: ./setup-lab.sh [basico|nodo|cadena|sprint]
set -euo pipefail
MODE=${1:-basico}

case "$MODE" in

basico)
  kubectl create namespace c6-estados --dry-run=client -o yaml | kubectl apply -f -
  kubectl -n c6-estados create configmap caso3-cfg --from-literal=OK=1 \
    --dry-run=client -o yaml | kubectl apply -f -
  cat <<'YAML' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata: {name: caso-1, namespace: c6-estados}
spec:
  nodeSelector: {hardware: fpga}
  containers: [{name: c, image: "nginx:1.27-alpine"}]
---
apiVersion: v1
kind: Pod
metadata: {name: caso-2, namespace: c6-estados}
spec:
  containers: [{name: c, image: "nginx:version-que-no-existe"}]
---
apiVersion: v1
kind: Pod
metadata: {name: caso-3, namespace: c6-estados}
spec:
  containers:
    - name: c
      image: nginx:1.27-alpine
      envFrom: [{configMapRef: {name: caso3-cfg-inexistente}}]
---
apiVersion: v1
kind: Pod
metadata: {name: caso-4, namespace: c6-estados}
spec:
  containers:
    - name: c
      image: busybox:1.36
      command: ["sh","-c","echo 'fallo de arranque: falta /etc/app.conf' >&2; exit 1"]
---
apiVersion: v1
kind: Pod
metadata: {name: caso-5, namespace: c6-estados}
spec:
  containers:
    - name: c
      image: nginx:1.27-alpine
      readinessProbe:
        httpGet: {path: /, port: 8081}
        periodSeconds: 5
---
apiVersion: v1
kind: Pod
metadata: {name: caso-6, namespace: c6-estados}
spec:
  containers:
    - name: c
      image: polinux/stress
      command: ["stress"]
      args: ["--vm","1","--vm-bytes","250M","--vm-hang","1"]
      resources:
        requests: {memory: "32Mi"}
        limits:   {memory: "64Mi"}
YAML
  echo "LAB 6.1 listo: 6 Pods rotos en c6-estados, 6 causas distintas."
  ;;

nodo)
  NODE=$(kubectl get nodes --no-headers -o custom-columns=N:.metadata.name \
        | grep -v master | head -1)
  kubectl cordon "$NODE"
  kubectl label node "$NODE" incidente=a --overwrite >/dev/null
  echo "LAB 6.2 (incidente A) listo sobre el nodo: $NODE"
  echo "El incidente B lo provoca el instructor en /etc/kubernetes/manifests/."
  ;;

cadena)
  kubectl create namespace c6-pedidos --dry-run=client -o yaml | kubectl apply -f -
  cat <<'YAML' | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata: {name: deployer, namespace: c6-pedidos}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata: {name: deployer, namespace: c6-pedidos}
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata: {name: deployer, namespace: c6-pedidos}
roleRef: {apiGroup: rbac.authorization.k8s.io, kind: Role, name: deployer}
subjects:
  - {apiGroup: rbac.authorization.k8s.io, kind: User, name: deployer}
---
apiVersion: v1
kind: ConfigMap
metadata: {name: pedidos-cfg, namespace: c6-pedidos}
data: {APP_ENV: production}
---
apiVersion: v1
kind: Secret
metadata: {name: pedidos-secret, namespace: c6-pedidos}
type: Opaque
stringData: {db-password: P3d1d0s2026}
---
apiVersion: v1
kind: Service
metadata: {name: pedidos, namespace: c6-pedidos}
spec:
  clusterIP: None
  selector: {app: pedidos-v2}
  ports: [{name: http, port: 80}]
---
apiVersion: apps/v1
kind: StatefulSet
metadata: {name: pedidos, namespace: c6-pedidos}
spec:
  serviceName: pedidos-headless
  replicas: 3
  selector: {matchLabels: {app: pedidos}}
  template:
    metadata: {labels: {app: pedidos}}
    spec:
      containers:
        - name: app
          image: nginx:1.27-alpine
          ports: [{containerPort: 80, name: http}]
          envFrom: [{configMapRef: {name: pedidos-config}}]
          env:
            - name: DB_PASSWORD
              valueFrom: {secretKeyRef: {name: pedidos-secret, key: password}}
          resources: {requests: {cpu: "6"}}
          volumeMounts: [{name: datos, mountPath: /data}]
  volumeClaimTemplates:
    - metadata: {name: datos}
      spec:
        storageClassName: inexistente
        accessModes: ["ReadWriteOnce"]
        resources: {requests: {storage: 1Gi}}
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: default-deny, namespace: c6-pedidos}
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: allow-dns, namespace: c6-pedidos}
spec:
  podSelector: {}
  policyTypes: [Egress]
  egress:
    - to: [{namespaceSelector: {matchLabels: {kubernetes.io/metadata.name: kube-system}}}]
      ports: [{protocol: UDP, port: 53}, {protocol: TCP, port: 53}]
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: allow-intra, namespace: c6-pedidos}
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
  ingress: [{from: [{podSelector: {}}]}]
  egress:  [{to:   [{podSelector: {}}]}]
YAML
  echo "LAB 6.3 listo: 6 fallos encadenados en c6-pedidos."
  ;;

sprint)
  kubectl create namespace c6-sprint --dry-run=client -o yaml | kubectl apply -f -
  NODE=$(kubectl get nodes --no-headers -o custom-columns=N:.metadata.name | grep -v master | head -1)
  kubectl cordon "$NODE" >/dev/null
  cat <<'YAML' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata: {name: api, namespace: c6-sprint}
spec:
  replicas: 3
  selector: {matchLabels: {app: api}}
  template:
    metadata: {labels: {app: api}}
    spec:
      containers:
        - name: api
          image: nginx:1.27-alpine
          ports: [{containerPort: 80}]
          resources: {requests: {cpu: "5"}}
---
apiVersion: v1
kind: Service
metadata: {name: api-svc, namespace: c6-sprint}
spec:
  selector: {app: api-backend}
  ports: [{port: 80, targetPort: 80}]
---
apiVersion: v1
kind: Pod
metadata: {name: batch, namespace: c6-sprint}
spec:
  containers:
    - name: batch
      image: busybox:1.36
      command: ["sh","-c","cat /config/job.conf"]
---
apiVersion: v1
kind: ServiceAccount
metadata: {name: viewer, namespace: c6-sprint}
YAML
  echo "LAB 6.4 listo: 5 tareas en c6-sprint. Nodo cordonado: $NODE. Arranca el cronometro."
  ;;

*)
  echo "Uso: $0 [basico|nodo|cadena|sprint]"; exit 1;;
esac
