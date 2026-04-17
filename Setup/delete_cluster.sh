#!/bin/bash
# Run on Prakhar-PC when you want to destroy everything.
set -euo pipefail

echo ">>> [1/2] Draining and Deleting Worker Nodes..."
for node in $(kubectl get nodes -o name | grep -v control-plane); do
    kubectl drain $node --ignore-daemonsets --delete-emptydir-data --force
    kubectl delete $node
done

echo ">>> [2/2] Triggering local reset..."
"$(dirname "$0")/node_reset.sh"

echo ">>> Go run 'bash Setup/node_reset.sh' on Reehan and Midnight now."