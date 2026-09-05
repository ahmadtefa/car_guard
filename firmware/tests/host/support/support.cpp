// =============================================================
//  HOST TEST ONLY — Arduino/EEPROM/pins/WiFi/HTTP/WS emulation
//  plus the test-license minting helpers. Links only into the
//  host test binary compiled by
//  firmware/tests/test_license_expiry_blocks_telemetry.py.
// =============================================================

#include "support.h"
#include "openssl_decl.h"

#include <Arduino.h>
#include <EEPROM.h>
#include <Esp.h>
#include <ESP8266WiFi.h>
#include <ESP8266WebServer.h>
#include <WebSocketsServer.h>
#include <ESP8266mDNS.h>

#include <map>
#include <string>
#include <utility>
#include <vector>

// ---------------------------------------------------------
// Deterministic test clock
// ---------------------------------------------------------
static uint64_t g_fake_millis = 0;

uint32_t millis() { return (uint32_t)(g_fake_millis & 0xFFFFFFFFULL); }
uint32_t micros() { return millis() * 1000UL; }

void delay(unsigned long ms) { g_fake_millis += ms; }
void delayMicroseconds(unsigned int us) { (void)us; }

void stub_set_millis(uint32_t ms) { g_fake_millis = ms; }
void stub_advance_millis(uint32_t ms) { g_fake_millis += ms; }

// ---------------------------------------------------------
// Serial / MDNS singletons
// ---------------------------------------------------------
SerialStub Serial;
MDNSResponder MDNS;

// ---------------------------------------------------------
// Pins
// ---------------------------------------------------------
static int g_pin_level[64];
static int g_analog_level[64];

void pinMode(int pin, uint8_t mode) {
  (void)pin;
  (void)mode;
}

void digitalWrite(int pin, uint8_t value) {
  if (pin >= 0 && pin < 64) g_pin_level[pin] = value;
}

int digitalRead(int pin) {
  if (pin >= 0 && pin < 64) return g_pin_level[pin];
  return 0;
}

int analogRead(int pin) {
  if (pin >= 0 && pin < 64) return g_analog_level[pin];
  return 0;
}

int stub_pin_level(int pin) { return digitalRead(pin); }
int stub_digital_reads(int pin) { return digitalRead(pin); }

void stub_set_analog(int pin, int value) {
  if (pin >= 0 && pin < 64) g_analog_level[pin] = value;
}

void stub_reset_pins() {
  for (int i = 0; i < 64; i++) {
    g_pin_level[i] = LOW;
    g_analog_level[i] = 512;
  }
}

// ---------------------------------------------------------
// EEPROM — flash-like storage that survives simulated reboots.
// ---------------------------------------------------------
static uint8_t g_eeprom_storage[4096];

uint8_t* EEPROMClass::storage() { return g_eeprom_storage; }
void EEPROMClass::begin(size_t size) { (void)size; }
void EEPROMClass::end() {}
bool EEPROMClass::commit() { return true; }

uint8_t EEPROMClass::read(int addr) { return g_eeprom_storage[addr]; }
void EEPROMClass::write(int addr, uint8_t value) {
  g_eeprom_storage[addr] = value;
}

EEPROMClass EEPROM;

void stub_eeprom_wipe() {
  for (size_t i = 0; i < sizeof(g_eeprom_storage); i++) g_eeprom_storage[i] = 0;
}

const uint8_t* stub_eeprom_bytes() { return g_eeprom_storage; }

// ---------------------------------------------------------
// ESP identity / restart
// ---------------------------------------------------------
static bool g_restart_requested = false;

EspClass ESP;
void EspClass::restart() { g_restart_requested = true; }

bool stub_restart_requested() { return g_restart_requested; }
void stub_clear_restart() { g_restart_requested = false; }

// ---------------------------------------------------------
// WiFi
// ---------------------------------------------------------
static bool g_sta_connected = false;
static int g_softap_stations = 0;

WiFiClass WiFi;
int WiFiClass::status() { return g_sta_connected ? WL_CONNECTED : WL_DISCONNECTED; }
int WiFiClass::softAPgetStationNum() { return g_softap_stations; }

