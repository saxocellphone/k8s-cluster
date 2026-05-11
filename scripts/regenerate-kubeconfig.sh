#!/bin/bash
# Regenerate ./kubeconfig from the control plane via talosctl.
#
# Use case: a new machine clones the repo and securely transfers `talosconfig`
# (e.g. via 1Password, scp from a trusted machine, or AirDrop). Running this
# script then produces a working kubeconfig — no need to also transfer the
# kubeconfig file separately.
#
# Why: kubeconfig is derived from cluster CA + a freshly-issued client cert.
# It's reproducible from talosconfig alone, so we only need to securely
# transfer one file (the smaller, more sensitive talosconfig) instead of two.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
TALOSCONFIG="${REPO_DIR}/talosconfig"
KUBECONFIG_OUT="${REPO_DIR}/kubeconfig"
CONTROL_PLANE_IP="192.168.8.227"

if [[ ! -f "$TALOSCONFIG" ]]; then
  cat >&2 <<EOF
ERROR: talosconfig missing at $TALOSCONFIG

Securely copy it once from another trusted machine, e.g.:
  scp other-machine:~/path/to/k8s-cluster/talosconfig "$TALOSCONFIG"

Then re-run this script.
EOF
  exit 1
fi

if ! command -v talosctl >/dev/null; then
  echo "ERROR: talosctl not installed. brew install siderolabs/tap/talosctl" >&2
  exit 1
fi

echo "Regenerating kubeconfig from talosctl (control plane: $CONTROL_PLANE_IP)..."
talosctl --talosconfig="$TALOSCONFIG" --nodes "$CONTROL_PLANE_IP" \
  kubeconfig --force "$KUBECONFIG_OUT"

chmod 600 "$KUBECONFIG_OUT"
echo "Done. kubeconfig written to: $KUBECONFIG_OUT"
echo
echo "Use it explicitly:"
echo "  kubectl --kubeconfig=$KUBECONFIG_OUT get nodes"
echo
echo "Or link as default for plain 'kubectl':"
echo "  mkdir -p ~/.kube && ln -sf \"$KUBECONFIG_OUT\" ~/.kube/config"
