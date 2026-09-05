#!/usr/bin/env bash
set -euo pipefail

APK=${1:?usage: audit_apk.sh path/to/app-release.apk}
command -v unzip >/dev/null || { echo 'unzip is required' >&2; exit 2; }
[ -f "$APK" ] || { echo "APK not found: $APK" >&2; exit 2; }

# Archive names are evidence of bundled key material. The content scan below
# deliberately does NOT search for the filename string: that name may appear
# harmlessly in documentation or code that explains which file the admin can
# import.
entries=$(unzip -Z1 "$APK")
if printf '%s\n' "$entries" | grep -Eiq '(^|/)[^/]*(\.pem|\.key|license-signing-key)(/|$)'; then
  echo 'FAIL: key-like file found in APK archive' >&2
  exit 1
fi

# Scan every non-directory archive entry for an actual PEM private-key marker.
# grep -a keeps binary DEX/resources data as bytes; only PEM BEGIN markers are
# rejected. PUBLIC KEY markers are intentionally not rejected.
private_marker='-----BEGIN[[:space:]]+(EC[[:space:]]+|RSA[[:space:]]+|OPENSSH[[:space:]]+|ENCRYPTED[[:space:]]+)?PRIVATE[[:space:]]+KEY-----'
while IFS= read -r entry; do
  [ -n "$entry" ] || continue
  case "$entry" in
    */) continue ;;
  esac
  if unzip -p "$APK" "$entry" 2>/dev/null \
      | grep -aEiq -- "$private_marker"; then
    echo "FAIL: PEM private-key marker found in APK contents: $entry" >&2
    exit 1
  fi
done <<EOF
$entries
EOF

echo 'PASS: no private-key file or PEM private-key marker found in APK'
