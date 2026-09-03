// Stage 3.1 additions: Base32 decoder (RFC4648 uppercase, no padding),
// SHA-256 helpers (wrapping BearSSL if available), and strict payload parser.

#include "license.h"
#include <Arduino.h>
#include <EEPROM.h>
#include <string.h>
#include <time.h>

// NOTE: This file adds helper utilities only. No activation, no ECDSA calls yet.

// -----------------------------
// Base32 RFC4648 (uppercase, no padding) decoder
// -----------------------------
static int base32_char_val(char c) {
  if (c >= 'A' && c <= 'Z') return c - 'A';
  if (c >= '2' && c <= '7') return 26 + (c - '2');
  return -1;
}

// decodeBase32: input must be uppercase A-Z and 2-7, no padding.
// returns number of bytes decoded, or -1 on error.
static int decodeBase32(const char* input, size_t inLen, uint8_t* out, size_t outMax) {
  if (inLen == 0) return 0;
  size_t bits = 0;
  uint32_t buffer = 0;
  size_t outLen = 0;

  for (size_t i = 0; i < inLen; i++) {
    int val = base32_char_val(input[i]);
    if (val < 0) return -1; // invalid char
    buffer = (buffer << 5) | (uint32_t)val;
    bits += 5;
    while (bits >= 8) {
      bits -= 8;
      if (outLen >= outMax) return -1; // overflow
      out[outLen++] = (uint8_t)((buffer >> bits) & 0xFF);
    }
  }
  // RFC4648 without padding allows leftover bits; reject if non-zero leftover bits
  if (bits > 0) {
    // leftover bits must be zero — however with no padding leftover is allowed only
    // if they are zero; we'll reject non-zero leftover to force full-byte encoding
    if ((buffer & ((1u << bits) - 1)) != 0) return -1;
  }
  return (int)outLen;
}

// -----------------------------
// SHA-256 helpers — use BearSSL if available at compile time
// We'll provide a fallback to a minimal software implementation only if BearSSL
// hash vtable is not available. In practice ESP8266 Arduino core provides
// BearSSL; we still guard compile-time usage.
// -----------------------------

#ifdef __has_include
#if __has_include(<bearssl/bearssl_hash.h>)
#define HAVE_BEARSSL_HASH 1
#include <bearssl/bearssl_hash.h>
#endif
#endif

static void sha256_digest(const uint8_t* data, size_t len, uint8_t out32[32]) {
#ifdef HAVE_BEARSSL_HASH
  // Use BearSSL's SHA-256
  br_sha256_context ctx;
  br_sha256_init(&ctx);
  br_sha256_update(&ctx, data, len);
  br_sha256_out(&ctx, out32);
#else
  // If BearSSL hash is not available at compile time, provide a compile error
  #error "BearSSL hash not available on this build — cannot compute SHA-256"
#endif
}

// -----------------------------
// Payload parser (strict 19 bytes)
// Format:
// 1 byte protocol version
// 12 bytes serial (ASCII uppercase, space padded)
// 1 byte license type (0=temporary,1=permanent)
// 2 bytes year (BE), 1 byte month, 1 byte day
// 1 byte months
// -----------------------------

struct ParsedPayload {
  uint8_t version;
  char serial[13]; // 12 + NUL
  uint8_t license_type;
  uint16_t year;
  uint8_t month;
  uint8_t day;
  uint8_t months;
};

static bool parse_payload19(const uint8_t* payload, size_t len, ParsedPayload* out) {
  if (len != 19) return false;
  out->version = payload[0];
  // serial: bytes 1..12
  memcpy(out->serial, payload + 1, 12);
  out->serial[12] = '\0';
  // validate serial: uppercase letters, digits, underscore or space
  for (int i = 0; i < 12; i++) {
    char c = out->serial[i];
    if (c == 0x20) continue; // space padding allowed
    if (c >= 'A' && c <= 'Z') continue;
    if (c >= '0' && c <= '9') continue;
    if (c == '_' ) continue;
    // invalid char
    return false;
  }
  out->license_type = payload[13];
  out->year = (uint16_t)payload[14] << 8 | (uint16_t)payload[15];
  out->month = payload[16];
  out->day = payload[17];
  out->months = payload[18];

  // Basic validations
  if (out->version != 0x01) return false; // unsupported protocol version
  if (!(out->license_type == 0x00 || out->license_type == 0x01)) return false;
  if (out->month < 1 || out->month > 12) return false;
  if (out->day < 1 || out->day > 31) return false; // deeper check below with month/day
  if (out->license_type == 0x01 && out->months != 0) return false; // permanent must have months=0
  if (out->license_type == 0x00 && out->months == 0) return false; // temporary must have months>0

  // Validate day vs month/year (simple check)
  static const uint8_t mdays[12] = {31,28,31,30,31,30,31,31,30,31,30,31};
  uint8_t maxday = mdays[out->month - 1];
  // leap year for feb
  if (out->month == 2) {
    bool leap = ((out->year % 4 == 0) && (out->year % 100 != 0)) || (out->year % 400 == 0);
    if (leap) maxday = 29;
  }
  if (out->day > maxday) return false;

  return true;
}

// -----------------------------
// Replay hash infrastructure (SHA-256) already supported by sha256_digest
// LicenseRecord.replayHash is 32 bytes as defined in header.
// -----------------------------

// -----------------------------
// Build-time check: ensure compile succeeds on target; no runtime action here.
// -----------------------------

