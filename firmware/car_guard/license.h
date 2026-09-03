#pragma once

#include <stdint.h>
#include <Arduino.h>

// License storage layout and API for CarGuard firmware

#define LICENSE_EEPROM_OFFSET 256
#define LICENSE_EEPROM_MAGIC 0x4C494345 // 'LICE'
#define LICENSE_EEPROM_VERSION 1

enum LicenseStatus : uint8_t { LICENSE_LOCKED = 0, LICENSE_ACTIVE = 1 };
enum LicenseType : uint8_t { LICENSE_TEMPORARY = 0, LICENSE_PERMANENT = 1 };

struct LicenseRecord {
  uint32_t magic;           // LICENSE_EEPROM_MAGIC
  uint8_t version;          // LICENSE_EEPROM_VERSION
  uint8_t status;           // LicenseStatus
  uint8_t type;             // LicenseType
  uint8_t reserved;
  char serial[24];          // null terminated
  uint32_t activationEpoch; // seconds since epoch
  uint32_t expirationEpoch; // 0 for permanent
  uint8_t replayHash[8];    // small fingerprint to avoid replay
  uint32_t checksum;        // simple checksum
};

// Public API
void license_init();
void license_load();
void license_save();

bool license_is_active();
uint32_t license_get_expiration();
const char* license_get_serial();
uint8_t license_get_type();

// Attempt activation using the Base32 string code (RFC4648 uppercase, no padding).
// Returns true if activation succeeded and license saved. On failure, returns false
// and sets a textual reason in last_activation_reason (max 64 chars).
bool license_attempt_activate(const String& base32code);

// Last activation attempt reason (populated on failure)
extern char last_activation_reason[64];

// Helper: check whether NTP/time is available (device must be connected to STA with internet)
bool license_has_ntp_time();

// For verification implementation: declare external verify function prototype
// that will be implemented using BearSSL or other crypto backend.
// It MUST perform ECDSA P-256 over SHA-256 on the given payload.
// Returns true if signature verifies under the built-in public key.

bool verify_ecdsa_p256_sha256(const uint8_t* payload, size_t payload_len,
                              const uint8_t* signature, size_t sig_len);
