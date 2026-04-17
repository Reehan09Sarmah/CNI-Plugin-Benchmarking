#!/bin/bash
# Run this on Prakhar-PC to switch Cilium from VXLAN to Native Routing

echo ">>> [1/2] Reconfiguring Cilium for Native Routing (No VXLAN)..."

# routingMode=native: Disables the VXLAN tunnel
# autoDirectNodeRoutes=true: Tells eBPF to setup the routes between your laptops automatically
# ipv4NativeRoutingCIDR: Must match your 10.244.0.0/16 cluster CIDR
cilium upgrade \
  --set routingMode=native \
  --set autoDirectNodeRoutes=true \
  --set ipv4NativeRoutingCIDR=10.244.0.0/16

echo ">>> [2/2] Waiting for Cilium to restart and sync routes..."
cilium status --wait

echo "============================================="
echo " ✅ CILIUM NATIVE ROUTING ENABLED"
echo " Verification: Run 'cilium status | grep Routing'"
echo " It should now say: 'Routing: Native'"
echo "============================================="