"""GitHub-App-backed MCP server (Streamable HTTP) for the OpenClaw cluster agent.

Why this exists
---------------
The agent's ONLY write path to the cluster is a GitHub pull request (GitOps —
Argo CD reconciles `main`, and direct cluster writes are reverted by selfHeal).
We deliberately authenticate as a **GitHub App** rather than a personal access
token: an App is its own machine identity, so it cannot inherit the operator's
admin privileges, and (paired with a "restrict push to main" ruleset) it
physically cannot push to or merge `main` — it can only open PRs the operator
merges.

App installation tokens live for ~1h. OpenClaw spawns MCP servers once and keeps
them alive for the gateway's lifetime, so a token captured at startup would go
stale. This service sidesteps that entirely: it runs as its own Streamable-HTTP
MCP server (OpenClaw connects by URL) and mints/refreshes the installation token
*internally, per call*. The agent never holds a token.

Tool surface is intentionally tiny — the local model serves only an 8k context
window, so a handful of purpose-built GitOps tools beats a generic 40-tool
GitHub server.

Config (env):
  GITHUB_APP_ID                 numeric App ID
  GITHUB_APP_INSTALLATION_ID    installation ID for the repo
  GITHUB_APP_PRIVATE_KEY        the App private key, PEM (multi-line)
  GITHUB_REPO                   "owner/name" (default saxocellphone/k8s-cluster)
  GITHUB_BASE_BRANCH            PR base branch (default "main")
  MCP_SHARED_TOKEN              shared secret; callers must send X-MCP-Token
  PORT                          listen port (default 9000)
"""

import base64
import json
import os
import time
import urllib.error
import urllib.request

import jwt  # PyJWT (RS256 signing of the App JWT)
import uvicorn
from mcp.server.fastmcp import FastMCP
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import JSONResponse

API = "https://api.github.com"

APP_ID = os.environ["GITHUB_APP_ID"]
INSTALLATION_ID = os.environ["GITHUB_APP_INSTALLATION_ID"]
PRIVATE_KEY = os.environ["GITHUB_APP_PRIVATE_KEY"]
REPO = os.environ.get("GITHUB_REPO", "saxocellphone/k8s-cluster")
BASE_BRANCH = os.environ.get("GITHUB_BASE_BRANCH", "main")
SHARED_TOKEN = os.environ.get("MCP_SHARED_TOKEN", "")
PORT = int(os.environ.get("PORT", "9000"))


class TokenManager:
    """Caches a GitHub App installation token, refreshing before it expires."""

    def __init__(self):
        self._token = None
        self._exp = 0.0

    def _mint(self):
        now = int(time.time())
        app_jwt = jwt.encode(
            {"iat": now - 60, "exp": now + 540, "iss": APP_ID},
            PRIVATE_KEY,
            algorithm="RS256",
        )
        body = _api(
            "POST",
            f"/app/installations/{INSTALLATION_ID}/access_tokens",
            bearer=app_jwt,
        )
        self._token = body["token"]
        # expires_at is ISO8601 ~1h out; refresh 5 min early using a local clock.
        self._exp = time.time() + 55 * 60

    def get(self):
        if not self._token or time.time() >= self._exp:
            self._mint()
        return self._token


def _api(method, path, token=None, bearer=None, payload=None):
    """Minimal GitHub REST call (stdlib only). Raises on HTTP error with detail."""
    url = path if path.startswith("http") else API + path
    data = json.dumps(payload).encode() if payload is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Accept", "application/vnd.github+json")
    req.add_header("X-GitHub-Api-Version", "2022-11-28")
    req.add_header("User-Agent", "openclaw-github-app-mcp")
    if bearer:
        req.add_header("Authorization", f"Bearer {bearer}")
    elif token:
        req.add_header("Authorization", f"token {token}")
    if data is not None:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:  # nosemgrep: python.lang.security.audit.dynamic-urllib-use-detected.dynamic-urllib-use-detected
            raw = resp.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        detail = e.read().decode("utf-8", "replace")
        raise RuntimeError(f"GitHub {method} {path} -> {e.code}: {detail}") from None


_tokens = TokenManager()


def gh(method, path, payload=None):
    return _api(method, path, token=_tokens.get(), payload=payload)


mcp = FastMCP("github-app", host="0.0.0.0", port=PORT)


def _as_json(value) -> str:
    """FastMCP streamable-HTTP often drops non-string tool returns into empty
    content blocks; always return JSON text so CLI/agent callers can parse it."""
    return json.dumps(value)


