# SOLUCIÓN — LAB 15.1 · Desplegar GRATITUD de extremo a extremo

> **MATERIAL DEL INSTRUCTOR.**

## Diagnóstico

El integrador no se valida por capas sueltas sino de **extremo a extremo**: una
petición HTTPS externa tiene que llegar a la caché y volver, con el certificado
propio, sin que ninguna NetworkPolicy la corte y con todos los Pods `Ready`.

## Procedimiento de referencia

```bash
# A - preparación
k create ns gratitud
k label ns gratitud pod-security.kubernetes.io/enforce=restricted pod-security.kubernetes.io/warn=restricted

CN=gratitud.example.com NAME=gratitud-tls NS=gratitud \
  ../../CLASE-10/RECURSOS/SCRIPTS/gen-tls-secret.sh     # o con openssl a mano

# (si no hay provisioner) PV estático:
cat <<'EOF' | k apply -f -
apiVersion: v1
kind: PersistentVolume
metadata: {name: gratitud-pv-uploads}
spec:
  storageClassName: manual
  capacity: {storage: 1Gi}
  accessModes: [ReadWriteOnce]
  persistentVolumeReclaimPolicy: Retain
  hostPath: {path: /mnt/gratitud-uploads, type: DirectoryOrCreate}
EOF

# B - verificar el chart
helm lint ../RECURSOS/CHART/gratitud
helm template gratitud ../RECURSOS/CHART/gratitud -n gratitud \
  -f ../RECURSOS/CHART/gratitud/values-examen.yaml | grep -c 'kind:'   # ~20

# C - instalar
helm install gratitud ../RECURSOS/CHART/gratitud -n gratitud \
  -f ../RECURSOS/CHART/gratitud/values-examen.yaml --wait --timeout 3m

# D - ajustar con helm upgrade (NO kubectl a mano)
#   - ingress.className: el de tu controlador  (k get ingressclass)
#   - persistence.storageClassName: "manual" o el de tu provisioner
helm upgrade gratitud ../RECURSOS/CHART/gratitud -n gratitud \
  -f ../RECURSOS/CHART/gratitud/values-examen.yaml \
  --set ingress.className=traefik --set persistence.storageClassName=manual

cd ../SCRIPTS && ./validar-gratitud.sh
```

## Estructura del chart (resumen)

| Fichero | Capa | Objetos |
|---|---|---|
| `workloads.yaml` | S9, S12 | 3 Deployments (`range .Values.tiers`) + 3 Services + `db-externa` ExternalName |
| `config.yaml` | S11 | ConfigMap `gratitud-config` + Secrets `gratitud-db`, `gratitud-tokens` |
| `pvc.yaml` | S11 | PVC `gratitud-uploads` |
| `ingress.yaml` | S10 | Ingress `gratitud` con `tls` (toggle) |
| `rbac.yaml` | S13 | SA + Role (sin `secrets`) + RoleBinding |
| `networkpolicy.yaml` | S13 | `default-deny`, `allow-dns`, cadenas `ingress→portal→api→cache` |
| `_helpers.tpl` | S12, S13 | contenedor común: 3 sondas, `resources`, `securityContext` restricted, `emptyDir` |

## Comprobación de extremo a extremo

```bash
IP=$(k get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
NP=$(k -n <ns-ingress> get svc <traefik> -o jsonpath='{.spec.ports[?(@.name=="websecure")].nodePort}')
curl -sk -o /dev/null -w '%{http_code}\n' --resolve gratitud.example.com:$NP:$IP https://gratitud.example.com:$NP/api   # 200
curl -skv --resolve gratitud.example.com:$NP:$IP https://gratitud.example.com:$NP/ 2>&1 | grep -E 'subject:|issuer:'    # CN=gratitud.example.com
```

## Error frecuente

* Etiquetar `enforce=restricted` **después** de instalar y que el `helm upgrade` siguiente no pueda recrear Pods si el `securityContext` no cumple: el chart ya cumple, pero comprueba el orden.
* `ingress.className` distinto del `IngressClass` real → Ingress sin `ADDRESS`.
* `persistence.storageClassName: ""` sin StorageClass por defecto y sin PV estático → PVC `Pending`.
* Retocar recursos con `kubectl` en vez de `values` + `helm upgrade`: el siguiente `upgrade` los pisa.
* Olvidar `metrics-server` → la capa 4 falla en `kubectl top`.

## CKA Tip

```bash
helm template <rel> <chart> -n <ns> -f v.yaml | kubectl apply --dry-run=server -f -
helm upgrade --install <rel> <chart> -n <ns> -f v.yaml --set k=v --wait
kubectl -n <ns> get all,ingress,pvc,networkpolicy,sa,role,rolebinding
```
