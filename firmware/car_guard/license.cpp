// =========================================================
//  CarGuard License — Stage 3.2 activation & persistence
//
//  This unit implements the real activation flow:
//    * decode Base32 -> 83 bytes (19 payload + 64 raw signature)
//    * ECDSA P-256 / SHA-256 signature verification (no DER)
//    * device serial check (chip-derived "KCG_XXXXXXXX")
//    * phone-supplied activation time (no network time dependency)
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

// The app supplies UTC Unix seconds. Keep that value as a monotonic runtime
// base so temporary-license checks do not call an external time service.
static uint32_t _phoneTimeEpoch = 0;
static uint32_t _phoneTimeMillis = 0;
static bool _phoneTimeAvailable = false;

// Last phone timestamp accepted by the anti-rollback check. The EEPROM copy
// is refreshed in coarse intervals, plus immediately for activation/rollback
// transitions, so a status poll does not cause an EEPROM write every time.
static uint32_t _lastPhoneTime = 0;
static uint32_t _lastPersistedPhoneTime = 0;
static bool _clockRecordValid = false;
static bool _clockRollbackDetected = false;
static bool _clockRollbackPersisted = false;
static bool _temporaryExpired = false;
static bool _temporaryExpiredPersisted = false;
static const uint32_t PHONE_CLOCK_PERSIST_INTERVAL = 60;

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
// Phone time validation, persistence and runtime clock.
//
// The timestamp is deliberately outside the signed 83-byte license payload:
// the license cryptography and payload layout remain unchanged. It is accepted
// only as a valid Unix-seconds value and is then advanced with millis() while
// the ESP8266 remains powered. The app refreshes it on LICENSE_STATUS, which
// also restores the time base after a reboot without an external time service.
// ---------------------------------------------------------
static uint32_t compute_clock_checksum(const LicenseClockRecord& rec) {
  LicenseClockRecord tmp = rec;
  tmp.checksum = 0;
  const uint8_t* p = reinterpret_cast<const uint8_t*>(&tmp);
  size_t len = offsetof(LicenseClockRecord, checksum);
  uint32_t sum = 0;
  for (size_t i = 0; i < len; i++) {
    sum = sum + p[i];
  }
  return sum;
}

static bool valid_phone_epoch(uint32_t epoch) {
  return epoch >= LICENSE_MIN_VALID_EPOCH;
}

static uint32_t current_phone_epoch() {
  if (!_phoneTimeAvailable) return 0;

  const uint32_t elapsedSeconds = (millis() - _phoneTimeMillis) / 1000UL;
  if (0xFFFFFFFFUL - _phoneTimeEpoch < elapsedSeconds) {
    return 0xFFFFFFFFUL;
  }
  return _phoneTimeEpoch + elapsedSeconds;
}

static bool persist_phone_clock(uint32_t lastPhoneTime,
                                bool clockRollback,
                                bool temporaryExpired) {
  if (!valid_phone_epoch(lastPhoneTime)) return false;

  LicenseClockRecord rec;
  memset(&rec, 0, sizeof(rec));
  rec.magic = LICENSE_CLOCK_EEPROM_MAGIC;
  rec.version = LICENSE_CLOCK_EEPROM_VERSION;
  rec.clockRollback = clockRollback ? 1 : 0;
  rec.temporaryExpired = temporaryExpired ? 1 : 0;
  rec.lastPhoneTime = lastPhoneTime;
  rec.checksum = compute_clock_checksum(rec);

  EEPROM.begin(EEPROM_SIZE);
  EEPROM.put(LICENSE_CLOCK_EEPROM_OFFSET, rec);
  const bool ok = EEPROM.commit();
  EEPROM.end();

  if (ok) {
    _clockRecordValid = true;
    _lastPersistedPhoneTime = lastPhoneTime;
    _clockRollbackPersisted = clockRollback;
    _temporaryExpiredPersisted = temporaryExpired;
  }
  return ok;
}