@mcp.tool()
def read_file(path: str, ref: str = BASE_BRANCH) -> str:
    """Read a file from the GitOps repo at `path` (repo-root relative) on branch
    or ref `ref` (default the base branch). Returns the decoded text. Use this to
    see a manifest's current contents before proposing an edit."""
    body = gh("GET", f"/repos/{REPO}/contents/{path}?ref={ref}")
    if isinstance(body, list):
        raise RuntimeError(f"{path} is a directory; use list_dir")
    content = base64.b64decode(body["content"]).decode("utf-8", "replace")
    return content


@mcp.tool()
def list_dir(path: str = "", ref: str = BASE_BRANCH) -> str:
    """List entries under directory `path` (repo-root relative, "" = repo root)
    on `ref`. Returns JSON list of {name, path, type} to help locate the right
    manifest before editing."""
    body = gh("GET", f"/repos/{REPO}/contents/{path}?ref={ref}")
    if not isinstance(body, list):
        raise RuntimeError(f"{path} is a file; use read_file")
    return _as_json(
        [{"name": e["name"], "path": e["path"], "type": e["type"]} for e in body]
    )


@mcp.tool()
def open_pr(title: str, body: str, branch: str, changes: list) -> str:
    """Open a pull request that edits one or more manifests.

    `branch` is a NEW feature branch name (e.g. "agent/bump-memos-mem"); it is
    created from the base branch. `changes` is a list of {"path": ..., "content":
    ...} objects giving each file's FULL new text. The PR targets the base branch
    for the operator to review and merge — this tool never pushes to or merges
    the base branch itself. Returns JSON {number, url}.
    """
    base = gh("GET", f"/repos/{REPO}/git/ref/heads/{BASE_BRANCH}")
    base_sha = base["object"]["sha"]
    try:
        gh(
            "POST",
            f"/repos/{REPO}/git/refs",
            {"ref": f"refs/heads/{branch}", "sha": base_sha},
        )
    except RuntimeError as e:
        if "Reference already exists" not in str(e):
            raise

    for ch in changes:
        path, new_text = ch["path"], ch["content"]
        sha = None
        try:
            cur = gh("GET", f"/repos/{REPO}/contents/{path}?ref={branch}")
            if isinstance(cur, dict):
                sha = cur.get("sha")
        except RuntimeError:
            sha = None  # new file
        put = {
            "message": f"{title}\n\n{path}",
            "content": base64.b64encode(new_text.encode()).decode(),
            "branch": branch,
        }
        if sha:
            put["sha"] = sha
        gh("PUT", f"/repos/{REPO}/contents/{path}", put)

    pr = gh(
        "POST",
        f"/repos/{REPO}/pulls",
        {"title": title, "head": branch, "base": BASE_BRANCH, "body": body},
    )
    return _as_json({"number": pr["number"], "url": pr["html_url"]})


@mcp.tool()
def list_open_prs() -> str:
    """List open pull requests on the repo as JSON [{number, title, url, head}].
    Use to check whether a change is already proposed before opening a duplicate."""
    body = gh("GET", f"/repos/{REPO}/pulls?state=open&per_page=50")
    return _as_json(
        [
            {
                "number": p["number"],
                "title": p["title"],
                "url": p["html_url"],
                "head": p["head"]["ref"],
            }
            for p in body
        ]
    )


@mcp.tool()
def get_pr(number: int) -> str:
    """Get one pull request's details plus its changed file paths (JSON)."""
    pr = gh("GET", f"/repos/{REPO}/pulls/{number}")
    files = gh("GET", f"/repos/{REPO}/pulls/{number}/files?per_page=100")
    return _as_json(
        {
            "number": pr["number"],
            "title": pr["title"],
            "url": pr["html_url"],
            "state": pr["state"],
            "mergeable": pr.get("mergeable"),
            "body": pr.get("body"),
            "files": [f["filename"] for f in files],
        }
    )


class Auth(BaseHTTPMiddleware):
    async def dispatch(self, request, call_next):
        if request.url.path == "/healthz":
            return JSONResponse({"ok": True})
        if SHARED_TOKEN and request.headers.get("x-mcp-token") != SHARED_TOKEN:
            return JSONResponse({"error": "unauthorized"}, status_code=401)
        return await call_next(request)


app = mcp.streamable_http_app()
app.add_middleware(Auth)

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=PORT)
