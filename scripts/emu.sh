#!/usr/bin/env bash
# Boot a headless Pixel emulator, install the debug APK, and (optionally)
# launch the app + take a screenshot. Used for no-cable QA when the user
# can't connect their phone.
#
# Usage:
#   scripts/emu.sh boot       # create AVD if missing + boot headless
#   scripts/emu.sh install    # gradle assembleDebug + adb install
#   scripts/emu.sh launch     # launch main activity
#   scripts/emu.sh shot <out> # screenshot to <out>.png
#   scripts/emu.sh kill       # kill running emulator
set -euo pipefail

SDK="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
export ANDROID_HOME="$SDK"
export ANDROID_SDK_ROOT="$SDK"
PATH="$SDK/cmdline-tools/latest/bin:$SDK/platform-tools:$SDK/emulator:$PATH"

AVD_NAME="es_pixel_api35"
SYS_IMG="system-images;android-35;google_apis;arm64-v8a"
PKG="com.equipseva.app.debug"
ACT="com.equipseva.app.MainActivity"

cmd="${1:-help}"

case "$cmd" in
  boot)
    if ! avdmanager list avd 2>/dev/null | grep -q "Name: $AVD_NAME"; then
      echo "Creating AVD $AVD_NAME..."
      echo "no" | avdmanager create avd -n "$AVD_NAME" -k "$SYS_IMG" -d "pixel_6" --force
    fi
    if ! adb devices | grep -q emulator; then
      echo "Booting $AVD_NAME with window..."
      nohup emulator -avd "$AVD_NAME" -no-snapshot -no-audio > /tmp/emu.log 2>&1 &
      echo "Waiting for boot..."
      adb wait-for-device
      until [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; do sleep 2; done
      echo "Booted."
    else
      echo "Emulator already running."
    fi
    ;;
  boot-headless)
    if ! avdmanager list avd 2>/dev/null | grep -q "Name: $AVD_NAME"; then
      echo "no" | avdmanager create avd -n "$AVD_NAME" -k "$SYS_IMG" -d "pixel_6" --force
    fi
    if ! adb devices | grep -q emulator; then
      nohup emulator -avd "$AVD_NAME" -no-window -no-snapshot -no-audio -gpu swiftshader_indirect > /tmp/emu.log 2>&1 &
      adb wait-for-device
      until [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; do sleep 2; done
    fi
    ;;
  install)
    ./gradlew :app:assembleDebug
    APK=$(ls -t app/build/outputs/apk/debug/*.apk | head -1)
    echo "Installing $APK..."
    adb install -r "$APK"
    ;;
  launch)
    adb shell am start -n "$PKG/$ACT"
    ;;
  shot)
    out="${2:-shot.png}"
    adb exec-out screencap -p > "$out"
    echo "Saved $out"
    ;;
  kill)
    adb emu kill || true
    ;;
  *)
    echo "Usage: $0 {boot|install|launch|shot <out>|kill}"
    exit 1
    ;;
esac
