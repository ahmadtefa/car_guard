#pragma once

// =============================================================
//  HOST TEST ONLY — WebSocket capture.
//  Every frame the firmware would push (broadcastTXT) or send in
//  reply (sendTXT) is recorded, so the tests can prove exactly
//  which telemetry frames the module emitted — and when it
//  stopped. sendTXT replies are how the mobile app receives
//  LICENSE_STATUS / LICENSE_RESULT / DEVICE_SERIAL answers.
// =============================================================

#include <functional>
#include <stdint.h>
#include <string>
#include <utility>
#include <vector>

#include "Arduino.h"

typedef enum {
  WStype_ERROR = 0,
  WStype_DISCONNECTED,
  WStype_CONNECTED,
  WStype_TEXT,
  WStype_BIN,
} WStype_t;

class WebSocketsServer {
public:
  typedef std::function<void(uint8_t, WStype_t, uint8_t*, size_t)> EventCb;

  explicit WebSocketsServer(uint16_t port) { (void)port; }

  void begin() {}
  void close() {}
  void loop() {}
  void onEvent(EventCb cb) { (void)cb; }

  int connectedClients();
  void broadcastTXT(const String& payload);
  void sendTXT(uint8_t clientId, const String& payload);
};

// Test-only capture + control.
void stub_ws_reset();
void stub_ws_set_clients(int count);
int stub_ws_broadcast_count();
const std::vector<std::string>& stub_ws_broadcasts();
const std::vector<std::pair<uint8_t, std::string>>& stub_ws_replies();
