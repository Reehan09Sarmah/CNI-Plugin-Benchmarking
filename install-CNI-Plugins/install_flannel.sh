#!/bin/bash
# Run on reehan-pc (master)
echo ">>> Installing Flannel CNI..."
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
echo ">>> Waiting for Flannel to spin up on all nodes..."
kubectl rollout status daemonset kube-flannel-ds -n kube-flannel --timeout=180s
echo ">>> Flannel is active!"
echo ""
echo ">>> Node status:"
kubectl get nodes
echo ""
echo ">>> Flannel pods:"
kubectl get pods -n kube-flannel -o wide