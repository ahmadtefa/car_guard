#pragma once

// =============================================================
//  HOST TEST ONLY — minimal BearSSL API surface.
//
//  license_helpers.cpp includes <bearssl/bearssl.h> via
//  __has_include. On the real firmware the genuine BearSSL
//  bundled with the ESP8266 Arduino core is used. On the host
//  this header declares the same tiny subset of the API and the
//  implementation (host/support/bearssl_shim.cpp) performs REAL
//  cryptography (SHA-256 + ECDSA P-256 verification) through the
//  host's libcrypto — no crypto is weakened, only the backend
//  library differs. Never linked into the ESP8266 sketch build.
// =============================================================

#include <stddef.h>
#include <stdint.h>

// ---- SHA-256 (context handled by the shim) ----
typedef struct {
  void* ctx;
} br_sha256_context;

void br_sha256_init(br_sha256_context* cc);
void br_sha256_update(br_sha256_context* cc, const void* data, size_t len);
void br_sha256_out(const br_sha256_context* cc, void* out);

// ---- EC (P-256) ----
#define BR_EC_secp256r1 23

typedef struct {
  int curve;
  unsigned char* q;
  size_t qlen;
} br_ec_public_key;

typedef struct br_ec_impl br_ec_impl;

typedef uint32_t (*br_ecdsa_vrfy)(const br_ec_impl* impl, const void* hash,
                                  size_t hash_len, const br_ec_public_key* pk,
                                  const void* sig, size_t sig_len);

const br_ec_impl* br_ec_get_default(void);
br_ecdsa_vrfy br_ecdsa_vrfy_raw_get_default(void);
