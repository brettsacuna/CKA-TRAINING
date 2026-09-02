#!/usr/bin/env bash
# SESION 11 - Prepara el escenario del LAB 11.4 (Challenge de config + storage) YA ROTO.
#
# 4 fallos:
#   1. api: env.valueFrom.secretKeyRef.key = DB_PASS   (la clave real es DB_PASSWORD)  -> CreateContainerConfigError
#   2. api: envFrom.configMapRef.name = gratitud-cfg    (el ConfigMap es gratitud-config) -> CreateContainerConfigError
#   3. api: volumeMounts.subPath = app.cnf              (items.path es app.conf)          -> /etc/gratitud/app.conf ausente
#   4. pvc: storageClassName = gratitud-manual          (el PV es storageClassName manual) -> PVC Pending
set -euo pipefail

kubectl create namespace gratitud-api   --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace gratitud-datos --dry-run=client -o yaml | kubectl apply -f -
kubectl label ns gratitud-api   part-of=gratitud tier=api   --overwrite >/dev/null
kubectl label ns gratitud-datos part-of=gratitud tier=datos --overwrite >/dev/null

cat <<'YAML' | kubectl apply -f -
# ---------- config CORRECTA ----------
apiVersion: v1
kind: ConfigMap
metadata: {name: gratitud-config, namespace: gratitud-api}
data:
  LOG_LEVEL: info
  FEATURE_GRATITUD_V2: "true"
  UPSTREAM_CACHE: http://cache.gratitud-datos
  app.conf: |
    [gratitud]
    log_level = info
    workers = 4
    upstream_cache = http://cache.gratitud-datos
---
apiVersion: v1
kind: Secret
metadata: {name: gratitud-db, namespace: gratitud-api}
type: Opaque
stringData: {DB_USER: gratitud, DB_PASSWORD: r3f-c4mbi4-esto, DB_HOST: db.corp.example.com}
---
apiVersion: v1
kind: Secret
metadata: {name: gratitud-api-tokens, namespace: gratitud-api}
type: Opaque
stringData: {PARTNER_TOKEN: pt_live_9f2c1a7b4e, WEBHOOK_SIGNING_KEY: whsk_3d8e0f5a19}
---
# ---------- api CON 3 DEFECTOS ----------
apiVersion: apps/v1
kind: Deployment
metadata: {name: api, namespace: gratitud-api, labels: {app: gratitud-api, part-of: gratitud}}
spec:
  replicas: 1
  selector: {matchLabels: {app: gratitud-api}}
  template:
    metadata: {labels: {app: gratitud-api, part-of: gratitud}}
    spec:
      containers:
        - name: api
          image: nginxinc/nginx-unprivileged:1.27-alpine
          ports: [{containerPort: 8080}]
          envFrom:
            - configMapRef: {name: gratitud-cfg}          # FALLO 2: es 'gratitud-config'
            - secretRef: {name: gratitud-db}
          env:
            - name: DB_PASSWORD
              valueFrom:
                secretKeyRef: {name: gratitud-db, key: DB_PASS}   # FALLO 1: la clave es 'DB_PASSWORD'
          volumeMounts:
            - {name: cfg, mountPath: /etc/gratitud/app.conf, subPath: app.cnf}   # FALLO 3: es 'app.conf'
      volumes:
        - name: cfg
          configMap:
            name: gratitud-config
            items: [{key: app.conf, path: app.conf}]
---
# ---------- storage ----------
apiVersion: v1
kind: PersistentVolume
metadata: {name: gratitud-pv-uploads, labels: {app: gratitud, uso: uploads}}
spec:
  storageClassName: manual
  capacity: {storage: 1Gi}
  accessModes: ["ReadWriteOnce"]
  persistentVolumeReclaimPolicy: Retain
  hostPath: {path: /mnt/gratitud-uploads, type: DirectoryOrCreate}
---
# FALLO 4: storageClassName no coincide con el del PV ('manual')
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: gratitud-uploads, namespace: gratitud-datos}
spec:
  storageClassName: gratitud-manual
  accessModes: ["ReadWriteOnce"]
  resources: {requests: {storage: 1Gi}}
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: datos, namespace: gratitud-datos, labels: {app: gratitud-datos, part-of: gratitud}}
spec:
  replicas: 1
  selector: {matchLabels: {app: gratitud-datos}}
  template:
    metadata: {labels: {app: gratitud-datos, part-of: gratitud}}
    spec:
      containers:
        - name: nginx
          image: nginx:1.27-alpine
          volumeMounts: [{name: data, mountPath: /data/uploads}]
      volumes:
        - name: data
          persistentVolumeClaim: {claimName: gratitud-uploads}
YAML

echo
echo "==============================================================="
echo " LAB 11.4 listo. GRATITUD esta ROTO a proposito."
echo " Sintomas: Pod api en CreateContainerConfigError; PVC gratitud-uploads Pending."
echo " Hay 4 fallos: secretKeyRef.key, configMapRef.name, subPath, storageClassName."
echo " NO uses optional:true. NO borres el PVC ni los Secrets/ConfigMap."
echo "==============================================================="
