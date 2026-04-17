#!/bin/bash
# ==========================================
# MASTER TEST EXECUTOR
# Run this file to automate the entire suite
# ==========================================

source config.env

echo "============================================="
echo " STARTING FULL CNI BENCHMARK PIPELINE"
echo " Configuration Profile: $TEST_NAME"
echo "============================================="

# Ensure all scripts are executable
chmod +x 00_deploy.sh 01_throughput.sh 02_latency_sizes.sh 03_microservices.sh

bash ./deploy_pods.sh
bash ./throughput.sh
bash ./latency.sh
bash ./microservices.sh

echo "============================================="
echo " SUCCESS! ALL TESTS COMPLETE."
echo " Files saved as: ${TEST_NAME}_*.csv"
echo "============================================="

# Optional CPU Prompt at the very end
SERVER_IP=$(kubectl get pod iperf-server -o jsonpath='{.status.podIP}')
echo ">>> [5/5] MANUAL CPU OVERHEAD TEST (Optional)"
echo "1. On the Worker Nodes, run: bash node_cpu_monitor.sh 30"
echo "2. Press ENTER here to trigger the 30s network blast."
read -p "Press ENTER when ready..."
kubectl exec iperf-client -- iperf3 -c $SERVER_IP -t 30 2>/dev/null >/dev/null
echo "Done! Record the percentages from the worker screens."