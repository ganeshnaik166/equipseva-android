#!/usr/bin/env bash
#
# Print the SHA-256 fingerprint of an Android signing certificate, in both
# the colon-separated hex form (Play Console / assetlinks.json) and the
# base64 form (BuildConfig EXPECTED_CERT_SHA256). Use after the first AAB
# upload — paste the value Play Console reports in App Integrity → App
# Signing into one of the modes below to derive the matching base64 the
# anti-tamper check expects.
#
# Modes:
#   SHA from the App Signing certificate (post-Play upload):
#     bash scripts/compute_signing_sha.sh --hex AB:CD:EF:...
#
#   SHA from a local keystore (.jks):
#     bash scripts/compute_signing_sha.sh --keystore path/to/release.jks --alias upload [--storepass PASS]
#
#   SHA from a built APK (debug or release):
#     bash scripts/compute_signing_sha.sh --apk path/to/app.apk
#
# Outputs to stdout:
#   hex_colon  : AB:CD:EF:01:23:...   (use in assetlinks.json + Play Console fields)
#   hex_plain  : abcdef0123...        (lowercase, no separators)
#   base64     : K83v...              (use as EXPECTED_CERT_SHA256 in CI secrets)
set -euo pipefail

mode=""
hex_colon=""
keystore=""
alias=""
storepass=""
apk=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --hex) hex_colon="$2"; mode="hex"; shift 2;;
    --keystore) keystore="$2"; mode="keystore"; shift 2;;
    --alias) alias="$2"; shift 2;;
    --storepass) storepass="$2"; shift 2;;
    --apk) apk="$2"; mode="apk"; shift 2;;
    -h|--help) sed -n '2,/^set /p' "$0" | sed 's/^# \?//' ; exit 0;;
    *) echo "Unknown arg: $1" >&2; exit 2;;
  esac
done

case "$mode" in
  hex)
    : "${hex_colon:?--hex requires a value}"
    ;;
  keystore)
    : "${keystore:?--keystore requires a path}"
    : "${alias:?--alias is required with --keystore}"
    pw_args=()
    if [[ -n "$storepass" ]]; then pw_args=(-storepass "$storepass"); fi
    hex_colon="$(keytool -list -v -keystore "$keystore" -alias "$alias" "${pw_args[@]}" 2>/dev/null \
      | awk -F': ' '/SHA256:/ {print $2; exit}')"
    if [[ -z "$hex_colon" ]]; then
      echo "Could not extract SHA256 from keystore. Check path/alias/password." >&2
      exit 1
    fi
    ;;
  apk)
    : "${apk:?--apk requires a path}"
    if ! command -v apksigner >/dev/null 2>&1; then
      # Try the bundled tool from the latest build-tools install.
      apksigner_bin="$(find "${ANDROID_HOME:-$HOME/Library/Android/sdk}/build-tools" -name apksigner -type f 2>/dev/null | sort -V | tail -1 || true)"
      if [[ -n "${apksigner_bin:-}" ]]; then alias_apksigner() { "$apksigner_bin" "$@"; }; else
        echo "apksigner not on PATH and not found under ANDROID_HOME. Install Android build-tools." >&2
        exit 1
      fi
    else
      alias_apksigner() { apksigner "$@"; }
    fi
    hex_colon="$(alias_apksigner verify --print-certs "$apk" 2>/dev/null \
      | awk -F': ' '/Signer #1 certificate SHA-256 digest/ {print $2; exit}')"
    if [[ -n "$hex_colon" ]]; then
      hex_colon="$(echo "$hex_colon" | sed 's/\(..\)/\1:/g; s/:$//' | tr 'a-f' 'A-F')"
    else
      echo "Could not extract SHA256 from APK." >&2
      exit 1
    fi
    ;;
  *)
    echo "Pick a mode: --hex / --keystore / --apk. See --help." >&2
    exit 2
    ;;
esac

# Normalise to upper-case colon hex.
hex_colon="$(echo "$hex_colon" | tr 'a-f' 'A-F')"
hex_plain="$(echo "$hex_colon" | tr -d ':' | tr 'A-F' 'a-f')"
b64="$(printf '%s' "$hex_plain" | xxd -r -p | base64 | tr -d '\n')"

cat <<EOF
hex_colon : ${hex_colon}
hex_plain : ${hex_plain}
base64    : ${b64}
EOF
