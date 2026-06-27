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

WORKLOADS = {
    "hipfire": {"namespace": AI_NAMESPACE, "deployment": "hipfire", "label_selector": "app=hipfire"},
    "comfyui": {"namespace": AI_NAMESPACE, "deployment": "comfyui", "label_selector": "app=comfyui"},
    "wolf": {"namespace": GAMING_NAMESPACE, "deployment": GAMING_DEPLOYMENT, "label_selector": f"app={GAMING_DEPLOYMENT}"},
}

# URL path segment → workload key (or None for off)
MODES = {
    "hipfire": "hipfire",
    "llm": "hipfire",  # legacy alias; SGLang removed
    "image": "comfyui",
    "gaming": "wolf",
    "off": None,
}


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
    if active == ["hipfire"]:
        mode = "hipfire"
    elif active == ["comfyui"]:
        mode = "image"
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
    rows = "".join(
        f"<tr><td>{p['namespace']}</td><td>{p['name']}</td><td>{p['app']}</td><td>{p['phase']}</td>"
        f"<td>{p['ready']}/{p['containers']}</td><td>{p['restarts']}</td><td>{p['node']}</td></tr>"
        for p in s["pods"]
    ) or '<tr><td colspan="7">No GPU workload pods running.</td></tr>'
    deploy_rows = "".join(
        f"<tr><td>{d['namespace']}</td><td>{name}</td><td>{d['deployment']}</td><td>{d['replicas']}</td>"
        f"<td>{d['ready']}</td><td>{d['available']}</td><td>{d['updated']}</td></tr>"
        for name, d in s["deployments"].items()
    )
    gn = s["gpuNode"]
    node_badge = "ok" if gn["ready"] else "bad"
    return f"""<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>AI Mode Switcher</title>
  <style>
    body {{ font-family: -apple-system, BlinkMacSystemFont, Segoe UI, sans-serif; margin: 2rem; max-width: 1040px; }}
    .mode {{ display: inline-block; padding: .25rem .6rem; border-radius: 999px; background: #eef; font-weight: 700; }}
    .ok {{ background: #dcfce7; }}
    .bad {{ background: #fee2e2; }}
    form {{ display: inline-block; margin: .4rem .4rem .4rem 0; }}
    button {{ font-size: 1rem; padding: .7rem 1rem; border-radius: .5rem; border: 1px solid #999; cursor: pointer; }}
    button.primary {{ background: #111827; color: white; }}
    button:disabled {{ opacity: .5; cursor: not-allowed; }}
    table {{ border-collapse: collapse; width: 100%; margin-top: 1rem; }}
    th, td {{ border-bottom: 1px solid #ddd; text-align: left; padding: .55rem; }}
    code {{ background: #f5f5f5; padding: .1rem .25rem; border-radius: .25rem; }}
    .warn {{ background: #fff7df; border: 1px solid #f0d58c; padding: .8rem; border-radius: .5rem; margin: 1rem 0; }}
  </style>
</head>
<body>
  <h1>AI Mode Switcher</h1>
  <p>Current mode: <span class="mode">{s['mode']}</span>
     · GPU node: <span class="mode {node_badge}">{gn['name']}: {gn['detail']}</span></p>
  <form method="post" action="/mode/hipfire"><button class="primary" {"disabled" if not gn["ready"] else ""}>HIPFire LLM mode</button></form>
  <form method="post" action="/mode/image"><button class="primary" {"disabled" if not gn["ready"] else ""}>Image mode</button></form>
  <form method="post" action="/mode/gaming"><button class="primary" {"disabled" if not gn["ready"] else ""}>Gaming mode</button></form>
  <form method="post" action="/mode/off"><button>Off</button></form>
  <form method="get" action="/"><button>Refresh</button></form>
  <div class="warn">
    One schedulable GPU on <code>{GPU_NODE}</code>. Switches <strong>drain</strong> other modes
    (timeout {DRAIN_TIMEOUT}s), wait <strong>{COOLDOWN_SEC}s</strong>, then start the target.
    Refuses scale-up while the GPU node is NotReady/unreachable.
    HIPFire: <code>hipfire.k8s.home</code> · Image: <code>comfyui.k8s.home</code> ·
    Gaming: Wolf/Moonlight. (SGLang / <code>llm</code> was removed.)
  </div>
  <h2>Deployments</h2>
  <table><thead><tr><th>Namespace</th><th>Name</th><th>Deployment</th><th>Desired</th><th>Ready</th><th>Available</th><th>Updated</th></tr></thead><tbody>{deploy_rows}</tbody></table>
  <h2>Pods</h2>
  <table><thead><tr><th>Namespace</th><th>Name</th><th>App</th><th>Phase</th><th>Ready</th><th>Restarts</th><th>Node</th></tr></thead><tbody>{rows}</tbody></table>
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
