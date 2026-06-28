#!/usr/bin/env bash
# Serve full-precision (BF16) Qwen via Transformers + ROCm on gfx1151.
# HIPFire cannot serve unquantized weights; this is a separate OpenAI-compatible API.
#
# Default model is public on HF (no gated license click). Qwen2.5-27B-Instruct is
# gated and returns 401 without HF_TOKEN + accepted license — do not use it without a token.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
export HOME="${MODEL_HOME:-/models/qwen-full-home}"
export HF_HOME="${HF_HOME:-/models/huggingface}"
export TRANSFORMERS_CACHE="${TRANSFORMERS_CACHE:-$HF_HOME}"
export HUGGINGFACE_HUB_CACHE="${HUGGINGFACE_HUB_CACHE:-$HF_HOME}"
export HSA_OVERRIDE_GFX_VERSION="${HSA_OVERRIDE_GFX_VERSION:-11.5.1}"
export HSA_ENABLE_SDMA="${HSA_ENABLE_SDMA:-0}"
export HIP_VISIBLE_DEVICES="${HIP_VISIBLE_DEVICES:-0}"

if [[ -n "${HF_TOKEN:-}" ]]; then
  export HUGGING_FACE_HUB_TOKEN="$HF_TOKEN"
fi

MODEL_ID="${QWEN_FULL_MODEL:-Qwen/Qwen2.5-14B-Instruct}"
PORT="${PORT:-8000}"
mkdir -p "$HOME" "$HF_HOME" /models/qwen-full-weights

# Pin transformers <4.52: newer builds gate on importlib.metadata torch version and reject
# ROCm image's 2.4.0a0+git* ("Disabling PyTorch"). Qwen2.5 works on 4.51; Qwen3.5 needs newer.
# Broken botocore in the ROCm conda image breaks generation imports — strip AWS SDKs.
python3 - <<'PY'
import subprocess, sys

def run(args, check=True):
    subprocess.run(args, check=check)

run([sys.executable, "-m", "pip", "install", "-q", "--upgrade", "pip"])
run(
    [
        sys.executable,
        "-m",
        "pip",
        "uninstall",
        "-y",
        "botocore",
        "boto3",
        "s3transfer",
        "aiobotocore",
        "awscli",
    ],
    check=False,
)
run(
    [
        sys.executable,
        "-m",
        "pip",
        "install",
        "-q",
        "--upgrade-strategy",
        "only-if-needed",
        "transformers==4.51.3",
        "accelerate==1.6.0",
        "fastapi",
        "uvicorn[standard]",
        "huggingface_hub",
        "safetensors",
        "sentencepiece",
        "protobuf",
        "six",
    ]
)
run(
    [sys.executable, "-m", "pip", "uninstall", "-y", "botocore", "boto3", "s3transfer"],
    check=False,
)
PY

python3 - <<'PY'
import os
import sys
from pathlib import Path

# ROCm pytorch image reports 2.4.0a0+git…; some transformers builds treat that as <2.4 and
# disable the backend entirely ("PyTorch was not found"). Normalize before import.
import torch

_raw_tv = torch.__version__
if "a0" in _raw_tv or "+" in _raw_tv or "git" in _raw_tv:
    torch.__version__ = "2.4.0"
    print(f"normalized torch.__version__ {_raw_tv!r} -> {torch.__version__!r}", flush=True)

from fastapi import FastAPI
from pydantic import BaseModel, Field
from transformers import AutoModelForCausalLM, AutoTokenizer
import uvicorn

model_id = os.environ.get("QWEN_FULL_MODEL", "Qwen/Qwen2.5-14B-Instruct")
token_kw = {}
tok_val = (
    os.environ.get("HF_TOKEN")
    or os.environ.get("HUGGING_FACE_HUB_TOKEN")
    or os.environ.get("HUGGINGFACE_HUB_TOKEN")
)
if tok_val:
    token_kw["token"] = tok_val

local_dir = Path("/models/qwen-full-weights") / model_id.replace("/", "__")
port = int(os.environ.get("PORT", "8000"))
max_gpu = os.environ.get("QWEN_MAX_GPU_MEM", "88GiB")
max_cpu = os.environ.get("QWEN_MAX_CPU_MEM", "6GiB")

