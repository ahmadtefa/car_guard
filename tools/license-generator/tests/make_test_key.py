#!/usr/bin/env python3
"""Write a deterministic NON-PRODUCTION TEST signing key to .test-keys/test_key.pem.

This is the ONLY key used by the automated tests. It is derived from the
spec-lock TEST scalar, is never committed (git-ignored under .test-keys/),
and MUST NOT be used for any real production license.
"""
import sys
from pathlib import Path

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import ec

# Spec-lock TEST (non-production) scalar — 32 bytes.
TEST_SCALAR = 0x1A2B3C4D5E6F708192A3B4C5D6E7F809112233445566778899AABBCCDDEEFF21


def main(out_path: str = ".test-keys/test_key.pem") -> Path:
    key = ec.derive_private_key(TEST_SCALAR, ec.SECP256R1())
    pem = key.private_bytes(
        serialization.Encoding.PEM,
        serialization.PrivateFormat.PKCS8,
        serialization.NoEncryption(),
    )
    out = Path(out_path)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(pem)
    print("TEST key written to %s" % out)
    return out


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else ".test-keys/test_key.pem")
