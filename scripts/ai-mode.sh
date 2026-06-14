#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
KUBECONFIG_FILE="${KUBECONFIG:-$REPO_DIR/kubeconfig}"
AI_NAMESPACE="ai-inference"
GAMING_NAMESPACE="${GAMING_NAMESPACE:-gaming}"
GAMING_DEPLOYMENT="${GAMING_DEPLOYMENT:-wolf}"

usage() {
  cat <<EOF
Usage: $0 <llm|image|gaming|off|status>

Modes:
  llm      Run the local LLM backend and stop ComfyUI/gaming.
  image    Run ComfyUI and stop the local LLM backend/gaming.
  gaming   Stop AI backends and start the GPU gaming workload if it exists.
  off      Stop AI backends and the GPU gaming workload if it exists.
  status   Show current GPU workload state.

This script time-shares the single AMD GPU on talos-gpu-01. The Argo CD
Application ignores Deployment replica drift for the AI workloads, so manual
mode changes are not reverted by self-heal. Set GAMING_NAMESPACE and
GAMING_DEPLOYMENT to override the future gaming workload target.
EOF
}

kubectl_ai() {
  kubectl --kubeconfig="$KUBECONFIG_FILE" -n "$AI_NAMESPACE" "$@"
}

kubectl_gaming() {
  kubectl --kubeconfig="$KUBECONFIG_FILE" -n "$GAMING_NAMESPACE" "$@"
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
  echo "AI deployments:"
  kubectl_ai get deploy llm comfyui
  echo
  echo "AI pods:"
  kubectl_ai get pods -o wide
  echo
  echo "AI services:"
  kubectl_ai get svc llm comfyui
  echo
  echo "Gaming deployment:"
  if kubectl_gaming get deployment "$GAMING_DEPLOYMENT" >/dev/null 2>&1; then
    kubectl_gaming get deployment "$GAMING_DEPLOYMENT"
    echo
    echo "Gaming pods:"
    kubectl_gaming get pods -l app="$GAMING_DEPLOYMENT" -o wide
  else
    echo "  $GAMING_NAMESPACE/$GAMING_DEPLOYMENT not found yet."
  fi
  echo
  echo "LAN URLs:"
  echo "  LLM:     http://llm.k8s.home/v1"
  echo "  ComfyUI: http://comfyui.k8s.home"
  echo "  Gaming:  pair Moonlight with talos-gpu-01 once Wolf/Sunshine is deployed"
}

set_ai_mode() {
  local llm_replicas="$1"
  local comfyui_replicas="$2"

  kubectl_ai scale deployment/llm --replicas="$llm_replicas"
  kubectl_ai scale deployment/comfyui --replicas="$comfyui_replicas"
}

set_gaming_replicas_if_present() {
  local replicas="$1"

  if kubectl_gaming get deployment "$GAMING_DEPLOYMENT" >/dev/null 2>&1; then
    kubectl_gaming scale deployment/"$GAMING_DEPLOYMENT" --replicas="$replicas"
  else
    echo "Gaming deployment $GAMING_NAMESPACE/$GAMING_DEPLOYMENT not found; skipping."
  fi
}

require_kubectl

case "${1:-}" in
  llm)
    echo "Switching to LLM mode..."
    set_gaming_replicas_if_present 0
    set_ai_mode 1 0
    show_status
    ;;
  image|comfyui)
    echo "Switching to image mode..."
    set_gaming_replicas_if_present 0
    set_ai_mode 0 1
    show_status
    ;;
  gaming)
    echo "Switching to gaming mode..."
    set_ai_mode 0 0
    set_gaming_replicas_if_present 1
    show_status
    ;;
  off)
    echo "Stopping GPU workloads..."
    set_ai_mode 0 0
    set_gaming_replicas_if_present 0
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
