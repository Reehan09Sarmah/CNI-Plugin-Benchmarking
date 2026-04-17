#!/bin/bash
set -euo pipefail

# Run on control node
echo ">>> [1/2] Installing Tigera Operator..."
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/tigera-operator.yaml

echo ">>> Waiting for Tigera Operator to be ready..."
kubectl -n tigera-operator rollout status deploy/tigera-operator --timeout=180s

echo ">>> [2/2] Injecting Custom Resources (Forced to 10.244.0.0/16)..."
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

echo ">>> Calico Operator is building the network. Check status with: watch kubectl get pods -n calico-system"