#!/bin/bash
source config.env
CSV_FILE="${TEST_NAME}_fortio.csv"
SERVER_IP=$(kubectl get pod fortio-server -o jsonpath='{.status.podIP}')

echo ">>> [4/5] Running Microservices Load ($TEST_NAME)..."
echo "Run,P50_ms,P99_ms,Max_ms" > $CSV_FILE

for ((i=1; i<=$RUNS; i++)); do
    echo "  [Run $i] 1000 QPS for $FORTIO_TIME..."
    OUTPUT=$(kubectl exec fortio-client -- fortio load -c 50 -qps 1000 -t $FORTIO_TIME -json - http://$SERVER_IP:8080/echo 2>/dev/null)
    
    P50=$(echo "$OUTPUT" | jq '.DurationHistogram.Percentiles[] | select(.Percentile == 50) | .Value * 1000')
    P99=$(echo "$OUTPUT" | jq '.DurationHistogram.Percentiles[] | select(.Percentile == 99) | .Value * 1000')
    MAX=$(echo "$OUTPUT" | jq '.DurationHistogram.Max * 1000')
    
    echo "$i,$P50,$P99,$MAX" >> $CSV_FILE
    echo "    P50: ${P50}ms | P99: ${P99}ms | Max: ${MAX}ms"
    sleep 3
done