void stub_set_sta_connected(bool connected) { g_sta_connected = connected; }
void stub_set_softap_stations(int count) { g_softap_stations = count; }

// ---------------------------------------------------------
// HTTP server capture
// ---------------------------------------------------------
struct HttpState {
  HTTPMethod method = HTTP_GET;
  std::map<std::string, std::string> args;
  int code = 0;
  std::string content_type;
  std::string body;
};

static HttpState g_http;

HTTPMethod ESP8266WebServer::method() { return g_http.method; }

bool ESP8266WebServer::hasArg(const char* name) {
  return g_http.args.find(name == nullptr ? "" : name) != g_http.args.end();
}

String ESP8266WebServer::arg(const char* name) {
  auto it = g_http.args.find(name == nullptr ? "" : name);
  return it == g_http.args.end() ? String("") : String(it->second);
}

void ESP8266WebServer::send(int code) { g_http.code = code; }

void ESP8266WebServer::send(int code, const char* contentType,
                            const String& body) {
  g_http.code = code;
  g_http.content_type = contentType == nullptr ? "" : contentType;
  g_http.body = body.c_str();
}

void ESP8266WebServer::sendHeader(const char*, const char*, bool) {}

void stub_request_reset() { g_http = HttpState(); }
void stub_request_set_method(HTTPMethod method) { g_http.method = method; }
void stub_request_set_arg(const char* name, const char* value) {
  g_http.args[name] = value;
}
int stub_response_code() { return g_http.code; }
const char* stub_response_body() { return g_http.body.c_str(); }
const char* stub_response_content_type() { return g_http.content_type.c_str(); }

// ---------------------------------------------------------
// WebSocket capture — the heartbeat of this test: every frame
// the firmware emits is recorded here.
// ---------------------------------------------------------
struct WsState {
  int clients = 0;
  std::vector<std::string> broadcasts;
  std::vector<std::pair<uint8_t, std::string>> replies;
};

static WsState g_ws;

int WebSocketsServer::connectedClients() { return g_ws.clients; }

void WebSocketsServer::broadcastTXT(const String& payload) {
  g_ws.broadcasts.emplace_back(payload.c_str());
}

void WebSocketsServer::sendTXT(uint8_t clientId, const String& payload) {
  g_ws.replies.emplace_back(clientId, payload.c_str());
}

void stub_ws_reset() { g_ws.broadcasts.clear(); g_ws.replies.clear(); }
void stub_ws_set_clients(int count) { g_ws.clients = count; }
int stub_ws_broadcast_count() { return (int)g_ws.broadcasts.size(); }
const std::vector<std::string>& stub_ws_broadcasts() { return g_ws.broadcasts; }
const std::vector<std::pair<uint8_t, std::string>>& stub_ws_replies() {
  return g_ws.replies;
}

// ---------------------------------------------------------
// TEST keypair — private key. This key is intentionally PUBLIC:
// it mints licenses accepted only by host-test builds (whose
// verify path uses test_pubkey.cpp). Production devices embed a
// completely different public key, so nothing here can activate
// or extend a real device. SEC1 DER (121 bytes, P-256).
// ---------------------------------------------------------
static const uint8_t kTestPrivateKeyDer[] = {
    0x30, 0x77, 0x02, 0x01, 0x01, 0x04, 0x20, 0x39, 0x75, 0xbb, 0xca, 0xfe,
    0x95, 0x8e, 0x02, 0x4c, 0xb7, 0x65, 0xd0, 0xbc, 0x0f, 0x02, 0x10, 0xd7,
    0x53, 0x09, 0xe7, 0x15, 0x2e, 0x65, 0x90, 0x38, 0x98, 0xe4, 0x27, 0x80,
    0xd9, 0x2b, 0x88, 0xa0, 0x0a, 0x06, 0x08, 0x2a, 0x86, 0x48, 0xce, 0x3d,
    0x03, 0x01, 0x07, 0xa1, 0x44, 0x03, 0x42, 0x00, 0x04, 0x9c, 0x8c, 0x9c,
    0xcd, 0xe1, 0x7f, 0x10, 0xf5, 0xb0, 0x95, 0xd3, 0x42, 0x4a, 0xdf, 0x65,
    0x6a, 0xd6, 0xbb, 0xcf, 0x86, 0xb9, 0x5f, 0xd7, 0x04, 0xf1, 0x77, 0x93,
    0x4b, 0xf9, 0x45, 0x2b, 0x8e, 0x59, 0x23, 0x35, 0xf8, 0x8c, 0x9d, 0x95,
    0x4b, 0xc7, 0xbb, 0xb7, 0x75, 0x72, 0x0d, 0xa6, 0x53, 0x67, 0xce, 0x30,
    0x25, 0x15, 0xb0, 0x0e, 0xbe, 0x63, 0x11, 0x1d, 0x02, 0x64, 0xac, 0x29,
    0x80,
};

