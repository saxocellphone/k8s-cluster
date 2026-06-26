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
Usage: $0 <llm|hipfire|image|gaming|off|status>

Modes:
  llm      Run the SGLang LLM backend and stop HIPFire/ComfyUI/gaming.
  hipfire  Run the HIPFire LLM backend and stop SGLang/ComfyUI/gaming.
  image    Run ComfyUI and stop the local LLM backends/gaming.
  gaming   Stop AI backends and start the GPU gaming workload if it exists.
  off      Stop AI backends and the GPU gaming workload if it exists.
  status   Show current GPU workload state.

This script time-shares the single AMD GPU on talos-gpu-01. Prefer the
mode-switcher UI/API (http://ai.k8s.home) which drains workloads, cooldowns,
and refuses switches while talos-gpu-01 is NotReady.

The Argo CD Application ignores Deployment replica drift for the AI workloads,
so manual mode changes are not reverted by self-heal. Set GAMING_NAMESPACE and
GAMING_DEPLOYMENT to override the gaming workload target.
EOF
}

gpu_node_ready() {
  local ready
  ready="$(kubectl --kubeconfig="$KUBECONFIG_FILE" get node talos-gpu-01 \
    -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)"
  [[ "$ready" == "True" ]]
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
  kubectl_ai get deploy llm hipfire comfyui
  echo
  echo "AI pods:"
  kubectl_ai get pods -o wide
  echo
  echo "AI services:"
  kubectl_ai get svc llm hipfire comfyui
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
  echo "  SGLang:  http://llm.k8s.home/v1"
  echo "  HIPFire: http://hipfire.k8s.home/v1"
  echo "  ComfyUI: http://comfyui.k8s.home"
  echo "  Gaming:  pair Moonlight with talos-gpu-01 once Wolf/Sunshine is deployed"
}

set_ai_mode() {
  local llm_replicas="$1"
  local hipfire_replicas="$2"
  local comfyui_replicas="$3"

  kubectl_ai scale deployment/llm --replicas="$llm_replicas"
  kubectl_ai scale deployment/hipfire --replicas="$hipfire_replicas"
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

require_gpu_node_for_start() {
  if ! gpu_node_ready; then
    echo "ERROR: talos-gpu-01 is not Ready — refusing to start a GPU workload." >&2
    echo "If ping works but talosctl hangs, power-cycle the Corsair; use mode 'off' only." >&2
    exit 1
  fi
}

case "${1:-}" in
  llm)
    require_gpu_node_for_start
    echo "Switching to LLM mode (prefer mode-switcher for drain+cooldown)..."
    set_gaming_replicas_if_present 0
    set_ai_mode 0 0 0
    echo "Waiting briefly for pods to terminate..."
    sleep 15
    set_ai_mode 1 0 0
    show_status
    ;;
  hipfire)
    require_gpu_node_for_start
    echo "Switching to HIPFire LLM mode (prefer mode-switcher for drain+cooldown)..."
    set_gaming_replicas_if_present 0
    set_ai_mode 0 0 0
    echo "Waiting briefly for pods to terminate..."
    sleep 15
    set_ai_mode 0 1 0

    show_status
    ;;
  image|comfyui)
    require_gpu_node_for_start
    echo "Switching to image mode..."
    set_gaming_replicas_if_present 0
    set_ai_mode 0 0 0
    sleep 15
    set_ai_mode 0 0 1
    show_status
    ;;
  gaming)
    require_gpu_node_for_start
    echo "Switching to gaming mode..."
    set_ai_mode 0 0 0
    sleep 15
    set_gaming_replicas_if_present 1
    show_status
    ;;

  off)
    echo "Stopping GPU workloads..."
    set_ai_mode 0 0 0
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
