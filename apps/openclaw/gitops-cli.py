#!/usr/bin/env python3
"""CLI bridge: OpenClaw agent → github-app-mcp (Streamable HTTP).

OpenClaw 2026.3.x removed in-config MCP clients (`mcp` / `mcpServers` are
unrecognized keys). The GitHub App MCP sidecar still runs and is the only
safe write path (open PRs). This CLI re-exposes its tools on PATH so the
agent can `exec` them without a gateway MCP integration.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.request

DEFAULT_URL = "http://github-app-mcp.openclaw.svc.cluster.local/mcp"


class McpClient:
    def __init__(self, url: str, token: str):
        self.url = url.rstrip("/")
        self.token = token
        self.session: str | None = None
        self._id = 0

    def _next_id(self) -> int:
        self._id += 1
        return self._id

    def _post(self, payload: dict) -> dict:
        data = json.dumps(payload).encode()
        req = urllib.request.Request(self.url, data=data, method="POST")
        req.add_header("Content-Type", "application/json")
        req.add_header("Accept", "application/json, text/event-stream")
        if self.token:
            req.add_header("X-MCP-Token", self.token)
        if self.session:
            req.add_header("Mcp-Session-Id", self.session)
        try:
            with urllib.request.urlopen(req, timeout=120) as resp:  # nosemgrep
                sid = resp.headers.get("Mcp-Session-Id") or resp.headers.get(
                    "mcp-session-id"
                )
                if sid:
                    self.session = sid
                raw = resp.read().decode("utf-8", "replace")
        except urllib.error.HTTPError as e:
            detail = e.read().decode("utf-8", "replace")
            raise SystemExit(f"MCP HTTP {e.code}: {detail}") from None

        if not raw.strip():
            return {}
        # Streamable HTTP may return SSE frames or a single JSON object.
        if "data:" in raw:
            last = None
            for line in raw.splitlines():
                if line.startswith("data:"):
                    chunk = line[5:].strip()
                    if chunk and chunk != "[DONE]":
                        last = json.loads(chunk)
            if last is None:
                raise SystemExit(f"empty SSE payload: {raw[:300]}")
            return last
        return json.loads(raw)

    def initialize(self) -> None:
        res = self._post(
            {
                "jsonrpc": "2.0",
                "id": self._next_id(),
                "method": "initialize",
                "params": {
                    "protocolVersion": "2024-11-05",
                    "capabilities": {},
                    "clientInfo": {"name": "openclaw-gitops-cli", "version": "1"},
                },
            }
        )
        if "error" in res:
            raise SystemExit(f"initialize failed: {res['error']}")
        # Best-effort notification (some servers require it before tools/*).
        try:
            self._post(
                {"jsonrpc": "2.0", "method": "notifications/initialized", "params": {}}
            )
        except SystemExit:
            pass

    def call_tool(self, name: str, arguments: dict) -> object:
        self.initialize()
        res = self._post(
            {
                "jsonrpc": "2.0",
                "id": self._next_id(),
                "method": "tools/call",
                "params": {"name": name, "arguments": arguments},
            }
        )
        if "error" in res:
            raise SystemExit(f"tools/call {name} failed: {res['error']}")
        result = res.get("result", res)
        # FastMCP often wraps tool output in content blocks.
        if isinstance(result, dict) and "content" in result:
            texts = []
            for block in result.get("content") or []:
                if isinstance(block, dict) and block.get("type") == "text":
                    texts.append(block.get("text", ""))
            if texts:
                joined = "\n".join(texts)
                try:
                    return json.loads(joined)
                except json.JSONDecodeError:
                    return joined
        return result


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="gitops",
        description="GitOps helpers via github-app-mcp (open PRs for saxocellphone/k8s-cluster).",
    )
    parser.add_argument(
        "--url",
        default=os.environ.get("GITHUB_MCP_URL", DEFAULT_URL),
        help="MCP streamable HTTP endpoint",
    )
    parser.add_argument(
        "--token",
        default=os.environ.get("GITHUB_MCP_TOKEN", ""),
        help="X-MCP-Token (default: env GITHUB_MCP_TOKEN)",
    )
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_list = sub.add_parser("list-prs", help="List open pull requests")
    p_list.set_defaults(tool="list_open_prs", args_builder=lambda _: {})

    p_get = sub.add_parser("get-pr", help="Get one PR by number")
    p_get.add_argument("number", type=int)
    p_get.set_defaults(
        tool="get_pr", args_builder=lambda a: {"number": a.number}
    )

    p_read = sub.add_parser("read", help="Read a file from the repo on a ref")
    p_read.add_argument("path")
    p_read.add_argument("--ref", default="main")
    p_read.set_defaults(
        tool="read_file", args_builder=lambda a: {"path": a.path, "ref": a.ref}
    )

    p_ls = sub.add_parser("ls", help="List a directory in the repo")
    p_ls.add_argument("path", nargs="?", default="")
    p_ls.add_argument("--ref", default="main")
    p_ls.set_defaults(
        tool="list_dir", args_builder=lambda a: {"path": a.path, "ref": a.ref}
    )

    p_pr = sub.add_parser(
        "open-pr",
        help="Open a PR. Pass changes as JSON: "
        '[{"path":"apps/foo.yaml","content":"..."}] via --changes-file or stdin.',
    )
    p_pr.add_argument("--title", required=True)
    p_pr.add_argument("--body", default="")
    p_pr.add_argument("--branch", required=True, help="New feature branch name")
    p_pr.add_argument(
        "--changes-file",
        help="JSON file with list of {path, content}; default read stdin",
    )
    p_pr.set_defaults(tool="open_pr")

    args = parser.parse_args(argv)
    if not args.token:
        print(
            "GITHUB_MCP_TOKEN is unset; cannot auth to github-app-mcp",
            file=sys.stderr,
        )
        return 2

    client = McpClient(args.url, args.token)

    if args.cmd == "open-pr":
        if args.changes_file:
            with open(args.changes_file, encoding="utf-8") as f:
                changes = json.load(f)
        else:
            changes = json.load(sys.stdin)
        if not isinstance(changes, list) or not changes:
            print("changes must be a non-empty JSON list", file=sys.stderr)
            return 2
        out = client.call_tool(
            "open_pr",
            {
                "title": args.title,
                "body": args.body,
                "branch": args.branch,
                "changes": changes,
            },
        )
    else:
        out = client.call_tool(args.tool, args.args_builder(args))

    if isinstance(out, (dict, list)):
        json.dump(out, sys.stdout, indent=2)
        sys.stdout.write("\n")
    else:
        print(out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
