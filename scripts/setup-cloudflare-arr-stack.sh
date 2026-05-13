#!/bin/bash
#
# setup-cloudflare-arr-stack.sh
# ------------------------------
# Idempotent-ish bootstrap for exposing the *arr stack via Cloudflare Tunnel
# behind Cloudflare Access. Performs four operations against the CF API:
#
#   1. Appends 3 ingress rules to the existing `homelab` tunnel:
#        sonarr.victornazzaro.com   -> sonarr.torrenting.svc:8989
#        radarr.victornazzaro.com   -> radarr.torrenting.svc:7878
#        qbit.victornazzaro.com     -> qbittorrent.torrenting.svc:8080
#      (preserves all existing rules; keeps the catch-all 404 last)
#
#      Note: prowlarr and readarr were originally exposed too but are
#      no longer; prowlarr is admin-only so doesn't warrant a public
#      hostname, and readarr was removed from the cluster entirely.
#
#   2. Creates an orange-clouded CNAME in Cloudflare DNS for each new
#      hostname, pointing at <tunnel-id>.cfargotunnel.com.
#
#   3. Creates one shared Access service token ('arr-stack-nzb360')
#      that nzb360 (and any other CF-Access-aware client) can use to
#      authenticate without a browser PIN.
#
#   4. Creates a single Access application ('Arr Stack') with policies:
#        a) Service Auth allow (the service token) -- ordered first
#        b) Email allow (operator allow-list)
#      attached to all 5 hostnames.
#
# Designed to be re-readable as documentation of what's configured in
# the CF account, not to be re-run blindly. Re-running will produce
# duplicate Access apps / service tokens / DNS records and 4xx errors
# on the duplicates -- read those errors and decide what to do.
#
# Required env:
#   CF_API_TOKEN   Cloudflare API token with these scopes:
#                    Account: Cloudflare Tunnel: Edit
#                    Account: Access: Apps and Policies: Edit
#                    Account: Access: Service Tokens: Edit
#                    Account: Account Settings: Read
#                    Zone:    DNS: Edit (victornazzaro.com)
#                    Zone:    Zone: Read (victornazzaro.com)
#
# Optional env (auto-discovered from the token if unset):
#   CF_ACCOUNT_ID  Cloudflare account ID
#   CF_ZONE_ID     Zone ID for victornazzaro.com
#   CF_TUNNEL_ID   ID of the `homelab` tunnel
#
# Required positional arg:
#   $1  Email address to add to the Access allow-list.
#
# Usage:
#   CF_API_TOKEN=cfut_xxx ./scripts/setup-cloudflare-arr-stack.sh you@example.com

set -euo pipefail

# ----- Args / env --------------------------------------------------------

if [[ $# -lt 1 ]]; then
  echo "usage: CF_API_TOKEN=... $0 <email-for-access-allow-list>" >&2
  exit 2
fi
EMAIL="$1"
: "${CF_API_TOKEN:?CF_API_TOKEN must be set}"

API="https://api.cloudflare.com/client/v4"
DOMAIN="victornazzaro.com"

# 3 hostnames + their cluster service URLs.
declare -a HOSTNAMES=(
  "sonarr.${DOMAIN}|http://sonarr.torrenting.svc.cluster.local:8989"
  "radarr.${DOMAIN}|http://radarr.torrenting.svc.cluster.local:7878"
  "qbit.${DOMAIN}|http://qbittorrent.torrenting.svc.cluster.local:8080"
)

# ----- Helpers -----------------------------------------------------------

cf() {
  # cf <method> <path> [<json-body>]
  local method="$1" path="$2" body="${3:-}"
  if [[ -n "$body" ]]; then
    curl -fsS -X "$method" \
      -H "Authorization: Bearer $CF_API_TOKEN" \
      -H "Content-Type: application/json" \
      --data "$body" \
      "${API}${path}"
  else
    curl -fsS -X "$method" \
      -H "Authorization: Bearer $CF_API_TOKEN" \
      "${API}${path}"
  fi
}

j() { python3 -c "import sys,json; print(json.load(sys.stdin)$1)"; }

# ----- Discover IDs ------------------------------------------------------

echo "=== Verifying token ==="
cf GET "/user/tokens/verify" >/dev/null && echo "token ok"

if [[ -z "${CF_ACCOUNT_ID:-}" ]]; then
  CF_ACCOUNT_ID=$(cf GET "/accounts" | j '["result"][0]["id"]')
fi
echo "account: $CF_ACCOUNT_ID"

if [[ -z "${CF_ZONE_ID:-}" ]]; then
  CF_ZONE_ID=$(cf GET "/zones?name=${DOMAIN}" | j '["result"][0]["id"]')
fi
echo "zone:    $CF_ZONE_ID"

if [[ -z "${CF_TUNNEL_ID:-}" ]]; then
  CF_TUNNEL_ID=$(cf GET "/accounts/${CF_ACCOUNT_ID}/cfd_tunnel?is_deleted=false&name=homelab" \
    | j '["result"][0]["id"]')
fi
echo "tunnel:  $CF_TUNNEL_ID"

# ----- 1) Update tunnel ingress ------------------------------------------

echo
echo "=== Step 1: appending tunnel ingress rules ==="

CURRENT_CONFIG=$(cf GET "/accounts/${CF_ACCOUNT_ID}/cfd_tunnel/${CF_TUNNEL_ID}/configurations")
NEW_CONFIG=$(python3 <<PY
import json, sys
cur = json.loads('''$CURRENT_CONFIG''')
config = cur["result"]["config"] or {"ingress": []}
ingress = list(config.get("ingress", []))

# Strip the trailing catch-all 404 (we'll re-append it at the end).
trailing = []
while ingress and "hostname" not in ingress[-1]:
    trailing.insert(0, ingress.pop())

existing_hostnames = {r.get("hostname") for r in ingress}
new_rules = [
    {"hostname": h, "service": svc}
    for h, svc in [tuple(x.split("|", 1)) for x in """$(printf '%s\n' "${HOSTNAMES[@]}")""".strip().splitlines()]
    if h not in existing_hostnames
]
print(json.dumps({"hostnames_added": [r["hostname"] for r in new_rules]}, indent=2), file=sys.stderr)

ingress.extend(new_rules)
ingress.extend(trailing) if trailing else ingress.append({"service": "http_status:404"})
config["ingress"] = ingress

print(json.dumps({"config": config}))
PY
)

cf PUT "/accounts/${CF_ACCOUNT_ID}/cfd_tunnel/${CF_TUNNEL_ID}/configurations" "$NEW_CONFIG" \
  | j '["success"]' | xargs -I{} echo "tunnel config update: {}"

# ----- 2) Create DNS CNAMEs ----------------------------------------------

echo
echo "=== Step 2: creating orange-clouded CNAMEs ==="

TUNNEL_TARGET="${CF_TUNNEL_ID}.cfargotunnel.com"
for entry in "${HOSTNAMES[@]}"; do
  HOST="${entry%%|*}"
  BODY=$(python3 -c "import json; print(json.dumps({
    'type': 'CNAME', 'name': '$HOST', 'content': '$TUNNEL_TARGET',
    'proxied': True, 'ttl': 1,
    'comment': 'managed by scripts/setup-cloudflare-arr-stack.sh'
  }))")
  RESULT=$(cf POST "/zones/${CF_ZONE_ID}/dns_records" "$BODY" 2>&1 || true)
  STATUS=$(echo "$RESULT" | j '["success"]' 2>/dev/null || echo "false")
  echo "  $HOST -> $TUNNEL_TARGET  [success=$STATUS]"
  if [[ "$STATUS" != "True" && "$STATUS" != "true" ]]; then
    echo "    raw: $RESULT" | head -c 300; echo
  fi
