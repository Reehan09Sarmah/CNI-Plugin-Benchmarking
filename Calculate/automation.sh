#!/bin/bash
# master.sh
set -euo pipefail
source config.env

echo "============================================="
echo " STARTING FULL CNI BENCHMARK PIPELINE"
echo " Configuration Profile: $TEST_NAME"
echo "============================================="

chmod +x deploy_pods.sh throughput.sh latency.sh microservices.sh

bash ./deploy_pods.sh

# Capture server IP right after pods are up, before tests tear anything down
SERVER_IP=$(kubectl get pod iperf-server -o jsonpath='{.status.podIP}')
echo ">>> iperf-server pod IP: $SERVER_IP"

bash ./throughput.sh
bash ./latency.sh
bash ./microservices.sh

echo "============================================="
echo " SUCCESS! ALL TESTS COMPLETE."
echo " Files saved as: ${TEST_NAME}_*.csv"
echo "============================================="

echo ">>> [OPTIONAL] CPU OVERHEAD TEST"
echo "On both worker nodes, run: bash worker_only_cpuOverhead.sh 30"
read -p "Press ENTER when workers are ready..."
kubectl exec iperf-client -- iperf3 -c $SERVER_IP -t 30
echo "Done! Record CPU percentages from worker screens."