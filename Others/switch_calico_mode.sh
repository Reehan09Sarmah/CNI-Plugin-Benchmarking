#!/bin/bash
set -euo pipefail

# Usage:
#   bash switch_calico_mode.sh bgp
#   bash switch_calico_mode.sh vxlan

MODE="${1:-}"
if [[ "$MODE" != "bgp" && "$MODE" != "vxlan" ]]; then
  echo "Usage: bash switch_calico_mode.sh [bgp|vxlan]"
  exit 1
fi

if [[ "$MODE" == "bgp" ]]; then
  ENCAP="None"
  VXLAN_MODE="Never"
  IPIP_MODE="Never"
else
  ENCAP="VXLANCrossSubnet"
  VXLAN_MODE="CrossSubnet"
  IPIP_MODE="Never"
fi

echo ">>> [1/3] Patching Installation to encapsulation=${ENCAP}..."
kubectl patch installation default --type merge -p "{\"spec\":{\"calicoNetwork\":{\"bgp\":\"Enabled\",\"ipPools\":[{\"cidr\":\"10.244.0.0/16\",\"blockSize\":26,\"encapsulation\":\"${ENCAP}\",\"natOutgoing\":\"Enabled\",\"nodeSelector\":\"all()\"}]}}}"

echo ">>> [2/3] Patching IPPool vxlan/ipip modes..."
kubectl patch ippool default-ipv4-ippool --type merge -p "{\"spec\":{\"vxlanMode\":\"${VXLAN_MODE}\",\"ipipMode\":\"${IPIP_MODE}\",\"natOutgoing\":true}}"

echo ">>> [3/3] Restarting calico-node daemonset..."
kubectl -n calico-system rollout restart ds/calico-node
kubectl -n calico-system rollout status ds/calico-node --timeout=300s

echo "============================================="
echo "Calico mode switch complete: ${MODE}"
echo "============================================="
kubectl get ippool default-ipv4-ippool -o jsonpath='{.spec.vxlanMode}{" "}{.spec.ipipMode}{"\n"}'
kubectl get installation default -o jsonpath='{.spec.calicoNetwork.ipPools[0].encapsulation}{"\n"}'
