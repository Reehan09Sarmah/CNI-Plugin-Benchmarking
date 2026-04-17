#!/bin/bash
# Run on Prakhar-PC.
echo ">>> Installing Flannel CNI..."
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

echo ">>> Waiting for Flannel to spin up..."
kubectl rollout status daemonset kube-flannel-ds -n kube-flannel --timeout=90s
echo ">>> Flannel is active!"