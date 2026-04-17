#!/bin/bash
echo ">>> [1/3] Wiping CNI networking rules and folders and iptables..."
sudo rm -rf /etc/cni/net.d/*
sudo rm -rf /var/lib/cni/
sudo ip link delete flannel.1 2>/dev/null || true
sudo ip link delete cni0 2>/dev/null || true
sudo ip route flush proto 80
sudo iptables -F
sudo iptables -t nat -F
sudo iptables -t mangle -F
sudo iptables -X
sudo systemctl restart kubelet

echo ">>> Node is completely clean and ready for a fresh CNI."