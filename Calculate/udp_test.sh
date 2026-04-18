#!/bin/bash
# ==========================================
# UDP THROUGHPUT, PACKET LOSS & JITTER
# Tests at 3 bandwidth targets
# ==========================================
set -euo pipefail
source config.env

CSV_FILE="${TEST_NAME}_udp.csv"
SERVER_IP=$(kubectl get pod iperf-server -o jsonpath='{.status.podIP}')
RUNS=3

echo ">>> UDP Test for: $TEST_NAME"
echo ">>> Server IP: $SERVER_IP"
echo "Bandwidth_Target,Run,Throughput_Mbps,Packet_Loss_Pct,Jitter_ms" > "$CSV_FILE"

for BW in 10M 25M 50M; do
  echo ""
  echo ">>> Testing at $BW..."
  for ((i=1; i<=RUNS; i++)); do
    echo "  [${BW} Run $i/$RUNS] Firing 30s..."
    RAW=$(kubectl exec iperf-client -- \
      iperf3 -c "$SERVER_IP" -u -b "$BW" -t 30 2>/dev/null) || true

    THROUGHPUT=$(echo "$RAW" | grep -E "receiver" | awk '{print $7}')
    UNIT=$(echo "$RAW" | grep -E "receiver" | awk '{print $8}')
    LOSS=$(echo "$RAW" | grep -E "receiver" | awk '{print $12}' | tr -d '()')
    JITTER=$(echo "$RAW" | grep -E "receiver" | awk '{print $9}')

    if [ -z "$THROUGHPUT" ]; then
      echo "    ERROR: Run $i failed"
    else
      if echo "$UNIT" | grep -q "Gbits"; then
        THROUGHPUT=$(echo "$THROUGHPUT * 1000" | bc)
      fi
      echo "$BW,$i,$THROUGHPUT,$LOSS,$JITTER" >> "$CSV_FILE"
      echo "    Throughput: ${THROUGHPUT} Mbps | Loss: ${LOSS}% | Jitter: ${JITTER}ms"
    fi
    sleep 5
  done
done

echo ""
echo ">>> UDP results saved to $CSV_FILE"