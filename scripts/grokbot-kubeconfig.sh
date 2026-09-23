#!/bin/bash
# Write ./grokbot-kubeconfig.yaml: a read-only kubeconfig for grokbot, backed
# by the long-lived token of ServiceAccount grokbot/grokbot (cluster/grokbot-rbac.yaml).
#
# Rotate: kubectl --kubeconfig=./kubeconfig -n grokbot delete secret grokbot-token,
# let Argo re-create it, then re-run this script and redeploy the file.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
ADMIN_KUBECONFIG="${REPO_DIR}/kubeconfig"
OUT="${REPO_DIR}/grokbot-kubeconfig.yaml"
SERVER="${GROKBOT_API_SERVER:-$(kubectl --kubeconfig="$ADMIN_KUBECONFIG" config view --minify -o jsonpath='{.clusters[0].cluster.server}')}"

k() { kubectl --kubeconfig="$ADMIN_KUBECONFIG" -n grokbot "$@"; }

TOKEN="$(k get secret grokbot-token -o jsonpath='{.data.token}' | base64 -d)"
CA="$(k get secret grokbot-token -o jsonpath='{.data.ca\.crt}')"
if [[ -z "$TOKEN" || -z "$CA" ]]; then
  echo "ERROR: grokbot-token not populated yet; is cluster-resources synced?" >&2
  exit 1
fi

umask 077
cat >"$OUT" <<EOF
apiVersion: v1
kind: Config
clusters:
  - name: homelab
    cluster:
      server: ${SERVER}
      certificate-authority-data: ${CA}
users:
  - name: grokbot
    user:
      token: ${TOKEN}
contexts:
  - name: grokbot@homelab
    context:
      cluster: homelab
      user: grokbot
current-context: grokbot@homelab
EOF

echo "Wrote $OUT (server: $SERVER)"
echo "Verify read-only:"
echo "  kubectl --kubeconfig=$OUT auth can-i --list | head"
echo "  kubectl --kubeconfig=$OUT auth can-i delete pods -A   # expect: no"
