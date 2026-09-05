#pragma once

// =============================================================
//  HOST TEST ONLY — hand-declared libcrypto prototypes.
//
//  The sandbox has libcrypto.so.3 but no OpenSSL development
//  headers, so the small set of functions used by the host test
//  harness is declared here manually. All types are opaque
//  (OpenSSL >= 1.1), so only function signatures are needed.
//  These are the stable, long-documented libcrypto APIs; they
//  are used ONLY by the host test binary, never by firmware.
// =============================================================

#include <stddef.h>

extern "C" {

// ---- digest ----
typedef struct evp_md_st EVP_MD;
typedef struct evp_md_ctx_st EVP_MD_CTX;
typedef struct engine_st ENGINE;

const EVP_MD* EVP_sha256(void);
EVP_MD_CTX* EVP_MD_CTX_new(void);
void EVP_MD_CTX_free(EVP_MD_CTX*);
int EVP_DigestInit_ex(EVP_MD_CTX*, const EVP_MD*, ENGINE*);
int EVP_DigestUpdate(EVP_MD_CTX*, const void*, size_t);
int EVP_DigestFinal_ex(EVP_MD_CTX*, unsigned char*, unsigned int*);

// ---- BIGNUM ----
typedef struct bignum_st BIGNUM;
BIGNUM* BN_bin2bn(const unsigned char*, int, BIGNUM*);
void BN_free(BIGNUM*);
int BN_bn2binpad(const BIGNUM*, unsigned char*, int);
int BN_num_bits(const BIGNUM*);

// ---- EC key / group / point ----
typedef struct ec_key_st EC_KEY;
typedef struct ec_group_st EC_GROUP;
typedef struct ec_point_st EC_POINT;

int OBJ_sn2nid(const char* short_name);
EC_KEY* EC_KEY_new_by_curve_name(int nid);
void EC_KEY_free(EC_KEY*);
const EC_GROUP* EC_KEY_get0_group(const EC_KEY*);
EC_POINT* EC_POINT_new(const EC_GROUP*);
void EC_POINT_free(EC_POINT*);
int EC_POINT_oct2point(const EC_GROUP*, EC_POINT*, const unsigned char*,
                       size_t, void*);
int EC_KEY_set_public_key(EC_KEY*, const EC_POINT*);
EC_KEY* d2i_ECPrivateKey(EC_KEY**, const unsigned char**, long);

// ---- ECDSA ----
typedef struct ECDSA_SIG_st ECDSA_SIG;
ECDSA_SIG* ECDSA_SIG_new(void);
void ECDSA_SIG_free(ECDSA_SIG*);
int ECDSA_SIG_set0(ECDSA_SIG*, BIGNUM*, BIGNUM*);
void ECDSA_SIG_get0(const ECDSA_SIG*, const BIGNUM**, const BIGNUM**);
ECDSA_SIG* ECDSA_do_sign(const unsigned char*, int, EC_KEY*);
int ECDSA_do_verify(const unsigned char*, int, const ECDSA_SIG*, EC_KEY*);

}  // extern "C"
