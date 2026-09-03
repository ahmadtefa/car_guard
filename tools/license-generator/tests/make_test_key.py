#!/usr/bin/env python3
"""Create a NON-PRODUCTION TEST signing keypair for the automated tests.

Writes into the git-ignored .test-keys/ directory:

  test_key.pem     EC P-256 PRIVATE key (PKCS8, unencrypted)
  test_pubkey.hex  uncompressed public point 04||X||Y (65 bytes) as hex
  test_pubkey.h    C array defining LICENSE_PUBKEY for the compat harness

Security:
  * No private key scalar is embedded in any source file.
  * The private key is external-only (on disk) and .test-keys/ is git-ignored,
    so it is NEVER committed to Git.
  * This is a NON-PRODUCTION test key. It is NOT a real device key.
  * When the test key already exists, it is left unchanged (idempotent) so the
    prebuilt compat harness's public key stays in sync.

Run as:  python3 tests/make_test_key.py  [output_dir]
"""
import sys
from pathlib import Path

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import ec


def pubkey_c_array(xy: bytes, array_name: str = "LICENSE_PUBKEY") -> str:
    """C array DEFINITION of the uncompressed public point.

    Only defines the `LICENSE_PUBKEY` array (exactly 65 bytes). The
    `LICENSE_PUBKEY_LEN` compile-time constant and the `extern` declaration are
    already provided by the real firmware `license_pubkey.h`, which this header
    must not redefine.
    """
    lines = ["const uint8_t %s[%d] = {" % (array_name, len(xy))]
    for i in range(0, len(xy), 12):
        chunk = ", ".join("0x%02X" % b for b in xy[i:i + 12])
        lines.append("    %s," % chunk)
    lines.append("};")
    return "\n".join(lines)


def main(out_dir: str = ".test-keys") -> Path:
    d = Path(out_dir)
    d.mkdir(parents=True, exist_ok=True)

    key_path = d / "test_key.pem"
    pub_hex_path = d / "test_pubkey.hex"
    pub_h_path = d / "test_pubkey.h"

    if key_path.exists() and pub_hex_path.exists() and pub_h_path.exists():
        # Idempotent: keep the existing external key so the harness stays in sync.
        xy = bytes.fromhex(pub_hex_path.read_text().strip())
        print("TEST key already present (using existing external key): %s" % key_path)
        print("TEST PUBLIC KEY (04||X||Y):")
        print(xy.hex())
        return key_path

    # Generate a fresh random P-256 keypair. No scalar is hardcoded anywhere.
    key = ec.generate_private_key(ec.SECP256R1())
    pem = key.private_bytes(
        serialization.Encoding.PEM,
        serialization.PrivateFormat.PKCS8,
        serialization.NoEncryption(),
    )
    xy = key.public_key().public_bytes(
        serialization.Encoding.X962,
        serialization.PublicFormat.UncompressedPoint,
    )

    key_path.write_bytes(pem)
    pub_hex_path.write_text(xy.hex() + "\n")
    pub_h_path.write_text(pubkey_c_array(xy) + "\n")

    print("TEST key written to %s" % key_path)
    print("TEST PUBLIC KEY (04||X||Y):")
    print(xy.hex())
    return key_path


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else ".test-keys")
