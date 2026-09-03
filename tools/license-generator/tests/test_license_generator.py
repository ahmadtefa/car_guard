#!/usr/bin/env python3
"""Automated tests for the Stage 4 License Generator.

Covers the required cases:
  1.  Temporary 1 month
  2.  Temporary 6 months
  3.  Temporary 12 months
  4.  Permanent
  5.  invalid serial
  6.  invalid months
  7.  invalid date
  8.  Base32 round-trip
  9.  strict Base32 rejection (lowercase / padding / separator / non-canonical)
  10. signature verify
  11. wrong serial: foreign serial produces a cryptographically valid signature
  12. wrong-device binding: a valid signed code for KCG_00000000 is REJECTED by
      the real firmware activation with reason SERIAL_MISMATCH
  13. modified payload rejected
  14. modified signature rejected
  15. generated code accepted by current firmware verifier (C++ compat):
      temp 1/6/12-month + permanent for the device serial KCG_1234ABCD
  16. test private key is not present in Git-tracked files and stays git-ignored

All use the NON-PRODUCTION TEST key in .test-keys/ (git-ignored).
"""
import hashlib
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path.insert(0, str(ROOT))

import license_generator as lg


# ---------------------------------------------------------------------
# Stage 4 approved known-answer vector — PUBLIC ONLY (no private key).
#
# This is a fixed regression fixture used to VERIFY a known-good license code
# against the known public key and the real firmware (decoder + BearSSL
# verifier + activation). The matching private key is intentionally NOT
# present anywhere; it must never be reconstructed here.
# ---------------------------------------------------------------------
KNOWN_PUBKEY = (
    "04E67B1EC6B06DE9B679935F9D594303333EF313335C4233C78513C15780328CBC"
    "727C3A9276F531BAC33F06B63DB4C33878015E86A9F4BFF1A2C318D9EEE99266"
)
KNOWN_PAYLOAD_HEX = "014B43475F31323334414243440007EA090F06"
KNOWN_SHA256 = "3C991B78E57F892360656CB77EBFBCA398A83ABF944912F9C66A26EF842F39AC"
KNOWN_R = "5325458CCF10592ADC37C2FCA15CA42BEAEB5C94F996A1E84A2D0DD6EB1E08BB"
KNOWN_S = "7E4745906DC89AE6FB056EF47485E66B65AED1E57BB13D88340D0806A8B1E2A2"
KNOWN_BASE32 = (
    "AFFUGR27GEZDGNCBIJBUIAAH5IEQ6BSTEVCYZTYQLEVNYN6C7SQVZJBL5LVVZFHZS2Q6QS"
    "RNBXLOWHQIXN7EORMQNXEJVZX3AVXPI5EF4ZVWLLWR4V53CPMIGQGQQBVIWHRKE"
)
KNOWN_SERIAL = "KCG_1234ABCD"
KNOWN_TYPE = "TEMPORARY"
KNOWN_DATE = "2026-09-15"
KNOWN_MONTHS = 6

# ---------------------------------------------------------------------
# TEST key (git-ignored). Generated externally; never committed.
# ---------------------------------------------------------------------
TEST_KEY = ROOT / ".test-keys" / "test_key.pem"


def _ensure_test_key():
    if not TEST_KEY.exists():
        subprocess.run(
            [sys.executable, str(HERE / "make_test_key.py"), str(TEST_KEY)],
            check=True,
        )
    return TEST_KEY


def _load_key():
    _ensure_test_key()
    return lg.load_private_key(TEST_KEY)


# ---------------------------------------------------------------------
# Little test runner (no external dependency: no pytest required).
# ---------------------------------------------------------------------
_passed = 0
_failed = 0


def check(name, cond):
    global _passed, _failed
    if cond:
        _passed += 1
        print("  [PASS] %s" % name)
    else:
        _failed += 1
        print("  [FAIL] %s" % name)


def expect_error(name, fn, needle=None):
    global _passed, _failed
    try:
        fn()
    except lg.GeneratorError as e:
        ok = (needle is None) or (needle.lower() in str(e).lower())
        if ok:
            _passed += 1
            print("  [PASS] %s -> %s" % (name, e))
        else:
            _failed += 1
            print("  [FAIL] %s raised wrong message: %s" % (name, e))
        return
    _failed += 1
    print("  [FAIL] %s did NOT raise GeneratorError" % name)


