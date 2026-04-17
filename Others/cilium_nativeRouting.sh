#!/bin/bash
# Run this on Prakhar-PC to switch Cilium from VXLAN to Native Routing (Cilium v1.15+)

echo ">>> [1/3] Reconfiguring Cilium for Native Routing (Disabling VXLAN)..."

# In v1.15+, 'tunnel' is removed. We use 'tunnelProtocol=none' instead.
cilium upgrade \
  --set routingMode=native \
  --set tunnelProtocol=none \
  --set autoDirectNodeRoutes=true \
  --set ipv4NativeRoutingCIDR=10.244.0.0/16

echo ">>> [2/3] Restarting Cilium pods to apply changes..."
kubectl rollout restart ds cilium -n kube-system
kubectl rollout status ds cilium -n kube-system --timeout=120s

echo ">>> [3/3] Verifying Native Routing Status..."
echo "-------------------------------------------------------------"

# Check the modern keys in the ConfigMap
CONFIG_MODE=$(kubectl get cm cilium-config -n kube-system -o jsonpath='{.data.routing-mode}')
PROTOCOL_MODE=$(kubectl get cm cilium-config -n kube-system -o jsonpath='{.data.tunnel-protocol}')

# Handle empty values for display
[ -z "$PROTOCOL_MODE" ] && PROTOCOL_MODE="none/disabled"

echo "Configured Routing Mode: $CONFIG_MODE"
echo "Tunnel Protocol: $PROTOCOL_MODE"

if [ "$CONFIG_MODE" == "native" ]; then
    echo "============================================="
    echo " ✅ SUCCESS: CILIUM NATIVE ROUTING ENABLED"
    echo "============================================="
else
    echo "============================================="
    echo " ⚠️  PARTIAL SUCCESS: Mode is $CONFIG_MODE."
    echo " Attempting manual fix for tunnel protocol..."
    kubectl patch cm cilium-config -n kube-system --type merge -p '{"data":{"tunnel-protocol":"none", "routing-mode":"native"}}'
    kubectl rollout restart ds cilium -n kube-system
    echo "============================================="
fi