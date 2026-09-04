// =========================================================
//  CarGuard System — ESP8266 (NodeMCU) Firmware
//  Synced with the Flutter app (arena/01a01dde-car-guard).
//
//  Changes marked with [APP SYNC] are additive and safe:
//   1. alarmActive is now kept in sync inside handleAlarm()
//   2. The WebSocket CSV payload carries alarm + muted (fields 10, 11)
//   3. The /data JSON carries "alarm" and "muted"
//  The mobile app reads them to mirror the module's buzzer state.
//
//  [STA+mDNS] — optional home/hotspot join: the module keeps its own
//  CarGuard AP AND can additionally join the phone's hotspot (or home
//  router) as a station. While joined it announces itself via mDNS as
//  "car_guard.local" so the app finds it automatically — no IP handling.
//  Boot is NEVER blocked by missing networks (car safety first).
// =========================================================

#include <ESP8266WiFi.h>
#include <ESP8266WebServer.h>
#include <ESP8266HTTPUpdateServer.h>
#include <ESP8266mDNS.h>
#include <DNSServer.h>
#include <OneWire.h>
#include <DallasTemperature.h>
#include <EEPROM.h>
#include <WebSocketsServer.h>

// =========================================================
// PIN DEFINITIONS
// =========================================================
#define D0 16
#define D1 5
#define D2 4
#define D3 0
#define D4 2
#define D5 14
#define D6 12
#define D7 13
#define D8 15

// =========================================================
// OBJECTS
// =========================================================
ESP8266WebServer server(80);
ESP8266HTTPUpdateServer httpUpdater;
DNSServer dnsServer;
WebSocketsServer webSocket(81);

// =========================================================
// WIFI AP
// =========================================================
char ap_ssid[32] = "CarGaurd";
char ap_password[32] = "12345678";

// =========================================================
// DNS
// =========================================================
const byte DNS_PORT = 53;

// =========================================================
// PINS
// =========================================================
#define LED_PIN    2
#define BUZZER     D2
#define ONE_WIRE_BUS D1
#define ADC_PIN    A0
#define RELAY_PIN  D3

// =========================================================
// DS18B20
// =========================================================
OneWire oneWire(ONE_WIRE_BUS);
DallasTemperature sensors(&oneWire);

// =========================================================
// ADC
// =========================================================
const float ADC_MAX = 1023.0;
const float VREF    = 3.3;

// =========================================================
// DEFAULT SETTINGS
// =========================================================
float MAX_TEMP   = 97.0;
float FAN_ON_TEMP = 90.0;
float MIN_VOLT   = 12.0;
float MAX_VOLT   = 14.8;
float tempOffset = 0.0;

// =========================================================
// EEPROM
// =========================================================
#define EEPROM_SIZE      512
#include "license.h"

// [STA+mDNS] bumped: the Settings struct now ends with the optional
// station (hotspot) credentials; old stores reset once to defaults.
#define EEPROM_SIGNATURE 0xBEAF0008

struct Settings {
  uint32_t signature;
  float    maxTemp;
  float    fanOnTemp;
  float    minVolt;
  float    maxVolt;
  float    offset;
  float    r1;
  float    r2;
  float    voltCalib;
  float    sensorPullUp;
  char     installDate[16];
  char     wifiSSID[32];
  char     wifiPASS[32];
  // [STA+mDNS] network the module should JOIN (phone hotspot / home router).
  // Empty staSSID = stay pure AP (old behavior, zero risk).
  char     staSSID[32];
  char     staPASS[32];
};

// Keep the established EEPROM partition: settings at 0, license at 256.
static_assert(sizeof(Settings) <= LICENSE_EEPROM_OFFSET,
              "Settings overlap the reserved license EEPROM area");

Settings settings;

// =========================================================
// STA + mDNS (optional home/hotspot join)
// =========================================================
// The AP (CarGuard) MUST stay up so the app always has a way back in —
// we never switch to pure station mode. mDNS announces the module as
// "car_guard.local", with the HTTP API as _http._tcp on port 80 and the
// websocket as _ws._tcp on port 81.
bool mdnsStarted = false;

void maybeStartStaAndMdns() {
  if (settings.staSSID[0] == 0) return;

  WiFi.mode(WIFI_AP_STA);
  WiFi.begin(settings.staSSID, settings.staPASS);
}

// [STA+mDNS] Runs once as soon as WiFi is up (AP is always up, so this
// fires right after boot) AND also advertises the STA address once the
// module joins a hotspot. The fixed host name "car_guard" lets the app
// discover the module without any IP typing, on both paths.
void advertiseMdns() {
  if (mdnsStarted) return;

  if (MDNS.begin("car_guard")) {
    MDNS.addService("http",    "tcp", 80);
    MDNS.addService("ws",      "tcp", 81);
    MDNS.addService("carguard","tcp", 80);
    mdnsStarted = true;

    Serial.println("📡 mDNS up: car_guard.local");
    Serial.print("   AP ip:  ");
    Serial.println(WiFi.softAPIP());
    Serial.print("   STA ip: ");
    Serial.println(WiFi.localIP());
  }
}

