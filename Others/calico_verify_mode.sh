#!/bin/bash
set -euo pipefail

# Usage:
#   bash calico_verify_mode.sh bgp
#   bash calico_verify_mode.sh vxlan

MODE="${1:-}"
if [[ "$MODE" != "bgp" && "$MODE" != "vxlan" ]]; then
  echo "Usage: bash calico_verify_mode.sh [bgp|vxlan]"
  exit 1
fi

encap="$(kubectl get installation default -o jsonpath='{.spec.calicoNetwork.ipPools[0].encapsulation}')"
vxlan_mode="$(kubectl get ippool default-ipv4-ippool -o jsonpath='{.spec.vxlanMode}')"
ipip_mode="$(kubectl get ippool default-ipv4-ippool -o jsonpath='{.spec.ipipMode}')"

echo "Current Installation.encapsulation: ${encap}"
echo "Current IPPool vxlan/ipip modes: ${vxlan_mode}/${ipip_mode}"

if [[ "$MODE" == "bgp" ]]; then
  [[ "$encap" == "None" ]] || { echo "FAIL: expected encapsulation None"; exit 2; }
  [[ "$vxlan_mode" == "Never" ]] || { echo "FAIL: expected vxlanMode Never"; exit 2; }
  [[ "$ipip_mode" == "Never" ]] || { echo "FAIL: expected ipipMode Never"; exit 2; }
else
  [[ "$encap" == "VXLANCrossSubnet" ]] || { echo "FAIL: expected encapsulation VXLANCrossSubnet"; exit 2; }
  [[ "$vxlan_mode" == "CrossSubnet" || "$vxlan_mode" == "Always" ]] || { echo "FAIL: expected vxlanMode CrossSubnet/Always"; exit 2; }
  [[ "$ipip_mode" == "Never" ]] || { echo "FAIL: expected ipipMode Never for VXLAN profile"; exit 2; }
fi

not_ready="$(kubectl get pods -n calico-system --no-headers | awk '$2 !~ /^([0-9]+)\/\1$/ || $3 != "Running" {print $1}')"
if [[ -n "$not_ready" ]]; then
  echo "FAIL: Some calico-system pods are not healthy:"
  echo "$not_ready"
  exit 3
fi

echo "PASS: Calico mode and pod health look correct for '${MODE}'."
