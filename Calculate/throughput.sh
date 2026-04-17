#!/bin/bash
# throughput.sh
set -euo pipefail
source config.env

CSV_FILE="${TEST_NAME}_throughput.csv"
SERVER_IP=$(kubectl get pod iperf-server -o jsonpath='{.status.podIP}')

echo ">>> [2/5] Running Throughput ($TEST_NAME)..."
echo "Run,Throughput_Gbps" > $CSV_FILE

TOTAL=0
for ((i=1; i<=$RUNS; i++)); do
  echo "  [Run $i] Firing ${THROUGHPUT_TIME}s..."
  RAW_JSON=$(kubectl exec iperf-client -- iperf3 -c $SERVER_IP -t $THROUGHPUT_TIME --json 2>/dev/null)
  RESULT=$(echo "$RAW_JSON" | jq -r '.end.sum_received.bits_per_second / 1000000000')
  if [ -z "$RESULT" ] || [ "$RESULT" == "null" ]; then
    echo "    Error: Run $i failed — check pod connectivity"
  else
    echo "$i,$RESULT" >> $CSV_FILE
    echo "    Result: $RESULT Gbps"
    TOTAL=$(echo "$TOTAL + $RESULT" | bc)
  fi
  sleep 3
done

AVG=$(echo "scale=3; $TOTAL / $RUNS" | bc)
echo ""
echo ">>> Throughput Average: $AVG Gbps"
echo ">>> Results saved to $CSV_FILE"