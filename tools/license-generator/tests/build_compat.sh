#!/usr/bin/env bash
# Build the end-to-end firmware-compatibility harness.
#
# Compiles the REAL firmware license translation units (license.cpp /
# license_helpers.cpp + license.h) together with the Python-generated TEST
# public key, using real BearSSL. The resulting binary:
#   testing_compat <BASE32_CODE>
# runs license_decode_base32 -> verify_ecdsa_p256_sha256 -> license_attempt_activate.
#
# Environment:
#   BEARSSL_INC   : directory containing bearssl/bearssl.h (repeatable via -I)
#   BEARSSL_LIB   : path to libbearssl.a
#   COMPAT_OUT    : output binary (default /tmp/compat/testing_compat)
#
# Required because Python's `cryptography` and the firmware's BearSSL are
# different crypto stacks — this proves the generator's output is byte- and
# log-form compatible with the actual firmware.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
FIRM="${REPO_ROOT}/firmware/car_guard"
TESTDIR_STAGE="$(cd "$(dirname "$0")" && pwd)"
OUT="${COMPAT_OUT:-/tmp/compat/testing_compat}"

BEARSSL_INC="${BEARSSL_INC:-}"
BEARSSL_LIB="${BEARSSL_LIB:-/tmp/bearssl-src/build/libbearssl.a}"

if [ -z "$BEARSSL_INC" ] || [ ! -f "$BEARSSL_LIB" ]; then
  echo "ERROR: set BEARSSL_INC (dir containing bearssl/bearssl.h) and" >&2
  echo "       BEARSSL_LIB (libbearssl.a). See README." >&2
  exit 2
fi

mkdir -p "$(dirname "$OUT")"

g++ -std=c++17 -O2 -Wall -Wextra -DPUBLIC_KEY_CONFIGURED=1 \
  -I "$FIRM" \
  -I /tmp/hostshims \
  -I "$BEARSSL_INC" \
  "$TESTDIR_STAGE/testing_compat.cpp" \
  "$BEARSSL_LIB" \
  -o "$OUT"

echo "Built compat harness -> $OUT"
echo "Usage: $OUT <BASE32_CODE>"
