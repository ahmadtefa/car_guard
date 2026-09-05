#pragma once

// =============================================================
//  HOST TEST ONLY — EEPROM emulation.
//
//  A 4 KiB static byte array held in the host process. Like real
//  flash storage it SURVIVES the harness's simulated reboots
//  (license_init() + license_load() re-read from this buffer).
//  Never linked into the ESP8266 sketch build.
// =============================================================

#include <stddef.h>
#include <stdint.h>
#include <string.h>

class EEPROMClass {
public:
  void begin(size_t size);
  void end();
  bool commit();  // host storage is already in place; commit always succeeds

  uint8_t read(int addr);
  void write(int addr, uint8_t value);

  template <typename T>
  T& get(int addr, T& t) {
    memcpy(&t, storage() + addr, sizeof(T));
    return t;
  }

  template <typename T>
  const T& put(int addr, const T& t) {
    memcpy(storage() + addr, &t, sizeof(T));
    return t;
  }

private:
  static uint8_t* storage();
};

extern EEPROMClass EEPROM;

// Test-only helpers.
void stub_eeprom_wipe();          // simulate a brand-new module
const uint8_t* stub_eeprom_bytes();  // raw view for assertions
