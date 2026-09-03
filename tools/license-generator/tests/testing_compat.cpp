// End-to-end compatibility proof.
// Runs the REAL firmware license functions over a Base32 code produced by the
// Python generator:
//   license_decode_base32 -> verify_ecdsa_p256_sha256 -> license_attempt_activate
//
// On success prints "COMPAT_OK" and exits 0.
#include "license.h"
#include "license_pubkey.h"
#include <bearssl/bearssl.h>
#include <stdio.h>
#include <string.h>
#include <string>

#include <Arduino.h>
#include <EEPROM.h>
#include <Esp.h>

unsigned long g_ms = 0;
unsigned long millis() { return g_ms; }
void delay(unsigned long m) { g_ms += m; }
void delayMicroseconds(unsigned int us) { (void)us; }
void pinMode(int p, int m) { (void)p; (void)m; }
void digitalWrite(int p, int v) { (void)p; (void)v; }
int digitalRead(int p) { (void)p; return 0; }
int analogRead(int p) { (void)p; return 0; }
void configTime(int t, int d, const char* a, const char* b, const char* c) {
  (void)t; (void)d; (void)a; (void)b; (void)c;
}
uint32_t ESPClass::getChipId() { return 0x1234ABCDu; }
void ESPClass::restart() {}
EEPROMClass EEPROM;
ESPClass ESP;

// TEST (non-production) public key — derived from the TEST scalar. This is the
// key the firmware must be compiled with (PUBLIC_KEY_CONFIGURED=1) to accept
// codes produced by the generator's TEST key.
extern const uint8_t LICENSE_PUBKEY[65];
const uint8_t LICENSE_PUBKEY[65] = {
  0x04,0xE6,0x7B,0x1E,0xC6,0xB0,0x6D,0xE9,0xB6,0x79,0x93,0x5F,0x9D,0x59,0x43,0x03,
  0x33,0x3E,0xF3,0x13,0x33,0x5C,0x42,0x33,0xC7,0x85,0x13,0xC1,0x57,0x80,0x32,0x8C,
  0xBC,0x72,0x7C,0x3A,0x92,0x76,0xF5,0x31,0xBA,0xC3,0x3F,0x06,0xB6,0x3D,0xB4,0xC3,
  0x38,0x78,0x01,0x5E,0x86,0xA9,0xF4,0xBF,0xF1,0xA2,0xC3,0x18,0xD9,0xEE,0xE9,0x92,0x66
};

// Real firmware translation units.
#include "license.cpp"
#include "license_helpers.cpp"

int main(int argc, char** argv) {
  if (argc < 2) {
    fprintf(stderr, "usage: testing_compat <BASE32_CODE>\n");
    return 2;
  }
  std::string code = argv[1];

  // 1. Decode with the firmware decoder.
  uint8_t decoded[83];
  size_t decodedLen = 0;
  if (!license_decode_base32(code.c_str(), code.size(), decoded, sizeof(decoded), &decodedLen)) {
    fprintf(stderr, "COMPAT_FAIL: license_decode_base32 rejected the code\n");
    return 1;
  }
  if (decodedLen != 83) {
    fprintf(stderr, "COMPAT_FAIL: decoded length %zu != 83\n", decodedLen);
    return 1;
  }
  const uint8_t* payload = decoded;              // 19 bytes
  const uint8_t* sig = decoded + 19;             // 64 bytes raw r||s

  // 2. Verify signature with the firmware verifier.
  if (!verify_ecdsa_p256_sha256(payload, 19, sig, 64)) {
    fprintf(stderr, "COMPAT_FAIL: verify_ecdsa_p256_sha256 rejected the signature\n");
    return 1;
  }

  // 3. Full activation (decode -> verify -> parse -> NTP -> replay -> persist).
  EEPROM.reset();
  license_init();
  license_load();
  bool ok = license_attempt_activate(code.c_str());
  if (!ok) {
    fprintf(stderr, "COMPAT_FAIL: license_attempt_activate failed: %s\n", last_activation_reason);
    return 1;
  }
  if (!license_is_active()) {
    fprintf(stderr, "COMPAT_FAIL: license not active after activation\n");
    return 1;
  }

  printf("COMPAT_OK: code accepted end-to-end by firmware\n");
  printf("  type=%u expiration=%u serial=%s\n",
         license_get_type(), license_get_expiration(), license_get_serial());
  return 0;
}
