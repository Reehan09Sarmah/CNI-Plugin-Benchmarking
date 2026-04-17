#!/bin/bash
# Run this on Prakhar-PC to switch Cilium from VXLAN to Native Routing

echo ">>> [1/3] Reconfiguring Cilium for Native Routing (No VXLAN)..."

# Apply the configuration changes via Helm/CLI
cilium upgrade \
  --set routingMode=native \
  --set autoDirectNodeRoutes=true \
  --set ipv4NativeRoutingCIDR=10.244.0.0/16

echo ">>> [2/3] Restarting Cilium pods to apply changes..."
# Force a rollout restart to ensure the new config is loaded into the eBPF maps
kubectl rollout restart ds cilium -n kube-system
kubectl rollout status ds cilium -n kube-system --timeout=120s

echo ">>> [3/3] Verifying Native Routing Status..."
echo "-------------------------------------------------------------"

# Check the ConfigMap directly for the source of truth
CONFIG_MODE=$(kubectl get cm cilium-config -n kube-system -o jsonpath='{.data.routing-mode}')
TUNNEL_MODE=$(kubectl get cm cilium-config -n kube-system -o jsonpath='{.data.tunnel-protocol}')

echo "Configured Routing Mode: $CONFIG_MODE"
echo "Tunnel Protocol (should be 'none' or empty): $TUNNEL_MODE"

if [ "$CONFIG_MODE" == "native" ]; then
    echo "============================================="
    echo " ✅ SUCCESS: CILIUM NATIVE ROUTING ENABLED"
    echo "============================================="
else
    echo "============================================="
    echo " ❌ FAILED: Still in Tunnel/VXLAN mode."
    echo " Try running: kubectl -n kube-system get cm cilium-config -o yaml"
    echo "============================================="
fi