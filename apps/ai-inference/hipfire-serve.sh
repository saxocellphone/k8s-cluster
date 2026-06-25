#!/bin/bash
set -euo pipefail

export HOME="${HIPFIRE_HOME:-/models/hipfire-home}"
export HIPFIRE_HOME="$HOME"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export TMPDIR="${TMPDIR:-$HOME/tmp}"
export HIP_USER_CACHE="${HIP_USER_CACHE:-$HOME/.cache/hip}"
# Daemon JIT cache defaults to $CWD/.hipfire_kernels; container CWD is often /
# (root-owned) which yields "failed to create cache dir: Permission denied".
export HIPFIRE_KERNEL_CACHE="${HIPFIRE_KERNEL_CACHE:-$HOME/.hipfire_kernels}"
export PATH="$HOME/.hipfire/bin:/opt/rocm/bin:$PATH"
export HIP_VISIBLE_DEVICES=0
export HSA_OVERRIDE_GFX_VERSION=11.5.1
export HSA_ENABLE_SDMA=0

MODEL="${HIPFIRE_MODEL:-qwen3.6:27b}"

# Prefer a writable home so any CWD-relative fallbacks still succeed.
cd "$HOME"

mkdir -p "$HOME/.hipfire/bin" "$HOME/.hipfire/models" "$HOME/.hipfire/cli" \
  "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME" "$TMPDIR" "$HIP_USER_CACHE" \
  "$HIPFIRE_KERNEL_CACHE"
for binary in daemon infer infer_hfq triattn_validate hipfire-tui; do
  if [[ -x "/opt/hipfire/bin/$binary" && ! -e "$HOME/.hipfire/bin/$binary" ]]; then
    ln -s "/opt/hipfire/bin/$binary" "$HOME/.hipfire/bin/$binary"
  fi
done
if [[ ! -e "$HOME/.hipfire/cli/index.ts" ]]; then
  cp -R /opt/hipfire/cli/. "$HOME/.hipfire/cli/"
fi

hipfire config set host 0.0.0.0
hipfire config set port 11435
hipfire config set default_model "$MODEL"
hipfire config set thinking off
hipfire config set max_think_tokens 0
hipfire config set max_tokens 256

if ! hipfire list | grep -F "$MODEL" >/dev/null 2>&1; then
  hipfire pull "$MODEL"
fi

exec hipfire serve 0.0.0.0:11435
