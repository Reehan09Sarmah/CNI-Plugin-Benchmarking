#!/bin/bash
# Run on Prakhar-PC when you want to destroy everything.
echo ">>> [1/2] Draining and Deleting Worker Nodes..."
for node in $(kubectl get nodes -o name | grep -v control-plane); do
    kubectl drain $node --ignore-daemonsets --delete-emptydir-data --force
    kubectl delete $node
done

echo ">>> [2/2] Triggering local reset..."
bash 00_reset_node.sh

echo ">>> Go run 'bash 00_reset_node.sh' on Reehan and Midnight now."