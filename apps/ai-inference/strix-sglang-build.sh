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

ROOT=/models/strix-halo-sglang
REPO_DIR="$ROOT/strix-halo-sglang"
SGLANG_DIR="$ROOT/sglang"
VENV_DIR="$ROOT/venv"
READY_MARKER="$ROOT/.ready-b0b8436f1c031caba61c4cadb10d22ba097cd960-strix-hip-graph-v1"
CONSTRAINTS=/tmp/rocm-constraints.txt

if [[ -f "$READY_MARKER" ]]; then
  echo "Strix Halo SGLang runtime already built at $ROOT"
  exit 0
fi

rm -rf "$ROOT"
mkdir -p "$ROOT" /models/huggingface /models/tunableop

git clone --depth 1 https://github.com/JeremiahM37/strix-halo-sglang.git "$REPO_DIR"

git init "$SGLANG_DIR"
cd "$SGLANG_DIR"
git remote add origin https://github.com/sgl-project/sglang.git
git fetch --depth 1 origin b0b8436f1c031caba61c4cadb10d22ba097cd960
git checkout FETCH_HEAD

sed -i \
  -e 's|\["gfx942", "gfx950"\]|["gfx942", "gfx950", "gfx1151"]|' \
  -e "s|'gfx942' or 'gfx950'|'gfx942', 'gfx950', or 'gfx1151'|" \
  sgl-kernel/setup_rocm.py

for f in sgl-kernel/csrc/moe/moe_topk_softmax_kernels.cu sgl-kernel/csrc/moe/moe_topk_sigmoid_kernels.cu; do
  python3 - "$f" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text()
marker = "// added: gfx1151 wave32 kStrixWarp"
anchor = "#include <torch/all.h>"
if marker not in text:
    if anchor not in text:
        raise RuntimeError(f"anchor not found: {path}")
    text = re.sub(r"\bWARP_SIZE\b", "kStrixWarp", text)
    text = text.replace(anchor, anchor + "\n\n" + marker + "\nstatic constexpr int kStrixWarp = 32;", 1)
    path.write_text(text)
print("patched", path)
PY
done

python3 - <<'PY'
from pathlib import Path

path = Path('/models/strix-halo-sglang/sglang/python/sglang/srt/layers/layernorm.py')
old = '''elif _is_hip:
    try:
        from vllm._custom_ops import fused_add_rms_norm, rms_norm

        _has_vllm_rms_norm = True
    except ImportError:
        # Fallback: vllm not available, will use forward_native
        _has_vllm_rms_norm = False'''
new = '''elif _is_hip:
    try:
        from vllm._custom_ops import fused_add_rms_norm, rms_norm

        _has_vllm_rms_norm = True
        import os as _os
        if _os.environ.get('SGLANG_FORCE_NATIVE_LAYERNORM', '0') == '1':
            _has_vllm_rms_norm = False
    except ImportError:
        _has_vllm_rms_norm = False'''
text = path.read_text()
if old not in text:
    raise RuntimeError('layernorm hip block not found; upstream layout changed')
path.write_text(text.replace(old, new))
PY

python3 - <<'PY'
from pathlib import Path

path = Path('/models/strix-halo-sglang/sglang/python/sglang/srt/models/qwen3_next.py')
text = path.read_text()

if 'import os\n' not in text:
    text = text.replace('import enum\n', 'import enum\nimport os\n', 1)

old_qk = 'if self.alt_stream is not None and get_is_capture_mode():'
new_qk = '''if (
            self.alt_stream is not None
            and get_is_capture_mode()
            and not (
                _is_hip
                and os.environ.get("SGLANG_HIP_CAPTURE_SINGLE_STREAM", "1") == "1"
            )
        ):'''
if old_qk not in text:
    raise RuntimeError('qwen3_next q/k norm capture branch not found; upstream layout changed')
text = text.replace(old_qk, new_qk, 1)

old_gdn = '''if (
            self.alt_stream is not None
            and get_is_capture_mode()
            and seq_len < DUAL_STREAM_TOKEN_THRESHOLD
        ):'''
new_gdn = '''if (
            self.alt_stream is not None
            and get_is_capture_mode()
            and not (
                _is_hip
                and os.environ.get("SGLANG_HIP_CAPTURE_SINGLE_STREAM", "1") == "1"
            )
            and seq_len < DUAL_STREAM_TOKEN_THRESHOLD
        ):'''
if old_gdn not in text:
    raise RuntimeError('qwen3_next GDN capture branch not found; upstream layout changed')
text = text.replace(old_gdn, new_gdn, 1)

path.write_text(text)
PY

cp "$REPO_DIR/patches/awq_moe_rocm_repack.py" \
  "$SGLANG_DIR/python/sglang/srt/layers/quantization/awq/schemes/awq_moe_rocm_repack.py"

cd "$SGLANG_DIR/sgl-kernel"
AMDGPU_TARGET=gfx1151 python3 setup_rocm.py develop

cp -a /opt/venv "$VENV_DIR"
PYTHON="$VENV_DIR/bin/python3"
PIP="$PYTHON -m pip"

cd "$SGLANG_DIR"
cp python/pyproject_other.toml python/pyproject.toml
sed -i 's/compressed-tensors==0.15.0/compressed-tensors>=0.16.0/' python/pyproject.toml
"$PYTHON" -c "import torch, torchvision; open('$CONSTRAINTS','w').write(f'torch=={torch.__version__}\ntorchvision=={torchvision.__version__}\n')"
PIP_CONSTRAINT="$CONSTRAINTS" $PIP install -e 'python[srt_hip]' --no-build-isolation

"$PYTHON" - <<'PY'
import torch
import sgl_kernel
ops = [name for name in torch._C._dispatch_get_all_op_names() if name.startswith('sgl_kernel')]
print('torch', torch.__version__)
print('hip', getattr(torch.version, 'hip', None))
print('cuda_available', torch.cuda.is_available())
print('device_count', torch.cuda.device_count())
if torch.cuda.is_available():
    print('device', torch.cuda.get_device_name(0))
print('sgl_kernel_ops', len(ops))
if len(ops) < 40:
    raise SystemExit('too few sgl_kernel ops registered')
PY

touch "$READY_MARKER"
echo "Strix Halo SGLang runtime built successfully at $ROOT"
