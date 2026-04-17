#!/bin/bash
# Run on Midnight-07 to completely erase a broken Calico install

echo ">>> [1/4] Deleting Calico Installation (This might take a minute)..."
kubectl delete installation default --wait=false

# Sometimes the deletion gets stuck. This forces it to clear:
kubectl patch installation default -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null

echo ">>> [2/4] Deleting Tigera Operator..."
kubectl delete -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/tigera-operator.yaml

echo ">>> [3/4] Wiping Custom Resource Definitions (CRDs)..."
kubectl delete crds --all -l app.kubernetes.io/name=tigera-operator

echo ">>> [4/4] Cleaning local network interfaces (Master node)..."
sudo rm -rf /etc/cni/net.d/*
sudo ip link delete vxlan.calico 2>/dev/null
sudo ip link delete cali 2>/dev/null

echo "============================================="
echo " 🧹 CALICO COMPLETELY REMOVED."
echo " Note: Run 'sudo rm -rf /etc/cni/net.d/*' on Prakhar and Reehan too!"
echo "============================================="