#include "license.h"
#include <EEPROM.h>
#include <string.h>
#include <time.h>

// Internal license record in RAM
static LicenseRecord _licenseRecord;
char last_activation_reason[64] = "";

// Simple additive checksum (not cryptographic) across the struct bytes
static uint32_t compute_checksum(const LicenseRecord &rec) {
  // make a copy with checksum = 0
  LicenseRecord tmp = rec;
  tmp.checksum = 0;
  const uint8_t *p = reinterpret_cast<const uint8_t *>(&tmp);
  size_t len = offsetof(LicenseRecord, checksum);
  uint32_t sum = 0;
  for (size_t i = 0; i < len; i++) {
    sum = sum + p[i];
  }
  return sum;
}

void license_init() {
  // initialize in-memory to locked safe state until load runs
  memset(&_licenseRecord, 0, sizeof(_licenseRecord));
  _licenseRecord.magic = 0;
  _licenseRecord.version = LICENSE_EEPROM_VERSION;
  _licenseRecord.status = LICENSE_LOCKED;
  _licenseRecord.type = LICENSE_TEMPORARY;
  _licenseRecord.activationEpoch = 0;
  _licenseRecord.expirationEpoch = 0;
  memset(_licenseRecord.serial, 0, sizeof(_licenseRecord.serial));
}

void license_load() {
  EEPROM.begin(EEPROM_SIZE);
  LicenseRecord rec;
  // read from fixed offset
  EEPROM.get(LICENSE_EEPROM_OFFSET, rec);
  EEPROM.end();

  bool valid = true;

  if (rec.magic != LICENSE_EEPROM_MAGIC) {
    valid = false;
  }
  if (rec.version != LICENSE_EEPROM_VERSION) {
    valid = false;
  }

  uint32_t cs = compute_checksum(rec);
  if (cs != rec.checksum) {
    valid = false;
  }

  if (valid) {
    // accept record
    memcpy(&_licenseRecord, &rec, sizeof(LicenseRecord));
    // ensure serial is NUL terminated
    _licenseRecord.serial[sizeof(_licenseRecord.serial)-1] = '\0';
  } else {
    // corrupted or missing: set safe default (LOCKED)
    memset(&_licenseRecord, 0, sizeof(_licenseRecord));
    _licenseRecord.magic = 0; // indicate no valid license stored
    _licenseRecord.version = LICENSE_EEPROM_VERSION;
    _licenseRecord.status = LICENSE_LOCKED;
    _licenseRecord.type = LICENSE_TEMPORARY;
    _licenseRecord.activationEpoch = 0;
    _licenseRecord.expirationEpoch = 0;
    memset(_licenseRecord.serial, 0, sizeof(_licenseRecord.serial));
  }
}

void license_save() {
  // prepare record
  LicenseRecord rec = _licenseRecord;
  rec.magic = LICENSE_EEPROM_MAGIC;
  rec.version = LICENSE_EEPROM_VERSION;
  // compute checksum
  rec.checksum = compute_checksum(rec);

  EEPROM.begin(EEPROM_SIZE);
  EEPROM.put(LICENSE_EEPROM_OFFSET, rec);
  EEPROM.commit();
  EEPROM.end();
  // also update in-memory copy
  memcpy(&_licenseRecord, &rec, sizeof(LicenseRecord));
}

bool license_is_active() {
  return _licenseRecord.status == LICENSE_ACTIVE;
}

uint32_t license_get_expiration() {
  return _licenseRecord.expirationEpoch;
}

const char* license_get_serial() {
  return _licenseRecord.serial;
}

uint8_t license_get_type() {
  return _licenseRecord.type;
}

bool license_has_ntp_time() {
  time_t now = time(nullptr);
  // consider valid if after 1 Jan 2022 (1640995200)
  return now > 1640995200;
}

// Note: license_attempt_activate and verify_ecdsa_p256_sha256 are intentionally
// not implemented here in this phase. They will be added in a future commit
// with full ECDSA + NTP activation logic. This file only provides storage and
// basic state helpers as requested.
