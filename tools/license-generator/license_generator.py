#!/usr/bin/env python3
# =====================================================================
#  CarGuard License Generator  (Stage 4)
#
#  Standalone, firmware-compatible desktop generator. Produces the exact
#  license code the ESP8266 firmware (firmware/car_guard/license.cpp /
#  license_helpers.cpp) decodes and verifies:
#
#    payload (19 bytes) || raw ECDSA P-256 r||s (64 bytes) = 83 bytes
#    -> RFC4648 Base32 (uppercase, no padding, no separators) = 133 chars
#
#  Crypto: `cryptography` (P-256 + SHA-256, deterministic RFC 6979 k is NOT
#  used — a per-signature random nonce is used, which is standard and secure).
#  The public key is exported as the uncompressed P-256 point 04||X||Y (65 B),
#  exactly matching what verify_ecdsa_p256_sha256() in the firmware expects.
#
#  The private key is NEVER embedded here. It is loaded from an external PEM
#  file (see --key-file). A TEST key (also an external PEM) is used only by
#  the automated tests and is git-ignored.
# =====================================================================

import argparse
import base64
import datetime
import re
import sys
from pathlib import Path

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.asymmetric.ec import EllipticCurvePrivateKey, EllipticCurvePublicKey
from cryptography.hazmat.primitives.asymmetric.utils import (
    decode_dss_signature,
    encode_dss_signature,
)

# ---------------------------------------------------------------------
# Firmware constants (must match license.h / license_helpers.cpp exactly)
# ---------------------------------------------------------------------
PAYLOAD_LEN = 19
SIG_LEN = 64
DECODED_LEN = 83          # 19 + 64
SERIAL_LEN = 12
BASE32_LEN = 133          # ceil(83*8/5)

VERSION = 0x01
LICENSE_TEMPORARY = 0
LICENSE_PERMANENT = 1

MAX_MONTHS = 120

# Device serial format enforced by the firmware: "KCG_" + 8 uppercase hex.
SERIAL_RE = re.compile(r"^KCG_[0-9A-F]{8}$")

# RFC4648 alphabet for the encoder. The firmware decoder only accepts
# 'A'-'Z' and '2'-'7' (uppercase, no padding, no separators).
BASE32_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"


class GeneratorError(Exception):
    """Raised on invalid input or a user-facing generator error."""


# ---------------------------------------------------------------------
# Validation helpers
# ---------------------------------------------------------------------
def validate_serial(serial: str) -> str:
    if not serial:
        raise GeneratorError("Device serial is required")
    if not SERIAL_RE.match(serial):
        raise GeneratorError(
            "Invalid serial '%s' — must match KCG_[0-9A-F]{8} (e.g. KCG_1A2B3C4D)" % serial
        )
    if len(serial) != SERIAL_LEN:
        raise GeneratorError("Serial must be exactly 12 characters")
    return serial.upper()


def validate_type(license_type: str) -> int:
    t = license_type.strip().upper()
    if t in ("TEMPORARY", "TEMP", "0"):
        return LICENSE_TEMPORARY
    if t in ("PERMANENT", "PERM", "1"):
        return LICENSE_PERMANENT
    raise GeneratorError("Invalid license type '%s' — use TEMPORARY or PERMANENT" % license_type)


def validate_months(license_type: int, months: int) -> int:
    if license_type == LICENSE_PERMANENT:
        if months != 0:
            raise GeneratorError("PERMANENT license must have months = 0 (got %d)" % months)
        return 0
    # temporary
    if months < 1 or months > MAX_MONTHS:
        raise GeneratorError(
            "TEMPORARY license months must be 1..%d (got %d)" % (MAX_MONTHS, months)
        )
    return months


def validate_date(year: int, month: int, day: int) -> datetime.date:
    try:
        d = datetime.date(year, month, day)
    except ValueError as e:
        raise GeneratorError("Invalid creation date %04d-%02d-%02d: %s" % (year, month, day, e))
    return d


def parse_date(s: str) -> datetime.date:
    """Accept YYYY-MM-DD (and YYYY/M/D variants)."""
    s = s.strip()
    for fmt in ("%Y-%m-%d", "%Y/%m/%d", "%Y-%m-%d", "%Y/%m/%d"):
        try:
            return datetime.datetime.strptime(s, fmt).date()
        except ValueError:
            continue
    raise GeneratorError("Invalid date '%s' — use YYYY-MM-DD" % s)


