#!/usr/bin/env bash
# CLASE 3 - Prepara el escenario del LAB 3.4 (Challenge de storage) YA ROTO.
set -euo pipefail
NS=c3-challenge

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -

echo ">> Creando PersistentVolumes..."
cat <<'YAML' | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata: {name: pv-reportes-small}
spec:
  capacity: {storage: 500Mi}
  accessModes: ["ReadWriteOnce"]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: slow
  hostPath: {path: /mnt/rep-small, type: DirectoryOrCreate}
---
apiVersion: v1
kind: PersistentVolume
metadata: {name: pv-reportes-ro}
spec:
  capacity: {storage: 5Gi}
  accessModes: ["ReadOnlyMany"]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: slow
  hostPath: {path: /mnt/rep-ro, type: DirectoryOrCreate}
---
apiVersion: v1
kind: PersistentVolume
metadata: {name: pv-reportes-ok}
spec:
  capacity: {storage: 5Gi}
  accessModes: ["ReadWriteOnce"]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: slow
  hostPath: {path: /mnt/rep-ok, type: DirectoryOrCreate}
YAML

echo ">> Dejando pv-reportes-ok en estado Released (claimRef obsoleto)..."
cat <<'YAML' | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: pvc-viejo, namespace: c3-challenge}
spec:
  storageClassName: slow
  accessModes: ["ReadWriteOnce"]
  resources: {requests: {storage: 5Gi}}
  volumeName: pv-reportes-ok
YAML
kubectl -n "$NS" wait --for=jsonpath='{.status.phase}'=Bound pvc/pvc-viejo --timeout=60s || true
kubectl -n "$NS" delete pvc pvc-viejo --wait=true || true

echo ">> Creando el PVC y el Deployment de la aplicacion (con defectos)..."
cat <<'YAML' | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: pvc-reportes, namespace: c3-challenge}
spec:
  storageClassName: manual
  accessModes: ["ReadWriteMany"]
  resources: {requests: {storage: 2Gi}}
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: reportes, namespace: c3-challenge}
spec:
  replicas: 1
  selector: {matchLabels: {app: reportes}}
  template:
    metadata: {labels: {app: reportes}}
    spec:
      volumes:
        - name: datos
          persistentVolumeClaim:
            claimName: pvc-reportes-data
      containers:
        - name: app
          image: nginx:1.27-alpine
          volumeMounts:
            - {name: datos, mountPath: /data}
YAML

echo
echo "==============================================================="
echo " LAB 3.4 listo. El escenario esta ROTO a proposito."
echo " Objetivo: deployment reportes 1/1 Running y su PVC en Bound."
echo " No elimines los PersistentVolumes."
echo "==============================================================="
