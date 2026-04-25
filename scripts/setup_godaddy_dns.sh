#!/usr/bin/env bash
#
# Point equipseva.com at GitHub Pages via the GoDaddy DNS API.
#
# What this does (idempotent — safe to re-run):
#   - Replaces all A records on @ (apex) with GitHub Pages' four IPv4 addresses,
#     deleting the WebsiteBuilder parking record in the process.
#   - Replaces all AAAA records on @ with GitHub Pages' four IPv6 addresses.
#   - Replaces the www CNAME (currently a self-loop on equipseva.com) with the
#     repo owner's github.io subdomain so HTTPS-with-Pages works on www.
#
# What this DOES NOT touch:
#   - The two NS records and the SOA — those are the GoDaddy nameservers.
#   - The _domainconnect CNAME and _dmarc TXT — keep them.
#
# Usage:
#   1. Generate a *production* API key at https://developer.godaddy.com/keys
#      (the "OTE" key won't work against your real domain).
#   2. Export the key + secret in your shell:
#        export GODADDY_KEY="..."
#        export GODADDY_SECRET="..."
#   3. (Optional) Override the GitHub username if it isn't `ganeshnaik166`:
#        export GH_USER="someone-else"
#   4. Run:
#        bash scripts/setup_godaddy_dns.sh
#
# Notes:
#   - The PUT endpoint REPLACES all records of the given type+name with the
#     payload, which is exactly what we want for the apex A and AAAA records.
#   - GoDaddy occasionally restricts the DNS API to paid tiers. If you get a
#     401 / 403, fall back to the manual GoDaddy DNS UI — the same record
#     values are listed in docs/launch/LAUNCH_CHECKLIST.md §1.
set -euo pipefail

: "${GODADDY_KEY:?Set GODADDY_KEY (production key from developer.godaddy.com/keys)}"
: "${GODADDY_SECRET:?Set GODADDY_SECRET (production secret from developer.godaddy.com/keys)}"

DOMAIN="${DOMAIN:-equipseva.com}"
GH_USER="${GH_USER:-ganeshnaik166}"
TTL="${TTL:-3600}"

BASE="https://api.godaddy.com/v1/domains/${DOMAIN}/records"
AUTH_HEADER="Authorization: sso-key ${GODADDY_KEY}:${GODADDY_SECRET}"

say() { printf '\n==> %s\n' "$*"; }

say "Replacing apex A records (deletes the WebsiteBuilder parking record)"
curl -fsS -X PUT "${BASE}/A/@" \
  -H "${AUTH_HEADER}" \
  -H "Content-Type: application/json" \
  -d "[
    {\"data\":\"185.199.108.153\",\"ttl\":${TTL}},
    {\"data\":\"185.199.109.153\",\"ttl\":${TTL}},
    {\"data\":\"185.199.110.153\",\"ttl\":${TTL}},
    {\"data\":\"185.199.111.153\",\"ttl\":${TTL}}
  ]"
echo " ok"

say "Replacing apex AAAA records (IPv6)"
curl -fsS -X PUT "${BASE}/AAAA/@" \
  -H "${AUTH_HEADER}" \
  -H "Content-Type: application/json" \
  -d "[
    {\"data\":\"2606:50c0:8000::153\",\"ttl\":${TTL}},
    {\"data\":\"2606:50c0:8001::153\",\"ttl\":${TTL}},
    {\"data\":\"2606:50c0:8002::153\",\"ttl\":${TTL}},
    {\"data\":\"2606:50c0:8003::153\",\"ttl\":${TTL}}
  ]"
echo " ok"

say "Pointing www CNAME at ${GH_USER}.github.io"
curl -fsS -X PUT "${BASE}/CNAME/www" \
  -H "${AUTH_HEADER}" \
  -H "Content-Type: application/json" \
  -d "[
    {\"data\":\"${GH_USER}.github.io\",\"ttl\":${TTL}}
  ]"
echo " ok"

say "Verifying — listing all records on ${DOMAIN}"
curl -fsS "${BASE}" \
  -H "${AUTH_HEADER}" \
  -H "Accept: application/json" \
  | python3 -m json.tool

cat <<EOF

Next manual steps (these the API can't do for you):
  1. GitHub repo → Settings → Pages → Source: main / /docs → Save.
  2. Wait ~5–15 min for DNS to propagate; tick "Enforce HTTPS" once GitHub issues the cert.
  3. Verify:
       curl -sI https://${DOMAIN}/.well-known/assetlinks.json
       open https://${DOMAIN}/privacy/
EOF
