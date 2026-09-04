#!/usr/bin/env bash
set -euo pipefail

APK=${1:?usage: audit_apk.sh path/to/app-release.apk}
command -v unzip >/dev/null || { echo 'unzip is required' >&2; exit 2; }
[ -f "$APK" ] || { echo "APK not found: $APK" >&2; exit 2; }

# Reject any PEM/private-key marker or the configured production private-key
# filename in packaged entries. The APK should contain code and public
# fingerprint configuration only, never imported key material.
if unzip -l "$APK" | grep -Eiq 'license-signing-key|\.pem$|\.key$|PRIVATE.KEY'; then
  echo 'FAIL: key-like file found in APK archive' >&2
  exit 1
fi
if unzip -p "$APK" $(unzip -Z1 "$APK" | grep -E '\.(dex|xml|txt|json)$' || true) 2>/dev/null \
    | grep -Eiq -- '-----BEGIN[[:space:]]+(EC[[:space:]]+)?PRIVATE KEY-----|license-signing-key\.pem'; then
  echo 'FAIL: private-key material found in APK contents' >&2
  exit 1
fi

echo 'PASS: no private-key file or PEM private-key marker found in APK'
