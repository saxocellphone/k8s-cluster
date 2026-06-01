#!/usr/bin/env python3
"""
notion-writer: deterministic OpenClaw cron -> Notion bridge.

OpenClaw's morning cron job POSTs its finished run payload here. This service
extracts the briefing text (the agent's final markdown), converts it to Notion
blocks with a fixed code path, creates a dated page under a parent page, and
sends a short Telegram notification with the page link. The agent is only
responsible for producing prose; the Notion write is fully deterministic, so it
can never "report success" while leaving the page empty.

Stdlib only (runs on python:3.x-slim, no pip install).

Env:
  NOTION_TOKEN            Notion internal integration secret (required)
  NOTION_PARENT_PAGE_ID   Parent page id for the daily briefings (required)
  NOTION_VERSION          Notion API version (default 2022-06-28)
  TELEGRAM_BOT_TOKEN      Optional; if set, sends a notification
  TELEGRAM_CHAT_ID        Optional; chat to notify
  WEBHOOK_TOKEN           Optional shared secret; if set, require Bearer match
  PAGE_TITLE_PREFIX       Default "Investment Briefing"
  TZ                      Used for the date in the page title
  PORT                    Default 8080
"""
import json
import os
import re
import sys
import urllib.request
import urllib.error
from datetime import datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

NOTION_TOKEN = os.environ.get("NOTION_TOKEN", "")
PARENT_PAGE_ID = os.environ.get("NOTION_PARENT_PAGE_ID", "")
NOTION_VERSION = os.environ.get("NOTION_VERSION", "2022-06-28")
TELEGRAM_BOT_TOKEN = os.environ.get("TELEGRAM_BOT_TOKEN", "")
TELEGRAM_CHAT_ID = os.environ.get("TELEGRAM_CHAT_ID", "")
WEBHOOK_TOKEN = os.environ.get("WEBHOOK_TOKEN", "")
TITLE_PREFIX = os.environ.get("PAGE_TITLE_PREFIX", "Investment Briefing")
PORT = int(os.environ.get("PORT", "8080"))

MAX_TEXT = 1900  # Notion rich_text content hard limit is 2000


def log(*a):
    print(*a, file=sys.stdout, flush=True)


# ---- Notion REST helpers ---------------------------------------------------

def notion(method, path, body=None):
    url = "https://api.notion.com/v1" + path
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method, headers={
        "Authorization": "Bearer " + NOTION_TOKEN,
        "Notion-Version": NOTION_VERSION,
        "Content-Type": "application/json",
    })
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.load(resp)


# ---- Markdown -> Notion blocks ---------------------------------------------

_LINK = re.compile(r"\[([^\]]+)\]\((https?://[^)\s]+)\)")
_BOLD = re.compile(r"\*\*([^*]+)\*\*")


def _chunk(s, n=MAX_TEXT):
    return [s[i:i + n] for i in range(0, len(s), n)] or [""]


def rich_text(text):
    """Build Notion rich_text from a line, handling [label](url) and **bold**."""
    out = []
    pos = 0
    # Handle links first; bold inside non-link spans.
    for m in _LINK.finditer(text):
        if m.start() > pos:
            out += _plain_or_bold(text[pos:m.start()])
        for piece in _chunk(m.group(1)):
            out.append({"type": "text", "text": {"content": piece, "link": {"url": m.group(2)}}})
        pos = m.end()
    if pos < len(text):
        out += _plain_or_bold(text[pos:])
    return out[:100] or [{"type": "text", "text": {"content": ""}}]


def _plain_or_bold(text):
    out = []
    pos = 0
    for m in _BOLD.finditer(text):
        if m.start() > pos:
            for piece in _chunk(text[pos:m.start()]):
                out.append({"type": "text", "text": {"content": piece}})
        for piece in _chunk(m.group(1)):
            out.append({"type": "text", "text": {"content": piece}, "annotations": {"bold": True}})
        pos = m.end()
    if pos < len(text):
        for piece in _chunk(text[pos:]):
            out.append({"type": "text", "text": {"content": piece}})
    return out


def _block(kind, text):
    return {"object": "block", "type": kind, kind: {"rich_text": rich_text(text)}}


def markdown_to_blocks(md):
    blocks = []
    for raw in md.replace("\r\n", "\n").split("\n"):
        line = raw.rstrip()
        s = line.strip()
        if not s:
            continue
        # Agents often wrap whole-line headings in bold (e.g. "**## Title**").
        # Strip a surrounding ** so the heading prefix is detected below.
        if s.startswith("**") and s.endswith("**") and len(s) > 4:
            inner = s[2:-2].strip()
            if inner.startswith("#"):
                s = inner
        if s in ("---", "***", "___"):
            blocks.append({"object": "block", "type": "divider", "divider": {}})
        elif s.startswith("### "):
            blocks.append(_block("heading_3", s[4:]))
        elif s.startswith("## "):
            blocks.append(_block("heading_2", s[3:]))
        elif s.startswith("# "):
            blocks.append(_block("heading_2", s[2:]))  # h1 -> h2 (Notion has no h1 in body)
        elif s.startswith("> "):
            blocks.append(_block("quote", s[2:]))
        elif re.match(r"^[-*+]\s+", s):
            blocks.append(_block("bulleted_list_item", re.sub(r"^[-*+]\s+", "", s)))
        elif re.match(r"^\d+[.)]\s+", s):
            blocks.append(_block("numbered_list_item", re.sub(r"^\d+[.)]\s+", "", s)))
        else:
            blocks.append(_block("paragraph", s))
    return blocks or [_block("paragraph", "(empty briefing)")]


