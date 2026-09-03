# CarGuard License Generator (Stage 4)

A standalone, firmware-compatible desktop tool that produces CarGuard license
codes. It is **independent** from the ESP8266 firmware and matches the exact
byte layout the firmware already decodes and verifies.

## What it produces

```
payload (19 bytes) || raw ECDSA P-256 r||s (64 bytes)  =  83 bytes
        -> RFC4648 Base32 (uppercase, no padding, no separators)  =  133 chars
```

- Signature: **ECDSA P-256 + SHA-256**, **raw `r || s`**, each component exactly
  **32-byte big-endian** — no DER / ASN.1. This is what
  `br_ecdsa_vrfy_raw_get_default()` in the firmware requires.
- Public key export: **uncompressed P-256 `04 || X(32) || Y(32)` = 65 bytes**,
  exactly what `verify_ecdsa_p256_sha256()` expects.

## Requirements

- Python 3.11 (tested)
- `cryptography` (>=3.3,<51). Install into a virtualenv:

```bash
cd tools/license-generator
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
```

## Key handling (security)

- **No private key is ever embedded** in the tool, any source file, or Git.
- The private key is loaded from an **external PEM file** via `--key-file`,
  and is needed only by `generate` and `public-key` (to derive the public key).
- **Verification uses a PUBLIC key only** — `verify` never loads a private key:
  pass `--public-key <04||X||Y hex>` or `--public-key-file <path>` (a PEM
  *public* key or a 130-char hex file).
- `.gitignore` excludes `*.pem`, `*.key`, `keys/`, `.test-keys/`, `.venv/`.
- **No production private key** is created or committed here.
- A **non-production TEST key** is generated at random by
  `tests/make_test_key.py` into the git-ignored `.test-keys/` directory for the
  automated tests. Its private-key PEM is external and never committed; no
  private scalar is embedded in any source file. It must never be used for real
  codes.

## CLI

```
# Generate a TEMPORARY license (months 1..120)
.venv/bin/python license_generator.py generate \
    --serial KCG_1234ABCD --type TEMPORARY --date 2026-09-15 --months 6 \
    --key-file ./path/to/private.pem

# Generate a PERMANENT license (months must be 0)
.venv/bin/python license_generator.py generate \
    --serial KCG_1234ABCD --type PERMANENT --date 2026-09-15 \
    --key-file ./path/to/private.pem

# Verify a code using ONLY a PUBLIC key (no private key required)
.venv/bin/python license_generator.py verify \
    --code <CODE> --public-key 04E67B...99266
# or from a public-key file (PEM public key or 04||X||Y hex)
.venv/bin/python license_generator.py verify \
    --code <CODE> --public-key-file ./path/to/public_key.pem

# Inspect a code's metadata WITHOUT verifying (no key needed)
.venv/bin/python license_generator.py inspect --code <CODE>

# Export the public key (hex + C array for license_pubkey.h) — NEVER the private key
.venv/bin/python license_generator.py public-key --key-file ./private.pem
```

The `public-key` command prints the `LICENSE_PUBKEY[65]` C array — paste it into
`license_pubkey.h` when a real key is available (set `PUBLIC_KEY_CONFIGURED 1`).
It prints **only** the public key (hex + C array); it never prints the private
key scalar or any private key material. The existing placeholder
`license_pubkey.h` is **not** modified by this tool.

## Creation Date semantics

Creation Date is a **validated field inside the signed payload**; it is **not**
used as the activation date. The device computes the real activation date from
**NTP time** at the moment a code is accepted, and expiration =
`NTP activation date + months`, with the firmware's calendar-aware / day-clamped
math. The generator's displayed "Expiration" is therefore informational.

## Tests

```bash
# 1. Build the two end-to-end firmware-compat harnesses (requires BearSSL).
#    BEARSSL_INC  -> dir containing bearssl/bearssl.h  (e.g. .../bearssl inc/)
#    BEARSSL_LIB  -> path to libbearssl.a
#
# 1a. Default harness using the git-ignored RANDOM external TEST key
#     (used by the generator tests). Also generates that key if missing.
BEARSSL_INC=/tmp/bearssl-host-inc \
BEARSSL_LIB=/tmp/bearssl-src/build/libbearssl.a \
  python3 tests/build_compat.sh                                  # -> /tmp/compat/testing_compat

# 1b. Known-answer harness compiled with the fixed PUBLIC-only witness key,
#     used by the [known-answer] regression vector.
BEARSSL_INC=/tmp/bearssl-host-inc \
BEARSSL_LIB=/tmp/bearssl-src/build/libbearssl.a \
  COMPAT_OUT=/tmp/compat/testing_compat_known PUBKEY_HEADER=known_pubkey.h \
  python3 tests/build_compat.sh

# 2. Run the full suite (66 checks) incl. firmware compatibility + known-answer.
COMPAT_BIN=/tmp/compat/testing_compat \
COMPAT_KNOWN_BIN=/tmp/compat/testing_compat_known \
  .venv/bin/python tests/test_license_generator.py
```

The test suite covers: temp 1/6/12-month, permanent, invalid serial, invalid
months, invalid date, Base32 round-trip + strictness (lowercase / padding /
separator / non-canonical bits rejected), signature verify, wrong serial,
modified payload, modified signature, generated code **accepted by the real
firmware verifier** (device serial `KCG_1234ABCD`), **device binding** (a valid
signed code for `KCG_00000000` is **rejected** by firmware activation with
reason `SERIAL_MISMATCH`), a **fixed known-answer regression vector** (the
approved Stage 4 public-only witness: SHA-256, raw r||s, 133-char Base32, and
both firmware accept + SERIAL_MISMATCH on a different device), and that no
private key is tracked or embedded by Git.

## Known-answer regression fixture

`tests/test_license_generator.py` carries a fixed, **public-only** witness
vector (serial `KCG_1234ABCD`, TEMPORARY, `2026-09-15`, months 6). It checks the
known payload hex, SHA-256 hash, raw 64-byte `r||s` signature, and 133-char
Base32 code, verifies the signature with the known **public** key, and feeds the
code through the real firmware decoder / BearSSL verifier / activation path. The
matching private key is **not** present and is never reconstructed here. The
random external TEST key remains used only by the generator tests.

## End-to-end compatibility proof

`testing_compat.cpp` feeds a generated Base32 code through the **real** firmware
functions:

```
license_decode_base32 -> verify_ecdsa_p256_sha256 -> license_attempt_activate
```

It is compiled against the actual `firmware/car_guard/license.cpp`,
`license_helpers.cpp` and `license.h`, linked with real BearSSL, and uses the
matching TEST public key (`PUBLIC_KEY_CONFIGURED=1`) from the git-ignored
`.test-keys/test_pubkey.h`. A code produced by the Python generator is accepted
on the host device serial `KCG_1234ABCD` (prints `COMPAT_OK`).

The harness also proves **device binding**: a valid signed code for a different
serial is passed in `reject:SERIAL_MISMATCH` mode, and activation must fail with
reason `SERIAL_MISMATCH` (prints `COMPAT_REJECTED ... reason=SERIAL_MISMATCH`)
even though the signature is cryptographically valid.
