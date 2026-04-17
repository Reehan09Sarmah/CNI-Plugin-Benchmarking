#!/bin/bash
set -euo pipefail
# ==========================================
# BULLETPROOF CALICO INSTALLATION
# Designed for a freshly initialized Control Plane
# ==========================================

echo ">>> [1/4] Scrubbing local CNI residue to prevent Init container crashes..."
sudo rm -rf /etc/cni/net.d/*
sudo rm -rf /var/lib/cni/
sudo rm -rf /var/lib/calico
sudo rm -rf /var/run/calico
sudo ip link delete vxlan.calico 2>/dev/null || true
sudo ip link delete cali 2>/dev/null || true

# Flush IP tables so Felix daemon doesn't panic
sudo iptables -F
sudo iptables -t nat -F
sudo iptables -t mangle -F
sudo iptables -X

echo ">>> [2/4] Removing Control Plane taints to allow workload scheduling..."
kubectl taint nodes --all node-role.kubernetes.io/control-plane- 2>/dev/null || true

echo ">>> [3/4] Installing Tigera Operator (Server-Side to bypass size limits)..."
kubectl apply --server-side --force-conflicts -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/tigera-operator.yaml

echo ">>> Waiting for Operator to be fully ready..."
kubectl -n tigera-operator rollout status deploy/tigera-operator --timeout=180s

echo ">>> [4/4] Injecting Default Calico Configuration (10.244.0.0/16)..."
cat <<EOF | kubectl apply -f -
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  calicoNetwork:
    ipPools:
    - blockSize: 26
      cidr: 10.244.0.0/16
      encapsulation: VXLANCrossSubnet
      natOutgoing: Enabled
      nodeSelector: all()
EOF

echo "============================================="
echo " 🚀 CALICO INSTALLATION TRIGGERED SUCCESSFULLY"
echo " IMPORTANT: Ensure your worker nodes run the same local CNI cleanup"
echo " (rm -rf /etc/cni/net.d/* and iptables -F) before joining the cluster!"
echo "============================================="
echo "Monitoring pod startup..."
watch kubectl get pods -n calico-system