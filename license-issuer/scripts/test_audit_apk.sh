#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AUDIT="$ROOT/scripts/audit_apk.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

make_apk() {
  local source_dir="$1"
  local output_apk="$2"
  (cd "$source_dir" && zip -q -r "$output_apk" .)
}

expect_pass() {
  local apk="$1"
  "$AUDIT" "$apk" >/dev/null
}

expect_fail() {
  local apk="$1"
  if "$AUDIT" "$apk" >/dev/null 2>&1; then
    echo "Expected audit failure: $apk" >&2
    exit 1
  fi
}

# The app source may construct boundaries at runtime, but must not contain a
# complete PEM private-key marker that could be copied into classes.dex.
if grep -R -Eiq -- '-----BEGIN[[:space:]]+(EC[[:space:]]+|RSA[[:space:]]+|OPENSSH[[:space:]]+|ENCRYPTED[[:space:]]+)?PRIVATE[[:space:]]+KEY-----|-----END[[:space:]]+(EC[[:space:]]+|RSA[[:space:]]+|OPENSSH[[:space:]]+|ENCRYPTED[[:space:]]+)?PRIVATE[[:space:]]+KEY-----' \
    "$ROOT/app/src/main" "$ROOT/app/src/test"; then
  echo 'FAIL: PEM private-key marker literal found in application source' >&2
  exit 1
fi
echo 'PASS: application source contains no PEM private-key marker literal'

# This fixture mirrors the user's current APK inventory. The DEX-like file
# contains the harmless import filename string, which must not be treated as a
# private key.
mkdir -p "$TMP/current/res"
printf 'manifest' > "$TMP/current/AndroidManifest.xml"
printf 'license-signing-key.pem' > "$TMP/current/classes.dex"
printf 'resources' > "$TMP/current/resources.arsc"
printf 'resource' > "$TMP/current/res/v9.xml"
printf 'metadata' > "$TMP/current/app-metadata.properties"
make_apk "$TMP/current" "$TMP/current.apk"
expect_pass "$TMP/current.apk"
echo 'PASS: current APK fixture'
echo 'PASS: filename text inside classes.dex is allowed'

# Actual PEM private-key marker in content must fail.
PEM_DASHES='-----'
PEM_BEGIN='BEGIN'
PEM_END='END'
PEM_EC_LABEL="EC PRIVATE KEY"
PEM_PKCS8_LABEL="PRIVATE KEY"
mkdir -p "$TMP/marker"
printf '%s\n' "${PEM_DASHES}${PEM_BEGIN} ${PEM_EC_LABEL}${PEM_DASHES}" 'not-a-key' \
  "${PEM_DASHES}${PEM_END} ${PEM_EC_LABEL}${PEM_DASHES}" \
  > "$TMP/marker/classes.dex"
make_apk "$TMP/marker" "$TMP/marker.apk"
expect_fail "$TMP/marker.apk"
echo 'PASS: EC PEM private-key marker rejected'

mkdir -p "$TMP/marker-pkcs8"
printf '%s\n' "${PEM_DASHES}${PEM_BEGIN} ${PEM_PKCS8_LABEL}${PEM_DASHES}" 'not-a-key' \
  "${PEM_DASHES}${PEM_END} ${PEM_PKCS8_LABEL}${PEM_DASHES}" \
  > "$TMP/marker-pkcs8/classes.dex"
make_apk "$TMP/marker-pkcs8" "$TMP/marker-pkcs8.apk"
expect_fail "$TMP/marker-pkcs8.apk"
echo 'PASS: PKCS#8 PEM private-key marker rejected'

# A key-like archive entry must fail even without private-key content.
mkdir -p "$TMP/file"
printf 'not a private key' > "$TMP/file/production.pem"
make_apk "$TMP/file" "$TMP/file.apk"
expect_fail "$TMP/file.apk"
echo 'PASS: .pem archive entry rejected'

mkdir -p "$TMP/keyfile"
printf 'not a private key' > "$TMP/keyfile/production.key"
make_apk "$TMP/keyfile" "$TMP/keyfile.apk"
expect_fail "$TMP/keyfile.apk"
echo 'PASS: .key archive entry rejected'

echo 'APK audit tests: PASS'