static void load_phone_clock() {
  _phoneTimeEpoch = 0;
  _phoneTimeMillis = 0;
  _phoneTimeAvailable = false;
  _lastPhoneTime = 0;
  _lastPersistedPhoneTime = 0;
  _clockRecordValid = false;
  _clockRollbackDetected = false;
  _clockRollbackPersisted = false;
  _temporaryExpired = false;
  _temporaryExpiredPersisted = false;

  EEPROM.begin(EEPROM_SIZE);
  LicenseClockRecord rec;
  EEPROM.get(LICENSE_CLOCK_EEPROM_OFFSET, rec);
  EEPROM.end();

  const bool valid =
      rec.magic == LICENSE_CLOCK_EEPROM_MAGIC &&
      rec.version == LICENSE_CLOCK_EEPROM_VERSION &&
      rec.checksum == compute_clock_checksum(rec) &&
      valid_phone_epoch(rec.lastPhoneTime);
  if (!valid) return;

  _lastPhoneTime = rec.lastPhoneTime;
  _lastPersistedPhoneTime = rec.lastPhoneTime;
  _clockRecordValid = true;
  _clockRollbackDetected = rec.clockRollback != 0;
  _clockRollbackPersisted = _clockRollbackDetected;
  _temporaryExpired = rec.temporaryExpired != 0;
  _temporaryExpiredPersisted = _temporaryExpired;

  // Continue from the last accepted time until the app supplies a fresher
  // value. This is deliberately monotonic during the current boot.
  _phoneTimeEpoch = rec.lastPhoneTime;
  _phoneTimeMillis = millis();
  _phoneTimeAvailable = true;
}

static bool phone_time_would_rollback(uint32_t epoch) {
  return _lastPhoneTime != 0 && epoch < _lastPhoneTime;
}

enum PhoneTimeResult {
  PHONE_TIME_ACCEPTED = 0,
  PHONE_TIME_INVALID = 1,
  PHONE_TIME_ROLLBACK = 2,
  PHONE_TIME_PERSIST_FAILED = 3,
};

static void record_clock_rollback() {
  _clockRollbackDetected = true;
  if (!_clockRollbackPersisted) {
    // Keep the previous trusted time; only persist the diagnostic flag.
    persist_phone_clock(_lastPhoneTime, true, _temporaryExpired);
  }
}

static PhoneTimeResult accept_phone_time(uint32_t epoch,
                                         bool forcePersist,
                                         bool clearTemporaryExpired) {
  if (!valid_phone_epoch(epoch)) return PHONE_TIME_INVALID;

  if (phone_time_would_rollback(epoch)) {
    record_clock_rollback();
    return PHONE_TIME_ROLLBACK;
  }

  const uint32_t runningTime = current_phone_epoch();
  const bool persistNeeded =
      forcePersist ||
      !_clockRecordValid ||
      (epoch > _lastPersistedPhoneTime &&
       epoch - _lastPersistedPhoneTime >= PHONE_CLOCK_PERSIST_INTERVAL) ||
      (_clockRollbackDetected != _clockRollbackPersisted) ||
      (clearTemporaryExpired && _temporaryExpired);

  const bool nextTemporaryExpired =
      clearTemporaryExpired ? false : _temporaryExpired;
  if (persistNeeded &&
      !persist_phone_clock(epoch, _clockRollbackDetected, nextTemporaryExpired)) {
    return PHONE_TIME_PERSIST_FAILED;
  }

  _lastPhoneTime = epoch;
  if (!_phoneTimeAvailable || epoch > runningTime) {
    _phoneTimeEpoch = epoch;
    _phoneTimeMillis = millis();
    _phoneTimeAvailable = true;
  }
  if (clearTemporaryExpired) {
    _temporaryExpired = false;
  }
  return PHONE_TIME_ACCEPTED;
}

static void mark_temporary_expired() {
  if (_temporaryExpired) return;
  _temporaryExpired = true;

  // This is a one-time write for the current license state. If the write
  // fails, keep the RAM lock and avoid repeatedly wearing EEPROM.
  if (!_temporaryExpiredPersisted) {
    persist_phone_clock(_lastPhoneTime, _clockRollbackDetected, true);
  }
}

// ---------------------------------------------------------
// Persisted-record validation. The serial check is repeated at runtime so a
// copied EEPROM image cannot make a different ESP8266 active.
// ---------------------------------------------------------
static bool record_is_valid() {
  return (_licenseRecord.magic == LICENSE_EEPROM_MAGIC) &&
         (_licenseRecord.version == LICENSE_EEPROM_VERSION) &&
         (compute_checksum(_licenseRecord) == _licenseRecord.checksum);
}

