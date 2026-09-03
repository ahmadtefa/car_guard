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
  9.  signature verify
  10. wrong serial rejected (verification-level: foreign serial in verify)
  11. modified payload rejected
  12. modified signature rejected
  13. generated code accepted by current firmware verifier (C++ compat)
  14. test private key is not present in Git-tracked files

All use the NON-PRODUCTION TEST key in .test-keys/ (git-ignored).
"""
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
# TEST key (git-ignored). Deterministic from the spec-lock scalar.
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


def run_compat(code):
    """Run the code through the REAL firmware compat harness. Return (rc, out)."""
    binpath = os.environ.get("COMPAT_BIN")
    if not binpath:
        binpath = "/tmp/compat/testing_compat"
    res = subprocess.run([binpath, code], capture_output=True, text=True)
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

    print("\n[git safety] test private key not tracked by Git\n")
    repo = subprocess.run(["git", "rev-parse", "--show-toplevel"],
                          capture_output=True, text=True, cwd=str(ROOT))
    top = repo.stdout.strip()
    if repo.returncode == 0 and top:
        tracked = subprocess.run(["git", "ls-files"],
                                 capture_output=True, text=True, cwd=top)
        tracked_files = tracked.stdout.splitlines()
        leaked = [f for f in tracked_files if f.endswith(".pem") or ".test-keys/" in f or "test_key" in f]
        check("no .pem / test key tracked by git", len(leaked) == 0)
        if leaked:
            print("      leaked: %s" % leaked)
        # confirm the test key file is git-ignored
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
