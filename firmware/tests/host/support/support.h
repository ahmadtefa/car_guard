#pragma once

// =============================================================
//  HOST TEST ONLY — test-support API.
//
//  Provides the deterministic test clock state, GPIO/EEPROM
//  emulation backing, HTTP/WebSocket capture and — crucially —
//  the TEST-ONLY license signing helper:
//
//    * test_build_license_code() mints licenses signed with a
//      dedicated TEST keypair (see test_pubkey.cpp). The test
//      private key is published in the repository on purpose:
//      these test licenses can never activate a real device
//      because production firmware embeds the PRODUCTION public
//      key, which is completely different. This does not touch
//      the license protocol, payload layout, signature format,
//      or any production behavior — the produced codes go
//      through the unmodified production activation path
//      (Base32 -> 83 bytes -> real ECDSA verify -> serial -> ...
//      -> EEPROM).
// =============================================================

#include <stddef.h>
#include <stdint.h>
#include <string>

// Signs a 19-byte license payload with the TEST private key and
// returns the 64-byte raw r||s signature. False on failure.
bool test_sign_license_payload(const uint8_t payload[19], uint8_t out_sig[64]);

// RFC4648 Base32 (uppercase A-Z / 2-7, no padding) encoder with
// canonical zero trailing bits — the exact inverse of the
// production license_decode_base32().
std::string test_base32_encode(const uint8_t* data, size_t len);

// Builds a complete Base32 license code string bound to the
// given 12-char device serial (payload + real test signature).
// Returns an empty string on failure.
std::string test_build_license_code(const char serial12[12], uint8_t type,
                                    uint16_t year, uint8_t month, uint8_t day,
                                    uint8_t months);