print(
    f"torch={_raw_tv} (api={torch.__version__}) cuda={torch.cuda.is_available()} devices={torch.cuda.device_count()}",
    flush=True,
)
if torch.cuda.is_available():
    print(f"device0={torch.cuda.get_device_name(0)}", flush=True)

print(f"Loading {model_id} (BF16, device_map=auto) cache={local_dir} …", flush=True)
local_dir.mkdir(parents=True, exist_ok=True)

# Require a complete-ish snapshot (config + at least one weight shard) — avoid segfault
# on half-downloaded trees from prior CrashLoops.
def _snapshot_usable(p: Path) -> bool:
    if not (p / "config.json").is_file():
        return False
    weights = list(p.glob("*.safetensors")) + list(p.glob("pytorch_model*.bin"))
    return len(weights) > 0

snapshot = None
if _snapshot_usable(local_dir):
    snapshot = str(local_dir)
    print(f"Using local snapshot {snapshot}", flush=True)
else:
    try:
        from huggingface_hub import snapshot_download

        print("snapshot_download …", flush=True)
        snapshot = snapshot_download(
            repo_id=model_id,
            local_dir=str(local_dir),
            **token_kw,
        )
        print(f"snapshot ready at {snapshot}", flush=True)
    except Exception as e:
        print(
            f"ERROR: cannot download {model_id}: {e}\n"
            "If the repo is gated, set HF_TOKEN and accept the model license on huggingface.co.\n"
            "Public alternatives: Qwen/Qwen2.5-14B-Instruct, Qwen/Qwen2.5-7B-Instruct.",
            file=sys.stderr,
            flush=True,
        )
        raise

load_from = snapshot or model_id

try:
    tok = AutoTokenizer.from_pretrained(
        load_from, trust_remote_code=True, local_files_only=bool(snapshot), **token_kw
    )
    # Prefer UMA FB; limit CPU spill so cgroup ~28–32Gi doesn't SIGSEGV/OOM on large models.
    # eager attn avoids sdpa+sliding-window warning path that was noisy on Qwen2.5.
    model = AutoModelForCausalLM.from_pretrained(
        load_from,
        torch_dtype=torch.bfloat16,
        device_map="auto",
        max_memory={0: max_gpu, "cpu": max_cpu},
        trust_remote_code=True,
        low_cpu_mem_usage=True,
        local_files_only=bool(snapshot),
        attn_implementation="eager",
        **token_kw,
    )
except Exception as e:
    print(f"ERROR loading model: {e}", file=sys.stderr, flush=True)
    raise

model.eval()
print("Model loaded.", flush=True)

app = FastAPI()


class Msg(BaseModel):
    role: str
    content: str


class ChatReq(BaseModel):
    model: str | None = None
    messages: list[Msg]
    max_tokens: int = Field(default=256, ge=1, le=8192)
    temperature: float = 0.7


@app.get("/health")
def health():
    return {"ok": True, "model": model_id}


@app.get("/v1/models")
def models():
    mid = model_id.replace("/", "-").lower()
    return {"data": [{"id": mid, "object": "model"}]}


@app.post("/v1/chat/completions")
def chat(req: ChatReq):
    if hasattr(tok, "apply_chat_template"):
        prompt = tok.apply_chat_template(
            [m.model_dump() for m in req.messages],
            tokenize=False,
            add_generation_prompt=True,
        )
    else:
        prompt = "\n".join(f"{m.role}: {m.content}" for m in req.messages) + "\nassistant:"
    inputs = tok(prompt, return_tensors="pt")
    # Prefer first parameter device when device_map=auto shards weights
    dev = next(model.parameters()).device
    inputs = {k: v.to(dev) for k, v in inputs.items()}
    with torch.inference_mode():
        out = model.generate(
            **inputs,
            max_new_tokens=req.max_tokens,
            do_sample=req.temperature > 0,
            temperature=max(req.temperature, 1e-5),
            pad_token_id=tok.eos_token_id,
        )
    text = tok.decode(out[0][inputs["input_ids"].shape[-1] :], skip_special_tokens=True)
    mid = model_id.replace("/", "-").lower()
    return {
        "id": "chatcmpl-qwen-full",
        "object": "chat.completion",
        "model": mid,
        "choices": [
            {
                "index": 0,
                "finish_reason": "stop",
                "message": {"role": "assistant", "content": text},
            }
        ],
    }


uvicorn.run(app, host="0.0.0.0", port=port)
PY
