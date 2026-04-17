#!/bin/bash
source config.env
CSV_FILE="${TEST_NAME}_throughput.csv"
SERVER_IP=$(kubectl get pod iperf-server -o jsonpath='{.status.podIP}')

echo ">>> [2/5] Running Throughput ($TEST_NAME)..."
echo "Run,Throughput_Gbps" > $CSV_FILE

for ((i=1; i<=$RUNS; i++)); do
    echo "  [Run $i] Firing $THROUGHPUT_TIME seconds..."
    RAW_JSON=$(kubectl exec iperf-client -- iperf3 -c $SERVER_IP -t $THROUGHPUT_TIME --json 2>/dev/null)
    RESULT=$(echo "$RAW_JSON" | jq -r '.end.sum_received.bits_per_second / 1000000000')
    
    if [ -z "$RESULT" ] || [ "$RESULT" == "null" ]; then 
        echo "    Error: Run failed."
    else
        echo "$i,$RESULT" >> $CSV_FILE
        echo "    Result: $RESULT Gbps"
    fi
    sleep 3 
done