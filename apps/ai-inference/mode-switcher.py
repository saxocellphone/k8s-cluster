#!/usr/bin/env python3
"""Exclusive GPU mode switcher for talos-gpu-01 (Strix Halo).

Modes: hipfire (default LLM), image (ComfyUI), gaming (Wolf), off.
Serializes transitions: scale others to 0, wait until pods are gone, cooldown,
refuse switches while the GPU node is NotReady, then scale target to 1.
"""
import json
import os
import ssl
import time
import urllib.error
import urllib.parse
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

AI_NAMESPACE = os.environ.get("AI_NAMESPACE", os.environ.get("NAMESPACE", "ai-inference"))
GAMING_NAMESPACE = os.environ.get("GAMING_NAMESPACE", "gaming")
GAMING_DEPLOYMENT = os.environ.get("GAMING_DEPLOYMENT", "wolf")
PORT = int(os.environ.get("PORT", "8080"))
DRAIN_TIMEOUT = int(os.environ.get("DRAIN_TIMEOUT_SEC", "300"))
COOLDOWN_SEC = int(os.environ.get("COOLDOWN_SEC", "60"))
POLL_SEC = float(os.environ.get("POLL_SEC", "3"))
GPU_NODE = os.environ.get("GPU_NODE", "talos-gpu-01")

TOKEN_PATH = "/var/run/secrets/kubernetes.io/serviceaccount/token"
CA_PATH = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
API_HOST = os.environ.get("KUBERNETES_SERVICE_HOST", "kubernetes.default.svc")
API_PORT = os.environ.get("KUBERNETES_SERVICE_PORT", "443")

# Every Deployment that requests the single amd.com/gpu MUST be listed here, or
# it can silently hold the GPU and keep whichever mode you pick Pending. A
# switch drains all WORKLOADS except the target. Keep in sync with the RBAC
# resourceNames (mode-switcher-rbac.yaml) and the Argo ignoreDifferences on
# /spec/replicas (argocd/apps/ai-inference.yaml) — otherwise selfHeal fights
# the drain.
WORKLOADS = {
    "vllm": {"namespace": AI_NAMESPACE, "deployment": "vllm", "label_selector": "app=vllm"},
    "hipfire": {"namespace": AI_NAMESPACE, "deployment": "hipfire", "label_selector": "app=hipfire"},
    "comfyui": {"namespace": AI_NAMESPACE, "deployment": "comfyui", "label_selector": "app=comfyui"},
    "qwen-full": {"namespace": AI_NAMESPACE, "deployment": "qwen-full", "label_selector": "app=qwen-full"},
    "wolf": {"namespace": GAMING_NAMESPACE, "deployment": GAMING_DEPLOYMENT, "label_selector": f"app={GAMING_DEPLOYMENT}"},
}

# URL path segment → workload key to scale up (or None for off). A WORKLOADS
# entry with no MODE is drain-only: never a target, always scaled to 0.
MODES = {
    "vllm": "vllm",
    "hipfire": "hipfire",
    "image": "comfyui",
    "qwen": "qwen-full",
    "gaming": "wolf",
    "off": None,
}

# Presentation metadata for the web UI: mode path → (category, label, blurb).
# Category is the real workload class, shown as the card eyebrow.
MODE_UI = {
    "vllm": ("LLM", "vLLM", "OpenAI-compatible endpoint"),
    "hipfire": ("LLM", "HIPFire", "Alternate LLM backend"),
    "image": ("IMAGE", "ComfyUI", "Image generation"),
    "qwen": ("LLM", "Qwen Full", "BF16 full-weight model"),
    "gaming": ("GAME", "Gaming", "Wolf · Moonlight stream"),
    "off": ("IDLE", "Off", "Release the GPU"),
}
MODE_ORDER = ["vllm", "hipfire", "image", "qwen", "gaming", "off"]


