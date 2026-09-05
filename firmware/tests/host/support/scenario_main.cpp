// =============================================================
//  HOST TEST ONLY — license-expiry telemetry gate scenario.
//
//  This driver links the PRODUCTION, UNMODIFIED firmware sources
//  (car_guard.ino, license.cpp, license_helpers.cpp) against the
//  host stubs and proves — at the firmware level — the full
//  sequence the user asked about:
//
//     ACTIVE -> (expiry) -> LOCKED -> telemetry blocked ->
//     reboot -> still LOCKED -> telemetry still blocked
//
//  It exercises the real production gate functions:
//   * license_is_active() / license_load() / license state machine
//   * broadcastWsData()  — the WebSocket telemetry emitter gate
//   * handleData()       — the HTTP /data telemetry gate
//   * handleRoot()       — the status page
//   * handleTestFan/handleFanOn/handleFanOff/handleMute/
//     handleCalibrateVoltage — protected control commands
//   * the real WebSocket command path onWsEvent() used by the app
//
//  Time is deterministic: licenses are minted at a fixed epoch
//  kT0, the phone-clock messages inject fixed epoch values, and
//  millis() advances through a host stub. Nothing waits in real
//  time and no license-duration constant was shortened in the
//  production code.
// =============================================================

#include <stdint.h>
#include <stdio.h>
#include <string>

#include <Arduino.h>
#include <EEPROM.h>
#include <Esp.h>
#include <ESP8266WebServer.h>
#include <ESP8266WiFi.h>
#include <WebSocketsServer.h>

#include "license.h"
#include "support.h"

// ---------------------------------------------------------
// Production globals / handlers from car_guard.ino (unchanged).
// ---------------------------------------------------------
extern float filteredTemp;
extern float filteredVolt;
extern float lastBroadcastTemp;
extern float lastBroadcastVolt;

void broadcastWsData();
void handleData();
void handleRoot();
void handleTestFan();
void handleFanOn();
void handleFanOff();
void handleMute();
void handleCalibrateVoltage();
void onWsEvent(uint8_t clientId, WStype_t type, uint8_t* payload,
               size_t length);

// ---------------------------------------------------------
// Deterministic scenario constants.
// kT0 = 2026-01-15T12:00:00Z. The test chip id 0x00123456 makes
// the device serial "KCG_00123456", and the one-month test
// license is minted at kT0 with the TEST keypair.
// ---------------------------------------------------------
static const uint32_t kT0 = 1768478400UL;
static const char kDeviceSerial[] = "KCG_00123456";
static const int kRelayPin = 0;  // production RELAY_PIN = D3 = 0

static int g_pass = 0;
static int g_fail = 0;

#define CHECK(cond, msg)                                    \
  do {                                                      \
    if (cond) {                                             \
      g_pass++;                                             \
      printf("ok    - %s\n", msg);                          \
    } else {                                                \
      g_fail++;                                             \
      printf("FAIL  - %s\n", msg);                          \
    }                                                       \
  } while (0)

static void mark(const char* tag) { printf("[MARK] %s\n", tag); }

static void sendWsText(const std::string& json) {
  onWsEvent(0, WStype_TEXT, (uint8_t*)json.c_str(), json.size());
}

static void wsStatus(uint32_t currentTime) {
  std::string json = "{\"cmd\":\"LICENSE_STATUS\",\"currentTime\":";
  json += std::to_string(currentTime);
  json += "}";
  sendWsText(json);
}

static void wsActivate(const std::string& code, uint32_t activationTime) {
  std::string json = "{\"cmd\":\"LICENSE_ACTIVATE\",\"code\":\"" + code +
                     "\",\"activationTime\":" + std::to_string(activationTime) +
                     "}";
  sendWsText(json);
}

static std::string lastReply() {
  const auto& replies = stub_ws_replies();
  return replies.empty() ? std::string() : replies.back().second;
}

static bool lastReplyHas(const std::string& sub) {
  return lastReply().find(sub) != std::string::npos;
}

