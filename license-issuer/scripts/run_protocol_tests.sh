#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${ROOT}/build/protocol-test-classes"
rm -rf "$OUT"
mkdir -p "$OUT"

JAVAC_BIN="${JAVAC:-javac}"
JAVA_BIN="${JAVA:-java}"

"$JAVAC_BIN" -encoding UTF-8 -source 8 -target 8 -d "$OUT" \
  "$ROOT/app/src/main/java/com/carguard/licenseissuer/LicenseProtocol.java" \
  "$ROOT/app/src/test/java/com/carguard/licenseissuer/LicenseProtocolSelfTest.java"

"$JAVA_BIN" -cp "$OUT" com.carguard.licenseissuer.LicenseProtocolSelfTest
