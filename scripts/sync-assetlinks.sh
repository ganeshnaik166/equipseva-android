#!/usr/bin/env bash
#
# Sync mirrors of assetlinks.json from the canonical (served) copy.
#
# Why this exists:
#   The Android App Links Digital Asset Links file must live at
#   https://equipseva.com/.well-known/assetlinks.json — that's served from
#   `docs/.well-known/assetlinks.json` (GitHub Pages: source = main/docs).
#
#   Three other copies exist in the repo for documentation and backup-hosting
#   plans (see docs/security/app-links-deployment.md). If one of them drifts
#   from the served file — e.g. after adding the Play App Signing SHA-256 per
#   Issue #303 — App Links verification can break silently on the affected
#   builds. This script keeps all four in sync from one edit.
#
#   `play-store/assetlinks.json` is intentionally NOT mirrored: it's the
#   Play Console upload artifact (prod-only, debug entry stripped). Edit
#   it separately when its content needs to change.
#
# Usage:
#   ./scripts/sync-assetlinks.sh         # sync mirrors from canonical
#   ./scripts/sync-assetlinks.sh --check # exit 1 if anything is drifted
#
set -euo pipefail

CANONICAL="docs/.well-known/assetlinks.json"
MIRRORS=(
  "docs/security/assetlinks.json"
  "well-known/.well-known/assetlinks.json"
  "website/.well-known/assetlinks.json"
)

cd "$(git rev-parse --show-toplevel)"

if [[ ! -f "$CANONICAL" ]]; then
  echo "ERROR: canonical file missing: $CANONICAL" >&2
  exit 1
fi

if [[ "${1-}" == "--check" ]]; then
  drift=0
  for mirror in "${MIRRORS[@]}"; do
    if ! cmp -s "$CANONICAL" "$mirror"; then
      echo "DRIFT: $mirror differs from $CANONICAL" >&2
      drift=1
    fi
  done
  if [[ $drift -eq 0 ]]; then
    echo "OK: all ${#MIRRORS[@]} mirrors match $CANONICAL"
  fi
  exit "$drift"
fi

for mirror in "${MIRRORS[@]}"; do
  if [[ ! -f "$mirror" ]]; then
    echo "ERROR: mirror missing: $mirror" >&2
    exit 1
  fi
  cp "$CANONICAL" "$mirror"
  echo "synced → $mirror"
done

echo
echo "Done. ${#MIRRORS[@]} mirror(s) now identical to $CANONICAL."
echo "Run again with --check from CI to detect future drift."
