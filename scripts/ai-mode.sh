#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
KUBECONFIG_FILE="${KUBECONFIG:-$REPO_DIR/kubeconfig}"
NAMESPACE="ai-inference"

usage() {
  cat <<EOF
Usage: $0 <llm|image|off|status>

Modes:
  llm     Run the local LLM backend and stop ComfyUI.
  image   Run ComfyUI and stop the local LLM backend.
  off     Stop both GPU backends.
  status  Show current AI backend state.

This script time-shares the single AMD GPU on talos-gpu-01. The Argo CD
Application ignores Deployment replica drift for these two workloads, so manual
mode changes are not reverted by self-heal.
EOF
}

kubectl_ai() {
  kubectl --kubeconfig="$KUBECONFIG_FILE" -n "$NAMESPACE" "$@"
}

require_kubectl() {
  if ! command -v kubectl >/dev/null; then
    echo "ERROR: kubectl not found" >&2
    exit 1
  fi
  if [[ ! -f "$KUBECONFIG_FILE" ]]; then
    echo "ERROR: kubeconfig not found at $KUBECONFIG_FILE" >&2
    exit 1
  fi
}

show_status() {
  echo "Deployments:"
  kubectl_ai get deploy llm comfyui
  echo
  echo "Pods:"
  kubectl_ai get pods -o wide
  echo
  echo "Services:"
  kubectl_ai get svc llm comfyui
  echo
  echo "LAN URLs:"
  echo "  LLM:     http://llm.k8s.home/v1"
  echo "  ComfyUI: http://comfyui.k8s.home"
}

set_mode() {
  local llm_replicas="$1"
  local comfyui_replicas="$2"

  kubectl_ai scale deployment/llm --replicas="$llm_replicas"
  kubectl_ai scale deployment/comfyui --replicas="$comfyui_replicas"
}

require_kubectl

case "${1:-}" in
  llm)
    echo "Switching to LLM mode..."
    set_mode 1 0
    show_status
    ;;
  image|comfyui)
    echo "Switching to image mode..."
    set_mode 0 1
    show_status
    ;;
  off)
    echo "Stopping AI GPU backends..."
    set_mode 0 0
    show_status
    ;;
  status)
    show_status
    ;;
  -h|--help|help|"")
    usage
    ;;
  *)
    echo "ERROR: unknown mode: $1" >&2
    usage >&2
    exit 1
    ;;
esac