// =========================================================
// FILTERS
// =========================================================
float filteredTemp = 25.0;
float filteredVolt = 12.0;

// =========================================================
// FAN
// =========================================================
const float FAN_HYSTERESIS = 5.0;
bool  fanState      = false;
bool  fanTestActive = false;
unsigned long fanTestStopAt = 0;

// =========================================================
// STATES
// =========================================================
unsigned long lastSensorRead    = 0;
unsigned long lastBuzz          = 0;
unsigned long lastLedBlink      = 0;
unsigned long lastNormalVoltTime = 0;
unsigned long lastWsBroadcast   = 0;
unsigned long lastClientCheck   = 0;

bool buzzState     = false;
bool buzzMuted     = false;
bool clientConnected = false;
bool ledState      = false;
bool alarmActive   = false;

// =========================================================
// WEBSOCKET BROADCAST OPTIMIZATION
// =========================================================
float lastBroadcastTemp = -999;
float lastBroadcastVolt = -999;

// =========================================================
// HELPER FUNCTIONS
// =========================================================
String getChipId() {
  char serial[20];
  uint32_t chipId = ESP.getChipId();
  sprintf(serial, "KCG_%08X", chipId);
  return String(serial);
}

// =========================================================
// LED
// =========================================================
void ledOn() {
  digitalWrite(LED_PIN, LOW);
  ledState = true;
}

void ledOff() {
  digitalWrite(LED_PIN, HIGH);
  ledState = false;
}

void ledBlink(int times, int delayTime) {
  for (int i = 0; i < times; i++) {
    ledOn();
    delay(delayTime);
    ledOff();
    delay(delayTime);
  }
}

// =========================================================
// SOUNDS  ——  Active Buzzer: digitalWrite فقط، مش tone()
// =========================================================

// نغمة بدء التشغيل — 3 نبضات صاعدة
void playStartupSound() {
  if (!license_is_active()) {
    digitalWrite(BUZZER, LOW);
    return;
  }
  for (int i = 0; i < 3; i++) {
    digitalWrite(BUZZER, HIGH);
    delay(100 + i * 60);   // 100 / 160 / 220 ms
    digitalWrite(BUZZER, LOW);
    delay(80);
  }
}

// نغمة حفظ الإعدادات — نبضتان سريعتان
void playSaveSuccessSound() {
  if (!license_is_active()) {
    digitalWrite(BUZZER, LOW);
    return;
  }
  digitalWrite(BUZZER, HIGH); delay(100);
  digitalWrite(BUZZER, LOW);  delay(80);
  digitalWrite(BUZZER, HIGH); delay(200);
  digitalWrite(BUZZER, LOW);
}

// نغمة اتصال عميل — نبضتان ثم واحدة طويلة
void playConnectSound() {
  if (!license_is_active()) {
    digitalWrite(BUZZER, LOW);
    return;
  }
  digitalWrite(BUZZER, HIGH); delay(100);
  digitalWrite(BUZZER, LOW);  delay(80);
  digitalWrite(BUZZER, HIGH); delay(100);
  digitalWrite(BUZZER, LOW);  delay(80);
  digitalWrite(BUZZER, HIGH); delay(320);
  digitalWrite(BUZZER, LOW);
}

// نغمة قطع الاتصال — طويلة ثم قصيرة
void playDisconnectSound() {
  if (!license_is_active()) {
    digitalWrite(BUZZER, LOW);
    return;
  }
  digitalWrite(BUZZER, HIGH); delay(320);
  digitalWrite(BUZZER, LOW);  delay(80);
  digitalWrite(BUZZER, HIGH); delay(100);
  digitalWrite(BUZZER, LOW);
}

// نغمة تأكيد (mute / test fan)
void playConfirmSound() {
  if (!license_is_active()) {
    digitalWrite(BUZZER, LOW);
    return;
  }
  digitalWrite(BUZZER, HIGH); delay(80);
  digitalWrite(BUZZER, LOW);  delay(60);
  digitalWrite(BUZZER, HIGH); delay(80);
  digitalWrite(BUZZER, LOW);
}

// إيقاف الصوت
void stopAlarmSound() {
  digitalWrite(BUZZER, LOW);
}

// =========================================================
// CORS
// =========================================================
void sendCORS() {
  server.sendHeader("Access-Control-Allow-Origin",  "*");
  server.sendHeader("Access-Control-Allow-Methods", "GET,POST,OPTIONS");
  server.sendHeader("Access-Control-Allow-Headers", "*");
}

// =========================================================
// EEPROM
// =========================================================
void saveSettings() {
  settings.signature = EEPROM_SIGNATURE;
  EEPROM.begin(EEPROM_SIZE);
  EEPROM.put(0, settings);
  EEPROM.commit();
  EEPROM.end();
  playSaveSuccessSound();
  Serial.println("✅ SETTINGS SAVED");
}

