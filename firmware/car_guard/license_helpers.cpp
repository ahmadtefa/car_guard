// =========================================================
//  CarGuard License — Stage 3.2 helpers
//
//  - RFC4648 Base32 decoder (uppercase A-Z / 2-7, no padding)
//  - SHA-256 wrapper over BearSSL (real BearSSL in ESP8266 core)
//  - strict 19-byte payload parser
//  - SHA-256 replay fingerprint over the whole decoded code
//  - ECDSA P-256 / SHA-256 signature verification (raw r||s, no DER)
//
//  The crypto backend is the genuine BearSSL shipped with
//  ESP8266 Arduino Core 3.1.2. The ECDSA verifier used is
//  `br_ecdsa_vrfy_raw_get_default()` operating on a raw
//  64-byte r||s signature — no ASN.1/DER conversion anywhere.
// =========================================================

#include "license.h"
#include "license_pubkey.h"
#include <Arduino.h>
#include <string.h>
#include <time.h>

// BearSSL is bundled with the ESP8266 Arduino core at tools/sdk/include/bearssl.
// We include the umbrella header (which pulls in bearssl_hash.h and bearssl_ec.h).
#ifdef __has_include
#  if __has_include(<bearssl/bearssl.h>)
#    define LICENSE_HAVE_BEARSSL 1
#    include <bearssl/bearssl.h>
#  endif
#endif

#ifndef LICENSE_HAVE_BEARSSL
#  error "Stage 3.2 requires BearSSL (missing <bearssl/bearssl.h>) — build this against ESP8266 Arduino Core 3.1.2"
#endif

// ---------------------------------------------------------
// SHA-256 (BearSSL)
// ---------------------------------------------------------
void license_sha256(const uint8_t* data, size_t len, uint8_t out32[32]) {
  br_sha256_context ctx;
  br_sha256_init(&ctx);
  br_sha256_update(&ctx, data, len);
  br_sha256_out(&ctx, out32);
}

// ---------------------------------------------------------
// Replay fingerprint: SHA-256 over the FULL decoded license code
// (83 bytes: payload + signature). 32 bytes as required.
// ---------------------------------------------------------
bool license_compute_replay_hash(const uint8_t* decoded, size_t len, uint8_t out32[32]) {
  if (decoded == NULL || out32 == NULL) return false;
  license_sha256(decoded, len, out32);
  return true;
}

// ---------------------------------------------------------
// RFC4648 Base32 (uppercase, no padding) decoder
// ---------------------------------------------------------
static int base32_char_val(char c) {
  if (c >= 'A' && c <= 'Z') return c - 'A';
  if (c >= '2' && c <= '7') return 26 + (c - '2');
  return -1;
}

bool license_decode_base32(const char* code, size_t codeLen,
                           uint8_t* out, size_t outMax, size_t* outLen) {
  if (code == NULL || out == NULL || outLen == NULL) return false;
  if (codeLen == 0) return false;

  size_t bits = 0;
  uint32_t buffer = 0;
  size_t outCnt = 0;

  for (size_t i = 0; i < codeLen; i++) {
    int val = base32_char_val(code[i]);
    if (val < 0) return false;                 // invalid character
    buffer = (buffer << 5) | (uint32_t)val;
    bits += 5;
    while (bits >= 8) {
      bits -= 8;
      if (outCnt >= outMax) return false;      // output buffer overflow
      out[outCnt++] = (uint8_t)((buffer >> bits) & 0xFF);
    }
  }

  // Reject non-canonical trailing bits (must be zero).
  if (bits > 0) {
    if ((buffer & ((1u << bits) - 1)) != 0) return false;
  }

  *outLen = outCnt;
  return true;
}

// ---------------------------------------------------------
// Strict 19-byte payload parser
// ---------------------------------------------------------
bool license_parse_payload(const uint8_t* payload, size_t len, LicensePayload* out) {
  if (payload == NULL || out == NULL) return false;
  if (len != LICENSE_PAYLOAD_LEN) return false;

  out->version = payload[0];

  // serial: bytes 1..12
  memcpy(out->serial, payload + 1, LICENSE_PAYLOAD_SERIAL_LEN);
  out->serial[LICENSE_PAYLOAD_SERIAL_LEN] = '\0';

  // validate serial: uppercase letters, digits, underscore or space padding
  for (int i = 0; i < LICENSE_PAYLOAD_SERIAL_LEN; i++) {
    char c = out->serial[i];
    if (c == 0x20) continue;              // space padding allowed
    if (c >= 'A' && c <= 'Z') continue;
    if (c >= '0' && c <= '9') continue;
    if (c == '_') continue;
    return false;                         // invalid char
  }

  out->type   = payload[13];
  out->year   = (uint16_t)payload[14] << 8 | (uint16_t)payload[15]; // big endian
  out->month  = payload[16];
  out->day    = payload[17];
  out->months = payload[18];

  // Basic validations
  if (out->version != 0x01) return false;                    // unsupported protocol version
  if (!(out->type == 0x00 || out->type == 0x01)) return false;
  if (out->month < 1 || out->month > 12) return false;
  if (out->day < 1 || out->day > 31) return false;
  if (out->type == LICENSE_PERMANENT && out->months != 0) return false;  // permanent must have months=0
  if (out->type == LICENSE_TEMPORARY && out->months == 0) return false;  // temporary must have months>0

  // Day vs month/year (with leap year handling)
  static const uint8_t mdays[12] = {31,28,31,30,31,30,31,31,30,31,30,31};
  uint8_t maxday = mdays[out->month - 1];
  if (out->month == 2) {
    bool leap = ((out->year % 4 == 0) && (out->year % 100 != 0)) || (out->year % 400 == 0);
    if (leap) maxday = 29;
  }
  if (out->day > maxday) return false;

  return true;
}

// ---------------------------------------------------------
// ECDSA P-256 + SHA-256 verification (raw r||s, no DER)
// ---------------------------------------------------------
bool verify_ecdsa_p256_sha256(const uint8_t* payload, size_t payload_len,
                              const uint8_t* signature, size_t sig_len) {
#if PUBLIC_KEY_CONFIGURED == 0
  // No production public key configured yet: refuse to verify.
  (void)payload; (void)payload_len; (void)signature; (void)sig_len;
  return false;
#else
  if (payload == NULL || signature == NULL) return false;
  if (payload_len != LICENSE_PAYLOAD_LEN) return false;
  if (sig_len != LICENSE_SIGNATURE_LEN) return false;

  // 1. SHA-256 hash of the signed payload.
  uint8_t hash[32];
  license_sha256(payload, payload_len, hash);

  // 2. Build the BearSSL EC public-key view for P-256.
  br_ec_public_key pk;
  pk.curve = BR_EC_secp256r1;
  pk.q = const_cast<unsigned char*>(reinterpret_cast<const unsigned char*>(LICENSE_PUBKEY));
  pk.qlen = LICENSE_PUBKEY_LEN;

  // 3. Raw (r||s = 64 bytes) ECDSA verifier — NO DER / ASN.1 path.
  br_ecdsa_vrfy vrfy = br_ecdsa_vrfy_raw_get_default();
  if (vrfy == NULL) return false;

  const br_ec_impl* impl = br_ec_get_default();
  if (impl == NULL) return false;

  uint32_t ok = vrfy(impl, hash, sizeof(hash), &pk, signature, sig_len);
  return ok == 1;
#endif
}
