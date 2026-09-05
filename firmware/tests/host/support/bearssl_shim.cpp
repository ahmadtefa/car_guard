// =============================================================
//  HOST TEST ONLY — implements the tiny BearSSL surface declared
//  in host/arduino/bearssl/bearssl.h using the host's libcrypto.
//
//  The cryptography is REAL and identical in kind to production:
//  SHA-256 and ECDSA P-256 verification of a 64-byte raw r||s
//  signature over the 32-byte digest of the 19-byte payload.
//  Only the backend library differs (libcrypto instead of the
//  ESP8266-core BearSSL). Never linked into the sketch build.
// =============================================================

#include <bearssl/bearssl.h>

#include "openssl_decl.h"

// ---------------------------------------------------------
// SHA-256 — one context per call site (production uses exactly
// one-shot init/update/out sequences).
// ---------------------------------------------------------
void br_sha256_init(br_sha256_context* cc) {
  cc->ctx = EVP_MD_CTX_new();
  if (cc->ctx != NULL) {
    EVP_DigestInit_ex((EVP_MD_CTX*)cc->ctx, EVP_sha256(), NULL);
  }
}

void br_sha256_update(br_sha256_context* cc, const void* data, size_t len) {
  if (cc->ctx != NULL) {
    EVP_DigestUpdate((EVP_MD_CTX*)cc->ctx, data, len);
  }
}

void br_sha256_out(const br_sha256_context* cc, void* out) {
  if (cc->ctx != NULL) {
    unsigned int out_len = 0;
    EVP_DigestFinal_ex((EVP_MD_CTX*)cc->ctx, (unsigned char*)out, &out_len);
    EVP_MD_CTX_free((EVP_MD_CTX*)cc->ctx);
    const_cast<br_sha256_context*>(cc)->ctx = NULL;
  }
}

// ---------------------------------------------------------
// ECDSA P-256 raw r||s verification over a 32-byte digest.
// ---------------------------------------------------------
struct br_ec_impl {
  int unused;
};

static br_ec_impl g_impl = {0};

const br_ec_impl* br_ec_get_default(void) { return &g_impl; }

static uint32_t host_verify_raw(const br_ec_impl* impl, const void* hash,
                                size_t hash_len, const br_ec_public_key* pk,
                                const void* sig, size_t sig_len) {
  (void)impl;
  if (hash == NULL || pk == NULL || sig == NULL) return 0;
  if (hash_len != 32) return 0;
  if (sig_len != 64) return 0;
  if (pk->curve != BR_EC_secp256r1) return 0;
  if (pk->q == NULL || pk->qlen != 65 || pk->q[0] != 0x04) return 0;

  uint32_t result = 0;
  EC_KEY* key = NULL;
  EC_POINT* point = NULL;
  ECDSA_SIG* ecsig = NULL;

  const int nid = OBJ_sn2nid("prime256v1");
  key = EC_KEY_new_by_curve_name(nid);
  if (key == NULL) goto done;

  point = EC_POINT_new(EC_KEY_get0_group(key));
  if (point == NULL) goto done;
  if (EC_POINT_oct2point(EC_KEY_get0_group(key), point, pk->q, pk->qlen,
                         NULL) != 1) {
    goto done;
  }
  if (EC_KEY_set_public_key(key, point) != 1) goto done;

  {
    const unsigned char* s = (const unsigned char*)sig;
    ecsig = ECDSA_SIG_new();
    if (ecsig == NULL) goto done;
    BIGNUM* r = BN_bin2bn(s, 32, NULL);
    BIGNUM* sn = BN_bin2bn(s + 32, 32, NULL);
    if (r == NULL || sn == NULL || ECDSA_SIG_set0(ecsig, r, sn) != 1) {
      // Ownership: on success ECDSA_SIG_set0 takes r/s; on failure free them.
      BN_free(r);
      BN_free(sn);
      goto done;
    }
    result = (ECDSA_do_verify((const unsigned char*)hash, (int)hash_len,
                              ecsig, key) == 1)
                 ? 1
                 : 0;
  }

done:
  if (ecsig != NULL) ECDSA_SIG_free(ecsig);
  if (point != NULL) EC_POINT_free(point);
  if (key != NULL) EC_KEY_free(key);
  return result;
}

br_ecdsa_vrfy br_ecdsa_vrfy_raw_get_default(void) { return &host_verify_raw; }