done

# ----- 3) Create service token -------------------------------------------

echo
echo "=== Step 3: creating Access service token (arr-stack-nzb360) ==="

ST_RESULT=$(cf POST "/accounts/${CF_ACCOUNT_ID}/access/service_tokens" \
  '{"name":"arr-stack-nzb360","duration":"forever"}')
ST_ID=$(echo "$ST_RESULT" | j '["result"]["id"]')
ST_CLIENT_ID=$(echo "$ST_RESULT" | j '["result"]["client_id"]')
ST_CLIENT_SECRET=$(echo "$ST_RESULT" | j '["result"]["client_secret"]')

# ----- 4) Create Access application + policies ---------------------------

echo
echo "=== Step 4: creating Access application 'Arr Stack' ==="

APP_BODY=$(python3 <<PY
import json
hostnames = [h.split("|",1)[0] for h in """$(printf '%s\n' "${HOSTNAMES[@]}")""".strip().splitlines()]
print(json.dumps({
    "name": "Arr Stack",
    "type": "self_hosted",
    "session_duration": "24h",
    "self_hosted_domains": hostnames,
    "domain": hostnames[0],  # legacy field, required by API
    "auto_redirect_to_identity": False,
    "policies": [
        {
            "name": "Service token (nzb360)",
            "decision": "non_identity",
            "precedence": 1,
            "include": [{"service_token": {"token_id": "$ST_ID"}}],
        },
        {
            "name": "Operator email allow-list",
            "decision": "allow",
            "precedence": 2,
            "include": [{"email": {"email": "$EMAIL"}}],
        },
    ],
}))
PY
)

APP_RESULT=$(cf POST "/accounts/${CF_ACCOUNT_ID}/access/apps" "$APP_BODY")
APP_ID=$(echo "$APP_RESULT" | j '["result"]["id"]')
echo "application id: $APP_ID"

# ----- Summary -----------------------------------------------------------

cat <<EOF

================================================================
DONE.

Public hostnames (all behind CF Access 'Arr Stack' application):
EOF
for entry in "${HOSTNAMES[@]}"; do echo "  https://${entry%%|*}"; done

cat <<EOF

Allowed via browser PIN:
  $EMAIL

Allowed via service token (nzb360 custom headers):
  CF-Access-Client-Id     = $ST_CLIENT_ID
  CF-Access-Client-Secret = $ST_CLIENT_SECRET

The Client Secret is shown ONCE -- save it now (1Password etc.).

In nzb360, for each *arr server connection, add two custom headers:
  Header Type: Cloudflare Client ID      Value: $ST_CLIENT_ID
  Header Type: Cloudflare Client Secret  Value: $ST_CLIENT_SECRET

================================================================
EOF