static bool record_matches_device() {
  if (!record_is_valid()) return false;
  char deviceSerial[16];
  get_device_serial(deviceSerial, sizeof(deviceSerial));
  return strcmp(_licenseRecord.serial, deviceSerial) == 0;
}

// ---------------------------------------------------------
// Transition state derived from the currently persisted record.
// An expired temporary license is treated as LOCKED so a renewal /
// upgrade can proceed.
// ---------------------------------------------------------
enum TransitionState { ST_LOCKED = 0, ST_TEMP_ACTIVE = 1, ST_PERM_ACTIVE = 2 };

static TransitionState current_transition_state(uint32_t now) {
  if (!record_matches_device()) return ST_LOCKED;
  if (_licenseRecord.status != LICENSE_ACTIVE) return ST_LOCKED;
  if (_licenseRecord.type == LICENSE_PERMANENT) return ST_PERM_ACTIVE;
  // Temporary: 'active' only if not expired. The sticky expired bit prevents
  // a later lower phone timestamp from reviving an already-ended term.
  if (_temporaryExpired || _licenseRecord.expirationEpoch == 0) {
    return ST_LOCKED;
  }
  if (now >= _licenseRecord.expirationEpoch) {
    mark_temporary_expired();
    return ST_LOCKED;
  }
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

  // Load the separate anti-rollback clock record without changing the
  // existing LicenseRecord or its EEPROM offset.
  load_phone_clock();
}