static bool broadcastJoinedHas(const std::string& sub) {
  for (const auto& frame : stub_ws_broadcasts()) {
    if (frame.find(sub) != std::string::npos) return true;
  }
  return false;
}

static void setLiveReadings(float temp, float volt) {
  filteredTemp = temp;
  filteredVolt = volt;
}

static void httpGet(void (*handler)()) {
  stub_request_reset();
  stub_request_set_method(HTTP_GET);
  handler();
}

static std::string httpBody() { return stub_response_body(); }

int main() {
  printf("# CarGuard host firmware test: license expiry blocks telemetry\n");

  stub_eeprom_wipe();
  stub_reset_pins();
  stub_set_analog(A0, 512);
  stub_set_sta_connected(true);
  stub_set_softap_stations(1);
  stub_ws_set_clients(1);
  stub_set_millis(0);

  // =======================================================
  // PHASE 1 — fresh module boots LOCKED; everything gated.
  // =======================================================
  license_init();
  license_load();

  CHECK(!license_is_active(), "P1 fresh boot is LOCKED (no license)");
  CHECK(std::string(license_get_status_reason()) == "NO_LICENSE",
        "P1 reason NO_LICENSE");

  wsStatus(kT0);
  CHECK(lastReplyHas("\"type\":\"LICENSE_STATUS\"") &&
            lastReplyHas("\"status\":\"LOCKED\"") &&
            lastReplyHas("\"licenseType\":\"NONE\""),
        "P1 WS LICENSE_STATUS answers LOCKED/NONE");

  // WebSocket telemetry gate (production broadcastWsData path).
  setLiveReadings(91.7f, 13.42f);
  stub_ws_reset();
  broadcastWsData();
  CHECK(stub_ws_broadcast_count() == 0,
        "P1 WebSocket emits ZERO telemetry frames while LOCKED");

  // HTTP telemetry gate (production handleData path).
  httpGet(&handleData);
  CHECK(stub_response_code() == 200 && httpBody().find("\"temp\":0.0") != std::string::npos &&
            httpBody().find("\"volt\":0.00") != std::string::npos &&
            httpBody().find("91.7") == std::string::npos &&
            httpBody().find("13.42") == std::string::npos,
        "P1 HTTP /data redacts temp/volt while LOCKED");
  CHECK(httpBody().find("\"licenseStatus\":\"LOCKED\"") != std::string::npos,
        "P1 HTTP /data reports licenseStatus LOCKED");

  // Protected control commands are refused (423 LICENSE_REQUIRED).
  {
    httpGet(&handleTestFan);
    bool testfan = stub_response_code() == 423 &&
                   httpBody() == "LICENSE_REQUIRED";
    httpGet(&handleFanOn);
    bool fanon = stub_response_code() == 423 && httpBody() == "LICENSE_REQUIRED";
    httpGet(&handleFanOff);
    bool fanoff = stub_response_code() == 423 && httpBody() == "LICENSE_REQUIRED";
    httpGet(&handleMute);
    bool mute = stub_response_code() == 423 && httpBody() == "LICENSE_REQUIRED";
    stub_request_reset();
    stub_request_set_arg("realVolt", "13.90");
    handleCalibrateVoltage();
    bool calib = stub_response_code() == 423 && httpBody() == "LICENSE_REQUIRED";
    CHECK(testfan && fanon && fanoff && mute && calib,
          "P1 fan/testfan/mute/calibrate all rejected with 423 while LOCKED");
  }
  CHECK(stub_pin_level(kRelayPin) == LOW, "P1 relay stays OFF while LOCKED");

  httpGet(&handleRoot);
  CHECK(httpBody().find("LICENSE REQUIRED") != std::string::npos &&
            httpBody().find("91.7") == std::string::npos,
        "P1 status page shows LICENSE REQUIRED, no readings");

  // =======================================================
  // PHASE 1.5 — a tampered license is rejected BEFORE the valid
  // activation (proves the ECDSA verification path is real).
  // =======================================================
  {
    std::string code = test_build_license_code(kDeviceSerial, 0, 2026, 1, 15, 1);
    CHECK(!code.empty(), "P1.5 test license code minted");
    char& pos = code[5];
    pos = (pos == 'A') ? 'B' : 'A';  // corrupt a payload character
    wsActivate(code, kT0);
    CHECK(lastReplyHas("\"status\":\"ERROR\"") &&
              lastReplyHas("\"reason\":\"SIGNATURE_INVALID\""),
          "P1.5 tampered license rejected with SIGNATURE_INVALID");
    CHECK(!license_is_active(), "P1.5 still LOCKED after tampered code");
  }

  // =======================================================
  // PHASE 2 — valid ONE-MONTH temporary license activates at
  // kT0; telemetry starts flowing.
  // =======================================================
  std::string tempCode = test_build_license_code(kDeviceSerial, 0, 2026, 1, 15, 1);
  wsActivate(tempCode, kT0);
  CHECK(lastReplyHas("\"status\":\"OK\""), "P2 valid 1-month license accepted");
  CHECK(license_is_active(), "P2 device ACTIVE after activation");
  CHECK(std::string(license_get_status_reason()) == "ACTIVE",
        "P2 reason ACTIVE");
  CHECK(license_get_type() == LICENSE_TEMPORARY, "P2 type TEMPORARY");

  const uint32_t expiry = license_get_expiration();
  CHECK(expiry > kT0 && expiry - kT0 >= 27UL * 24 * 3600 &&
            expiry - kT0 <= 32UL * 24 * 3600,
        "P2 expiry ≈ kT0 + 1 calendar month");

  // A successful activation pushes the first live frame immediately
  // (production sendLicenseWsReply behavior): the app sees readings at
  // once, without waiting for the next sensor tick.
  CHECK(broadcastJoinedHas("91.7,13.42"),
        "P2 firmware pushes the first telemetry frame on activation");

  stub_ws_reset();
  setLiveReadings(95.5f, 12.34f);
  broadcastWsData();
  CHECK(stub_ws_broadcast_count() == 1 &&
            broadcastJoinedHas("95.5,12.34"),
        "P2 WebSocket broadcasts live telemetry while ACTIVE");

  httpGet(&handleData);
  CHECK(httpBody().find("\"temp\":95.5") != std::string::npos &&
            httpBody().find("\"volt\":12.34") != std::string::npos &&
            httpBody().find("\"licenseStatus\":\"ACTIVE\"") != std::string::npos,
        "P2 HTTP /data serves live readings with licenseStatus ACTIVE");

  httpGet(&handleFanOn);
  CHECK(stub_response_code() == 200, "P2 /fanon accepted while ACTIVE");
  CHECK(stub_pin_level(kRelayPin) == HIGH, "P2 relay switched ON");
  httpGet(&handleFanOff);
  CHECK(stub_response_code() == 200 && stub_pin_level(kRelayPin) == LOW,
        "P2 /fanoff accepted, relay OFF");
  httpGet(&handleMute);
  CHECK(stub_response_code() == 200, "P2 /mute accepted while ACTIVE");
  mark("phase2_active_with_telemetry");

  // =======================================================
  // PHASE 3 — 60 seconds before expiry: still ACTIVE.
  // =======================================================
  wsStatus(expiry - 60);
  CHECK(lastReplyHas("\"status\":\"ACTIVE\""),
        "P3 WS status ACTIVE 60s before expiry");
  stub_ws_reset();
  setLiveReadings(96.1f, 12.40f);
  broadcastWsData();
  CHECK(stub_ws_broadcast_count() == 1 && broadcastJoinedHas("96.1,12.40"),
        "P3 telemetry still broadcasting before expiry");
  mark("phase3_active_before_expiry");

  // =======================================================
  // PHASE 4 — the clock reaches the expiry: LOCKED, EXPIRED
  // reason, telemetry stops on BOTH channels.
  // =======================================================
  stub_ws_reset();
  wsStatus(expiry);
  CHECK(lastReplyHas("\"type\":\"LICENSE_STATUS\"") &&
            lastReplyHas("\"status\":\"LOCKED\"") &&
            lastReplyHas("\"licenseType\":\"TEMPORARY\""),
        "P4 WS status flips to LOCKED at expiry");
  CHECK(lastReplyHas(("\"expires\":" + std::to_string(expiry)).c_str()),
        "P4 WS reply still reports the expiry timestamp");
  CHECK(!license_is_active(), "P4 license_is_active() == false at expiry");
  CHECK(std::string(license_get_status_reason()) == "EXPIRED",
        "P4 reason EXPIRED");

  setLiveReadings(97.0f, 11.11f);
  broadcastWsData();
  CHECK(stub_ws_broadcast_count() == 0,
        "P4 WebSocket emits ZERO telemetry frames after expiry");

  httpGet(&handleData);
  CHECK(httpBody().find("\"temp\":0.0") != std::string::npos &&
            httpBody().find("\"volt\":0.00") != std::string::npos &&
            httpBody().find("\"licenseStatus\":\"LOCKED\"") != std::string::npos,
        "P4 HTTP /data redacted + LOCKED after expiry");
  CHECK(httpBody().find("expired") != std::string::npos,
        "P4 HTTP /data message says the temporary license expired");

  httpGet(&handleFanOn);
  CHECK(stub_response_code() == 423 && stub_pin_level(kRelayPin) == LOW,
        "P4 protected command refused (423) after expiry");
  mark("phase4_expired_locked_telemetry_blocked");

  // =======================================================
  // PHASE 5 — phone-clock games cannot revive the license.
  // =======================================================
  wsStatus(expiry - 3600);  // app clock moved BACK: must be rejected
  CHECK(lastReplyHas("\"status\":\"LOCKED\""),
        "P5 backdated phone clock rejected, still LOCKED");
  CHECK(!license_is_active(), "P5 still inactive after backdated clock");

  // A brand-new validly-signed license offered with a backdated
  // activation time must be rejected as CLOCK_ROLLBACK.
  {
    std::string code2 = test_build_license_code(kDeviceSerial, 0, 2026, 2, 1, 1);
    wsActivate(code2, expiry - 3600);
    CHECK(lastReplyHas("\"status\":\"ERROR\"") &&
              lastReplyHas("\"reason\":\"CLOCK_ROLLBACK\""),
          "P5 backdated activation rejected with CLOCK_ROLLBACK");
    CHECK(!license_is_active(), "P5 still inactive after backdated activation");
  }

  stub_advance_millis(2UL * 24 * 3600 * 1000);  // wall time keeps running
  CHECK(!license_is_active(), "P5 still inactive after 2 days elapsed");
  stub_ws_reset();
  setLiveReadings(97.0f, 11.11f);
  broadcastWsData();
  CHECK(stub_ws_broadcast_count() == 0,
        "P5 telemetry still blocked while time passes");

  wsStatus(expiry + 86400);  // phone clock forward: accepted, still locked
  CHECK(lastReplyHas("\"status\":\"LOCKED\"") && !license_is_active(),
        "P5 forward phone clock cannot revive (sticky expired flag)");
  mark("phase5_clock_games_blocked");

  // =======================================================
  // PHASE 6 — REBOOT: the module must wake up LOCKED and keep
  // telemetry blocked, without any help from the app.
  // =======================================================
  stub_ws_reset();
  stub_set_millis(5000);  // real boards restart millis() from 0
  license_init();
  license_load();  // the exact production boot sequence

  CHECK(!license_is_active(),
        "P6 rebooted module is LOCKED immediately (sticky EEPROM state)");
  CHECK(std::string(license_get_status_reason()) == "EXPIRED",
        "P6 reason EXPIRED after reboot");

  // Simulate the app reconnecting (as in production onWsEvent).
  onWsEvent(0, WStype_CONNECTED, NULL, 0);
  CHECK(lastReplyHas("\"status\":\"LOCKED\""),
        "P6 auto LICENSE_STATUS after reboot says LOCKED");

  setLiveReadings(97.0f, 11.11f);
  const int broadcastsAfterReconnect = stub_ws_broadcast_count();
  broadcastWsData();
  CHECK(broadcastsAfterReconnect == 0 && stub_ws_broadcast_count() == 0,
        "P6 WebSocket telemetry blocked after reboot");

  httpGet(&handleData);
  CHECK(httpBody().find("\"temp\":0.0") != std::string::npos &&
            httpBody().find("\"volt\":0.00") != std::string::npos &&
            httpBody().find("\"licenseStatus\":\"LOCKED\"") != std::string::npos,
        "P6 HTTP /data redacted after reboot");

  wsStatus(kT0 + 1200);  // phone tries a pre-expiry clock after reboot
  CHECK(lastReplyHas("\"status\":\"LOCKED\"") && !license_is_active(),
        "P6 pre-expiry phone clock rejected after reboot (rollback)");

  wsStatus(expiry + 2UL * 86400);  // forward clock: accepted but still locked
  CHECK(lastReplyHas("\"status\":\"LOCKED\"") && !license_is_active(),
        "P6 forward clock after reboot cannot revive the license");

  stub_ws_reset();
  broadcastWsData();
  CHECK(stub_ws_broadcast_count() == 0,
        "P6 telemetry STILL blocked after clock attempts");
  mark("phase6_reboot_stays_locked");

  // =======================================================
  // PHASE 7 — the ONLY way back is a genuine new signed license;
  // then telemetry resumes (proving the gate is exactly the
  // license state, not a stuck flag).
  // =======================================================
  {
    const uint32_t renewalTime = expiry + 2UL * 86400;
    std::string code3 =
        test_build_license_code(kDeviceSerial, 0, 2026, 2, 17, 1);
    wsActivate(code3, renewalTime);
    CHECK(lastReplyHas("\"status\":\"OK\""),
          "P7 genuine renewal license accepted from LOCKED");
    CHECK(license_is_active(), "P7 ACTIVE again after genuine renewal");
    CHECK(license_get_expiration() > expiry,
          "P7 new expiry beyond the old one");

    stub_ws_reset();
    setLiveReadings(88.8f, 14.01f);
    broadcastWsData();
    CHECK(stub_ws_broadcast_count() == 1 && broadcastJoinedHas("88.8,14.01"),
          "P7 telemetry resumes ONLY after genuine re-activation");
  }
  mark("phase7_renewal_via_signed_license_only");

  // =======================================================
  // PHASE 8 — a PERMANENT license never expires; the runtime
  // clock never locks it out (sanity for the gate semantics).
  // =======================================================
  {
    const uint32_t permTime = expiry + 2UL * 86400 + 3600;
    std::string permCode =
        test_build_license_code(kDeviceSerial, 1, 2026, 2, 18, 0);
    wsActivate(permCode, permTime);
    CHECK(lastReplyHas("\"status\":\"OK\"") && license_is_active(),
          "P8 TEMPORARY -> PERMANENT upgrade accepted");
    CHECK(license_get_type() == LICENSE_PERMANENT &&
              license_get_expiration() == 0,
          "P8 permanent license has no expiry");

    stub_advance_millis(30UL * 24 * 3600 * 1000);
    CHECK(license_is_active(), "P8 permanent ignores clock advance (+30d)");
    stub_ws_reset();
    setLiveReadings(90.5f, 13.99f);
    broadcastWsData();
    CHECK(stub_ws_broadcast_count() == 1,
          "P8 permanent telemetry unaffected by expiry clock");
  }
  mark("phase8_permanent_unaffected");

  // =======================================================
  printf("TAP SUMMARY: pass=%d fail=%d\n", g_pass, g_fail);
  printf(g_fail == 0 ? "RESULT: ALL CHECKS PASSED\n" : "RESULT: FAILURES\n");
  return g_fail == 0 ? 0 : 1;
}