void loadSettings() {
  EEPROM.begin(EEPROM_SIZE);
  EEPROM.get(0, settings);
  EEPROM.end();

  if (settings.signature == EEPROM_SIGNATURE) {
    MAX_TEMP    = settings.maxTemp;
    FAN_ON_TEMP = settings.fanOnTemp;
    MIN_VOLT    = settings.minVolt;
    MAX_VOLT    = settings.maxVolt;
    tempOffset  = settings.offset;
    strcpy(ap_ssid,     settings.wifiSSID);
    strcpy(ap_password, settings.wifiPASS);
    Serial.println("✅ SETTINGS LOADED");
    Serial.print("📶 SSID: ");
    Serial.println(ap_ssid);
  } else {
    settings.signature   = EEPROM_SIGNATURE;
    settings.maxTemp     = 97.0;
    settings.fanOnTemp   = 90.0;
    settings.minVolt     = 12.0;
    settings.maxVolt     = 14.8;
    settings.offset      = 0.0;
    settings.r1          = 4700.0;
    settings.r2          = 1000.0;
    settings.voltCalib   = 1.0;
    settings.sensorPullUp = 4700.0;
    strcpy(settings.installDate, "2026-06-08");
    // [STA+mDNS] fresh unit starts as AP-only until /joinwifi is called.
    settings.staSSID[0] = 0;
    settings.staPASS[0] = 0;
    strcpy(settings.wifiSSID, "CarGaurd");
    strcpy(settings.wifiPASS, "12345678");
    strcpy(ap_ssid,     settings.wifiSSID);
    strcpy(ap_password, settings.wifiPASS);
    saveSettings();
  }
}

// =========================================================
// FAN
// =========================================================
void fanOn() {
  // Defense in depth: every path to the relay is safe even if a new caller
  // forgets to apply the endpoint-level license check.
  if (!license_is_active()) {
    digitalWrite(RELAY_PIN, LOW);
    fanState = false;
    fanTestActive = false;
    return;
  }
  digitalWrite(RELAY_PIN, HIGH);
  fanState = true;
  Serial.println("🌀 FAN ON");
}

void fanOff() {
  digitalWrite(RELAY_PIN, LOW);
  fanState = false;
  Serial.println("🌀 FAN OFF");
}

void updateFanControl() {
  if (!license_is_active()) {
    fanTestActive = false;
    fanOff();
    return;
  }
  if (fanTestActive) {
    if (millis() >= fanTestStopAt) {
      fanTestActive = false;
      fanOff();
    }
    return;
  }
  float fanOffTemp = FAN_ON_TEMP - FAN_HYSTERESIS;
  if (!fanState && filteredTemp >= FAN_ON_TEMP)  fanOn();
  else if (fanState && filteredTemp <= fanOffTemp) fanOff();
}

// =========================================================
// VOLTAGE
// =========================================================
float readVoltage() {
  long sum = 0;
  for (int i = 0; i < 10; i++) {
    sum += analogRead(ADC_PIN);
    delayMicroseconds(100);
  }
  float adc  = (sum / 10.0f) / ADC_MAX;
  float Vadc = adc * VREF;
  float Vin  = Vadc * ((settings.r1 + settings.r2) / settings.r2);
  return Vin * settings.voltCalib;
}

// =========================================================
// SENSORS
// =========================================================
void updateSensors() {
  if (millis() - lastSensorRead >= 1000) {
    lastSensorRead = millis();

    sensors.requestTemperatures();

    unsigned long start = millis();
    while (!sensors.isConversionComplete() && (millis() - start) < 750) {
      webSocket.loop();
      server.handleClient();
      dnsServer.processNextRequest();
      delay(1);
    }

    float t = sensors.getTempCByIndex(0);
    if (t != DEVICE_DISCONNECTED_C && t > -50 && t < 150) {
      float rawTemp = t + tempOffset;
      filteredTemp  = (filteredTemp * 0.7) + (rawTemp * 0.3);
    }

    float v    = readVoltage();
    filteredVolt = (filteredVolt * 0.7) + (v * 0.3);

    updateFanControl();
  }
}

// =========================================================
// ALARM  ——  نغمة واحدة عالية متقطعة بشكل واضح
// =========================================================
void handleAlarm() {
  // LOCKED is deliberately silent: licensing is not a vehicle alarm.
  if (!license_is_active()) {
    alarmActive = false;
    buzzState = false;
    buzzMuted = false;
    digitalWrite(BUZZER, LOW);
    return;
  }

  bool tempDanger  = filteredTemp >= MAX_TEMP;
  bool voltOutRange = (filteredVolt < MIN_VOLT || filteredVolt > MAX_VOLT);
  bool voltAlarmActive = false;

  if (!voltOutRange) {
    lastNormalVoltTime = millis();
  } else {
    if (millis() - lastNormalVoltTime >= 2000) {
      voltAlarmActive = true;
    }
  }

  bool danger = tempDanger || voltAlarmActive;

  // [APP SYNC] keep the global state so it can be reported to the app.
  alarmActive = danger;

  if (danger && !buzzMuted) {
    // ——— نغمة واحدة متقطعة: 200ms ON / 200ms OFF ———
    // غيّر الرقم 200 حسب الرغبة:
    //   150 = سريع جداً (urgent)
    //   200 = سريع واضح  ← مناسب
    //   350 = متوسط
    //   500 = بطيء
    if (millis() - lastBuzz >= 200) {
      lastBuzz   = millis();
      buzzState  = !buzzState;
      digitalWrite(BUZZER, buzzState ? HIGH : LOW);
    }
  } else {
    digitalWrite(BUZZER, LOW);
    buzzState = false;
    if (!danger) buzzMuted = false;
  }
}

