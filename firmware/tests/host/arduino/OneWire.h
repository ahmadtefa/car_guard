#pragma once

// =============================================================
//  HOST TEST ONLY — OneWire facade (no bus).
// =============================================================

class OneWire {
public:
  explicit OneWire(int pin) { (void)pin; }
};
