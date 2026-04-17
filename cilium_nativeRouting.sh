#!/bin/bash
# Run this on Prakhar-PC to switch Cilium from VXLAN to Native Routing

echo ">>> [1/3] Reconfiguring Cilium for Native Routing (Disabling VXLAN)..."

# Added --set tunnel=disabled to ensure the vxlan interface is removed
cilium upgrade \
  --set routingMode=native \
  --set tunnel=disabled \
  --set autoDirectNodeRoutes=true \
  --set ipv4NativeRoutingCIDR=10.244.0.0/16

echo ">>> [2/3] Restarting Cilium pods to apply changes..."
kubectl rollout restart ds cilium -n kube-system
kubectl rollout status ds cilium -n kube-system --timeout=120s

echo ">>> [3/3] Verifying Native Routing Status..."
echo "-------------------------------------------------------------"

CONFIG_MODE=$(kubectl get cm cilium-config -n kube-system -o jsonpath='{.data.routing-mode}')
TUNNEL_MODE=$(kubectl get cm cilium-config -n kube-system -o jsonpath='{.data.tunnel}')

echo "Configured Routing Mode: $CONFIG_MODE"
echo "Tunnel Mode (should be 'disabled'): $TUNNEL_MODE"

if [ "$CONFIG_MODE" == "native" ] && [ "$TUNNEL_MODE" == "disabled" ]; then
    echo "============================================="
    echo " ✅ SUCCESS: CILIUM NATIVE ROUTING ENABLED"
    echo "============================================="
else
    echo "============================================="
    echo " ⚠️  PARTIAL SUCCESS: Mode is $CONFIG_MODE but tunnel is $TUNNEL_MODE."
    echo " Running one more manual patch to be sure..."
    kubectl patch cm cilium-config -n kube-system --type merge -p '{"data":{"tunnel":"disabled"}}'
    kubectl rollout restart ds cilium -n kube-system
    echo "============================================="
fi