#!/usr/bin/env bash
# Attach local OpenCode CLI to the in-cluster server (never use bare localhost —
# that is only reachable *inside* the pod).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
KUBECONFIG_FILE="${KUBECONFIG:-$REPO_DIR/kubeconfig}"

URL="${OPENCODE_URL:-https://opencode.victornazzaro.com}"
# Prefer explicit env, else load Basic auth from cluster secret.
USER="${OPENCODE_SERVER_USERNAME:-${OPENCODE_USER:-}}"
PASS="${OPENCODE_SERVER_PASSWORD:-${OPENCODE_PASS:-}}"

if [[ -z "$USER" || -z "$PASS" ]]; then
  if [[ ! -f "$KUBECONFIG_FILE" ]]; then
    echo "ERROR: set OPENCODE_SERVER_USERNAME/PASSWORD or provide $KUBECONFIG_FILE" >&2
    exit 1
  fi
  USER="$(kubectl --kubeconfig="$KUBECONFIG_FILE" -n opencode get secret opencode-secrets \
    -o jsonpath='{.data.OPENCODE_SERVER_USERNAME}' | base64 -d)"
  PASS="$(kubectl --kubeconfig="$KUBECONFIG_FILE" -n opencode get secret opencode-secrets \
    -o jsonpath='{.data.OPENCODE_SERVER_PASSWORD}' | base64 -d)"
fi

# Optional: OPENCODE_URL=http://opencode.k8s.home for LAN (needs DNS → ingress LB)
echo "Attaching to $URL as $USER …" >&2
exec opencode attach "$URL" -u "$USER" -p "$PASS" "$@"