// =========================================================
// LED STATUS
// =========================================================
void updateLedStatus() {
  if (millis() - lastClientCheck >= 2000) {
    lastClientCheck = millis();
    int numStations = WiFi.softAPgetStationNum();

    if (numStations > 0) {
      if (!clientConnected) {
        clientConnected = true;
        ledBlink(3, 100);
        Serial.println("📱 CLIENT CONNECTED");
        playConnectSound();
      }
    } else {
      if (clientConnected) {
        clientConnected = false;
        ledBlink(2, 150);
        Serial.println("📱 CLIENT DISCONNECTED");
        playDisconnectSound();
      }
    }
  }

  if (clientConnected) {
    if (millis() - lastLedBlink >= 500) {
      lastLedBlink = millis();
      ledState     = !ledState;
      digitalWrite(LED_PIN, ledState ? LOW : HIGH);
    }
  } else {
    ledOn();
  }
}

// =========================================================
// WEBSOCKET BROADCAST
// =========================================================
void broadcastWsData() {
  if (webSocket.connectedClients() == 0) return;

  if (abs(filteredTemp - lastBroadcastTemp) < 0.5 &&
      abs(filteredVolt - lastBroadcastVolt) < 0.1) {
    return;
  }

  lastBroadcastTemp = filteredTemp;
  lastBroadcastVolt = filteredVolt;

  // [APP SYNC] CSV protocol (11 fields):
  // temp,volt,fanState,?,maxTemp,fanOnTemp,minVolt,maxVolt,offset,alarm,muted
  String payload = String(filteredTemp, 1) + "," +
                   String(filteredVolt, 2) + "," +
                   String((license_is_active() &&
                           (fanState || fanTestActive)) ? 1 : 0) + ",0," +
                   String(MAX_TEMP, 1) + "," +
                   String(FAN_ON_TEMP, 1) + "," +
                   String(MIN_VOLT, 1) + "," +
                   String(MAX_VOLT, 1) + "," +
                   String(tempOffset, 2) + "," +
                   String((license_is_active() && alarmActive) ? 1 : 0) + "," +
                   String((license_is_active() && buzzMuted) ? 1 : 0);

  webSocket.broadcastTXT(payload);
}

// =========================================================
// WEBSOCKET EVENTS
// =========================================================
void sendLicenseWsReply(uint8_t clientId, const char* json) {
  String response;
  String serial = getChipId();
  if (license_handle_ws_command(json, serial.c_str(), response)) {
    webSocket.sendTXT(clientId, response);
  }
}

void onWsEvent(uint8_t clientId, WStype_t type, uint8_t* payload, size_t length) {
  switch (type) {
    case WStype_CONNECTED:
      Serial.printf("🔌 WS CLIENT #%u CONNECTED\n", clientId);
      sendLicenseWsReply(clientId, "{\"cmd\":\"DEVICE_SERIAL\"}");
      sendLicenseWsReply(clientId, "{\"cmd\":\"LICENSE_STATUS\"}");
      broadcastWsData();
      break;
    case WStype_TEXT: {
      // The license code is at most 133 characters; reject oversized frames
      // before copying so an arbitrary WebSocket client cannot exhaust RAM.
      char message[256];
      if (payload == NULL || length == 0 || length >= sizeof(message)) return;
      memcpy(message, payload, length);
      message[length] = '\0';
      sendLicenseWsReply(clientId, message);
      break;
    }
    case WStype_DISCONNECTED:
      Serial.printf("🔌 WS CLIENT #%u DISCONNECTED\n", clientId);
      break;
    default:
      break;
  }
}

// =========================================================
// API HANDLERS
// =========================================================
// [STA+mDNS] /joinwifi?ssid=..&pass=.. — learn the hotspot/home network.
// Saved to EEPROM; the module keeps its AP alive while trying to join.
void handleJoinWiFi() {
  sendCORS();
  if (server.method() == HTTP_OPTIONS) { server.send(204); return; }

  if (server.hasArg("ssid")) {
    String ssid = server.arg("ssid");
    String pass = server.hasArg("pass") ? server.arg("pass") : "";

    if (ssid.length() < 1 || ssid.length() > 31 || pass.length() > 31) {
      server.send(400, "text/plain", "INVALID LENGTH");
      return;
    }

    // Open network allowed: empty password is valid.
    if (pass.length() > 0 && pass.length() < 8) {
      server.send(400, "text/plain", "PASSWORD TOO SHORT");
      return;
    }

    ssid.toCharArray(settings.staSSID, 32);
    pass.toCharArray(settings.staPASS, 32);
    saveSettings();

    server.send(200, "text/plain", "OK");

    Serial.print("📡 Joining network: ");
    Serial.println(ssid);
    maybeStartStaAndMdns();
  } else {
    server.send(400, "text/plain", "MISSING PARAMETERS");
  }
}

