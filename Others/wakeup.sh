#!/bin/bash
# ==========================================
# K8S NODE REBOOT RECOVERY SCRIPT
# Run this on ALL laptops after power-on
# ==========================================

echo ">>> [1/3] Disabling Swap (Kubernetes Requirement)..."
sudo swapoff -a
# This line prevents swap from turning back on after the next reboot
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

echo ">>> [2/3] Ensuring Container Runtime & Kubelet are running..."
sudo systemctl daemon-reload
sudo systemctl enable --now containerd
sudo systemctl restart kubelet

echo ">>> [3/3] Verifying Node Readiness..."
sleep 5
if systemctl is-active --quiet kubelet; then
    echo "✅ Kubelet is running."
else
    echo "❌ Kubelet failed to start. Run 'journalctl -xeu kubelet' to see why."
fi

# Only run this check on the Control Plane (Prakhar)
if [ -f "/etc/kubernetes/admin.conf" ]; then
    echo ">>> [CONTROL PLANE] Waiting for API Server to wake up..."
    until kubectl get nodes &> /dev/null; do
        printf "."
        sleep 2
    done
    echo -e "\n✅ Cluster is reachable. Current Node Status:"
    kubectl get nodes
fi