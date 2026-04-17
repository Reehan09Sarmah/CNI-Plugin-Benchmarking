#!/bin/bash
set -euo pipefail

# Usage:
#   bash delete_calico.sh
#   CALICO_VERSION=v3.30.3 bash delete_calico.sh

CALICO_VERSION="${CALICO_VERSION:-v3.30.3}"

echo ">>> Using Calico manifest version: ${CALICO_VERSION}"

echo ">>> [1/4] Deleting Calico Installation (This might take a minute)..."
kubectl delete installation default --wait=false 2>/dev/null || true

# Sometimes the deletion gets stuck. This forces it to clear:
kubectl patch installation default -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true

echo ">>> [2/4] Deleting Tigera Operator..."
kubectl delete -f "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/tigera-operator.yaml" 2>/dev/null || true

echo ">>> [3/4] Wiping Custom Resource Definitions (CRDs)..."
kubectl delete crds --all -l app.kubernetes.io/name=tigera-operator 2>/dev/null || true

echo ">>> [4/4] Cleaning local network interfaces (Master node)..."
sudo rm -rf /etc/cni/net.d/*
sudo ip link delete vxlan.calico 2>/dev/null || true
sudo ip link delete cilium_vxlan 2>/dev/null || true
sudo ip link delete flannel.1 2>/dev/null || true
sudo ip link delete cni0 2>/dev/null || true

echo "============================================="
echo "CALICO COMPLETELY REMOVED."
echo " Note: Run 'sudo rm -rf /etc/cni/net.d/*' on Prakhar and Reehan too!"
echo "============================================="