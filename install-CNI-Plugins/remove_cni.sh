#!/bin/bash
set -euo pipefail

CNI="${1:-}"
if [ -z "$CNI" ]; then
  echo "Usage: bash remove_cni.sh flannel|calico"
  exit 1
fi

case "$CNI" in
  flannel)
    echo ">>> Removing Flannel..."
    kubectl delete -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml \
      --ignore-not-found=true 2>/dev/null || true
    kubectl delete namespace kube-flannel --ignore-not-found=true 2>/dev/null || true
    echo ">>> Flannel removed."
    ;;
  calico)
    echo ">>> Removing Calico..."
    kubectl delete installation default --ignore-not-found=true 2>/dev/null || true
    CALICO_VER="${CALICO_VER:-v3.30.3}"
    kubectl delete -f https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VER}/manifests/tigera-operator.yaml \
      --ignore-not-found=true 2>/dev/null || true

    for ns in calico-system calico-apiserver tigera-operator; do
      if kubectl get namespace "$ns" &>/dev/null; then
        echo "    Force deleting namespace: $ns"
        kubectl get namespace "$ns" -o json \
          | python3 -c "import sys,json; d=json.load(sys.stdin); d['spec']['finalizers']=[]; print(json.dumps(d))" \
          | kubectl replace --raw "/api/v1/namespaces/$ns/finalize" -f - 2>/dev/null || true
        kubectl delete namespace "$ns" --force --grace-period=0 2>/dev/null || true
      fi
    done

    kubectl get crds 2>/dev/null | grep -E "calico|tigera" | awk '{print $1}' \
      | xargs kubectl delete crd 2>/dev/null || true

    echo ">>> Calico removed."
    ;;
  *)
    echo "Unknown CNI: $CNI. Use flannel or calico."
    exit 1
    ;;
esac

echo ">>> Now run node_cleanup.sh on ALL nodes."