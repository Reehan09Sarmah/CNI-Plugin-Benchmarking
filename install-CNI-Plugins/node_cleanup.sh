#!/bin/bash
set -euo pipefail

echo ">>> [1/5] Removing stale CNI configs..."
sudo rm -rf /etc/cni/net.d/*
sudo rm -rf /var/lib/cni/
sudo rm -rf /var/lib/calico/ 2>/dev/null || true
sudo rm -rf /var/run/calico/ 2>/dev/null || true

echo ">>> [2/5] Deleting virtual network interfaces..."
sudo ip link delete cni0         2>/dev/null || true
sudo ip link delete flannel.1    2>/dev/null || true
sudo ip link delete vxlan.calico 2>/dev/null || true
sudo ip link delete cilium_host  2>/dev/null || true
sudo ip link delete cilium_net   2>/dev/null || true
sudo ip link delete cilium_vxlan 2>/dev/null || true

echo ">>> [3/5] Flushing stale Cilium routes..."
sudo ip route flush proto 80 2>/dev/null || true

echo ">>> [4/5] Ensuring br_netfilter is loaded..."
sudo modprobe br_netfilter
echo "br_netfilter" | sudo tee /etc/modules-load.d/br_netfilter.conf > /dev/null
sudo sysctl -w net.bridge.bridge-nf-call-iptables=1
sudo sysctl -w net.ipv4.ip_forward=1

echo ">>> [5/5] Restarting kubelet..."
sudo systemctl restart kubelet

echo ""
echo ">>> Verification:"
sudo ls /etc/cni/net.d/ 2>/dev/null || echo "    CNI dir empty — good"
echo "    br_netfilter: $(lsmod | grep -c br_netfilter) module(s) loaded"
echo "    ip_forward: $(cat /proc/sys/net/ipv4/ip_forward)"
echo ">>> Node cleanup complete!"