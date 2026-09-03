#pragma once

#include <stdint.h>
#include <stddef.h>

// =========================================================
//  CarGuard License public key — PRODUCTION PLACEHOLDER.
//
//  There is NO production public key yet. The License Generator
//  is built in a later stage. Until then the system must never
//  be considered production ready, and every activation attempt
//  MUST fail with PUBLIC_KEY_NOT_CONFIGURED.
//
//  When the real key is available, replace this file with a
//  generated version that:
//
//    #define PUBLIC_KEY_CONFIGURED 1   (or build with -DPUBLIC_KEY_CONFIGURED=1)
//
//  and provide the definition (declared below) in one of the license
//  translation units:
//
//    const uint8_t LICENSE_PUBKEY[65]; // 0x04 || X || Y (P-256, uncompressed)
//
//  LICENSE_PUBKEY_LEN is a compile-time constant (65) enforced below,
//  so the provider only has to supply the 65-byte uncompressed point.
//  Do NOT place a fake / test key here. The system stays locked
//  until the genuine key is substituted.
// =========================================================

#ifndef PUBLIC_KEY_CONFIGURED
#define PUBLIC_KEY_CONFIGURED 0
#endif

#if PUBLIC_KEY_CONFIGURED == 1
// Provided by the generated public-key translation unit only when
// PUBLIC_KEY_CONFIGURED == 1. It MUST be the uncompressed P-256 point
//   0x04 || X(32) || Y(32)  -> exactly 65 bytes.
extern const uint8_t  LICENSE_PUBKEY[65];

// Compile-time guarantee that the key is the P-256 uncompressed size.
static constexpr size_t LICENSE_PUBKEY_LEN = 65;
static_assert(LICENSE_PUBKEY_LEN == 65,
              "P-256 uncompressed public key must be exactly 65 bytes");
#endif