def _phase_cls(phase):
    return {
        "Running": "ok", "Succeeded": "ok",
        "Pending": "warn", "Failed": "bad", "Unknown": "bad",
    }.get(phase or "", "idle")


def _state_pill(replicas, ready):
    if replicas and ready >= replicas:
        return '<span class="pill ok">running</span>'
    if replicas:
        return '<span class="pill warn">starting</span>'
    return '<span class="pill idle">stopped</span>'


def apps_base(namespace):
    return f"https://{API_HOST}:{API_PORT}/apis/apps/v1/namespaces/{namespace}"


def core_base(namespace=None):
    if namespace:
        return f"https://{API_HOST}:{API_PORT}/api/v1/namespaces/{namespace}"
    return f"https://{API_HOST}:{API_PORT}/api/v1"


def token():
    with open(TOKEN_PATH, "r", encoding="utf-8") as f:
        return f.read().strip()


def context():
    return ssl.create_default_context(cafile=CA_PATH)


def request_json(method, url, body=None, timeout=30):
    data = None if body is None else json.dumps(body).encode("utf-8")
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Authorization", f"Bearer {token()}")
    req.add_header("Accept", "application/json")
    if body is not None:
        req.add_header("Content-Type", "application/merge-patch+json")
    with urllib.request.urlopen(req, context=context(), timeout=timeout) as resp:  # nosemgrep
        raw = resp.read()
    return json.loads(raw.decode("utf-8")) if raw else {}


def scale(name, replicas):
    workload = WORKLOADS[name]
    return request_json(
        "PATCH",
        f"{apps_base(workload['namespace'])}/deployments/{workload['deployment']}/scale",
        {"spec": {"replicas": replicas}},
    )


def deployment(name):
    workload = WORKLOADS[name]
    return request_json(
        "GET",
        f"{apps_base(workload['namespace'])}/deployments/{workload['deployment']}",
    )


def pods(name):
    workload = WORKLOADS[name]
    query = urllib.parse.urlencode({"labelSelector": workload["label_selector"]})
    return request_json("GET", f"{core_base(workload['namespace'])}/pods?{query}")


def gpu_node_ready():
    try:
        node = request_json("GET", f"{core_base()}/nodes/{GPU_NODE}")
    except urllib.error.HTTPError as e:
        return False, f"cannot read node {GPU_NODE}: HTTP {e.code}"
    except Exception as e:
        return False, f"cannot read node {GPU_NODE}: {e}"

    for t in node.get("spec", {}).get("taints") or []:
        if t.get("key") in (
            "node.kubernetes.io/unreachable",
            "node.kubernetes.io/not-ready",
            "node.kubernetes.io/unschedulable",
        ):
            return False, f"{GPU_NODE} tainted {t.get('key')}={t.get('effect')}"

    ready = False
    for c in node.get("status", {}).get("conditions") or []:
        if c.get("type") == "Ready":
            ready = c.get("status") == "True"
            if not ready:
                return False, f"{GPU_NODE} Ready={c.get('status')} reason={c.get('reason')}"
            break
    if not ready:
        return False, f"{GPU_NODE} has no Ready=True condition"
    return True, f"{GPU_NODE} Ready"


def deployment_status(name):
    workload = WORKLOADS[name]
    d = deployment(name)
    return {
        "namespace": workload["namespace"],
        "deployment": workload["deployment"],
        "replicas": d.get("spec", {}).get("replicas", 0) or 0,
        "ready": d.get("status", {}).get("readyReplicas", 0) or 0,
        "available": d.get("status", {}).get("availableReplicas", 0) or 0,
        "updated": d.get("status", {}).get("updatedReplicas", 0) or 0,
    }


def any_workload_pods(names=None):
    names = names if names is not None else list(WORKLOADS)
    remaining = []
    for name in names:
        for pod in pods(name).get("items", []):
            phase = pod.get("status", {}).get("phase", "")
            if phase != "Succeeded":
                remaining.append(
                    f"{pod.get('metadata', {}).get('namespace')}/"
                    f"{pod.get('metadata', {}).get('name')} ({phase})"
                )
    return remaining


