# GRS Project - Kubernetes CNI Benchmark Toolkit

## Portability Status
No, the scripts are not fully "run anywhere" yet. They are portable across similar Linux lab machines, but they assume:
- Linux hosts with `systemd` (Ubuntu-like environment).
- `kubeadm`, `kubectl`, `containerd`, and sudo access.
- A 3-node cluster pattern (1 control plane + 2 workers).
- Reachable node names/IPs and permissions to run cluster/admin commands.

They are not designed for:
- Windows/macOS hosts as Kubernetes nodes.
- Managed Kubernetes (EKS/GKE/AKS) control planes.
- Arbitrary node counts without adjusting env variables and expectations.

## Repository Layout
- `Setup/`: cluster lifecycle scripts.
- `install-CNI-Plugins/`: CNI install scripts.
- `Calculate/`: benchmark deployment and runners.
- Root helper scripts: cleanup, mode switch, and safety checks.

## Recommended Setup Flow (Semi-automated)
Run from control plane node:

```bash
bash Setup/semi_automation_setup.sh
```

Optional parameters:

```bash
POD_CIDR=10.244.0.0/16 \
CNI_PLUGIN=calico \
CALICO_MODE=bgp \
CALICO_VERSION=v3.30.3 \
EXPECTED_NODES=3 \
bash Setup/semi_automation_setup.sh
```

What this script automates:
- `kubeadm init` (if needed).
- kubeconfig setup.
- node readiness wait.
- selected CNI install.
- post-checks (`kubectl get nodes/pods`).

What remains manual by design (to avoid race/destructive mistakes):
- Running `Setup/node_reset.sh` on each worker.
- Running the generated `kubeadm join` command on workers.
- Node-level CNI cleanup verification on all workers.

## CNI Operations

### Install Calico
```bash
bash install-CNI-Plugins/install_calico.sh
```

BGP-only Calico (no overlay):
```bash
CALICO_ENCAP=None bash install-CNI-Plugins/install_calico.sh
```

### Switch Calico mode later
```bash
bash switch_calico_mode.sh bgp
bash switch_calico_mode.sh vxlan
```

### Verify Calico mode
```bash
bash calico_verify_mode.sh bgp
bash calico_verify_mode.sh vxlan
```

### CNI safety check on each node
```bash
bash cni_safety_check.sh
```

If it reports mixed CNI files in `/etc/cni/net.d`, clean the node before proceeding.

## Benchmark Flow
From `Calculate/`:

```bash
cd Calculate
bash automation.sh
```

Configuration is in `Calculate/config.env`.

## Destructive Scripts
These scripts can disrupt networking/cluster state. Use intentionally:
- `Setup/node_reset.sh`
- `wipe_cni.sh --yes`
- `delete_calico.sh`
- `Setup/delete_cluster.sh`

## Quick Recovery Notes
- If pods are stuck in `ContainerCreating` and events mention the wrong CNI plugin, check for stale files in `/etc/cni/net.d`.
- For Calico BGP-only, expected checks:
  - `kubectl get installation default -o jsonpath='{.spec.calicoNetwork.ipPools[0].encapsulation}{"\n"}'` -> `None`
  - `kubectl get ippool default-ipv4-ippool -o jsonpath='{.spec.vxlanMode}{" "}{.spec.ipipMode}{"\n"}'` -> `Never Never`
