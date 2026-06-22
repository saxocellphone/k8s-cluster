#!/usr/bin/env python3
import json
import os
import ssl
import urllib.error
import urllib.parse
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

AI_NAMESPACE = os.environ.get("AI_NAMESPACE", os.environ.get("NAMESPACE", "ai-inference"))
GAMING_NAMESPACE = os.environ.get("GAMING_NAMESPACE", "gaming")
GAMING_DEPLOYMENT = os.environ.get("GAMING_DEPLOYMENT", "wolf")
PORT = int(os.environ.get("PORT", "8080"))
TOKEN_PATH = "/var/run/secrets/kubernetes.io/serviceaccount/token"
CA_PATH = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
API_HOST = os.environ.get("KUBERNETES_SERVICE_HOST", "kubernetes.default.svc")
API_PORT = os.environ.get("KUBERNETES_SERVICE_PORT", "443")

WORKLOADS = {
    "llm": {"namespace": AI_NAMESPACE, "deployment": "llm", "label_selector": "app=llm"},
    "comfyui": {"namespace": AI_NAMESPACE, "deployment": "comfyui", "label_selector": "app=comfyui"},
    "wolf": {"namespace": GAMING_NAMESPACE, "deployment": GAMING_DEPLOYMENT, "label_selector": f"app={GAMING_DEPLOYMENT}"},
}


def apps_base(namespace):
    return f"https://{API_HOST}:{API_PORT}/apis/apps/v1/namespaces/{namespace}"


def core_base(namespace):
    return f"https://{API_HOST}:{API_PORT}/api/v1/namespaces/{namespace}"


def token():
    with open(TOKEN_PATH, "r", encoding="utf-8") as f:
        return f.read().strip()


def context():
    return ssl.create_default_context(cafile=CA_PATH)


def request_json(method, url, body=None):
    data = None if body is None else json.dumps(body).encode("utf-8")
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Authorization", f"Bearer {token()}")
    req.add_header("Accept", "application/json")
    if body is not None:
        req.add_header("Content-Type", "application/merge-patch+json")
    with urllib.request.urlopen(req, context=context(), timeout=10) as resp:
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


def deployment_status(name):
    workload = WORKLOADS[name]
    d = deployment(name)
    return {
        "namespace": workload["namespace"],
        "deployment": workload["deployment"],
        "replicas": d.get("spec", {}).get("replicas", 0),
        "ready": d.get("status", {}).get("readyReplicas", 0),
        "available": d.get("status", {}).get("availableReplicas", 0),
        "updated": d.get("status", {}).get("updatedReplicas", 0),
    }


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
    if active == ["llm"]:
        mode = "llm"
    elif active == ["comfyui"]:
        mode = "image"
    elif active == ["wolf"]:
        mode = "gaming"
    elif active:
        mode = "mixed"

    return {"mode": mode, "deployments": deployments, "pods": pod_rows}


def set_mode(mode):
    if mode == "llm":
        scale("comfyui", 0)
        scale("wolf", 0)
        scale("llm", 1)
    elif mode == "image":
        scale("llm", 0)
        scale("wolf", 0)
        scale("comfyui", 1)
    elif mode == "gaming":
        scale("llm", 0)
        scale("comfyui", 0)
        scale("wolf", 1)
    elif mode == "off":
        scale("llm", 0)
        scale("comfyui", 0)
        scale("wolf", 0)
    else:
        raise ValueError(f"unknown mode: {mode}")
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
    return f"""<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>AI Mode Switcher</title>
  <style>
    body {{ font-family: -apple-system, BlinkMacSystemFont, Segoe UI, sans-serif; margin: 2rem; max-width: 1040px; }}
    .mode {{ display: inline-block; padding: .25rem .6rem; border-radius: 999px; background: #eef; font-weight: 700; }}
    form {{ display: inline-block; margin: .4rem .4rem .4rem 0; }}
    button {{ font-size: 1rem; padding: .7rem 1rem; border-radius: .5rem; border: 1px solid #999; cursor: pointer; }}
    button.primary {{ background: #111827; color: white; }}
    table {{ border-collapse: collapse; width: 100%; margin-top: 1rem; }}
    th, td {{ border-bottom: 1px solid #ddd; text-align: left; padding: .55rem; }}
    code {{ background: #f5f5f5; padding: .1rem .25rem; border-radius: .25rem; }}
    .warn {{ background: #fff7df; border: 1px solid #f0d58c; padding: .8rem; border-radius: .5rem; }}
  </style>
</head>
<body>
  <h1>AI Mode Switcher</h1>
  <p>Current mode: <span class="mode">{s['mode']}</span></p>
  <form method="post" action="/mode/llm"><button class="primary">LLM mode</button></form>
  <form method="post" action="/mode/image"><button class="primary">Image mode</button></form>
  <form method="post" action="/mode/gaming"><button class="primary">Gaming mode</button></form>
  <form method="post" action="/mode/off"><button>Off</button></form>
  <form method="get" action="/"><button>Refresh</button></form>
  <div class="warn">
    This node has one schedulable GPU. LLM mode uses <code>llm.k8s.home</code>.
    Image mode uses <code>comfyui.k8s.home</code>. Gaming mode starts Wolf for Moonlight.
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
            if self.path == "/api/status":
                self.send(200, json.dumps(status()).encode("utf-8"), "application/json")
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
        except urllib.error.HTTPError as e:
            self.send(500, e.read(), "text/plain")
        except Exception as e:
            self.send(500, str(e).encode("utf-8"), "text/plain")

    def log_message(self, fmt, *args):
        print(f"{self.address_string()} - {fmt % args}")


if __name__ == "__main__":
    ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
