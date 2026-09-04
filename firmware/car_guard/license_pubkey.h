#pragma once

#include <stdint.h>
#include <stddef.h>

// CarGuard production license public-key configuration.
//
// The matching private signing key is external to this repository and must
// never be embedded in firmware, the Flutter project, or Git.
#define PUBLIC_KEY_CONFIGURED 1

#if PUBLIC_KEY_CONFIGURED == 1
// Uncompressed NIST P-256 point: 0x04 || X(32) || Y(32).
extern const uint8_t LICENSE_PUBKEY[65];
static constexpr size_t LICENSE_PUBKEY_LEN = 65;
static_assert(LICENSE_PUBKEY_LEN == 65,
              "P-256 uncompressed public key must be exactly 65 bytes");
#endif
