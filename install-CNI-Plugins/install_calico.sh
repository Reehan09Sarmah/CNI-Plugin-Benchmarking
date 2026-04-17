#!/bin/bash
# Run on Prakhar-PC.
echo ">>> [1/2] Installing Tigera Operator..."
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/tigera-operator.yaml
sleep 10

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