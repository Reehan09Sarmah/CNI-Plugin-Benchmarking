#!/bin/bash
set -euo pipefail

FORCE="${1:-}"
if [[ "$FORCE" != "--yes" ]]; then
	echo "WARNING: This will remove CNI configs and flush iptables on this node."
	echo "Re-run with: bash wipe_cni.sh --yes"
	exit 1
fi

echo ">>> [1/3] Wiping CNI networking rules and folders and iptables..."
sudo rm -rf /etc/cni/net.d/*
sudo rm -rf /var/lib/cni/
sudo rm -rf /var/lib/calico/
sudo rm -rf /var/run/calico/
sudo ip link delete flannel.1 2>/dev/null || true
sudo ip link delete vxlan.calico 2>/dev/null || true
sudo ip link delete cilium_vxlan 2>/dev/null || true
sudo ip link delete cni0 2>/dev/null || true
sudo ip route flush proto 80
sudo iptables -F
sudo iptables -t nat -F
sudo iptables -t mangle -F
sudo iptables -X
sudo systemctl restart kubelet

echo ">>> Node is completely clean and ready for a fresh CNI."