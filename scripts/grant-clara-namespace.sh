#!/bin/bash
#
# grant-clara-namespace.sh
# -------------------------
# Creates a namespace (if it doesn't exist) and binds the `clara`
# ServiceAccount as namespace-admin via the existing `clara-namespace-admin`
# ClusterRole. Use this whenever Clara needs a new namespace.
#
# The namespace name must start with "clara" as a safety guard.
#
# Usage:
#   ./scripts/grant-clara-namespace.sh <namespace-name>
#
# Examples:
#   ./scripts/grant-clara-namespace.sh clara-dev
#   ./scripts/grant-clara-namespace.sh clara-staging

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
KUBECONFIG_FILE="${REPO_DIR}/kubeconfig"

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <namespace-name>" >&2
  echo "  namespace must start with 'clara'" >&2
  exit 2
fi

NS="$1"

if [[ "$NS" != clara* ]]; then
  echo "error: namespace '$NS' does not start with 'clara'" >&2
  exit 1
fi

export KUBECONFIG="$KUBECONFIG_FILE"

echo "=== Ensuring namespace $NS exists ==="
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -

echo "=== Creating RoleBinding for clara SA in $NS ==="
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: clara-admin
  namespace: $NS
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: clara-namespace-admin
subjects:
  - kind: ServiceAccount
    name: clara
    namespace: clara
EOF

echo "=== Done. Clara can now operate in namespace '$NS' ==="
echo "  kubectl --kubeconfig=clara-kubeconfig.yaml -n $NS get pods"
