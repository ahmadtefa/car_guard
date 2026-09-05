#pragma once

// =============================================================
//  HOST TEST ONLY — WiFi facade. No radios; the AP/STA state is
//  a settable variable so the harness can mimic a connected app.
// =============================================================

#include <stdint.h>
#include "Arduino.h"

#define WIFI_AP_STA 0x03
#define WL_CONNECTED 3
#define WL_DISCONNECTED 6

class IPAddress {
public:
  IPAddress() {}
  IPAddress(uint8_t a, uint8_t b, uint8_t c, uint8_t d) { (void)a; (void)b; (void)c; (void)d; }
  String toString() const { return String("192.168.4.1"); }
};

class WiFiClass {
public:
  void mode(int) {}
  bool softAP(const char*, const char*) { return true; }
  void begin(const char*, const char*) {}
  void setAutoReconnect(bool) {}
  IPAddress softAPIP() { return IPAddress(192, 168, 4, 1); }
  IPAddress localIP() { return IPAddress(192, 168, 4, 1); }
  int status();                    // driven by stub_set_sta_connected()
  int softAPgetStationNum();       // driven by stub_set_softap_stations()
};

extern WiFiClass WiFi;

// Test-only control.
void stub_set_sta_connected(bool connected);
void stub_set_softap_stations(int count);
