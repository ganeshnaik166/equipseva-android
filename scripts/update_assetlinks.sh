#!/usr/bin/env bash
#
# Update docs/.well-known/assetlinks.json with the App Signing SHA-256
# from Play Console (or any new release-signing key).
#
# After your first AAB upload to Play Console, copy the SHA-256 from
#   Play Console → Setup → App integrity → App signing → "App signing key certificate"
# (it's the colon-separated hex form), then run:
#
#   bash scripts/update_assetlinks.sh AB:CD:EF:01:23:...:FF
#
# The script:
#   - Validates the input shape (32 hex bytes, colon-separated).
#   - Replaces the production-package SHA in docs/.well-known/assetlinks.json,
#     leaving the debug-package SHA intact so adb-installed dev builds keep
#     working with the App Link.
#   - Prints a diff and stages the change. You commit/push.
#
# To apply ONLY the production fingerprint (drop the debug entry — recommended
# once you no longer need debug App-Link binding):
#
#   bash scripts/update_assetlinks.sh --no-debug AB:CD:...
set -euo pipefail

include_debug=true
if [[ "${1:-}" == "--no-debug" ]]; then
  include_debug=false
  shift
fi

sha="${1:-}"
if [[ -z "$sha" ]]; then
  echo "Usage: $0 [--no-debug] <colon-hex-SHA-256>" >&2
  exit 2
fi

if ! [[ "$sha" =~ ^([0-9A-Fa-f]{2}:){31}[0-9A-Fa-f]{2}$ ]]; then
  echo "Bad SHA-256 format. Expected 32 hex bytes separated by colons." >&2
  echo "Got: $sha" >&2
  exit 1
fi

sha_upper="$(echo "$sha" | tr 'a-f' 'A-F')"

target="docs/.well-known/assetlinks.json"
if [[ ! -f "$target" ]]; then
  echo "Cannot find $target. Run from repo root." >&2
  exit 1
fi

debug_block=""
if $include_debug; then
  # Preserve the existing debug-package entry verbatim.
  debug_block="$(python3 - <<'PY'
import json, sys
with open("docs/.well-known/assetlinks.json") as f:
    data = json.load(f)
debug = next((e for e in data if e.get("target", {}).get("package_name", "").endswith(".debug")), None)
if debug:
    print(json.dumps(debug, indent=2))
PY
)"
fi

python3 - "$sha_upper" "$include_debug" <<'PY'
import json, sys

new_sha = sys.argv[1]
include_debug = sys.argv[2] == "true"

with open("docs/.well-known/assetlinks.json") as f:
    data = json.load(f)

prod_entry = {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
        "namespace": "android_app",
        "package_name": "com.equipseva.app",
        "sha256_cert_fingerprints": [new_sha],
    },
}

debug_entry = next(
    (e for e in data if e.get("target", {}).get("package_name", "").endswith(".debug")),
    None,
)

out = [prod_entry]
if include_debug and debug_entry:
    out.append(debug_entry)

with open("docs/.well-known/assetlinks.json", "w") as f:
    json.dump(out, f, indent=2)
    f.write("\n")
PY

echo
echo "Updated $target. Diff:"
git --no-pager diff -- "$target" || true

echo
echo "Next:"
echo "  git add $target"
echo "  git commit -m 'Update assetlinks.json with Play Console signing SHA-256'"
echo "  git push origin main"