namespace {

// Real SHA-256 over libcrypto; the same digest the firmware uses.
bool host_sha256(const uint8_t* data, size_t len, uint8_t out32[32]) {
  EVP_MD_CTX* ctx = EVP_MD_CTX_new();
  if (ctx == NULL) return false;
  unsigned int out_len = 0;
  const bool ok =
      EVP_DigestInit_ex(ctx, EVP_sha256(), NULL) == 1 &&
      EVP_DigestUpdate(ctx, data, len) == 1 &&
      EVP_DigestFinal_ex(ctx, out32, &out_len) == 1 && out_len == 32;
  EVP_MD_CTX_free(ctx);
  return ok;
}

EC_KEY* load_test_private_key() {
  const unsigned char* p = kTestPrivateKeyDer;
  return d2i_ECPrivateKey(NULL, &p, (long)sizeof(kTestPrivateKeyDer));
}

}  // namespace

bool test_sign_license_payload(const uint8_t payload[19], uint8_t out_sig[64]) {
  if (payload == NULL || out_sig == NULL) return false;

  uint8_t hash[32];
  if (!host_sha256(payload, 19, hash)) return false;

  EC_KEY* key = load_test_private_key();
  if (key == NULL) return false;

  ECDSA_SIG* sig = ECDSA_do_sign(hash, (int)sizeof(hash), key);
  EC_KEY_free(key);
  if (sig == NULL) return false;

  const BIGNUM* r = NULL;
  const BIGNUM* s = NULL;
  ECDSA_SIG_get0(sig, &r, &s);
  const bool ok = r != NULL && s != NULL &&
                  BN_bn2binpad(r, out_sig, 32) == 32 &&
                  BN_bn2binpad(s, out_sig + 32, 32) == 32;
  ECDSA_SIG_free(sig);
  return ok;
}

std::string test_base32_encode(const uint8_t* data, size_t len) {
  static const char* kAlphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
  if (data == NULL || len == 0) return std::string();

  std::string out;
  uint32_t buffer = 0;
  size_t bits = 0;
  for (size_t i = 0; i < len; i++) {
    buffer = (buffer << 8) | data[i];
    bits += 8;
    while (bits >= 5) {
      bits -= 5;
      out += kAlphabet[(buffer >> bits) & 0x1F];
    }
  }
  if (bits > 0) {
    // Canonical: trailing bits are zero by construction.
    out += kAlphabet[(buffer << (5 - bits)) & 0x1F];
  }
  return out;
}

std::string test_build_license_code(const char serial12[12], uint8_t type,
                                    uint16_t year, uint8_t month, uint8_t day,
                                    uint8_t months) {
  if (serial12 == NULL) return std::string();

  uint8_t payload[19];
  payload[0] = 0x01;  // protocol version
  for (int i = 0; i < 12; i++) payload[1 + i] = (uint8_t)serial12[i];
  payload[13] = type;
  payload[14] = (uint8_t)(year >> 8);
  payload[15] = (uint8_t)(year & 0xFF);
  payload[16] = month;
  payload[17] = day;
  payload[18] = months;

  uint8_t signature[64];
  if (!test_sign_license_payload(payload, signature)) return std::string();

  uint8_t decoded[19 + 64];
  for (int i = 0; i < 19; i++) decoded[i] = payload[i];
  for (int i = 0; i < 64; i++) decoded[19 + i] = signature[i];

  return test_base32_encode(decoded, sizeof(decoded));
}
