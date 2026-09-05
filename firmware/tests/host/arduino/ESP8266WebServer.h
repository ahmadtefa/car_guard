#pragma once

// =============================================================
//  HOST TEST ONLY — HTTP server capture.
//  Handlers are invoked directly by the test driver; this class
//  records the request args and the last response exactly the
//  way the real server would hand them to the handler.
// =============================================================

#include <stdint.h>
#include <map>
#include <string>

#include "Arduino.h"

enum HTTPMethod {
  HTTP_GET = 0,
  HTTP_POST,
  HTTP_PUT,
  HTTP_PATCH,
  HTTP_DELETE,
  HTTP_OPTIONS,
};

class ESP8266WebServer {
public:
  explicit ESP8266WebServer(int port) { (void)port; }

  void on(const char* uri, void (*handler)()) {
    (void)uri;
    (void)handler;
  }
  void onNotFound(void (*handler)()) { (void)handler; }
  void begin() {}
  void handleClient() {}
  void close() {}

  // ---- request side (set by the harness before calling a handler) ----
  HTTPMethod method();
  bool hasArg(const char* name);
  String arg(const char* name);

  // ---- response side (captured from the handler) ----
  void send(int code);
  void send(int code, const char* contentType, const String& body);
  void sendHeader(const char* name, const char* value, bool first = false);
};

// Test-only request/response control.
void stub_request_reset();
void stub_request_set_method(HTTPMethod method);
void stub_request_set_arg(const char* name, const char* value);
int stub_response_code();
const char* stub_response_body();
const char* stub_response_content_type();
