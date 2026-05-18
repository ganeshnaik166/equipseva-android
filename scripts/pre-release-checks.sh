#!/usr/bin/env bash
#
# Pre-release configuration guard. Run before any release AAB / APK
# build to catch the launch-checklist gaps from
# memory/project_pre_playstore_launch_checklist.md.
#
# Usage:
#   scripts/pre-release-checks.sh           # exit 0 if ready, 1 + report otherwise
#   PRECHECK_LOOSE=1 scripts/pre-release-checks.sh   # warnings instead of failures
#
# Wired into Gradle as the `preReleaseCheck` task; release builds depend
# on it so a forgetful "./gradlew bundleRelease" can never silently ship
# with an empty EXPECTED_CERT_SHA256 or stale assetlinks.json.

set -euo pipefail

LOOSE="${PRECHECK_LOOSE:-0}"
FAIL=0
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LOCAL_PROPS="$ROOT_DIR/local.properties"
ASSETLINKS_URL="https://equipseva.com/.well-known/assetlinks.json"
UPLOAD_PACKAGE="com.equipseva.app"

# Upload key SHA-256 (hex, colon-separated). Anchored against this
# specific value because both the assetlinks.json *and* the build's
# EXPECTED_CERT_SHA256 must reference the same upload key. If you ever
# rotate the upload key, update this constant + the assetlinks file +
# every CI secret in lockstep.
UPLOAD_KEY_SHA_HEX="92:B9:05:A8:19:7D:0C:54:E2:91:8B:27:75:DD:9A:F8:C9:A6:F5:13:8F:8C:59:17:77:80:FD:DF:67:A2:D1:C1"

red() { printf "\033[31m%s\033[0m\n" "$*"; }
green() { printf "\033[32m%s\033[0m\n" "$*"; }
yellow() { printf "\033[33m%s\033[0m\n" "$*"; }

fail() {
  red "  FAIL: $*"
  if [[ "$LOOSE" == "1" ]]; then
    yellow "  (PRECHECK_LOOSE=1 → continuing)"
  else
    FAIL=1
  fi
}
ok() { green "  OK:   $*"; }

# Extract a key from one or more .properties files (no shell-injection —
# handles quoted values + trims whitespace). Falls back to env var of
# same name when no file has it.
get_prop() {
  local key="$1"
  shift
  local val=""
  local files=("$@")
  if [[ ${#files[@]} -eq 0 ]]; then files=("$LOCAL_PROPS"); fi
  for f in "${files[@]}"; do
    if [[ -z "$val" && -f "$f" ]]; then
      val="$(awk -F= -v k="$key" '
        $0 !~ /^[[:space:]]*#/ {
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", $1)
          if ($1 == k) {
            sub(/^[^=]*=/, "", $0)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
            print $0
            exit
          }
        }
      ' "$f")"
    fi
  done
  if [[ -z "$val" ]]; then val="${!key:-}"; fi
  printf "%s" "$val"
}

echo "━━━ pre-release checks ━━━"

# ── 1. EXPECTED_CERT_SHA256 ────────────────────────────────────────
echo "[1/3] EXPECTED_CERT_SHA256 (anti-repackaging guard)"
EXP_SHA="$(get_prop EXPECTED_CERT_SHA256)"
if [[ -z "$EXP_SHA" ]]; then
  fail "EXPECTED_CERT_SHA256 not set in local.properties or env. SignatureVerifier silently skips when empty — release builds would ship without anti-repackaging enforcement."
elif [[ ! "$EXP_SHA" =~ ^[A-Za-z0-9+/]+=*$ ]]; then
  fail "EXPECTED_CERT_SHA256 set but doesn't look like base64. Use: 'keytool -list -v ... | grep SHA256' then base64-encode the raw 32-byte digest (NOT the colon-hex)."
elif [[ "${#EXP_SHA}" -lt 40 ]]; then
  fail "EXPECTED_CERT_SHA256 too short (got ${#EXP_SHA} chars; expected ~44 for a 32-byte digest)."
else
  ok "EXPECTED_CERT_SHA256 set (${#EXP_SHA} chars, base64-shaped)"
fi

# ── 2. assetlinks.json reachable + contains upload-key fingerprint ─
echo "[2/3] assetlinks.json hosting"
if ! command -v curl >/dev/null 2>&1; then
  fail "curl not on PATH — cannot verify $ASSETLINKS_URL"
else
  HTTP_BODY="$(curl -fsSL --max-time 10 "$ASSETLINKS_URL" 2>&1 || true)"
  if [[ -z "$HTTP_BODY" || "$HTTP_BODY" == *"Could not resolve host"* || "$HTTP_BODY" == *"curl:"* ]]; then
    fail "could not fetch $ASSETLINKS_URL — check Cloudflare / DNS"
  else
    if [[ "$HTTP_BODY" == *"\"$UPLOAD_PACKAGE\""* ]]; then
      ok "live assetlinks.json contains $UPLOAD_PACKAGE"
    else
      fail "live assetlinks.json missing target for $UPLOAD_PACKAGE"
    fi
    # Strip colons for a flexible match (some tools serve with/without).
    UPLOAD_KEY_NO_COLONS="${UPLOAD_KEY_SHA_HEX//:/}"
    HTTP_NO_COLONS="${HTTP_BODY//:/}"
    if [[ "$HTTP_NO_COLONS" == *"$UPLOAD_KEY_NO_COLONS"* ]]; then
      ok "live assetlinks.json contains the upload-key fingerprint"
    else
      fail "live assetlinks.json missing the upload-key SHA-256. Expected: $UPLOAD_KEY_SHA_HEX"
    fi
    # Play signing key reminder — can't verify automatically, but warn loudly.
    yellow "  REMINDER: Play App Signing key SHA-256 must also be present"
    yellow "            once the first AAB lands in Play Console. Check via"
    yellow "            Play Console → Setup → App integrity → App signing."
  fi
fi

# ── 3. release keystore present (when not in CI loose mode) ────────
echo "[3/3] release keystore"
KS_PROPS="$ROOT_DIR/keystore.properties"
if [[ ! -f "$KS_PROPS" ]]; then
  fail "keystore.properties missing — release build will fall back to debug signing (never publish that AAB)"
else
  # storeFile lives in keystore.properties (it's the canonical Gradle
  # convention), not local.properties — read from there first.
  STORE_FILE="$(get_prop storeFile "$KS_PROPS" "$LOCAL_PROPS")"
  if [[ -z "$STORE_FILE" ]]; then
    fail "keystore.properties present but storeFile= line is empty"
  elif [[ ! -f "$ROOT_DIR/$STORE_FILE" && ! -f "$STORE_FILE" ]]; then
    fail "keystore.properties references storeFile=$STORE_FILE but that file doesn't exist"
  else
    ok "release keystore present"
  fi
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [[ "$FAIL" -ne 0 ]]; then
  red "pre-release checks FAILED. Re-run with PRECHECK_LOOSE=1 to ignore (CI dry-runs only)."
  exit 1
fi
green "pre-release checks PASSED."
exit 0
