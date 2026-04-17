#!/bin/bash
# DO NOT RUN THIS AS-IS.
# This is a placeholder to remind you how to join workers.

echo "To join workers to the cluster:"
echo "1. Ensure you ran 'bash Setup/node_reset.sh' on them first."
echo "2. Paste the exact 'sudo kubeadm join...' command output by script 01."
echo ""
echo "Example:"
echo "sudo kubeadm join <PRAKHAR_IP>:6443 --token <token> --discovery-token-ca-cert-hash <hash>"