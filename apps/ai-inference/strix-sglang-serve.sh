#!/bin/bash
set -euo pipefail

export SGLANG_FORCE_NATIVE_LAYERNORM=1
export HF_HOME=/models/huggingface
export HF_HUB_CACHE=/models/huggingface/hub
export PYTORCH_ROCM_ARCH=gfx1151
export PYTORCH_TUNABLEOP_ENABLED=1
export PYTORCH_TUNABLEOP_FILENAME=/models/tunableop/tunableop_results.csv
export HIP_FORCE_DEV_KERNARG=1
export TORCH_ROCM_AOTRITON_ENABLE_EXPERIMENTAL=1
export HIP_VISIBLE_DEVICES=0
export HSA_OVERRIDE_GFX_VERSION=11.5.1
export HSA_ENABLE_SDMA=0
export SGLANG_HIP_CAPTURE_SINGLE_STREAM="${SGLANG_HIP_CAPTURE_SINGLE_STREAM:-1}"

ROOT=/models/strix-halo-sglang
VENV_DIR="$ROOT/venv"
SGLANG_DIR="$ROOT/sglang"
READY_MARKER="$ROOT/.ready-b0b8436f1c031caba61c4cadb10d22ba097cd960-strix-hip-graph-v1"

if [[ ! -f "$READY_MARKER" ]]; then
  echo "SGLang runtime is not built. Missing $READY_MARKER" >&2
  exit 1
fi

mkdir -p /models/tunableop
PYTHON="$VENV_DIR/bin/python3"
if [[ ! -x "$PYTHON" ]]; then
  echo "SGLang Python runtime missing at $PYTHON" >&2
  exit 1
fi
cd "$SGLANG_DIR"

BASE_ARGS=(
  -m sglang.launch_server
  --model-path "${SGLANG_MODEL:-Qwen/Qwen3.6-27B}"
  --host 0.0.0.0
  --port "${SGLANG_PORT:-8080}"
  --tp-size 1
  --trust-remote-code
  --context-length "${SGLANG_CONTEXT_LENGTH:-32768}"
  --mem-fraction-static "${SGLANG_MEM_FRACTION_STATIC:-0.96}"
  --max-total-tokens "${SGLANG_MAX_TOTAL_TOKENS:-32768}"
  --max-mamba-cache-size "${SGLANG_MAX_MAMBA_CACHE_SIZE:-16}"
  --reasoning-parser qwen3
  --attention-backend triton
)

graph_args() {
  case "${SGLANG_CUDA_GRAPH_MODE:-decode}" in
    off|disabled|false|0)
      printf '%s\0' \
        --cuda-graph-backend-decode disabled \
        --cuda-graph-backend-prefill disabled
      ;;
    decode)
      printf '%s\0' \
        --cuda-graph-backend-decode full \
        --cuda-graph-bs-decode "${SGLANG_CUDA_GRAPH_BS_DECODE:-1}" \
        --cuda-graph-backend-prefill disabled
      ;;
    full)
      printf '%s\0' \
        --cuda-graph-backend-decode full \
        --cuda-graph-bs-decode "${SGLANG_CUDA_GRAPH_BS_DECODE:-1}" \
        --cuda-graph-backend-prefill tc_piecewise
      ;;
    *)
      echo "Unknown SGLANG_CUDA_GRAPH_MODE=${SGLANG_CUDA_GRAPH_MODE}; expected decode, full, or off" >&2
      exit 2
      ;;
  esac
}

run_server() {
  local -a args
  mapfile -d '' -t args < <(graph_args)
  "$PYTHON" "${BASE_ARGS[@]}" "${args[@]}"
}

run_server_graphs_off() {
  "$PYTHON" "${BASE_ARGS[@]}" \
    --cuda-graph-backend-decode disabled \
    --cuda-graph-backend-prefill disabled
}

if [[ "${SGLANG_CUDA_GRAPH_MODE:-decode}" =~ ^(off|disabled|false|0)$ ]]; then
  run_server_graphs_off
  exit $?
fi

if [[ "${SGLANG_CUDA_GRAPH_AUTO_FALLBACK:-1}" != "1" ]]; then
  run_server
  exit $?
fi

LOG=/tmp/sglang-startup.log
set +e
run_server 2>&1 | tee "$LOG"
status=${PIPESTATUS[0]}
set -e

if [[ $status -ne 0 ]] && grep -E 'Capture cuda graph failed|CUDA graph capture failed|Expected iter != ops_\.end' "$LOG" >/dev/null; then
  echo "SGLang graph capture failed; restarting with CUDA/HIP graphs disabled." >&2
  run_server_graphs_off
  exit $?
fi

exit "$status"
