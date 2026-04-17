#!/bin/bash
# Run this on ALL NODES (Prakhar, Reehan, Midnight) to completely clean the slate.
echo ">>> [1/4] Factory Resetting Kubernetes..."
sudo kubeadm reset -f

echo ">>> [2/4] Wiping CNI networking rules and folders..."
sudo rm -rf /etc/cni/net.d/*
sudo rm -rf /var/lib/cni/
sudo rm -rf /var/lib/calico
sudo rm -rf /var/run/calico
sudo rm -rf ~/.kube

echo ">>> [3/4] Flushing IP Tables (Crucial for CNI swapping)..."
sudo iptables -F
sudo iptables -t nat -F
sudo iptables -t mangle -F
sudo iptables -X

echo ">>> [4/4] Restarting Container Runtime..."
sudo systemctl restart containerd
sudo systemctl restart kubelet
echo ">>> Node is completely clean and ready to join a new cluster!"