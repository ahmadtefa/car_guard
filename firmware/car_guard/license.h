#pragma once

#include <stdint.h>
#include <stddef.h>
#include <Arduino.h>

// =========================================================
//  CarGuard License System — storage layout + public API
//  Stage 3.2: full activation (BearerSSL ECDSA P-256 / SHA-256),
//  NTP-based activation date, transition + replay policy.
// =========================================================

// ---------------------------------------------------------
// EEPROM size. `car_guard.ino` defines `EEPROM_SIZE 512` for the
// whole sketch, but Arduino compiles each .cpp as its own translation
// unit, so the sketch macro is NOT visible here. Define a matching
// default (= the value actually used by the firmware) so the license
// module is self-contained and the fit checks below are meaningful.
// A build may override it; it must stay consistent with car_guard.ino.
// ---------------------------------------------------------
#ifndef EEPROM_SIZE
#define EEPROM_SIZE 512
#endif

// ---------------------------------------------------------
// EEPROM layout
//   * settings (struct Settings, 184 bytes) is stored at offset 0
//     -> [0, 183].
//   * the license record lives at the fixed offset below, clear of
//     the settings region: [256, 256+sizeof(LicenseRecord)-1].
//   * EEPROM_SIZE 512 leaves room for both without any overlap and
//     without changing the existing settings layout.
// ---------------------------------------------------------
#define LICENSE_EEPROM_OFFSET 256
#define LICENSE_EEPROM_MAGIC 0x4C494345 // 'LICE'
#define LICENSE_EEPROM_VERSION 1

// ---------------------------------------------------------
// Decoded license code layout:  payload (19) || signature (64)
// The signature is the raw ECDSA P-256 r||s value (64 bytes),
// never DER / ASN.1.
// ---------------------------------------------------------
#define LICENSE_DECODED_LEN       83   // 19 + 64
#define LICENSE_PAYLOAD_LEN       19
#define LICENSE_SIGNATURE_LEN     64
#define LICENSE_PAYLOAD_SERIAL_LEN 12

// Minimum time_t considered a valid NTP-synchronized timestamp
// (2022-01-01 00:00:00 UTC).
#define LICENSE_NTP_MIN_VALID_EPOCH 1640995200

// ---------------------------------------------------------
// License state / type enums
// ---------------------------------------------------------
enum LicenseStatus : uint8_t { LICENSE_LOCKED = 0, LICENSE_ACTIVE = 1 };
enum LicenseType   : uint8_t { LICENSE_TEMPORARY = 0, LICENSE_PERMANENT = 1 };

// ---------------------------------------------------------
// Payload (19 bytes) layout parsed from the signed area:
//   1  byte  protocol version (0x01)
//   12 bytes device serial (ASCII uppercase, space padded)
//   1  byte  license type (0 = temporary, 1 = permanent)
//   2  bytes year  (big endian)
//   1  byte  month
//   1  byte  day
//   1  byte  months (>0 for temporary, 0 for permanent)
// ---------------------------------------------------------
struct LicensePayload {
  uint8_t  version;
  char     serial[LICENSE_PAYLOAD_SERIAL_LEN + 1]; // 12 + NUL
  uint8_t  type;
  uint16_t year;
  uint8_t  month;
  uint8_t  day;
  uint8_t  months;
};

// ---------------------------------------------------------
// License record stored in EEPROM (and mirrored in RAM).
// ---------------------------------------------------------
struct LicenseRecord {
  uint32_t magic;           // LICENSE_EEPROM_MAGIC
  uint8_t  version;         // LICENSE_EEPROM_VERSION
  uint8_t  status;          // LicenseStatus
  uint8_t  type;            // LicenseType
  uint8_t  reserved;
  char     serial[24];      // NUL terminated device serial
  uint32_t activationEpoch; // seconds since epoch (UTC) = creation date (NTP)
  uint32_t expirationEpoch; // 0 for permanent
  uint8_t  replayHash[32];  // SHA-256 of the whole decoded 83-byte license code
  uint32_t checksum;        // simple additive checksum
};

// Compile-time sanity checks
static_assert(sizeof(LicenseRecord) == 76, "Unexpected LicenseRecord size");
#ifdef EEPROM_SIZE
static_assert(LICENSE_EEPROM_OFFSET + sizeof(LicenseRecord) <= EEPROM_SIZE,
              "LicenseRecord does not fit in configured EEPROM_SIZE");
#endif

// ---------------------------------------------------------
// Public API
// ---------------------------------------------------------
void license_init();
void license_load();

bool license_is_active();
uint32_t license_get_expiration();
const char* license_get_serial();
uint8_t license_get_type();

// Attempt activation using the Base32 string code (RFC4648 uppercase, no padding).
// Returns true if activation succeeded and the license was persisted. On failure
// returns false and sets a textual reason in last_activation_reason (max 64 chars).
bool license_attempt_activate(const String& base32code);

// Last activation attempt reason (populated on failure)
extern char last_activation_reason[64];

// True when the device has a plausible NTP-synchronized time available.
bool license_has_ntp_time();

// ---------------------------------------------------------
// License commands over WebSocket (dependency-free, no socket / no secrets).
//
// `json` is the NUL-terminated JSON text received from a client;
// `deviceSerial` is the device identity string (e.g. getChipId()).
// Recognized commands:
//   {"cmd":"DEVICE_SERIAL"}
//   {"cmd":"LICENSE_STATUS"}
//   {"cmd":"LICENSE_ACTIVATE","code":"<BASE32>"}
//
// On success fills `response` with the reply and returns true. Returns false
// if the message is NOT a recognized license command (caller should ignore it,
// preserving any existing WebSocket behavior). `license_attempt_activate()`
// is the only activation path. Never returns the replay hash, never echoes the
// raw activation code, and never logs it.
// ---------------------------------------------------------
bool license_handle_ws_command(const char* json, const char* deviceSerial, String& response);

// ECDSA P-256 + SHA-256 signature verification over `payload` using the built-in
// public key. `signature` MUST be the raw r||s value (64 bytes) — no DER / ASN.1.
bool verify_ecdsa_p256_sha256(const uint8_t* payload, size_t payload_len,
                              const uint8_t* signature, size_t sig_len);

// ---------------------------------------------------------
// Internal helpers bridged across the license translation units
// (not part of the public device API, exposed for the parser/verify path).
// ---------------------------------------------------------
void license_sha256(const uint8_t* data, size_t len, uint8_t out32[32]);
bool license_compute_replay_hash(const uint8_t* decoded, size_t len, uint8_t out32[32]);
bool license_parse_payload(const uint8_t* payload, size_t len, LicensePayload* out);
// RFC4648 Base32 (uppercase A-Z / 2-7, no padding) decoder.
// Returns true and sets *outLen on success; false on any invalid character,
// length overflow, or non-canonical trailing bits.
bool license_decode_base32(const char* code, size_t codeLen,
                           uint8_t* out, size_t outMax, size_t* outLen);