# ---- payload text extraction -----------------------------------------------

PREFERRED_KEYS = ("finalText", "final_text", "text", "message", "summary",
                  "output", "reply", "result", "content", "body")


def extract_briefing(payload):
    """Pull the briefing markdown from an arbitrary cron webhook payload.

    Strategy: prefer known keys that carry the agent's final text, else fall
    back to the single longest string found anywhere in the structure.
    """
    if isinstance(payload, str):
        return payload
    best = ""
    # 1) preferred keys (deep)
    def walk_pref(node):
        nonlocal best
        if isinstance(node, dict):
            for k, v in node.items():
                if k in PREFERRED_KEYS and isinstance(v, str) and len(v) > len(best):
                    best = v
                walk_pref(v)
        elif isinstance(node, list):
            for x in node:
                walk_pref(x)
    walk_pref(payload)
    if len(best) >= 80:
        return best
    # 2) longest string anywhere
    longest = best
    def walk_all(node):
        nonlocal longest
        if isinstance(node, str):
            if len(node) > len(longest):
                longest = node
        elif isinstance(node, dict):
            for v in node.values():
                walk_all(v)
        elif isinstance(node, list):
            for x in node:
                walk_all(x)
    walk_all(payload)
    return longest


# ---- Telegram --------------------------------------------------------------

def telegram_notify(text):
    if not (TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID):
        return
    try:
        body = json.dumps({
            "chat_id": TELEGRAM_CHAT_ID,
            "text": text,
            "disable_web_page_preview": True,
        }).encode()
        req = urllib.request.Request(
            "https://api.telegram.org/bot%s/sendMessage" % TELEGRAM_BOT_TOKEN,
            data=body, method="POST", headers={"Content-Type": "application/json"})
        urllib.request.urlopen(req, timeout=20).read()
    except Exception as e:  # notification is best-effort
        log("telegram notify failed:", e)


# ---- core write ------------------------------------------------------------

def write_briefing(md):
    title = "%s \u2014 %s" % (TITLE_PREFIX, datetime.now().strftime("%Y-%m-%d"))
    blocks = markdown_to_blocks(md)
    page = notion("POST", "/pages", {
        "parent": {"page_id": PARENT_PAGE_ID},
        "properties": {"title": {"title": [{"text": {"content": title}}]}},
        "children": blocks[:90],
    })
    page_id = page["id"]
    # append any remaining blocks in batches of 90
    rest = blocks[90:]
    for i in range(0, len(rest), 90):
        notion("PATCH", "/blocks/%s/children" % page_id, {"children": rest[i:i + 90]})
    url = page.get("url", "https://www.notion.so/" + page_id.replace("-", ""))
    log("wrote page:", title, page_id, "blocks=%d" % len(blocks))
    return title, url, len(blocks)


# ---- HTTP ------------------------------------------------------------------

class Handler(BaseHTTPRequestHandler):
    def _send(self, code, obj):
        body = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *a):
        pass  # quiet default access logs

    def do_GET(self):
        if self.path in ("/healthz", "/health"):
            return self._send(200, {"ok": True})
        return self._send(404, {"error": "not found"})

    def do_POST(self):
        if WEBHOOK_TOKEN:
            auth = self.headers.get("Authorization", "")
            tok = auth[7:] if auth.startswith("Bearer ") else self.headers.get("x-openclaw-token", "")
            if tok != WEBHOOK_TOKEN:
                return self._send(401, {"error": "unauthorized"})
        try:
            n = int(self.headers.get("Content-Length", "0"))
            raw = self.rfile.read(n) if n else b""
            try:
                payload = json.loads(raw.decode("utf-8")) if raw else {}
            except Exception:
                payload = raw.decode("utf-8", "replace")
            md = (extract_briefing(payload) or "").strip()
            if len(md) < 40:
                log("payload had no usable briefing text; keys:",
                    list(payload.keys()) if isinstance(payload, dict) else type(payload).__name__)
                return self._send(422, {"error": "no briefing text in payload"})
            title, url, nblocks = write_briefing(md)
            telegram_notify("\U0001F4C8 Morning briefing saved to Notion: %s\n%s" % (title, url))
            return self._send(200, {"ok": True, "page_url": url, "blocks": nblocks})
        except urllib.error.HTTPError as e:
            detail = e.read().decode("utf-8", "replace")[:500]
            log("notion HTTP error:", e.code, detail)
            return self._send(502, {"error": "notion", "detail": detail})
        except Exception as e:
            log("error:", repr(e))
            return self._send(500, {"error": str(e)})


def main():
    missing = [k for k, v in (("NOTION_TOKEN", NOTION_TOKEN),
                              ("NOTION_PARENT_PAGE_ID", PARENT_PAGE_ID)) if not v]
    if missing:
        log("FATAL: missing env:", ", ".join(missing))
        sys.exit(1)
    log("notion-writer listening on :%d (telegram=%s, auth=%s)" % (
        PORT, bool(TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID), bool(WEBHOOK_TOKEN)))
    ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()


if __name__ == "__main__":
    main()
