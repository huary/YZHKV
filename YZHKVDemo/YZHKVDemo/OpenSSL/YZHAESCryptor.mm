//
//  YZHAESCryptor.m
//  YZHKVDemo
//
//  Created by yuan on 2019/7/28.
//  Copyright © 2019 yuan. All rights reserved.
//

#import "YZHAESCryptor.h"
#import "openSSL_aes.h"
#include <stdlib.h>
#include <string.h>

typedef NS_ENUM(uint8_t, _AESKeySize)
{
    _AESKeySize128   = 16,
    _AESKeySize192   = 24,
    _AESKeySize256   = 32,
};

static const NSInteger AESBlockSize_s   = 16;

typedef void(*_AES_CFB)(const unsigned char *in, unsigned char *out, size_t length, const openSSL::AES_KEY *key, unsigned char *ivec, int *num, const int enc);

typedef NSUInteger(^_YZHAESEncryptSizeBlock)(NSUInteger inputSize, AESPaddingType paddingType);

typedef struct _YZHAESCryptKey
{
    openSSL::AES_KEY *ptr_AESEncryptKey;
    openSSL::AES_KEY *ptr_AESDecryptKey;
}_YZHAESCryptKey_S, *_PTR_YZHAESCryptKey_S;

@interface YZHAESCryptor ()
{
@private
    NSData *_key;
    NSData *_inVector;
    NSData *_encryptVector;
    NSData *_decryptVector;
    _AES_CFB _ptr_func;
    openSSL::AES_KEY _AESEncryptKey;
    openSSL::AES_KEY _AESDecryptKey;
    openSSL::AES_KEY *_ptrAESKey;
    _YZHAESCryptKey_S _cryptKey;
}

@property (nonatomic, assign) int offset;

@property (nonatomic, copy) _YZHAESEncryptSizeBlock  encryptSizeBlock;
@property (nonatomic, copy) YZHAESCryptDataPaddingBlock    paddingBlock;


@end


@implementation YZHAESCryptor

+ (BOOL)accessInstanceVariablesDirectly
{
    return NO;
}

void _AES_cfb1_crypt_block_data(const unsigned char *in, unsigned char *out,
                                size_t length, const openSSL::AES_KEY *key,
                                unsigned char *ivec, int *num, const int enc)
{
    openSSL::AES_cfb1_encrypt(in, out, TYPE_LS(length, 3), key, ivec, num, enc);
}

void _AES_cbc_crypt_block_data(const unsigned char *in, unsigned char *out,
                                 size_t length, const openSSL::AES_KEY *key,
                                 unsigned char *ivec, int *num, const int enc)
{
    if (length <= 0 || key == nullptr) {
        return;
    }
    BOOL r = TYPE_AND(length, (AESBlockSize_s - 1));
    assert(r == 0);
    
    _YZHAESCryptKey_S *ptr_cryptKey = (_YZHAESCryptKey_S*)key;
    
    openSSL::AES_KEY AESKey = (enc == AES_ENCRYPT) ? *(ptr_cryptKey->ptr_AESEncryptKey) : *(ptr_cryptKey->ptr_AESDecryptKey);
    openSSL::AES_cbc_encrypt(in, out, length, &AESKey, ivec, num, enc);
}

void _AES_ecb_crypt_block_data(const unsigned char *in, unsigned char *out,
                     size_t length, const openSSL::AES_KEY *key,
                     unsigned char *ivec, int *num, const int enc)
{
    if (length <= 0 || key == nullptr) {
        return;
    }
    BOOL r = TYPE_AND(length, (AESBlockSize_s - 1));
    assert(r == 0);
    
    _YZHAESCryptKey_S *ptr_cryptKey = (_YZHAESCryptKey_S*)key;

    openSSL::AES_KEY AESKey = (enc == AES_ENCRYPT) ? *(ptr_cryptKey->ptr_AESEncryptKey) : *(ptr_cryptKey->ptr_AESDecryptKey);

    
    size_t cryptLen = 0;
    uint8_t *inTmp = (uint8_t*)in;
    uint8_t *outTmp = (uint8_t*)out;
    while (cryptLen < length) {
        openSSL::AES_KEY AESKeyTmp = AESKey;
        openSSL::AES_ecb_encrypt(inTmp, outTmp, AESBlockSize_s, &AESKeyTmp, ivec, num, enc);
        
        inTmp += AESBlockSize_s;
        outTmp += AESBlockSize_s;
        cryptLen += AESBlockSize_s;
    }
}



