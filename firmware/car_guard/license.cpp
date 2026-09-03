// =========================================================
//  CarGuard License — Stage 3.2 activation & persistence
//
//  This unit implements the real activation flow:
//    * decode Base32 -> 83 bytes (19 payload + 64 raw signature)
//    * ECDSA P-256 / SHA-256 signature verification (no DER)
//    * device serial check (chip-derived "KCG_XXXXXXXX")
//    * NTP-based activation time (never phone/app time)
//    * transition policy (LOCKED/TEMPORARY/PERMANENT)
//    * replay protection (SHA-256 fingerprint of the whole code)
//    * calendar-aware (clamped) expiry for temporary licenses
//    * EEPROM persist only after every check passes
// =========================================================

#include "license.h"
#include "license_pubkey.h"
#include <EEPROM.h>
#include <string.h>
#include <time.h>
#include <Esp.h>

// Internal license record in RAM
static LicenseRecord _licenseRecord;
char last_activation_reason[64] = "";

// ---------------------------------------------------------
// Additive checksum (non-cryptographic) across the struct bytes
// preceding the checksum field.
// ---------------------------------------------------------
static uint32_t compute_checksum(const LicenseRecord& rec) {
  LicenseRecord tmp = rec;
  tmp.checksum = 0;
  const uint8_t* p = reinterpret_cast<const uint8_t*>(&tmp);
  size_t len = offsetof(LicenseRecord, checksum);
  uint32_t sum = 0;
  for (size_t i = 0; i < len; i++) {
    sum = sum + p[i];
  }
  return sum;
}

// ---------------------------------------------------------
// Device serial: derived from the ESP chip id, identical to the
// firmware getChipId() -> "KCG_%08X" (12 ASCII chars).
// ---------------------------------------------------------
static void get_device_serial(char* out, size_t outLen) {
  if (out == NULL || outLen == 0) return;
  if (outLen < 13) { out[0] = '\0'; return; }
  uint32_t chipId = ESP.getChipId();
  snprintf(out, outLen, "KCG_%08X", (unsigned int)chipId);
}

// ---------------------------------------------------------
// UTC calendar helpers (timezone-independent; ignore local tz).
// ---------------------------------------------------------
static bool is_leap(int y) {
  return ((y % 4 == 0) && (y % 100 != 0)) || (y % 400 == 0);
}

static int days_in_month(int y, int m) {
  static const int mdays[12] = {31,28,31,30,31,30,31,31,30,31,30,31};
  if (m == 2) return is_leap(y) ? 29 : 28;
  return mdays[m - 1];
}

// Days from civil date to Unix epoch days (Howard Hinnant algorithm).
static int64_t days_from_civil(int64_t y, int m, int d) {
  y -= m <= 2;
  const int64_t era = (y >= 0 ? y : y - 399) / 400;
  const unsigned yoe = (unsigned)(y - era * 400);                 // [0, 399]
  const unsigned doy = (unsigned)((153 * (m + (m > 2 ? -3 : 9)) + 2) / 5 + d - 1); // [0, 365]
  const unsigned doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;     // [0, 146096]
  return (int64_t)era * 146097 + (int64_t)doe - 719468;
}

static void epoch_to_utc(uint32_t epoch, int& y, int& mo, int& d,
                         int& hh, int& mm, int& ss) {
  time_t t = (time_t)epoch;
  struct tm tm;
  gmtime_r(&t, &tm);
  y  = tm.tm_year + 1900;
  mo = tm.tm_mon + 1;
  d  = tm.tm_mday;
  hh = tm.tm_hour;
  mm = tm.tm_min;
  ss = tm.tm_sec;
}

// Add `months` to `epoch` in the proleptic Gregorian calendar, clamping
// the day to the last day of the target month (e.g. Jan 31 + 1 mo -> Feb 28/29).
// Only meaningful for months >= 1.
static bool add_months_clamped(uint32_t epoch, int months, uint32_t& outEpoch) {
  if (months <= 0 || months > 120) return false;
  int y, mo, d, hh, mm, ss;
  epoch_to_utc(epoch, y, mo, d, hh, mm, ss);

  int total = y * 12 + (mo - 1) + months;
  int ny = total / 12;
  int nm = (total % 12) + 1;
  int nd = d;
  int last = days_in_month(ny, nm);
  if (nd > last) nd = last;
  if (ny < 1970) return false;

  int64_t days = days_from_civil(ny, nm, nd);
  outEpoch = (uint32_t)(days * 86400LL + hh * 3600LL + mm * 60LL + ss);
  return true;
}

