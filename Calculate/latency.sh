#!/bin/bash
# latency.sh
set -euo pipefail
source config.env

CSV_FILE="${TEST_NAME}_latency_sizes.csv"
SERVER_IP=$(kubectl get pod netperf-server -o jsonpath='{.status.podIP}')

echo ">>> [3/5] Running Latency by Sizes ($TEST_NAME)..."
echo "Payload_Size,Run,Transactions_Per_Sec" > $CSV_FILE

for SIZE in 1 64 256; do
  echo ">>> Testing Payload: ${SIZE} bytes"
  for ((i=1; i<=$RUNS; i++)); do
    RESULT=$(kubectl exec netperf-client -- \
      netperf -H $SERVER_IP -t TCP_RR -l $LATENCY_TIME -P 0 -- \
      -r ${SIZE},${SIZE} 2>/dev/null \
      | grep -E '^[[:space:]]*[0-9]+' \
      | awk '{print $6}')
    if [ -z "$RESULT" ]; then
      echo "    Error on Size=${SIZE} Run=$i"
    else
      echo "${SIZE},$i,$RESULT" >> $CSV_FILE
      echo "    [${SIZE}B Run $i] $RESULT Trans/sec"
    fi
    sleep 2
  done
done

echo ""
echo ">>> Latency results saved to $CSV_FILE"