void handleData() {
  sendCORS();
  if (server.method() == HTTP_OPTIONS) { server.send(204); return; }

  // [APP SYNC] alarm + muted mirror the buzzer state on the module.
  String json = "{";
  json += "\"temp\":"     + String(filteredTemp, 1) + ",";
  json += "\"volt\":"     + String(filteredVolt, 2) + ",";
  json += "\"maxTemp\":"  + String(MAX_TEMP)         + ",";
  json += "\"fanOnTemp\":" + String(FAN_ON_TEMP)     + ",";
  json += "\"minVolt\":"  + String(MIN_VOLT)         + ",";
  json += "\"maxVolt\":"  + String(MAX_VOLT)         + ",";
  json += "\"offset\":"   + String(tempOffset, 2)   + ",";
  json += "\"fanState\":" + String((license_is_active() &&
                                      (fanState || fanTestActive)) ? 1 : 0) + ",";
  json += "\"alarm\":"    + String((license_is_active() && alarmActive) ? 1 : 0) + ",";
  json += "\"muted\":"    + String((license_is_active() && buzzMuted) ? 1 : 0) + ",";
  json += "\"licenseStatus\":\"" + String(license_is_active() ? "ACTIVE" : "LOCKED") + "\",";
  json += "\"licenseType\":\"" +
          String(license_has_record()
                     ? (license_get_type() == LICENSE_PERMANENT ? "PERMANENT" : "TEMPORARY")
                     : "NONE") + "\",";
  json += "\"licenseMessage\":\"" + String(license_get_status_message()) + "\",";
  // [STA+mDNS] let the app show/route around the joined-network state.
  json += "\"staUp\":"    + String((WiFi.status() == WL_CONNECTED) ? 1 : 0) + ",";
  json += "\"staIp\":\""  + String(WiFi.localIP().toString()) + "\",";
  json += "\"mdns\":\""   + (mdnsStarted ? String("car_guard.local") : String("")) + "\"";
  json += "}";

  server.send(200, "application/json", json);
}

void handleSaveAllSettings() {
  sendCORS();
  if (server.method() == HTTP_OPTIONS) { server.send(204); return; }

  if (server.hasArg("maxTemp")   && server.hasArg("fanOnTemp") &&
      server.hasArg("minVolt")   && server.hasArg("maxVolt")   &&
      server.hasArg("offset")) {

    float newMaxTemp    = server.arg("maxTemp").toFloat();
    float newFanOnTemp  = server.arg("fanOnTemp").toFloat();
    float newMinVolt    = server.arg("minVolt").toFloat();
    float newMaxVolt    = server.arg("maxVolt").toFloat();
    float newOffset     = server.arg("offset").toFloat();

    if (newMaxTemp   >= 50  && newMaxTemp   <= 150 &&
        newFanOnTemp >= 40  && newFanOnTemp <= 140 &&
        newMinVolt   >= 8.0 && newMinVolt   <= 28.0 &&
        newMaxVolt   >= 12.0 && newMaxVolt  <= 30.0 &&
        newOffset    >= -10 && newOffset    <= 10) {

      MAX_TEMP    = newMaxTemp;
      FAN_ON_TEMP = newFanOnTemp;
      MIN_VOLT    = newMinVolt;
      MAX_VOLT    = newMaxVolt;
      tempOffset  = newOffset;

      settings.maxTemp   = MAX_TEMP;
      settings.fanOnTemp = FAN_ON_TEMP;
      settings.minVolt   = MIN_VOLT;
      settings.maxVolt   = MAX_VOLT;
      settings.offset    = tempOffset;

      saveSettings();
      server.send(200, "text/plain", "OK");
      broadcastWsData();
    } else {
      server.send(400, "text/plain", "INVALID VALUES");
    }
  } else {
    server.send(400, "text/plain", "MISSING PARAMETERS");
  }
}

void handleSaveWiFiSettings() {
  sendCORS();
  if (server.method() == HTTP_OPTIONS) { server.send(204); return; }

  if (server.hasArg("ssid") && server.hasArg("password")) {
    String newSSID = server.arg("ssid");
    String newPASS = server.arg("password");

    if (newSSID.length() >= 4 && newPASS.length() >= 8) {
      newSSID.toCharArray(settings.wifiSSID, 32);
      newPASS.toCharArray(settings.wifiPASS, 32);
      strcpy(ap_ssid,     settings.wifiSSID);
      strcpy(ap_password, settings.wifiPASS);
      saveSettings();

      server.send(200, "text/plain", "OK");

      delay(100);
      WiFi.softAP(ap_ssid, ap_password);

      Serial.println("✅ WiFi Updated Successfully!");
      Serial.print("📶 New SSID: ");
      Serial.println(ap_ssid);
    } else {
      server.send(400, "text/plain", "INVALID LENGTH");
    }
  } else {
    server.send(400, "text/plain", "MISSING PARAMETERS");
  }
}

