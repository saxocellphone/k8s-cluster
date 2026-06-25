#!/usr/bin/env bash
# Minimal custom client against the cluster OpenCode server.
# Edge auth is Cloudflare Access (no OpenCode basic auth).
#
# Browser: open https://opencode.victornazzaro.com and complete Access login.
#
# CLI / automation (service token on the Access app):
#   export OPENCODE_URL=https://opencode.victornazzaro.com
#   export CF_ACCESS_CLIENT_ID=…
#   export CF_ACCESS_CLIENT_SECRET=…
#   ./reference-client.sh "Summarize /workspace"
#
# In-cluster only (no Access headers; Service is open on the pod network):
#   export OPENCODE_URL=http://opencode.opencode.svc.cluster.local:4096
#   ./reference-client.sh "…"
set -euo pipefail

URL="${OPENCODE_URL:?set OPENCODE_URL}"
PROMPT="${*:-List files under /workspace and describe the sandbox.}"

curl_auth=()
if [[ -n "${CF_ACCESS_CLIENT_ID:-}" && -n "${CF_ACCESS_CLIENT_SECRET:-}" ]]; then
  curl_auth+=(
    -H "CF-Access-Client-Id: ${CF_ACCESS_CLIENT_ID}"
    -H "CF-Access-Client-Secret: ${CF_ACCESS_CLIENT_SECRET}"
  )
fi

echo "== health =="
curl -fsS "${curl_auth[@]}" "${URL}/global/health"
echo

echo "== create session =="
SESSION_JSON=$(curl -fsS "${curl_auth[@]}" -H 'Content-Type: application/json' \
  -d '{"title":"reference-client"}' \
  "${URL}/session")
echo "$SESSION_JSON" | head -c 500
echo
SID=$(echo "$SESSION_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('id') or d.get('sessionID') or '')")
echo "session id: $SID"

echo "== async prompt (204 expected) =="
code=$(curl -sS -o /tmp/oc-msg.out -w '%{http_code}' "${curl_auth[@]}" \
  -H 'Content-Type: application/json' \
  -d "$(PROMPT="$PROMPT" python3 -c "import json,os; print(json.dumps({'parts':[{'type':'text','text':os.environ['PROMPT']}]}))")" \
  "${URL}/session/${SID}/prompt_async" || true)
echo "HTTP $code"
if [[ "$code" != "204" && "$code" != "200" ]]; then
  echo "prompt_async failed; trying sync /message"
  curl -fsS "${curl_auth[@]}" -H 'Content-Type: application/json' \
    -d "$(PROMPT="$PROMPT" python3 -c "import json,os; print(json.dumps({'parts':[{'type':'text','text':os.environ['PROMPT']}]}))")" \
    "${URL}/session/${SID}/message" | head -c 2000
  echo
fi

echo "== list messages (may be empty if still running) =="
curl -fsS "${curl_auth[@]}" "${URL}/session/${SID}/message?limit=5" | head -c 2000
echo
echo
echo "OpenAPI: ${URL}/doc"
echo "Attach TUI (needs Access cookie/token in front): opencode attach ${URL}"
