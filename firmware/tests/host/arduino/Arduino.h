#pragma once

// =============================================================
//  HOST TEST ONLY — minimal Arduino runtime shim.
//
//  This header (and everything under firmware/tests/host/) is
//  compiled ONLY by the host-side firmware test harness in
//  firmware/tests/. It is never part of the ESP8266 sketch
//  build: the Arduino IDE / arduino-cli / PlatformIO compile
//  only sources inside firmware/car_guard/.
//
//  It provides the small Arduino API surface the production
//  sources use: String, millis() (a deterministic test clock),
//  pin I/O recording, and Serial. Nothing here can influence a
//  production build or bypass the real license checks.
// =============================================================

#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <string>
#include <cstring>

// ---------------------------------------------------------
// String — std::string-backed subset of the Arduino API.
// ---------------------------------------------------------
class String {
public:
  String() {}
  String(const char* c) : s_(c == nullptr ? "" : c) {}
  String(const std::string& x) : s_(x) {}
  String(char c) : s_(1, c) {}
  String(int v) : s_(std::to_string(v)) {}
  String(unsigned int v) : s_(std::to_string(v)) {}
  String(long v) : s_(std::to_string(v)) {}
  String(unsigned long v) : s_(std::to_string(v)) {}
  explicit String(double v, int digits = 2) { set(v, digits); }
  String(float v, int digits = 2) { set((double)v, digits); }

  size_t length() const { return s_.size(); }
  const char* c_str() const { return s_.c_str(); }
  int indexOf(const char* needle) const {
    size_t p = s_.find(needle == nullptr ? "" : needle);
    return p == std::string::npos ? -1 : (int)p;
  }
  float toFloat() const { return (float)atof(s_.c_str()); }
  void toCharArray(char* buf, unsigned int len) const {
    if (buf == nullptr || len == 0) return;
    std::strncpy(buf, s_.c_str(), len - 1);
    buf[len - 1] = '\0';
  }

  String& operator+=(const String& o) { s_ += o.s_; return *this; }
  String& operator+=(const char* o) { s_ += (o == nullptr ? "" : o); return *this; }
  String& operator+=(char c) { s_ += c; return *this; }

  friend String operator+(const String& a, const String& b) { String r(a); r += b; return r; }
  friend String operator+(const String& a, const char* b) { String r(a); r += b; return r; }
  friend String operator+(const char* a, const String& b) { String r(a); r += b; return r; }

  friend bool operator==(const String& a, const String& b) { return a.s_ == b.s_; }
  friend bool operator==(const String& a, const char* b) { return a.s_ == (b == nullptr ? "" : b); }
  friend bool operator!=(const String& a, const String& b) { return !(a == b); }
  friend bool operator!=(const String& a, const char* b) { return !(a == b); }

private:
  void set(double v, int digits) {
    char buf[64];
    std::snprintf(buf, sizeof(buf), "%.*f", digits, v);
    s_ = buf;
  }

  std::string s_;
};

// ---------------------------------------------------------
// Time — deterministic test clock.
// Production firmware links the real ESP8266 millis(); the host
// harness drives these with stub_set_millis/stub_advance_millis,
// which is exactly the "test-only clock provider" pattern: it
// exists only in the host build and is invisible to production.
// ---------------------------------------------------------
uint32_t millis();
uint32_t micros();
void delay(unsigned long ms);
void delayMicroseconds(unsigned int us);

void stub_set_millis(uint32_t ms);
void stub_advance_millis(uint32_t ms);

// ---------------------------------------------------------
// Pins — recorded so tests can assert relay/buzzer states.
// ---------------------------------------------------------
#define HIGH 0x1
#define LOW 0x0
#define INPUT 0x0
#define OUTPUT 0x1
#define A0 17

void pinMode(int pin, uint8_t mode);
void digitalWrite(int pin, uint8_t value);
int digitalRead(int pin);
int analogRead(int pin);

// Host-test introspection of the recorded pin levels.
int stub_pin_level(int pin);
int stub_digital_reads(int pin);
void stub_set_analog(int pin, int value);
void stub_reset_pins();

// ---------------------------------------------------------
// Serial — captured, never printed by default.
// ---------------------------------------------------------
class SerialStub {
public:
  void begin(unsigned long) {}
  void printf(const char*, ...) {}
  template <typename T> void print(const T&) {}
  template <typename T> void println(const T&) {}
  void println() {}
};

extern SerialStub Serial;

// Arduino's abs() is a macro (used on floats in car_guard.ino).
#ifndef abs
#define abs(x) ((x) > 0 ? (x) : -(x))
#endif

typedef uint8_t byte;

// The real ESP8266 Arduino core exposes the EspClass singleton from
// Arduino.h; mirror that so sketch code sees ESP without an extra
// include.
#include <Esp.h>
