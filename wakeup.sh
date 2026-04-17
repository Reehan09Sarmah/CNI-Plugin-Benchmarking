#!/bin/bash
# ==========================================
# K8S NODE REBOOT RECOVERY SCRIPT
# Run this on ALL laptops after power-on
# ==========================================

echo ">>> [1/3] Disabling Swap (Kubernetes Requirement)..."
sudo swapoff -a
# This line prevents swap from turning back on after the next reboot
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

echo ">>> [2/3] Ensuring Container Runtime & Kubelet are running..."
sudo systemctl daemon-reload
sudo systemctl enable --now containerd
sudo systemctl restart kubelet

echo ">>> [3/3] Verifying Node Readiness..."
sleep 5
if systemctl is-active --quiet kubelet; then
    echo "✅ Kubelet is running."
else
    echo "❌ Kubelet failed to start. Run 'journalctl -xeu kubelet' to see why."
fi

# Only run this check on the Control Plane (Prakhar)
if [ -f "/etc/kubernetes/admin.conf" ]; then
    echo ">>> [CONTROL PLANE] Waiting for API Server to wake up..."
    until kubectl get nodes &> /dev/null; do
        printf "."
        sleep 2
    done
    echo -e "\n✅ Cluster is reachable. Current Node Status:"
    kubectl get nodes
fi
```

---

### ⚠️ The "IP Address Trap" (Read this if things don't start)
When you switch off your laptops and turn them back on, your Wi-Fi router might give **Prakhar-PC** a new IP address (e.g., it was `.105` yesterday, but today it is `.110`). 

**If Prakhar's IP changes, the cluster will break.** You have two choices:

1.  **The Pro Way (Static IP):** Go into your laptop's Wi-Fi settings and set a "Manual/Static IP" so it never changes.
2.  **The Quick Way (Re-Init):** If the IP changed and you can't reach the cluster, just run the **Purge & Reset** sequence from your manual:
    * `bash 00_reset_node.sh` (On all)
    * `bash 01_create_control_plane.sh` (On Prakhar)
    * Re-join the workers. 
    * *Since you have the scripts, this only takes 2 minutes!*

---

### 📖 Final Addition to the Operations Manual
Add this section to the very beginning of your **cni_benchmark_manual.md**:

```markdown
## 🌅 Daily Start-Up Procedure (The "Cold Start")
*Use this every time you open your laptops to start a new testing session.*

1. **Power on** all laptops and connect to the **same** Wi-Fi network.
2. **On All Laptops:** Run the wake-up script to prep the kernel:
   ```bash
   bash 07_wake_up_nodes.sh
   ```
3. **On Prakhar-PC:** Check if the workers reconnected:
   ```bash
   kubectl get nodes
   ```
   *If nodes stay in 'NotReady' for more than 2 minutes, the CNI pods might be stuck. Restart them:*
   `kubectl delete pods -n kube-system -l k8s-app=kube-proxy` (This often kicks the network back to life).

4. **Verify Signal:** Ensure Reehan and Midnight have full Wi-Fi bars before starting the `master_runner.sh`.