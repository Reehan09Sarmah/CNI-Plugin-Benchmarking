# GRS Project - CNI Benchmark Study Under Real Campus Network Conditions

This repository contains our Kubernetes CNI comparison work across Calico, Flannel, and Cilium.

The key outcome of this project is not only benchmark numbers, but a diagnosis: in our environment (university Wi-Fi and lab hosts), practical network constraints changed plugin behavior enough to flip several theoretical expectations.

## Executive Summary

- We built a repeatable benchmark workflow for multi-CNI testing on a kubeadm cluster.
- We measured TCP throughput, request/response rate, latency distribution, UDP behavior, and control-plane overhead.
- We observed strong environment effects and run-to-run variability.
- Final conclusion: results are valid and publishable as environment-conditioned findings, not universal ranking claims.

## What We Built and Ran

### Cluster and CNI lifecycle automation

- Cluster setup/reset/join helpers in `Setup/`.
- CNI install/removal scripts in `install-CNI-Plugins/`.
- Safety and cleanup tools in `Others/`.

### Benchmarks executed (`Calculate/`)

- `throughput.sh`: TCP throughput with `iperf3` (`Results/*_throughput.csv`)
- `latency.sh`: TCP_RR transactions/sec by payload (`Results/*_latency_sizes.csv`)
- `microservices.sh`: Fortio P50/P99/Max latency (`Results/*_fortio.csv`)
- `udp_test.sh`: UDP throughput, packet loss, jitter (`Calculate/*_udp.csv`)
- `control_cpu_overhead.sh`: node/pod CPU and memory during load (`Calculate/*_cpu_nodes.csv`, `Calculate/*_cpu_pods.csv`)

### Baseline benchmark config

From `Calculate/config.env`:

- `RUNS=5` (most tests)
- Throughput duration: `30s`
- Latency duration: `10s`
- Fortio duration: `15s`

## Data Coverage and Quality Notes

These points are critical for correct interpretation:

- `Results/calico_bgp_fortio.csv` has 4 runs, not 5.
- `Results/cilium_vxlan_latency_sizes.csv` is malformed as multi-line records and requires custom parsing.
- `Results/flannel_hostgw_throughput.csv` is highly unstable (two very low runs, three high runs).
- Pod CPU values in `Calculate/*_cpu_pods.csv` are in millicores (`m`), not full cores.

## Consolidated Results

### 1) TCP throughput (Gbps, higher is better)

| Mode | Mean Throughput (Gbps) | Notes |
|---|---:|---|
| Calico VXLAN | 0.1186 | Highest mean |
| Flannel VXLAN | 0.1178 | Very close to Calico VXLAN |
| Calico BGP | 0.1161 | Strong and consistent |
| Cilium Native | 0.1021 | Lower than expected |
| Flannel host-gw | 0.0884 | High variance |
| Cilium VXLAN | 0.0576 | Lowest throughput |

### 2) Fortio latency (ms, lower is better)

Average P99 latency:

- Cilium VXLAN: `27.75`
- Flannel VXLAN: `38.77`
- Calico VXLAN: `46.21`
- Cilium Native: `60.19`
- Flannel host-gw: `90.33`
- Calico BGP: `111.24`

Important outlier:

- `Results/flannel_hostgw_fortio.csv` contains a max latency spike around `2347 ms`.

### 3) TCP request/response by payload (transactions/sec, higher is better)

Average across payload sizes:

- Flannel VXLAN: `202.4`
- Flannel host-gw: `197.8`
- Cilium VXLAN: `173.6` (after reconstructing malformed CSV)
- Calico BGP: `157.3`
- Calico VXLAN: `156.8`
- Cilium Native: `112.1`

### 4) UDP behavior (Mbps / loss / jitter)

Average across target rates 10M, 25M, 50M:

- Calico BGP: `11.88 Mbps`, `38.15%` loss, `1.81 ms` jitter
- Flannel VXLAN: `9.98 Mbps`, `46.50%` loss, `1.94 ms` jitter
- Flannel host-gw: `8.67 Mbps`, `57.94%` loss, `3.36 ms` jitter
- Calico VXLAN: `5.78 Mbps`, `68.33%` loss, `13.34 ms` jitter

Note: no Cilium UDP CSV in current dataset.

### 5) CPU overhead snapshot

Node average CPU usage:

- Calico BGP: `6.00%`
- Flannel host-gw: `5.22%` (peaks up to `12%` on one node)
- Calico VXLAN: `5.17%`
- Flannel VXLAN: `3.92%`

Pod average CPU (millicores):

- Calico VXLAN: `14.71m` (inflated by `kube-apiserver` spikes up to `177m`)
- Flannel VXLAN: `8.41m`
- Flannel host-gw: `8.33m`
- Calico BGP: `8.24m`

## Why Results Flipped vs Theory

In clean wired environments, theoretical CNI expectations often hold. In our campus network scenario, the dominant factors were likely external to pure CNI datapath efficiency:

- Variable Wi-Fi airtime and contention
- Non-trivial packet loss and jitter under load
- Queueing/retransmission effects dominating transport behavior
- Overlay/MTU penalties becoming more visible under loss
- Endpoint and control-plane contention on mixed lab hardware

This explains observed inversions, such as:

- Cilium VXLAN showing very good latency distribution but poor throughput.
- Flannel VXLAN and Calico BGP performing strongly in specific practical metrics.
- Host-gw mode showing good request-rate means but unstable outliers.

## Diagnosis and Final Position

This project now represents a practical systems diagnosis, not just a textbook benchmark:

- The CNI ranking is environment-dependent.
- Under university Wi-Fi constraints, noise and contention can dominate expected plugin advantages.
- Our conclusions are defensible if presented as context-specific findings.

Recommended presentation statement:

"Our CNI comparison demonstrates that real network conditions can materially invert theoretical performance rankings; therefore, CNI choice should be validated in the target environment rather than selected from generic benchmarks alone."

## Achievements

- End-to-end automation for multi-CNI benchmark cycles.
- Collected datasets across throughput, latency, UDP behavior, and resource overhead.
- Identified and documented data quality artifacts and outliers.
- Produced a diagnosis linking performance inversion to realistic network conditions.
- Converted results into a presentation-ready narrative grounded in measured evidence.

## Reproducibility and Safe Usage

- Primary execution entry: `Calculate/automation.sh`
- Configuration source: `Calculate/config.env`
- CNI safety check before/after switching: `Others/cni_safety_check.sh`

Scripts that can disrupt cluster/network state:

- `Setup/node_reset.sh`
- `Others/wipe_cni.sh --yes`
- `Others/delete_calico.sh`
- `Setup/delete_cluster.sh`

## Next Improvement Targets

- Add Cilium UDP and CPU-overhead datasets for full parity.
- Normalize CSV schema validation before aggregation.
- Increase run count and include time-of-day windows.
- Compare same tests on wired LAN vs Wi-Fi to isolate environmental impact.
