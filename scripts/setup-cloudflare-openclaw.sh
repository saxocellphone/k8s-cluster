#!/bin/bash
#
# setup-cloudflare-openclaw.sh
# ----------------------------
# Exposes the OpenClaw control UI via the existing `homelab` Cloudflare
# Tunnel, behind Cloudflare Access using Cloudflare's default login
# (one-time PIN emailed to allowed addresses -- no IdP required).
#
# Companion to scripts/setup-cloudflare-arr-stack.sh. Same account, same
# tunnel, same zone (victornazzaro.com). The tunnel is remotely-managed
# (token-based, see apps/cloudflared/) so hostname routing and Access
# policy live in the Cloudflare account, not in Git -- this script is the
# source-of-truth documentation of what's configured there.
#
# It performs (against the CF API):
#   1. Appends 1 ingress rule to the `homelab` tunnel:
#        openclaw.victornazzaro.com -> http://openclaw.openclaw.svc.cluster.local:18789
#      (preserves existing rules; keeps the catch-all 404 last)
#   2. Creates an orange-clouded CNAME openclaw.victornazzaro.com ->
#      <tunnel-id>.cfargotunnel.com
#   3. Creates an Access application 'OpenClaw' scoped to that hostname
#      with an email allow-list policy. Login uses Cloudflare's built-in
#      one-time PIN (default), so only the allowed email can get in.
#
# Re-running will produce duplicate DNS records / Access apps and 4xx
# errors on the duplicates -- read those and decide what to do.
#
# Required env:
#   CF_API_TOKEN   Cloudflare API token with these scopes:
#                    Account: Cloudflare Tunnel: Edit
#                    Account: Access: Apps and Policies: Edit
#                    Account: Account Settings: Read
#                    Zone:    DNS: Edit (victornazzaro.com)
#                    Zone:    Zone: Read (victornazzaro.com)
#
# Required positional arg:
#   $1  Operator email for the Access allow-list (use the same one as the
#       Arr Stack).
#
# Optional env (auto-discovered from the token if unset):
#   CF_ACCOUNT_ID  CF_ZONE_ID  CF_TUNNEL_ID
#
# Usage:
#   CF_API_TOKEN=cfut_xxx ./scripts/setup-cloudflare-openclaw.sh you@example.com

set -euo pipefail

# ----- Args / env --------------------------------------------------------

if [[ $# -lt 1 ]]; then
  echo "usage: CF_API_TOKEN=... $0 <operator-email>" >&2
  exit 2
fi
EMAIL="$1"
: "${CF_API_TOKEN:?CF_API_TOKEN must be set}"

API="https://api.cloudflare.com/client/v4"
DOMAIN="victornazzaro.com"
HOSTNAME="openclaw.${DOMAIN}"
ORIGIN="http://openclaw.openclaw.svc.cluster.local:18789"

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

# ----- 1) Append tunnel ingress rule -------------------------------------

echo
echo "=== Step 1: appending tunnel ingress rule ==="

CURRENT_CONFIG=$(cf GET "/accounts/${CF_ACCOUNT_ID}/cfd_tunnel/${CF_TUNNEL_ID}/configurations")
NEW_CONFIG=$(HOSTNAME="$HOSTNAME" ORIGIN="$ORIGIN" python3 <<PY
import json, os, sys
cur = json.loads('''$CURRENT_CONFIG''')
config = cur["result"]["config"] or {"ingress": []}
ingress = list(config.get("ingress", []))

# Strip the trailing catch-all 404 (re-appended at the end).
trailing = []
while ingress and "hostname" not in ingress[-1]:
    trailing.insert(0, ingress.pop())

host, origin = os.environ["HOSTNAME"], os.environ["ORIGIN"]
if host not in {r.get("hostname") for r in ingress}:
    ingress.append({"hostname": host, "service": origin})
    print(json.dumps({"hostname_added": host}, indent=2), file=sys.stderr)
else:
    print(json.dumps({"hostname_already_present": host}, indent=2), file=sys.stderr)

ingress.extend(trailing) if trailing else ingress.append({"service": "http_status:404"})
config["ingress"] = ingress
print(json.dumps({"config": config}))
PY
)

cf PUT "/accounts/${CF_ACCOUNT_ID}/cfd_tunnel/${CF_TUNNEL_ID}/configurations" "$NEW_CONFIG" \
  | j '["success"]' | xargs -I{} echo "tunnel config update: {}"

# ----- 2) Create DNS CNAME -----------------------------------------------

echo
echo "=== Step 2: creating orange-clouded CNAME ==="

TUNNEL_TARGET="${CF_TUNNEL_ID}.cfargotunnel.com"
DNS_BODY=$(HOSTNAME="$HOSTNAME" TARGET="$TUNNEL_TARGET" python3 -c "import json,os; print(json.dumps({
  'type':'CNAME','name':os.environ['HOSTNAME'],'content':os.environ['TARGET'],
  'proxied':True,'ttl':1,'comment':'managed by scripts/setup-cloudflare-openclaw.sh'
}))")
RESULT=$(cf POST "/zones/${CF_ZONE_ID}/dns_records" "$DNS_BODY" 2>&1 || true)
STATUS=$(echo "$RESULT" | j '["success"]' 2>/dev/null || echo "false")
echo "  $HOSTNAME -> $TUNNEL_TARGET  [success=$STATUS]"
if [[ "$STATUS" != "True" && "$STATUS" != "true" ]]; then
  echo "    raw: $RESULT" | head -c 300; echo
fi

# ----- 3) Create Access application + policy -----------------------------

echo
echo "=== Step 3: creating Access application 'OpenClaw' ==="

APP_BODY=$(HOSTNAME="$HOSTNAME" EMAIL="$EMAIL" python3 <<'PY'
import json, os
host, email = os.environ["HOSTNAME"], os.environ["EMAIL"]
print(json.dumps({
    "name": "OpenClaw",
    "type": "self_hosted",
    "session_duration": "24h",
    "self_hosted_domains": [host],
    "domain": host,                  # legacy field, required by API
    "auto_redirect_to_identity": False,
    "policies": [
        {
            "name": "Operator email allow-list",
            "decision": "allow",
            "precedence": 1,
            "include": [{"email": {"email": email}}],
        },
    ],
}))
PY
)

APP_ID=$(cf POST "/accounts/${CF_ACCOUNT_ID}/access/apps" "$APP_BODY" | j '["result"]["id"]')
echo "application id: $APP_ID"

# ----- Summary -----------------------------------------------------------

cat <<EOF

================================================================
DONE.

OpenClaw UI:   https://${HOSTNAME}
Origin:        ${ORIGIN}
Login:         Cloudflare Access -> one-time PIN (email code)
Allowed:       ${EMAIL}

First load may take ~1 min for the CNAME to propagate. Visiting the URL
prompts for your email, sends a 6-digit code, and admits only ${EMAIL}.
================================================================
EOF
