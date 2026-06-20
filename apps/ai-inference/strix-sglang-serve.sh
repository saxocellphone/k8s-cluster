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

ROOT=/models/strix-halo-sglang
VENV_DIR="$ROOT/venv"
SGLANG_DIR="$ROOT/sglang"
READY_MARKER="$ROOT/.ready-b0b8436f1c031caba61c4cadb10d22ba097cd960"

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
exec "$PYTHON" -m sglang.launch_server \
  --model-path "${SGLANG_MODEL:-Qwen/Qwen3.6-27B}" \
  --host 0.0.0.0 \
  --port "${SGLANG_PORT:-8080}" \
  --tp-size 1 \
  --trust-remote-code \
  --context-length "${SGLANG_CONTEXT_LENGTH:-8192}" \
  --mem-fraction-static "${SGLANG_MEM_FRACTION_STATIC:-0.96}" \
  --max-total-tokens "${SGLANG_MAX_TOTAL_TOKENS:-8192}" \
  --max-mamba-cache-size "${SGLANG_MAX_MAMBA_CACHE_SIZE:-16}" \
  --reasoning-parser qwen3 \
  --attention-backend triton \
  --disable-cuda-graph
