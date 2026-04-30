#!/usr/bin/env bash
# Interactive Play Store screenshot capture helper.
#
# Walks you through the 8 v1 screens (Book Repair + Engineer Jobs scope —
# marketplace is gated off in v1) and uses `adb exec-out screencap -p` to
# capture each one straight off the device/emulator. Output lands in
# play-store/launch-assets/v1-candidates/screenshots/.
#
# Pre-reqs:
#   - adb on PATH (`brew install android-platform-tools` if missing)
#   - One device or emulator connected (`adb devices` shows it)
#   - The round-2 redesign (PR #214) merged or running on the device
#   - You signed in as both a hospital test user and an engineer test user
#     (or willing to sign in/out between captures)
#
# Usage:
#   bash play-store/launch-assets/capture-screenshots.sh

set -euo pipefail

cd "$(dirname "$0")/../.."  # repo root

OUT_DIR="play-store/launch-assets/v1-candidates/screenshots"
mkdir -p "$OUT_DIR"

if ! command -v adb >/dev/null 2>&1; then
  echo "ERROR: adb not on PATH. Install with: brew install android-platform-tools" >&2
  exit 1
fi

DEVICE_COUNT=$(adb devices | grep -E "device$" | wc -l | tr -d ' ')
if [ "$DEVICE_COUNT" = "0" ]; then
  echo "ERROR: No device/emulator connected. Run an emulator or plug in a phone with USB debugging on." >&2
  exit 1
fi

# 8 screens for v1 — order matches Play Console upload sequence
SCREENS=(
  "01-welcome|Welcome screen (auth/welcome). Cold-start the app, do not sign in yet."
  "02-role-select|Role select. Sign in with a test account that has not picked a role."
  "03-home-hospital|Hospital Home dashboard. Sign in as a hospital test user."
  "04-home-engineer|Engineer Home dashboard. Sign in as an engineer test user."
  "05-repair-job-detail|Repair job detail. From engineer home, open a job from the Jobs feed."
  "06-engineer-directory|Engineer directory. From hospital home, tap Find Engineer."
  "07-kyc-submitted|KYC submitted screen. As engineer, complete KYC submission flow."
  "08-chat|Chat conversation. Open any active chat thread."
)

echo
echo "EquipSeva v1 — Play Store screenshot capture"
echo "============================================="
echo "Output dir: $OUT_DIR"
echo "Device: $(adb devices | grep -E "device$" | head -1 | awk '{print $1}')"
echo

for entry in "${SCREENS[@]}"; do
  IFS='|' read -r name desc <<< "$entry"
  echo "--- $name ---"
  echo "  $desc"
  echo "  Navigate the app, then press Enter to capture (or 's' to skip):"
  read -r reply
  if [ "$reply" = "s" ]; then
    echo "  skipped"
    continue
  fi
  out="$OUT_DIR/$name.png"
  adb exec-out screencap -p > "$out"
  size=$(stat -f%z "$out" 2>/dev/null || stat -c%s "$out")
  echo "  saved $out ($((size / 1024)) KB)"
  echo
done

echo
echo "Done. Files:"
ls -la "$OUT_DIR"
echo
echo "Verify each PNG:"
echo "  - portrait orientation (height > width)"
echo "  - min 320 px on the short side, max 3840 px on the long side"
echo "  - no PII (sign in with test accounts, fake hospital + fake engineer)"
echo
echo "Then upload to Play Console: Store listing -> Graphics -> Phone screenshots."
