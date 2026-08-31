#!/usr/bin/env bash
#
# Starts the Android Auto Desktop Head Unit (DHU) simulator against a
# connected phone or emulator running the Android Auto app.
#
# Usage:
#   ./scripts/android-auto/run-dhu.sh
#   ./scripts/android-auto/run-dhu.sh -i rotary   # rotary controller mode
#
# Docs: https://developer.android.com/training/cars/testing/dhu
#
set -euo pipefail

PORT="${DHU_PORT:-5277}"

# ---------------------------------------------------------------------------
# 1. Locate the Android SDK
# ---------------------------------------------------------------------------
SDK=""
for candidate in \
  "${ANDROID_HOME:-}" \
  "${ANDROID_SDK_ROOT:-}" \
  "$HOME/Library/Android/sdk" \
  "$HOME/Android/Sdk"; do
  if [[ -n "$candidate" && -d "$candidate" ]]; then
    SDK="$candidate"
    break
  fi
done

if [[ -z "$SDK" ]]; then
  echo "❌ Android SDK not found."
  echo "   Install Android Studio or set ANDROID_HOME / ANDROID_SDK_ROOT."
  exit 1
fi

ADB="$SDK/platform-tools/adb"
DHU_DIR="$SDK/extras/google/auto"
DHU="$DHU_DIR/desktop-head-unit"

if [[ ! -x "$ADB" ]]; then
  echo "❌ adb not found at: $ADB"
  echo "   Install 'Android SDK Platform-Tools' (sdkmanager \"platform-tools\")."
  exit 1
fi

# ---------------------------------------------------------------------------
# 2. Make sure the DHU package is installed (extras;google;auto)
# ---------------------------------------------------------------------------
if [[ ! -f "$DHU" ]]; then
  echo "📦 DHU not installed — trying to install it via sdkmanager…"
  SDKMANAGER=""
  for candidate in \
    "$SDK/cmdline-tools/latest/bin/sdkmanager" \
    "$SDK/cmdline-tools/newest/bin/sdkmanager" \
    "$SDK/tools/bin/sdkmanager"; do
    if [[ -x "$candidate" ]]; then
      SDKMANAGER="$candidate"
      break
    fi
  done

  if [[ -z "$SDKMANAGER" ]]; then
    echo "❌ sdkmanager not found."
    echo "   Open Android Studio → Settings → Languages & Frameworks →"
    echo "   Android SDK → SDK Tools → tick"
    echo "   'Android Auto Desktop Head Unit emulator', then re-run this script."
    exit 1
  fi

  "$SDKMANAGER" --install "extras;google;auto"
  chmod +x "$DHU" 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# 3. Make sure a device/emulator is connected
# ---------------------------------------------------------------------------
DEVICE_COUNT="$("$ADB" devices | awk 'NR>1 && $2=="device"' | wc -l | tr -d ' ')"
if [[ "$DEVICE_COUNT" -eq 0 ]]; then
  echo "❌ No device connected."
  echo "   • Plug in a phone with USB debugging enabled, or"
  echo "   • start an emulator, then re-run this script."
  exit 1
fi

# ---------------------------------------------------------------------------
# 4. Tunnel + launch
# ---------------------------------------------------------------------------
# Best effort: try to start the head unit server on the phone/emulator
# without the manual "tap the version 10 times" dance. On emulators with a
# rooted adb shell this usually works; otherwise we print manual steps.
GEARHEAD_INSTALLED="$("$ADB" shell pm list packages 2>/dev/null | grep -c 'com.google.android.projection.gearhead' || true)"
if [[ "${GEARHEAD_INSTALLED:-0}" -gt 0 ]]; then
  echo "🤖 Trying to start the Android Auto head unit server via adb…"
  if ! "$ADB" shell am startservice -W \
      com.google.android.projection.gearhead/com.google.android.projection.gearhead.companion.DeveloperHeadUnitNetworkService >/dev/null 2>&1; then
    "$ADB" shell am start-foreground-service \
      com.google.android.projection.gearhead/com.google.android.projection.gearhead.companion.DeveloperHeadUnitNetworkService >/dev/null 2>&1 || true
  fi
else
  echo "ℹ️  Android Auto app not found on the device."
  echo "   • Physical phone: install/update it from Google Play, or"
  echo "   • Emulator: see 'emulator-only flow' in docs/android_auto.md."
fi

echo "🔌 Forwarding tcp:$PORT → device tcp:$PORT …"
"$ADB" forward "tcp:$PORT" "tcp:$PORT"

echo
echo "🚗 Starting the Desktop Head Unit (close its window to quit)…"
echo "   Remember on the phone: Android Auto app → ⋮ Developer settings →"
echo "   'Start head unit server'."
echo
cd "$DHU_DIR"
exec ./desktop-head-unit --adb="localhost:$PORT" "$@"
