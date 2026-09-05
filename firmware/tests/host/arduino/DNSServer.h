#pragma once

// =============================================================
//  HOST TEST ONLY — captive-portal DNS facade (no network).
// =============================================================

#include <stdint.h>
#include "ESP8266WiFi.h"

class DNSServer {
public:
  bool start(uint16_t, const char*, const IPAddress&) { return true; }
  void processNextRequest() {}
  void stop() {}
};
