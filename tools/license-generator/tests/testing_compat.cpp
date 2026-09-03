// End-to-end compatibility proof.
// Runs the REAL firmware license functions over a Base32 code produced by the
// Python generator:
//   license_decode_base32 -> verify_ecdsa_p256_sha256 -> license_attempt_activate
//
// Modes (2nd argument, optional):
//   <none> / accept           Ensure the code is accepted and activated.
//   reject                   Ensure activation FAILS (any reason).
//   reject:REASON            Ensure activation FAILS with reason == REASON
//                            (e.g. reject:SERIAL_MISMATCH).
//
// In 'reject' modes the harness still requires decode + signature verification +
// payload parse to succeed (proving the code is otherwise cryptographically
// valid) — only the activation step must fail. On failure it prints
//   COMPAT_REJECTED: reason=<last_activation_reason>
// and exits 0 only when the expectation matched; otherwise exits 1.
#include "license.h"
#include "license_pubkey.h"
#include <bearssl/bearssl.h>
#include <stdio.h>
#include <stdlib.h>
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
uint32_t ESPClass::getChipId() {
  // Optional device-serial override (e.g. TEST_CHIP_ID=00000000) so the same
  // binary can test both the matching device and a NON-matching device.
  const char* s = getenv("TEST_CHIP_ID");
  if (s != NULL && s[0] != '\0') {
    return (uint32_t)strtoul(s, NULL, 16);
  }
  return 0x1234ABCDu;
}
void ESPClass::restart() {}
EEPROMClass EEPROM;
ESPClass ESP;

// Public key for the firmware. The file it comes from is selectable at build
// time so the same harness can be compiled against either:
//   - the git-ignored random EXTERNAL TEST key (test_pubkey.h, default), or
//   - the fixed Stage 4 known-answer PUBLIC key (known_pubkey.h).
// Neither header ever contains a private key.
extern const uint8_t LICENSE_PUBKEY[65];
#ifndef TEST_PUBKEY_HEADER
#define TEST_PUBKEY_HEADER "test_pubkey.h"
#endif
#include TEST_PUBKEY_HEADER   // defines LICENSE_PUBKEY (65 bytes)

// Real firmware translation units.
#include "license.cpp"
#include "license_helpers.cpp"

int main(int argc, char** argv) {
  if (argc < 2) {
    fprintf(stderr, "usage: testing_compat <BASE32_CODE> [accept|reject[:REASON]]\n");
    return 2;
  }
  std::string code = argv[1];
  std::string mode = (argc >= 3) ? argv[2] : "accept";
  std::string wantReason;
  if (mode.rfind("reject:", 0) == 0) {
    wantReason = mode.substr(7);
    mode = "reject";
  }
  bool expectAccept = (mode == "accept" || mode.empty());

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

  // 2. Verify signature with the firmware verifier (must be cryptographically valid).
  bool sigOk = verify_ecdsa_p256_sha256(payload, 19, sig, 64);
  if (!sigOk) {
    fprintf(stderr, "COMPAT_FAIL: verify_ecdsa_p256_sha256 rejected the signature\n");
    return 1;
  }

  // 3. Full activation (decode -> verify -> parse -> NTP -> replay -> persist).
  EEPROM.reset();
  license_init();
  license_load();
  bool ok = license_attempt_activate(code.c_str());
  const char* reason = last_activation_reason;

  if (expectAccept) {
    if (!ok) {
      fprintf(stderr, "COMPAT_FAIL: license_attempt_activate failed: %s\n", reason);
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

  // Reject mode: activation MUST fail, but the code was cryptographically valid.
  if (ok) {
    fprintf(stderr, "COMPAT_FAIL: expected activation to fail, but it succeeded\n");
    return 1;
  }
  if (!wantReason.empty() && strcmp(reason, wantReason.c_str()) != 0) {
    fprintf(stderr, "COMPAT_FAIL: expected reason '%s', got '%s'\n",
            wantReason.c_str(), reason);
    return 1;
  }
  printf("COMPAT_REJECTED: activation failed end-to-end (signature was valid)\n");
  printf("  reason=%s\n", reason);
  return 0;
}
