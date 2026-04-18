#!/bin/bash
# ==========================================
# CPU OVERHEAD MONITOR DURING FORTIO
# Run on master while fortio test is active
# Usage: bash cpu_overhead.sh
# ==========================================
set -euo pipefail
source config.env

CSV_PODS="${TEST_NAME}_cpu_pods.csv"
CSV_NODES="${TEST_NAME}_cpu_nodes.csv"
FORTIO_DURATION=15

SERVER_IP=$(kubectl get pod fortio-server -o jsonpath='{.status.podIP}')

echo ">>> Starting CPU overhead capture for: $TEST_NAME"
echo ">>> Fortio target: http://${SERVER_IP}:8080/echo"
echo ""

echo "Timestamp,Namespace,Pod,CPU_cores,Memory" > "$CSV_PODS"
echo "Timestamp,Node,CPU_percent,Memory_percent" > "$CSV_NODES"

echo ">>> Launching Fortio (1000 QPS, 50 connections, ${FORTIO_DURATION}s)..."
kubectl exec fortio-client -- \
  fortio load -c 50 -qps 1000 -t "${FORTIO_DURATION}s" \
  "http://${SERVER_IP}:8080/echo" > /tmp/fortio_cpu_run.json 2>/dev/null &

FORTIO_PID=$!
echo ">>> Sampling CPU every 2s..."
echo ""

SAMPLE=0
while kill -0 $FORTIO_PID 2>/dev/null; do
  TS=$(date +%H:%M:%S)
  SAMPLE=$((SAMPLE + 1))

  kubectl top pods -A --no-headers 2>/dev/null \
    | grep -E "kube-system|kube-flannel|calico-system|cilium" \
    | while read -r ns pod cpu mem; do
        echo "$TS,$ns,$pod,$cpu,$mem"
      done >> "$CSV_PODS"

  kubectl top nodes --no-headers 2>/dev/null \
    | while read -r node cpu cpupct mem mempct; do
        echo "$TS,$node,$cpupct,$mempct"
      done >> "$CSV_NODES"

  echo "  [Sample $SAMPLE @ $TS] captured"
  sleep 2
done

wait $FORTIO_PID || true
echo ""
echo ">>> Fortio complete. $SAMPLE samples captured."
echo ""

echo "============================================="
echo " POD CPU SUMMARY: $TEST_NAME"
echo "============================================="
echo "Pod,Avg_CPU,Peak_CPU"
awk -F',' 'NR>1 {
  gsub(/m/, "", $4)
  sum[$3] += $4
  count[$3]++
  if ($4 > peak[$3]) peak[$3] = $4
}
END {
  for (pod in sum)
    printf "%s,%.1fm,%.1fm\n", pod, sum[pod]/count[pod], peak[pod]
}' "$CSV_PODS" | sort

echo ""
echo "============================================="
echo " NODE CPU SUMMARY: $TEST_NAME"
echo "============================================="
echo "Node,Avg_CPU%,Peak_CPU%"
awk -F',' 'NR>1 {
  gsub(/%/, "", $3)
  sum[$2] += $3
  count[$2]++
  if ($3 > peak[$2]) peak[$2] = $3
}
END {
  for (node in sum)
    printf "%s,%.1f%%,%.1f%%\n", node, sum[node]/count[node], peak[node]
}' "$CSV_NODES" | sort

echo ""
echo ">>> Results saved to $CSV_PODS and $CSV_NODES"