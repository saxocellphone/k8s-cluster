#!/usr/bin/env bash
# Minimal custom client against a remote OpenCode server (Phase 5 reference).
# Usage:
#   export OPENCODE_URL=https://opencode.victornazzaro.com
#   export OPENCODE_USER=opencode
#   export OPENCODE_PASSWORD='…'   # or OPENCODE_SERVER_PASSWORD
#   ./reference-client.sh "Summarize the repo layout under /workspace"
set -euo pipefail

URL="${OPENCODE_URL:?set OPENCODE_URL}"
USER="${OPENCODE_USER:-opencode}"
PASS="${OPENCODE_PASSWORD:-${OPENCODE_SERVER_PASSWORD:?set OPENCODE_PASSWORD}}"
PROMPT="${*:-List files under /workspace and describe the sandbox.}"

auth=(-u "${USER}:${PASS}")

echo "== health =="
curl -fsS "${auth[@]}" "${URL}/global/health"
echo

echo "== create session =="
SESSION_JSON=$(curl -fsS "${auth[@]}" -H 'Content-Type: application/json' \
  -d '{"title":"reference-client"}' \
  "${URL}/session")
echo "$SESSION_JSON" | head -c 500
echo
SID=$(echo "$SESSION_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id') or json.load(open('/dev/stdin')))" 2>/dev/null || true)
if [[ -z "${SID:-}" ]]; then
  SID=$(echo "$SESSION_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('id') or d.get('sessionID') or d.get('session',{}).get('id',''))")
fi
echo "session id: $SID"

echo "== async prompt (204 expected) =="
# Prefer async so flaky mobile networks do not hold one HTTP call for the whole turn.
code=$(curl -sS -o /tmp/oc-msg.out -w '%{http_code}' "${auth[@]}" \
  -H 'Content-Type: application/json' \
  -d "$(python3 -c "import json; print(json.dumps({'parts':[{'type':'text','text':'''$PROMPT'''}]}))")" \
  "${URL}/session/${SID}/prompt_async" || true)
echo "HTTP $code"
if [[ "$code" != "204" && "$code" != "200" ]]; then
  echo "prompt_async failed; trying sync /message"
  curl -fsS "${auth[@]}" -H 'Content-Type: application/json' \
    -d "$(python3 -c "import json; print(json.dumps({'parts':[{'type':'text','text':'''$PROMPT'''}]}))")" \
    "${URL}/session/${SID}/message" | head -c 2000
  echo
fi

echo "== list messages (may be empty if still running) =="
curl -fsS "${auth[@]}" "${URL}/session/${SID}/message?limit=5" | head -c 2000
echo
echo
echo "OpenAPI: ${URL}/doc"
echo "Attach TUI: opencode attach ${URL} -u ${USER} -p '***'"
