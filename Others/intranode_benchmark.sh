#!/bin/bash
# ==========================================
# INTRANODE (SAME-NODE) BENCHMARK SUITE
# Tests pure CNI software overhead without Wi-Fi
# ==========================================

TEST_NAME="cilium_vxlan_intranode"
TARGET_NODE="reehan-pc"  # BOTH client and server will live here

echo "============================================="
echo " 🚀 STARTING INTRANODE BENCHMARK"
echo " Target Node: $TARGET_NODE"
echo "============================================="

# --- 1. DEPLOYMENT ---
echo ">>> [1/4] Deploying pods to a single node ($TARGET_NODE)..."
cat <<YAML > intranode-infrastructure.yaml
---
apiVersion: v1
kind: Pod
metadata: { name: iperf-server-intra, labels: { app: throughput } }
spec:
  nodeName: ${TARGET_NODE}
  containers:
  - name: iperf
    image: networkstatic/iperf3
    command: ["iperf3", "-s"]
    ports: [{ containerPort: 5201 }]
---
apiVersion: v1
kind: Pod
metadata: { name: iperf-client-intra, labels: { app: throughput } }
spec:
  nodeName: ${TARGET_NODE}
  containers:
  - name: iperf
    image: networkstatic/iperf3
    command: ["sleep", "infinity"]
---
apiVersion: v1
kind: Pod
metadata: { name: netperf-server-intra, labels: { app: latency } }
spec:
  nodeName: ${TARGET_NODE}
  containers:
  - name: netperf
    image: cilium/netperf
    command: ["netserver", "-D"]
    ports: [{ containerPort: 12865 }]
---
apiVersion: v1
kind: Pod
metadata: { name: netperf-client-intra, labels: { app: latency } }
spec:
  nodeName: ${TARGET_NODE}
  containers:
  - name: netperf
    image: cilium/netperf
    command: ["/bin/sh", "-c", "sleep infinity"]
---
apiVersion: v1
kind: Pod
metadata: { name: fortio-server-intra, labels: { app: microservice } }
spec:
  nodeName: ${TARGET_NODE}
  containers:
  - name: fortio
    image: fortio/fortio
    command: ["fortio", "server"]
    ports: [{ containerPort: 8080 }]
---
apiVersion: v1
kind: Pod
metadata: { name: fortio-client-intra, labels: { app: microservice } }
spec:
  nodeName: ${TARGET_NODE}
  containers:
  - name: fortio
    image: fortio/fortio
    command: ["fortio", "server"]
YAML

kubectl delete -f intranode-infrastructure.yaml 2>/dev/null
kubectl apply -f intranode-infrastructure.yaml
kubectl wait --for=condition=ready pod --all --timeout=120s

# --- 2. THROUGHPUT ---
echo ">>> [2/4] Running Intranode Throughput..."
IPERF_IP=$(kubectl get pod iperf-server-intra -o jsonpath='{.status.podIP}')
echo "Run,Throughput_Gbps" > ${TEST_NAME}_throughput.csv

for i in {1..3}; do
    RAW_JSON=$(kubectl exec iperf-client-intra -- iperf3 -c $IPERF_IP -t 15 --json 2>/dev/null)
    RESULT=$(echo "$RAW_JSON" | jq -r '.end.sum_received.bits_per_second / 1000000000')
    echo "$i,$RESULT" >> ${TEST_NAME}_throughput.csv
    echo "    Run $i: $RESULT Gbps"
done

# --- 3. LATENCY BY SIZES ---
echo ">>> [3/4] Running Intranode Latency..."
NETPERF_IP=$(kubectl get pod netperf-server-intra -o jsonpath='{.status.podIP}')
echo "Payload_Size,Run,Transactions_Per_Sec" > ${TEST_NAME}_latency_sizes.csv

for SIZE in 1 64 256; do
    echo "  Testing ${SIZE}B..."
    for i in {1..3}; do
        RESULT=$(kubectl exec netperf-client-intra -- netperf -H $NETPERF_IP -t TCP_RR -l 5 -- -r ${SIZE},${SIZE} 2>/dev/null | grep -E '^[[:space:]]*[0-9]+' | awk '{print $6}')
        echo "${SIZE},$i,$RESULT" >> ${TEST_NAME}_latency_sizes.csv
    done
done

# --- 4. MICROSERVICES (FORTIO) ---
echo ">>> [4/4] Running Intranode Microservices Load..."
FORTIO_IP=$(kubectl get pod fortio-server-intra -o jsonpath='{.status.podIP}')
echo "Run,P50_ms,P99_ms,Max_ms" > ${TEST_NAME}_fortio.csv

for i in {1..3}; do
    OUTPUT=$(kubectl exec fortio-client-intra -- fortio load -c 50 -qps 1000 -t 10s -json - http://$FORTIO_IP:8080/echo 2>/dev/null)
    P50=$(echo "$OUTPUT" | jq '.DurationHistogram.Percentiles[] | select(.Percentile == 50) | .Value * 1000')
    P99=$(echo "$OUTPUT" | jq '.DurationHistogram.Percentiles[] | select(.Percentile == 99) | .Value * 1000')
    MAX=$(echo "$OUTPUT" | jq '.DurationHistogram.Max * 1000')
    echo "$i,$P50,$P99,$MAX" >> ${TEST_NAME}_fortio.csv
    echo "    Run $i -> P50: ${P50}ms | P99: ${P99}ms | Max: ${MAX}ms"
done

echo "============================================="
echo " ✅ INTRANODE BENCHMARKS COMPLETE!"
echo " Results saved with prefix: ${TEST_NAME}_"
echo "============================================="