def wait_workloads_gone(names, timeout=DRAIN_TIMEOUT):
    deadline = time.time() + timeout
    while time.time() < deadline:
        left = any_workload_pods(names)
        if not left:
            return
        time.sleep(POLL_SEC)
    left = any_workload_pods(names)
    raise TimeoutError(
        f"timed out after {timeout}s waiting for pods to terminate: {', '.join(left[:8])}"
        + ("…" if len(left) > 8 else "")
    )


def status():
    deployments = {name: deployment_status(name) for name in WORKLOADS}
    pod_rows = []
    for name in WORKLOADS:
        for pod in pods(name).get("items", []):
            statuses = pod.get("status", {}).get("containerStatuses", [])
            init_statuses = pod.get("status", {}).get("initContainerStatuses", [])
            restarts = sum(s.get("restartCount", 0) for s in statuses + init_statuses)
            pod_rows.append({
                "namespace": pod.get("metadata", {}).get("namespace"),
                "name": pod.get("metadata", {}).get("name"),
                "app": pod.get("metadata", {}).get("labels", {}).get("app"),
                "phase": pod.get("status", {}).get("phase"),
                "ready": sum(1 for s in statuses if s.get("ready")),
                "containers": len(statuses),
                "restarts": restarts,
                "node": pod.get("spec", {}).get("nodeName", ""),
            })

    active = [name for name, d in deployments.items() if d["replicas"] > 0]
    mode = "off"
    if active == ["vllm"]:
        mode = "vllm"
    elif active == ["hipfire"]:
        mode = "hipfire"
    elif active == ["comfyui"]:
        mode = "image"
    elif active == ["qwen-full"]:
        mode = "qwen"
    elif active == ["wolf"]:
        mode = "gaming"
    elif active:
        mode = "mixed"

    node_ok, node_detail = gpu_node_ready()
    return {
        "mode": mode,
        "deployments": deployments,
        "pods": pod_rows,
        "gpuNode": {"name": GPU_NODE, "ready": node_ok, "detail": node_detail},
        "policy": {
            "drainTimeoutSec": DRAIN_TIMEOUT,
            "cooldownSec": COOLDOWN_SEC,
        },
    }


def set_mode(mode):
    if mode not in MODES:
        raise ValueError(f"unknown mode: {mode}")

    target = MODES[mode]
    if target is not None:
        ok, detail = gpu_node_ready()
        if not ok:
            raise RuntimeError(
                f"refusing to enable {mode}: GPU node not ready ({detail}). "
                "Power-cycle talos-gpu-01 if Talos API is wedged (ping works, talosctl hangs)."
            )

    others = [n for n in WORKLOADS if n != target]
    for name in others:
        scale(name, 0)
    wait_workloads_gone(others)

    if COOLDOWN_SEC > 0 and target is not None:
        time.sleep(COOLDOWN_SEC)

    if target is not None:
        ok, detail = gpu_node_ready()
        if not ok:
            raise RuntimeError(
                f"refusing to scale up {target}: GPU node not ready after drain ({detail})"
            )
        scale(target, 1)
    return status()