void handleGetWiFiSettings() {
  sendCORS();
  if (server.method() == HTTP_OPTIONS) { server.send(204); return; }

  String json = "{";
  json += "\"ssid\":\""     + String(settings.wifiSSID) + "\",";
  json += "\"password\":\"" + String(settings.wifiPASS) + "\",";
  json += "\"fw\":\"portaliq-sta-mdns-2026-08-21\"";
  json += "}";

  server.send(200, "application/json", json);
}

// [FACTORY RESET] /factoryreset — wipes every stored setting (AP name,
// password, alarm limits, STA creds…) by invalidating the EEPROM signature,
// then rebooting so defaults are re-burned. Needed when someone forgets
// custom credentials they saved earlier through /savewifi.
void handleFactoryReset() {
  sendCORS();
  if (server.method() == HTTP_OPTIONS) { server.send(204); return; }

  settings.signature   = 0x00000000;          // invalidate -> defaults on boot
  settings.staSSID[0]  = 0;
  settings.staPASS[0]  = 0;
  saveSettings();

  server.send(200, "text/plain", "FACTORY RESET - REBOOTING");
  Serial.println("🏭 FACTORY RESET REQUESTED — rebooting with defaults");
  delay(600);
  ESP.restart();
}

void handleGetAllSettings() {
  sendCORS();
  if (server.method() == HTTP_OPTIONS) { server.send(204); return; }

  String json = "{";
  json += "\"maxTemp\":"    + String(MAX_TEMP)              + ",";
  json += "\"fanOnTemp\":"  + String(FAN_ON_TEMP)           + ",";
  json += "\"minVolt\":"    + String(MIN_VOLT)              + ",";
  json += "\"maxVolt\":"    + String(MAX_VOLT)              + ",";
  json += "\"offset\":"     + String(tempOffset, 2)        + ",";
  json += "\"r1\":"         + String(settings.r1, 0)       + ",";
  json += "\"r2\":"         + String(settings.r2, 0)       + ",";
  json += "\"voltCalib\":"  + String(settings.voltCalib, 4) + ",";
  json += "\"sensorPullUp\":" + String(settings.sensorPullUp, 0) + ",";
  json += "\"installDate\":\"" + String(settings.installDate)    + "\",";
  json += "\"wifiSSID\":\""    + String(settings.wifiSSID)       + "\",";
  json += "\"serial\":\""      + getChipId()                     + "\"";
  json += "}";

  server.send(200, "application/json", json);
}

void handleSaveAdvancedSettings() {
  sendCORS();
  if (server.method() == HTTP_OPTIONS) { server.send(204); return; }

  if (server.hasArg("r1")) {
    float val = server.arg("r1").toFloat();
    if (val > 0 && val < 100000) settings.r1 = val;
  }
  if (server.hasArg("r2")) {
    float val = server.arg("r2").toFloat();
    if (val > 0 && val < 100000) settings.r2 = val;
  }
  if (server.hasArg("voltCalib")) {
    float val = server.arg("voltCalib").toFloat();
    if (val > 0.1 && val < 10.0) settings.voltCalib = val;
  }
  if (server.hasArg("sensorPullUp")) {
    float val = server.arg("sensorPullUp").toFloat();
    if (val > 0 && val < 100000) settings.sensorPullUp = val;
  }
  if (server.hasArg("offset")) {
    float val = server.arg("offset").toFloat();
    if (val >= -10 && val <= 10) {
      tempOffset       = val;
      settings.offset  = tempOffset;
    }
  }
  if (server.hasArg("installDate")) {
    String date = server.arg("installDate");
    if (date.length() >= 8 && date.length() <= 16) {
      date.toCharArray(settings.installDate, 16);
    }
  }

  saveSettings();
  server.send(200, "text/plain", "OK");
}

void handleTestFan() {
  sendCORS();
  if (server.method() == HTTP_OPTIONS) { server.send(204); return; }
  if (!license_is_active()) {
    fanTestActive = false;
    fanOff();
    server.send(423, "text/plain", "LICENSE_REQUIRED");
    return;
  }

  fanTestActive = true;
  fanTestStopAt = millis() + 5000;
  fanOn();
  playConfirmSound();
  server.send(200, "text/plain", "OK");
}

void handleMute() {
  sendCORS();
  if (server.method() == HTTP_OPTIONS) { server.send(204); return; }
  if (!license_is_active()) {
    buzzMuted = false;
    stopAlarmSound();
    server.send(423, "text/plain", "LICENSE_REQUIRED");
    return;
  }

  buzzMuted = true;
  stopAlarmSound();
  playConfirmSound();
  server.send(200, "text/plain", "OK");
}

