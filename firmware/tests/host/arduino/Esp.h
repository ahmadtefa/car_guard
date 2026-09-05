#pragma once

// =============================================================
//  HOST TEST ONLY — fixed ESP identity.
//  The test chip id makes the device serial deterministic:
//  getChipId() -> "KCG_00123456", so host-generated test
//  licenses can be bound to this exact simulated module.
// =============================================================

#include <stdint.h>

class EspClass {
public:
  uint32_t getChipId() { return 0x00123456UL; }
  void restart();  // sets the stub restart flag instead of rebooting
};

extern EspClass ESP;

// Test-only introspection for handlers that call ESP.restart().
bool stub_restart_requested();
void stub_clear_restart();
