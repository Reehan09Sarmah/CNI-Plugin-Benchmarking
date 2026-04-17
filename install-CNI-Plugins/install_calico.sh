#!/bin/bash
set -euo pipefail

# Usage examples:
#   bash install_calico.sh
#   CALICO_VERSION=v3.30.3 CALICO_ENCAP=None bash install_calico.sh

CALICO_VERSION="${CALICO_VERSION:-v3.30.3}"
CALICO_CIDR="${CALICO_CIDR:-10.244.0.0/16}"
CALICO_BLOCK_SIZE="${CALICO_BLOCK_SIZE:-26}"
CALICO_ENCAP="${CALICO_ENCAP:-VXLANCrossSubnet}" # None or VXLANCrossSubnet
CALICO_NAT_OUTGOING="${CALICO_NAT_OUTGOING:-Enabled}"

if [[ "$CALICO_ENCAP" != "None" && "$CALICO_ENCAP" != "VXLANCrossSubnet" ]]; then
  echo "Unsupported CALICO_ENCAP='$CALICO_ENCAP'. Use None or VXLANCrossSubnet."
  exit 1
fi

echo ">>> [1/4] Installing Tigera Operator ${CALICO_VERSION}..."
kubectl apply --server-side --force-conflicts \
  -f "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/tigera-operator.yaml"

kubectl -n tigera-operator rollout status deploy/tigera-operator --timeout=240s

echo ">>> [2/4] Applying Calico Installation (encapsulation=${CALICO_ENCAP})..."
cat <<EOF | kubectl apply -f -
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  calicoNetwork:
    bgp: Enabled
    ipPools:
    - blockSize: ${CALICO_BLOCK_SIZE}
      cidr: ${CALICO_CIDR}
      encapsulation: ${CALICO_ENCAP}
      natOutgoing: ${CALICO_NAT_OUTGOING}
      nodeSelector: all()
EOF

echo ">>> [3/4] Waiting for calico-node rollout..."
kubectl -n calico-system rollout status ds/calico-node --timeout=300s || true

if [[ "$CALICO_ENCAP" == "None" ]]; then
  echo ">>> [4/4] Enforcing BGP-only dataplane (vxlan/ipip disabled)..."
  # Operator eventually reconciles these fields, but patching removes ambiguity.
  kubectl patch ippool default-ipv4-ippool --type merge -p '{"spec":{"vxlanMode":"Never","ipipMode":"Never","natOutgoing":true}}' || true
  kubectl -n calico-system rollout restart ds/calico-node
  kubectl -n calico-system rollout status ds/calico-node --timeout=300s || true
else
  echo ">>> [4/4] Keeping VXLAN CrossSubnet mode."
fi

echo "============================================="
echo "Calico install complete."
echo "Version: ${CALICO_VERSION}"
echo "Encapsulation: ${CALICO_ENCAP}"
echo "============================================="
kubectl get pods -n calico-system -o wide