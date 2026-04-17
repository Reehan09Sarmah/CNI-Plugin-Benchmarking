#!/bin/bash
# Run on Prakhar-PC.
echo ">>> [1/2] Downloading Cilium CLI..."
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-amd64.tar.gz
sudo tar xzvfC cilium-linux-amd64.tar.gz /usr/local/bin
rm cilium-linux-amd64.tar.gz

echo ">>> [2/2] Installing Cilium to Cluster..."
# We pass the exact same CIDR so it matches the cluster init
cilium install --set ipv4.podCIDR="10.244.0.0/16"

echo ">>> Checking Cilium Status..."
cilium status --wait
echo ">>> Cilium is active!"