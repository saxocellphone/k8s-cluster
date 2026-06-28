#!/usr/bin/env bash
# Minimal custom client against the cluster OpenCode server.
# Auth: OpenCode HTTP Basic (OPENCODE_SERVER_USERNAME / OPENCODE_SERVER_PASSWORD).
#
# Browser: https://opencode.victornazzaro.com (basic auth prompt)
# CLI:     ./scripts/opencode-attach.sh
#      or: opencode attach https://opencode.victornazzaro.com -u opencode -p '…'
# LAN:     OPENCODE_URL=http://opencode.k8s.home ./scripts/opencode-attach.sh
# Do NOT use http://localhost:4096 on your laptop — that only works inside the pod.
#
#   export OPENCODE_URL=https://opencode.victornazzaro.com
#   export OPENCODE_USER=opencode
#   export OPENCODE_PASSWORD='…'
#   ./reference-client.sh "List files under /workspace"
#
# In-cluster (still needs basic auth if password is set on the server):
#   export OPENCODE_URL=http://opencode.opencode.svc.cluster.local:4096
set -euo pipefail

URL="${OPENCODE_URL:?set OPENCODE_URL}"
USER="${OPENCODE_USER:-opencode}"
PASS="${OPENCODE_PASSWORD:-${OPENCODE_SERVER_PASSWORD:?set OPENCODE_PASSWORD or OPENCODE_SERVER_PASSWORD}}"
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
SID=$(echo "$SESSION_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('id') or d.get('sessionID') or '')")
echo "session id: $SID"

echo "== async prompt (204 expected) =="
code=$(curl -sS -o /tmp/oc-msg.out -w '%{http_code}' "${auth[@]}" \
  -H 'Content-Type: application/json' \
  -d "$(PROMPT="$PROMPT" python3 -c "import json,os; print(json.dumps({'parts':[{'type':'text','text':os.environ['PROMPT']}]}))")" \
  "${URL}/session/${SID}/prompt_async" || true)
echo "HTTP $code"
if [[ "$code" != "204" && "$code" != "200" ]]; then
  echo "prompt_async failed; trying sync /message"
  curl -fsS "${auth[@]}" -H 'Content-Type: application/json' \
    -d "$(PROMPT="$PROMPT" python3 -c "import json,os; print(json.dumps({'parts':[{'type':'text','text':os.environ['PROMPT']}]}))")" \
    "${URL}/session/${SID}/message" | head -c 2000
  echo
fi

echo "== list messages (may be empty if still running) =="
curl -fsS "${auth[@]}" "${URL}/session/${SID}/message?limit=5" | head -c 2000
echo
echo
echo "OpenAPI: ${URL}/doc"
echo "Attach TUI: opencode attach ${URL} -u ${USER} -p '***'"