def run_compat(code, mode="accept", binpath=None, env=None):
    """Run the code through the REAL firmware compat harness.

    `mode` is passed to the harness: "accept" (default), "reject", or a
    "reject:REASON" string (e.g. "reject:SERIAL_MISMATCH"). `binpath` overrides
    the harness binary (default $COMPAT_BIN or /tmp/compat/testing_compat). `env`
    adds environment (e.g. TEST_CHIP_ID to change the device serial). Return
    (rc, out); a missing binary returns (127, ...) rather than raising.
    """
    if binpath is None:
        binpath = os.environ.get("COMPAT_BIN")
    if not binpath:
        binpath = "/tmp/compat/testing_compat"
    if not os.path.isfile(binpath):
        return 127, "compat harness not found: %s" % binpath
    cmd = [binpath, code]
    if mode and mode != "accept":
        cmd.append(mode)
    run_env = dict(os.environ)
    if env:
        run_env.update(env)
    res = subprocess.run(cmd, capture_output=True, text=True, env=run_env)
    return res.returncode, (res.stdout + res.stderr)


def main():
    print("=== Stage 4 License Generator tests ===")
    key = _load_key()
    pub = key.public_key()
    creation = lg.parse_date("2026-09-15")
    serial = "KCG_1234ABCD"

    print("\n[generate] temporary months across 1/6/12 + permanent\n")
    for months in (1, 6, 12):
        code = lg.generate_code(serial, lg.LICENSE_TEMPORARY, creation, months, key)
        check("temp %2d month: 133 chars" % months, len(code) == 133)
        # decode + verify independently
        data = lg.base32_decode(code)
        check("temp %2d month: decoded 83 bytes" % months, len(data) == 83)
        check("temp %2d month: verify ok" % months,
              lg.verify_signature(data[:19], data[19:], pub))
        meta = lg.parse_payload(data[:19])
        check("temp %2d month: months==%d" % (months, months), meta["months"] == months)

    perm_code = lg.generate_code(serial, lg.LICENSE_PERMANENT, creation, 0, key)
    perm_data = lg.base32_decode(perm_code)
    check("permanent: 133 chars", len(perm_code) == 133)
    check("permanent: months==0", lg.parse_payload(perm_data[:19])["months"] == 0)
    check("permanent: valid signature", lg.verify_signature(perm_data[:19], perm_data[19:], pub))

    print("\n[validation] input rejection\n")
    expect_error("empty serial", lambda: lg.validate_serial(""))
    expect_error("serial no prefix", lambda: lg.validate_serial("ABCD1234ABCD"))
    expect_error("serial lowercase", lambda: lg.validate_serial("KCG_1234abcd"))
    expect_error("serial too short", lambda: lg.validate_serial("KCG_1234ABC"))
    expect_error("serial wrong chars", lambda: lg.validate_serial("KCG_1234ZZZZ"))

    expect_error("temp months 0", lambda: lg.validate_months(lg.LICENSE_TEMPORARY, 0))
    expect_error("temp months negative", lambda: lg.validate_months(lg.LICENSE_TEMPORARY, -1))
    expect_error("temp months >120", lambda: lg.validate_months(lg.LICENSE_TEMPORARY, 121))
    expect_error("perm months nonzero", lambda: lg.validate_months(lg.LICENSE_PERMANENT, 3))

    expect_error("invalid date Feb 30", lambda: lg.validate_date(2026, 2, 30))
    expect_error("invalid date month 13", lambda: lg.validate_date(2026, 13, 1))
    expect_error("invalid date day 0", lambda: lg.validate_date(2026, 1, 0))

    print("\n[base32] round-trip + strictness\n")
    raw = bytes(range(83))
    enc = lg.base32_encode(raw)
    check("base32 encode 83B -> 133 chars", len(enc) == 133)
    check("base32 round-trip", lg.base32_decode(enc) == raw)
    check("no padding", "=" not in enc)
    check("uppercase only", enc.isupper())
    # invalid chars
    expect_error("lowercase rejected", lambda: lg.base32_decode(enc.lower()))
    expect_error("padding rejected", lambda: lg.base32_decode(enc + "="))
    expect_error("separator rejected", lambda: lg.base32_decode(enc[:60] + "-" + enc[60:]))
    # non-canonical trailing bits: craft a code whose last symbol has a set pad bit
    bad = enc[:-1] + "B"  # 'B' has trailing bits that may produce nonzero leftover
    try:
        lg.base32_decode(bad)
        check("non-canonical trailing bits rejected", False)
    except lg.GeneratorError:
        check("non-canonical trailing bits rejected", True)

    print("\n[signature] verify + tamper rejection\n")
    code = lg.generate_code(serial, lg.LICENSE_TEMPORARY, creation, 6, key)
    data = lg.base32_decode(code)
    check("valid signature accepted", lg.verify_signature(data[:19], data[19:], pub))

    # modified payload
    mod_payload = bytearray(data[:19]); mod_payload[1] ^= 0x01
    check("modified payload rejected",
          not lg.verify_signature(bytes(mod_payload), data[19:], pub))
    # modified signature
    mod_sig = bytearray(data[19:]); mod_sig[20] ^= 0x01
    check("modified signature rejected", not lg.verify_signature(data[:19], bytes(mod_sig), pub))

    # wrong serial at verification: sign a code for a DIFFERENT device, verify as expected
    wrong_serial = "KCG_00000000"
    wrong_code = lg.generate_code(wrong_serial, lg.LICENSE_TEMPORARY, creation, 6, key)
    wrong_data = lg.base32_decode(wrong_code)
    check("wrong serial: signature still verifies (crypto)",
          lg.verify_signature(wrong_data[:19], wrong_data[19:], pub))
    check("wrong serial: payload serial == KCG_00000000",
          lg.parse_payload(wrong_data[:19])["serial"] == wrong_serial)

    print("\n[known-answer] fixed Stage 4 regression vector (public key only)\n")
    known_payload = bytes.fromhex(KNOWN_PAYLOAD_HEX)
    known_sig = bytes.fromhex(KNOWN_R + KNOWN_S)
    known_decoded = known_payload + known_sig
    check("known-answer: payload is 19 bytes", len(known_payload) == 19)
    check("known-answer: signature is 64 bytes", len(known_sig) == 64)
    check("known-answer: decoded is 83 bytes", len(known_decoded) == 83)

    # SHA-256 of the 19-byte payload matches the vector.
    check("known-answer: SHA-256(payload) matches",
          hashlib.sha256(known_payload).hexdigest().upper() == KNOWN_SHA256)

    # Public key loads and VERIFIES the signature (Python cryptography).
    known_pub = lg.load_public_key(KNOWN_PUBKEY)
    check("known-answer: public key loads as P-256", known_pub.curve.name == "secp256r1")
    check("known-answer: signature verifies with known public key",
          lg.verify_signature(known_payload, known_sig, known_pub))

    # Base32 code round-trips to the exact known string.
    check("known-answer: Base32 decodes to payload||sig",
          lg.base32_decode(KNOWN_BASE32) == known_decoded)
    check("known-answer: Base32 encode of payload||sig matches known code",
          lg.base32_encode(known_decoded) == KNOWN_BASE32)
    check("known-answer: Base32 is 133 chars and matches",
          len(KNOWN_BASE32) == 133 and KNOWN_BASE32.isupper() and "=" not in KNOWN_BASE32)

    # Payload metadata parses to the expected values.
    kmeta = lg.parse_payload(known_payload)
    check("known-answer: payload serial == %s" % KNOWN_SERIAL, kmeta["serial"] == KNOWN_SERIAL)
    check("known-answer: payload type == %s" % KNOWN_TYPE, kmeta["type"] == KNOWN_TYPE)
    check("known-answer: payload date == %s" % KNOWN_DATE,
          str(kmeta["creation"]) == KNOWN_DATE)
    check("known-answer: payload months == %d" % KNOWN_MONTHS, kmeta["months"] == KNOWN_MONTHS)

    # Real firmware path (known pubkey binary): must accept on the matched
    # device and reject (SERIAL_MISMATCH) on a non-matching device.
    known_bin = os.environ.get("COMPAT_KNOWN_BIN", "/tmp/compat/testing_compat_known")
    rc, out = run_compat(KNOWN_BASE32, "accept", binpath=known_bin)
    ok = (rc == 0) and ("COMPAT_OK" in out) and ("serial=%s" % KNOWN_SERIAL in out)
    check("known-answer: firmware accepts code on device %s" % KNOWN_SERIAL, ok)
    if not ok:
        print("      rc=%d out=%s" % (rc, out.strip()))

    rc, out = run_compat(KNOWN_BASE32, "reject:SERIAL_MISMATCH",
                         binpath=known_bin, env={"TEST_CHIP_ID": "00000000"})
    ok = (rc == 0) and ("COMPAT_REJECTED" in out) and ("reason=SERIAL_MISMATCH" in out)
    check("known-answer: firmware rejects code on device KCG_00000000 (SERIAL_MISMATCH)", ok)
    if not ok:
        print("      rc=%d out=%s" % (rc, out.strip()))

    print("\n[end-to-end] generator -> firmware verifier (real C++ harness)\n")
    for months in (1, 6, 12):
        c = lg.generate_code(serial, lg.LICENSE_TEMPORARY, creation, months, key)
        rc, out = run_compat(c)
        ok = (rc == 0) and ("COMPAT_OK" in out)
        check("firmware accepts temp %2d-month code" % months, ok)
        if not ok:
            print("      rc=%d out=%s" % (rc, out.strip()))
    pc = lg.generate_code(serial, lg.LICENSE_PERMANENT, creation, 0, key)
    rc, out = run_compat(pc)
    check("firmware accepts permanent code", (rc == 0) and ("COMPAT_OK" in out))

    # Device binding: a code for a DIFFERENT serial must be cryptographically
    # valid but REJECTED by firmware activation because it is not bound to this
    # device (host device serial = KCG_1234ABCD).
    foreign = "KCG_00000000"
    foreign_code = lg.generate_code(foreign, lg.LICENSE_TEMPORARY, creation, 6, key)
    foreign_data = lg.base32_decode(foreign_code)
    check("wrong-device code: 133 chars", len(foreign_code) == 133)
    check("wrong-device code: cryptographically valid (public key verifies)",
          lg.verify_signature(foreign_data[:19], foreign_data[19:], pub))
    check("wrong-device code: payload serial == %s" % foreign,
          lg.parse_payload(foreign_data[:19])["serial"] == foreign)
    rc, out = run_compat(foreign_code, "reject:SERIAL_MISMATCH")
    ok = (rc == 0) and ("COMPAT_REJECTED" in out) and ("reason=SERIAL_MISMATCH" in out)
    check("wrong-device code: firmware rejects activation (SERIAL_MISMATCH)", ok)
    if not ok:
        print("      rc=%d out=%s" % (rc, out.strip()))

    print("\n[git safety] no private key tracked or embedded by Git\n")
    repo = subprocess.run(["git", "rev-parse", "--show-toplevel"],
                          capture_output=True, text=True, cwd=str(ROOT))
    top = repo.stdout.strip()
    if repo.returncode == 0 and top:
        tracked = subprocess.run(["git", "ls-files"],
                                 capture_output=True, text=True, cwd=top)
        tracked_files = tracked.stdout.splitlines()

        # (a) No private-key files (or .test-keys/ artifacts) are tracked.
        key_ext = (".pem", ".key", ".der", ".p12", ".pfx", ".crt")
        leaked = [f for f in tracked_files
                  if f.lower().endswith(key_ext)
                  or "/.test-keys/" in f
                  or f.startswith(".test-keys/")]
        check("no private key file tracked by git", len(leaked) == 0)
        if leaked:
            print("      leaked: %s" % leaked)

        # (b) No tracked source EMBEDS a private key (any PEM private-key block).
        # Markers are built by concatenation so the scanner itself does not
        # literally contain the contiguous PEM header/footer text.
        begin_marker = "-----" + "BEGIN"
        key_marker = "PRIVATE KEY" + "-----"
        embedded = []
        for f in tracked_files:
            fp = os.path.join(top, f)
            if os.path.isfile(fp):
                try:
                    with open(fp, "r", errors="replace") as fh:
                        c = fh.read()
                        if (begin_marker in c) and (key_marker in c):
                            embedded.append(f)
                except Exception:
                    pass
        check("no private key embedded in tracked source", len(embedded) == 0)
        if embedded:
            print("      embedded: %s" % embedded)

        # (c) The external TEST key file is git-ignored and not tracked.
        ignored = subprocess.run(["git", "check-ignore", "-q", str(TEST_KEY)],
                                 capture_output=True, cwd=top)
        check("test key file is git-ignored", ignored.returncode == 0)
    else:
        check("repo root resolved", False)

    print()
    print("====================================================")
    print("RESULT: %d passed, %d failed" % (_passed, _failed))
    print("====================================================")
    return 1 if _failed else 0


if __name__ == "__main__":
    sys.exit(main())