- (instancetype)init
{
    self = [super init];
    if (self) {
        _offset = 0;
        _ptr_func = nullptr;
        memset(&_AESEncryptKey, 0, sizeof(openSSL::AES_KEY));
        memset(&_AESDecryptKey, 0, sizeof(openSSL::AES_KEY));
        
        _cryptKey.ptr_AESEncryptKey = &_AESEncryptKey;
        _cryptKey.ptr_AESDecryptKey = &_AESDecryptKey;
    }
    return self;
}

//以这种方式初始化，默认为YZHCryptModeECB的加密模式
- (instancetype)initWithAESKey:(NSData*)AESKey keyType:(YZHAESKeyType)keyType
{
    return [self initWithAESKey:AESKey keyType:keyType inVector:nil cryptMode:YZHCryptModeECB];
}

//输入加密模式及输入向量，如果为YZHCryptModeECB，输入向量不起作用
- (instancetype)initWithAESKey:(NSData *)AESKey keyType:(YZHAESKeyType)keyType inVector:(nullable NSData*)inVector cryptMode:(YZHCryptMode)cryptMode
{
    self = [super init];
    if (self) {
        _key = [self _checkKey:AESKey type:keyType];
        if (_key) {
            _inVector = [self _checkInVector:inVector cryptMode:cryptMode];
            _keyType = keyType;
            _cryptMode = cryptMode;
            [self reset];
        }
    }
    return self;
}

- (NSData*)_copyData:(NSData*)data
{
    NSMutableData *cp = [NSMutableData data];
    [cp appendData:data];
    return cp;
}

- (void)reset
{
    self.offset = 0;
    if (_inVector) {
        _encryptVector = [self _copyData:_inVector];
        _decryptVector = [self _copyData:_inVector];
    }
    [self _setCryptKey];
}

- (void)_setCryptKey
{
    openSSL::AES_set_encrypt_key((uint8_t*)_key.bytes, (int32_t)TYPE_LS((int32_t)_key.length, 3), &_AESEncryptKey);
    openSSL::AES_set_decrypt_key((uint8_t*)_key.bytes, (int32_t)TYPE_LS((int32_t)_key.length, 3), &_AESDecryptKey);
}

- (NSData*)_checkKey:(NSData*)key type:(YZHAESKeyType)type
{
    uint8_t keySize = 0;
    switch (type) {
        case YZHAESKeyType128: {
            keySize = _AESKeySize128;
            break;
        }
        case YZHAESKeyType192: {
            keySize = _AESKeySize192;
            break;
        }
        case YZHAESKeyType256: {
            keySize = _AESKeySize256;
            break;
        }
        default:
            break;
    }
    if (keySize > 0 && key.length >= keySize) {
        return [key subdataWithRange:NSMakeRange(0, keySize)];
    }
    return nil;
}

+(uint8_t)_getPaddingSize:(NSUInteger)inputSize paddingType:(AESPaddingType)paddingType
{
    if (inputSize == 0) {
        return 0;
    }
    NSInteger r = TYPE_AND(inputSize, (AESBlockSize_s - 1));
    NSInteger appendSize = 0;
    if (paddingType == AESPaddingTypeZero) {
        appendSize = r ? AESBlockSize_s - r : 0;
    }
    else if (paddingType == AESPaddingTypePKCS7) {
        appendSize = AESBlockSize_s - r;
    }
    return appendSize;
}

+(NSUInteger)_getEncryptSize:(NSUInteger)inputSize paddingType:(AESPaddingType)paddingType
{
    uint8_t paddingSize = [self _getPaddingSize:inputSize paddingType:paddingType];
    return inputSize + paddingSize;
}

+(NSData*)_paddingData:(NSData*)data type:(AESPaddingType)type cryptOperation:(YZHCryptOperation)cryptOperation
{
    NSUInteger len = data.length;
    if (len == 0) {
        return data;
    }
    uint8_t paddingSize = [self _getPaddingSize:len paddingType:type];
    uint8_t paddingValue = 0;
    
    if (type == AESPaddingTypeZero) {
        if (cryptOperation == YZHCryptOperationEncrypt) {
            paddingValue = 0;
        }
    }
    else if (type == AESPaddingTypePKCS7) {
        if (cryptOperation == YZHCryptOperationEncrypt) {
            paddingValue = paddingSize;
        }
        else {
            uint8_t last = 0;
            [data getBytes:&last range:NSMakeRange(len - 1, 1)];
            if (last > 0 && last <= AESBlockSize_s && last < len) {
                data = [data subdataWithRange:NSMakeRange(0, len - last)];
            }
        }
    }
    
    if (cryptOperation == YZHCryptOperationEncrypt && paddingSize > 0) {
        NSMutableData *oldData = [NSMutableData dataWithData:data];
        NSMutableData *paddingData = [NSMutableData dataWithLength:paddingSize];
        memset((uint8_t*)paddingData.bytes, (uint8_t)paddingValue, paddingSize);
        [oldData appendData:paddingData];
        return [oldData copy];
    }
    return data;
}

