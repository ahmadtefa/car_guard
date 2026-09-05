#pragma once

// =============================================================
//  HOST TEST ONLY — DS18B20 facade. Returns a fixed, plausible
//  temperature; sensor acquisition is outside the license test.
// =============================================================

#define DEVICE_DISCONNECTED_C -127.0f

class OneWire;

class DallasTemperature {
public:
  explicit DallasTemperature(OneWire*) {}
  void begin() {}
  void setWaitForConversion(bool) {}
  void requestTemperatures() {}
  bool isConversionComplete() { return true; }
  float getTempCByIndex(int) { return 25.0f; }
};