void handleRestart() {
  sendCORS();
  if (server.method() == HTTP_OPTIONS) { server.send(204); return; }

  server.send(200, "text/plain", "RESTARTING");
  delay(500);
  ESP.restart();
}

void handleCalibrateVoltage() {
  sendCORS();
  if (server.method() == HTTP_OPTIONS) { server.send(204); return; }

  if (!server.hasArg("realVolt")) {
    server.send(400, "text/plain", "Missing realVolt");
    return;
  }

  float realVolt = server.arg("realVolt").toFloat();
  if (realVolt < 8.0 || realVolt > 30.0) {
    server.send(400, "text/plain", "Invalid voltage range");
    return;
  }

  float sum = 0;
  for (int i = 0; i < 32; i++) {
    sum += analogRead(ADC_PIN);
    delay(5);
  }

  float vAdc = (sum / 32.0f / ADC_MAX) * VREF;
  float raw  = vAdc * ((settings.r1 + settings.r2) / settings.r2);
  settings.voltCalib = realVolt / raw;

  saveSettings();
  server.send(200, "text/plain", "OK," + String(settings.voltCalib, 4));
}

void handleRoot() {
  sendCORS();
  String html = "";
  html += "<!DOCTYPE html><html><head>";
  html += "<meta charset='UTF-8'>";
  html += "<meta name='viewport' content='width=device-width, initial-scale=1.0'>";
  html += "<title>CarGuard System</title>";
  html += "<style>";
  html += "body{background:#0a0a10;color:#fff;font-family:Tahoma,Arial,sans-serif;display:flex;justify-content:center;align-items:center;min-height:100vh;margin:0;padding:20px;}";
  html += ".card{background:rgba(12,12,22,0.9);border:1px solid rgba(0,212,255,0.2);border-radius:20px;padding:30px;max-width:400px;width:100%;text-align:center;}";
  html += "h1{background:linear-gradient(135deg,#00d4ff,#ff00ff);-webkit-background-clip:text;background-clip:text;color:transparent;font-size:24px;}";
  html += ".data{margin:10px 0;padding:10px;background:rgba(0,212,255,0.05);border-radius:10px;}";
  html += ".data span{color:#00d4ff;font-weight:bold;}";
  html += ".status{display:inline-block;padding:4px 12px;border-radius:15px;font-size:12px;margin-top:5px;}";
  html += ".online{background:rgba(0,255,136,0.15);color:#00ff88;border:1px solid #00ff88;}";
  html += ".offline{background:rgba(255,34,68,0.15);color:#ff2244;border:1px solid #ff2244;}";
  html += ".license-banner{margin:12px 0;padding:10px;border-radius:10px;background:rgba(255,184,0,0.12);color:#ffcc33;border:1px solid #ffcc33;font-size:13px;}";
  html += ".btn{display:inline-block;margin:5px;padding:8px 20px;background:rgba(0,212,255,0.1);border:1px solid #00d4ff;border-radius:10px;color:#00d4ff;text-decoration:none;font-size:12px;}";
  html += ".footer{font-size:10px;color:#4a6070;margin-top:20px;}";
  html += "</style></head><body>";
  const bool licenseActive = license_is_active();
  html += "<div class='card'>";
  html += "<h1>🚗 CarGuard System</h1>";
  if (licenseActive) {
    html += "<div class='data'>🔐 License: <span>ACTIVE</span></div>";
  } else {
    html += "<div class='license-banner'>🔒 LICENSE REQUIRED<br/><small>";
    html += license_get_status_message();
    html += "</small></div>";
  }
  html += "<div class='data'>🌡️ Temp: <span>" + String(filteredTemp, 1) + " °C</span></div>";
  html += "<div class='data'>⚡ Volt: <span>" + String(filteredVolt, 2) + " V</span></div>";
  html += "<div class='data'>🌀 Fan: <span>"  +
          String((licenseActive && fanState) ? "ON" : "OFF") + "</span></div>";
  html += "<div class='data'>📱 Clients: <span>" + String(WiFi.softAPgetStationNum()) + "</span></div>";
  html += "<div style='margin:15px 0;'>";
  html += "<span class='status " + String(WiFi.softAPgetStationNum() > 0 ? "online" : "offline") + "'>";
  html += WiFi.softAPgetStationNum() > 0 ? "✅ Connected" : "❌ No clients";
  html += "</span></div>";
  html += "<div><a href='/update' class='btn'>📡 OTA Update</a></div>";
  html += "<div class='footer'>";
  html += "🔢 Serial: "   + getChipId()               + "<br/>";
  html += "📅 Install: "  + String(settings.installDate) + "<br/>";
  html += "🔌 WebSocket: port 81";
  html += "</div>";
  html += "</div></body></html>";

  server.send(200, "text/html", html);
}

