#pragma once

// =============================================================
//  HOST TEST ONLY — OTA updater facade. Records that the route
//  was registered; never serves anything.
// =============================================================

#include "ESP8266WebServer.h"

class ESP8266HTTPUpdateServer {
public:
  void setup(ESP8266WebServer*, const char* path) { (void)path; }
};