- (NSData*)_checkInVector:(nullable NSData*)inVector cryptMode:(YZHCryptMode)cryptMode
{
    switch (cryptMode) {
        case YZHCryptModeCFB: {
            _ptrAESKey = &_AESEncryptKey;
            _ptr_func = (openSSL::AES_cfb128_encrypt);
            self.encryptSizeBlock = ^NSUInteger(NSUInteger inputSize, AESPaddingType paddingType) {
                return inputSize;
            };
//            self.paddingBlock = ^NSData *(YZHAESCryptor *cryptor, NSData *cryptData, AESPaddingType paddingType, YZHCryptOperation cryptOperation) {
//                return cryptData;
//            };
            break;
        }
        case YZHCryptModeCFB1: {
            _ptrAESKey = &_AESEncryptKey;
            _ptr_func = _AES_cfb1_crypt_block_data;//(openSSL::AES_cfb1_encrypt);
            self.encryptSizeBlock = ^NSUInteger(NSUInteger inputSize, AESPaddingType paddingType) {
                return inputSize;
            };
//            self.paddingBlock = ^NSData *(YZHAESCryptor *cryptor, NSData *cryptData, AESPaddingType paddingType, YZHCryptOperation cryptOperation) {
//                return cryptData;
//            };
            break;
        }
        case YZHCryptModeCFB8: {
            _ptrAESKey = &_AESEncryptKey;
            _ptr_func = (openSSL::AES_cfb8_encrypt);
            self.encryptSizeBlock = ^NSUInteger(NSUInteger inputSize, AESPaddingType paddingType) {
                return inputSize;
            };
//            self.paddingBlock = ^NSData *(YZHAESCryptor *cryptor, NSData *cryptData, AESPaddingType paddingType, YZHCryptOperation cryptOperation) {
//                return cryptData;
//            };
            break;
        }
        case YZHCryptModeOFB: {
            _ptrAESKey = &_AESEncryptKey;
            _ptr_func = (openSSL::AES_ofb128_encrypt);
            self.encryptSizeBlock = ^NSUInteger(NSUInteger inputSize, AESPaddingType paddingType) {
                return inputSize;
            };
//            self.paddingBlock = ^NSData *(YZHAESCryptor *cryptor, NSData *cryptData, AESPaddingType paddingType, YZHCryptOperation cryptOperation) {
//                return cryptData;
//            };
            break;
        }
        case YZHCryptModeCBC: {
            _ptrAESKey = (openSSL::AES_KEY *)&_cryptKey;
            _ptr_func = _AES_cbc_crypt_block_data;
            self.encryptSizeBlock = ^NSUInteger(NSUInteger inputSize, AESPaddingType paddingType) {
                return [YZHAESCryptor _getEncryptSize:inputSize paddingType:paddingType];
            };
            self.paddingBlock = ^NSData *(YZHAESCryptor *cryptor, NSData *cryptData, AESPaddingType paddingType, YZHCryptOperation cryptOperation) {
                return [YZHAESCryptor _paddingData:cryptData type:paddingType cryptOperation:cryptOperation];
            };
            break;
        }
        case YZHCryptModeECB: {
            _ptrAESKey = (openSSL::AES_KEY *)&_cryptKey;
            _ptr_func = _AES_ecb_crypt_block_data;
            self.encryptSizeBlock = ^NSUInteger(NSUInteger inputSize, AESPaddingType paddingType) {
                return [YZHAESCryptor _getEncryptSize:inputSize paddingType:paddingType];
            };
            self.paddingBlock = ^NSData *(YZHAESCryptor *cryptor, NSData *cryptData, AESPaddingType paddingType, YZHCryptOperation cryptOperation) {
                return [YZHAESCryptor _paddingData:cryptData type:paddingType cryptOperation:cryptOperation];
            };
            break;
        }
        default:
            break;
    }
    if (cryptMode == YZHCryptModeECB || inVector.length < AESBlockSize_s) {
        return nil;
    }
    return [inVector subdataWithRange:NSMakeRange(0, AESBlockSize_s)];
}

