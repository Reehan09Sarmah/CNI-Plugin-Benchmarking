#!/bin/bash
# ==========================================
# CLUSTER PRE-FLIGHT DIAGNOSTICS
# Run this before any benchmark execution
# ==========================================

echo "============================================="
echo " 🩺 INITIATING PRE-FLIGHT DIAGNOSTICS"
echo "============================================="

# --- 1. NODE HEALTH CHECK ---
echo ">>> [1/4] Checking Physical Node Status..."
NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
READY_NODES=$(kubectl get nodes | grep " Ready" | wc -l)

if [ "$NODE_COUNT" -ne 3 ]; then
    echo "  [WARNING] Expected 3 nodes (Control Plane + 2 Workers), found $NODE_COUNT."
fi

if [ "$READY_NODES" -ne "$NODE_COUNT" ]; then
    echo "  [FAIL] Not all nodes are in 'Ready' state. Check kubelet on workers."
    kubectl get nodes
    exit 1
else
    echo "  [PASS] All $READY_NODES nodes are Ready."
fi

# --- 2. CNI SYSTEM HEALTH ---
echo ">>> [2/4] Checking System & CNI Pods..."
FAILED_SYSTEM_PODS=$(kubectl get pods -A | grep -v 'Running\|Completed\|NAMESPACE' | wc -l)

if [ "$FAILED_SYSTEM_PODS" -ne 0 ]; then
    echo "  [FAIL] Found $FAILED_SYSTEM_PODS system pods struggling (CrashLoop/Pending)."
    kubectl get pods -A | grep -v 'Running\|Completed'
    echo "  Fix the CNI before running benchmarks!"
    exit 1
else
    echo "  [PASS] All system and CNI pods are healthy."
fi

# --- 3. BENCHMARK POD VERIFICATION ---
echo ">>> [3/4] Checking Benchmark Infrastructure..."
EXPECTED_PODS=("iperf-server" "iperf-client" "netperf-server" "netperf-client" "fortio-server" "fortio-client")
MISSING=0

for pod in "${EXPECTED_PODS[@]}"; do
    STATUS=$(kubectl get pod "$pod" -o jsonpath='{.status.phase}' 2>/dev/null)
    if [ "$STATUS" != "Running" ]; then
        echo "  [ERROR] Pod '$pod' is missing or not Running (Current State: $STATUS)"
        MISSING=$((MISSING + 1))
    fi
done

if [ "$MISSING" -ne 0 ]; then
    echo "  [FAIL] Benchmark pods are not fully deployed. Did you run 00_deploy.sh?"
    exit 1
else
    echo "  [PASS] All 6 benchmark pods are Running."
fi

# --- 4. NETWORK ROUTING VERIFICATION ---
echo ">>> [4/4] Verifying CNI IP Allocation..."
SERVER_IP=$(kubectl get pod iperf-server -o jsonpath='{.status.podIP}' 2>/dev/null)
CLIENT_IP=$(kubectl get pod iperf-client -o jsonpath='{.status.podIP}' 2>/dev/null)

if [ -z "$SERVER_IP" ] || [ -z "$CLIENT_IP" ]; then
    echo "  [FAIL] Pods do not have IP addresses assigned. The CNI is broken."
    exit 1
else
    echo "  [PASS] IP Allocation successful. (Server: $SERVER_IP, Client: $CLIENT_IP)"
fi

echo "============================================="
echo " ✅ ALL SYSTEMS GO. READY FOR BENCHMARKS."
echo "============================================="