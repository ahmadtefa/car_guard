#pragma once

// =============================================================
//  HOST TEST ONLY — mDNS facade (no network).
// =============================================================

#include <stdint.h>

class MDNSResponder {
public:
  bool begin(const char*) { return true; }
  void addService(const char*, const char*, uint16_t) {}
  void update() {}
};

extern MDNSResponder MDNS;