# ---------------------------------------------------------------------
# Payload building (19 bytes, byte-exact to the firmware parser)
# ---------------------------------------------------------------------
def build_payload(serial: str, license_type: int, creation: datetime.date, months: int) -> bytes:
    payload = bytearray(PAYLOAD_LEN)

    payload[0] = VERSION                                   # protocol version

    # serial: bytes 1..12, left-aligned, right-padded with spaces (0x20)
    serial = validate_serial(serial)
    raw = serial.encode("ascii")
    if len(raw) > SERIAL_LEN:
        raise GeneratorError("Serial too long for the 12-byte field")
    for i in range(SERIAL_LEN):
        payload[1 + i] = raw[i] if i < len(raw) else 0x20

    payload[13] = license_type                             # 0 = temp, 1 = perm

    # year: bytes 14..15 big-endian
    payload[14] = (creation.year >> 8) & 0xFF
    payload[15] = creation.year & 0xFF

    payload[16] = creation.month
    payload[17] = creation.day

    payload[18] = months

    return bytes(payload)


def parse_payload(payload: bytes) -> dict:
    """Decode and validate a 19-byte payload, mirroring license_parse_payload."""
    if len(payload) != PAYLOAD_LEN:
        raise GeneratorError("Payload must be exactly %d bytes" % PAYLOAD_LEN)

    version = payload[0]
    if version != VERSION:
        raise GeneratorError("Unsupported payload version 0x%02X" % version)

    serial_bytes = payload[1:13]
    # strip trailing space padding
    serial = serial_bytes.decode("ascii").rstrip(" ")
    if not SERIAL_RE.match(serial):
        raise GeneratorError("Serial in payload is invalid: %r" % serial)

    license_type = payload[13]
    if license_type not in (LICENSE_TEMPORARY, LICENSE_PERMANENT):
        raise GeneratorError("Invalid license type 0x%02X in payload" % license_type)

    year = (payload[14] << 8) | payload[15]
    month = payload[16]
    day = payload[17]
    months = payload[18]

    validate_date(year, month, day)  # raises if not a real calendar date

    if license_type == LICENSE_TEMPORARY and months == 0:
        raise GeneratorError("TEMPORARY payload has months == 0")
    if license_type == LICENSE_PERMANENT and months != 0:
        raise GeneratorError("PERMANENT payload has months != 0")
    if license_type == LICENSE_TEMPORARY and (months < 1 or months > MAX_MONTHS):
        raise GeneratorError("TEMPORARY months out of range: %d" % months)

    return {
        "version": version,
        "serial": serial,
        "type": "TEMPORARY" if license_type == LICENSE_TEMPORARY else "PERMANENT",
        "license_type": license_type,
        "year": year,
        "month": month,
        "day": day,
        "creation": datetime.date(year, month, day),
        "months": months,
    }


# ---------------------------------------------------------------------
# Base32 (RFC4648 uppercase, no padding, strict)
# ---------------------------------------------------------------------
def base32_encode(data: bytes) -> str:
    if not data:
        return ""
    out = []
    bits = 0
    buffer = 0
    for b in data:
        buffer = (buffer << 8) | b
        bits += 8
        while bits >= 5:
            bits -= 5
            out.append(BASE32_ALPHABET[(buffer >> bits) & 0x1F])
    if bits > 0:
        # canonical trailing zero bits
        out.append(BASE32_ALPHABET[(buffer << (5 - bits)) & 0x1F])
    return "".join(out)


def base32_decode(code: str, *, strict: bool = True) -> bytes:
    """Strict RFC4648 uppercase decode mirroring the firmware decoder.

    Rejects lowercase, padding ('='), separators, and non-canonical trailing
    bits. When strict=False, whitespace is ignored (for lenient reads only).
    """
    if strict:
        s = code
    else:
        s = "".join(ch for ch in code if not ch.isspace())

    if not s:
        raise GeneratorError("Empty Base32 code")

    bits = 0
    buffer = 0
    out = bytearray()
    for ch in s:
        val = -1
        if "A" <= ch <= "Z":
            val = ord(ch) - ord("A")
        elif "2" <= ch <= "7":
            val = 26 + (ord(ch) - ord("2"))
        if val < 0:
            raise GeneratorError("Invalid Base32 character %r (must be A-Z or 2-7)" % ch)
        buffer = (buffer << 5) | val
        bits += 5
        while bits >= 8:
            bits -= 8
            out.append((buffer >> bits) & 0xFF)

    # non-canonical trailing bits must be zero (matches firmware)
    if bits > 0:
        if (buffer & ((1 << bits) - 1)) != 0:
            raise GeneratorError("Non-canonical trailing bits in Base32 code")

    return bytes(out)


