#!/usr/bin/env bash
set -euo pipefail

NS="kube-system"
SA="calico-kube-controllers"
ROLE="calico-kube-controllers-hostendpoints"
BIND="calico-kube-controllers-hostendpoints"

echo "[1/4] Checking current permission..."
kubectl auth can-i watch hostendpoints.crd.projectcalico.org \
  --as="system:serviceaccount:${NS}:${SA}" || true

echo "[2/4] Applying RBAC (ClusterRole + ClusterRoleBinding)..."
cat <<YAML | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: ${ROLE}
rules:
- apiGroups: ["crd.projectcalico.org"]
  resources: ["hostendpoints"]
  verbs: ["get","list","watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: ${BIND}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: ${ROLE}
subjects:
- kind: ServiceAccount
  name: ${SA}
  namespace: ${NS}
YAML

echo "[3/4] Re-checking permission..."
kubectl auth can-i watch hostendpoints.crd.projectcalico.org \
  --as="system:serviceaccount:${NS}:${SA}"

echo "[4/4] Restarting calico-kube-controllers..."
kubectl -n "${NS}" rollout restart deployment "${SA}"
kubectl -n "${NS}" rollout status deployment "${SA}" --timeout=120s

echo "OK: RBAC fixed and controllers restarted."