// ---------------------------------------------------------
// NTP: obtain a trusted time (never phone / app provided).
// configTime is idempotent; we then poll up to `timeout_ms`
// for time() to become plausible.
// ---------------------------------------------------------
static uint32_t license_wait_ntp_time(uint32_t timeout_ms) {
  static bool sntp_configured = false;
  if (!sntp_configured) {
    configTime(0, 0, "pool.ntp.org", "time.nist.gov", "ntp.aliyun.com");
    sntp_configured = true;
  }
  uint32_t start = millis();
  while (millis() - start < timeout_ms) {
    time_t now = time(nullptr);
    if ((uint64_t)now > (uint64_t)LICENSE_NTP_MIN_VALID_EPOCH) {
      return (uint32_t)now;
    }
    delay(100);
  }
  return 0;
}

// ---------------------------------------------------------
// Transition state derived from the currently persisted record.
// An expired temporary license is treated as LOCKED so a renewal /
// upgrade can proceed.
// ---------------------------------------------------------
enum TransitionState { ST_LOCKED = 0, ST_TEMP_ACTIVE = 1, ST_PERM_ACTIVE = 2 };

static TransitionState current_transition_state(uint32_t now) {
  if (_licenseRecord.magic != LICENSE_EEPROM_MAGIC) return ST_LOCKED;
  if (_licenseRecord.status != LICENSE_ACTIVE) return ST_LOCKED;
  if (_licenseRecord.type == LICENSE_PERMANENT) return ST_PERM_ACTIVE;
  // Temporary: 'active' only if not expired.
  if (_licenseRecord.expirationEpoch == 0) return ST_LOCKED;
  if (now >= _licenseRecord.expirationEpoch) return ST_LOCKED;
  return ST_TEMP_ACTIVE;
}

static bool transition_allowed(uint8_t newType, uint32_t now) {
  TransitionState st = current_transition_state(now);
  switch (st) {
    case ST_LOCKED:
      // LOCKED -> TEMPORARY / PERMANENT both allowed.
      return true;
    case ST_PERM_ACTIVE:
      // PERMANENT active -> TEMPORARY / PERMANENT both rejected.
      strcpy(last_activation_reason, "CANNOT_REPLACE_PERMANENT");
      return false;
    case ST_TEMP_ACTIVE:
      if (newType == LICENSE_PERMANENT) return true;  // TEMP -> PERM allowed
      // TEMP active -> TEMP rejected.
      strcpy(last_activation_reason, "EXISTING_TEMP_ACTIVE");
      return false;
  }
  strcpy(last_activation_reason, "UNKNOWN_TRANSITION_STATE");
  return false;
}

// ---------------------------------------------------------
// Persist the given record. Only updates the in-RAM copy after the
// EEPROM commit succeeds. Returns false (and leaves RAM untouched)
// on a failed commit.
// ---------------------------------------------------------
static bool license_persist(const LicenseRecord& rec) {
  LicenseRecord toSave = rec;
  toSave.magic = LICENSE_EEPROM_MAGIC;
  toSave.version = LICENSE_EEPROM_VERSION;
  toSave.checksum = compute_checksum(toSave);

  EEPROM.begin(EEPROM_SIZE);
  EEPROM.put(LICENSE_EEPROM_OFFSET, toSave);
  bool ok = EEPROM.commit();
  EEPROM.end();

  if (ok) {
    memcpy(&_licenseRecord, &toSave, sizeof(LicenseRecord));
  }
  return ok;
}

// ---------------------------------------------------------
// Public lifecycle
// ---------------------------------------------------------
void license_init() {
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
  EEPROM.get(LICENSE_EEPROM_OFFSET, rec);
  EEPROM.end();

  bool valid = (rec.magic == LICENSE_EEPROM_MAGIC) &&
               (rec.version == LICENSE_EEPROM_VERSION) &&
               (compute_checksum(rec) == rec.checksum);

  if (valid) {
    memcpy(&_licenseRecord, &rec, sizeof(LicenseRecord));
    _licenseRecord.serial[sizeof(_licenseRecord.serial) - 1] = '\0';
  } else {
    license_init();
  }
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
  return (uint64_t)now > (uint64_t)LICENSE_NTP_MIN_VALID_EPOCH;
}

