#!/usr/bin/env bash
#
# One-time setup for testing Android Auto on an EMULATOR (no physical phone).
#
# What it does:
#   1. Installs the required SDK packages (platform-tools, emulator,
#      an API 33 Google Play system image and the DHU itself).
#   2. Creates a ready-made AVD named "CarGuard_Auto".
#   3. Optionally (--boot) boots the AVD and waits for it to finish booting.
#   4. Optionally (--aa-apk FILE) sideloads the Android Auto companion APK
#      (an x86_64 build is required — see docs/android_auto.md).
#
# Usage:
#   ./scripts/android-auto/setup-emulator.sh
#   ./scripts/android-auto/setup-emulator.sh --boot
#   ./scripts/android-auto/setup-emulator.sh --boot --aa-apk android-auto.apk
#
set -euo pipefail

IMAGE="system-images;android-33;google_apis_playstore;x86_64"
AVD_NAME="CarGuard_Auto"

BOOT=0
AA_APK=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --boot)
      BOOT=1
      shift
      ;;
    --aa-apk)
      AA_APK="${2:-}"
      if [[ -z "$AA_APK" ]]; then
        echo "❌ --aa-apk needs a file path."
        exit 1
      fi
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

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

# ---------------------------------------------------------------------------
# 2. Locate sdkmanager / avdmanager / adb
# ---------------------------------------------------------------------------
SDKMANAGER=""
AVDMANAGER=""
for sub in "cmdline-tools/latest" "cmdline-tools/newest" "tools"; do
  if [[ -z "$SDKMANAGER" && -x "$SDK/$sub/bin/sdkmanager" ]]; then
    SDKMANAGER="$SDK/$sub/bin/sdkmanager"
    AVDMANAGER="$SDK/$sub/bin/avdmanager"
  fi
done

if [[ -z "$SDKMANAGER" ]]; then
  echo "❌ sdkmanager not found under: $SDK"
  echo "   Android Studio → Settings → Languages & Frameworks → Android SDK →"
  echo "   SDK Tools → tick 'Android SDK Command-line Tools (latest)'."
  exit 1
fi

ADB="$SDK/platform-tools/adb"

# ---------------------------------------------------------------------------
# 3. Install the needed SDK packages
# ---------------------------------------------------------------------------
echo "📦 Installing SDK packages (this can take a few minutes)…"
echo "   • platform-tools  • emulator  • $IMAGE  • extras;google;auto (DHU)"
yes | "$SDKMANAGER" --licenses >/dev/null 2>&1 || true
"$SDKMANAGER" --install \
  "platform-tools" \
  "emulator" \
  "$IMAGE" \
  "extras;google;auto" >/dev/null

echo "✅ SDK packages installed."

# ---------------------------------------------------------------------------
# 4. Create the AVD (idempotent)
# ---------------------------------------------------------------------------
if "$AVDMANAGER" list avd 2>/dev/null | grep -q "Name: $AVD_NAME$"; then
  echo "♻️  AVD '$AVD_NAME' already exists — skipping creation."
else
  echo "🛠  Creating AVD '$AVD_NAME'…"
  echo no | "$AVDMANAGER" create avd --force \
    --name "$AVD_NAME" \
    --package "$IMAGE" \
    --device pixel_5 ||
    echo no | "$AVDMANAGER" create avd --force \
      --name "$AVD_NAME" \
      --package "$IMAGE"
fi

# ---------------------------------------------------------------------------
# 5. Optionally sideload the Android Auto companion APK
# ---------------------------------------------------------------------------
if [[ -n "$AA_APK" ]]; then
  if [[ ! -f "$AA_APK" ]]; then
    echo "❌ APK not found: $AA_APK"
    exit 1
  fi
  if [[ ! -x "$ADB" ]]; then
    echo "❌ adb not found — platform-tools failed to install?"
    exit 1
  fi
  if ! "$ADB" get-state >/dev/null 2>&1; then
    echo "⚠️  No device/emulator running yet — start the emulator first, then re-run:"
    echo "      adb install -r \"$AA_APK\""
  else
    echo "📲 Installing Android Auto APK…"
    "$ADB" install -r "$AA_APK" || {
      echo "❌ Install failed. Make sure you downloaded an x86_64 variant of"
      echo "   the Android Auto APK (see docs/android_auto.md § emulator)."
      exit 1
    }
    echo "✅ Android Auto app installed."
  fi
fi

# ---------------------------------------------------------------------------
# 6. Optionally boot the emulator and wait for it
# ---------------------------------------------------------------------------
if [[ "$BOOT" -eq 1 ]]; then
  echo "🚀 Booting the emulator (first boot takes a few minutes)…"
  "$SDK/emulator/emulator" -avd "$AVD_NAME" "${EMULATOR_EXTRA:-}" &
  EMU_PID=$!
  "$ADB" wait-for-device
  until [[ "$("$ADB" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == "1" ]]; do
    sleep 3
  done
  echo "✅ Emulator booted (PID $EMU_PID)."
fi

echo
echo "🎉 Done! Next steps:"
echo "   1. flutter run                     # install Car Guard on the emulator"
if [[ "$BOOT" -eq 0 ]]; then
  echo "   (or boot it now:  ./setup-emulator.sh --boot)"
fi
echo "   2. ./scripts/android-auto/run-dhu.sh   # start the car simulator"
