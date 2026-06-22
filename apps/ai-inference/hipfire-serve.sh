#!/bin/bash
set -euo pipefail

export HOME="${HIPFIRE_HOME:-/models/hipfire-home}"
export HIPFIRE_HOME="$HOME"
export PATH="$HOME/.hipfire/bin:/opt/rocm/bin:$PATH"
export HIP_VISIBLE_DEVICES=0
export HSA_OVERRIDE_GFX_VERSION=11.5.1
export HSA_ENABLE_SDMA=0

MODEL="${HIPFIRE_MODEL:-qwen3.6:27b}"

mkdir -p "$HOME/.hipfire/bin" "$HOME/.hipfire/models" "$HOME/.hipfire/cli"
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
