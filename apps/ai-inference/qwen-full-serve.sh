#!/usr/bin/env bash
# Serve full-precision (BF16) Qwen via Transformers + ROCm on gfx1151.
# HIPFire cannot serve unquantized weights; this is a separate OpenAI-compatible API.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
export HOME="${MODEL_HOME:-/models/qwen-full-home}"
export HF_HOME="${HF_HOME:-/models/huggingface}"
export TRANSFORMERS_CACHE="${TRANSFORMERS_CACHE:-$HF_HOME}"
export HSA_OVERRIDE_GFX_VERSION="${HSA_OVERRIDE_GFX_VERSION:-11.5.1}"
export HSA_ENABLE_SDMA="${HSA_ENABLE_SDMA:-0}"
export HIP_VISIBLE_DEVICES="${HIP_VISIBLE_DEVICES:-0}"

MODEL_ID="${QWEN_FULL_MODEL:-Qwen/Qwen2.5-27B-Instruct}"
PORT="${PORT:-8000}"
mkdir -p "$HOME" "$HF_HOME" /models/qwen-full-weights

python3 - <<'PY'
import os, subprocess, sys
pkgs = ["transformers", "accelerate", "fastapi", "uvicorn[standard]", "huggingface_hub", "safetensors", "sentencepiece", "protobuf"]
subprocess.check_call([sys.executable, "-m", "pip", "install", "-q", "--upgrade", "pip"])
subprocess.check_call([sys.executable, "-m", "pip", "install", "-q", *pkgs])
PY

python3 - <<PY
import os
from pathlib import Path

import torch
from fastapi import FastAPI
from pydantic import BaseModel, Field
from transformers import AutoModelForCausalLM, AutoTokenizer
import uvicorn

model_id = os.environ.get("QWEN_FULL_MODEL", "Qwen/Qwen2.5-27B-Instruct")
local_dir = Path("/models/qwen-full-weights") / model_id.replace("/", "__")
port = int(os.environ.get("PORT", "8000"))

print(f"torch={torch.__version__} cuda={torch.cuda.is_available()} devices={torch.cuda.device_count()}", flush=True)
if torch.cuda.is_available():
    print(f"device0={torch.cuda.get_device_name(0)}", flush=True)

print(f"Loading {model_id} (BF16, device_map=auto) into {local_dir} …", flush=True)
local_dir.mkdir(parents=True, exist_ok=True)

tok = AutoTokenizer.from_pretrained(model_id, trust_remote_code=True, cache_dir=str(local_dir))
model = AutoModelForCausalLM.from_pretrained(
    model_id,
    torch_dtype=torch.bfloat16,
    device_map="auto",
    trust_remote_code=True,
    cache_dir=str(local_dir),
    low_cpu_mem_usage=True,
)
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
    # Minimal chat template
    if hasattr(tok, "apply_chat_template"):
        prompt = tok.apply_chat_template(
            [m.model_dump() for m in req.messages],
            tokenize=False,
            add_generation_prompt=True,
        )
    else:
        prompt = "\n".join(f"{m.role}: {m.content}" for m in req.messages) + "\nassistant:"
    inputs = tok(prompt, return_tensors="pt")
    inputs = {k: v.to(model.device) for k, v in inputs.items()}
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
        "choices": [{"index": 0, "finish_reason": "stop", "message": {"role": "assistant", "content": text}}],
    }


uvicorn.run(app, host="0.0.0.0", port=port)
PY
