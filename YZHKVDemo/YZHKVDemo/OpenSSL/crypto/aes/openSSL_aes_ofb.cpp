/*
 * Copyright 2002-2016 The OpenSSL Project Authors. All Rights Reserved.
 *
 * Licensed under the Apache License 2.0 (the "License").  You may not use
 * this file except in compliance with the License.  You can obtain a copy
 * in the file LICENSE in the source distribution or at
 * https://www.openssl.org/source/license.html
 */

#include "openSSL_aes.h"
#include "openSSL_modes.h"

namespace openSSL {
    
//    void AES_ofb128_encrypt(const unsigned char *in, unsigned char *out,
//                            size_t length, const AES_KEY *key,
//                            unsigned char *ivec, int *num)
    void AES_ofb128_encrypt(const unsigned char *in, unsigned char *out,
                            size_t length, const AES_KEY *key,
                            unsigned char *ivec, int *num, const int enc)
    {
        CRYPTO_ofb128_encrypt(in, out, length, key, ivec, num,
                              (block128_f) AES_encrypt);
    }
}
