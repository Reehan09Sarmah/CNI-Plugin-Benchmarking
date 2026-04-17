#!/bin/bash
set -euo pipefail

echo ">>> Checking local CNI config directory: /etc/cni/net.d"

if [[ ! -d /etc/cni/net.d ]]; then
	echo "FAIL: /etc/cni/net.d does not exist."
	exit 1
fi

mapfile -t cni_files < <(ls -1 /etc/cni/net.d/*.conf /etc/cni/net.d/*.conflist 2>/dev/null || true)

if [[ ${#cni_files[@]} -eq 0 ]]; then
	echo "FAIL: No CNI config (.conf/.conflist) found in /etc/cni/net.d."
	exit 1
fi

echo "Found CNI config files:"
printf ' - %s\n' "${cni_files[@]}"

has_calico=0
has_cilium=0
has_flannel=0

for f in "${cni_files[@]}"; do
	[[ "$f" == *calico* ]] && has_calico=1
	[[ "$f" == *cilium* ]] && has_cilium=1
	[[ "$f" == *flannel* ]] && has_flannel=1
done

cni_count=$((has_calico + has_cilium + has_flannel))

if [[ $cni_count -gt 1 ]]; then
	echo "FAIL: Mixed CNI configs detected (calico/cilium/flannel overlap)."
	echo "Fix: keep only one CNI's config files on each node before running benchmarks."
	exit 2
fi

echo "PASS: No mixed CNI detected on this node."