- (BOOL)isValidCryptor
{
    return [self _checkKey:_key type:self.keyType] ? YES : NO;
}

//http://www.seacha.com/tools/aes.html
- (NSData*)crypt:(YZHCryptOperation)operation input:(NSData*)input
{
    return [self crypt:operation input:input paddingType:AESPaddingTypePKCS7 paddingBlock:self.paddingBlock];
}

- (NSData*)crypt:(YZHCryptOperation)operation input:(NSData*)input paddingType:(AESPaddingType)paddingType paddingBlock:(YZHAESCryptDataPaddingBlock)paddingBlock
{
    if (input.length <= 0 || [self isValidCryptor] == NO) {
        return nil;
    }
    NSInteger length = input.length;
    NSMutableData *output = [NSMutableData data];
    int offset = self.offset;
    
    if (operation == YZHCryptOperationEncrypt) {
        size_t outLength = self.encryptSizeBlock(length, paddingType);
        output = [NSMutableData dataWithLength:outLength];
        
        if (paddingBlock) {
            input = paddingBlock(self, input, paddingType, operation);
        }
        
        ((_AES_CFB)*(self->_ptr_func))((uint8_t*)input.bytes, (uint8_t*)output.bytes, input.length, self->_ptrAESKey, (uint8_t*)(_encryptVector.bytes), &offset, AES_ENCRYPT);
    }
    else {
        output = [NSMutableData dataWithLength:length];
        
        ((_AES_CFB)*(self->_ptr_func))((uint8_t*)input.bytes, (uint8_t*)output.bytes, input.length, self->_ptrAESKey, (uint8_t*)(_decryptVector.bytes), &offset, AES_DECRYPT);
        
        if (paddingBlock) {
            output = [paddingBlock(self, output, paddingType, operation) mutableCopy];
        }
    }
    self.offset = offset;
    
    return output;//[output copy];
}

- (void)crypt:(YZHCryptOperation)operation input:(uint8_t*)input inSize:(int64_t)inSize output:(uint8_t*)output outSize:(int64_t*)outSize
{
    [self crypt:operation input:input inSize:inSize output:output outSize:outSize paddingType:AESPaddingTypePKCS7 paddingBlock:self.paddingBlock];
}

- (void)crypt:(YZHCryptOperation)operation input:(uint8_t*)input inSize:(int64_t)inSize output:(uint8_t*)output outSize:(int64_t*)outSize paddingType:(AESPaddingType)paddingType paddingBlock:(YZHAESCryptDataPaddingBlock)paddingBlock
{
    if (input == nullptr || inSize <= 0 || output == nullptr || *outSize < inSize || [self isValidCryptor] == NO) {
        return ;
    }
    
    int offset = self.offset;
    
    int64_t cryptSize = inSize;
    if (operation == YZHCryptOperationEncrypt) {
        cryptSize = self.encryptSizeBlock((NSUInteger)inSize, paddingType);

        uint8_t *inPtr = input;
        NSData *inData = nil;
        if (paddingBlock) {
            inData = [NSData dataWithBytes:input length:(NSUInteger)inSize];
            inData = paddingBlock(self, inData, paddingType, operation);
            inPtr = (uint8_t*)inData.bytes;
            
            cryptSize = MIN(cryptSize, inData.length);
        }
        
        ((_AES_CFB)*(self->_ptr_func))((uint8_t*)inPtr, (uint8_t*)output, (size_t)cryptSize, self->_ptrAESKey, (uint8_t*)(_encryptVector.bytes), &offset, AES_ENCRYPT);
    }
    else {
        
        ((_AES_CFB)*(self->_ptr_func))((uint8_t*)input, (uint8_t*)output, (size_t)cryptSize, self->_ptrAESKey, (uint8_t*)(_decryptVector.bytes), &offset, AES_DECRYPT);
        
        if (paddingBlock) {
            NSData *outData = [NSData dataWithBytesNoCopy:output length:(NSUInteger)cryptSize freeWhenDone:NO];
            outData = paddingBlock(self, outData, paddingType, operation);
            cryptSize = MIN(cryptSize, outData.length);
//            memcpy(output, outData.bytes, cryptSize);
            memmove(output, outData.bytes, (size_t)cryptSize);
        }
    }
    self.offset = offset;
    
    if (outSize) {
        *outSize = cryptSize;
    }
}

@end
