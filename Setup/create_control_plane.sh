#!/bin/bash
# Run this ONLY on Prakhar-PC (Control Plane).

# We use 10.244.0.0/16 because Flannel requires it, and we will force 
# Calico and Cilium to respect it later.
echo ">>> [1/3] Initializing Kubernetes Control Plane..."
sudo kubeadm init --pod-network-cidr=10.244.0.0/16

echo ">>> [2/3] Setting up kubeconfig for current user..."
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

echo "=================================================================="
echo " CLUSTER CREATED SUCCESSFULLY!"
echo " COPY THE 'kubeadm join' COMMAND BELOW AND RUN IT ON THE WORKERS:"
echo "=================================================================="
kubeadm token create --print-join-command