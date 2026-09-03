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
//  and provide the definitions (already declared below) in one of
//  the license translation units:
//
//    const uint8_t LICENSE_PUBKEY[65]; // 0x04 || X || Y (P-256, uncompressed)
//    const size_t  LICENSE_PUBKEY_LEN; // 65
//
//  Do NOT place a fake / test key here. The system stays locked
//  until the genuine key is substituted.
// =========================================================

#ifndef PUBLIC_KEY_CONFIGURED
#define PUBLIC_KEY_CONFIGURED 0
#endif

#if PUBLIC_KEY_CONFIGURED == 1
// Provided by the generated public-key translation unit only when
// PUBLIC_KEY_CONFIGURED == 1. Declared here so verify_ecdsa_p256_sha256
// can reference them.
extern const uint8_t  LICENSE_PUBKEY[65];
extern const size_t   LICENSE_PUBKEY_LEN;
#endif