void handleNotFound() {
  sendCORS();
  // [PORTAL] The module runs a wildcard DNS that points every hostname at
  // itself, so Android/iOS/Windows connectivity probes (generate_204,
  // hotspot-detect.html, connecttest.txt…) always land here. Answering
  // with 302 -> / makes the OS classify the AP as a *captive portal*:
  // it keeps the phone on 4G for internet and shows its one-shot
  // "Sign in to network" notice instead of cutting data off — same
  // behavior you get on a café WiFi.
  server.sendHeader("Location", "/", true);
  server.send(302, "text/plain", "Redirect to CarGuard");
}

// =========================================================
// SETUP
// =========================================================
void setup() {
  Serial.begin(115200);
  Serial.println("\n==========================================");
  Serial.println("🚗 CarGuard System Starting...");
  Serial.println("==========================================");

  pinMode(LED_PIN,   OUTPUT);
  pinMode(BUZZER,    OUTPUT);
  pinMode(RELAY_PIN, OUTPUT);

  // Load the license before any startup/connection sound. The license area
  // is independent from Settings and is never cleared during boot.
  license_init();
  license_load();

  digitalWrite(BUZZER, LOW);   // تأكد الـ buzzer مطفي في البداية
  fanOff();
  ledOn();
  delay(500);
  ledOff();

  if (license_is_active()) {
    playStartupSound();
  } else {
    digitalWrite(BUZZER, LOW);
  }

  sensors.begin();
  sensors.setWaitForConversion(false);

  loadSettings();

  // [STA+mDNS] AP stays always-on; the STA join is attempted in parallel
  // and never blocks boot (the hotspot might legitimately be off).
  WiFi.mode(WIFI_AP_STA);
  WiFi.softAP(ap_ssid, ap_password);
  maybeStartStaAndMdns();

  dnsServer.start(53, "*", WiFi.softAPIP());

  // [STA+mDNS] mDNS answers on the AP too — no need to wait for the STA
  // link: discovery works identically in both topologies.
  advertiseMdns();

  // OTA does not erase EEPROM and therefore preserves the license record at
  // LICENSE_EEPROM_OFFSET across firmware updates.
  httpUpdater.setup(&server, "/update");

  webSocket.begin();
  webSocket.onEvent(onWsEvent);

  server.on("/",                    handleRoot);
  server.on("/data",                handleData);
  server.on("/mute",                handleMute);
  server.on("/testfan",             handleTestFan);
  server.on("/restart",             handleRestart);
  server.on("/savewifi",            handleSaveWiFiSettings);
  server.on("/joinwifi",            handleJoinWiFi);
  server.on("/getwifisettings",     handleGetWiFiSettings);
  server.on("/factoryreset",        handleFactoryReset);
  server.on("/saveallsettings",     handleSaveAllSettings);
  server.on("/saveadvancedsettings",handleSaveAdvancedSettings);
  server.on("/getallsettings",      handleGetAllSettings);
  server.on("/calibratevoltage",    handleCalibrateVoltage);

  // [PORTAL] Explicit OS connectivity-probe paths so they never fall
  // through as 404s (handleNotFound now answers captive-portal style).
  server.on("/generate_204",        handleNotFound);  // Android
  server.on("/hotspot-detect.html", handleNotFound);  // iOS
  server.on("/connecttest.txt",     handleNotFound);  // Windows
  server.on("/ncsi.txt",            handleNotFound);  // Windows

  server.onNotFound(handleNotFound);

  server.begin();

  lastNormalVoltTime = millis();

  Serial.println("==========================================");
  Serial.println("✅ SYSTEM READY");
  Serial.println("==========================================");
  Serial.print("📶 SSID: ");     Serial.println(ap_ssid);
  Serial.print("🔑 Password: "); Serial.println(ap_password);
  Serial.print("🌐 IP: ");       Serial.println(WiFi.softAPIP());
  Serial.print("🔢 Serial: ");   Serial.println(getChipId());
  Serial.print("📅 Install: ");  Serial.println(settings.installDate);
  Serial.println("📡 OTA: http://192.168.4.1/update");
  Serial.println("🔌 WebSocket: ws://192.168.4.1:81/");
  Serial.println("==========================================");

  ledOn();
}

// =========================================================
// LOOP
// =========================================================
void loop() {
  dnsServer.processNextRequest();
  server.handleClient();
  webSocket.loop();

  // [STA+mDNS] mandatory pump — the responder only serves queries while
  // update() is being called from loop().
  if (mdnsStarted) {
    MDNS.update();
  }

  // [STA+mDNS] if the hotspot link drops, quietly re-attempt the join.
  if (settings.staSSID[0] != 0) {
    static unsigned long lastStaCheck = 0;
    if (millis() - lastStaCheck > 15000) {
      lastStaCheck = millis();
      if (WiFi.status() != WL_CONNECTED) {
        Serial.println("📡 STA lost — retrying join...");
        WiFi.begin(settings.staSSID, settings.staPASS);
      }
    }
  }

  updateSensors();
  handleAlarm();
  updateLedStatus();

  if (millis() - lastWsBroadcast >= 1000) {
    lastWsBroadcast = millis();
    broadcastWsData();
  }

  delay(1);
}
