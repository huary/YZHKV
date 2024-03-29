/*
 * Copyright 2002-2016 The OpenSSL Project Authors. All Rights Reserved.
 *
 * Licensed under the Apache License 2.0 (the "License").  You may not use
 * this file except in compliance with the License.  You can obtain a copy
 * in the file LICENSE in the source distribution or at
 * https://www.openssl.org/source/license.html
 */

#include <assert.h>

#include "openSSL_aes.h"
#include "openSSL_aes_locl.h"

namespace openSSL {
    
    static int blockSize_s = 16;
    
//    void AES_ecb_encrypt(const unsigned char *in, unsigned char *out,
//                         const AES_KEY *key, const int enc)
    void AES_ecb_encrypt(const unsigned char *in, unsigned char *out,
                         size_t length, const AES_KEY *key,
                         unsigned char *ivec, int *num, const int enc)
    {
        
        assert(in && out && key);
        assert((AES_ENCRYPT == enc) || (AES_DECRYPT == enc));
        
        if (AES_ENCRYPT == enc)
            AES_encrypt(in, out, key);
        else
            AES_decrypt(in, out, key);
    }
}