# ---------------------------------------------------------------------
# Signing / verification
# ---------------------------------------------------------------------
def load_private_key(path) -> EllipticCurvePrivateKey:
    if isinstance(path, str):
        path = Path(path)
    if not path.exists():
        raise GeneratorError("Private key file not found: %s" % path)
    data = path.read_bytes()
    try:
        key = serialization.load_pem_private_key(data, password=None)
    except Exception as e:
        raise GeneratorError("Could not load private key: %s" % e)
    if not isinstance(key, EllipticCurvePrivateKey):
        raise GeneratorError("Loaded key is not an EC private key")
    if key.curve.name != "secp256r1":
        raise GeneratorError("Key must be on secp256r1 (P-256), got %s" % key.curve.name)
    return key


def load_public_key_bytes(key: EllipticCurvePrivateKey) -> bytes:
    pk = key.public_key()
    return pk.public_bytes(
        serialization.Encoding.X962,
        serialization.PublicFormat.UncompressedPoint,
    )


def private_key_scalar_hex(key: EllipticCurvePrivateKey) -> str:
    return "%064X" % key.private_numbers().private_value


def sign_payload(payload: bytes, key: EllipticCurvePrivateKey) -> bytes:
    if len(payload) != PAYLOAD_LEN:
        raise GeneratorError("Payload must be %d bytes" % PAYLOAD_LEN)
    der = key.sign(payload, ec.ECDSA(hashes.SHA256()))
    r, s = decode_dss_signature(der)
    # each component exactly 32-byte big-endian
    return r.to_bytes(32, "big") + s.to_bytes(32, "big")


def verify_signature(payload: bytes, signature: bytes, public_key: EllipticCurvePublicKey) -> bool:
    if len(signature) != SIG_LEN:
        return False
    r = int.from_bytes(signature[:32], "big")
    s = int.from_bytes(signature[32:], "big")
    der = encode_dss_signature(r, s)
    try:
        public_key.verify(der, payload, ec.ECDSA(hashes.SHA256()))
        return True
    except Exception:
        return False


def load_public_key(public_xy_hex: str) -> EllipticCurvePublicKey:
    xy = bytes.fromhex(public_xy_hex)
    if len(xy) != 65 or xy[0] != 0x04:
        raise GeneratorError("Public key must be 04||X||Y (65 bytes)")
    x = int.from_bytes(xy[1:33], "big")
    y = int.from_bytes(xy[33:], "big")
    return ec.EllipticCurvePublicNumbers(x, y, ec.SECP256R1()).public_key()


# ---------------------------------------------------------------------
# High-level generator
# ---------------------------------------------------------------------
def generate_code(serial, license_type, creation: datetime.date, months, key) -> str:
    months = validate_months(license_type, months)
    payload = build_payload(serial, license_type, creation, months)
    signature = sign_payload(payload, key)
    decoded = payload + signature
    if len(decoded) != DECODED_LEN:
        raise GeneratorError("Internal: decoded length %d != 83" % len(decoded))
    return base32_encode(decoded)


def decode_and_verify(code: str, key: EllipticCurvePrivateKey) -> dict:
    """Decode a code, verify it against the key's public key, and parse metadata."""
    data = base32_decode(code)
    if len(data) != DECODED_LEN:
        raise GeneratorError("Decoded license is %d bytes, expected %d" % (len(data), DECODED_LEN))
    payload = data[:PAYLOAD_LEN]
    signature = data[PAYLOAD_LEN:]
    pub = key.public_key()
    if not verify_signature(payload, signature, pub):
        raise GeneratorError("Signature verification failed")
    meta = parse_payload(payload)
    meta["signature_ok"] = True
    return meta


def public_key_c_array(key: EllipticCurvePrivateKey, array_name="LICENSE_PUBKEY") -> str:
    xy = load_public_key_bytes(key)
    lines = []
    lines.append("const uint8_t %s[%d] = {" % (array_name, len(xy)))
    for i in range(0, len(xy), 12):
        chunk = ", ".join("0x%02X" % b for b in xy[i:i + 12])
        lines.append("    %s," % chunk)
    lines.append("};")
    lines.append("const size_t %s_LEN = %d; // 0x04 || X(32) || Y(32)" % (array_name, len(xy)))
    return "\n".join(lines)


# ---------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------
def _parse_date_arg(value: str) -> datetime.date:
    return parse_date(value)


