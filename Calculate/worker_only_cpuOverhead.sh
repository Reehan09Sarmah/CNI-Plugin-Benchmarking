#!/bin/bash
# Put this file on worker nodes ONLY.
# Run it with: bash node_cpu_monitor.sh 30

DURATION=${1:-30}
echo ">>> Monitoring CPU for $DURATION seconds..."
# Get average idle percentage over the duration
IDLE_AVG=$(mpstat 1 $DURATION | tail -1 | awk '{print $NF}')
# Calculate usage (100 - idle)
USAGE=$(echo "100 - $IDLE_AVG" | bc)
echo "======================================"
echo " AVERAGE CPU USAGE: $USAGE%"
echo "======================================"