#!/bin/bash
set -euo pipefail

# Semi-automated cluster setup runner.
# Runs deterministic steps automatically and keeps manual checkpoints where race
# conditions are likely (worker reset/join and multi-node CNI cleanup).
#
# Usage examples:
#   bash Setup/semi_automation_setup.sh
#   POD_CIDR=10.244.0.0/16 CNI_PLUGIN=calico CALICO_MODE=bgp bash Setup/semi_automation_setup.sh
#   CNI_PLUGIN=flannel bash Setup/semi_automation_setup.sh

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

POD_CIDR="${POD_CIDR:-10.244.0.0/16}"
CNI_PLUGIN="${CNI_PLUGIN:-calico}"      # calico|cilium|flannel|none
CALICO_MODE="${CALICO_MODE:-bgp}"        # bgp|vxlan
CALICO_VERSION="${CALICO_VERSION:-v3.30.3}"
EXPECTED_NODES="${EXPECTED_NODES:-3}"
NODE_READY_TIMEOUT="${NODE_READY_TIMEOUT:-300}"  # seconds

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1"
    exit 1
  }
}

confirm() {
  local prompt="$1"
  read -r -p "$prompt [y/N]: " ans
  [[ "$ans" == "y" || "$ans" == "Y" ]]
}

wait_nodes_ready() {
  local end=$((SECONDS + NODE_READY_TIMEOUT))
  while (( SECONDS < end )); do
    local ready
    ready="$(kubectl get nodes --no-headers 2>/dev/null | awk '$2=="Ready"{c++} END{print c+0}')"
    if [[ "$ready" -ge "$EXPECTED_NODES" ]]; then
      echo "All expected nodes are Ready (${ready}/${EXPECTED_NODES})."
      return 0
    fi
    echo "Waiting for nodes to become Ready (${ready}/${EXPECTED_NODES})..."
    sleep 5
  done
  echo "Timeout waiting for nodes to become Ready."
  kubectl get nodes || true
  return 1
}

require_cmd sudo
require_cmd kubeadm
require_cmd kubectl

if [[ "$CNI_PLUGIN" != "calico" && "$CNI_PLUGIN" != "cilium" && "$CNI_PLUGIN" != "flannel" && "$CNI_PLUGIN" != "none" ]]; then
  echo "Unsupported CNI_PLUGIN='$CNI_PLUGIN'. Use calico|cilium|flannel|none."
  exit 1
fi

if [[ "$CALICO_MODE" != "bgp" && "$CALICO_MODE" != "vxlan" ]]; then
  echo "Unsupported CALICO_MODE='$CALICO_MODE'. Use bgp|vxlan."
  exit 1
fi

echo "============================================="
echo "Semi-automation setup starting"
echo "POD_CIDR=${POD_CIDR}"
echo "CNI_PLUGIN=${CNI_PLUGIN}"
echo "CALICO_MODE=${CALICO_MODE}"
echo "CALICO_VERSION=${CALICO_VERSION}"
echo "============================================="

echo "Manual gate: ensure all nodes were reset and cleaned first."
echo "Recommended command on each node: bash Setup/node_reset.sh"
confirm "Continue now?" || exit 1

if [[ ! -f /etc/kubernetes/admin.conf ]]; then
  echo ">>> [1/6] Initializing control plane..."
  sudo kubeadm init --pod-network-cidr="$POD_CIDR"
else
  echo ">>> [1/6] Control plane already initialized, skipping kubeadm init."
fi

echo ">>> [2/6] Configuring kubeconfig for current user..."
mkdir -p "$HOME/.kube"
sudo cp -f /etc/kubernetes/admin.conf "$HOME/.kube/config"
sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"

echo ">>> [3/6] Creating worker join command..."
JOIN_CMD="$(kubeadm token create --print-join-command)"
echo "Run this on each worker (with sudo):"
echo "$JOIN_CMD"
confirm "Press y after all workers have joined" || exit 1

echo ">>> [4/6] Waiting for node readiness..."
wait_nodes_ready

echo ">>> [5/6] Installing selected CNI (${CNI_PLUGIN})..."
case "$CNI_PLUGIN" in
  calico)
    if [[ "$CALICO_MODE" == "bgp" ]]; then
      CALICO_ENCAP="None"
    else
      CALICO_ENCAP="VXLANCrossSubnet"
    fi
    CALICO_VERSION="$CALICO_VERSION" CALICO_CIDR="$POD_CIDR" CALICO_ENCAP="$CALICO_ENCAP" \
      bash "$ROOT_DIR/install-CNI-Plugins/install_calico.sh"
    ;;
  cilium)
    bash "$ROOT_DIR/install-CNI-Plugins/install_cilium.sh"
    ;;
  flannel)
    bash "$ROOT_DIR/install-CNI-Plugins/install_flannel.sh"
    ;;
  none)
    echo "Skipping CNI install by request."
    ;;
esac

echo ">>> [6/6] Post-checks..."
kubectl get nodes
kubectl get pods -A

if [[ -x "$ROOT_DIR/cni_safety_check.sh" ]]; then
  echo "Running local CNI safety check on this node..."
  bash "$ROOT_DIR/cni_safety_check.sh" || true
  echo "Run the same command on each worker to ensure no mixed CNI leftovers."
fi

if [[ "$CNI_PLUGIN" == "calico" && -x "$ROOT_DIR/calico_verify_mode.sh" ]]; then
  bash "$ROOT_DIR/calico_verify_mode.sh" "$CALICO_MODE" || true
fi

echo "============================================="
echo "Setup flow completed."
echo "If any post-check failed, fix it before benchmark runs."
echo "============================================="
