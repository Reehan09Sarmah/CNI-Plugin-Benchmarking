#!/bin/bash
set -euo pipefail

echo ">>> [1/4] Downloading Cilium CLI..."
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
curl -L --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-amd64.tar.gz
sudo tar xzvfC cilium-linux-amd64.tar.gz /usr/local/bin
rm -f cilium-linux-amd64.tar.gz

echo ">>> [2/4] Installing Cilium v1.15.0..."
cilium install --version 1.15.0

echo ">>> [3/4] Waiting for Cilium to be ready..."
cilium status --wait

echo ">>> [4/4] Verifying..."
kubectl get pods -n kube-system | grep cilium
kubectl get nodes

echo ""
echo "============================================="
echo " CILIUM INSTALLED SUCCESSFULLY"
echo " Default mode: VXLAN overlay"
echo " Next: update config.env and run deploy_pods.sh"
echo "============================================="