def cmd_generate(args) -> int:
    try:
        license_type = validate_type(args.type)
        creation = _parse_date_arg(args.date)
        months = args.months if args.months is not None else 0
        key = load_private_key(args.key_file)
        code = generate_code(args.serial, license_type, creation, months, key)
        payload = build_payload(validate_serial(args.serial), license_type, creation,
                                validate_months(license_type, months))
        meta = parse_payload(payload)
        print("GENERATED CODE (%d chars):" % len(code))
        print(code)
        print()
        print("Metadata:")
        print("  Serial:        %s" % meta["serial"])
        print("  Type:          %s" % meta["type"])
        print("  Creation Date: %04d-%02d-%02d" % (meta["year"], meta["month"], meta["day"]))
        print("  Months:        %d" % meta["months"])
        print("  Expiration:    (computed by the device from NTP activation date + %d months)" % (0 if meta["license_type"] == LICENSE_PERMANENT else meta["months"]))
        return 0
    except GeneratorError as e:
        print("ERROR: %s" % e, file=sys.stderr)
        return 2


def cmd_verify(args) -> int:
    try:
        code = args.code
        key = load_private_key(args.key_file)
        meta = decode_and_verify(code, key)
        print("SIGNATURE: VALID")
        print("Serial:        %s" % meta["serial"])
        print("Type:          %s" % meta["type"])
        print("Creation Date: %04d-%02d-%02d" % (meta["year"], meta["month"], meta["day"]))
        print("Months:        %d" % meta["months"])
        print("Decoded bytes: 83 (payload 19 + signature 64)")
        return 0
    except GeneratorError as e:
        print("ERROR: %s" % e, file=sys.stderr)
        return 2


def cmd_inspect(args) -> int:
    try:
        data = base32_decode(args.code)
        if len(data) != DECODED_LEN:
            raise GeneratorError("Decoded license is %d bytes, expected %d" % (len(data), DECODED_LEN))
        payload = data[:PAYLOAD_LEN]
        meta = parse_payload(payload)
        print("Code length:    %d chars" % len(args.code))
        print("Decoded length: %d bytes" % len(data))
        print("Payload:        %s" % payload.hex())
        print("Signature(64B): %s (NOT verified — no key loaded)" % data[PAYLOAD_LEN:].hex())
        print("Serial:        %s" % meta["serial"])
        print("Type:          %s" % meta["type"])
        print("Creation Date: %04d-%02d-%02d" % (meta["year"], meta["month"], meta["day"]))
        print("Months:        %d" % meta["months"])
        return 0
    except GeneratorError as e:
        print("ERROR: %s" % e, file=sys.stderr)
        return 2


def cmd_public_key(args) -> int:
    try:
        key = load_private_key(args.key_file)
        xy = load_public_key_bytes(key)
        print("Public key (04||X||Y, %d bytes):" % len(xy))
        print(xy.hex())
        print()
        print("C array for license_pubkey.h:")
        print(public_key_c_array(key))
        print()
        print("Private key scalar (DO NOT SHARE, for test only):")
        print(private_key_scalar_hex(key))
        return 0
    except GeneratorError as e:
        print("ERROR: %s" % e, file=sys.stderr)
        return 2


def build_arg_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="license_generator",
        description="CarGuard license generator (firmware-compatible, P-256/SHA-256).",
    )
    sub = p.add_subparsers(dest="command", required=True)

    g = sub.add_parser("generate", help="Generate a license code")
    g.add_argument("--serial", required=True, help="Device serial (KCG_XXXXXXXX)")
    g.add_argument("--type", required=True, help="TEMPORARY or PERMANENT")
    g.add_argument("--date", required=True, help="Creation date YYYY-MM-DD")
    g.add_argument("--months", type=int, default=None,
                   help="Months for TEMPORARY (1..120); ignored/0 for PERMANENT")
    g.add_argument("--key-file", required=True, help="Path to the private key PEM")
    g.set_defaults(func=cmd_generate)

    v = sub.add_parser("verify", help="Verify a license code against the private key")
    v.add_argument("--code", required=True, help="The Base32 license code")
    v.add_argument("--key-file", required=True, help="Private key PEM (public derived)")
    v.set_defaults(func=cmd_verify)

    i = sub.add_parser("inspect", help="Inspect a code's metadata WITHOUT verifying")
    i.add_argument("--code", required=True, help="The Base32 license code")
    i.set_defaults(func=cmd_inspect)

    pk = sub.add_parser("public-key", help="Export the public key (hex + C array)")
    pk.add_argument("--key-file", required=True, help="Private key PEM (public derived)")
    pk.set_defaults(func=cmd_public_key)

    return p


def main(argv=None) -> int:
    parser = build_arg_parser()
    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