def html():
    s = status()
    gn = s["gpuNode"]
    node_ok = gn["ready"]

    # Hero: which single workload currently holds the GPU.
    if s["mode"] == "off":
        occ_cat, occ_name, occ_state = "AVAILABLE", "Idle", "idle"
    elif s["mode"] in MODE_UI:
        occ_cat, occ_name, _ = MODE_UI[s["mode"]]
        occ_state = "live"
    else:  # mixed / unexpected
        occ_cat, occ_name, occ_state = "CONTENDED", s["mode"].title(), "warn"

    cards = ""
    for key in MODE_ORDER:
        cat, label, blurb = MODE_UI[key]
        active = s["mode"] == key
        disabled = not node_ok and key != "off"
        lamp = "on" if active else ("off" if disabled else "idle")
        cls = "card" + (" is-active" if active else "") + (" is-disabled" if disabled else "")
        if active:
            tag = '<span class="tag live">active</span>'
        elif disabled:
            tag = '<span class="tag muted">locked</span>'
        else:
            tag = '<span class="tag">select</span>'
        cards += (
            f'<form method="post" action="/mode/{key}">'
            f'<button class="{cls}"{" disabled" if disabled else ""}>'
            f'<span class="card-top"><span class="lamp {lamp}"></span>'
            f'<span class="eyebrow">{cat}</span></span>'
            f'<span class="card-name">{label}</span>'
            f'<span class="card-blurb">{blurb}</span>{tag}'
            f'</button></form>'
        )

    deploy_rows = "".join(
        f'<tr><td class="mono strong">{d["deployment"]}</td>'
        f'<td class="mono muted">{d["namespace"]}</td>'
        f'<td class="num">{d["replicas"]}</td>'
        f'<td class="num {"ok-t" if d["replicas"] and d["ready"] >= d["replicas"] else ("warn-t" if d["replicas"] else "muted")}">{d["ready"]}</td>'
        f'<td>{_state_pill(d["replicas"], d["ready"])}</td></tr>'
        for name, d in s["deployments"].items()
    )

    pod_rows = "".join(
        f'<tr><td class="mono strong">{p["name"]}</td>'
        f'<td class="mono muted">{p["app"] or "—"}</td>'
        f'<td><span class="pill {_phase_cls(p["phase"])}">{p["phase"] or "—"}</span></td>'
        f'<td class="num {"warn-t" if p["ready"] < p["containers"] else "ok-t"}">{p["ready"]}/{p["containers"]}</td>'
        f'<td class="num {"warn-t" if p["restarts"] else "muted"}">{p["restarts"]}</td>'
        f'<td class="mono muted">{p["node"] or "—"}</td></tr>'
        for p in s["pods"]
    ) or '<tr><td colspan="6" class="empty">No GPU workloads running — pick a mode above.</td></tr>'

    node_lamp = "on" if node_ok else "off"
    alert = "" if node_ok else (
        f'<div class="alert">GPU node unavailable — <span class="mono">{gn["detail"]}</span>. '
        f'Modes are locked until it recovers.</div>'
    )

    return f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>GPU Control · {GPU_NODE}</title>
  <style>
    :root {{
      --bg:#0e1117; --panel:#151a24; --panel2:#1b212e; --line:#262d3b;
      --txt:#e8ecf4; --mut:#8b93a6; --amber:#ff9d42; --amber-dim:rgba(255,157,66,.12);
      --grn:#37d9a0; --ylw:#ffce5c; --red:#ff6f6f; --idle:#5b6577;
      --mono:ui-monospace,"SF Mono","JetBrains Mono",Menlo,Consolas,monospace;
      --sans:system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;
    }}
    * {{ box-sizing:border-box; }}
    html {{ -webkit-text-size-adjust:100%; }}
    body {{ margin:0; color:var(--txt); font-family:var(--sans);
      background:radial-gradient(1100px 560px at 82% -12%, #18233a 0%, var(--bg) 58%);
      -webkit-font-smoothing:antialiased; }}
    a {{ color:inherit; }}
    .wrap {{ max-width:1080px; margin:0 auto; padding:clamp(1rem,3.2vw,2.6rem); }}
    .eyebrow {{ font-family:var(--mono); font-size:.66rem; letter-spacing:.2em;
      text-transform:uppercase; color:var(--mut); }}
    .mono {{ font-family:var(--mono); }}
    .muted {{ color:var(--mut); }} .strong {{ color:var(--txt); }}

    /* masthead */
    header {{ display:flex; align-items:center; justify-content:space-between; gap:1rem; flex-wrap:wrap; }}
    .brand h1 {{ margin:.15rem 0 0; font-size:clamp(1.35rem,3.2vw,1.9rem); font-weight:800;
      letter-spacing:-.02em; }}
    .brand h1 span {{ color:var(--amber); }}
    .nodechip {{ display:inline-flex; align-items:center; gap:.5rem; font-family:var(--mono);
      font-size:.74rem; padding:.5rem .8rem; border:1px solid var(--line); border-radius:.6rem;
      background:var(--panel); color:var(--mut); }}

    /* GPU bay — signature */
    .bay {{ position:relative; margin:1.4rem 0 1.8rem; padding:clamp(1.1rem,3vw,1.7rem);
      border:1px solid var(--line); border-radius:1rem; background:
        linear-gradient(var(--amber),var(--amber)) 0 0/16px 2px no-repeat,
        linear-gradient(var(--amber),var(--amber)) 0 0/2px 16px no-repeat,
        linear-gradient(var(--amber),var(--amber)) 100% 0/16px 2px no-repeat,
        linear-gradient(var(--amber),var(--amber)) 100% 0/2px 16px no-repeat,
        linear-gradient(var(--amber),var(--amber)) 0 100%/16px 2px no-repeat,
        linear-gradient(var(--amber),var(--amber)) 0 100%/2px 16px no-repeat,
        linear-gradient(var(--amber),var(--amber)) 100% 100%/16px 2px no-repeat,
        linear-gradient(var(--amber),var(--amber)) 100% 100%/2px 16px no-repeat,
        linear-gradient(180deg,var(--panel2),var(--panel));
      display:flex; align-items:center; justify-content:space-between; gap:1.4rem; flex-wrap:wrap; }}
    .bay .slot {{ display:flex; align-items:center; gap:1.1rem; min-width:0; }}
    .bay .glyph {{ flex:none; width:54px; height:54px; border-radius:.7rem; border:1px solid var(--line);
      display:grid; place-items:center; font-family:var(--mono); font-weight:700; font-size:1.5rem;
      color:var(--amber); background:var(--amber-dim); }}
    .occ-name {{ font-size:clamp(1.5rem,4.5vw,2.15rem); font-weight:800; letter-spacing:-.02em;
      line-height:1.05; }}
    .occ-name.idle {{ color:var(--mut); }} .occ-name.warn {{ color:var(--ylw); }}
    .bay .meta {{ display:flex; flex-direction:column; align-items:flex-end; gap:.5rem;
      font-family:var(--mono); font-size:.76rem; color:var(--mut); }}
    .status {{ display:inline-flex; align-items:center; gap:.5rem; }}

    /* status lamps */
    .lamp {{ width:9px; height:9px; border-radius:50%; flex:none; background:var(--idle);
      box-shadow:0 0 0 0 rgba(0,0,0,0); }}
    .lamp.on {{ background:var(--amber); box-shadow:0 0 10px 1px var(--amber); animation:pulse 2.4s ease-in-out infinite; }}
    .lamp.off {{ background:var(--red); box-shadow:0 0 8px 0 rgba(255,111,111,.6); }}
    .lamp.idle {{ background:var(--idle); }}
    @keyframes pulse {{ 0%,100%{{ opacity:1; }} 50%{{ opacity:.45; }} }}

    .alert {{ margin:-.6rem 0 1.4rem; padding:.7rem .9rem; border-radius:.6rem; font-size:.86rem;
      background:rgba(255,111,111,.1); border:1px solid rgba(255,111,111,.35); color:#ffd9d9; }}

    /* section label */
    .lbl {{ display:flex; align-items:baseline; gap:.7rem; margin:1.8rem 0 .85rem; }}
    .lbl h2 {{ margin:0; font-size:.95rem; font-weight:700; letter-spacing:.01em; }}
    .lbl .rule {{ flex:1; height:1px; background:var(--line); }}

    /* mode grid */
    .grid {{ display:grid; gap:.7rem; grid-template-columns:repeat(auto-fill,minmax(158px,1fr)); }}
    .grid form {{ margin:0; }}
    .card {{ width:100%; text-align:left; cursor:pointer; color:var(--txt); font-family:var(--sans);
      display:flex; flex-direction:column; gap:.32rem; min-height:118px; padding:.9rem .95rem;
      border:1px solid var(--line); border-radius:.8rem; background:var(--panel);
      transition:transform .12s ease, border-color .12s ease, background .12s ease; }}
    .card:hover {{ transform:translateY(-2px); border-color:#38425a; }}
    .card:focus-visible {{ outline:2px solid var(--amber); outline-offset:2px; }}
    .card-top {{ display:flex; align-items:center; gap:.45rem; }}
    .card-name {{ font-size:1.12rem; font-weight:750; letter-spacing:-.01em; }}
    .card-blurb {{ font-size:.78rem; color:var(--mut); flex:1; }}
    .tag {{ align-self:flex-start; font-family:var(--mono); font-size:.62rem; letter-spacing:.14em;
      text-transform:uppercase; padding:.2rem .45rem; border-radius:.35rem; color:var(--mut);
      background:rgba(255,255,255,.04); border:1px solid var(--line); }}
    .tag.live {{ color:#1c1206; background:var(--amber); border-color:var(--amber); font-weight:700; }}
    .card.is-active {{ border-color:var(--amber); background:linear-gradient(180deg,var(--amber-dim),var(--panel)); }}
    .card.is-disabled {{ opacity:.42; cursor:not-allowed; }}
    .card.is-disabled:hover {{ transform:none; border-color:var(--line); }}

    /* data tables */
    .panel {{ border:1px solid var(--line); border-radius:.8rem; background:var(--panel); overflow:hidden; }}
    .scroll {{ overflow-x:auto; }}
    table {{ border-collapse:collapse; width:100%; font-size:.86rem; }}
    thead th {{ text-align:left; padding:.6rem .85rem; font-family:var(--mono); font-weight:500;
      font-size:.66rem; letter-spacing:.14em; text-transform:uppercase; color:var(--mut);
      border-bottom:1px solid var(--line); white-space:nowrap; }}
    tbody td {{ padding:.6rem .85rem; border-bottom:1px solid rgba(38,45,59,.6); white-space:nowrap; }}
    tbody tr:last-child td {{ border-bottom:0; }}
    .num {{ text-align:right; font-family:var(--mono); }}
    .ok-t {{ color:var(--grn); }} .warn-t {{ color:var(--ylw); }}
    .empty {{ text-align:center; color:var(--mut); padding:1.4rem; }}
    .pill {{ font-family:var(--mono); font-size:.68rem; letter-spacing:.05em; padding:.18rem .5rem;
      border-radius:999px; border:1px solid var(--line); color:var(--mut); }}
    .pill.ok {{ color:var(--grn); border-color:rgba(55,217,160,.35); background:rgba(55,217,160,.08); }}
    .pill.warn {{ color:var(--ylw); border-color:rgba(255,206,92,.35); background:rgba(255,206,92,.08); }}
    .pill.bad {{ color:var(--red); border-color:rgba(255,111,111,.35); background:rgba(255,111,111,.08); }}
    .pill.idle {{ color:var(--idle); }}

    /* footer */
    footer {{ margin-top:1.9rem; display:flex; align-items:center; justify-content:space-between;
      gap:1rem; flex-wrap:wrap; font-size:.8rem; color:var(--mut); }}
    .policy {{ font-family:var(--mono); font-size:.74rem; }}
    .policy b {{ color:var(--amber); font-weight:600; }}
    .ghost {{ font-family:var(--mono); font-size:.76rem; color:var(--txt); text-decoration:none;
      padding:.5rem .85rem; border:1px solid var(--line); border-radius:.6rem; background:var(--panel);
      transition:border-color .12s ease; }}
    .ghost:hover {{ border-color:#38425a; }}

    @media (max-width:560px) {{
      .bay {{ flex-direction:column; align-items:flex-start; }}
      .bay .meta {{ align-items:flex-start; }}
    }}
    @media (prefers-reduced-motion:reduce) {{
      * {{ animation:none !important; transition:none !important; }}
    }}
  </style>
</head>
<body>
  <div class="wrap">
    <header>
      <div class="brand">
        <div class="eyebrow">{GPU_NODE} · Strix Halo · single GPU</div>
        <h1>GPU <span>Control</span></h1>
      </div>
      <div class="nodechip"><span class="lamp {node_lamp}"></span>{gn['detail']}</div>
    </header>

    {alert}

    <section class="bay" aria-label="Current GPU occupant">
      <div class="slot">
        <div class="glyph">{occ_cat[:1]}</div>
        <div>
          <div class="eyebrow">Now holding the GPU · {occ_cat}</div>
          <div class="occ-name {occ_state}">{occ_name}</div>
        </div>
      </div>
      <div class="meta">
        <span class="status"><span class="lamp {node_lamp}"></span>node {"ready" if node_ok else "down"}</span>
        <span>drain {DRAIN_TIMEOUT}s · cooldown {COOLDOWN_SEC}s</span>
      </div>
    </section>

    <div class="lbl"><h2>Select mode</h2><div class="rule"></div></div>
    <div class="grid">{cards}</div>

    <div class="lbl"><h2>Workloads</h2><div class="rule"></div></div>
    <div class="panel scroll">
      <table>
        <thead><tr><th>Deployment</th><th>Namespace</th><th class="num">Desired</th><th class="num">Ready</th><th>State</th></tr></thead>
        <tbody>{deploy_rows}</tbody>
      </table>
    </div>

    <div class="lbl"><h2>Pods</h2><div class="rule"></div></div>
    <div class="panel scroll">
      <table>
        <thead><tr><th>Pod</th><th>App</th><th>Phase</th><th class="num">Ready</th><th class="num">Restarts</th><th>Node</th></tr></thead>
        <tbody>{pod_rows}</tbody>
      </table>
    </div>

    <footer>
      <span class="policy">One switch <b>drains</b> every other GPU workload, waits, then starts the target.</span>
      <a class="ghost" href="/">↻ Refresh</a>
    </footer>
  </div>
</body>
</html>""".encode("utf-8")


class Handler(BaseHTTPRequestHandler):
    def send(self, code, body, content_type="text/html; charset=utf-8"):
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        try:
            if self.path == "/api/status" or self.path.startswith("/api/status?"):
                self.send(200, json.dumps(status()).encode("utf-8"), "application/json")
            elif self.path == "/healthz":
                self.send(200, b"ok", "text/plain")
            elif self.path == "/" or self.path.startswith("/?"):
                self.send(200, html())
            else:
                self.send(404, b"not found", "text/plain")
        except Exception as e:
            self.send(500, str(e).encode("utf-8"), "text/plain")

    def do_POST(self):
        try:
            if self.path.startswith("/mode/"):
                mode = self.path.rsplit("/", 1)[-1]
                set_mode(mode)
                self.send_response(303)
                self.send_header("Location", "/")
                self.end_headers()
            else:
                self.send(404, b"not found", "text/plain")
        except ValueError as e:
            self.send(400, str(e).encode("utf-8"), "text/plain")
        except TimeoutError as e:
            self.send(504, str(e).encode("utf-8"), "text/plain")
        except RuntimeError as e:
            self.send(503, str(e).encode("utf-8"), "text/plain")
        except urllib.error.HTTPError as e:
            self.send(500, e.read(), "text/plain")
        except Exception as e:
            self.send(500, str(e).encode("utf-8"), "text/plain")

    def log_message(self, fmt, *args):
        print(f"{self.address_string()} - {fmt % args}")


if __name__ == "__main__":
    ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