// ---------------------------------------------------------
// Activation
// ---------------------------------------------------------
bool license_attempt_activate(const String& base32code) {
  strcpy(last_activation_reason, "");

  if (base32code.length() == 0) {
    strcpy(last_activation_reason, "EMPTY_CODE");
    return false;
  }

#if PUBLIC_KEY_CONFIGURED == 0
  // No production public key configured. Every activation must fail.
  (void)base32code;
  strcpy(last_activation_reason, "PUBLIC_KEY_NOT_CONFIGURED");
  return false;
#endif

  // 1. Decode Base32 -> strict 83 bytes.
  uint8_t decoded[LICENSE_DECODED_LEN];
  size_t decodedLen = 0;
  if (!license_decode_base32(base32code.c_str(), base32code.length(),
                             decoded, sizeof(decoded), &decodedLen)) {
    strcpy(last_activation_reason, "DECODE_ERROR");
    return false;
  }
  if (decodedLen != LICENSE_DECODED_LEN) {
    strcpy(last_activation_reason, "INVALID_LENGTH");
    return false;
  }

  const uint8_t* payload   = decoded;                         // 19 bytes
  const uint8_t* signature = decoded + LICENSE_PAYLOAD_LEN;   // 64 bytes (raw r||s)

  // 2. Signature verification (raw r||s, no DER/ASN.1).
  if (!verify_ecdsa_p256_sha256(payload, LICENSE_PAYLOAD_LEN,
                                signature, LICENSE_SIGNATURE_LEN)) {
    strcpy(last_activation_reason, "SIGNATURE_INVALID");
    return false;
  }

  // 3. Parse the signed payload.
  LicensePayload pl;
  if (!license_parse_payload(payload, LICENSE_PAYLOAD_LEN, &pl)) {
    strcpy(last_activation_reason, "INVALID_PAYLOAD");
    return false;
  }

  // 4. Device serial check (license must be bound to THIS device).
  char deviceSerial[16];
  get_device_serial(deviceSerial, sizeof(deviceSerial));
  // tolerate trailing space padding in the 12-byte serial field
  for (int i = LICENSE_PAYLOAD_SERIAL_LEN - 1; i >= 0; i--) {
    if (pl.serial[i] == ' ') pl.serial[i] = '\0';
    else break;
  }
  if (strcmp(pl.serial, deviceSerial) != 0) {
    strcpy(last_activation_reason, "SERIAL_MISMATCH");
    return false;
  }

  // 5. NTP time (never accept phone/app-provided time). ~8 s timeout.
  uint32_t now = license_wait_ntp_time(8000);
  if (now == 0) {
    strcpy(last_activation_reason, "NTP_UNAVAILABLE");
    return false;
  }

  // 6. Replay protection: SHA-256 fingerprint of the whole 83-byte code.
  uint8_t replay[32];
  license_compute_replay_hash(decoded, decodedLen, replay);
  bool alreadyUsed =
      (_licenseRecord.magic == LICENSE_EEPROM_MAGIC) &&
      (memcmp(_licenseRecord.replayHash, replay, sizeof(replay)) == 0);
  if (alreadyUsed) {
    strcpy(last_activation_reason, "ALREADY_USED");
    return false;
  }

  // 7. Transition policy (LOCKED/TEMPORARY/PERMANENT).
  uint8_t newType = (pl.type == LICENSE_PERMANENT) ? LICENSE_PERMANENT : LICENSE_TEMPORARY;
  if (!transition_allowed(newType, now)) {
    return false; // reason already set
  }

  // 8. Compute activation (creation) date + expiration from NTP time.
  //    creation date = current NTP time (authoritative, not from the code/app).
  uint32_t activation = now;
  uint32_t expiration = 0; // 0 = permanent
  if (newType == LICENSE_TEMPORARY) {
    if (!add_months_clamped(activation, pl.months, expiration)) {
      strcpy(last_activation_reason, "INVALID_TERM");
      return false;
    }
  }

  // 9. Build + persist ONLY after every check passes.
  LicenseRecord rec;
  memset(&rec, 0, sizeof(rec));
  rec.magic = LICENSE_EEPROM_MAGIC;
  rec.version = LICENSE_EEPROM_VERSION;
  rec.status = LICENSE_ACTIVE;
  rec.type = newType;
  rec.reserved = 0;
  strncpy(rec.serial, deviceSerial, sizeof(rec.serial) - 1);
  rec.serial[sizeof(rec.serial) - 1] = '\0';
  rec.activationEpoch = activation;
  rec.expirationEpoch = expiration;
  memcpy(rec.replayHash, replay, sizeof(rec.replayHash));

  if (!license_persist(rec)) {
    strcpy(last_activation_reason, "EEPROM_COMMIT_FAILED");
    return false;
  }

  strcpy(last_activation_reason, "OK");
  return true;
}