bool license_is_active() {
  // A stored record that is not valid for this physical ESP8266 is never
  // treated as active. This also rejects an EEPROM image copied from another
  // device even when its checksum is intact.
  if (!record_matches_device() || _licenseRecord.status != LICENSE_ACTIVE) {
    return false;
  }

  // A TEMPORARY license is considered active while the phone-supplied runtime
  // clock is available and the term has not expired. PERMANENT licenses do not
  // need a clock and never expire.
  if (_licenseRecord.type == LICENSE_TEMPORARY) {
    const uint32_t now = current_phone_epoch();
    if (_temporaryExpired || _licenseRecord.expirationEpoch == 0 || now == 0) {
      return false;
    }
    if (now >= _licenseRecord.expirationEpoch) {
      mark_temporary_expired();
      return false; // expired -> LOCKED
    }
  }

  return _licenseRecord.type == LICENSE_PERMANENT ||
         _licenseRecord.type == LICENSE_TEMPORARY;
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

bool license_has_record() {
  return record_is_valid();
}

const char* license_get_status_reason() {
  if (!record_is_valid()) return "NO_LICENSE";
  if (!record_matches_device()) return "SERIAL_MISMATCH";
  if (_licenseRecord.status != LICENSE_ACTIVE) return "INVALID";
  if (_licenseRecord.type == LICENSE_PERMANENT) return "ACTIVE";
  if (_licenseRecord.type != LICENSE_TEMPORARY ||
      _licenseRecord.expirationEpoch == 0) {
    return "INVALID";
  }
  const uint32_t now = current_phone_epoch();
  if (_temporaryExpired || now >= _licenseRecord.expirationEpoch) {
    mark_temporary_expired();
    return "EXPIRED";
  }
  if (now == 0) return "TIME_UNAVAILABLE";
  return "ACTIVE";
}

const char* license_get_status_message() {
  const char* reason = license_get_status_reason();
  if (strcmp(reason, "ACTIVE") == 0) return "License active";
  if (strcmp(reason, "EXPIRED") == 0) return "Temporary license expired";
  if (strcmp(reason, "TIME_UNAVAILABLE") == 0) {
    return "Waiting for phone time";
  }
  if (strcmp(reason, "SERIAL_MISMATCH") == 0) {
    return "License belongs to another device";
  }
  if (strcmp(reason, "INVALID") == 0) return "License record invalid";
  return "License required for this device";
}

// ---------------------------------------------------------
// Activation
// ---------------------------------------------------------
bool license_attempt_activate(const String& base32code, uint32_t activationEpoch) {
  strcpy(last_activation_reason, "");

  if (base32code.length() == 0) {
    strcpy(last_activation_reason, "EMPTY_CODE");
    return false;
  }

#if PUBLIC_KEY_CONFIGURED == 0
  // No production public key configured. Every activation must fail.
  (void)base32code;
  (void)activationEpoch;
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

  // 5. Validate the phone timestamp after the signed code checks. It is only
  // sanity-checked here; no external time lookup is performed.
  if (!valid_phone_epoch(activationEpoch)) {
    strcpy(last_activation_reason, "INVALID_TIMESTAMP");
    return false;
  }
  if (phone_time_would_rollback(activationEpoch)) {
    record_clock_rollback();
    strcpy(last_activation_reason, "CLOCK_ROLLBACK");
    return false;
  }

  // 6. Use the validated phone timestamp for transition and expiry
  // calculations. The signed payload, Base32 and signature rules are unchanged.
  const uint32_t now = activationEpoch;

  // 7. Replay protection: SHA-256 fingerprint of the whole 83-byte code.
  uint8_t replay[32];
  license_compute_replay_hash(decoded, decodedLen, replay);
  bool alreadyUsed =
      (_licenseRecord.magic == LICENSE_EEPROM_MAGIC) &&
      (memcmp(_licenseRecord.replayHash, replay, sizeof(replay)) == 0);
  if (alreadyUsed) {
    strcpy(last_activation_reason, "ALREADY_USED");
    return false;
  }

  // 8. Transition policy (LOCKED/TEMPORARY/PERMANENT).
  uint8_t newType = (pl.type == LICENSE_PERMANENT) ? LICENSE_PERMANENT : LICENSE_TEMPORARY;
  if (!transition_allowed(newType, now)) {
    return false; // reason already set
  }

  // 9. Compute activation (creation) date + expiration from the phone time.
  uint32_t activation = now;
  uint32_t expiration = 0; // 0 = permanent
  if (newType == LICENSE_TEMPORARY) {
    if (!add_months_clamped(activation, pl.months, expiration)) {
      strcpy(last_activation_reason, "INVALID_TERM");
      return false;
    }
  }

  // 10. Build + persist ONLY after every check passes.
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

  // Persist the accepted phone time before the license record. This guarantees
  // a reboot cannot compare a future activation against an older clock value.
  const PhoneTimeResult timeResult =
      accept_phone_time(activationEpoch, true, true);
  if (timeResult == PHONE_TIME_ROLLBACK) {
    strcpy(last_activation_reason, "CLOCK_ROLLBACK");
    return false;
  }
  if (timeResult != PHONE_TIME_ACCEPTED) {
    strcpy(last_activation_reason, "CLOCK_PERSIST_FAILED");
    return false;
  }

  if (!license_persist(rec)) {
    strcpy(last_activation_reason, "EEPROM_COMMIT_FAILED");
    return false;
  }

  strcpy(last_activation_reason, "OK");
  return true;
}

// =========================================================
// License commands over WebSocket
//
// These helpers are intentionally dependency-free (no JSON library, no
// socket). They only interpret the small set of license commands and build
// the reply string. The caller (car_guard.ino onWsEvent) sends the reply.
// Security: never returns the replay hash, never echoes or logs the raw
// activation code, and relies on license_attempt_activate() — the only
// activation path — which itself requires a valid phone timestamp.
// =========================================================

// Minimal, dependency-free JSON string-value lookup for `"key":"..."`.
// Returns true and sets `out` when the key is found with a string value.
static bool jsonGetString(const char* json, const char* key, String& out) {
  if (json == NULL || key == NULL) return false;

  char needle[32];
  size_t kn = strlen(key);
  if (kn + 3 > sizeof(needle)) return false;
  needle[0] = '"';
  memcpy(needle + 1, key, kn);
  needle[kn + 1] = '"';
  needle[kn + 2] = '\0';

  const char* p = strstr(json, needle);
  if (p == NULL) return false;
  p += strlen(needle);

  while (*p == ' ' || *p == '\t' || *p == '\r' || *p == '\n') p++;
  if (*p != ':') return false;
  p++;
  while (*p == ' ' || *p == '\t' || *p == '\r' || *p == '\n') p++;
  if (*p != '"') return false;
  p++;

  const char* start = p;
  while (*p != '\0' && *p != '"') p++;   // license codes are [A-Z2-7], no escapes
  out = "";
  for (const char* q = start; q < p; ++q) out += *q;
  return true;
}

// Minimal JSON unsigned-integer lookup for UTC Unix-second fields.
// The activation timestamp is numeric, required, non-empty and bounded to the
// same uint32_t range used by LicenseRecord; no JSON library or network clock
// is involved.
static bool jsonGetUint32(const char* json, const char* key, uint32_t& out) {
  if (json == NULL || key == NULL) return false;

  char needle[48];
  size_t kn = strlen(key);
  if (kn + 3 > sizeof(needle)) return false;
  needle[0] = '"';
  memcpy(needle + 1, key, kn);
  needle[kn + 1] = '"';
  needle[kn + 2] = '\0';

  const char* p = strstr(json, needle);
  if (p == NULL) return false;
  p += strlen(needle);

  while (*p == ' ' || *p == '\t' || *p == '\r' || *p == '\n') p++;
  if (*p != ':') return false;
  p++;
  while (*p == ' ' || *p == '\t' || *p == '\r' || *p == '\n') p++;
  if (*p < '0' || *p > '9') return false;

  uint64_t value = 0;
  while (*p >= '0' && *p <= '9') {
    const uint64_t digit = (uint64_t)(*p - '0');
    if (value > (0xFFFFFFFFULL - digit) / 10ULL) return false;
    value = value * 10ULL + digit;
    p++;
  }

  while (*p == ' ' || *p == '\t' || *p == '\r' || *p == '\n') p++;
  if (*p != ',' && *p != '}' && *p != '\0') return false;

  const uint32_t epoch = (uint32_t)value;
  if (!valid_phone_epoch(epoch)) return false;
  out = epoch;
  return true;
}

bool license_handle_ws_command(const char* json, const char* deviceSerial, String& response) {
  if (json == NULL) return false;

  String cmd;
  if (!jsonGetString(json, "cmd", cmd)) return false; // not a recognized command frame

  // 1. DEVICE_SERIAL
  if (cmd == "DEVICE_SERIAL") {
    response = "{\"type\":\"DEVICE_SERIAL\",\"serial\":\"";
    response += deviceSerial;
    response += "\"}";
    return true;
  }

  // 2. LICENSE_STATUS  (no secrets: no replay hash, no serial, no code)
  if (cmd == "LICENSE_STATUS") {
    uint32_t currentTime = 0;
    // The field is optional for compatibility with older clients. Car Guard
    // sends it on every status query so temporary expiry also works after a
    // reboot without an external time service.
    if (jsonGetUint32(json, "currentTime", currentTime)) {
      // A rollback is recorded and rejected; the previous runtime clock stays
      // in force, so a stale phone cannot extend a temporary license.
      accept_phone_time(currentTime, false, false);
    }

    bool active = license_is_active();
    String licType = "NONE";
    uint32_t expires = 0;
    // Keep the persisted TEMPORARY type and expiry visible while LOCKED so
    // the UI can distinguish an expired term from a device with no record.
    if (license_has_record()) {
      licType = (license_get_type() == LICENSE_PERMANENT) ? "PERMANENT" : "TEMPORARY";
      expires = license_get_expiration();
    }
    response = "{\"type\":\"LICENSE_STATUS\",\"status\":\"";
    response += active ? "ACTIVE" : "LOCKED";
    response += "\",\"licenseType\":\"";
    response += licType;
    response += "\",\"expires\":";
    response += String((unsigned long)expires);
    response += "}";
    return true;
  }

  // 3. LICENSE_ACTIVATE
  if (cmd == "LICENSE_ACTIVATE") {
    String code;
    if (!jsonGetString(json, "code", code) || code.length() == 0) {
      response = "{\"type\":\"LICENSE_RESULT\",\"status\":\"ERROR\",\"reason\":\"MISSING_CODE\",\"expires\":0}";
      return true;
    }

    uint32_t activationTime = 0;
    if (!jsonGetUint32(json, "activationTime", activationTime)) {
      response = "{\"type\":\"LICENSE_RESULT\",\"status\":\"ERROR\",\"reason\":\"INVALID_TIMESTAMP\",\"expires\":0}";
      return true;
    }

    bool ok = license_attempt_activate(code, activationTime);
    if (ok) {
      response = "{\"type\":\"LICENSE_RESULT\",\"status\":\"OK\",\"reason\":\"";
      response += String(last_activation_reason);
      response += "\",\"expires\":";
      response += String((unsigned long)license_get_expiration());
      response += "}";
    } else {
      response = "{\"type\":\"LICENSE_RESULT\",\"status\":\"ERROR\",\"reason\":\"";
      response += String(last_activation_reason);
      response += "\",\"expires\":0}";
    }
    return true;
  }

  // Some other command — not ours; let the caller decide.
  return false;
}
