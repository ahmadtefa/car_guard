# Car Guard License Issuer

Standalone offline Android issuer for the existing Car Guard license protocol.
This project is separate from the Car Guard Flutter application and ESP8266
firmware. It does not modify either one.

## Security model

- The production private key is selected with Android's system document picker.
- The PEM is parsed in memory and is never copied into app storage, assets,
  preferences, logs, network requests, or the APK.
- No `INTERNET` permission is declared.
- The key is accepted only when its derived P-256 public key matches the
  configured production fingerprint.
- Clear/reset drops the in-memory key reference and clears the imported byte
  buffer and displayed activation code on a best-effort basis.
- Development tests use an ephemeral random test key and never print or save a
  production activation code.

The expected fingerprint is:

```text
d0de642207cab1f8a88f4e6d6bd120dd05497fb2b3652df0e161beec0ad35e5f
```

The rotated/old fingerprint is retained only as a negative test fixture; it is
not used as a production configuration value.

The checker compares that value with the SHA-256 of the firmware's uncompressed
`04 || X || Y` public point. It also accepts the same configured value when the
operator's fingerprint was calculated over the standard SubjectPublicKeyInfo
DER encoding; the imported key still has to derive to exactly one P-256 public
point. The app shows no private-key material.

## Protocol

The issuer builds the existing 19-byte payload, signs it with ECDSA P-256 and
SHA-256, converts the DER signature to raw 32-byte-big-endian `r || s`, appends
that 64-byte signature, and emits canonical RFC4648 Base32 without padding.
The final binary is 83 bytes and the final code is 133 uppercase characters.
The payload creation date is the current UTC date; firmware activation expiry
continues to use authoritative NTP activation time, not this metadata date.

## Build

From this directory, with an Android SDK, API 35, build-tools, JDK 17, and
Gradle/Android Gradle Plugin available:

```bash
gradle :app:assembleRelease
```

The release build is intentionally unsigned unless a local Android signing
configuration is supplied by the administrator. Never use the Car Guard
license private key as an APK signing key.

## Protocol tests

```bash
./scripts/run_protocol_tests.sh
```

The tests generate a temporary in-memory P-256 test key and cover payload,
signature, Base32, serial, months, fingerprint mismatch, and tamper rejection.
They do not access the production key path.
