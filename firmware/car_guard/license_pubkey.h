#pragma once

// License public key placeholder.
//
// PRODUCTION: Replace this file with a generated version that defines
// PUBLIC_KEY_CONFIGURED 1 and provides the production uncompressed EC point
// in LICENSE_PUBKEY (bytes) with length LICENSE_PUBKEY_LEN (should be 65: 0x04||X||Y).
// Example to provide later:
// #define PUBLIC_KEY_CONFIGURED 1
// const uint8_t LICENSE_PUBKEY[65] = { 0x04, 0xAA, 0xBB, ... };
// const size_t LICENSE_PUBKEY_LEN = 65;

// Default: no public key configured.
#define PUBLIC_KEY_CONFIGURED 0

// When PUBLIC_KEY_CONFIGURED == 1 the following symbols must be defined:
// const uint8_t LICENSE_PUBKEY[LICENSE_PUBKEY_LEN];
// const size_t LICENSE_PUBKEY_LEN;

